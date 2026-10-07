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
        case .nativeLibraryMissing(let msg):
            return "Native TDLib library missing: \(msg)"
        case .clientCreationFailed:
            return "Failed to create TDLib client instance."
        case .clientClosed:
            return "TDLib client session has been closed."
        case .unresolvedClose(let msg):
            return "TDLib close deadline expired without native closed confirmation: \(msg)"
        case .timeout:
            return "TDLib request timed out."
        case .capacityExceeded(let msg):
            return "TDLib capacity exceeded: \(msg)"
        case .executionFailed(let msg):
            return "TDLib execution failed: \(msg)"
        case .malformedResponse:
            return "Malformed or oversized JSON response from TDLib."
        case .invalidParameter(let msg):
            return "Invalid TDLib parameter: \(msg)"
        case .tdlibError(let code, let msg):
            return "TDLib error (\(code)): \(msg)"
        }
    }
}

/// Narrow, low-level Swift bridge to TDLib's C JSON interface.
/// Strictly honors the C pointer ownership and lifetime rules defined in `td_json_client.h`:
/// pointers returned by `td_receive` / `td_execute` are copied immediately into Swift
/// memory before the next call on that thread.
public final class TDLibBridge: Sendable {
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
    public func receive(timeout: Double) -> String? {
        guard let cStr = td_receive(timeout) else {
            return nil
        }
        return String(cString: cStr)
    }

    /// Synchronously executes a service TDLib request.
    /// The returned UTF-8 string is copied immediately from TDLib's memory.
    public func execute(jsonRequest: String) -> String? {
        jsonRequest.withCString { cStr in
            guard let cStrRes = td_execute(cStr) else {
                return nil
            }
            return String(cString: cStrRes)
        }
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
    private var activeSessions: [Int32: @Sendable (String) async -> Void] = [:]
    private var receiveTask: Task<Void, Never>?
    private var isRunning: Bool = false

    public init(bridge: TDLibBridge = TDLibBridge()) {
        self.bridge = bridge
    }

    public func registerSession(clientID: Int32, handler: @escaping @Sendable (String) async -> Void) {
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

                if let jsonString = bridge.receive(timeout: 1.0) {
                    await self.routeIncomingJSON(jsonString)
                }
            }
        }
    }

    private func routeIncomingJSON(_ jsonString: String) async {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        var targetClientID: Int32?
        if let cid = dict["@client_id"] as? Int32 {
            targetClientID = cid
        } else if let cid = dict["@client_id"] as? Int {
            targetClientID = Int32(cid)
        } else if let num = dict["@client_id"] as? NSNumber {
            targetClientID = num.int32Value
        }

        if let cid = targetClientID, let handler = activeSessions[cid] {
            await handler(jsonString)
            return
        }

        // Broadcast to all active sessions if unrouted
        for handler in activeSessions.values {
            await handler(jsonString)
        }
    }
}
