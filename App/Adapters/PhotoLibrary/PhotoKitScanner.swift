import Foundation
import Photos
import CryptoKit
import CloudifiedCore

/// PhotoKit enumeration engine handling access verification, metadata scanning, and bounded pagination.
public enum PhotoKitScanner {
    public static let maxPageSize = 200

    /// Refetch a current PhotoKit snapshot; checking an already fetched immutable
    /// PHAsset again cannot establish that it stayed unchanged during export.
    public static func verifyGeneration(_ identity: AssetIdentity) throws {
        guard let current = PHAsset.fetchAssets(withLocalIdentifiers: [identity.localIdentifier], options: nil).firstObject else {
            throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing)
        }
        guard computeGeneration(for: current) == identity.generation else {
            throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .contentChanged)
        }
    }

    /// Computes a canonical deterministic generation hash for a local PHAsset.
    public static func computeGeneration(for asset: PHAsset) -> String {
        var descriptor = "source-generation-v2:\(asset.localIdentifier):\(asset.pixelWidth)x\(asset.pixelHeight):\(asset.mediaType.rawValue)"
        if let creation = asset.creationDate {
            descriptor += ":c=\(creation.timeIntervalSince1970)"
        }
        if let modification = asset.modificationDate {
            descriptor += ":m=\(modification.timeIntervalSince1970)"
        }
        if asset.duration > 0 {
            descriptor += ":d=\(asset.duration)"
        }
        descriptor += ":s=\(asset.mediaSubtypes.rawValue)"
        descriptor += ":f=\(asset.isFavorite)"
        if let location = asset.location {
            descriptor += ":l=\(location.coordinate.latitude),\(location.coordinate.longitude),\(location.altitude),\(location.timestamp.timeIntervalSince1970)"
        }

        let hash = SHA256.hash(data: Data(descriptor.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Determines the Core MediaKind for a PHAsset.
    /// Live Photos are classified as .photo once per architecture specification.
    public static func kind(for asset: PHAsset) -> MediaKind {
        if asset.mediaType == .video {
            return .video
        }
        return .photo
    }

    /// Maps a PHAssetResourceType to a core ResourceRole.
    /// Excludes rendered derivatives and adjustment metadata.
    public static func role(for type: PHAssetResourceType) -> ResourceRole? {
        switch type {
        case .photo:
            return .still
        case .pairedVideo:
            return .motion
        case .video:
            return .video
        case .alternatePhoto:
            return .auxiliary
        default:
            return nil
        }
    }

    /// Checks if a resource type represents an original camera resource rather than an edited preview.
    public static func isOriginalResourceType(_ type: PHAssetResourceType) -> Bool {
        return role(for: type) != nil
    }

    /// Performs the initial metadata enumeration pass across the accessible photo library.
    /// Paginates asset identities into the Ledger in pages of <= 200 items.
    public static func scanAccessibleLibrary(
        ledger: Ledger,
        fetchOptions: PHFetchOptions? = nil
    ) async throws -> (scanID: UUID, totalDiscovered: Int) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw SafeFailure(.accessDenied, domain: .photos, cause: .permissionDenied)
        }

        let scanID = try await ledger.beginScan()

        let options = fetchOptions ?? PHFetchOptions()
        let mediaPredicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )
        if let existing = options.predicate {
            options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [existing, mediaPredicate])
        } else {
            options.predicate = mediaPredicate
        }
        if options.sortDescriptors == nil || options.sortDescriptors?.isEmpty == true {
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        }

        let fetchResult = PHAsset.fetchAssets(with: options)
        let totalCount = fetchResult.count

        var page: [AssetIdentity] = []
        page.reserveCapacity(maxPageSize)

        for i in 0..<totalCount {
            try Task.checkCancellation()
            let asset = fetchResult.object(at: i)
            let generation = computeGeneration(for: asset)
            let mediaKind = kind(for: asset)

            let identity = AssetIdentity(
                id: UUID(),
                localIdentifier: asset.localIdentifier,
                generation: generation,
                kind: mediaKind
            )
            page.append(identity)

            if page.count == maxPageSize {
                _ = try await ledger.registerAssets(page, scanID: scanID)
                page.removeAll(keepingCapacity: true)
            }
        }

        if !page.isEmpty {
            _ = try await ledger.registerAssets(page, scanID: scanID)
        }

        try await ledger.completeScan(scanID)
        return (scanID, totalCount)
    }
}
