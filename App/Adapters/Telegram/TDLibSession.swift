import Foundation
import os
import CloudifiedCore

/// High-level authorization states surfaced by TDLib.
public enum TDLibAuthorizationState: Sendable, Equatable {
    case uninitialized
    case waitTdlibParameters
    case waitEncryptionKey
    case waitPhoneNumber
    case waitCode
    case waitPassword
    case ready
    case loggingOut
    case closing
    case closed
}

/// Parameters required to initialize a TDLib native database and network session.
public struct TDLibParameters: Sendable {
    public let apiId: Int32
    public let apiHash: String
    public let databaseDirectory: String
    public let filesDirectory: String
    public let useFileDatabase: Bool
    public let useChatInfoDatabase: Bool
    public let useMessageDatabase: Bool
    public let applicationVersion: String
    public let deviceModel: String
    public let systemVersion: String
    public let systemLanguageCode: String

    public init(
        apiId: Int32,
        apiHash: String,
        databaseDirectory: String,
        filesDirectory: String,
        useFileDatabase: Bool = true,
        useChatInfoDatabase: Bool = true,
        useMessageDatabase: Bool = true,
        applicationVersion: String = "1.0.0",
        deviceModel: String = "iOS",
        systemVersion: String = "iOS 26",
        systemLanguageCode: String = "en"
    ) {
        self.apiId = apiId
        self.apiHash = apiHash
        self.databaseDirectory = databaseDirectory
        self.filesDirectory = filesDirectory
        self.useFileDatabase = useFileDatabase
        self.useChatInfoDatabase = useChatInfoDatabase
        self.useMessageDatabase = useMessageDatabase
        self.applicationVersion = applicationVersion
        self.deviceModel = deviceModel
        self.systemVersion = systemVersion
        self.systemLanguageCode = systemLanguageCode
    }
}

/// Owns a single active TDLib client session.
/// Manages off-main receiving, request correlation with deadlines, update distribution,
/// and deterministic terminal closing.
public actor TDLibSession {
    private let bridge: TDLibBridge
    private var clientID: Int32?
    private var receiveTask: Task<Void, Never>?
    private var pendingRequests: [String: CheckedContinuation<TDLibResponse, any Error>] = [:]
    private var updateContinuations: [UUID: AsyncStream<TDLibResponse>.Continuation] = [:]

    private var currentAuthState: TDLibAuthorizationState = .uninitialized
    private var isClosing = false
    private var isTerminated = false

    // Progress coalescing state for file updates: file_id -> last emitted uptime
    private var fileProgressEmittedTimes: [Int64: TimeInterval] = [:]

    public init(bridge: TDLibBridge = TDLibBridge()) {
        self.bridge = bridge
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

    /// Initializes and starts the owned TDLib client and its background receive loop.
    public func start() async throws -> Int32 {
        guard clientID == nil else {
            throw TDLibError.executionFailed("TDLibSession is already started.")
        }
        let id = try bridge.createClientID()
        self.clientID = id
        self.isTerminated = false
        self.isClosing = false

        // Launch dedicated off-main receive loop
        let task = Task.detached(priority: .userInitiated) { [weak self, bridge] in
            while true {
                guard let self else { break }
                let terminated: Bool = await self.isClosed
                if terminated { break }

                if let jsonString = bridge.receive(timeout: 1.0) {
                    await self.handleIncomingJSON(jsonString)
                }
            }
        }
        self.receiveTask = task
        return id
    }

    /// Subscribes to the broadcast stream of TDLib updates.
    public func updateStream() -> AsyncStream<TDLibResponse> {
        let streamID = UUID()
        return AsyncStream { continuation in
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
    public func sendRequest(_ request: [String: Any], timeout: TimeInterval = 60.0) async throws -> TDLibResponse {
        guard let clientID, !isTerminated else {
            throw TDLibError.clientClosed
        }

        var mutableReq = request
        let extraID = UUID().uuidString
        mutableReq["@extra"] = extraID

        let jsonString = try TDLibJSON.serialize(mutableReq)

        return try await withThrowingTaskGroup(of: TDLibResponse.self) { group in
            group.addTask { [self] in
                try await withCheckedThrowingContinuation { continuation in
                    Task { [self] in
                        await self.registerPendingRequest(id: extraID, continuation: continuation)
                        self.bridge.send(clientID: clientID, jsonRequest: jsonString)
                    }
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TDLibError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func registerPendingRequest(id: String, continuation: CheckedContinuation<TDLibResponse, any Error>) {
        if isTerminated {
            continuation.resume(throwing: TDLibError.clientClosed)
            return
        }
        pendingRequests[id] = continuation
    }

    // MARK: - Incoming Message Handling

    private func handleIncomingJSON(_ jsonString: String) {
        guard let dict = TDLibJSON.parseDictionary(jsonString) else {
            return
        }
        let response = TDLibResponse(dict)

        // Check if this is a response correlated with a pending request via @extra
        if let extra = TDLibJSON.parseExtra(dict), let continuation = pendingRequests.removeValue(forKey: extra) {
            if let error = TDLibJSON.parseError(dict) {
                continuation.resume(throwing: TDLibError.tdlibError(code: error.code, message: error.message))
            } else {
                continuation.resume(returning: response)
            }
            return
        }

        // Process authorization state updates
        if let type = TDLibJSON.parseType(dict) {
            if type == "updateAuthorizationState" {
                if let stateObj = dict["authorization_state"] as? [String: Any],
                   let stateType = TDLibJSON.parseType(stateObj) {
                    handleAuthStateUpdate(stateType)
                }
            } else if type == "updateFile" {
                // Rate-limit file progress updates before broadcasting
                if let file = dict["file"] as? [String: Any],
                   let fileID = TDLibJSON.parseID(file["id"]) {
                    let now = ProcessInfo.processInfo.systemUptime
                    let lastTime = fileProgressEmittedTimes[fileID] ?? 0
                    if now - lastTime < 0.5 {
                        return // coalesce noisy progress to ~2 Hz
                    }
                    fileProgressEmittedTimes[fileID] = now
                }
            }
        }

        // Broadcast to all active update listeners
        for continuation in updateContinuations.values {
            continuation.yield(response)
        }
    }

    private func handleAuthStateUpdate(_ stateType: String) {
        switch stateType {
        case "authorizationStateWaitTdlibParameters":
            currentAuthState = .waitTdlibParameters
        case "authorizationStateWaitEncryptionKey":
            currentAuthState = .waitEncryptionKey
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
    }

    // MARK: - Session Termination

    /// Closes the TDLib session and waits for native cleanup.
    public func close() async throws {
        guard let clientID, !isTerminated, !isClosing else {
            return
        }
        isClosing = true

        // Send TDLib close request
        let closeReq: [String: Any] = ["@type": "close"]
        if let reqStr = try? TDLibJSON.serialize(closeReq) {
            bridge.send(clientID: clientID, jsonRequest: reqStr)
        }

        // Bounded wait for authorizationStateClosed or timeout
        let maxWaitSeconds: TimeInterval = 10.0
        let start = ProcessInfo.processInfo.systemUptime
        while currentAuthState != .closed && (ProcessInfo.processInfo.systemUptime - start) < maxWaitSeconds {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        completeClosure()
    }

    private func completeClosure() {
        guard !isTerminated else { return }
        isTerminated = true
        currentAuthState = .closed

        // Cancel all pending continuations
        for continuation in pendingRequests.values {
            continuation.resume(throwing: TDLibError.clientClosed)
        }
        pendingRequests.removeAll()

        // Terminate all update streams
        for continuation in updateContinuations.values {
            continuation.finish()
        }
        updateContinuations.removeAll()

        receiveTask?.cancel()
        receiveTask = nil
        clientID = nil
    }
}
