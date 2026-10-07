import Foundation
import CTDLib

/// Classified errors from the native TDLib C bridge.
public enum TDLibError: LocalizedError, Sendable, Equatable {
    case nativeLibraryMissing(String)
    case clientCreationFailed
    case clientClosed
    case unresolvedClose(String)
    case timeout
    case capacityExceeded(String)
    case executionFailed(String)
    case malformedResponse
    case invalidParameter(String)
    case tdlibError(code: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case .nativeLibraryMissing:
            return "Native TDLib library is unavailable."
        case .clientCreationFailed:
            return "Failed to create TDLib client instance."
        case .clientClosed:
            return "TDLib client session has been closed."
        case .unresolvedClose:
            return "TDLib has not confirmed closure; resource ownership remains unresolved."
        case .timeout:
            return "TDLib request timed out."
        case .capacityExceeded:
            return "TDLib delivery capacity exceeded; reconciliation is required."
        case .executionFailed:
            return "TDLib could not complete the operation."
        case .malformedResponse:
            return "Malformed or oversized JSON response from TDLib."
        case .invalidParameter:
            return "Invalid TDLib request parameters."
        case .tdlibError(let code, _):
            return "TDLib rejected the request (code \(code))."
        }
    }
}

/// Narrow, low-level Swift bridge to TDLib's C JSON interface.
/// Strictly honors the C pointer ownership and lifetime rules defined in `td_json_client.h`:
/// pointers returned by `td_receive` / `td_execute` are copied immediately into Swift
/// memory before the next call on that thread.
public final class TDLibBridge: Sendable {
    // Returned native pointers stay protected through the copy, including execute.
    private static let pointerLock = NSLock()
    public init() {}

    /// Creates an opaque TDLib client identifier.
    /// Fails fast with `TDLibError.clientCreationFailed` if client ID creation fails.
    public func createClientID() throws -> Int32 {
        let clientID = td_create_client_id()
        guard clientID > 0 else {
            throw TDLibError.clientCreationFailed
        }
        return clientID
    }

    /// Sends a JSON request string to TDLib for the given client.
    public func send(clientID: Int32, jsonRequest: String) {
        jsonRequest.withCString { cStr in
            td_send(clientID, cStr)
        }
    }

    /// Receives the next response or update from TDLib with the specified timeout.
    /// Must only be called from a single process-global thread/task.
    /// The returned UTF-8 string is copied immediately from TDLib's memory.
    fileprivate func receive(timeout: Double) throws -> String? {
        Self.pointerLock.lock(); defer { Self.pointerLock.unlock() }
        guard let cStr = td_receive(timeout) else {
            return nil
        }
        return try Self.copyResponse(cStr)
    }

    /// Synchronously executes a service TDLib request.
    /// The returned UTF-8 string is copied immediately from TDLib's memory.
    public func execute(jsonRequest: String) throws -> String? {
        Self.pointerLock.lock(); defer { Self.pointerLock.unlock() }
        return try jsonRequest.withCString { cStr in
            guard let cStrRes = td_execute(cStr) else {
                return nil
            }
            return try Self.copyResponse(cStrRes)
        }
    }

    /// Bound the native read before allocating a Swift string; invalid UTF-8 fails.
    private static func copyResponse(_ pointer: UnsafePointer<CChar>) throws -> String {
        let length = strnlen(pointer, TDLibJSON.maxJSONBytes + 1)
        guard length <= TDLibJSON.maxJSONBytes else { throw TDLibError.malformedResponse }
        let bytes = UnsafeRawPointer(pointer).assumingMemoryBound(to: UInt8.self)
        guard let string = String(bytes: UnsafeBufferPointer(start: bytes, count: length), encoding: .utf8) else {
            throw TDLibError.malformedResponse
        }
        return string
    }

    /// Sets the native log message callback and verbosity level.
    public func setLogMessageCallback(maxVerbosity: Int32, callback: td_log_message_callback_ptr?) {
        td_set_log_message_callback(maxVerbosity, callback)
    }
}

/// Process-wide receiver router that guarantees exactly one Task calls `td_receive`,
/// routing updates by `@client_id` to registered session actors without busy-spinning.
public actor TDLibProcessReceiver {
    public static let shared = TDLibProcessReceiver()

    private let bridge: TDLibBridge
    private var activeSessions: [Int32: @Sendable (Result<TDLibResponse, TDLibError>) async -> Void] = [:]
    private var receiveTask: Task<Void, Never>?
    private var isRunning: Bool = false

    private init(bridge: TDLibBridge = TDLibBridge()) {
        self.bridge = bridge
    }

    public func registerSession(clientID: Int32, handler: @escaping @Sendable (Result<TDLibResponse, TDLibError>) async -> Void) {
        activeSessions[clientID] = handler
        startReceiveLoopIfNeeded()
    }

    public func unregisterSession(clientID: Int32) {
        activeSessions.removeValue(forKey: clientID)
    }

    public func hasActiveSessions() -> Bool {
        !activeSessions.isEmpty
    }

    private func startReceiveLoopIfNeeded() {
        guard !isRunning else { return }
        isRunning = true

        receiveTask = Task.detached(priority: .userInitiated) { [weak self, bridge] in
            while !Task.isCancelled {
                guard let self else { break }
                let hasSessions = await self.hasActiveSessions()
                if !hasSessions {
                    // Avoid busy-spinning when no sessions are active
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                    continue
                }

                do {
                    if let jsonString = try bridge.receive(timeout: 1.0) {
                        await self.routeIncomingJSON(jsonString)
                    }
                } catch {
                    await self.reportProtocolFailure()
                }
            }
        }
    }

    private func routeIncomingJSON(_ jsonString: String) async {
        let response: TDLibResponse
        do { response = try TDLibJSON.parse(jsonString) }
        catch { await reportProtocolFailure(); return }
        guard let targetClientID = response.clientID, targetClientID > 0 else {
            await reportProtocolFailure()
            return
        }
        guard let handler = activeSessions[targetClientID] else { return }
        // An unknown/old client cannot change another account's auth or close state.
        await handler(.success(response))
    }

    private func reportProtocolFailure() async {
        // Corrupt routing cannot establish the affected account; fence all owned
        // sessions instead of losing a possible acceptance/close confirmation.
        for handler in Array(activeSessions.values) {
            await handler(.failure(.malformedResponse))
        }
    }
}
