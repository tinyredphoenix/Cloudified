import Foundation
import Photos
import CloudifiedCore

/// End-to-end PhotoLibrary pipeline coordinator.
/// Integrates scanning, incremental content planning, recipe persistence, and plan generation.
public final class PhotoLibraryPipeline: Sendable {
    private let ledger: Ledger
    private let fileStore: FileLeaseStore
    private let storageLayout: StorageLayout
    private let permit: SharedExportPermit
    private let exporter: PhotoResourceExporter
    public let originalPreparer: PhotoLibraryOriginalPreparer

    public init(
        ledger: Ledger,
        fileStore: FileLeaseStore,
        storageLayout: StorageLayout = .shared,
        permit: SharedExportPermit = .shared,
        exporter: PhotoResourceExporter = .shared
    ) {
        self.ledger = ledger
        self.fileStore = fileStore
        self.storageLayout = storageLayout
        self.permit = permit
        self.exporter = exporter
        self.originalPreparer = PhotoLibraryOriginalPreparer(
            ledger: ledger,
            fileStore: fileStore,
            storageLayout: storageLayout,
            permit: permit,
            exporter: exporter
        )
    }

    /// Scans the entire accessible Photo Library, registering canonical AssetIdentity items into the Ledger.
    public func scanLibrary() async throws -> (scanID: UUID, totalDiscovered: Int) {
        return try await PhotoKitScanner.scanAccessibleLibrary(ledger: ledger)
    }

    /// Incrementally measures an individual asset, generates its source-v1 recipe,
    /// builds provider plans, and enqueues them into the Ledger.
    public func planAsset(
        asset: AssetIdentity,
        googleDestination: Destination? = nil,
        telegramDestination: Destination? = nil,
        googleLiveFallback: LivePhotoFallbackOption = .bothSeparately,
        videoPartThreshold: Int64 = LosslessVideoPartSplitter.defaultTargetPartSize
    ) async throws {
        // Fetch PHAsset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing)
        }

        let isLive = phAsset.mediaSubtypes.contains(.photoLive)
        let resources = PHAssetResource.assetResources(for: phAsset)

        // Metadata
        var locationMeta: SourceLocationMetadata?
        if let loc = phAsset.location {
            locationMeta = SourceLocationMetadata(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                altitude: loc.altitude,
                timestamp: loc.timestamp
            )
        }

        let metadata = SourceAssetMetadata(
            creationDate: phAsset.creationDate,
            modificationDate: phAsset.modificationDate,
            pixelWidth: phAsset.pixelWidth,
            pixelHeight: phAsset.pixelHeight,
            durationSeconds: phAsset.duration > 0 ? phAsset.duration : nil,
            isFavorite: phAsset.isFavorite,
            location: locationMeta
        )

        // Measure resource descriptors under the shared permit
        let resourceDescriptors: [SourceResourceDescriptor] = try await permit.withPermit {
            var descriptors: [SourceResourceDescriptor] = []

            for res in resources {
                guard let role = PhotoKitScanner.role(for: res.type) else { continue }

                // Export to temporary file to measure exact bytes and hashes
                let tempURL = storageLayout.stagingURL.appendingPathComponent("measure_\(UUID().uuidString).tmp")
                defer { try? FileManager.default.removeItem(at: tempURL) }

                let (sha256, sha1, byteCount) = try await exporter.exportResource(res, to: tempURL)

                descriptors.append(SourceResourceDescriptor(
                    role: role,
                    uti: res.uniformTypeIdentifier,
                    originalFilename: res.originalFilename,
                    sha256: sha256,
                    sha1: sha1,
                    byteCount: byteCount,
                    photoKitResourceDataUTI: res.uniformTypeIdentifier
                ))
            }
            return descriptors
        }

        guard !resourceDescriptors.isEmpty else {
            throw SafeFailure(.unsupportedOriginal, domain: .photos, cause: .formatRejected)
        }

        // Plan video splitting if needed
        var videoSplit: VideoSplitRecipe?
        if asset.kind == .video, let videoDesc = resourceDescriptors.first(where: { $0.role == .video }) {
            if videoDesc.byteCount > videoPartThreshold {
                let partCount = Int((videoDesc.byteCount + videoPartThreshold - 1) / videoPartThreshold)
                var parts: [VideoPartDescriptor] = []

                // Note: parts are measured precisely on extraction or from master file
                for i in 0..<partCount {
                    let offset = Int64(i) * videoPartThreshold
                    let length = min(videoPartThreshold, videoDesc.byteCount - offset)
                    parts.append(VideoPartDescriptor(
                        partIndex: i,
                        partCount: partCount,
                        offset: offset,
                        byteCount: length,
                        sha256: videoDesc.sha256, // Placeholder updated during master staging
                        sha1: videoDesc.sha1
                    ))
                }
                videoSplit = VideoSplitRecipe(
                    targetPartSize: videoPartThreshold,
                    totalByteCount: videoDesc.byteCount,
                    parts: parts
                )
            }
        }

        let recipe = SourceRecipe(
            assetLocalIdentifier: asset.localIdentifier,
            generation: asset.generation,
            mediaKind: asset.kind,
            isLivePhoto: isLive,
            resources: resourceDescriptors,
            metadata: metadata,
            videoSplit: videoSplit
        )

        // Persist source recipe into Ledger
        let recipeData = try recipe.encode()
        try await ledger.saveSourceRecipe(assetID: asset.id, json: recipeData)

        // Build and enqueue Google plan if destination connected
        if let googleDest = googleDestination {
            let googlePlan = try UploadPlanProducer.buildGooglePlan(
                recipe: recipe,
                livePhotoFallback: googleLiveFallback
            )
            try await ledger.enqueue(assetID: asset.id, destinationID: googleDest.id, plan: googlePlan)
        }

        // Build and enqueue Telegram plan if destination connected
        if let telegramDest = telegramDestination {
            let telegramPlan = try UploadPlanProducer.buildTelegramPlan(recipe: recipe)
            try await ledger.enqueue(assetID: asset.id, destinationID: telegramDest.id, plan: telegramPlan)
        }
    }
}
