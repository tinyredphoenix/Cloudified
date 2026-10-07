import Foundation
import CloudifiedCore

/// Deterministic upload plan builder generating provider-specific plans via ContentIdentity.
public enum UploadPlanProducer {
    /// Builds the Google Photos upload plan adhering to the specified Live Photo fallback choice.
    public static func buildGooglePlan(
        recipe: SourceRecipe,
        livePhotoFallback: LivePhotoFallbackOption = .bothSeparately
    ) throws -> UploadPlan {
        var requirements: [ResourceRequirement] = []
        let policyVersion: String

        let selected: [SourceResourceDescriptor]
        if recipe.isLivePhoto {
            let hasStill = recipe.resources.contains { $0.role == .still }
            let hasMotion = recipe.resources.contains { $0.role == .motion }
            switch livePhotoFallback {
            case .keyImageOnly:
                guard hasStill else { throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing) }
                policyVersion = "google-live-keyImageOnly-v1"
                selected = recipe.resources.filter { $0.role != .motion }
            case .motionVideoOnly:
                guard hasMotion else { throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing) }
                policyVersion = "google-live-motionVideoOnly-v1"
                selected = recipe.resources.filter { $0.role == .motion }
            case .bothSeparately:
                guard hasStill && hasMotion else { throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing) }
                policyVersion = "google-live-bothSeparately-v1"
                selected = recipe.resources
            }
        } else {
            policyVersion = recipe.mediaKind == .video ? "google-video-v1" : "google-photo-v1"
            selected = recipe.resources
        }
        for original in selected {
            requirements.append(try ContentIdentity.resource(role: original.role, originals: [original.originalContent]))
        }

        guard !requirements.isEmpty else {
            throw SafeFailure(.unsupportedOriginal, domain: .photos, cause: .formatRejected)
        }

        let plan = try ContentIdentity.plan(policyVersion: policyVersion, resources: requirements)
        return plan
    }

    /// Builds the Telegram upload plan requiring every original resource/part plus archive manifest.
    public static func buildTelegramPlan(recipe: SourceRecipe) throws -> UploadPlan {
        let policyVersion = "telegram-archive-v1"
        var requirements: [ResourceRequirement] = []
        var manifestEntries: [ArchiveManifestBuilder.ManifestResourceEntry] = []

        for resDesc in recipe.resources {
            if let split = recipe.videoSplits.first(where: {
                ($0.originalSha256 == resDesc.sha256 || ($0.role == resDesc.role && $0.totalByteCount == resDesc.byteCount))
            }), split.parts.count > 1 {
                // Multipart oversized original
                for part in split.parts {
                    let original = part.originalContent
                    let req = try ContentIdentity.resource(role: part.role, originals: [original])
                    requirements.append(req)
                    manifestEntries.append(.init(
                        role: part.role,
                        tag: req.tag,
                        sha256: part.sha256,
                        sha1: part.sha1,
                        byteCount: part.byteCount,
                        partIndex: part.partIndex,
                        partCount: part.partCount
                    ))
                }
            } else {
                // Standard non-split original resource
                let original = resDesc.originalContent
                let req = try ContentIdentity.resource(role: resDesc.role, originals: [original])
                requirements.append(req)
                manifestEntries.append(.init(
                    role: resDesc.role,
                    tag: req.tag,
                    sha256: resDesc.sha256,
                    sha1: resDesc.sha1,
                    byteCount: resDesc.byteCount
                ))
            }
        }

        // Generate manifest association hash including full-original reconstruction descriptors
        let (_, associationHash) = try ArchiveManifestBuilder.buildManifest(
            kind: recipe.mediaKind,
            isLivePhoto: recipe.isLivePhoto,
            metadata: recipe.metadata,
            originals: recipe.resources,
            resources: manifestEntries
        )

        // Manifest resource requirement
        let manifestReq = try ContentIdentity.resource(
            role: .manifest,
            originals: [],
            associationHash: associationHash
        )
        requirements.append(manifestReq)

        let plan = try ContentIdentity.plan(policyVersion: policyVersion, resources: requirements)
        return plan
    }
}
