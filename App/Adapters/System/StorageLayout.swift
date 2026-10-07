import Foundation
import CloudifiedCore

/// Safe Foundation storage-layout coordinator for app-owned Application Support directories.
/// Directs the persistent SQLite database, original media staging, and manifests roots.
public final class StorageLayout: Sendable {
    public let rootDirectory: URL
    public let databaseURL: URL
    public let stagingURL: URL
    public let manifestsURL: URL

    public init(fileManager: FileManager = .default) throws {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let cloudifiedRoot = appSupport.appendingPathComponent("Cloudified", isDirectory: true)

        self.rootDirectory = cloudifiedRoot
        self.databaseURL = cloudifiedRoot.appendingPathComponent("ledger.sqlite")
        self.stagingURL = cloudifiedRoot.appendingPathComponent("staging", isDirectory: true)
        self.manifestsURL = cloudifiedRoot.appendingPathComponent("manifests", isDirectory: true)

        try Self.prepareDirectory(cloudifiedRoot, fileManager: fileManager)
        try Self.prepareDirectory(stagingURL, fileManager: fileManager)
        try Self.prepareDirectory(manifestsURL, fileManager: fileManager)
    }

    /// Prepares directory with intermediate paths, backup exclusion, and complete file protection.
    /// Throws classified SafeFailure on creation or attribute failure.
    private static func prepareDirectory(_ url: URL, fileManager: FileManager) throws {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            let code = (error as NSError).code
            let cause: KnownCause = (code == NSFileWriteNoPermissionError || code == EACCES || code == EPERM) ? .permissionDenied : .unknown
            throw SafeFailure(.accessDenied, domain: .fileSystem, code: code, cause: cause)
        }

        var mutableURL = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        do {
            try mutableURL.setResourceValues(resourceValues)
        } catch {
            let code = (error as NSError).code
            throw SafeFailure(.transfer, domain: .fileSystem, code: code, cause: .unknown)
        }

        #if os(iOS)
        do {
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
        } catch {
            let code = (error as NSError).code
            let cause: KnownCause = (code == NSFileWriteNoPermissionError || code == EACCES || code == EPERM) ? .permissionDenied : .unknown
            throw SafeFailure(.accessDenied, domain: .fileSystem, code: code, cause: cause)
        }
        #endif
    }

    /// Queries real available volume capacity in bytes using Apple's important usage capacity key.
    /// Throws classified SafeFailure instead of returning 0 or manufacturing false disk full.
    public func availableCapacity() throws -> Int64 {
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        do {
            let values = try rootDirectory.resourceValues(forKeys: keys)
            if let important = values.volumeAvailableCapacityForImportantUsage, important >= 0 {
                return important
            }
            if let standard = values.volumeAvailableCapacity, standard >= 0 {
                return Int64(standard)
            }
        } catch {
            // Fall through to attributesOfFileSystem
        }

        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: rootDirectory.path)
            if let freeSize = attrs[.systemFreeSize] as? Int64, freeSize >= 0 {
                return freeSize
            }
        } catch {
            let code = (error as NSError).code
            let cause: KnownCause = (code == NSFileReadNoPermissionError || code == EACCES || code == EPERM) ? .permissionDenied : .unknown
            throw SafeFailure(.accessDenied, domain: .fileSystem, code: code, cause: cause)
        }

        throw SafeFailure(.sourceUnavailable, domain: .fileSystem, cause: .unknown)
    }
}
