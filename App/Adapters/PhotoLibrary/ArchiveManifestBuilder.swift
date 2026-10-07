import Foundation
import CryptoKit
import CloudifiedCore

/// Stable archive recipe excludes PhotoKit IDs/generation and final remote IDs.
/// The uploaded document also records confirmed message references and full
/// original hashes/filenames/UTIs, so lossless parts can be reconstructed/verified.
public enum ArchiveManifestBuilder {
    public static let schemaVersion = "manifest-v1"
    public struct ManifestResourceEntry: Codable, Sendable {
        public let role: ResourceRole
        public let tag: String
        public let sha256: String
        public let sha1: String
        public let byteCount: Int64
        public let partIndex: Int?
        public let partCount: Int?
        public init(role: ResourceRole, tag: String, sha256: String, sha1: String, byteCount: Int64,
                    partIndex: Int? = nil, partCount: Int? = nil) {
            self.role = role; self.tag = tag; self.sha256 = sha256; self.sha1 = sha1; self.byteCount = byteCount
            self.partIndex = partIndex; self.partCount = partCount
        }
    }
    public struct ManifestReference: Codable, Sendable {
        public let tag: String
        public let finalReference: Data
    }
    /// Explicit whitelist: future local resource-selector fields in SourceRecipe
    /// must not enter a remote content identity or archived PhotoKit identifiers.
    public struct ManifestOriginal: Codable, Sendable {
        public let role: ResourceRole
        public let uti: String
        public let originalFilename: String
        public let sha256: String
        public let sha1: String
        public let byteCount: Int64
        init(_ source: SourceResourceDescriptor) {
            role = source.role; uti = source.uti; originalFilename = source.originalFilename
            sha256 = source.sha256; sha1 = source.sha1; byteCount = source.byteCount
        }
    }
    public struct ArchiveRecipe: Codable, Sendable {
        public let schema: String
        public let kind: MediaKind
        public let isLivePhoto: Bool
        public let metadata: SourceAssetMetadata
        public let originals: [ManifestOriginal]
        public let resources: [ManifestResourceEntry]
    }
    public struct ManifestDocument: Codable, Sendable {
        public let recipe: ArchiveRecipe
        public let confirmedReferences: [ManifestReference]
    }
    public static func buildManifest(kind: MediaKind, isLivePhoto: Bool,
        metadata: SourceAssetMetadata, originals: [SourceResourceDescriptor],
        resources: [ManifestResourceEntry], receipts: [RemoteReceipt] = []
    ) throws -> (data: Data, associationHash: String) {
        guard !originals.isEmpty, originals.count <= 32, resources.count <= 255 else { throw CoreError.invalidContract }
        let recipe = ArchiveRecipe(schema: schemaVersion, kind: kind, isLivePhoto: isLivePhoto,
                                   metadata: metadata, originals: originals.map(ManifestOriginal.init), resources: resources)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // Milliseconds since Unix epoch retain fractional external capture times;
        // metadata is private archive material, never diagnostic output.
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let stableData = try encoder.encode(recipe)
        let hash = SHA256.hash(data: stableData).map { String(format: "%02x", $0) }.joined()
        let requiredTags = Set(resources.map(\.tag))
        let references = receipts.filter { requiredTags.contains($0.tag) }.sorted { $0.tag < $1.tag }
            .map { ManifestReference(tag: $0.tag, finalReference: $0.opaqueReference) }
        let data = try encoder.encode(ManifestDocument(recipe: recipe, confirmedReferences: references))
        guard data.count <= 1_048_576 else { throw CoreError.invalidContract }
        return (data, hash)
    }
}
