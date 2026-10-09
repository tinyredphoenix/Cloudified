import Foundation
import Darwin
import CloudifiedCore

/// High-level client coordinating TDLib session lifecycle, credentials, and authentication flows.
/// Does not fabricate fake Connected states or fake receipts; surfaces real native states for Phase 4-B.
struct TDLibRequestRejection: Error, Sendable { let failure: SafeFailure }

public actor TDLibClient {
    let profileID: String
    private let credentialStore: KeychainCredentialStore
    private var isStarting = false
    private var networkType = "networkTypeNone"
    private var appliedNetworkType: String?
    private var isApplyingNetworkPolicy = false
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

    var connectionReady: Bool { get async { await session.connectionReady } }

    /// Resolves and creates canonical disjoint, profile-bound database and files directories
    /// with NSFileProtectionCompleteUntilFirstUserAuthentication and backup exclusion.
    public static func storageURLs(forProfile profileID: String) throws -> (databaseURL: URL, filesURL: URL) {
        try KeychainCredentialStore.validateProfileID(profileID)
        let fileManager = FileManager.default
        let support: URL
        do {
            support = try fileManager.url(for: .applicationSupportDirectory,
                                          in: .userDomainMask, appropriateFor: nil, create: true)
                .resolvingSymlinksInPath()
        } catch { throw storageFailure(error) }
        var parent = support
        for name in ["Cloudified", "Telegram", profileID] {
            parent.appendPathComponent(name, isDirectory: true)
            try prepareDirectory(parent, fileManager: fileManager)
        }
        let database = parent.appendingPathComponent("database", isDirectory: true)
        let files = parent.appendingPathComponent("files", isDirectory: true)
        try prepareDirectory(database, fileManager: fileManager)
        try prepareDirectory(files, fileManager: fileManager)
        return (database, files)
    }

    private static func prepareDirectory(_ url: URL, fileManager: FileManager) throws {
        do {
            guard url.resolvingSymlinksInPath().path == url.standardizedFileURL.path else {
                throw SafeFailure(.sourceUnavailable, domain: .fileSystem, cause: .storagePathConflict)
            }
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
            } catch {
                let value = error as NSError
                // Application Support/Cloudified already exists on first linking;
                // the native profile also survives launches. Accept only an
                // existing real directory, including a concurrent creator.
                guard (value.domain == NSCocoaErrorDomain && value.code == NSFileWriteFileExistsError) ||
                    (value.domain == NSPOSIXErrorDomain && value.code == Int(EEXIST)) else { throw error }
            }
            let existing = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard existing.isDirectory == true, existing.isSymbolicLink != true,
                  url.resolvingSymlinksInPath().path == url.standardizedFileURL.path else {
                throw SafeFailure(.sourceUnavailable, domain: .fileSystem, cause: .storagePathConflict)
            }
            #if os(iOS)
            // Explicitly update existing directories too, not just newly created ones.
            try fileManager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                          ofItemAtPath: url.path)
            #endif
            var directory = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
        } catch let failure as SafeFailure { throw failure }
        catch {
            // A private filesystem path must not escape through NSError prose.
            throw storageFailure(error)
        }
    }

    private static func storageFailure(_ error: any Error) -> SafeFailure {
        let value = error as NSError
        if (value.domain == NSPOSIXErrorDomain && [Int(ENOSPC), Int(EDQUOT)].contains(value.code)) ||
            (value.domain == NSCocoaErrorDomain && value.code == NSFileWriteOutOfSpaceError) {
            return SafeFailure(.diskFull, domain: .fileSystem, code: value.code, cause: .insufficientSpace)
        }
        if (value.domain == NSPOSIXErrorDomain && [Int(EACCES), Int(EPERM)].contains(value.code)) ||
            (value.domain == NSCocoaErrorDomain && [NSFileReadNoPermissionError, NSFileWriteNoPermissionError].contains(value.code)) {
            return SafeFailure(.accessDenied, domain: .fileSystem, code: value.code, cause: .permissionDenied)
        }
        return SafeFailure(.sourceUnavailable, domain: .fileSystem, code: value.code, cause: .storageUnavailable)
    }

    /// Initializes and starts the native TDLib session with the given filesystem parameters.
    /// Strictly matches pinned td_api.tl `setTdlibParameters` schema with base64 encryption key.
    /// Prepares disjoint roots with complete-until-first-user-authentication protection and backup exclusion,
    /// bootstraps authorization state awaiting waitTdlibParameters before sending parameters,
    /// and retains native ownership on failure so the client can be cleanly closed.
    public func start(
        databaseDirectory: String? = nil,
        filesDirectory: String? = nil,
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unavailable"
    ) async throws {
        guard !isStarting else { throw TDLibError.executionFailed("Client initialization is in progress.") }
        isStarting = true
        defer { isStarting = false }
        try Task.checkCancellation()
        let cred = try credentialStore.loadTelegramCredential(forProfile: profileID)
        let dbKey = try credentialStore.getOrCreateTDLibDatabaseKey(forProfile: profileID)
        let roots = try Self.storageURLs(forProfile: profileID)
        // Optional legacy arguments may only name this profile's canonical roots;
        // accepting arbitrary disjoint paths could share another account database.
        switch (databaseDirectory, filesDirectory) {
        case (nil, nil): break
        case let (database?, files?):
            guard URL(fileURLWithPath: database).standardizedFileURL == roots.databaseURL,
                  URL(fileURLWithPath: files).standardizedFileURL == roots.filesURL else {
                throw TDLibError.invalidParameter("Directories must belong to the mapped profile.")
            }
        default: throw TDLibError.invalidParameter("Both directory arguments must be supplied together.")
        }

        if !(await session.hasNativeClient) {
            appliedNetworkType = nil
            try await trace(.telegramNativeCreate, .started)
            _ = try await session.start()
            try await trace(.telegramNativeCreate, .succeeded)
        }
        // The pinned ABI emits no updates until its first request. This genuine
        // query starts delivery; session applies its auth response before resuming.
        _ = try await session.sendRequest(["@type": "getAuthorizationState"], timeout: 10)
        let state = await session.authState
        if [.waitPhoneNumber, .waitCode, .waitPassword, .waitEmailAddress, .waitEmailCode,
            .waitOtherDeviceConfirmation, .waitRegistration, .waitPremiumPurchase, .ready].contains(state) {
            try await applyNetworkPolicy(whileStarting: true)
            return
        }
        guard state == .waitTdlibParameters else {
            throw SafeFailure(.authentication, domain: .tdlib, cause: .initializationFailed)
        }

        let params = TDLibParameters(
            apiId: cred.apiId,
            apiHash: cred.apiHash,
            databaseDirectory: roots.databaseURL.path,
            filesDirectory: roots.filesURL.path,
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
            // TDLib queues setNetworkType until setTdlibParameters initializes its
            // network manager. Enqueue the gate first, then initialize without
            // waiting for that queued response. Both responses remain observed.
            let initialType = networkType
            let session = self.session
            let dispatched = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    defer { dispatched.continuation.finish() }
                    _ = try await session.sendRequest(["@type": "setNetworkType", "type": ["@type": initialType]],
                        timeout: 30, onDispatched: { dispatched.continuation.yield(()) })
                }
                var iterator = dispatched.stream.makeAsyncIterator()
                guard await iterator.next() != nil else {
                    try Task.checkCancellation()
                    try await group.waitForAll()
                    throw SafeFailure(.authentication, domain: .tdlib, cause: .initializationFailed)
                }
                try Task.checkCancellation()
                _ = try await session.sendRequest(params.toRequestDictionary(), timeout: 20)
                try await group.waitForAll()
            }
            appliedNetworkType = initialType
            _ = try await session.sendRequest(["@type": "getAuthorizationState"], timeout: 10)
            // A policy change may have arrived during initialization.
            try await applyNetworkPolicy(whileStarting: true)
        } catch {
            if error is CoreError || error is CredentialError || error is CancellationError { throw error }
            let classified = Self.classify(error)
            try await emitDiagnostic(.failure, decision: .wait, severity: .error, failure: classified)
            throw classified
        }
    }

    /// Submits a phone number for user authentication.
    public func setAuthenticationPhoneNumber(_ phoneNumber: String) async throws {
        let normalized = try Self.internationalPhoneNumber(phoneNumber)
        let req: [String: Any] = [
            "@type": "setAuthenticationPhoneNumber",
            "phone_number": normalized,
            "settings": NSNull()
        ]
        do {
            _ = try await session.sendRequest(req)
        } catch {
            if error is CoreError || error is CredentialError || error is CancellationError { throw error }
            let classified = Self.classify(error, method: .setAuthenticationPhoneNumber)
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
            let classified = Self.classify(error, method: .checkAuthenticationCode)
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
            let classified = Self.classify(error, method: .checkAuthenticationPassword)
            throw classified
        }
    }

    /// Internal production protocol surface. Ownership transfers to the session;
    /// arbitrary native/server prose is never exposed through diagnostics.
    func request(_ request: sending [String: Any], timeout: TimeInterval = 60) async throws -> TDLibResponse {
        let method = DiagnosticNativeMethod(rawValue: request["@type"] as? String ?? "") ?? .other
        do { return try await session.sendRequest(request, timeout: timeout) }
        catch {
            if case TDLibError.tdlibError = error { throw TDLibRequestRejection(failure: Self.classify(error, method: method)) }
            if error is CoreError || error is CancellationError { throw error }
            throw Self.classify(error)
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
    public func updates(types: Set<String>? = nil) async throws -> AsyncThrowingStream<TDLibResponse, any Error> {
        try await session.updateStream(types: types)
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
    func setNetworkPolicy(allowed: Bool, wifi: Bool) async throws {
        let type = allowed ? (wifi ? "networkTypeWiFi" : "networkTypeMobile") : "networkTypeNone"
        networkType = type
        try await applyNetworkPolicy()
    }
    private func applyNetworkPolicy(whileStarting: Bool = false) async throws {
        guard (!isStarting || whileStarting), !isApplyingNetworkPolicy else { return }
        let state = await session.authState
        // Authorization lookup suspends this actor. Reserve policy ownership
        // only after rechecking it, so concurrent callers cannot apply stale gates.
        guard (!isStarting || whileStarting), !isApplyingNetworkPolicy,
              ![.uninitialized, .waitTdlibParameters, .closed, .closing, .uncertain].contains(state) else { return }
        isApplyingNetworkPolicy = true
        defer { isApplyingNetworkPolicy = false }
        while networkType != appliedNetworkType {
            let type = networkType
            _ = try await session.sendRequest(["@type": "setNetworkType", "type": ["@type": type]], timeout: 10)
            appliedNetworkType = type
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

    private func trace(_ stage: DiagnosticStage, _ status: DiagnosticStatus) async throws {
        try await diagnosticSink?(.setupTrace, EventContext(origin: .telegram,
            diagnostic: DiagnosticDetail(stage: stage, status: status, correlationID: UUID())),
            .proceed, .info, nil, nil, nil, nil)
    }

    // MARK: - Error Classification

    /// Formatting normalization only; never guesses a country code or logs digits.
    static func internationalPhoneNumber(_ input: String) throws -> String {
        var result = ""
        for scalar in input.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar), let digit = Character(String(scalar)).wholeNumberValue {
                result += String(digit)
            } else if scalar == "+", result.isEmpty { result += "+" }
            else if CharacterSet.whitespacesAndNewlines.contains(scalar) || "()- .".unicodeScalars.contains(scalar) { continue }
            else { throw SafeFailure(.authentication, domain: .tdlib, cause: .phoneNumberInvalid) }
        }
        guard result.first == "+", (2...15).contains(result.dropFirst().count), result.dropFirst().first != "0" else {
            throw SafeFailure(.authentication, domain: .tdlib, cause: .phoneNumberInvalid)
        }
        return result
    }
    static func nativeReason(_ error: any Error) -> DiagnosticNativeError? {
        guard case TDLibError.tdlibError(let code, let message) = error, code != 406 else { return nil }
        return DiagnosticNativeError(rawValue: message) ?? .other
    }

    /// Maps TDLib error codes and bridge errors to Core SafeFailure.
    /// Never exposes raw secrets, tokens, or private paths.
    public static func classify(_ error: any Error, method: DiagnosticNativeMethod? = nil) -> SafeFailure {
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
                return SafeFailure(.authentication, domain: .tdlib, cause: .initializationFailed)
            case .tdlibError(let code, _):
                switch nativeReason(error) {
                case .phoneNumberInvalid: return SafeFailure(.authentication, domain: .tdlib, code: Int(code), cause: .phoneNumberInvalid)
                case .phoneNumberBanned: return SafeFailure(.authentication, domain: .tdlib, code: Int(code), cause: .phoneNumberBanned)
                case .apiIdInvalid, .apiIdPublishedFlood: return SafeFailure(.authentication, domain: .tdlib, code: Int(code), cause: .applicationCredentialsRejected)
                case .phoneNumberFlood, .phonePasswordFlood: return SafeFailure(.rateLimit, domain: .tdlib, code: Int(code), cause: .serverRateLimit)
                case .phoneCodeInvalid, .phoneCodeExpired, .passwordHashInvalid, .updateAppToLogin, .authRestart:
                    return SafeFailure(.authentication, domain: .tdlib, code: Int(code), cause: .authenticationRejected)
                default: break
                }
                if code == 401 {
                    return SafeFailure(.authentication, domain: .tdlib, code: Int(code), cause: .loginRequired)
                }
                if code == 429 {
                    return SafeFailure(.rateLimit, domain: .tdlib, code: Int(code), cause: .serverRateLimit)
                }
                if code == 400, let method, [.setAuthenticationPhoneNumber, .checkAuthenticationCode, .checkAuthenticationPassword, .setAuthenticationEmailAddress, .checkAuthenticationEmailCode, .setTdlibParameters].contains(method) {
                    return SafeFailure(.authentication, domain: .tdlib, code: Int(code), cause: .authenticationRejected)
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
