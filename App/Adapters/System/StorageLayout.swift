import Foundation

/// Safe Foundation storage-layout coordinator for app-owned Application Support directories.
/// Directs the persistent SQLite database, original media staging, and manifests roots.
public final class StorageLayout: Sendable {
    public static let shared = StorageLayout()

    public let rootDirectory: URL
    public let databaseURL: URL
    public let stagingURL: URL
    public let manifestsURL: URL

    public init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let cloudifiedRoot = appSupport.appendingPathComponent("Cloudified", isDirectory: true)

        self.rootDirectory = cloudifiedRoot
        self.databaseURL = cloudifiedRoot.appendingPathComponent("ledger.sqlite")
        self.stagingURL = cloudifiedRoot.appendingPathComponent("staging", isDirectory: true)
        self.manifestsURL = cloudifiedRoot.appendingPathComponent("manifests", isDirectory: true)

        try? Self.prepareDirectory(cloudifiedRoot, fileManager: fileManager)
        try? Self.prepareDirectory(stagingURL, fileManager: fileManager)
        try? Self.prepareDirectory(manifestsURL, fileManager: fileManager)
    }

    /// Prepares directory with intermediate paths, backup exclusion, and complete file protection.
    private static func prepareDirectory(_ url: URL, fileManager: FileManager) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        var mutableURL = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(resourceValues)

        #if os(iOS)
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #endif
    }

    /// Queries real available volume capacity in bytes using Apple's important usage capacity key.
    public func availableDiskSpace() -> Int64 {
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        if let values = try? rootDirectory.resourceValues(forKeys: keys) {
            if let important = values.volumeAvailableCapacityForImportantUsage {
                return max(0, important)
            }
            if let standard = values.volumeAvailableCapacity {
                return max(0, Int64(standard))
            }
        }
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: rootDirectory.path),
           let freeSize = attrs[.systemFreeSize] as? Int64 {
            return max(0, freeSize)
        }
        return 0
    }
}
