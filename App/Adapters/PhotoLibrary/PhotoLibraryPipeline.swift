import Foundation
import Photos
import CloudifiedCore

/// End-to-end PhotoLibrary pipeline coordinator conforming to PhotoLibraryAdapterProtocol.
/// Integrates scanning, incremental admitted planning, recipe persistence, and independent plan generation.
public final class PhotoLibraryPipeline: PhotoLibraryAdapterProtocol, Sendable {
    private let ledger: Ledger
    private let fileStore: FileLeaseStore
    private let storageLayout: StorageLayout
    private let permit: SharedExportPermit
    private let exporter: PhotoResourceExporter
    private let _originalPreparer: PhotoLibraryOriginalPreparer

    public var originalPreparer: any OriginalPreparer {
        _originalPreparer
    }

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
        self._originalPreparer = PhotoLibraryOriginalPreparer(
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

    /// Incrementally measures an individual asset with admitted reservations, generates its source-v1 recipe,
    /// builds independent provider plans, and enqueues them into the Ledger.
    public func planAsset(
        asset: AssetIdentity,
        googleDestination: Destination? = nil,
        telegramDestination: Destination? = nil,
        googleLiveFallback: LivePhotoFallbackOption = .bothSeparately,
        videoPartThreshold: Int64 = LosslessVideoPartSplitter.defaultTargetPartSize
    ) async throws {
        do {
            // Fetch PHAsset
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil)
            guard let phAsset = fetchResult.firstObject else {
                throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing)
            }

            // Verify generation before measurement
            let initialGen = PhotoKitScanner.computeGeneration(for: phAsset)
            guard initialGen == asset.generation else {
                throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .contentChanged)
            }

            let isLive = phAsset.mediaSubtypes.contains(.photoLive)
            let allResources = PHAssetResource.assetResources(for: phAsset)
            let originalResources = allResources.filter { PhotoKitScanner.isOriginalResourceType($0.type) }
                .sorted { ($0.type.rawValue, $0.originalFilename, $0.uniformTypeIdentifier) <
                    ($1.type.rawValue, $1.originalFilename, $1.uniformTypeIdentifier) }

            guard !originalResources.isEmpty else {
                throw SafeFailure(.unsupportedOriginal, domain: .photos, cause: .formatRejected)
            }

            // Extract metadata
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

            // Measure resource descriptors under the shared permit with admitted storage reservations
            let (descriptors, splits): ([SourceResourceDescriptor], [VideoSplitRecipe]) = try await permit.withPermit {
                var measuredDescriptors: [SourceResourceDescriptor] = []
                var measuredSplits: [VideoSplitRecipe] = []

                for res in originalResources {
                    guard let role = PhotoKitScanner.role(for: res.type) else { continue }

                    let available = try storageLayout.availableCapacity()
                    let safety: Int64 = 536_870_912
                    let transportOverhead: Int64 = 268_435_456
                    guard available >= safety + transportOverhead + 1_048_576 else {
                        throw SafeFailure(.diskFull, domain: .fileSystem, cause: .insufficientSpace)
                    }

                    let reservedCap = min(available - safety - transportOverhead, 2_000_000_000)
                    let reservation = try await ledger.reserveStorage(
                        bytes: reservedCap,
                        availableBytes: available,
                        transportOverhead: transportOverhead
                    )

                    let stagingID = UUID()
                    let ownership: ExportFileOwnership
                    do {
                        ownership = try await fileStore.beginExport(fileID: stagingID)
                    } catch {
                        try await ledger.releaseReservation(reservation.id)
                        throw error
                    }

                    var publishedLease: LeasedFile?
                    var exportEnded = false
                    do {
                        let (sha256, sha1, bytesWritten) = try await exporter.exportResource(
                            res,
                            to: ownership.partialURL,
                            beforeWrite: { written in
                                guard written <= reservedCap else {
                                    throw SafeFailure(.diskFull, domain: .fileSystem, cause: .insufficientSpace)
                                }
                            }
                        )

                        // Verify generation after measurement
                        try PhotoKitScanner.verifyGeneration(asset)

                        // Atomically move partial to published path
                        try FileManager.default.moveItem(at: ownership.partialURL, to: ownership.publishedURL)

                        // Resize reservation to exact measured bytes
                        let currentAvailable = try storageLayout.availableCapacity()
                        let resized = try await ledger.reserveStorage(
                            bytes: bytesWritten,
                            availableBytes: currentAvailable,
                            transportOverhead: 0,
                            writtenBytes: bytesWritten,
                            replacing: reservation.id
                        )

                        let content = OriginalContent(sha256: sha256, sha1: sha1, byteCount: bytesWritten, role: role)
                        let leased = try await fileStore.registerPublished(
                            fileID: stagingID,
                            byteCount: bytesWritten,
                            reservationID: resized.id,
                            reexportable: true,
                            content: content
                        )
                        publishedLease = leased
                        try await fileStore.endExport(ownership)
                        exportEnded = true

                        // Emit export & hashing events
                        try await ledger.appendEvent(
                            .export,
                            context: EventContext(origin: .source, assetID: asset.id),
                            decision: .proceed,
                            bytes: bytesWritten
                        )
                        try await ledger.appendEvent(
                            .hashing,
                            context: EventContext(origin: .source, assetID: asset.id),
                            decision: .proceed,
                            bytes: bytesWritten
                        )

                        // If oversized original, compute real part hashes while holding leased file
                        if bytesWritten > videoPartThreshold {
                            let split = try LosslessVideoPartSplitter.planSplit(
                                fileURL: leased.url,
                                totalBytes: bytesWritten,
                                role: role,
                                originalSha256: sha256,
                                targetPartSize: videoPartThreshold
                            )
                            measuredSplits.append(split)
                            try await ledger.appendEvent(
                                .preparation,
                                context: EventContext(origin: .source, assetID: asset.id),
                                decision: .proceed,
                                bytes: bytesWritten
                            )
                        }

                        // Release lease; file remains in cache with recoverable=1 for upload reuse/cleanup
                        publishedLease = nil // release removes its runtime pin even if diagnostics fail
                        try await fileStore.release(leased)

                        measuredDescriptors.append(SourceResourceDescriptor(
                            role: role,
                            uti: res.uniformTypeIdentifier,
                            originalFilename: res.originalFilename,
                            sha256: sha256,
                            sha1: sha1,
                            byteCount: bytesWritten,
                            photoKitResourceDataUTI: res.uniformTypeIdentifier
                        ))
                    } catch {
                        var cleanupError: (any Error)?
                        if let leased = publishedLease {
                            do { try await fileStore.release(leased) } catch { cleanupError = error }
                        }
                        if !exportEnded {
                            do { try await fileStore.rollbackExport(ownership, reservationID: reservation.id) }
                            catch { cleanupError = error }
                        }
                        throw cleanupError ?? error
                    }
                }

                return (measuredDescriptors, measuredSplits)
            }

            guard !descriptors.isEmpty else {
                throw SafeFailure(.unsupportedOriginal, domain: .photos, cause: .formatRejected)
            }

            let recipe = try SourceRecipe(
                assetLocalIdentifier: asset.localIdentifier,
                generation: asset.generation,
                mediaKind: asset.kind,
                isLivePhoto: isLive,
                resources: descriptors,
                metadata: metadata,
                videoSplits: splits
            )

            // Persist source recipe into Ledger
            let recipeData = try recipe.encode()
            try await ledger.saveSourceRecipe(assetID: asset.id, json: recipeData)

            // Independent plan generation and enqueue for Google
            if let googleDest = googleDestination {
                do {
                    let googlePlan = try UploadPlanProducer.buildGooglePlan(
                        recipe: recipe,
                        livePhotoFallback: googleLiveFallback
                    )
                    try await ledger.enqueue(assetID: asset.id, destinationID: googleDest.id, plan: googlePlan)
                } catch {
                    let failure = (error as? SafeFailure) ?? SafeFailure(.unsupportedOriginal, domain: .photos, cause: .formatRejected)
                    try await ledger.recordSourceFailure(
                        assetID: asset.id,
                        destinationIDs: [googleDest.id],
                        error: failure,
                        permanent: true
                    )
                }
            }

            // Independent plan generation and enqueue for Telegram
            if let telegramDest = telegramDestination {
                do {
                    let telegramPlan = try UploadPlanProducer.buildTelegramPlan(recipe: recipe)
                    try await ledger.enqueue(assetID: asset.id, destinationID: telegramDest.id, plan: telegramPlan)
                } catch {
                    let failure = (error as? SafeFailure) ?? SafeFailure(.unsupportedOriginal, domain: .photos, cause: .formatRejected)
                    try await ledger.recordSourceFailure(
                        assetID: asset.id,
                        destinationIDs: [telegramDest.id],
                        error: failure,
                        permanent: true
                    )
                }
            }
        } catch {
            let failure = (error as? SafeFailure) ?? SafeFailure(.transfer, domain: .photos, cause: .unknown)
            let dests = [googleDestination?.id, telegramDestination?.id].compactMap { $0 }
            if !dests.isEmpty {
                let isPermanent = failure.category == .unsupportedOriginal || failure.cause == .sourceMissing
                try? await ledger.recordSourceFailure(
                    assetID: asset.id,
                    destinationIDs: dests,
                    error: failure,
                    permanent: isPermanent
                )
            }
            throw error
        }
    }

    // MARK: - Bounded Planning Producer (usable by P5)

    public struct PlanBatchResult: Sendable {
        public let nextCursor: Int64
        public let plannedCount: Int
        public let failedCount: Int
        public let hasMore: Bool
    }

    /// Paginates scanned canonical identities from the Ledger in bounded pages, planning each asset.
    /// Asset-level failures are recorded to Ledger without aborting the batch.
    public func planScannedBatch(
        scanID: UUID,
        afterCursor: Int64 = 0,
        limit: Int = 50,
        googleDestination: Destination? = nil,
        telegramDestination: Destination? = nil,
        googleLiveFallback: LivePhotoFallbackOption = .bothSeparately,
        videoPartThreshold: Int64 = LosslessVideoPartSplitter.defaultTargetPartSize
    ) async throws -> PlanBatchResult {
        let page = try await ledger.scannedAssetPage(scanID: scanID, afterCursor: afterCursor, limit: limit)
        guard !page.isEmpty else {
            return PlanBatchResult(nextCursor: afterCursor, plannedCount: 0, failedCount: 0, hasMore: false)
        }

        var planned = 0
        var failed = 0
        var lastCursor = afterCursor

        for row in page {
            try Task.checkCancellation()
            lastCursor = max(lastCursor, row.cursor)
            do {
                try await planAsset(
                    asset: row.asset,
                    googleDestination: googleDestination,
                    telegramDestination: telegramDestination,
                    googleLiveFallback: googleLiveFallback,
                    videoPartThreshold: videoPartThreshold
                )
                planned += 1
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failed += 1
                // Failure already durably recorded via recordSourceFailure inside planAsset
            }
        }

        return PlanBatchResult(
            nextCursor: lastCursor,
            plannedCount: planned,
            failedCount: failed,
            hasMore: page.count == limit
        )
    }
}
