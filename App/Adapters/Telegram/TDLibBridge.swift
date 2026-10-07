import Foundation
import CTDLib

/// Classified errors from the native TDLib C bridge.
public enum TDLibError: LocalizedError, Sendable, Equatable {
    case nativeLibraryMissing(String)
    case clientCreationFailed
    case clientClosed
    case timeout
    case executionFailed(String)
    case invalidResponse
    case tdlibError(code: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case .nativeLibraryMissing(let msg):
            return "Native TDLib library missing: \(msg)"
        case .clientCreationFailed:
            return "Failed to create TDLib client instance."
        case .clientClosed:
            return "TDLib client session has been closed."
        case .timeout:
            return "TDLib request timed out."
        case .executionFailed(let msg):
            return "TDLib execution failed: \(msg)"
        case .invalidResponse:
            return "Invalid JSON response from TDLib."
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
    /// Fails fast with `TDLibError.nativeLibraryMissing` if the native library is not linked.
    public func createClientID() throws -> Int32 {
        let clientID = td_create_client_id()
        guard clientID > 0 else {
            throw TDLibError.nativeLibraryMissing(
                "libtdjson native binary has not been assembled. Run scripts/assemble_tdlib.sh or cloud CI build."
            )
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
