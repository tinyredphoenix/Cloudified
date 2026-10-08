import SwiftUI
import Combine
import CloudifiedCore
import Photos
import os

/// Presentation coordinator and environment for the Cloudified application.
/// Composition root integrating StorageLayout, Ledger, FileLeaseStore, PhotoLibraryPipeline,
/// and BackupEngine with real Google Photos and Telegram provider adapters.
@MainActor
public final class AppEnvironment: ObservableObject {
    @Published public var selectedTab: AppTab = .dashboard
    @Published public var dashboardState: DashboardViewState
    @Published public var notUploadedState: NotUploadedViewState
    @Published public var logsState: LogsViewState
    @Published public var settingsState: SettingsViewState

    // Core Composition
    public let storageLayout: StorageLayout?
    public let ledger: Ledger?
    public let fileLeaseStore: FileLeaseStore?
    public let photoPipeline: PhotoLibraryPipeline?
    public let backupEngine: BackupEngine?

    // Security & Adapters
    let credentialStore: KeychainCredentialStore
    let googleSession: GooglePhotosClientSession?
    let googleAdapter: GooglePhotosProviderAdapter?
    let tdlibClient: TDLibClient?
    let telegramAdapter: TelegramProviderAdapter?

    // Background & Invalidation Tasks
    private var ledgerObserverTask: Task<Void, Never>?
    private var telegramStatusTask: Task<Void, Never>?
    private var telegramRecoveryTask: Task<Void, Never>?
    private var backupExecutionTask: Task<Void, Never>?
    private var refreshThrottlerTask: Task<Void, Never>?
    private var pendingRefresh = false

    // Coordinator State
    private var planningCursor: Int64 = 0
    private var isScanning = false
    private var isPlanning = false
    private var activeScanID: UUID?
    private var googleRecovered = false
    private var telegramRecovered = false
    private var startupInventoryCompleted = false
    private var inMemoryDiagnosticFailures: [String] = []

    public init(
        dashboardState: DashboardViewState = DashboardViewState(),
        notUploadedState: NotUploadedViewState = NotUploadedViewState(),
        logsState: LogsViewState = LogsViewState(),
        settingsState: SettingsViewState = SettingsViewState()
    ) {
        self.dashboardState = dashboardState
        self.notUploadedState = notUploadedState
        self.logsState = logsState
        self.settingsState = settingsState

        let keychain = KeychainCredentialStore()
        self.credentialStore = keychain

        // Restore non-secret persistent settings
        if let savedPolicyRaw = UserDefaults.standard.string(forKey: "CloudifiedLivePhotoFallback"),
           let savedPolicy = LivePhotoFallbackOption(rawValue: savedPolicyRaw) {
            self.settingsState.livePhotoFallback = savedPolicy
        }
        if UserDefaults.standard.object(forKey: "CloudifiedWiFiOnly") != nil {
            self.settingsState.isWiFiOnlyEnabled = UserDefaults.standard.bool(forKey: "CloudifiedWiFiOnly")
        }

        // Initialize core composition and adapters
        var layoutInit: StorageLayout? = nil
        var ledgerInit: Ledger? = nil
        var fileStoreInit: FileLeaseStore? = nil
        var pipelineInit: PhotoLibraryPipeline? = nil
        var engineInit: BackupEngine? = nil
        var gSessionInit: GooglePhotosClientSession? = nil
        var gAdapterInit: GooglePhotosProviderAdapter? = nil
        var tClientInit: TDLibClient? = nil
        var tAdapterInit: TelegramProviderAdapter? = nil

        do {
            let layout = try StorageLayout()
            layoutInit = layout

            let led = try Ledger(
                databaseURL: layout.databaseURL,
                version: "1.0.0",
                revision: "2fba9b7539567df3ca297b6af1421d07440bd738"
            )
            ledgerInit = led

            let files = FileLeaseStore(root: layout.stagingURL, ledger: led)
            fileStoreInit = files

            let pipeline = PhotoLibraryPipeline(ledger: led, fileStore: files, storageLayout: layout)
            pipelineInit = pipeline

            let engine = BackupEngine(ledger: led, files: files)
            engineInit = engine

            // Diagnostic sink injecting durable ledger writes into client sessions
            let sink: @Sendable (EventOperation, EventContext, EventDecision, EventSeverity, SafeFailure?, TimeInterval?, Int64?, Int64?) async throws -> Void = { operation, context, decision, severity, failure, duration, bytes, expectedBytes in
                do {
                    try await led.appendEvent(
                        operation,
                        context: context,
                        decision: decision,
                        severity: severity,
                        failure: failure,
                        duration: duration,
                        bytes: bytes,
                        expectedBytes: expectedBytes
                    )
                } catch {
                    os_log(.fault, "Diagnostic persistence failed: %{public}@", error.localizedDescription)
                    Task { @MainActor in
                        // Record in memory safely so persistence failures are visible
                        print("CRITICAL: Diagnostic event persistence failed: \(error.localizedDescription)")
                    }
                    throw error
                }
            }

            let gSession = try GooglePhotosClientSession(profileID: "primary", credentialStore: keychain, diagnosticSink: sink)
            gSessionInit = gSession
            gAdapterInit = GooglePhotosProviderAdapter(session: gSession, ledger: led, files: files)

            let tClient = try TDLibClient(profileID: "primary", credentialStore: keychain, diagnosticSink: sink)
            tClientInit = tClient
            tAdapterInit = TelegramProviderAdapter(client: tClient, ledger: led, files: files)
        } catch {
            os_log(.fault, "Core initialization failed: %{public}@", error.localizedDescription)
            self.dashboardState.waitingOrErrorReason = "Initialization failed: \(error.localizedDescription)"
            self.dashboardState.overallState = .needsAttention(reason: "Storage layout error")
        }

        self.storageLayout = layoutInit
        self.ledger = ledgerInit
        self.fileLeaseStore = fileStoreInit
        self.photoPipeline = pipelineInit
        self.backupEngine = engineInit
        self.googleSession = gSessionInit
        self.googleAdapter = gAdapterInit
        self.tdlibClient = tClientInit
        self.telegramAdapter = tAdapterInit

        // Kick off startup bootstrap
        Task { [weak self] in
            await self?.bootstrap()
        }
    }

    deinit {
        ledgerObserverTask?.cancel()
        telegramStatusTask?.cancel()
        telegramRecoveryTask?.cancel()
        backupExecutionTask?.cancel()
        refreshThrottlerTask?.cancel()
    }

    // MARK: - Startup & Bootstrap

    private func bootstrap() async {
        startSubscriptions()
        await runStartupRecovery()
    }

    /// Independent provider recovery and gated startup file lease inventory.
    private func runStartupRecovery() async {
        guard let ledger = ledger, let files = fileLeaseStore else { return }

        // 1. Google Recovery
        if let gSession = googleSession, let gAdapter = googleAdapter {
            if (try? credentialStore.loadGoogleCredential(forProfile: "primary")) != nil {
                do {
                    try await gSession.loadSavedSession()
                    if let dest = try await ledger.selectedDestination(.google) {
                        try await gAdapter.recover(dest)
                        googleRecovered = true
                    } else {
                        googleRecovered = true
                    }
                } catch {
                    let safe = (error as? SafeFailure) ?? SafeFailure(.reconciliation, domain: .google, cause: .unknown)
                    os_log(.error, "Google startup recovery failed: %{public}@", safe.description)
                    recordDiagnosticFailure("Google recovery failed: \(safe.description)")
                    googleRecovered = false
                }
            } else {
                googleRecovered = true
            }
        } else {
            googleRecovered = true
        }

        // 2. Telegram Recovery
        if let tClient = tdlibClient, let tAdapter = telegramAdapter {
            if (try? credentialStore.loadTelegramCredential(forProfile: "primary")) != nil {
                do {
                    try await tClient.start()
                    if let dest = try await ledger.selectedDestination(.telegram) {
                        try await tAdapter.recover(dest)
                        telegramRecovered = true
                    } else {
                        telegramRecovered = true
                    }
                } catch {
                    let safe = (error as? SafeFailure) ?? SafeFailure(.reconciliation, domain: .tdlib, cause: .unknown)
                    os_log(.error, "Telegram startup recovery failed: %{public}@", safe.description)
                    recordDiagnosticFailure("Telegram recovery failed: \(safe.description)")
                    telegramRecovered = false
                }
            } else {
                telegramRecovered = true
            }
        } else {
            telegramRecovered = true
        }

        // 3. Gated startup file inventory: completed ONLY after BOTH providers reconcile
        if googleRecovered && telegramRecovered {
            files.completeStartupInventory()
            startupInventoryCompleted = true
        } else {
            startupInventoryCompleted = false
            os_log(.fault, "Startup inventory gated: recovery failed for one or more providers.")
        }

        // 4. Populate initial settings state from stored configuration
        await updateSettingsFromStored()

        // 5. Initial UI refresh
        scheduleThrottledRefresh()
    }

    private func updateSettingsFromStored() async {
        guard let ledger = ledger else { return }
        do {
            if let gDest = try await ledger.selectedDestination(.google) {
                settingsState.isGoogleConnected = true
                settingsState.isGoogleEnabled = gDest.enabled
                if let cred = try? credentialStore.loadGoogleCredential(forProfile: "primary") {
                    settingsState.googleAccountEmail = cred.email
                }
            } else {
                settingsState.isGoogleConnected = false
                settingsState.googleAccountEmail = nil
            }

            if let tDest = try await ledger.selectedDestination(.telegram) {
                settingsState.isTelegramConnected = true
                settingsState.isTelegramEnabled = tDest.enabled
                if let client = tdlibClient {
                    let auth = await client.authorizationState
                    updateTelegramAuthStep(from: auth)
                    if auth == .ready {
                        if let me = try? await client.getMe() {
                            let firstName = me["first_name"]?.stringValue ?? ""
                            let lastName = me["last_name"]?.stringValue ?? ""
                            let username = me["username"]?.stringValue
                            let displayName = username.map { "@\($0)" } ?? "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                            settingsState.telegramAccountName = displayName.isEmpty ? "Telegram User" : displayName
                        }
                    }
                }
            } else {
                settingsState.isTelegramConnected = false
                settingsState.telegramAccountName = nil
                settingsState.telegramChannelName = nil
                if let client = tdlibClient {
                    let auth = await client.authorizationState
                    updateTelegramAuthStep(from: auth)
                }
            }
        } catch {
            os_log(.error, "Failed loading stored settings: %{public}@", error.localizedDescription)
        }
    }

    private func updateTelegramAuthStep(from state: TDLibAuthorizationState) {
        switch state {
        case .uninitialized:
            settingsState.telegramAuthStep = (try? credentialStore.loadTelegramCredential(forProfile: "primary")) != nil ? .readyForChannel : .unconfigured
        case .waitTdlibParameters:
            settingsState.telegramAuthStep = .unconfigured
        case .waitPhoneNumber:
            settingsState.telegramAuthStep = .enterPhoneNumber
        case .waitCode:
            settingsState.telegramAuthStep = .enterCode
        case .waitPassword:
            settingsState.telegramAuthStep = .enterPassword
        case .waitEmailAddress:
            settingsState.telegramAuthStep = .enterEmail
        case .waitEmailCode:
            settingsState.telegramAuthStep = .enterEmailCode
        case .waitOtherDeviceConfirmation:
            settingsState.telegramAuthStep = .otherDeviceConfirmation
        case .waitRegistration:
            settingsState.telegramAuthStep = .registration
        case .waitPremiumPurchase:
            settingsState.telegramAuthStep = .premiumPurchase
        case .ready:
            settingsState.telegramAuthStep = settingsState.isTelegramConnected ? .connected : .readyForChannel
        case .loggingOut, .closing:
            settingsState.telegramAuthStep = .closing
        case .closed:
            settingsState.telegramAuthStep = .closed
        case .uncertain:
            settingsState.telegramAuthStep = .error
        }
    }

    // MARK: - Subscription Streams & Invalidation

    private func startSubscriptions() {
        guard let ledger = ledger, let tAdapter = telegramAdapter else { return }

        // Single subscription to Ledger changes
        ledgerObserverTask = Task { [weak self] in
            do {
                let stream = try await ledger.observeChanges()
                for await _ in stream {
                    guard let self else { break }
                    await self.scheduleThrottledRefresh()
                }
            } catch {
                os_log(.error, "Ledger change stream failed: %{public}@", error.localizedDescription)
            }
        }

        // Single subscription to Telegram status events (UI invalidation only, NOT backup trigger)
        telegramStatusTask = Task { [weak self] in
            guard let self else { return }
            for await _ in tAdapter.statusEvents {
                await self.scheduleThrottledRefresh()
            }
        }

        // Single subscription to Telegram recovery events (coordinator wakeups)
        telegramRecoveryTask = Task { [weak self] in
            guard let self else { return }
            for await _ in tAdapter.recoveryEvents {
                await self.handleTelegramRecoverySignal()
            }
        }
    }

    private func handleTelegramRecoverySignal() async {
        guard let ledger = ledger else { return }
        if let dest = try? await ledger.selectedDestination(.telegram) {
            try? await ledger.wakeWaiting(destinationID: dest.id)
            scheduleThrottledRefresh()
        }
    }

    /// Throttles UI refresh updates to <= 2 Hz (minimum 500ms interval).
    public func scheduleThrottledRefresh() {
        pendingRefresh = true
        guard refreshThrottlerTask == nil else { return }

        refreshThrottlerTask = Task { [weak self] in
            while let self = self, self.pendingRefresh {
                self.pendingRefresh = false
                await self.performUIRefresh()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            self?.refreshThrottlerTask = nil
        }
    }

    // MARK: - Dashboard UI State Assembly

    private func performUIRefresh() async {
        guard let engine = backupEngine, let ledger = ledger else { return }

        let snapshot = try? await engine.snapshot()
        let nativeTransfers = (await telegramAdapter?.nativeTransferSnapshot()) ?? []

        // Photos permission scope
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch authStatus {
        case .authorized:
            dashboardState.permissionScopeDescription = "Full photo library access"
        case .limited:
            dashboardState.permissionScopeDescription = "Selected/access granted photos only"
        case .denied, .restricted:
            dashboardState.permissionScopeDescription = "Photo library access denied"
        case .notDetermined:
            dashboardState.permissionScopeDescription = "Not determined"
        @unknown default:
            dashboardState.permissionScopeDescription = "Not determined"
        }

        if let snap = snapshot {
            dashboardState.accessibleLibraryTotal = snap.ledger.libraryTotal
            dashboardState.savedToBothCount = snap.ledger.savedToBoth
            dashboardState.scanTimestamp = snap.ledger.scanStartedAt

            // 1. Google Status
            let googleSnap = snap.ledger.providers.first(where: { $0.provider == .google })
            var gCard = ProviderCardState(name: "Google Photos")
            gCard.isEnabled = googleSnap?.enabled ?? false
            gCard.isConnected = googleSnap?.destinationID != nil
            gCard.accountIdentifier = settingsState.googleAccountEmail
            gCard.savedCount = googleSnap?.confirmed
            gCard.remainingCount = googleSnap?.remaining
            gCard.totalCount = googleSnap?.total
            gCard.failedCount = (googleSnap?.photos?.failed ?? 0) + (googleSnap?.videos?.failed ?? 0)
            gCard.lastConfirmedDate = googleSnap?.lastConfirmedAt

            if let act = snap.active[.google] {
                gCard.currentActivity = "Google: \(act.phase.rawValue.capitalized)"
            } else if let blocked = googleSnap?.blockedReason {
                gCard.currentActivity = "Waiting: \(mapSafeFailureCause(blocked))"
            } else if !(googleSnap?.enabled ?? true) {
                gCard.currentActivity = "Disabled"
            } else if googleSnap?.destinationID == nil {
                gCard.currentActivity = "Not connected"
            } else {
                gCard.currentActivity = "Idle"
            }
            dashboardState.googleStatus = gCard

            // 2. Telegram Status (merges native ongoing transfer bytes by job/mapping)
            let telegramSnap = snap.ledger.providers.first(where: { $0.provider == .telegram })
            var tCard = ProviderCardState(name: "Telegram")
            tCard.isEnabled = telegramSnap?.enabled ?? false
            tCard.isConnected = telegramSnap?.destinationID != nil
            tCard.accountIdentifier = settingsState.telegramAccountName
            tCard.channelIdentifier = settingsState.telegramChannelName
            tCard.savedCount = telegramSnap?.confirmed
            tCard.remainingCount = telegramSnap?.remaining
            tCard.totalCount = telegramSnap?.total
            tCard.failedCount = (telegramSnap?.photos?.failed ?? 0) + (telegramSnap?.videos?.failed ?? 0)
            tCard.lastConfirmedDate = telegramSnap?.lastConfirmedAt

            if let native = nativeTransfers.first {
                let sent = ByteCountFormatter.string(fromByteCount: native.uploadedBytes, countStyle: .file)
                let total = ByteCountFormatter.string(fromByteCount: native.expectedBytes, countStyle: .file)
                tCard.currentActivity = "Native: \(sent) of \(total)"
            } else if let act = snap.active[.telegram] {
                tCard.currentActivity = "Telegram: \(act.phase.rawValue.capitalized)"
            } else if let blocked = telegramSnap?.blockedReason {
                tCard.currentActivity = "Waiting: \(mapSafeFailureCause(blocked))"
            } else if !(telegramSnap?.enabled ?? true) {
                tCard.currentActivity = "Disabled"
            } else if telegramSnap?.destinationID == nil {
                tCard.currentActivity = "Not connected"
            } else {
                tCard.currentActivity = "Idle"
            }
            dashboardState.telegramStatus = tCard

            // 3. Media breakdown (Photos & Videos)
            var pSec = MediaSectionState(
                title: "Photos",
                subtitle: "Live Photos are included; motion does not inflate video count"
            )
            pSec.totalCount = googleSnap?.photos?.total ?? telegramSnap?.photos?.total
            pSec.googleSaved = googleSnap?.photos?.confirmed
            pSec.googleRemaining = googleSnap?.photos?.remaining
            pSec.googleFailed = googleSnap?.photos?.failed
            pSec.telegramSaved = telegramSnap?.photos?.confirmed
            pSec.telegramRemaining = telegramSnap?.photos?.remaining
            pSec.telegramFailed = telegramSnap?.photos?.failed
            dashboardState.photosSection = pSec

            var vSec = MediaSectionState(
                title: "Videos",
                subtitle: "Full original quality; independent concurrent queue"
            )
            vSec.totalCount = googleSnap?.videos?.total ?? telegramSnap?.videos?.total
            vSec.googleSaved = googleSnap?.videos?.confirmed
            vSec.googleRemaining = googleSnap?.videos?.remaining
            vSec.googleFailed = googleSnap?.videos?.failed
            vSec.telegramSaved = telegramSnap?.videos?.confirmed
            vSec.telegramRemaining = telegramSnap?.videos?.remaining
            vSec.telegramFailed = telegramSnap?.videos?.failed
            dashboardState.videosSection = vSec

            // 4. Current Transfer (merges Core LaneActivity with native Telegram transfers)
            if let act = snap.active[.google] {
                dashboardState.currentTransfer = CurrentTransferState(
                    filename: "Preparing Google asset",
                    mediaType: "Original",
                    provider: "Google Photos",
                    bytesSent: act.bytes ?? 0,
                    totalBytes: act.expectedBytes,
                    componentOrPart: act.phase.rawValue.capitalized,
                    attemptNumber: act.attempt,
                    maxAttempts: 3
                )
            } else if let act = snap.active[.telegram] {
                dashboardState.currentTransfer = CurrentTransferState(
                    filename: "Preparing Telegram asset",
                    mediaType: "Original",
                    provider: "Telegram",
                    bytesSent: act.bytes ?? 0,
                    totalBytes: act.expectedBytes,
                    componentOrPart: act.phase.rawValue.capitalized,
                    attemptNumber: act.attempt,
                    maxAttempts: 3
                )
            } else if let native = nativeTransfers.first {
                dashboardState.currentTransfer = CurrentTransferState(
                    filename: "Telegram native transfer",
                    mediaType: "Original",
                    provider: "Telegram",
                    bytesSent: native.uploadedBytes,
                    totalBytes: native.expectedBytes,
                    componentOrPart: "\(native.activity)",
                    attemptNumber: 1,
                    maxAttempts: 3
                )
            } else {
                dashboardState.currentTransfer = nil
            }

            // 5. Overall Activity State
            if snap.paused {
                dashboardState.overallState = .paused
            } else if let gate = snap.systemGate {
                dashboardState.overallState = .waiting(reason: "System gate: \(gate.rawValue)")
            } else if isScanning {
                dashboardState.overallState = .scanning
            } else if isPlanning {
                dashboardState.overallState = .preparing
            } else if snap.active[.google] != nil || snap.active[.telegram] != nil || !nativeTransfers.isEmpty {
                dashboardState.overallState = .uploading
            } else if !snap.ledger.scanned {
                dashboardState.overallState = .notScanned
            } else if let failure = snap.laneFailures.values.first {
                dashboardState.overallState = .needsAttention(reason: mapSafeFailureCause(failure))
            } else {
                let gDone = googleSnap != nil && (googleSnap?.enabled == true ? (googleSnap?.remaining ?? 0) == 0 : true)
                let tDone = telegramSnap != nil && (telegramSnap?.enabled == true ? (telegramSnap?.remaining ?? 0) == 0 : true)
                if (snap.ledger.libraryTotal ?? 0) > 0 && gDone && tDone {
                    dashboardState.overallState = .complete
                } else {
                    dashboardState.overallState = .idle
                }
            }
        }

        // 6. Refresh Not Uploaded page
        let failures = (try? await ledger.failurePage(limit: 50)) ?? []
        let sourceFailures = (try? await ledger.sourceFailurePage(limit: 50)) ?? []
        notUploadedState.items = mapFailuresToItems(failures: failures, sourceFailures: sourceFailures)

        // 7. Refresh Logs page
        let origin: EventOrigin?
        switch logsState.originFilter {
        case .all: origin = nil
        case .google: origin = .google
        case .telegram: origin = .telegram
        case .system: origin = .system
        }

        let severity: EventSeverity?
        switch logsState.severityFilter {
        case .all: severity = nil
        case .info: severity = .info
        case .warning: severity = .warning
        case .error: severity = .error
        }

        if let page = try? await ledger.logPage(origin: origin, severity: severity, limit: 100) {
            logsState.entries = page.events.map { mapDiagnosticEvent($0) }
        }
    }

    // MARK: - Backup & Engine Controls

    public func requestBackup() {
        guard let engine = backupEngine, let pipeline = photoPipeline, let ledger = ledger else {
            dashboardState.waitingOrErrorReason = "Engine not initialized."
            dashboardState.overallState = .needsAttention(reason: "Storage layout unavailable")
            return
        }

        guard dashboardState.canStartBackup else {
            dashboardState.waitingOrErrorReason = "Connect Google Photos or Telegram in Settings to start."
            dashboardState.overallState = .needsAttention(reason: "No destinations connected")
            return
        }

        if backupExecutionTask != nil {
            return
        }

        backupExecutionTask = Task { [weak self] in
            guard let self else { return }
            defer { self.backupExecutionTask = nil }

            do {
                // 1. Verify photo library authorization
                let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                guard status == .authorized || status == .limited else {
                    self.dashboardState.overallState = .needsAttention(reason: "Photo library permission denied")
                    return
                }

                // 2. Discover/Scan library if not yet completed
                let snap = try await engine.snapshot()
                var currentScanID: UUID
                if !snap.ledger.scanned {
                    self.isScanning = true
                    self.dashboardState.overallState = .scanning
                    let (scannedID, _) = try await pipeline.scanLibrary()
                    currentScanID = scannedID
                    self.activeScanID = scannedID
                    self.isScanning = false
                    self.scheduleThrottledRefresh()
                } else {
                    currentScanID = self.activeScanID ?? UUID()
                }

                // 3. Collect enabled adapters (both run concurrently in ONE runReadyBatch)
                let googleDest = try await ledger.selectedDestination(.google)
                let telegramDest = try await ledger.selectedDestination(.telegram)

                var activeAdapters: [any ProviderAdapter] = []
                if let gAdapter = self.googleAdapter, let gDest = googleDest, try await ledger.canRun(gDest.id) {
                    activeAdapters.append(gAdapter)
                }
                if let tAdapter = self.telegramAdapter, let tDest = telegramDest, try await ledger.canRun(tDest.id) {
                    activeAdapters.append(tAdapter)
                }

                guard !activeAdapters.isEmpty else {
                    self.dashboardState.waitingOrErrorReason = "No enabled destinations ready to upload."
                    return
                }

                // 4. Bounded producer loop: one-asset source planning interleaved with ready transfers
                var hasMore = true
                while hasMore && !Task.isCancelled {
                    let currentSnap = try await engine.snapshot()
                    if currentSnap.paused || currentSnap.systemGate != nil { break }

                    self.isPlanning = true
                    let planResult = try await pipeline.planNextAsset(
                        scanID: currentScanID,
                        afterCursor: self.planningCursor,
                        googleDestination: googleDest,
                        telegramDestination: telegramDest,
                        googleLiveFallback: self.settingsState.livePhotoFallback
                    )
                    self.planningCursor = planResult.nextCursor
                    hasMore = planResult.hasMore
                    self.isPlanning = false

                    // Both adapters execute concurrently inside one runReadyBatch
                    let results = try await engine.runReadyBatch(
                        adapters: activeAdapters,
                        preparer: pipeline.originalPreparer
                    )

                    if !hasMore {
                        let latestSnap = try await engine.snapshot()
                        let gRem = latestSnap.ledger.providers.first(where: { $0.provider == .google })?.remaining ?? 0
                        let tRem = latestSnap.ledger.providers.first(where: { $0.provider == .telegram })?.remaining ?? 0
                        if (googleDest != nil ? gRem == 0 : true) && (telegramDest != nil ? tRem == 0 : true) {
                            break
                        }
                    }

                    if results.contains(where: { $0.failure != nil }) {
                        break
                    }
                }

                self.scheduleThrottledRefresh()
            } catch {
                if !(error is CancellationError) {
                    os_log(.error, "Backup error: %{public}@", error.localizedDescription)
                    self.dashboardState.overallState = .needsAttention(reason: error.localizedDescription)
                }
            }
        }
    }

    public func requestPause() {
        Task { [weak self] in
            guard let self, let engine = self.backupEngine else { return }
            do {
                try await engine.pause()
                self.backupExecutionTask?.cancel()
                self.backupExecutionTask = nil
                self.dashboardState.overallState = .paused
                self.scheduleThrottledRefresh()
            } catch {
                os_log(.error, "Pause error: %{public}@", error.localizedDescription)
            }
        }
    }

    public func requestResume() {
        Task { [weak self] in
            guard let self, let engine = self.backupEngine else { return }
            do {
                try await engine.resume()
                self.dashboardState.overallState = .idle
                self.scheduleThrottledRefresh()
                self.requestBackup()
            } catch {
                os_log(.error, "Resume error: %{public}@", error.localizedDescription)
            }
        }
    }

    public func retryItem(_ item: NotUploadedItem) {
        Task { [weak self] in
            guard let self, let ledger = self.ledger else { return }
            do {
                if let jobID = item.jobID {
                    try await ledger.explicitRetry(jobID: jobID)
                    let job = try await ledger.job(jobID)
                    try await ledger.wakeWaiting(destinationID: job.destination.id)
                }
                self.scheduleThrottledRefresh()
                if self.dashboardState.canStartBackup {
                    self.requestBackup()
                }
            } catch {
                os_log(.error, "Explicit retry error: %{public}@", error.localizedDescription)
            }
        }
    }

    // MARK: - Destination Settings & Linking

    public func setGoogleEnabled(_ enabled: Bool) {
        settingsState.isGoogleEnabled = enabled
        Task { [weak self] in
            guard let self, let ledger = self.ledger, let engine = self.backupEngine else { return }
            if let dest = try await ledger.selectedDestination(.google) {
                try await engine.setEnabled(destinationID: dest.id, enabled: enabled)
                self.scheduleThrottledRefresh()
            }
        }
    }

    public func setTelegramEnabled(_ enabled: Bool) {
        settingsState.isTelegramEnabled = enabled
        Task { [weak self] in
            guard let self, let ledger = self.ledger, let engine = self.backupEngine else { return }
            if let dest = try await ledger.selectedDestination(.telegram) {
                try await engine.setEnabled(destinationID: dest.id, enabled: enabled)
                self.scheduleThrottledRefresh()
            }
        }
    }

    public func setWiFiOnly(_ enabled: Bool) {
        settingsState.isWiFiOnlyEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "CloudifiedWiFiOnly")
        Task { [weak self] in
            guard let self, let engine = self.backupEngine else { return }
            // P6 system gate hook: cleared when allowed network is available
            try? await engine.setSystemGate(nil)
            self.scheduleThrottledRefresh()
        }
    }

    /// Updates Live Photo policy: settles provider, invalidates current coverage, resets cursor, replans.
    public func updateLivePhotoPolicy(_ option: LivePhotoFallbackOption) {
        Task { [weak self] in
            guard let self, let engine = self.backupEngine, let ledger = self.ledger else { return }
            settingsState.isSettlingGoogle = true
            defer { settingsState.isSettlingGoogle = false }

            do {
                _ = await engine.settleProvider(.google)

                if let dest = try await ledger.selectedDestination(.google) {
                    let wasEnabled = try await ledger.canRun(dest.id)
                    try await ledger.setEnabled(dest.id, false)
                    try await ledger.invalidateCurrentCoverage(destinationID: dest.id)
                    UserDefaults.standard.set(option.rawValue, forKey: "CloudifiedLivePhotoFallback")
                    self.settingsState.livePhotoFallback = option
                    self.planningCursor = 0
                    if wasEnabled {
                        try await ledger.setEnabled(dest.id, true)
                    }
                } else {
                    UserDefaults.standard.set(option.rawValue, forKey: "CloudifiedLivePhotoFallback")
                    self.settingsState.livePhotoFallback = option
                    self.planningCursor = 0
                }
                self.scheduleThrottledRefresh()
            } catch {
                os_log(.error, "Live photo coverage update error: %{public}@", error.localizedDescription)
            }
        }
    }

    public func connectGoogle(oauthToken: String) async throws {
        guard let session = googleSession, let adapter = googleAdapter, let ledger = ledger else {
            throw SafeFailure(.sourceUnavailable, domain: .google, cause: .unknown)
        }
        settingsState.isConnectingGoogle = true
        settingsState.googleAuthErrorMessage = nil
        defer { settingsState.isConnectingGoogle = false }

        do {
            let cred = try await session.connect(oauthToken: oauthToken)
            let destination = try await adapter.mapVerifiedAccount()
            try await ledger.setEnabled(destination.id, true)

            settingsState.isGoogleConnected = true
            settingsState.googleAccountEmail = cred.email
            scheduleThrottledRefresh()
        } catch {
            let safe = (error as? SafeFailure) ?? GooglePhotosClientSession.classify(error)
            settingsState.googleAuthErrorMessage = mapSafeFailureCause(safe)
            throw safe
        }
    }

    public func disconnectGoogle() async throws {
        guard let engine = backupEngine, let session = googleSession, let ledger = ledger else { return }
        settingsState.isSettlingGoogle = true
        defer { settingsState.isSettlingGoogle = false }

        _ = await engine.settleProvider(.google)

        if let dest = try await ledger.selectedDestination(.google) {
            try await ledger.setEnabled(dest.id, false)
            try await ledger.deselectDestination(dest.id)
        }
        try await session.disconnect()

        settingsState.isGoogleConnected = false
        settingsState.googleAccountEmail = nil
        scheduleThrottledRefresh()
    }

    public func saveTelegramAPICredentials(apiId: Int32, apiHash: String) async throws {
        guard let client = tdlibClient else { return }
        settingsState.isConnectingTelegram = true
        settingsState.telegramAuthErrorMessage = nil
        defer { settingsState.isConnectingTelegram = false }

        let cred = StoredTelegramCredential(apiId: apiId, apiHash: apiHash)
        try credentialStore.saveTelegramCredential(cred, forProfile: "primary")
        try await client.start()
        let auth = await client.authorizationState
        updateTelegramAuthStep(from: auth)
    }

    public func submitTelegramPhone(_ phone: String) async throws {
        guard let client = tdlibClient else { return }
        settingsState.isConnectingTelegram = true
        settingsState.telegramAuthErrorMessage = nil
        defer { settingsState.isConnectingTelegram = false }

        do {
            try await client.setAuthenticationPhoneNumber(phone)
            let auth = await client.authorizationState
            updateTelegramAuthStep(from: auth)
        } catch {
            let safe = (error as? SafeFailure) ?? TDLibClient.classify(error)
            settingsState.telegramAuthErrorMessage = mapSafeFailureCause(safe)
            throw safe
        }
    }

    public func submitTelegramCode(_ code: String) async throws {
        guard let client = tdlibClient else { return }
        settingsState.isConnectingTelegram = true
        settingsState.telegramAuthErrorMessage = nil
        defer { settingsState.isConnectingTelegram = false }

        do {
            try await client.checkAuthenticationCode(code)
            let auth = await client.authorizationState
            updateTelegramAuthStep(from: auth)
        } catch {
            let safe = (error as? SafeFailure) ?? TDLibClient.classify(error)
            settingsState.telegramAuthErrorMessage = mapSafeFailureCause(safe)
            throw safe
        }
    }

    public func submitTelegramPassword(_ password: String) async throws {
        guard let client = tdlibClient else { return }
        settingsState.isConnectingTelegram = true
        settingsState.telegramAuthErrorMessage = nil
        defer { settingsState.isConnectingTelegram = false }

        do {
            try await client.checkAuthenticationPassword(password)
            let auth = await client.authorizationState
            updateTelegramAuthStep(from: auth)
        } catch {
            let safe = (error as? SafeFailure) ?? TDLibClient.classify(error)
            settingsState.telegramAuthErrorMessage = mapSafeFailureCause(safe)
            throw safe
        }
    }

    public func submitTelegramEmail(_ email: String) async throws {
        guard let client = tdlibClient else { return }
        settingsState.isConnectingTelegram = true
        settingsState.telegramAuthErrorMessage = nil
        defer { settingsState.isConnectingTelegram = false }

        do {
            _ = try await client.request(["@type": "setAuthenticationEmailAddress", "email_address": email])
            let auth = await client.authorizationState
            updateTelegramAuthStep(from: auth)
        } catch {
            let safe = (error as? SafeFailure) ?? TDLibClient.classify(error)
            settingsState.telegramAuthErrorMessage = mapSafeFailureCause(safe)
            throw safe
        }
    }

    public func submitTelegramEmailCode(_ code: String) async throws {
        guard let client = tdlibClient else { return }
        settingsState.isConnectingTelegram = true
        settingsState.telegramAuthErrorMessage = nil
        defer { settingsState.isConnectingTelegram = false }

        do {
            _ = try await client.request(["@type": "checkAuthenticationEmailCode", "code": ["@type": "emailAddressAuthenticationCode", "code": code]])
            let auth = await client.authorizationState
            updateTelegramAuthStep(from: auth)
        } catch {
            let safe = (error as? SafeFailure) ?? TDLibClient.classify(error)
            settingsState.telegramAuthErrorMessage = mapSafeFailureCause(safe)
            throw safe
        }
    }

    public func mapTelegramChannel(chatID: Int64) async throws {
        guard let client = tdlibClient, let adapter = telegramAdapter, let ledger = ledger else { return }
        settingsState.isConnectingTelegram = true
        settingsState.telegramAuthErrorMessage = nil
        defer { settingsState.isConnectingTelegram = false }

        do {
            let dest = try await adapter.mapVerifiedChannel(chatID: chatID)
            try await ledger.setEnabled(dest.id, true)

            let me = try await client.getMe()
            let firstName = me["first_name"]?.stringValue ?? ""
            let lastName = me["last_name"]?.stringValue ?? ""
            let username = me["username"]?.stringValue
            let displayName = username.map { "@\($0)" } ?? "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)

            let chat = try await client.request(["@type": "getChat", "chat_id": chatID])
            let chatTitle = chat["title"]?.stringValue ?? "Channel \(chatID)"

            settingsState.isTelegramConnected = true
            settingsState.telegramAccountName = displayName.isEmpty ? "Telegram User" : displayName
            settingsState.telegramChannelName = chatTitle
            settingsState.telegramChatID = chatID
            settingsState.telegramAuthStep = .connected

            scheduleThrottledRefresh()
        } catch {
            let safe = (error as? SafeFailure) ?? TDLibClient.classify(error)
            settingsState.telegramAuthErrorMessage = mapSafeFailureCause(safe)
            throw safe
        }
    }

    public func disconnectTelegram() async throws {
        guard let engine = backupEngine, let client = tdlibClient, let ledger = ledger else { return }
        settingsState.isSettlingTelegram = true
        defer { settingsState.isSettlingTelegram = false }

        _ = await engine.settleProvider(.telegram)

        if let dest = try await ledger.selectedDestination(.telegram) {
            try await ledger.setEnabled(dest.id, false)
            try await ledger.deselectDestination(dest.id)
        }
        try await client.close()
        try? credentialStore.deleteTelegramCredential(forProfile: "primary")

        settingsState.isTelegramConnected = false
        settingsState.telegramAccountName = nil
        settingsState.telegramChannelName = nil
        settingsState.telegramChatID = nil
        settingsState.telegramAuthStep = .unconfigured
        scheduleThrottledRefresh()
    }

    // MARK: - Redacted Diagnostics Export

    public func exportRedactedLogs() async throws -> URL {
        guard let ledger = ledger else {
            throw SafeFailure(.sourceUnavailable, domain: .core, cause: .unknown)
        }
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("cloudified-diagnostics-\(UUID().uuidString).jsonl")
        try await ledger.exportDiagnostics(to: fileURL)
        return fileURL
    }

    // MARK: - Helpers & Mappings

    private func recordDiagnosticFailure(_ reason: String) {
        inMemoryDiagnosticFailures.append("\(Date().ISO8601Format()): \(reason)")
        if inMemoryDiagnosticFailures.count > 50 {
            inMemoryDiagnosticFailures.removeFirst()
        }
    }

    private func mapFailuresToItems(failures: [FailureRow], sourceFailures: [SourceFailureRow]) -> [NotUploadedItem] {
        var items: [NotUploadedItem] = []

        for row in failures {
            let statusStr: String
            switch row.job.state {
            case .failed: statusStr = "Failed"
            case .waiting: statusStr = "Waiting"
            case .reconciling, .delayed: statusStr = "Pending"
            default: statusStr = "Waiting"
            }

            let providerStr = row.job.destination.provider == .google ? "Google Photos" : "Telegram"
            let reason = row.failure.map { mapSafeFailureCause($0) } ?? "Upload attempt failed"
            let category = row.failure?.category.rawValue ?? "Transfer"
            let code = row.failure?.code.map(String.init) ?? row.failure?.cause.rawValue

            let item = NotUploadedItem(
                id: row.job.id.uuidString,
                jobID: row.job.id,
                localIdentifier: row.asset.localIdentifier,
                filename: "Asset \(row.asset.localIdentifier.prefix(8))",
                captureDate: Date(),
                mediaType: row.asset.kind == .photo ? "Photo" : "Video",
                durationSeconds: nil,
                provider: providerStr,
                status: statusStr,
                attemptCount: row.job.attempts,
                maxAttempts: 3,
                stage: "Transfer",
                errorCategory: category,
                technicalCode: code,
                plainLanguageReason: reason,
                suggestedRemedy: "Check provider connectivity or retry manually.",
                confirmedComponents: ["\(row.confirmedResources) of \(row.requiredResources) components confirmed"],
                missingObligations: [],
                nextRetryDate: row.job.retryAt
            )
            items.append(item)
        }

        for row in sourceFailures {
            let providerStr = row.destination.provider == .google ? "Google Photos" : "Telegram"
            let reason = mapSafeFailureCause(row.error)
            let item = NotUploadedItem(
                id: row.asset.id.uuidString + "-" + row.destination.id.uuidString,
                jobID: nil,
                localIdentifier: row.asset.localIdentifier,
                filename: "Source Asset \(row.asset.localIdentifier.prefix(8))",
                captureDate: row.occurredAt,
                mediaType: row.asset.kind == .photo ? "Photo" : "Video",
                durationSeconds: nil,
                provider: providerStr,
                status: row.permanent ? "Failed" : "Waiting",
                attemptCount: 1,
                maxAttempts: 3,
                stage: "Preparation",
                errorCategory: row.error.category.rawValue,
                technicalCode: row.error.code.map(String.init) ?? row.error.cause.rawValue,
                plainLanguageReason: reason,
                suggestedRemedy: "Verify that the original asset exists in the Photos library.",
                confirmedComponents: [],
                missingObligations: [],
                nextRetryDate: nil
            )
            items.append(item)
        }

        return items
    }

    private func mapDiagnosticEvent(_ event: DiagnosticEvent) -> DiagnosticLogEntry {
        let originStr: String
        switch event.context.origin {
        case .google: originStr = "Google Photos"
        case .telegram: originStr = "Telegram"
        case .source: originStr = "PhotoKit Source"
        case .core: originStr = "Core Engine"
        case .system: originStr = "System"
        }

        let message: String
        if let failure = event.failure {
            message = mapSafeFailureCause(failure)
        } else if let bytes = event.bytes, let exp = event.expectedBytes {
            let sent = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            let total = ByteCountFormatter.string(fromByteCount: exp, countStyle: .file)
            message = "\(event.operation.rawValue.capitalized): \(sent) of \(total)"
        } else {
            message = "\(event.operation.rawValue.capitalized) -> \(event.decision.rawValue)"
        }

        return DiagnosticLogEntry(
            id: String(event.sequence),
            timestamp: event.timestamp,
            origin: originStr,
            severity: event.severity.rawValue,
            stage: event.operation.rawValue,
            attemptNumber: event.context.attempt,
            message: message,
            safeErrorCode: event.failure?.code.map(String.init)
        )
    }

    /// Maps strict Core SafeFailure causes to distinct understandable user-facing descriptions.
    private func mapSafeFailureCause(_ failure: SafeFailure) -> String {
        switch failure.cause {
        case .identityUnverified:
            return "Google OpenID subject verification failed. Account identity could not be verified."
        case .pairingUnverified:
            return "Google Live Photo pairing capability could not be verified. Select an alternative fallback policy in Settings."
        case .pendingSendUnmatched:
            return "Telegram pending message correlation failed. File ownership retained without resending."
        case .privateChannelRequired:
            return "Telegram requires an owned private channel with creator permissions and auto-delete disabled."
        case .accountChanged:
            return "Destination account or credentials changed. Re-authentication required."
        case .loginRequired:
            return "Authentication required. Please connect in Settings."
        case .permissionDenied:
            return "Permission denied. Please check system privacy settings."
        case .insufficientSpace:
            return "Insufficient device storage space for staging and transport."
        case .formatRejected:
            return "Media format or layout rejected by destination."
        case .contentChanged:
            return "Local asset content changed during export."
        case .sourceMissing:
            return "Original photo or video asset is missing from local library."
        case .interrupted:
            return "Operation was interrupted or cancelled."
        case .serverRateLimit:
            return "Destination rate limit reached. Waiting before next retry."
        case .deadlineExceeded:
            return "Network request deadline exceeded."
        case .offline:
            return "Network connection offline."
        default:
            return failure.description
        }
    }
}
