import Foundation
import CloudifiedCore

/// High-level authorization states surfaced by TDLib.
/// Aligned with pinned TDLib commit 42e6a5259551178d1dab54a22ad96d14bd906e20.
public enum TDLibAuthorizationState: Sendable, Equatable {
    case uninitialized
    case waitTdlibParameters
    case waitPhoneNumber
    case waitCode
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
/// coalesces file progress while guaranteeing critical terminal delivery,
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
    private var updateContinuations: [UUID: AsyncStream<TDLibResponse>.Continuation] = [:]

    private var currentAuthState: TDLibAuthorizationState = .uninitialized
    private var isClosing = false
    private var isTerminated = false
    private var closeTask: Task<Void, any Error>?

    // Progress coalescing state for file updates: file_id -> last emitted uptime
    private var fileProgressEmittedTimes: [Int64: TimeInterval] = [:]

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

    // MARK: - Lifecycle

    /// Initializes and starts the owned TDLib client and registers with the process receiver.
    public func start() async throws -> Int32 {
        guard clientID == nil else {
            throw TDLibError.executionFailed("TDLibSession is already started.")
        }
        let id = try bridge.createClientID()
        self.clientID = id
        self.isTerminated = false
        self.isClosing = false
        self.currentAuthState = .uninitialized

        // Register session handler with the process-global receiver
        await receiver.registerSession(clientID: id) { [weak self] jsonString in
            await self?.handleIncomingJSON(jsonString)
        }

        try? await emitDiagnostic(.appStart, decision: .proceed, severity: .info)
        return id
    }

    /// Subscribes to the broadcast stream of TDLib updates with bounded buffer policy.
    public func updateStream() throws -> AsyncStream<TDLibResponse> {
        guard updateContinuations.count < Self.maxSubscribers else {
            throw TDLibError.capacityExceeded("Maximum subscriber limit reached (\(Self.maxSubscribers)).")
        }

        let streamID = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(100)) { continuation in
            self.registerUpdateContinuation(continuation, id: streamID)
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.unregisterUpdateContinuation(id: streamID)
                }
            }
        }
    }

    private func registerUpdateContinuation(_ continuation: AsyncStream<TDLibResponse>.Continuation, id: UUID) {
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
                // Spawn dedicated deadline timer
                let timeoutTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    await self?.resolvePendingRequest(id: extraID, result: .failure(TDLibError.timeout))
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
                await self?.resolvePendingRequest(id: extraID, result: .failure(CancellationError()))
            }
        }
    }

    private func resolvePendingRequest(id: String, result: Result<TDLibResponse, any Error>) {
        guard let pending = pendingRequests.removeValue(forKey: id) else {
            return
        }
        pending.timeoutTask.cancel()

        if case .failure(let error) = result {
            if let tdErr = error as? TDLibError, case .timeout = tdErr {
                Task { [weak self] in
                    try? await self?.emitDiagnostic(
                        .failure,
                        decision: .wait,
                        severity: .error,
                        failure: SafeFailure(.timeout, domain: .tdlib, cause: .deadlineExceeded)
                    )
                }
            } else if error is CancellationError {
                Task { [weak self] in
                    try? await self?.emitDiagnostic(
                        .failure,
                        decision: .wait,
                        severity: .warning,
                        failure: SafeFailure(.transfer, domain: .tdlib, cause: .interrupted)
                    )
                }
            }
        }

        pending.continuation.resume(with: result)
    }

    // MARK: - Incoming Message Handling

    private func handleIncomingJSON(_ jsonString: String) {
        guard let response = try? TDLibJSON.parse(jsonString) else {
            return
        }

        // Correlate with pending request via @extra if present
        if let extra = response.extra, pendingRequests[extra] != nil {
            if response.isError {
                let code = response.errorCode ?? 0
                let message = response.errorMessage ?? "TDLib error"
                resolvePendingRequest(id: extra, result: .failure(TDLibError.tdlibError(code: code, message: message)))
            } else {
                resolvePendingRequest(id: extra, result: .success(response))
            }
            return
        }

        // Process authorization state updates
        if let type = response.type {
            if type == "updateAuthorizationState" {
                if let stateObj = response.object(forKey: "authorization_state"),
                   let stateType = stateObj.type {
                    handleAuthStateUpdate(stateType)
                }
            } else if type == "updateFile" {
                // Separate latest-value progress coalescing from guaranteed terminal states
                if let file = response.object(forKey: "file"),
                   let fileID = file.int64(forKey: "id") {
                    let isCompleted = file.object(forKey: "local")?.bool(forKey: "is_downloading_completed") == true
                        || file.object(forKey: "remote")?.bool(forKey: "is_uploading_completed") == true

                    if isCompleted {
                        // Terminal state: evict from progress tracking and guarantee delivery
                        fileProgressEmittedTimes.removeValue(forKey: fileID)
                    } else {
                        // Intermediate progress: coalesce to ~2 Hz
                        let now = ProcessInfo.processInfo.systemUptime
                        let lastTime = fileProgressEmittedTimes[fileID] ?? 0
                        if now - lastTime < 0.5 {
                            return
                        }
                        // Prune cache if over capacity
                        if fileProgressEmittedTimes.count >= Self.maxTrackedFiles {
                            fileProgressEmittedTimes.removeAll(keepingCapacity: true)
                        }
                        fileProgressEmittedTimes[fileID] = now
                    }
                }
            }
        }

        // Broadcast to all active update listeners
        for continuation in updateContinuations.values {
            continuation.yield(response)
        }
    }

    private func handleAuthStateUpdate(_ stateType: String) {
        let oldState = currentAuthState
        switch stateType {
        case "authorizationStateWaitTdlibParameters":
            currentAuthState = .waitTdlibParameters
        case "authorizationStateWaitPhoneNumber":
            currentAuthState = .waitPhoneNumber
        case "authorizationStateWaitCode":
            currentAuthState = .waitCode
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
            completeClosure()
        default:
            break
        }

        if oldState != currentAuthState {
            Task { [weak self] in
                try? await self?.emitDiagnostic(
                    .enabledChanged,
                    decision: .proceed,
                    severity: .info
                )
            }
        }
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
        return try await task.value
    }

    private func performClose() async throws {
        guard let clientID, !isTerminated else { return }
        self.isClosing = true
        self.currentAuthState = .closing

        // Send close command to TDLib
        let closeReq: [String: Any] = ["@type": "close"]
        if let closeJSON = try? TDLibJSON.serializeRequest(closeReq) {
            bridge.send(clientID: clientID, jsonRequest: closeJSON)
        }

        // Await native confirmation with finite bounded deadline (10 seconds)
        let maxWaitSeconds: TimeInterval = 10.0
        let start = ProcessInfo.processInfo.systemUptime
        while currentAuthState != .closed && (ProcessInfo.processInfo.systemUptime - start) < maxWaitSeconds {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        if currentAuthState != .closed {
            // Unresolved close deadline: do NOT fabricate closed state
            currentAuthState = .uncertain
            try? await emitDiagnostic(
                .failure,
                decision: .wait,
                severity: .error,
                failure: SafeFailure(.invariant, domain: .tdlib, cause: .interrupted)
            )
            throw TDLibError.unresolvedClose("TDLib did not acknowledge authorizationStateClosed within \(maxWaitSeconds)s.")
        }
    }

    private func completeClosure() {
        guard !isTerminated else { return }
        isTerminated = true
        isClosing = false
        currentAuthState = .closed

        // Cancel and resolve all pending requests
        for id in pendingRequests.keys {
            resolvePendingRequest(id: id, result: .failure(TDLibError.clientClosed))
        }
        pendingRequests.removeAll()

        // Terminate all update streams
        for continuation in updateContinuations.values {
            continuation.finish()
        }
        updateContinuations.removeAll()
        fileProgressEmittedTimes.removeAll()

        if let cid = clientID {
            Task { [receiver] in
                await receiver.unregisterSession(clientID: cid)
            }
        }
        clientID = nil

        Task { [weak self] in
            try? await self?.emitDiagnostic(.finalization, decision: .proceed, severity: .info)
        }
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
        try await diagnosticSink(operation, context, decision, severity, failure, duration, bytes, expectedBytes)
    }
}
