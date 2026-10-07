import Foundation
import CloudifiedCore

/// Private, durable source-v1 recipe describing an asset's measured original resources,
/// metadata, and deterministic part splitting. Persisted into Ledger.saveSourceRecipe.
public struct SourceRecipe: Codable, Equatable, Sendable {
    public static let currentVersion = "source-v1"

    public let version: String
    public let assetLocalIdentifier: String
    public let generation: String
    public let mediaKind: MediaKind
    public let isLivePhoto: Bool
    public let resources: [SourceResourceDescriptor]
    public let metadata: SourceAssetMetadata
    public let videoSplit: VideoSplitRecipe?

    public init(
        version: String = SourceRecipe.currentVersion,
        assetLocalIdentifier: String,
        generation: String,
        mediaKind: MediaKind,
        isLivePhoto: Bool,
        resources: [SourceResourceDescriptor],
        metadata: SourceAssetMetadata,
        videoSplit: VideoSplitRecipe? = nil
    ) {
        self.version = version
        self.assetLocalIdentifier = assetLocalIdentifier
        self.generation = generation
        self.mediaKind = mediaKind
        self.isLivePhoto = isLivePhoto
        self.resources = resources
        self.metadata = metadata
        self.videoSplit = videoSplit
    }

    /// Serializes this recipe to canonical UTF-8 JSON.
    /// Strictly guards against exceeding the Ledger's 256 KiB limit.
    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(self)
        guard data.count <= 262_144 else {
            throw SafeFailure(.invariant, domain: .photos, cause: .invalidContract)
        }
        return data
    }

    /// Decodes a SourceRecipe from UTF-8 JSON.
    public static func decode(from data: Data) throws -> SourceRecipe {
        let decoder = JSONDecoder()
        return try decoder.decode(SourceRecipe.self, from: data)
    }
}

/// Description of an original asset resource measured directly from PhotoKit export.
public struct SourceResourceDescriptor: Codable, Equatable, Sendable {
    public let role: ResourceRole
    public let uti: String
    public let originalFilename: String
    public let sha256: String
    public let sha1: String
    public let byteCount: Int64
    public let photoKitResourceDataUTI: String?

    public init(
        role: ResourceRole,
        uti: String,
        originalFilename: String,
        sha256: String,
        sha1: String,
        byteCount: Int64,
        photoKitResourceDataUTI: String? = nil
    ) {
        self.role = role
        self.uti = uti
        self.originalFilename = originalFilename
        self.sha256 = sha256
        self.sha1 = sha1
        self.byteCount = byteCount
        self.photoKitResourceDataUTI = photoKitResourceDataUTI
    }

    public var originalContent: OriginalContent {
        OriginalContent(sha256: sha256, sha1: sha1, byteCount: byteCount, role: role)
    }
}

/// External asset metadata extracted from PHAsset properties.
public struct SourceAssetMetadata: Codable, Equatable, Sendable {
    public let creationDate: Date?
    public let modificationDate: Date?
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let durationSeconds: TimeInterval?
    public let isFavorite: Bool
    public let location: SourceLocationMetadata?

    public init(
        creationDate: Date?,
        modificationDate: Date?,
        pixelWidth: Int,
        pixelHeight: Int,
        durationSeconds: TimeInterval? = nil,
        isFavorite: Bool = false,
        location: SourceLocationMetadata? = nil
    ) {
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.durationSeconds = durationSeconds
        self.isFavorite = isFavorite
        self.location = location
    }
}

/// External location metadata for archive manifests.
/// Strictly excluded from diagnostic event logs.
public struct SourceLocationMetadata: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double?
    public let timestamp: Date?

    public init(latitude: Double, longitude: Double, altitude: Double? = nil, timestamp: Date? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
    }
}

/// Lossless video-part split recipe for Telegram large-file archival.
public struct VideoSplitRecipe: Codable, Equatable, Sendable {
    public let targetPartSize: Int64
    public let totalByteCount: Int64
    public let parts: [VideoPartDescriptor]

    public init(targetPartSize: Int64, totalByteCount: Int64, parts: [VideoPartDescriptor]) {
        self.targetPartSize = targetPartSize
        self.totalByteCount = totalByteCount
        self.parts = parts
    }
}

/// Descriptor for a single byte-exact part of a split video.
public struct VideoPartDescriptor: Codable, Equatable, Sendable {
    public let partIndex: Int
    public let partCount: Int
    public let offset: Int64
    public let byteCount: Int64
    public let sha256: String
    public let sha1: String

    public init(partIndex: Int, partCount: Int, offset: Int64, byteCount: Int64, sha256: String, sha1: String) {
        self.partIndex = partIndex
        self.partCount = partCount
        self.offset = offset
        self.byteCount = byteCount
        self.sha256 = sha256
        self.sha1 = sha1
    }

    public var originalContent: OriginalContent {
        OriginalContent(
            sha256: sha256,
            sha1: sha1,
            byteCount: byteCount,
            role: .video,
            partIndex: partIndex,
            partCount: partCount
        )
    }
}
