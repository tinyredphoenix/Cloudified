import Foundation
import CloudifiedCore

/// App-owned actor isolating the pinned GPMCClient implementation and credential vault.
/// Handles session lifecycle, authenticated RPC dispatch, transport injection, and classified error diagnostics
/// while preserving the boundaries required before Phase 4-B critical upload integration.
actor GooglePhotosClientSession {
    private let profileID: String
    private let credentialStore: KeychainCredentialStore
    private let customTransport: (any FileUploadTransport)?
    private let networkPolicy: UploadRequestNetworkPolicy
    private let diagnosticSink: (@Sendable (EventOperation, EventContext, EventDecision, EventSeverity, SafeFailure?, TimeInterval?, Int64?, Int64?) async throws -> Void)?

    private var client: GPMCClient?
    private var isConfigured = false

    init(
        profileID: String,
        credentialStore: KeychainCredentialStore = KeychainCredentialStore(),
        transport: (any FileUploadTransport)? = nil,
        networkPolicy: UploadRequestNetworkPolicy = UploadRequestNetworkPolicy(),
        diagnosticSink: (@Sendable (EventOperation, EventContext, EventDecision, EventSeverity, SafeFailure?, TimeInterval?, Int64?, Int64?) async throws -> Void)? = nil
    ) throws {
        try KeychainCredentialStore.validateProfileID(profileID)
        self.profileID = profileID
        self.credentialStore = credentialStore
        self.customTransport = transport
        self.networkPolicy = networkPolicy
        self.diagnosticSink = diagnosticSink
    }

    /// Whether a credential has been configured and loaded for this profile.
    var hasConfiguredCredential: Bool {
        isConfigured
    }

    /// Connects using an existing stored credential from Keychain.
    func loadSavedSession() async throws {
        let cred = try credentialStore.loadGoogleCredential(forProfile: profileID)
        let gpmc = try GPMCClient(authData: cred.authData, networkPolicy: networkPolicy, fileUploadTransport: customTransport)
        self.client = gpmc
        self.isConfigured = true

        try await emitDiagnostic(.appStart, decision: .proceed, severity: .info)
    }

    /// Connects by exchanging a freshly acquired OAuth authorization token.
    func connect(oauthToken: String) async throws -> StoredGoogleCredential {
        let policy = networkPolicy
        let result = try await GoogleTokenExchange.run(oauthToken: oauthToken, requestPolicy: { request in
            policy.apply(to: &request)
        })
        let cred = StoredGoogleCredential(
            androidId: result.androidId,
            email: result.email,
            masterToken: result.masterToken,
            authData: result.authData,
            connectedAt: Date()
        )
        try credentialStore.saveGoogleCredential(cred, forProfile: profileID)

        let gpmc = try GPMCClient(authData: cred.authData, networkPolicy: networkPolicy, fileUploadTransport: customTransport)
        self.client = gpmc
        self.isConfigured = true

        try await emitDiagnostic(.enabledChanged, decision: .proceed, severity: .info)
        return cred
    }

    /// Clears active client state and removes stored credentials from Keychain.
    func disconnect() async throws {
        client = nil
        isConfigured = false
        try credentialStore.deleteGoogleCredential(forProfile: profileID)

        try await emitDiagnostic(.finalization, decision: .proceed, severity: .info)
    }

    private func requireClient() throws -> GPMCClient {
        guard let client else {
            throw SafeFailure(.authentication, domain: .google, cause: .loginRequired)
        }
        return client
    }

    /// Authenticates or refreshes the underlying access token.
    func authenticate() async throws {
        let client = try requireClient()
        do {
            try await client.authenticate()
        } catch let err as GPMCError {
            let classified = Self.classify(err)
            try await emitDiagnostic(.failure, decision: .wait, severity: .error, failure: classified)
            throw classified
        }
    }

    /// Validates read access by running an authenticated dry-run hash check.
    func validateReadAccess() async throws {
        let client = try requireClient()
        do {
            try await client.validateReadAccess()
        } catch let err as GPMCError {
            let classified = Self.classify(err)
            try await emitDiagnostic(.failure, decision: .wait, severity: .error, failure: classified)
            throw classified
        }
    }

    /// Checks remote presence by SHA-1 hash without uploading.
    func checkPresence(sha1: Data, asLivePhotoMotion: Bool = false) async throws -> String? {
        let client = try requireClient()
        do {
            return try await client.remoteMediaKey(sha1: sha1, asLivePhotoMotion: asLivePhotoMotion)
        } catch let err as GPMCError {
            let classified = Self.classify(err)
            try await emitDiagnostic(.failure, decision: .wait, severity: .error, failure: classified)
            throw classified
        }
    }

    /// Prepares an upload session for a standard photo or video original.
    func prepareUpload(
        file: URL,
        filename: String,
        modified: Date? = nil,
        phase: @escaping @Sendable (UploadPhase) -> Void
    ) async throws -> UploadPreparation {
        let client = try requireClient()
        do {
            return try await client.prepareUpload(file: file, filename: filename, modified: modified, phase: phase)
        } catch let err as GPMCError {
            let classified = Self.classify(err)
            try await emitDiagnostic(.failure, decision: .wait, severity: .error, failure: classified)
            throw classified
        }
    }

    /// Prepares an upload session for the motion video of a Live Photo.
    func prepareMotionUpload(
        file: URL,
        filename: String,
        modified: Date? = nil,
        stillHash: Data,
        phase: @escaping @Sendable (UploadPhase) -> Void
    ) async throws -> UploadPreparation {
        let client = try requireClient()
        do {
            return try await client.prepareMotionUpload(
                file: file,
                filename: filename,
                modified: modified,
                stillHash: stillHash,
                phase: phase
            )
        } catch let err as GPMCError {
            let classified = Self.classify(err)
            try await emitDiagnostic(.failure, decision: .wait, severity: .error, failure: classified)
            throw classified
        }
    }

    /// Transfers file bytes to the resumable upload URL using the configured transport.
    func transfer(
        prepared: PreparedUpload,
        file: URL,
        transferID: UUID,
        foreground: Bool = false,
        phase: @escaping @Sendable (UploadPhase) -> Void
    ) async throws -> PreparedUpload {
        let client = try requireClient()
        do {
            return try await client.transfer(prepared, file: file, transferID: transferID, foreground: foreground, phase: phase)
        } catch let err as GPMCError {
            let classified = Self.classify(err)
            try await emitDiagnostic(.failure, decision: .wait, severity: .error, failure: classified)
            throw classified
        }
    }

    /// Commits the upload receipt to Google Photos.
    func commit(
        prepared: PreparedUpload,
        useQuota: Bool,
        saver: Bool,
        pairedStillHash: Data? = nil,
        phase: @escaping @Sendable (UploadPhase) -> Void
    ) async throws -> UploadOutcome {
        let client = try requireClient()
        do {
            return try await client.commit(prepared, useQuota: useQuota, saver: saver, pairedStillHash: pairedStillHash, phase: phase)
        } catch let err as GPMCError {
            let classified = Self.classify(err)
            try await emitDiagnostic(.failure, decision: .wait, severity: .error, failure: classified)
            throw classified
        }
    }

    /// Cancels a running background transfer.
    func cancelTransfer(_ transferID: UUID) async {
        guard let client else { return }
        await client.cancelTransfer(transferID)
    }

    /// Forgets a completed transfer token association.
    func forgetTransfer(_ transferID: UUID) async {
        guard let client else { return }
        await client.forgetTransfer(transferID)
    }

    private func emitDiagnostic(
        _ operation: EventOperation,
        decision: EventDecision,
        severity: EventSeverity,
        failure: SafeFailure? = nil
    ) async throws {
        guard let diagnosticSink else { return }
        let context = EventContext(origin: .google)
        try await diagnosticSink(operation, context, decision, severity, failure, nil, nil, nil)
    }

    // MARK: - Error Classification

    /// Maps GPMC protocol errors to Core classified SafeFailure values.
    static func classify(_ error: GPMCError) -> SafeFailure {
        switch error.kind {
        case .credentialRejected:
            return SafeFailure(.authentication, domain: .google, cause: .loginRequired)
        case .tokenBound:
            return SafeFailure(.authentication, domain: .google, cause: .loginRequired)
        case .storageFull:
            return SafeFailure(.quota, domain: .google, cause: .quotaExceeded)
        case .transport:
            return SafeFailure(.connectivity, domain: .google, cause: .offline)
        case .invalidUploadReceipt:
            return SafeFailure(.transfer, domain: .google, cause: .providerRejected)
        case .pairedPhotoMissing:
            return SafeFailure(.transfer, domain: .google, cause: .unknown)
        case .server(let code):
            if code == 429 {
                return SafeFailure(.rateLimit, domain: .google, code: code, cause: .serverRateLimit)
            }
            if code == 408 {
                return SafeFailure(.timeout, domain: .google, code: code, cause: .deadlineExceeded)
            }
            return SafeFailure(.transfer, domain: .google, code: code, cause: .providerRejected)
        case .malformed:
            return SafeFailure(.transfer, domain: .google, cause: .formatRejected)
        }
    }
}
