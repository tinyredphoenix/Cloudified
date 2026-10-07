import Foundation
import Security

/// Classified credential storage failures.
public enum CredentialError: Error, Sendable, Equatable {
    case notConfigured
    case accessDenied(OSStatus)
    case storageFailure(OSStatus)
    case corrupt
}

/// Google authentication credentials persisted securely in Keychain.
public struct StoredGoogleCredential: Codable, Equatable, Sendable {
    public let androidId: String
    public let email: String
    public let masterToken: String
    public let authData: String
    public let connectedAt: Date

    public init(
        androidId: String,
        email: String,
        masterToken: String,
        authData: String,
        connectedAt: Date = Date()
    ) {
        self.androidId = androidId
        self.email = email
        self.masterToken = masterToken
        self.authData = authData
        self.connectedAt = connectedAt
    }
}

/// Telegram API credentials and encryption configuration persisted securely in Keychain.
public struct StoredTelegramCredential: Codable, Equatable, Sendable {
    public let apiId: Int32
    public let apiHash: String
    public let phoneNumber: String?
    public let botToken: String?
    public let databaseEncryptionKey: String
    public let createdAt: Date

    public init(
        apiId: Int32,
        apiHash: String,
        phoneNumber: String? = nil,
        botToken: String? = nil,
        databaseEncryptionKey: String,
        createdAt: Date = Date()
    ) {
        self.apiId = apiId
        self.apiHash = apiHash
        self.phoneNumber = phoneNumber
        self.botToken = botToken
        self.databaseEncryptionKey = databaseEncryptionKey
        self.createdAt = createdAt
    }
}

/// Low-level Keychain operations protocol.
public protocol KeychainStoreBackend: Sendable {
    func read(service: String, account: String) throws -> Data?
    func write(service: String, account: String, data: Data) throws
    func delete(service: String, account: String) throws
}

/// Production implementation of KeychainStoreBackend targeting device Keychain.
public struct SystemKeychainBackend: KeychainStoreBackend {
    public init() {}

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    public func read(service: String, account: String) throws -> Data? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        if status == errSecInteractionNotAllowed || status == errSecAuthFailed {
            throw CredentialError.accessDenied(status)
        }
        guard status == errSecSuccess else {
            throw CredentialError.storageFailure(status)
        }
        return item as? Data
    }

    public func write(service: String, account: String, data: Data) throws {
        var query = baseQuery(service: service, account: account)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(query.merging([kSecValueData as String: data]) { _, new in new } as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            let updateQuery = baseQuery(service: service, account: account)
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if updateStatus == errSecInteractionNotAllowed || updateStatus == errSecAuthFailed {
                throw CredentialError.accessDenied(updateStatus)
            }
            guard updateStatus == errSecSuccess else {
                throw CredentialError.storageFailure(updateStatus)
            }
            return
        }
        if addStatus == errSecInteractionNotAllowed || addStatus == errSecAuthFailed {
            throw CredentialError.accessDenied(addStatus)
        }
        guard addStatus == errSecSuccess else {
            throw CredentialError.storageFailure(addStatus)
        }
    }

    public func delete(service: String, account: String) throws {
        let query = baseQuery(service: service, account: account)
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecItemNotFound || status == errSecSuccess {
            return
        }
        if status == errSecInteractionNotAllowed || status == errSecAuthFailed {
            throw CredentialError.accessDenied(status)
        }
        throw CredentialError.storageFailure(status)
    }
}

/// Secure native Keychain storage for provider credentials and TDLib encryption keys.
/// Items are protected with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and bound
/// by explicit private session/profile identifiers rather than display names or token hashes.
public final class KeychainCredentialStore: Sendable {
    public static let defaultService = "com.tinyredphoenix.cloudified.credentials"

    private let service: String
    private let backend: any KeychainStoreBackend

    public init(
        service: String = defaultService,
        backend: any KeychainStoreBackend = SystemKeychainBackend()
    ) {
        self.service = service
        self.backend = backend
    }

    private func googleAccountKey(sessionID: String) -> String {
        "google.session.\(sessionID)"
    }

    private func telegramAccountKey(sessionID: String) -> String {
        "telegram.session.\(sessionID)"
    }

    private func tdlibKeyAccountKey(sessionID: String) -> String {
        "telegram.tdlib_db_key.\(sessionID)"
    }

    // MARK: - Google Credentials

    public func saveGoogleCredential(_ cred: StoredGoogleCredential, forSession sessionID: String) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(cred)
        } catch {
            throw CredentialError.corrupt
        }
        try backend.write(service: service, account: googleAccountKey(sessionID: sessionID), data: data)
    }

    public func loadGoogleCredential(forSession sessionID: String) throws -> StoredGoogleCredential {
        guard let data = try backend.read(service: service, account: googleAccountKey(sessionID: sessionID)) else {
            throw CredentialError.notConfigured
        }
        do {
            return try JSONDecoder().decode(StoredGoogleCredential.self, from: data)
        } catch {
            throw CredentialError.corrupt
        }
    }

    public func deleteGoogleCredential(forSession sessionID: String) throws {
        try backend.delete(service: service, account: googleAccountKey(sessionID: sessionID))
    }

    // MARK: - Telegram Credentials

    public func saveTelegramCredential(_ cred: StoredTelegramCredential, forSession sessionID: String) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(cred)
        } catch {
            throw CredentialError.corrupt
        }
        try backend.write(service: service, account: telegramAccountKey(sessionID: sessionID), data: data)
    }

    public func loadTelegramCredential(forSession sessionID: String) throws -> StoredTelegramCredential {
        guard let data = try backend.read(service: service, account: telegramAccountKey(sessionID: sessionID)) else {
            throw CredentialError.notConfigured
        }
        do {
            return try JSONDecoder().decode(StoredTelegramCredential.self, from: data)
        } catch {
            throw CredentialError.corrupt
        }
    }

    public func deleteTelegramCredential(forSession sessionID: String) throws {
        try backend.delete(service: service, account: telegramAccountKey(sessionID: sessionID))
    }

    // MARK: - TDLib Database Encryption Key

    /// Generates a cryptographically secure 256-bit random key encoded in base64.
    public static func generateDatabaseEncryptionKey() throws -> String {
        var keyData = Data(count: 32)
        let result = keyData.withUnsafeMutableBytes { ptr -> Int32 in
            guard let baseAddress = ptr.baseAddress else { return -1 }
            return SecRandomCopyBytes(kSecRandomDefault, 32, baseAddress)
        }
        guard result == errSecSuccess else {
            throw CredentialError.storageFailure(result)
        }
        return keyData.base64EncodedString()
    }

    /// Loads the TDLib database key for this session or generates and persists a fresh 256-bit key.
    public func getOrCreateTDLibDatabaseKey(forSession sessionID: String) throws -> String {
        let account = tdlibKeyAccountKey(sessionID: sessionID)
        if let existingData = try backend.read(service: service, account: account),
           let keyString = String(data: existingData, encoding: .utf8),
           !keyString.isEmpty {
            return keyString
        }

        let freshKey = try Self.generateDatabaseEncryptionKey()
        guard let freshData = freshKey.data(using: .utf8) else {
            throw CredentialError.corrupt
        }
        try backend.write(service: service, account: account, data: freshData)
        return freshKey
    }

    public func deleteTDLibDatabaseKey(forSession sessionID: String) throws {
        try backend.delete(service: service, account: tdlibKeyAccountKey(sessionID: sessionID))
    }
}
