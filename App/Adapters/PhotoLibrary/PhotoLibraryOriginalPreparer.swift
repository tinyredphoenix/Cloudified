import Foundation
import Photos
import CloudifiedCore

/// Production implementation of OriginalPreparer.
/// Resolves frozen asset recipes, exports originals via PhotoKit, slices lossless video parts,
/// and builds archive manifests while strictly honoring storage admission and lease ownership.
public final class PhotoLibraryOriginalPreparer: OriginalPreparer, Sendable {
    private let ledger: Ledger
    private let fileStore: FileLeaseStore
    private let storageLayout: StorageLayout
    private let permit: SharedExportPermit
    private let exporter: PhotoResourceExporter

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
    }

    public func prepare(
        job: JobRecord,
        resource: ResourceRequirement,
        receipts: [RemoteReceipt]
    ) async throws -> [LeasedFile] {
        // 1. Check if the file is already staged and active
        if let existing = try? await fileStore.acquire(fileID: resource.id) {
            return [existing]
        }

        // 2. Handle archive manifest resource
        if resource.role == .manifest {
            return [try await prepareManifest(job: job, resource: resource, receipts: receipts)]
        }

        // 3. Acquire process-wide export permit
        return try await permit.withPermit {
            // Retrieve private durable recipe
            guard let recipeData = try await ledger.sourceRecipe(assetID: job.asset.id),
                  let recipe = try? SourceRecipe.decode(from: recipeData) else {
                throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing)
            }

            var leasedFiles: [LeasedFile] = []

            for original in resource.originals {
                if let partIndex = original.partIndex {
                    // Lossless video part extraction
                    let leased = try await prepareVideoPart(
                        job: job,
                        resourceID: resource.id,
                        original: original,
                        partIndex: partIndex,
                        recipe: recipe
                    )
                    leasedFiles.append(leased)
                } else {
                    // Full original resource export
                    let leased = try await exportOriginalResource(
                        job: job,
                        resourceID: resource.id,
                        original: original,
                        recipe: recipe
                    )
                    leasedFiles.append(leased)
                }
            }

            return leasedFiles
        }
    }

    // MARK: - Manifest Preparation

    private func prepareManifest(
        job: JobRecord,
        resource: ResourceRequirement,
        receipts: [RemoteReceipt]
    ) async throws -> LeasedFile {
        guard let recipeData = try await ledger.sourceRecipe(assetID: job.asset.id),
              let recipe = try? SourceRecipe.decode(from: recipeData) else {
            throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing)
        }

        var entries: [ArchiveManifestBuilder.ManifestResourceEntry] = []
        for req in job.plan.resources where req.role != .manifest {
            for original in req.originals {
                entries.append(.init(
                    role: req.role,
                    tag: req.tag,
                    sha256: original.sha256,
                    sha1: original.sha1,
                    byteCount: original.byteCount,
                    partIndex: original.partIndex,
                    partCount: original.partCount
                ))
            }
        }

        let requiredTags = Set(entries.map(\.tag))
        guard requiredTags.isSubset(of: Set(receipts.filter { $0.destinationID == job.destination.id }.map(\.tag))) else {
            throw SafeFailure(.invariant, domain: .core, cause: .invalidContract)
        }
        let (manifestData, associationHash) = try ArchiveManifestBuilder.buildManifest(
            kind: recipe.mediaKind,
            isLivePhoto: recipe.isLivePhoto,
            metadata: recipe.metadata,
            originals: recipe.resources,
            resources: entries,
            receipts: receipts.filter { $0.destinationID == job.destination.id }
        )

        let expected = try ContentIdentity.resource(role: .manifest, originals: [], associationHash: associationHash)
        guard expected.tag == resource.tag else { throw CoreError.invalidContract }

        let available = storageLayout.availableDiskSpace()
        let reservation = try await ledger.reserveStorage(
            bytes: Int64(manifestData.count),
            availableBytes: available,
            transportOverhead: 0
        )

        let ownership = try await fileStore.beginExport(fileID: resource.id)
        do {
            try manifestData.write(to: ownership.partialURL)
            try FileManager.default.moveItem(at: ownership.partialURL, to: ownership.publishedURL)
            let leased = try await fileStore.registerPublished(
                fileID: resource.id,
                byteCount: Int64(manifestData.count),
                reservationID: reservation.id,
                reexportable: true
            )
            try await fileStore.endExport(ownership)
            return leased
        } catch {
            try? FileManager.default.removeItem(at: ownership.partialURL)
            try? FileManager.default.removeItem(at: ownership.publishedURL)
            try? await fileStore.endExport(ownership)
            try? await ledger.releaseReservation(reservation.id)
            throw error
        }
    }

    // MARK: - Original Media Export

    private func exportOriginalResource(
        job: JobRecord,
        resourceID: UUID,
        original: OriginalContent,
        recipe: SourceRecipe
    ) async throws -> LeasedFile {
        // Fetch PHAsset by local identifier
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [job.asset.localIdentifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing)
        }

        // Verify generation has not changed
        let currentGeneration = PhotoKitScanner.computeGeneration(for: phAsset)
        guard currentGeneration == job.asset.generation else {
            throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .contentChanged)
        }

        // Locate matching resource
        let resources = PHAssetResource.assetResources(for: phAsset)
        guard let matched = resources.first(where: { res in
            let role = PhotoKitScanner.role(for: res.type)
            return role == original.role
        }) else {
            throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing)
        }

        let available = storageLayout.availableDiskSpace()
        let reservation = try await ledger.reserveStorage(
            bytes: original.byteCount,
            availableBytes: available,
            transportOverhead: 0
        )

        let ownership = try await fileStore.beginExport(fileID: resourceID)

        do {
            let (sha256, sha1, bytesWritten) = try await exporter.exportResource(
                matched,
                to: ownership.partialURL
            )

            guard bytesWritten == original.byteCount,
                  sha256 == original.sha256,
                  sha1 == original.sha1 else {
                throw SafeFailure(.invariant, domain: .photos, cause: .contentChanged)
            }

            try FileManager.default.moveItem(at: ownership.partialURL, to: ownership.publishedURL)

            let leased = try await fileStore.registerPublished(
                fileID: resourceID,
                byteCount: bytesWritten,
                reservationID: reservation.id,
                reexportable: true
            )
            try await fileStore.endExport(ownership)

            try? await ledger.appendEvent(
                .export,
                context: EventContext(origin: .source, assetID: job.asset.id, resourceID: resourceID),
                decision: .proceed,
                bytes: bytesWritten
            )

            return leased
        } catch {
            try? FileManager.default.removeItem(at: ownership.partialURL)
            try? FileManager.default.removeItem(at: ownership.publishedURL)
            try? await fileStore.endExport(ownership)
            try? await ledger.releaseReservation(reservation.id)
            throw error
        }
    }

    // MARK: - Video Part Extraction

    private func prepareVideoPart(
        job: JobRecord,
        resourceID: UUID,
        original: OriginalContent,
        partIndex: Int,
        recipe: SourceRecipe
    ) async throws -> LeasedFile {
        guard let split = recipe.videoSplit,
              partIndex < split.parts.count else {
            throw SafeFailure(.invariant, domain: .photos, cause: .invalidContract)
        }
        let partDesc = split.parts[partIndex]

        // Ensure master video is exported/staged first
        let masterResourceDesc = recipe.resources.first { $0.role == .video }
        guard let masterDesc = masterResourceDesc else {
            throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing)
        }

        let masterFileID = UUID(uuidString: "00000000-0000-0000-0000-" + String(format: "%012x", abs(masterDesc.sha256.hashValue)))
            ?? UUID()

        // Acquire or export master video
        let masterLease: LeasedFile
        if let existing = try? await fileStore.acquire(fileID: masterFileID) {
            masterLease = existing
        } else {
            masterLease = try await exportOriginalResource(
                job: job,
                resourceID: masterFileID,
                original: masterDesc.originalContent,
                recipe: recipe
            )
        }
        defer {
            Task { [fileStore] in try? await fileStore.release(masterLease) }
        }

        let available = storageLayout.availableDiskSpace()
        let reservation = try await ledger.reserveStorage(
            bytes: partDesc.byteCount,
            availableBytes: available,
            transportOverhead: 0
        )

        let ownership = try await fileStore.beginExport(fileID: resourceID)

        do {
            let (sha256, sha1, bytesWritten) = try LosslessVideoPartSplitter.extractPart(
                from: masterLease.url,
                descriptor: partDesc,
                to: ownership.partialURL
            )

            guard bytesWritten == partDesc.byteCount,
                  sha256 == partDesc.sha256,
                  sha1 == partDesc.sha1 else {
                throw SafeFailure(.invariant, domain: .photos, cause: .contentChanged)
            }

            try FileManager.default.moveItem(at: ownership.partialURL, to: ownership.publishedURL)

            let leased = try await fileStore.registerPublished(
                fileID: resourceID,
                byteCount: bytesWritten,
                reservationID: reservation.id,
                reexportable: true
            )
            try await fileStore.endExport(ownership)
            return leased
        } catch {
            try? FileManager.default.removeItem(at: ownership.partialURL)
            try? FileManager.default.removeItem(at: ownership.publishedURL)
            try? await fileStore.endExport(ownership)
            try? await ledger.releaseReservation(reservation.id)
            throw error
        }
    }
}
