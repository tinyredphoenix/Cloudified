import Foundation
@preconcurrency import Photos
import CloudifiedCore

extension AppEnvironment {
    func recipe(_ asset: AssetIdentity) async throws -> SourceRecipe? {
        guard let data = try await ledger?.sourceRecipe(assetID: asset.id) else { return nil }
        return try SourceRecipe.decode(from: data)
    }
    func performUIRefresh() async {
        logsState.fallbackEntries = fallback.snapshot().reversed().map {
            DiagnosticLogEntry(id: $0.id.uuidString, timestamp: $0.timestamp, origin: "System", severity: "error",
                stage: "Diagnostic persistence fallback (memory only)", message: explain($0.failure), safeErrorCode: $0.failure.description)
        }
        guard let engine = backupEngine, let ledger else { return }
        do {
            let snapshot = try await engine.snapshot(), durable = snapshot.ledger
            if let g = durable.providers.first(where: { $0.provider == .google }) {
                settingsState.isGoogleEnabled = g.enabled; settingsState.isGoogleConnected = g.destinationID != nil
            }
            if let t = durable.providers.first(where: { $0.provider == .telegram }) {
                settingsState.isTelegramEnabled = t.enabled; settingsState.isTelegramConnected = t.destinationID != nil
            }
            var transfers: [CurrentTransferState] = []
            for provider in Provider.allCases {
                guard let activity = snapshot.active[provider] else { continue }
                let job = try await ledger.job(activity.jobID), source = try await recipe(job.asset)
                let resource = job.plan.resources.first { $0.id == activity.resourceID }
                transfers.append(CurrentTransferState(id: job.id.uuidString, activity: activity.phase.rawValue.capitalized,
                    filename: resource.flatMap { r in source?.resources.first(where: { $0.sha256 == r.originals.first?.sha256 })?.originalFilename } ?? source?.resources.first?.originalFilename ?? "Media \(job.asset.id.uuidString.prefix(8)) (name unavailable)",
                    mediaType: job.asset.kind == .photo ? "Photo" : "Video", provider: provider.displayName,
                    bytesSent: activity.bytes ?? 0, totalBytes: activity.expectedBytes,
                    componentOrPart: resource.map(componentLabel), attemptNumber: activity.attempt > 0 ? activity.attempt : nil))
            }
            // Native sends may still own inputs after a worker timeout. Merge on
            // job identity; never fabricate attempt 1 or label an acknowledgement Saved.
            let nativeWork = await telegramAdapter?.nativeTransferSnapshot() ?? []
            for native in nativeWork {
                guard !transfers.contains(where: { $0.id == native.jobID.uuidString }) else { continue }
                let job = try await ledger.job(native.jobID), source = try await recipe(job.asset)
                let resource = job.plan.resources.first { $0.tag == native.resourceTag }
                let activity: String
                switch native.activity {
                case .uploading: activity = "Native upload in progress"
                case .awaitingAcknowledgement: activity = "Awaiting Telegram acknowledgement"
                case .waitingForConnection: activity = "Native send waiting for connection"
                case .uncertain: activity = "Native outcome unknown; recovery required"
                }
                transfers.append(CurrentTransferState(id: native.transferID.uuidString, activity: activity,
                    filename: source?.resources.first?.originalFilename ?? "Original media (name unavailable)",
                    mediaType: job.asset.kind == .photo ? "Photo" : "Video", provider: "Telegram",
                    bytesSent: native.uploadedBytes, totalBytes: native.expectedBytes,
                    componentOrPart: resource.map(componentLabel), attemptNumber: job.attempts > 0 ? job.attempts : nil))
            }
            dashboardState.canPause = backupRequested && !pausedByUser
            dashboardState.canResume = !backupRequested && durable.scanned
            dashboardState.controlsAvailable = bootstrapComplete && commandProvider == nil && !controlTransition
            dashboardState.currentTransfers = transfers
            dashboardState.accessibleLibraryTotal = durable.libraryTotal
            dashboardState.scanTimestamp = durable.scanStartedAt; dashboardState.savedToBothCount = durable.savedToBoth
            let auth = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            dashboardState.permissionScopeDescription = auth == .limited ? "Selected Photos only" : (auth == .authorized ? "Full Photos access" : "Photos access required")
            for provider in Provider.allCases {
                guard let value = durable.providers.first(where: { $0.provider == provider }) else { continue }
                let error = value.blockedReason ?? snapshot.laneFailures[provider] ?? providerErrors[provider]
                let activity: String
                if value.destinationID == nil { activity = "Not connected" }
                else if !value.enabled { activity = "Disabled — backlog retained" }
                else if let error { activity = explain(error) }
                else if !value.recoveryComplete { activity = "Checking existing remote content before uploads" }
                else if snapshot.paused { activity = "Paused" }
                else if let gate = snapshot.systemGate { activity = explain(SafeFailure(.connectivity, domain: .core, cause: gate)) }
                else if let active = transfers.first(where: { $0.provider == provider.displayName }) { activity = active.activity }
                else if planningProvider == provider { activity = "Preparing next original" }
                else if let date = value.resumeAt { activity = "Waiting until \(date.formatted())" }
                else { activity = backupRequested ? "Ready / checking remaining work" : "Idle" }
                let card = ProviderCardState(name: provider.displayName, isEnabled: value.enabled,
                    isConnected: value.destinationID != nil,
                    accountIdentifier: provider == .google ? settingsState.googleAccountEmail : settingsState.telegramAccountName,
                    channelIdentifier: provider == .telegram ? settingsState.telegramChannelName : nil,
                    currentActivity: activity, savedCount: value.confirmed, remainingCount: value.remaining,
                    totalCount: value.total, waitingCount: value.photos.flatMap { p in value.videos.map { p.waiting + $0.waiting } }, failedCount: value.photos.flatMap { p in value.videos.map { p.failed + $0.failed } },
                    lastConfirmedDate: value.lastConfirmedAt)
                if provider == .google { dashboardState.googleStatus = card } else { dashboardState.telegramStatus = card }
            }
            let g = durable.providers.first { $0.provider == .google }, t = durable.providers.first { $0.provider == .telegram }
            dashboardState.photosSection = mediaSection("Photos", kind: .photo, google: g?.photos, telegram: t?.photos, transfers: transfers)
            dashboardState.videosSection = mediaSection("Videos", kind: .video, google: g?.videos, telegram: t?.videos, transfers: transfers)
            if isScanning { dashboardState.overallState = .scanning }
            else if snapshot.paused || pausedByUser { dashboardState.overallState = .paused }
            else if let cause = snapshot.systemGate { dashboardState.overallState = .waiting(reason: explain(SafeFailure(.connectivity, domain: .core, cause: cause))) }
            else if snapshot.active.values.contains(where: { $0.phase == .uploading }) || nativeWork.contains(where: { $0.activity == .uploading }) { dashboardState.overallState = .uploading }
            else if snapshot.active.values.contains(where: { $0.phase == .finalizing }) { dashboardState.overallState = .finalizing }
            else if snapshot.active.values.contains(where: { $0.phase == .preparing }) { dashboardState.overallState = .preparing }
            else if snapshot.active.values.contains(where: { $0.phase == .checking }) { dashboardState.overallState = .checking }
            else if !nativeWork.isEmpty { dashboardState.overallState = .waiting(reason: "Awaiting native send outcome") }
            else if let systemError { dashboardState.overallState = .needsAttention(reason: explain(systemError)) }
            else if planningProvider != nil { dashboardState.overallState = .preparing }
            else if !durable.scanned { dashboardState.overallState = .notScanned }
            else if durable.providers.contains(where: { $0.enabled && ($0.blockedReason != nil || !$0.recoveryComplete) }) { dashboardState.overallState = .checking }
            else if durable.providers.contains(where: { $0.enabled }) && durable.providers.filter({ $0.enabled }).allSatisfy({ $0.remaining == 0 }) { dashboardState.overallState = .complete }
            else { dashboardState.overallState = .idle }
            dashboardState.waitingOrErrorReason = systemError.map { explain($0) + " " + continuation.summary } ?? continuation.summary
            continuation.update(confirmed: durable.providers.compactMap(\.confirmed).reduce(0, +),
                total: durable.scanned ? durable.providers.compactMap(\.total).reduce(0, +) : nil,
                subtitle: dashboardState.overallState.title)
            if selectedTab == .logs && logCursor == nil && !logsState.isLoading { loadLogPage(generation: logQueryGeneration) }
            if selectedTab == .notUploaded && failureCursor == nil && sourceFailureCursor == nil && !notUploadedState.isLoading {
                loadFailurePage(generation: failureQueryGeneration, older: false)
            }
        } catch {
            let safe = ProviderSupport.safe(error, domain: .sqlite)
            // Avoid a feedback loop through ledger observation or fallback events.
            dashboardState.overallState = .needsAttention(reason: explain(safe))
            dashboardState.waitingOrErrorReason = safe.description
        }
    }
    func componentLabel(_ resource: ResourceRequirement) -> String {
        if let original = resource.originals.first, let index = original.partIndex, let count = original.partCount {
            return "\(resource.role.rawValue.capitalized) part \(index + 1) of \(count)"
        }
        return resource.role == .manifest ? "Archive manifest" : resource.role.rawValue.capitalized
    }
    func mediaSection(_ title: String, kind: MediaKind, google: MediaCounts?, telegram: MediaCounts?, transfers: [CurrentTransferState]) -> MediaSectionState {
        let active = transfers.filter { $0.mediaType == (kind == .photo ? "Photo" : "Video") }
        return MediaSectionState(title: title, subtitle: kind == .photo ? "Live Photo components remain one photo obligation" : "Original video bytes; no conversion",
            totalCount: google?.total ?? telegram?.total, googleSaved: google?.confirmed, googleRemaining: google?.remaining,
            googleFailed: google?.failed, telegramSaved: telegram?.confirmed, telegramRemaining: telegram?.remaining,
            telegramFailed: telegram?.failed, activeOperation: active.isEmpty ? nil : active.map { "\($0.provider): \($0.activity)" }.joined(separator: " · "),
            byteProgress: active.isEmpty ? nil : active.map { "\($0.provider): \($0.byteProgressText)" }.joined(separator: " · "))
    }
}
extension Provider { var displayName: String { self == .google ? "Google Photos" : "Telegram" } }
