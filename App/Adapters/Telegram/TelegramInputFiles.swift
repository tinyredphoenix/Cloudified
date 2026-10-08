import Foundation
import CloudifiedCore

/// TDLib derives a document filename from its input path. A protected hard link
/// preserves the actual name without copying a large original. Durable checkpoints
/// and Core holds own BOTH path names until all native readers are terminal.
struct TelegramInputFiles: Sendable {
    let root: URL
    init(stagingRoot: URL) { root = stagingRoot.appendingPathComponent("telegram-inputs", isDirectory: true) }
    func url(transferID: UUID, filename: String) throws -> URL {
        guard !filename.isEmpty, filename != ".", filename != "..", filename.utf8.count <= 255,
              !filename.contains("/"), !filename.contains("\\"), !filename.contains("\0") else { throw CoreError.invalidContract }
        return root.appendingPathComponent(transferID.uuidString, isDirectory: true).appendingPathComponent(filename)
    }
    func create(transferID: UUID, input: LeasedFile, filename: String) throws -> URL {
        let target = try url(transferID: transferID, filename: filename)
        guard root.resolvingSymlinksInPath().path == root.standardizedFileURL.path else { throw CoreError.invalidContract }
        let parent = target.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        guard parent.resolvingSymlinksInPath().path == parent.standardizedFileURL.path else { throw CoreError.invalidContract }
        var protected = root
        var values = URLResourceValues(); values.isExcludedFromBackup = true; try protected.setResourceValues(values)
        #if os(iOS)
        for dir in [root, parent] { try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: dir.path) }
        #endif
        guard !FileManager.default.fileExists(atPath: target.path), input.url.resolvingSymlinksInPath().path == input.url.standardizedFileURL.path else { throw CoreError.invalidContract }
        try FileManager.default.linkItem(at: input.url, to: target)
        return target
    }
    func remove(transferID: UUID) throws {
        let directory = root.appendingPathComponent(transferID.uuidString, isDirectory: true)
        guard directory.resolvingSymlinksInPath().path == directory.standardizedFileURL.path else { throw CoreError.invalidContract }
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
}
