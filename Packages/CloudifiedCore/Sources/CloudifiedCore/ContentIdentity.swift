import Foundation
import CryptoKit

/// Versioned canonical identities contain no local IDs, installation UUIDs, paths,
/// upload timestamps or remote receipts. Reinstall is allowed to change all of those.
/// Original hashes MUST be computed from the actual unmodified exported bytes.
public enum ContentIdentity {
    public static let version = "cloudified-v1"
    private struct ResourceKey: Encodable {
        let version: String
        let role: ResourceRole
        let originals: [OriginalContent]
        let associationHash: String?
    }
    private struct PlanKey: Encodable {
        let version: String
        let policyVersion: String
        let resources: [ResourceKeyWithTag]
    }
    private struct ResourceKeyWithTag: Encodable {
        let tag: String
        let role: ResourceRole
        let originals: [OriginalContent]
    }
    /// Manifest associationHash hashes the archive recipe/external metadata, not
    /// its eventual transport-dependent message IDs. Paired uploads may include a
    /// stable association hash. Plain original/part identity uses role + byte hashes.
    public static func resource(role: ResourceRole, originals: [OriginalContent], associationHash: String? = nil) throws -> ResourceRequirement {
        guard associationHash.map({ UploadPlan.hex($0, length: 64) }) ?? true,
              role != .manifest || associationHash != nil else { throw CoreError.invalidContract }
        let key = ResourceKey(version: version, role: role, originals: originals, associationHash: associationHash)
        return ResourceRequirement(tag: try digest(key), role: role, originals: originals)
    }
    public static func plan(policyVersion: String, resources: [ResourceRequirement]) throws -> UploadPlan {
        let key = PlanKey(version: version, policyVersion: policyVersion,
                          resources: resources.map { ResourceKeyWithTag(tag: $0.tag, role: $0.role, originals: $0.originals) })
        let plan = UploadPlan(coverageHash: try digest(key), policyVersion: policyVersion, resources: resources)
        try plan.validate()
        return plan
    }
    public static func telegramCaptionTag(_ resource: ResourceRequirement) throws -> String {
        guard UploadPlan.hex(resource.tag, length: 64) else { throw CoreError.invalidContract }
        return "\(version):\(resource.tag)"
    }
    private static func digest<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return SHA256.hash(data: try encoder.encode(value)).map { String(format: "%02x", $0) }.joined()
    }
}
