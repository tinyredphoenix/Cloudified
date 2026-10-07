import Foundation
import CryptoKit
import CloudifiedCore

/// Builder for bounded Telegram archive manifest JSON (<= 1 MiB) and association hashes.
public enum ArchiveManifestBuilder {
    public static let schemaVersion = "manifest-v1"

    /// Manifest structure encoded into the archive document.
    public struct ManifestDocument: Codable, Sendable {
        public let schema: String
        public let generation: String
        public let kind: MediaKind
        public let isLivePhoto: Bool
        public let metadata: SourceAssetMetadata
        public let resources: [ManifestResourceEntry]

        public init(
            schema: String = ArchiveManifestBuilder.schemaVersion,
            generation: String,
            kind: MediaKind,
            isLivePhoto: Bool,
            metadata: SourceAssetMetadata,
            resources: [ManifestResourceEntry]
        ) {
            self.schema = schema
            self.generation = generation
            self.kind = kind
            self.isLivePhoto = isLivePhoto
            self.metadata = metadata
            self.resources = resources
        }
    }

    public struct ManifestResourceEntry: Codable, Sendable {
        public let role: ResourceRole
        public let tag: String
        public let sha256: String
        public let sha1: String
        public let byteCount: Int64
        public let partIndex: Int?
        public let partCount: Int?

        public init(
            role: ResourceRole,
            tag: String,
            sha256: String,
            sha1: String,
            byteCount: Int64,
            partIndex: Int? = nil,
            partCount: Int? = nil
        ) {
            self.role = role
            self.tag = tag
            self.sha256 = sha256
            self.sha1 = sha1
            self.byteCount = byteCount
            self.partIndex = partIndex
            self.partCount = partCount
        }
    }

    /// Serializes the manifest to deterministic JSON and computes its association hash.
    public static func buildManifest(
        generation: String,
        kind: MediaKind,
        isLivePhoto: Bool,
        metadata: SourceAssetMetadata,
        resources: [ManifestResourceEntry]
    ) throws -> (data: Data, associationHash: String) {
        let doc = ManifestDocument(
            generation: generation,
            kind: kind,
            isLivePhoto: isLivePhoto,
            metadata: metadata,
            resources: resources
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(doc)

        guard data.count <= 1_048_576 else {
            throw SafeFailure(.invariant, domain: .core, cause: .invalidContract)
        }

        let hashHex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return (data, hashHex)
    }
}
