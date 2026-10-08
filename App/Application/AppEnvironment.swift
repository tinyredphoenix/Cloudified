import Foundation
import Combine
@preconcurrency import Photos
import CloudifiedCore

public enum AppTab: Hashable, Sendable { case dashboard, notUploaded, logs, settings }
typealias DiagnosticSink = @Sendable (EventOperation, EventContext, EventDecision, EventSeverity, SafeFailure?, TimeInterval?, Int64?, Int64?) async throws -> Void

/// Composition and task ownership. Commands, snapshots and bounded page queries
/// live in focused extensions; SQLite/attempt/receipt ownership remains in Core.
@MainActor
public final class AppEnvironment: ObservableObject {
    @Published public var selectedTab: AppTab = .dashboard
    @Published public var dashboardState = DashboardViewState()
    @Published public var notUploadedState = NotUploadedViewState()
    @Published public var logsState = LogsViewState()
    @Published public var settingsState = SettingsViewState()
    public let storageLayout: StorageLayout?
    public let ledger: Ledger?
    public let fileLeaseStore: FileLeaseStore?
    public let photoPipeline: PhotoLibraryPipeline?
    public let backupEngine: BackupEngine?
    let credentialStore = KeychainCredentialStore()
    let networkPolicy = UploadRequestNetworkPolicy()
    let fallback = DiagnosticFallback()
    let networkMonitor = NetworkPolicyMonitor()
    let continuation = BackupContinuation()
    let diagnosticSink: DiagnosticSink
    let exportStore: DiagnosticExportStore?
    let googleSession: GooglePhotosClientSession?
    let googleAdapter: GooglePhotosProviderAdapter?
    var tdlibClient: TDLibClient?
    var telegramAdapter: TelegramProviderAdapter?

    var observers: [Task<Void, Never>] = []
    var telegramObservers: [Task<Void, Never>] = []
    var bootstrapTask: Task<Void, Never>?
    var backupExecutionTask: Task<Void, Never>?
    var libraryAccessTask: Task<Void, Never>?
    var refreshTask: Task<Void, Never>?
    var policyTask: Task<Void, Never>?
    var retryTask: Task<Void, Never>?
    var cleanupTask: Task<Void, Never>?
    var failurePageTask: Task<Void, Never>?
    var logPageTask: Task<Void, Never>?
    var runPageTask: Task<Void, Never>?
    var sourceStatusTask: Task<Void, Never>?
    var recoveryWake: Set<Provider> = []
    var recoveryTasks: [Provider: Task<Void, Never>] = [:]
    var sourceProducer: DemandSourceProducer?
    var planningCursors: [UUID: Int64] = [:]
    var planningEpoch = 0
    var activeScanID: UUID?
    var pendingRefresh = false
    var policyDirty = false
    var bootstrapComplete = false
    var isScanning = false
    var planningProvider: Provider?
    var backupRequested = false
    var resumeAfterExpiration = false
    var needsWake = false
    var retryDeadlines: [Provider: Date] = [:]
    var needsFreshScan = false
    var pausedByUser = UserDefaults.standard.bool(forKey: "CloudifiedUserPaused")
    var commandProvider: Provider?
    var commandID: UUID?
    var controlTransition = false
    var systemError: SafeFailure?
    var providerErrors: [Provider: SafeFailure] = [:]
    var startupInventoryCompleted = false
    var network: NetworkPolicySnapshot?
    var isForeground = true
    var shuttingDown = false
    var onMemoryPressure: (@MainActor () -> Void)?
    var failureQueryGeneration = 0
    var logQueryGeneration = 0
    var failureCursor: Int64?
    var sourceFailureCursor: Int64?
    var logCursor: Int64?
    var runCursor: Date?
    var nextFailureCursor: Int64?
    var nextSourceFailureCursor: Int64?
    var nextLogCursor: Int64?

    public init() {
        let safeFallback = fallback
        var layoutValue: StorageLayout?, ledgerValue: Ledger?, filesValue: FileLeaseStore?
        var pipelineValue: PhotoLibraryPipeline?, engineValue: BackupEngine?
        var exportValue: DiagnosticExportStore?, googleValue: GooglePhotosClientSession?
        var googleAdapterValue: GooglePhotosProviderAdapter?, telegramValue: TDLibClient?
        var telegramAdapterValue: TelegramProviderAdapter?
        var initialAttentionReason: String? = nil
        var sink: DiagnosticSink = { _, _, _, _, failure, _, _, _ in
            safeFallback.record(failure ?? SafeFailure(.invariant, domain: .sqlite, cause: .persistenceFailed))
            throw CoreError.recoveryRequired
        }
        do {
            let layout = try StorageLayout()
            let bundle = Bundle.main
            let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unavailable"
            let revision = bundle.object(forInfoDictionaryKey: "CloudifiedRevision") as? String ?? "unknown"
            let led = try Ledger(databaseURL: layout.databaseURL, version: version,
                                 revision: revision.contains("$(") ? "unknown" : revision)
            let files = try FileLeaseStore(root: layout.stagingURL, ledger: led)
            sink = { op, context, decision, severity, failure, duration, bytes, expected in
                do {
                    try await led.appendEvent(op, context: context, decision: decision, severity: severity,
                        failure: failure, duration: duration, bytes: bytes, expectedBytes: expected)
                } catch {
                    safeFallback.record(ProviderSupport.safe(error, domain: .sqlite)); throw error
                }
            }
            let google = try GooglePhotosClientSession(profileID: "primary", credentialStore: credentialStore,
                                                       networkPolicy: networkPolicy, diagnosticSink: sink)
            let telegram = try TDLibClient(profileID: "primary", credentialStore: credentialStore, diagnosticSink: sink)
            layoutValue = layout; ledgerValue = led; filesValue = files
            pipelineValue = PhotoLibraryPipeline(ledger: led, fileStore: files, storageLayout: layout)
            engineValue = BackupEngine(ledger: led, files: files)
            exportValue = try DiagnosticExportStore(layout: layout)
            googleValue = google; googleAdapterValue = GooglePhotosProviderAdapter(session: google, ledger: led, files: files)
            telegramValue = telegram; telegramAdapterValue = TelegramProviderAdapter(client: telegram, ledger: led, files: files)
        } catch {
            let safe = ProviderSupport.safe(error, domain: .core); safeFallback.record(safe)
            initialAttentionReason = safe.description
        }
        storageLayout = layoutValue; ledger = ledgerValue; fileLeaseStore = filesValue
        photoPipeline = pipelineValue; backupEngine = engineValue; exportStore = exportValue
        googleSession = googleValue; googleAdapter = googleAdapterValue
        tdlibClient = telegramValue; telegramAdapter = telegramAdapterValue; diagnosticSink = sink
        if let initialAttentionReason {
            dashboardState.overallState = .needsAttention(reason: initialAttentionReason)
        }
        if let raw = UserDefaults.standard.string(forKey: "CloudifiedLivePhotoFallback"),
           let value = LivePhotoFallbackOption(rawValue: raw) { settingsState.livePhotoFallback = value }
        if UserDefaults.standard.object(forKey: "CloudifiedWiFiOnly") != nil {
            settingsState.isWiFiOnlyEnabled = UserDefaults.standard.bool(forKey: "CloudifiedWiFiOnly")
        }
        networkPolicy.setCellularAllowed(!settingsState.isWiFiOnlyEnabled)
        continuation.onChange = { [weak self] in self?.schedulePolicyUpdate(); self?.scheduleThrottledRefresh() }
        continuation.onExpiration = { [weak self] in self?.backgroundExpired() }
        startSubscriptions(); startTelegramSubscriptions()
        bootstrapTask = Task { [weak self] in await self?.bootstrap() }
    }
    deinit {
        for task in observers + telegramObservers { task.cancel() }
        bootstrapTask?.cancel(); backupExecutionTask?.cancel(); libraryAccessTask?.cancel(); refreshTask?.cancel()
        policyTask?.cancel(); retryTask?.cancel(); cleanupTask?.cancel(); sourceStatusTask?.cancel()
        for task in recoveryTasks.values { task.cancel() }
        failurePageTask?.cancel(); logPageTask?.cancel(); runPageTask?.cancel()
        networkMonitor.stop()
    }
    func bootstrap() async {
        do {
            try await exportStore?.removeStale()
            if pausedByUser { try await backupEngine?.pause() }
        } catch { await report(error, provider: nil) }
        await establishStartupInventory()
        // Readiness belongs to each destination. A slow remote history scan must
        // not hold the healthy provider behind a global bootstrap await.
        bootstrapComplete = true
        requestRecovery(.google); requestRecovery(.telegram)
        await refreshStoredSettings()
        schedulePolicyUpdate(); scheduleThrottledRefresh(); requestDrain()
    }
    func startSubscriptions() {
        if let ledger {
            observers.append(Task { [weak self] in
                do { for await _ in try await ledger.observeChanges() { self?.scheduleThrottledRefresh() } }
                catch { await self?.report(error, provider: nil) }
            })
        }
        let fallbackEvents = fallback.events
        observers.append(Task { [weak self] in
            for await _ in fallbackEvents { self?.scheduleThrottledRefresh() }
        })
        let paths = networkMonitor.events
        observers.append(Task { [weak self] in
            for await value in paths { self?.network = value; self?.schedulePolicyUpdate() }
        })
    }
    func startTelegramSubscriptions() {
        guard let client = tdlibClient, let adapter = telegramAdapter else { return }
        telegramObservers.append(Task { [weak self] in
            do {
                for try await update in try await client.updates(types: ["updateAuthorizationState", "updateConnectionState"]) {
                    if update.type == "updateAuthorizationState" {
                        let auth = await client.authorizationState
                        self?.updateTelegramAuthStep(auth)
                        if auth == .ready { self?.requestRecovery(.telegram) }
                    } else if update.type == "updateConnectionState",
                              update.object(forKey: "state")?.type == "connectionStateReady" {
                        self?.requestRecovery(.telegram)
                    }
                }
            } catch { await self?.report(error, provider: .telegram) }
        })
        let statuses = adapter.statusEvents, recovery = adapter.recoveryEvents
        telegramObservers.append(Task { [weak self] in
            for await _ in statuses { self?.scheduleThrottledRefresh() }
        })
        telegramObservers.append(Task { [weak self] in
            for await _ in recovery { self?.requestRecovery(.telegram) }
        })
    }
    public func scheduleThrottledRefresh() {
        pendingRefresh = true
        guard refreshTask == nil, !shuttingDown else { return }
        refreshTask = Task { [weak self] in
            while self?.pendingRefresh == true && !Task.isCancelled {
                self?.pendingRefresh = false
                await self?.performUIRefresh()
                do { try await Task.sleep(for: .milliseconds(500)) } catch { break }
            }
            self?.refreshTask = nil
        }
    }
    func report(_ error: any Error, provider: Provider?) async {
        let safe = ProviderSupport.safe(error, domain: provider == .google ? .google : (provider == .telegram ? .tdlib : .core))
        if let provider {
            providerErrors[provider] = safe
            if provider == .google { settingsState.googleAuthErrorMessage = explain(safe) }
            else { settingsState.telegramAuthErrorMessage = explain(safe) }
        } else { systemError = safe; dashboardState.waitingOrErrorReason = explain(safe) }
        do {
            try await ledger?.appendEvent(.failure, context: EventContext(origin: provider?.origin ?? .system),
                                         decision: .wait, severity: .error, failure: safe)
        } catch { fallback.record(ProviderSupport.safe(error, domain: .sqlite)) }
        if ledger == nil { fallback.record(safe) }
        scheduleThrottledRefresh()
    }
    func explain(_ failure: SafeFailure) -> String { FailureExplanation.message(failure) }
}
