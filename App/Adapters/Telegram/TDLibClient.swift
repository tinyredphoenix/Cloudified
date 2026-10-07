import Foundation
import CloudifiedCore

/// High-level client coordinating TDLib session lifecycle, credentials, and authentication flows.
/// Does not fabricate fake Connected or fake receipts; surfaces real native states for Phase 4-B.
public actor TDLibClient {
    private let sessionID: String
    private let credentialStore: KeychainCredentialStore
    private let session: TDLibSession

    public init(
        sessionID: String = "primary",
        credentialStore: KeychainCredentialStore = KeychainCredentialStore(),
        session: TDLibSession = TDLibSession()
    ) {
        self.sessionID = sessionID
        self.credentialStore = credentialStore
        self.session = session
    }

    /// Current authorization state from the session.
    public var authorizationState: TDLibAuthorizationState {
        get async {
            await session.authState
        }
    }

    /// Whether this client is currently closed.
    public var isClosed: Bool {
        get async {
            await session.isClosed
        }
    }

    /// Initializes and starts the native TDLib session with the given filesystem parameters.
    public func start(
        databaseDirectory: String,
        filesDirectory: String,
        appVersion: String = "1.0.0"
    ) async throws {
        let cred = try credentialStore.loadTelegramCredential(forSession: sessionID)
        let dbKey = try credentialStore.getOrCreateTDLibDatabaseKey(forSession: sessionID)

        _ = try await session.start()

        // Wait for waitTdlibParameters or send parameters
        let params: [String: Any] = [
            "@type": "setTdlibParameters",
            "database_directory": databaseDirectory,
            "files_directory": filesDirectory,
            "use_file_database": true,
            "use_chat_info_database": true,
            "use_message_database": true,
            "use_secret_chats": false,
            "api_id": cred.apiId,
            "api_hash": cred.apiHash,
            "system_language_code": "en",
            "device_model": "iOS",
            "system_version": "iOS 26",
            "application_version": appVersion,
            "enable_storage_optimizer": true
        ]

        _ = try await session.sendRequest(params)

        // Provide encryption key
        let keyReq: [String: Any] = [
            "@type": "checkDatabaseEncryptionKey",
            "encryption_key": dbKey
        ]
        _ = try await session.sendRequest(keyReq)
    }

    /// Submits a phone number for user authentication.
    public func setAuthenticationPhoneNumber(_ phoneNumber: String) async throws {
        let req: [String: Any] = [
            "@type": "setAuthenticationPhoneNumber",
            "phone_number": phoneNumber
        ]
        _ = try await session.sendRequest(req)
    }

    /// Submits an SMS / Telegram verification code.
    public func checkAuthenticationCode(_ code: String) async throws {
        let req: [String: Any] = [
            "@type": "checkAuthenticationCode",
            "code": code
        ]
        _ = try await session.sendRequest(req)
    }

    /// Submits a 2FA cloud password if enabled on the account.
    public func checkAuthenticationPassword(_ password: String) async throws {
        let req: [String: Any] = [
            "@type": "checkAuthenticationPassword",
            "password": password
        ]
        _ = try await session.sendRequest(req)
    }

    /// Retrieves information about the authenticated user.
    public func getMe() async throws -> TDLibResponse {
        let req: [String: Any] = ["@type": "getMe"]
        return try await session.sendRequest(req)
    }

    /// Streams raw updates from the underlying TDLib session.
    public func updates() async -> AsyncStream<TDLibResponse> {
        await session.updateStream()
    }

    /// Closes the client and waits for native TDLib session termination.
    public func close() async throws {
        try await session.close()
    }

    // MARK: - Error Classification

    /// Maps TDLib error codes and bridge errors to Core SafeFailure.
    public static func classify(_ error: any Error) -> SafeFailure {
        if let tdErr = error as? TDLibError {
            switch tdErr {
            case .nativeLibraryMissing:
                return SafeFailure(.sourceUnavailable, domain: .tdlib, cause: .unknown)
            case .clientClosed:
                return SafeFailure(.transfer, domain: .tdlib, cause: .interrupted)
            case .timeout:
                return SafeFailure(.timeout, domain: .tdlib, cause: .deadlineExceeded)
            case .tdlibError(let code, _):
                if code == 401 {
                    return SafeFailure(.authentication, domain: .tdlib, code: Int(code), cause: .loginRequired)
                }
                if code == 429 {
                    return SafeFailure(.rateLimit, domain: .tdlib, code: Int(code), cause: .serverRateLimit)
                }
                if code == 400 {
                    return SafeFailure(.transfer, domain: .tdlib, code: Int(code), cause: .formatRejected)
                }
                return SafeFailure(.transfer, domain: .tdlib, code: Int(code), cause: .providerRejected)
            default:
                return SafeFailure(.transfer, domain: .tdlib, cause: .unknown)
            }
        }
        return SafeFailure(.transfer, domain: .tdlib, cause: .unknown)
    }
}
