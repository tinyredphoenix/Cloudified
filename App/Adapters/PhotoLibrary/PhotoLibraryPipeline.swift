import Foundation
@preconcurrency import Photos
import os
import CloudifiedCore

/// End-to-end PhotoLibrary pipeline coordinator conforming to PhotoLibraryAdapterProtocol.
/// Integrates scanning, demand-driven admitted planning, recipe persistence, and independent plan generation.
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
        storageLayout: StorageLayout,
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
        // Both empty destination arguments must cause no export/enqueue work
        guard googleDestination != nil || telegramDestination != nil else {
            return
        }

        try Task.checkCancellation()

        // Fetch PHAsset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            let err = SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing)
            let dests = [googleDestination?.id, telegramDestination?.id].compactMap { $0 }
            if !dests.isEmpty {
                try await ledger.recordSourceFailure(assetID: asset.id, destinationIDs: dests, error: err, permanent: true)
            }
            throw err
        }

        // Verify generation before measurement against refetched snapshot
        do {
            try PhotoKitScanner.verifyGeneration(asset)
        } catch {
            let safeErr = (error as? SafeFailure) ?? SafeFailure(.sourceUnavailable, domain: .photos, cause: .contentChanged)
            let dests = [googleDestination?.id, telegramDestination?.id].compactMap { $0 }
            if !dests.isEmpty {
                try await ledger.recordSourceFailure(assetID: asset.id, destinationIDs: dests, error: safeErr, permanent: true)
            }
            throw safeErr
        }

        let isLive = phAsset.mediaSubtypes.contains(.photoLive)
        let allResources = PHAssetResource.assetResources(for: phAsset)
        let originalResources = allResources.filter { PhotoKitScanner.isOriginalResourceType($0.type) }
            .sorted { ($0.type.rawValue, $0.originalFilename, $0.uniformTypeIdentifier) <
                ($1.type.rawValue, $1.originalFilename, $1.uniformTypeIdentifier) }

        guard !originalResources.isEmpty else {
            let err = SafeFailure(.unsupportedOriginal, domain: .photos, cause: .formatRejected)
            let dests = [googleDestination?.id, telegramDestination?.id].compactMap { $0 }
            if !dests.isEmpty {
                try await ledger.recordSourceFailure(assetID: asset.id, destinationIDs: dests, error: err, permanent: true)
            }
            throw err
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

        struct PreparedResourcesOutput: Sendable {
            var measuredDescriptors: [SourceResourceDescriptor] = []
            var measuredSplits: [VideoSplitRecipe] = []
            var failedResources: [(role: ResourceRole, error: SafeFailure)] = []
            var telegramSplitFailed: Bool = false
        }

        struct CandidateEntry: @unchecked Sendable {
            let resource: PHAssetResource
            let selectorIndex: Int
        }

        // Group and index identical candidates by (type, originalFilename, uniformTypeIdentifier) to freeze selectors
        var candidateCounts: [String: Int] = [:]
        var tempSelectors: [CandidateEntry] = []
        for res in originalResources {
            let key = "\(res.type.rawValue):\(res.originalFilename):\(res.uniformTypeIdentifier)"
            let idx = candidateCounts[key, default: 0]
            candidateCounts[key] = idx + 1
            tempSelectors.append(CandidateEntry(resource: res, selectorIndex: idx))
        }
        let resourceSelectors = tempSelectors

        let output = try await permit.withPermit { () -> PreparedResourcesOutput in
            var result = PreparedResourcesOutput()
            for entry in resourceSelectors {
                try Task.checkCancellation()
                let res = entry.resource
                let selectorIdx = entry.selectorIndex
                guard let role = PhotoKitScanner.role(for: res.type) else { continue }

                // Conservative copy count for enabled transports
                let copyCount = (googleDestination != nil && telegramDestination != nil) ? 2 : 1
                let fixedOverhead: Int64 = 67_108_864
                let available: Int64
                do {
                    available = try storageLayout.availableCapacity()
                } catch {
                    let safeErr = (error as? SafeFailure) ?? SafeFailure(.sourceUnavailable, domain: .fileSystem, cause: .unknown)
                    result.failedResources.append((role: role, error: safeErr))
                    continue
                }

                let reservation: StorageReservation
                do {
                    reservation = try await ledger.reserveSourceStorage(
                        availableBytes: available,
                        additionalCopyCount: copyCount,
                        fixedOverheadBytes: fixedOverhead
                    )
                } catch {
                    let safeErr = (error as? SafeFailure) ?? SafeFailure(.diskFull, domain: .fileSystem, cause: .insufficientSpace)
                    result.failedResources.append((role: role, error: safeErr))
                    continue
                }

                let reservedCap = reservation.byteCount
                let stagingID = UUID()
                let ownership: ExportFileOwnership
                do {
                    ownership = try await fileStore.beginExport(fileID: stagingID)
                } catch {
                    try? await ledger.releaseReservation(reservation.id)
                    let safeErr = (error as? SafeFailure) ?? SafeFailure(.transfer, domain: .fileSystem, cause: .unknown)
                    result.failedResources.append((role: role, error: safeErr))
                    continue
                }

                var publishedLease: LeasedFile?
                var exportEnded = false
                let coalescer = SourceProgressCoalescer(
                    ledger: ledger,
                    context: EventContext(origin: .source, assetID: asset.id)
                )

                do {
                    let (sha256, sha1, bytesWritten) = try await exporter.exportResource(
                        res,
                        to: ownership.partialURL,
                        beforeWrite: { [storageLayout] written in
                            guard written <= reservedCap else {
                                throw SafeFailure(.diskFull, domain: .fileSystem, cause: .insufficientSpace)
                            }
                            let freeSpace = try storageLayout.availableCapacity()
                            guard freeSpace >= 536_870_912 else {
                                throw SafeFailure(.diskFull, domain: .fileSystem, cause: .insufficientSpace)
                            }
                            try coalescer.update(bytes: written)
                        }
                    )

                    // Verify generation after measurement
                    try PhotoKitScanner.verifyGeneration(asset)

                    // Atomically move partial to published path
                    try FileManager.default.moveItem(at: ownership.partialURL, to: ownership.publishedURL)

                    // Resize reservation to exact measured bytes with conservative overhead
                    let currentAvailable = try storageLayout.availableCapacity()
                    let actualTransportOverhead = fixedOverhead + bytesWritten * Int64(copyCount)
                    let resized = try await ledger.reserveStorage(
                        bytes: bytesWritten,
                        availableBytes: currentAvailable,
                        transportOverhead: actualTransportOverhead,
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

                    try await coalescer.finish(finalBytes: bytesWritten)

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

                    // If Telegram is enabled and original is oversized video, compute real part hashes while holding lease
                    if telegramDestination != nil && bytesWritten > videoPartThreshold && role == .video {
                        do {
                            let split = try LosslessVideoPartSplitter.planSplit(
                                fileURL: leased.url,
                                totalBytes: bytesWritten,
                                role: role,
                                originalSha256: sha256,
                                targetPartSize: videoPartThreshold
                            )
                            result.measuredSplits.append(split)
                            try await ledger.appendEvent(
                                .preparation,
                                context: EventContext(origin: .source, assetID: asset.id),
                                decision: .proceed,
                                bytes: bytesWritten
                            )
                        } catch {
                            result.telegramSplitFailed = true
                        }
                    }

                    // Release lease; file remains in cache with recoverable=1 for upload reuse/cleanup
                    publishedLease = nil
                    try await fileStore.release(leased)

                    result.measuredDescriptors.append(SourceResourceDescriptor(
                        role: role,
                        uti: res.uniformTypeIdentifier,
                        originalFilename: res.originalFilename,
                        sha256: sha256,
                        sha1: sha1,
                        byteCount: bytesWritten,
                        photoKitResourceDataUTI: res.uniformTypeIdentifier,
                        resourceType: res.type.rawValue,
                        selectorIndex: selectorIdx
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
                    let safeErr = (error as? SafeFailure) ?? SafeFailure(.transfer, domain: .photos, cause: .unknown)
                    result.failedResources.append((role: role, error: safeErr))
                    if let cleanupError { throw cleanupError }
                }
            }
            return result
        }

        let measuredDescriptors = output.measuredDescriptors
        let measuredSplits = output.measuredSplits
        let failedResources = output.failedResources
        let telegramSplitFailed = output.telegramSplitFailed

        // Build source recipe if at least one resource was successfully measured
        let recipe: SourceRecipe?
        if !measuredDescriptors.isEmpty {
            recipe = try? SourceRecipe(
                assetLocalIdentifier: asset.localIdentifier,
                generation: asset.generation,
                mediaKind: asset.kind,
                isLivePhoto: isLive,
                resources: measuredDescriptors,
                metadata: metadata,
                videoSplits: measuredSplits
            )
            if let recipe, let recipeData = try? recipe.encode() {
                try await ledger.saveSourceRecipe(assetID: asset.id, json: recipeData)
            }
        } else {
            recipe = nil
        }

        // Genuine independent provider plan evaluation and enqueue
        var googleEnqueued = false
        var telegramEnqueued = false

        // Google Photos evaluation
        if let googleDest = googleDestination {
            do {
                guard let recipe else {
                    let err = failedResources.first?.error ?? SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing)
                    throw err
                }
                // Check if Google's specific required coverage is satisfied
                if isLive {
                    let hasStill = recipe.resources.contains { $0.role == .still }
                    let hasMotion = recipe.resources.contains { $0.role == .motion }
                    switch googleLiveFallback {
                    case .keyImageOnly:
                        guard hasStill else { throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing) }
                    case .motionVideoOnly:
                        guard hasMotion else { throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing) }
                    case .bothSeparately:
                        guard hasStill && hasMotion else { throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing) }
                    }
                }
                let googlePlan = try UploadPlanProducer.buildGooglePlan(
                    recipe: recipe,
                    livePhotoFallback: googleLiveFallback
                )
                try await ledger.enqueue(assetID: asset.id, destinationID: googleDest.id, plan: googlePlan)
                googleEnqueued = true
            } catch let err as CoreError {
                throw err
            } catch {
                let failure = (error as? SafeFailure) ?? SafeFailure(.unsupportedOriginal, domain: .photos, cause: .formatRejected)
                try await ledger.recordSourceFailure(
                    assetID: asset.id,
                    destinationIDs: [googleDest.id],
                    error: failure,
                    permanent: failure.category == .unsupportedOriginal || failure.cause == .sourceMissing
                )
            }
        }

        // Telegram evaluation
        if let telegramDest = telegramDestination {
            do {
                guard let recipe, !telegramSplitFailed else {
                    let err = failedResources.first?.error ?? SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing)
                    throw err
                }
                // Telegram strictly requires every original resource
                guard recipe.resources.count == originalResources.count else {
                    throw SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing)
                }
                let telegramPlan = try UploadPlanProducer.buildTelegramPlan(recipe: recipe)
                try await ledger.enqueue(assetID: asset.id, destinationID: telegramDest.id, plan: telegramPlan)
                telegramEnqueued = true
            } catch let err as CoreError {
                throw err
            } catch {
                let failure = (error as? SafeFailure) ?? SafeFailure(.unsupportedOriginal, domain: .photos, cause: .formatRejected)
                try await ledger.recordSourceFailure(
                    assetID: asset.id,
                    destinationIDs: [telegramDest.id],
                    error: failure,
                    permanent: failure.category == .unsupportedOriginal || failure.cause == .sourceMissing
                )
            }
        }

        if !googleEnqueued && !telegramEnqueued {
            let primaryErr = failedResources.first?.error ?? SafeFailure(.sourceUnavailable, domain: .photos, cause: .sourceMissing)
            throw primaryErr
        }
    }

    // MARK: - Bounded Planning Producer (usable by P5)

    public struct PlanBatchResult: Sendable {
        public let nextCursor: Int64
        public let plannedCount: Int
        public let failedCount: Int
        public let hasMore: Bool
    }

    /// Plans at most ONE asset per demand, returning immediately so P5 can merge a ready drain.
    /// Asset-level failures are recorded to Ledger without aborting the producer.
    public func planNextAsset(
        scanID: UUID,
        afterCursor: Int64 = 0,
        googleDestination: Destination? = nil,
        telegramDestination: Destination? = nil,
        googleLiveFallback: LivePhotoFallbackOption = .bothSeparately,
        videoPartThreshold: Int64 = LosslessVideoPartSplitter.defaultTargetPartSize
    ) async throws -> PlanBatchResult {
        guard googleDestination != nil || telegramDestination != nil else {
            return PlanBatchResult(nextCursor: afterCursor, plannedCount: 0, failedCount: 0, hasMore: false)
        }

        let page = try await ledger.scannedAssetPage(scanID: scanID, afterCursor: afterCursor, limit: 1)
        guard let row = page.first else {
            return PlanBatchResult(nextCursor: afterCursor, plannedCount: 0, failedCount: 0, hasMore: false)
        }

        try Task.checkCancellation()

        var planned = 0
        var failed = 0

        do {
            try await planAsset(
                asset: row.asset,
                googleDestination: googleDestination,
                telegramDestination: telegramDestination,
                googleLiveFallback: googleLiveFallback,
                videoPartThreshold: videoPartThreshold
            )
            planned = 1
        } catch is CancellationError {
            throw CancellationError()
        } catch let err as CoreError {
            throw err
        } catch {
            failed = 1
        }

        let more = try await !ledger.scannedAssetPage(scanID: scanID, afterCursor: row.cursor, limit: 1).isEmpty

        return PlanBatchResult(
            nextCursor: row.cursor,
            plannedCount: planned,
            failedCount: failed,
            hasMore: more
        )
    }

    /// Bounded planning producer fulfilling PhotoLibraryAdapterProtocol requirement.
    public func planScannedBatch(
        scanID: UUID,
        afterCursor: Int64 = 0,
        limit: Int = 1,
        googleDestination: Destination? = nil,
        telegramDestination: Destination? = nil,
        googleLiveFallback: LivePhotoFallbackOption = .bothSeparately,
        videoPartThreshold: Int64 = LosslessVideoPartSplitter.defaultTargetPartSize
    ) async throws -> PlanBatchResult {
        return try await planNextAsset(
            scanID: scanID,
            afterCursor: afterCursor,
            googleDestination: googleDestination,
            telegramDestination: telegramDestination,
            googleLiveFallback: googleLiveFallback,
            videoPartThreshold: videoPartThreshold
        )
    }
}

/// Coalesces progress events to ~2 Hz with bounded asynchronous execution and error propagation.
final class SourceProgressCoalescer: Sendable {
    private struct State: Sendable {
        var lastEmittedTime: TimeInterval = 0
        var latestBytes: Int64 = 0
        var isScheduled: Bool = false
        var isTerminated: Bool = false
        var persistenceError: (any Error)?
    }

    private let stateLock = OSAllocatedUnfairLock(initialState: State())
    private let ledger: Ledger
    private let context: EventContext
    private let expectedBytes: Int64?

    init(ledger: Ledger, context: EventContext, expectedBytes: Int64? = nil) {
        self.ledger = ledger
        self.context = context
        self.expectedBytes = expectedBytes
    }

    func update(bytes: Int64) throws {
        let shouldSchedule: Bool = try stateLock.withLock { state in
            if let err = state.persistenceError {
                throw err
            }
            guard !state.isTerminated else { return false }
            state.latestBytes = bytes
            let now = ProcessInfo.processInfo.systemUptime
            if now - state.lastEmittedTime >= 0.5 && !state.isScheduled {
                state.lastEmittedTime = now
                state.isScheduled = true
                return true
            }
            return false
        }

        if shouldSchedule {
            Task { [weak self] in
                guard let self else { return }
                let bytesToSend: Int64 = self.stateLock.withLock { $0.latestBytes }
                do {
                    try await self.ledger.appendEvent(
                        .progress,
                        context: self.context,
                        decision: .proceed,
                        bytes: bytesToSend,
                        expectedBytes: self.expectedBytes
                    )
                } catch {
                    self.stateLock.withLock { state in
                        state.persistenceError = error
                    }
                }
                self.stateLock.withLock { state in
                    state.isScheduled = false
                }
            }
        }
    }

    func finish(finalBytes: Int64) async throws {
        let shouldEmit = try stateLock.withLock { state -> Bool in
            if let err = state.persistenceError {
                throw err
            }
            state.isTerminated = true
            return finalBytes > 0
        }

        if shouldEmit {
            try await ledger.appendEvent(
                .progress,
                context: context,
                decision: .proceed,
                bytes: finalBytes,
                expectedBytes: expectedBytes
            )
        }
    }
}
