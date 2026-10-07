import Foundation
import CloudifiedCore

/// High-level client coordinating TDLib session lifecycle, credentials, and authentication flows.
/// Does not fabricate fake Connected states or fake receipts; surfaces real native states for Phase 4-B.
public actor TDLibClient {
    private let profileID: String
    private let credentialStore: KeychainCredentialStore
    private let session: TDLibSession
    private let diagnosticSink: (@Sendable (EventOperation, EventContext, EventDecision, EventSeverity, SafeFailure?, TimeInterval?, Int64?, Int64?) async throws -> Void)?

    public init(
        profileID: String,
        credentialStore: KeychainCredentialStore = KeychainCredentialStore(),
        session: TDLibSession? = nil,
        diagnosticSink: (@Sendable (EventOperation, EventContext, EventDecision, EventSeverity, SafeFailure?, TimeInterval?, Int64?, Int64?) async throws -> Void)? = nil
    ) throws {
        try KeychainCredentialStore.validateProfileID(profileID)
        self.profileID = profileID
        self.credentialStore = credentialStore
        self.diagnosticSink = diagnosticSink
        self.session = session ?? TDLibSession(diagnosticSink: diagnosticSink)
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

    /// A delivery or diagnostic gap requires reconciliation before further commands.
    public var requiresReconciliation: Bool {
        get async { await session.requiresReconciliation }
    }

    /// Initializes and starts the native TDLib session with the given filesystem parameters.
    /// Strictly matches pinned td_api.tl `setTdlibParameters` schema with base64 encryption key.
    public func start(
        databaseDirectory: String,
        filesDirectory: String,
        appVersion: String = "1.0.0"
    ) async throws {
        let cred = try credentialStore.loadTelegramCredential(forProfile: profileID)
        let dbKey = try credentialStore.getOrCreateTDLibDatabaseKey(forProfile: profileID)

        _ = try await session.start()

        let params = TDLibParameters(
            apiId: cred.apiId,
            apiHash: cred.apiHash,
            databaseDirectory: databaseDirectory,
            filesDirectory: filesDirectory,
            databaseEncryptionKey: dbKey,
            useFileDatabase: true,
            useChatInfoDatabase: true,
            useMessageDatabase: true,
            useSecretChats: false,
            applicationVersion: appVersion,
            deviceModel: "iPhone",
            systemVersion: "iOS 26",
            systemLanguageCode: "en"
        )

        do {
            _ = try await session.sendRequest(params.toRequestDictionary())
        } catch {
            if error is CoreError || error is CredentialError || error is CancellationError { throw error }
            let classified = Self.classify(error)
            try await emitDiagnostic(.failure, decision: .wait, severity: .error, failure: classified)
            throw classified
        }
    }

    /// Submits a phone number for user authentication.
    public func setAuthenticationPhoneNumber(_ phoneNumber: String) async throws {
        let req: [String: Any] = [
            "@type": "setAuthenticationPhoneNumber",
            "phone_number": phoneNumber
        ]
        do {
            _ = try await session.sendRequest(req)
        } catch {
            if error is CoreError || error is CredentialError || error is CancellationError { throw error }
            let classified = Self.classify(error)
            try await emitDiagnostic(.failure, decision: .wait, severity: .error, failure: classified)
            throw classified
        }
    }

    /// Submits an SMS / Telegram verification code.
    public func checkAuthenticationCode(_ code: String) async throws {
        let req: [String: Any] = [
            "@type": "checkAuthenticationCode",
            "code": code
        ]
        do {
            _ = try await session.sendRequest(req)
        } catch {
            if error is CoreError || error is CredentialError || error is CancellationError { throw error }
            let classified = Self.classify(error)
            try await emitDiagnostic(.failure, decision: .wait, severity: .error, failure: classified)
            throw classified
        }
    }

    /// Submits a 2FA cloud password if enabled on the account.
    public func checkAuthenticationPassword(_ password: String) async throws {
        let req: [String: Any] = [
            "@type": "checkAuthenticationPassword",
            "password": password
        ]
        do {
            _ = try await session.sendRequest(req)
        } catch {
            if error is CoreError || error is CredentialError || error is CancellationError { throw error }
            let classified = Self.classify(error)
            try await emitDiagnostic(.failure, decision: .wait, severity: .error, failure: classified)
            throw classified
        }
    }

    /// Retrieves information about the authenticated user.
    public func getMe() async throws -> TDLibResponse {
        let req: [String: Any] = ["@type": "getMe"]
        do {
            return try await session.sendRequest(req)
        } catch {
            if error is CoreError || error is CredentialError || error is CancellationError { throw error }
            let classified = Self.classify(error)
            try await emitDiagnostic(.failure, decision: .wait, severity: .error, failure: classified)
            throw classified
        }
    }

    /// Streams raw updates from the underlying TDLib session with bounded buffering.
    public func updates() async throws -> AsyncThrowingStream<TDLibResponse, any Error> {
        try await session.updateStream()
    }

    /// Closes the client and waits for native TDLib session termination.
    public func close() async throws {
        do {
            try await session.close()
        } catch {
            if error is CoreError || error is CredentialError || error is CancellationError { throw error }
            let classified = Self.classify(error)
            try await emitDiagnostic(.failure, decision: .wait, severity: .error, failure: classified)
            throw classified
        }
    }

    private func emitDiagnostic(
        _ operation: EventOperation,
        decision: EventDecision,
        severity: EventSeverity,
        failure: SafeFailure? = nil
    ) async throws {
        guard let diagnosticSink else { return }
        let context = EventContext(origin: .telegram)
        try await diagnosticSink(operation, context, decision, severity, failure, nil, nil, nil)
    }

    // MARK: - Error Classification

    /// Maps TDLib error codes and bridge errors to Core SafeFailure.
    /// Never exposes raw secrets, tokens, or private paths.
    public static func classify(_ error: any Error) -> SafeFailure {
        if let safeFailure = error as? SafeFailure {
            return safeFailure
        }
        if let tdErr = error as? TDLibError {
            switch tdErr {
            case .nativeLibraryMissing, .clientCreationFailed:
                return SafeFailure(.sourceUnavailable, domain: .tdlib, cause: .unknown)
            case .clientClosed:
                return SafeFailure(.transfer, domain: .tdlib, cause: .interrupted)
            case .unresolvedClose:
                return SafeFailure(.invariant, domain: .tdlib, cause: .interrupted)
            case .timeout:
                return SafeFailure(.timeout, domain: .tdlib, cause: .deadlineExceeded)
            case .capacityExceeded:
                return SafeFailure(.transfer, domain: .tdlib, cause: .providerRejected)
            case .malformedResponse:
                return SafeFailure(.transfer, domain: .tdlib, cause: .formatRejected)
            case .invalidParameter:
                return SafeFailure(.transfer, domain: .tdlib, cause: .formatRejected)
            case .executionFailed:
                return SafeFailure(.transfer, domain: .tdlib, cause: .unknown)
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
            }
        }
        return SafeFailure(.transfer, domain: .tdlib, cause: .unknown)
    }
}
