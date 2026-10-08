import Foundation
import CloudifiedCore

/// High-level authorization states surfaced by TDLib.
/// Aligned with pinned TDLib commit 42e6a5259551178d1dab54a22ad96d14bd906e20.
public enum TDLibAuthorizationState: Sendable, Equatable {
    case uninitialized
    case waitTdlibParameters
    case waitPhoneNumber
    case waitPremiumPurchase
    case waitEmailAddress
    case waitEmailCode
    case waitCode
    case waitOtherDeviceConfirmation
    case waitRegistration
    case waitPassword
    case ready
    case loggingOut
    case closing
    case closed
    case uncertain
}

/// Parameters required to initialize a TDLib native database and network session.
/// Strictly matches td_api.tl `setTdlibParameters` schema at pinned commit.
public struct TDLibParameters: Sendable {
    public let apiId: Int32
    public let apiHash: String
    public let databaseDirectory: String
    public let filesDirectory: String
    public let databaseEncryptionKey: String
    public let useFileDatabase: Bool
    public let useChatInfoDatabase: Bool
    public let useMessageDatabase: Bool
    public let useSecretChats: Bool
    public let applicationVersion: String
    public let deviceModel: String
    public let systemVersion: String
    public let systemLanguageCode: String
    public let useTestDC: Bool

    public init(
        apiId: Int32,
        apiHash: String,
        databaseDirectory: String,
        filesDirectory: String,
        databaseEncryptionKey: String,
        useFileDatabase: Bool = true,
        useChatInfoDatabase: Bool = true,
        useMessageDatabase: Bool = true,
        useSecretChats: Bool = false,
        applicationVersion: String = "1.0.0",
        deviceModel: String = "iPhone",
        systemVersion: String = "iOS 26",
        systemLanguageCode: String = "en",
        useTestDC: Bool = false
    ) {
        self.apiId = apiId
        self.apiHash = apiHash
        self.databaseDirectory = databaseDirectory
        self.filesDirectory = filesDirectory
        self.databaseEncryptionKey = databaseEncryptionKey
        self.useFileDatabase = useFileDatabase
        self.useChatInfoDatabase = useChatInfoDatabase
        self.useMessageDatabase = useMessageDatabase
        self.useSecretChats = useSecretChats
        self.applicationVersion = applicationVersion
        self.deviceModel = deviceModel
        self.systemVersion = systemVersion
        self.systemLanguageCode = systemLanguageCode
        self.useTestDC = useTestDC
    }

    /// Converts to exact TDLib JSON request dictionary.
    public func toRequestDictionary() -> [String: Any] {
        [
            "@type": "setTdlibParameters",
            "use_test_dc": useTestDC,
            "database_directory": databaseDirectory,
            "files_directory": filesDirectory,
            "database_encryption_key": databaseEncryptionKey,
            "use_file_database": useFileDatabase,
            "use_chat_info_database": useChatInfoDatabase,
            "use_message_database": useMessageDatabase,
            "use_secret_chats": useSecretChats,
            "api_id": apiId,
            "api_hash": apiHash,
            "system_language_code": systemLanguageCode,
            "device_model": deviceModel,
            "system_version": systemVersion,
            "application_version": applicationVersion
        ]
    }
}

/// Actor owning a single active TDLib client session.
/// Routes requests/updates through the process-global TDLibProcessReceiver,
/// enforces bounded memory and request maps, handles deadlines without hangs,
/// coalesces file progress and fences critical delivery overflow,
/// and manages deterministic native close acknowledgement.
public actor TDLibSession {
    public static let maxPendingRequests = 100
    public static let maxSubscribers = 10
    public static let maxTrackedFiles = 1000

    private struct PendingRequest {
        let continuation: CheckedContinuation<TDLibResponse, any Error>
        let timeoutTask: Task<Void, Never>
    }

    private let bridge: TDLibBridge
    private let receiver: TDLibProcessReceiver
    private let diagnosticSink: (@Sendable (EventOperation, EventContext, EventDecision, EventSeverity, SafeFailure?, TimeInterval?, Int64?, Int64?) async throws -> Void)?

    private var clientID: Int32?
    private var pendingRequests: [String: PendingRequest] = [:]
    private var updateContinuations: [UUID: AsyncThrowingStream<TDLibResponse, any Error>.Continuation] = [:]
    private var processingFailure: (any Error)?

    private var currentAuthState: TDLibAuthorizationState = .uninitialized
    private var isClosing = false
    private var isTerminated = false
    private var closeTask: Task<Void, any Error>?

    // Progress coalescing state for file transfers: file_id -> tracking record
    private struct FileTransferTracking: Sendable {
        var lastEmittedUptime: TimeInterval
        var lastUploadedSize: Int64
        var wasUploadingActive: Bool
        var wasDownloadingActive: Bool
    }
    private var fileTransferTracking: [Int64: FileTransferTracking] = [:]

    public init(
        bridge: TDLibBridge = TDLibBridge(),
        receiver: TDLibProcessReceiver = .shared,
        diagnosticSink: (@Sendable (EventOperation, EventContext, EventDecision, EventSeverity, SafeFailure?, TimeInterval?, Int64?, Int64?) async throws -> Void)? = nil
    ) {
        self.bridge = bridge
        self.receiver = receiver
        self.diagnosticSink = diagnosticSink
    }

    /// Current authorization state.
    public var authState: TDLibAuthorizationState {
        currentAuthState
    }

    /// Whether this session has been terminated.
    public var isClosed: Bool {
        isTerminated
    }
    /// A delivery/log gap fences new commands; it is not remote rejection/absence.
    public var requiresReconciliation: Bool { processingFailure != nil }

    // MARK: - Lifecycle

    /// Initializes and starts the owned TDLib client and registers with the process receiver.
    public func start() async throws -> Int32 {
        guard clientID == nil, closeTask == nil else {
            throw TDLibError.executionFailed("TDLibSession is already started.")
        }
        self.isTerminated = false
        self.isClosing = false
        self.currentAuthState = .uninitialized
        self.processingFailure = nil

        // Atomically create native client ID and register session handler with receiver
        let id = try await receiver.createAndRegisterSession { [weak self] result in
            await self?.handleIncomingResponse(result)
        }
        self.clientID = id

        try await emitDiagnostic(.appStart, decision: .proceed, severity: .info)
        return id
    }

    /// Subscribes to the broadcast stream of TDLib updates with bounded buffer policy.
    public func updateStream() throws -> AsyncThrowingStream<TDLibResponse, any Error> {
        if let processingFailure { throw processingFailure }
        guard updateContinuations.count < Self.maxSubscribers else {
            throw TDLibError.capacityExceeded("Maximum subscriber limit reached (\(Self.maxSubscribers)).")
        }

        let streamID = UUID()
        return AsyncThrowingStream(bufferingPolicy: .bufferingOldest(100)) { continuation in
            self.registerUpdateContinuation(continuation, id: streamID)
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.unregisterUpdateContinuation(id: streamID)
                }
            }
        }
    }

    private func registerUpdateContinuation(_ continuation: AsyncThrowingStream<TDLibResponse, any Error>.Continuation, id: UUID) {
        updateContinuations[id] = continuation
    }

    private func unregisterUpdateContinuation(id: UUID) {
        updateContinuations.removeValue(forKey: id)
    }

    // MARK: - Request Dispatch & Correlation

    /// Sends an asynchronous TDLib request and waits for the correlated response.
    /// Strictly validates finite positive timeouts, registers atomically, and uses
    /// a single terminal resolver to guarantee continuation resolution without hangs.
    public func sendRequest(_ request: [String: Any], timeout: TimeInterval = 60.0) async throws -> TDLibResponse {
        try Task.checkCancellation()
        if let processingFailure { throw processingFailure }
        guard timeout.isFinite, timeout > 0, timeout <= 300.0 else {
            throw TDLibError.invalidParameter("Timeout must be finite positive number <= 300 seconds.")
        }
        guard let clientID, !isTerminated, !isClosing else {
            throw TDLibError.clientClosed
        }
        guard pendingRequests.count < Self.maxPendingRequests else {
            throw TDLibError.capacityExceeded("Pending requests limit reached (\(Self.maxPendingRequests)).")
        }

        var mutableReq = request
        let extraID = UUID().uuidString
        mutableReq["@extra"] = extraID

        let jsonString = try TDLibJSON.serializeRequest(mutableReq)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                // Spawn dedicated deadline timer
                let timeoutTask = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000)) }
                    catch { return }
                    await self?.resolveFailure(id: extraID, error: TDLibError.timeout)
                }

                self.pendingRequests[extraID] = PendingRequest(
                    continuation: continuation,
                    timeoutTask: timeoutTask
                )

                // Dispatch to C ABI
                self.bridge.send(clientID: clientID, jsonRequest: jsonString)
            }
        } onCancel: {
            Task { [weak self] in
                await self?.resolveFailure(id: extraID, error: CancellationError())
            }
        }
    }

    private func resolvePendingRequest(id: String, result: Result<TDLibResponse, any Error>) {
        guard let pending = pendingRequests.removeValue(forKey: id) else {
            return
        }
        pending.timeoutTask.cancel()

        pending.continuation.resume(with: result)
    }

    private func resolveFailure(id: String, error: any Error) async {
        // Reserve the terminal result before awaiting a potentially slow sink.
        guard let pending = pendingRequests.removeValue(forKey: id) else { return }
        // The deadline task must not cancel itself before persisting its event.
        if (error as? TDLibError) != .timeout { pending.timeoutTask.cancel() }
        do {
            try await emitDiagnostic(.failure, decision: .wait, severity: .error,
                                     failure: error is CancellationError
                                        ? SafeFailure(.transfer, domain: .tdlib, cause: .interrupted)
                                        : TDLibClient.classify(error))
            pending.continuation.resume(throwing: error)
        } catch {
            pending.continuation.resume(throwing: error)
            interruptInput(error)
        }
    }

    private func interruptInput(_ error: any Error) {
        if processingFailure == nil { processingFailure = error }
        let failure = processingFailure!
        for id in Array(pendingRequests.keys) {
            resolvePendingRequest(id: id, result: .failure(failure))
        }
        for continuation in updateContinuations.values { continuation.finish(throwing: failure) }
        updateContinuations.removeAll()
        // Keep the receiver/native client alive for real close acknowledgement.
    }

    // MARK: - Incoming Message Handling

    private func handleIncomingResponse(_ result: Result<TDLibResponse, TDLibError>) async {
        let response: TDLibResponse
        do { response = try result.get() }
        catch {
            interruptInput(error)
            return
        }

        // Correlate with pending request via @extra if present
        if let extra = response.extra, pendingRequests[extra] != nil {
            if response.isError {
                let code = response.errorCode ?? 0
                let message = response.errorMessage ?? "TDLib error"
                await resolveFailure(id: extra, error: TDLibError.tdlibError(code: code, message: message))
            } else {
                resolvePendingRequest(id: extra, result: .success(response))
            }
            return
        }

        var isClosedAcknowledgement = false
        // Process authorization state updates
        if let type = response.type {
            if type == "updateAuthorizationState" {
                if let stateObj = response.object(forKey: "authorization_state"),
                   let stateType = stateObj.type {
                    isClosedAcknowledgement = await handleAuthStateUpdate(stateType)
                }
            } else if type == "updateFile" {
                // Separate latest-value progress coalescing from guaranteed terminal states
                if let file = response.object(forKey: "file"),
                   let fileID = file.int64(forKey: "id") {
                    let remote = file.object(forKey: "remote")
                    let local = file.object(forKey: "local")

                    let isUploadingActive = remote?.bool(forKey: "is_uploading_active") == true
                    let isUploadingCompleted = remote?.bool(forKey: "is_uploading_completed") == true
                    let uploadedSize = remote?.int64(forKey: "uploaded_size") ?? 0

                    let isDownloadingActive = local?.bool(forKey: "is_downloading_active") == true
                    let isDownloadingCompleted = local?.bool(forKey: "is_downloading_completed") == true

                    let prev = fileTransferTracking[fileID]
                    let wasUploadingActive = prev?.wasUploadingActive ?? false
                    let wasDownloadingActive = prev?.wasDownloadingActive ?? false

                    // Terminal transitions for upload or download
                    let isUploadTerminal = isUploadingCompleted || (wasUploadingActive && !isUploadingActive)
                    let isDownloadTerminal = isDownloadingCompleted || (wasDownloadingActive && !isDownloadingActive)

                    if isUploadTerminal || isDownloadTerminal {
                        // Terminal state: evict from progress tracking and guarantee delivery
                        fileTransferTracking.removeValue(forKey: fileID)
                    } else if isUploadingActive || isDownloadingActive {
                        // Intermediate progress: coalesce to ~2 Hz
                        let now = ProcessInfo.processInfo.systemUptime
                        let lastTime = prev?.lastEmittedUptime ?? 0
                        if now - lastTime < 0.5 {
                            fileTransferTracking[fileID] = FileTransferTracking(
                                lastEmittedUptime: lastTime,
                                lastUploadedSize: uploadedSize,
                                wasUploadingActive: isUploadingActive,
                                wasDownloadingActive: isDownloadingActive
                            )
                            return
                        }
                        // Prune cache if over capacity
                        if fileTransferTracking.count >= Self.maxTrackedFiles {
                            fileTransferTracking.removeAll(keepingCapacity: true)
                        }
                        fileTransferTracking[fileID] = FileTransferTracking(
                            lastEmittedUptime: now,
                            lastUploadedSize: uploadedSize,
                            wasUploadingActive: isUploadingActive,
                            wasDownloadingActive: isDownloadingActive
                        )
                    }
                }
            }
        }

        // Broadcast to all active update listeners FIRST so that authorizationStateClosed
        // reaches subscribers BEFORE the stream terminates
        for (id, continuation) in Array(updateContinuations) {
            switch continuation.yield(response) {
            case .enqueued: break
            case .terminated: updateContinuations.removeValue(forKey: id)
            case .dropped:
                let failure = TDLibError.capacityExceeded("Critical update delivery overflow; reconciliation required.")
                interruptInput(failure)
                return
            @unknown default:
                interruptInput(TDLibError.malformedResponse)
                return
            }
        }

        if isClosedAcknowledgement {
            await completeClosure()
        }
    }

    private func handleAuthStateUpdate(_ stateType: String) async -> Bool {
        let oldState = currentAuthState
        var isClosed = false
        switch stateType {
        case "authorizationStateWaitTdlibParameters":
            currentAuthState = .waitTdlibParameters
        case "authorizationStateWaitPhoneNumber":
            currentAuthState = .waitPhoneNumber
        case "authorizationStateWaitPremiumPurchase":
            currentAuthState = .waitPremiumPurchase
        case "authorizationStateWaitEmailAddress":
            currentAuthState = .waitEmailAddress
        case "authorizationStateWaitEmailCode":
            currentAuthState = .waitEmailCode
        case "authorizationStateWaitCode":
            currentAuthState = .waitCode
        case "authorizationStateWaitOtherDeviceConfirmation":
            currentAuthState = .waitOtherDeviceConfirmation
        case "authorizationStateWaitRegistration":
            currentAuthState = .waitRegistration
        case "authorizationStateWaitPassword":
            currentAuthState = .waitPassword
        case "authorizationStateReady":
            currentAuthState = .ready
        case "authorizationStateLoggingOut":
            currentAuthState = .loggingOut
        case "authorizationStateClosing":
            currentAuthState = .closing
        case "authorizationStateClosed":
            currentAuthState = .closed
            isClosed = true
        default:
            break
        }

        if oldState != currentAuthState {
            do { try await emitDiagnostic(.enabledChanged, decision: .proceed, severity: .info) }
            catch { interruptInput(error) }
        }
        return isClosed
    }

    // MARK: - Close Handling

    /// Closes the client session and awaits terminal closed acknowledgement from native TDLib.
    /// All concurrent close callers await the same closure Task.
    public func close() async throws {
        if isTerminated { return }
        if let existing = closeTask {
            return try await existing.value
        }

        let task = Task { [self] in
            try await performClose()
        }
        self.closeTask = task
        defer { self.closeTask = nil }
        return try await task.value
    }

    private func performClose() async throws {
        guard let clientID, !isTerminated else { return }
        self.isClosing = true
        self.currentAuthState = .closing

        // Send close command to TDLib
        let closeReq: [String: Any] = ["@type": "close"]
        let closeJSON = try TDLibJSON.serializeRequest(closeReq)
        bridge.send(clientID: clientID, jsonRequest: closeJSON)

        // Await native confirmation with finite bounded deadline (10 seconds)
        let maxWaitSeconds: TimeInterval = 10.0
        let start = ProcessInfo.processInfo.systemUptime
        while (!isTerminated || self.clientID != nil) && (ProcessInfo.processInfo.systemUptime - start) < maxWaitSeconds {
            do { try await Task.sleep(nanoseconds: 100_000_000) }
            catch { throw TDLibError.unresolvedClose("Close interrupted; native confirmation remains pending.") }
        }

        if !isTerminated || self.clientID != nil {
            // Unresolved close deadline: do NOT fabricate closed state
            currentAuthState = .uncertain
            try await emitDiagnostic(
                .failure,
                decision: .wait,
                severity: .error,
                failure: SafeFailure(.invariant, domain: .tdlib, cause: .interrupted)
            )
            throw TDLibError.unresolvedClose("TDLib did not acknowledge authorizationStateClosed within \(maxWaitSeconds)s.")
        }
        if let processingFailure { throw processingFailure }
    }

    private func completeClosure() async {
        guard !isTerminated else { return }
        isTerminated = true
        isClosing = false
        currentAuthState = .closed

        // Cancel and resolve all pending requests
        for id in Array(pendingRequests.keys) {
            resolvePendingRequest(id: id, result: .failure(TDLibError.clientClosed))
        }
        pendingRequests.removeAll()

        // Terminate all update streams now that authorizationStateClosed has been delivered
        for continuation in updateContinuations.values {
            continuation.finish()
        }
        updateContinuations.removeAll()
        fileTransferTracking.removeAll()

        if let cid = clientID {
            await receiver.unregisterSession(clientID: cid)
        }
        clientID = nil

        // Attempt persistent diagnostic logging; failure must not alter genuine native closed fact
        do { try await emitDiagnostic(.finalization, decision: .proceed, severity: .info) }
        catch { /* Native close remains acknowledged fact */ }
    }

    private func emitDiagnostic(
        _ operation: EventOperation,
        decision: EventDecision,
        severity: EventSeverity,
        failure: SafeFailure? = nil,
        duration: TimeInterval? = nil,
        bytes: Int64? = nil,
        expectedBytes: Int64? = nil
    ) async throws {
        guard let diagnosticSink else { return }
        let context = EventContext(origin: .telegram)
        do { try await diagnosticSink(operation, context, decision, severity, failure, duration, bytes, expectedBytes) }
        catch { interruptInput(error); throw error }
    }
}
