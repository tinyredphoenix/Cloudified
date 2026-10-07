import Foundation

public struct LeasedFile: Sendable {
    public let fileID: UUID
    public let leaseID: UUID
    public let url: URL
    public let byteCount: Int64
    // Only FileLeaseStore may mint a lease; adapters cannot fabricate ownership.
    init(fileID: UUID, leaseID: UUID, url: URL, byteCount: Int64) {
        self.fileID = fileID; self.leaseID = leaseID; self.url = url; self.byteCount = byteCount
    }
}
public struct StorageReservation: Sendable {
    public let id: UUID
    public let byteCount: Int64
    public let oversized: Bool
}
public struct ExportFileOwnership: Sendable {
    public let fileID: UUID
    public let partialURL: URL
    public let publishedURL: URL
    fileprivate let token: UUID
}

public actor FileLeaseStore {
    public let root: URL
    private let ledger: Ledger
    private var leases: [UUID: UUID] = [:]
    private var deleting: Set<UUID> = []
    private var orphanIterator: FileManager.DirectoryEnumerator?
    private var inventoryReconciled = false
    public init(root: URL, ledger: Ledger) throws {
        self.root = root.standardizedFileURL; self.ledger = ledger
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var protectedRoot = root
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try protectedRoot.setResourceValues(values)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: root.path)
        #endif
    }
    /// P3 owns .partial creation/cancellable writes. Publication must rename the
    /// verified terminal file to this internally generated filename atomically.
    public func publishedURL(fileID: UUID) -> URL { root.appendingPathComponent(fileID.uuidString + ".original") }
    /// P3 must retain this across every PhotoKit callback and the rename/register
    /// window, releasing only after the export writer is genuinely terminal.
    public func beginExport(fileID: UUID) throws -> ExportFileOwnership {
        guard !deleting.contains(fileID), !leases.values.contains(fileID),
              !FileManager.default.fileExists(atPath: root.appendingPathComponent(fileID.uuidString + ".partial").path),
              !FileManager.default.fileExists(atPath: publishedURL(fileID: fileID).path) else { throw CoreError.invalidTransition }
        let token = UUID(); leases[token] = fileID
        return ExportFileOwnership(fileID: fileID, partialURL: root.appendingPathComponent(fileID.uuidString + ".partial"), publishedURL: publishedURL(fileID: fileID), token: token)
    }
    public func endExport(_ ownership: ExportFileOwnership) throws {
        guard leases[ownership.token] == ownership.fileID else { throw CoreError.invalidTransition }
        leases.removeValue(forKey: ownership.token)
    }
    public func registerPublished(fileID: UUID, byteCount: Int64, reservationID: UUID,
                                  reexportable: Bool) async throws -> LeasedFile {
        guard !deleting.contains(fileID) else { throw CoreError.invalidTransition }
        let url = publishedURL(fileID: fileID)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              values.fileSize.map(Int64.init) == byteCount, byteCount >= 0 else { throw CoreError.invalidContract }
        // Pin before awaiting ledger: actor reentrancy cannot open a cleanup gap.
        let leaseID = UUID(); leases[leaseID] = fileID
        do {
            try await ledger.registerStaged(fileID: fileID, relativePath: url.lastPathComponent, bytes: byteCount, reservationID: reservationID, reexportable: reexportable)
            return LeasedFile(fileID: fileID, leaseID: leaseID, url: url, byteCount: byteCount)
        } catch { leases.removeValue(forKey: leaseID); throw error }
    }
    public func acquire(fileID: UUID) async throws -> LeasedFile {
        guard !deleting.contains(fileID) else { throw CoreError.invalidTransition }
        let leaseID = UUID(); leases[leaseID] = fileID
        do {
            let record = try await ledger.stagedFile(fileID)
            let url = root.appendingPathComponent(record.path)
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true, values.fileSize.map(Int64.init) == record.bytes else { throw CoreError.invalidContract }
            try await ledger.appendEvent(.leaseAcquire, context: EventContext(resourceID: fileID), decision: .proceed)
            return LeasedFile(fileID: fileID, leaseID: leaseID, url: url, byteCount: record.bytes)
        } catch { leases.removeValue(forKey: leaseID); throw error }
    }
    public func release(_ file: LeasedFile) async throws {
        guard leases[file.leaseID] == file.fileID else { throw CoreError.invalidTransition }
        leases.removeValue(forKey: file.leaseID)
        try await ledger.appendEvent(.leaseRelease, context: EventContext(resourceID: file.fileID), decision: .proceed)
    }
    /// Called after PhotoKit callbacks, actual background sessions and TDLib sends
    /// are inventoried. Retained holds remain protected, including unmatched tasks.
    public func completeStartupInventory() { inventoryReconciled = true }
    public func hold(files: [LeasedFile], transferID: UUID, job: JobRecord, resourceID: UUID) async throws {
        guard files.allSatisfy({ leases[$0.leaseID] == $0.fileID }) else { throw CoreError.invalidContract }
        try await ledger.holdFiles(files.map(\.fileID), transferID: transferID, job: job, resourceID: resourceID)
    }
    /// Only a genuinely terminal transport callback/inventory proof may call this.
    public func transportFinished(_ transferID: UUID) async throws { try await ledger.releaseHold(transferID) }
    @discardableResult public func sweep(limit: Int = 20) async throws -> Int {
        guard inventoryReconciled, (1...100).contains(limit) else { throw CoreError.recoveryRequired }
        let candidates = try await ledger.stagedCleanupCandidates(limit: limit)
        var removed = 0
        for candidate in candidates {
            if leases.values.contains(candidate.id) { continue }
            // Local pin fences acquire()/publish() across the DB await. A deleting
            // record rejects new acquires; no new reader can appear after this point.
            let fence = UUID(); leases[fence] = candidate.id; deleting.insert(candidate.id)
            let marked: Bool
            do { marked = try await ledger.markDeleting(candidate.id) }
            catch { leases.removeValue(forKey: fence); deleting.remove(candidate.id); throw error }
            guard marked else { leases.removeValue(forKey: fence); deleting.remove(candidate.id); continue }
            do {
                let url = root.appendingPathComponent(candidate.path)
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
                try await ledger.finishDeleting(candidate.id)
                removed += 1; leases.removeValue(forKey: fence); deleting.remove(candidate.id)
            } catch { leases.removeValue(forKey: fence); deleting.remove(candidate.id); throw error }
        }
        return removed
    }
    /// Bounded directory enumeration after startup inventory. Only our exact UUID
    /// filenames are eligible; unrelated files/directories are never removed.
    /// Repeat calls at idle while a full page is reclaimed, not in a busy loop.
    @discardableResult public func reclaimOrphans(limit: Int = 20) async throws -> Int {
        guard inventoryReconciled, (1...100).contains(limit) else { throw CoreError.recoveryRequired }
        if orphanIterator == nil {
            orphanIterator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: [.skipsSubdirectoryDescendants])
        }
        guard let entries = orphanIterator else { return 0 }
        var removed = 0
        var examined = 0
        while removed < limit, examined < 200 {
            guard let url = nextURL(entries) else { orphanIterator = nil; break }
            examined += 1
            let ext = url.pathExtension
            guard ext == "partial" || ext == "original",
                  let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  url.lastPathComponent == id.uuidString + "." + ext,
                  !leases.values.contains(id) else { continue }
            let fence = UUID(); leases[fence] = id; deleting.insert(id)
            do {
                let registered = try await ledger.isStaged(id)
                // A concurrent export that arrived during the await pins the file.
                let otherReaders = leases.contains { $0.key != fence && $0.value == id }
                if !registered && !otherReaders {
                    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    if values.isRegularFile == true, values.isSymbolicLink != true {
                        try FileManager.default.removeItem(at: url); removed += 1
                        try await ledger.appendEvent(.cleanup, context: EventContext(resourceID: id), decision: .proceed)
                    }
                }
                leases.removeValue(forKey: fence)
                deleting.remove(id)
            } catch { leases.removeValue(forKey: fence); deleting.remove(id); throw error }
        }
        return removed
    }
    public var orphanScanInProgress: Bool { orphanIterator != nil }
    private func nextURL(_ iterator: FileManager.DirectoryEnumerator) -> URL? { iterator.nextObject() as? URL }
}

struct StagedRecord: Sendable { let id: UUID; let path: String; let bytes: Int64 }
extension Ledger {
    func isStaged(_ id: UUID) throws -> Bool { try !db.rows("SELECT id FROM staged WHERE id=?", [id.sql]).isEmpty }
    /// P3 source-change observation must revoke this permission if staged bytes
    /// become the only recoverable copy. Transport holds still take precedence.
    public func setReexportable(fileID: UUID, _ allowed: Bool) throws {
        try db.execute("UPDATE staged SET recoverable=? WHERE id=? AND deleting=0", [.integer(allowed ? 1 : 0), fileID.sql])
        guard db.changes == 1 else { throw CoreError.invalidTransition }
    }
    public func reserveStorage(bytes: Int64, availableBytes: Int64, transportOverhead: Int64, writtenBytes: Int64 = 0,
                               replacing: UUID? = nil) throws -> StorageReservation {
        guard bytes >= 0, availableBytes >= 0, transportOverhead >= 0, writtenBytes >= 0, writtenBytes <= bytes else { throw CoreError.invalidContract }
        return try transaction {
            let soft: Int64 = 1_073_741_824, safety: Int64 = 536_870_912
            let staged = try db.rows("SELECT COALESCE(SUM(bytes),0) AS n FROM staged").first!.int("n")
            let reserved = try db.rows("SELECT COALESCE(SUM(bytes),0) AS n FROM reservations WHERE id!=?", [replacing?.sql ?? .text("")]).first!.int("n")
            let remainingWrite = bytes - writtenBytes
            // availableBytes already excludes files actually written. Reserve
            // outstanding promised bytes separately; never subtract staging twice.
            guard availableBytes >= safety, transportOverhead <= availableBytes - safety,
                  reserved <= availableBytes - safety - transportOverhead,
                  remainingWrite <= availableBytes - safety - transportOverhead - reserved,
                  bytes <= Int64.max - staged - reserved else {
                throw SafeFailure(.diskFull, domain: .fileSystem, cause: .insufficientSpace)
            }
            let oversized = staged + reserved + bytes > soft
            if oversized, try db.rows("SELECT id FROM reservations WHERE oversized=1 AND id!=? UNION ALL SELECT id FROM staged WHERE oversized=1", [replacing?.sql ?? .text("")]).count > 0 {
                throw SafeFailure(.diskFull, domain: .fileSystem, cause: .insufficientSpace)
            }
            let id = replacing ?? UUID()
            try db.execute("INSERT INTO reservations(id,bytes,oversized) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET bytes=excluded.bytes,oversized=excluded.oversized", [id.sql, .integer(bytes), .integer(oversized ? 1 : 0)])
            return StorageReservation(id: id, byteCount: bytes, oversized: oversized)
        }
    }
    public func releaseReservation(_ id: UUID) throws { try db.execute("DELETE FROM reservations WHERE id=?", [id.sql]) }
    func registerStaged(fileID: UUID, relativePath: String, bytes: Int64, reservationID: UUID, reexportable: Bool) throws {
        guard relativePath == fileID.uuidString + ".original" else { throw CoreError.invalidContract }
        try transaction {
            guard let reservation = try db.rows("SELECT bytes,oversized FROM reservations WHERE id=?", [reservationID.sql]).first, reservation.int("bytes") >= bytes else { throw CoreError.invalidContract }
            try db.execute("INSERT INTO staged(id,relative_path,bytes,oversized,recoverable) VALUES(?,?,?,?,?)", [fileID.sql, .text(relativePath), .integer(bytes), .integer(reservation.int("oversized")), .integer(reexportable ? 1 : 0)])
            try db.execute("DELETE FROM reservations WHERE id=?", [reservationID.sql])
            try record(.leaseAcquire, context: EventContext(resourceID: fileID), decision: .proceed)
        }
    }
    func stagedFile(_ id: UUID) throws -> StagedRecord {
        guard let row = try db.rows("SELECT * FROM staged WHERE id=? AND deleting=0", [id.sql]).first,
              try row.string("relative_path") == id.uuidString + ".original" else { throw CoreError.invalidContract }
        return StagedRecord(id: id, path: try row.string("relative_path"), bytes: row.int("bytes"))
    }
    func holdFiles(_ ids: [UUID], transferID: UUID, job: JobRecord, resourceID: UUID) throws {
        try transaction {
            guard job.plan.resources.contains(where: { $0.id == resourceID }) else { throw CoreError.invalidContract }
            try db.execute("INSERT INTO transfers(id,destination_id,job_id,resource_id) VALUES(?,?,?,?)", [transferID.sql, job.destination.id.sql, job.id.sql, resourceID.sql])
            for id in ids {
                _ = try stagedFile(id)
                try db.execute("INSERT INTO holds(transfer_id,file_id,destination_id,job_id) VALUES(?,?,?,?)", [transferID.sql, id.sql, job.destination.id.sql, job.id.sql])
            }
        }
    }
    public func retainedTransferIDs(destinationID: UUID) throws -> [UUID] {
        try db.rows("SELECT id FROM transfers WHERE destination_id=? LIMIT 200", [destinationID.sql]).map {
            guard let id = UUID(uuidString: try $0.string("id")) else { throw CoreError.invalidContract }; return id
        }
    }
    func releaseHold(_ id: UUID) throws {
        try transaction {
            try db.execute("DELETE FROM holds WHERE transfer_id=?", [id.sql])
            try db.execute("DELETE FROM transfers WHERE id=?", [id.sql])
        }
    }
    func stagedCleanupCandidates(limit: Int) throws -> [StagedRecord] {
        try db.rows("SELECT * FROM staged s WHERE recoverable=1 AND NOT EXISTS(SELECT 1 FROM holds h WHERE h.file_id=s.id) LIMIT ?", [.integer(Int64(limit))]).map {
            guard let id = UUID(uuidString: try $0.string("id")), try $0.string("relative_path") == id.uuidString + ".original" else { throw CoreError.invalidContract }
            return StagedRecord(id: id, path: try $0.string("relative_path"), bytes: $0.int("bytes"))
        }
    }
    func markDeleting(_ id: UUID) throws -> Bool {
        try db.execute("UPDATE staged SET deleting=1 WHERE id=? AND recoverable=1 AND NOT EXISTS(SELECT 1 FROM holds WHERE file_id=?)", [id.sql, id.sql])
        return db.changes == 1
    }
    func finishDeleting(_ id: UUID) throws {
        try transaction {
            try db.execute("DELETE FROM staged WHERE id=? AND deleting=1 AND NOT EXISTS(SELECT 1 FROM holds WHERE file_id=?)", [id.sql, id.sql])
            guard db.changes == 1 else { throw CoreError.invalidTransition }
            try record(.cleanup, context: EventContext(resourceID: id), decision: .proceed)
        }
    }
}
