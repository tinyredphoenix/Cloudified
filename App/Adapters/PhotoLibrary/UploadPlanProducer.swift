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

        if recipe.isLivePhoto {
            let stillDesc = recipe.resources.first { $0.role == .still }
            let motionDesc = recipe.resources.first { $0.role == .motion }

            switch livePhotoFallback {
            case .keyImageOnly:
                policyVersion = "google-live-keyImageOnly-v1"
                if let still = stillDesc {
                    let req = try ContentIdentity.resource(role: .still, originals: [still.originalContent])
                    requirements.append(req)
                }
            case .motionVideoOnly:
                policyVersion = "google-live-motionVideoOnly-v1"
                if let motion = motionDesc {
                    let req = try ContentIdentity.resource(role: .motion, originals: [motion.originalContent])
                    requirements.append(req)
                }
            case .bothSeparately:
                policyVersion = "google-live-bothSeparately-v1"
                if let still = stillDesc {
                    let reqStill = try ContentIdentity.resource(role: .still, originals: [still.originalContent])
                    requirements.append(reqStill)
                }
                if let motion = motionDesc {
                    let reqMotion = try ContentIdentity.resource(role: .motion, originals: [motion.originalContent])
                    requirements.append(reqMotion)
                }
            }
        } else if recipe.mediaKind == .video {
            policyVersion = "google-video-v1"
            if let videoDesc = recipe.resources.first(where: { $0.role == .video }) {
                let req = try ContentIdentity.resource(role: .video, originals: [videoDesc.originalContent])
                requirements.append(req)
            }
        } else {
            policyVersion = "google-photo-v1"
            if let stillDesc = recipe.resources.first(where: { $0.role == .still }) {
                let req = try ContentIdentity.resource(role: .still, originals: [stillDesc.originalContent])
                requirements.append(req)
            }
        }

        guard !requirements.isEmpty else {
            throw SafeFailure(.unsupportedOriginal, domain: .photos, cause: .formatRejected)
        }

        let plan = try ContentIdentity.plan(policyVersion: policyVersion, resources: requirements)
        try plan.validate()
        return plan
    }

    /// Builds the Telegram upload plan requiring every original resource/part plus archive manifest.
    public static func buildTelegramPlan(recipe: SourceRecipe) throws -> UploadPlan {
        let policyVersion = "telegram-archive-v1"
        var requirements: [ResourceRequirement] = []
        var manifestEntries: [ArchiveManifestBuilder.ManifestResourceEntry] = []

        if recipe.mediaKind == .video, let split = recipe.videoSplit, split.parts.count > 1 {
            // Multipart video
            for part in split.parts {
                let original = part.originalContent
                let req = try ContentIdentity.resource(role: .video, originals: [original])
                requirements.append(req)
                manifestEntries.append(.init(
                    role: .video,
                    tag: req.tag,
                    sha256: part.sha256,
                    sha1: part.sha1,
                    byteCount: part.byteCount,
                    partIndex: part.partIndex,
                    partCount: part.partCount
                ))
            }
        } else {
            // Standard media (still photo, Live Photo pair, or single video)
            for resDesc in recipe.resources {
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

        // Generate manifest association hash
        let (_, associationHash) = try ArchiveManifestBuilder.buildManifest(
            generation: recipe.generation,
            kind: recipe.mediaKind,
            isLivePhoto: recipe.isLivePhoto,
            metadata: recipe.metadata,
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
        try plan.validate()
        return plan
    }
}
