import Foundation

public struct MediaCounts: Equatable, Sendable {
    public let total: Int
    public let confirmed: Int
    public let uploaded: Int
    public let alreadyPresent: Int
    public let failed: Int
    public let waiting: Int
    public var remaining: Int { total - confirmed }
}
public struct ProviderSnapshot: Sendable {
    public let provider: Provider
    public let destinationID: UUID?
    public let enabled: Bool
    public let recoveryComplete: Bool
    public let blockedReason: SafeFailure?
    public let resumeAt: Date?
    public let photos: MediaCounts?
    public let videos: MediaCounts?
    public let lastConfirmedAt: Date?
    public var total: Int? { photos.flatMap { p in videos.map { p.total + $0.total } } }
    public var confirmed: Int? { photos.flatMap { p in videos.map { p.confirmed + $0.confirmed } } }
    public var remaining: Int? { total.flatMap { t in confirmed.map { t - $0 } } }
}
public struct LedgerSnapshot: Sendable {
    public let scanned: Bool
    public let scanStartedAt: Date?
    public let libraryTotal: Int?
    public let savedToBoth: Int?
    public let providers: [ProviderSnapshot]
}
public struct FailureRow: Sendable {
    public let cursor: Int64
    public let job: JobRecord
    public let asset: AssetIdentity
    public let failure: SafeFailure?
    public let confirmedResources: Int
    public let requiredResources: Int
}
extension Ledger {
    public func snapshot() throws -> LedgerSnapshot {
        // Single actor turn, no awaits: state cannot change between these queries.
        let scan = try db.rows("SELECT s.* FROM scans s JOIN meta m ON m.value=s.id WHERE m.key='scan'").first
        let scanned = scan?.int("complete") == 1
        let total = scanned ? Int(try db.rows("SELECT COUNT(*) AS n FROM assets WHERE scan_id=(SELECT value FROM meta WHERE key='scan')").first!.int("n")) : nil
        var providers: [ProviderSnapshot] = []
        for provider in Provider.allCases {
            let row = try db.rows("SELECT * FROM destinations WHERE provider=? AND selected=1", [.text(provider.rawValue)]).first
            let id = try row.map { row -> UUID in
                guard let id = UUID(uuidString: try row.string("id")) else { throw CoreError.invalidContract }; return id
            }
            let photos = scanned && id != nil ? try counts(destinationID: id!, kind: .photo) : nil
            let videos = scanned && id != nil ? try counts(destinationID: id!, kind: .video) : nil
            let last = try id.flatMap { try db.rows("SELECT MAX(last_confirmed) AS date FROM jobs WHERE destination_id=?", [$0.sql]).first?.double("date") }.map(Date.init(timeIntervalSince1970:))
            let failure = try row.flatMap { row -> SafeFailure? in
                if case .blob = row.values["blocked"] { return try db.decode(SafeFailure.self, row, "blocked") }; return nil
            }
            providers.append(ProviderSnapshot(provider: provider, destinationID: id, enabled: row?.int("enabled") == 1,
                                              recoveryComplete: row?.int("recovered") == 1, blockedReason: failure,
                                              resumeAt: row?.double("resume_at").map(Date.init(timeIntervalSince1970:)),
                                              photos: photos, videos: videos, lastConfirmedAt: last))
        }
        let both: Int?
        if scanned, providers.allSatisfy({ $0.destinationID != nil }) {
            both = Int(try db.rows("""
                SELECT COUNT(*) AS n FROM assets a WHERE a.scan_id=(SELECT value FROM meta WHERE key='scan')
                AND EXISTS(SELECT 1 FROM aliases x JOIN jobs j ON j.id=x.job_id JOIN destinations d ON d.id=j.destination_id WHERE x.asset_id=a.id AND j.state='confirmed' AND d.selected=1 AND d.provider='google')
                AND EXISTS(SELECT 1 FROM aliases x JOIN jobs j ON j.id=x.job_id JOIN destinations d ON d.id=j.destination_id WHERE x.asset_id=a.id AND j.state='confirmed' AND d.selected=1 AND d.provider='telegram')
                """).first!.int("n"))
        } else { both = nil }
        return LedgerSnapshot(scanned: scanned, scanStartedAt: scan?.double("created").map(Date.init(timeIntervalSince1970:)), libraryTotal: total, savedToBoth: both, providers: providers)
    }
    private func counts(destinationID: UUID, kind: MediaKind) throws -> MediaCounts {
        let row = try db.rows("""
            SELECT COUNT(*) AS total,
            COALESCE(SUM(j.state='confirmed'),0) AS confirmed,
            COALESCE(SUM(j.state='failed'),0) AS failed,
            COALESCE(SUM(j.state IN ('waiting','reconciling','delayed')),0) AS waiting,
            COALESCE(SUM(j.state='confirmed' AND EXISTS(SELECT 1 FROM obligations o JOIN receipts r ON r.tag=o.tag AND r.destination_id=j.destination_id WHERE o.job_id=j.id AND r.kind='uploaded')),0) AS uploaded
            FROM assets a LEFT JOIN aliases x ON x.asset_id=a.id AND x.destination_id=?
            LEFT JOIN jobs j ON j.id=x.job_id
            WHERE a.kind=? AND a.scan_id=(SELECT value FROM meta WHERE key='scan')
            """, [destinationID.sql, .text(kind.rawValue)]).first!
        let confirmed = Int(row.int("confirmed")), uploaded = Int(row.int("uploaded"))
        return MediaCounts(total: Int(row.int("total")), confirmed: confirmed, uploaded: uploaded,
                           alreadyPresent: confirmed - uploaded, failed: Int(row.int("failed")), waiting: Int(row.int("waiting")))
    }
    public func failurePage(beforeCursor: Int64? = nil, provider: Provider? = nil, kind: MediaKind? = nil,
                            limit: Int = 50) throws -> [FailureRow] {
        guard (1...100).contains(limit) else { throw CoreError.invalidContract }
        var clauses = ["x.rowid<?", "d.selected=1", "j.state IN ('failed','waiting','reconciling')", "a.scan_id=(SELECT value FROM meta WHERE key='scan')"]
        var args: [SQLValue] = [.integer(beforeCursor ?? Int64.max)]
        if let provider { clauses.append("d.provider=?"); args.append(.text(provider.rawValue)) }
        if let kind { clauses.append("a.kind=?"); args.append(.text(kind.rawValue)) }
        args.append(.integer(Int64(limit)))
        return try db.rows("SELECT x.rowid AS cursor,j.id AS job_id,a.body AS asset_body,j.failure,(SELECT COUNT(*) FROM obligations o WHERE o.job_id=j.id AND o.status='confirmed') AS confirmed,(SELECT COUNT(*) FROM obligations o WHERE o.job_id=j.id) AS required FROM aliases x JOIN jobs j ON j.id=x.job_id JOIN assets a ON a.id=x.asset_id JOIN destinations d ON d.id=j.destination_id WHERE \(clauses.joined(separator: " AND ")) ORDER BY x.rowid DESC LIMIT ?", args).map { row in
            guard let id = UUID(uuidString: try row.string("job_id")) else { throw CoreError.invalidContract }
            let failure: SafeFailure?
            if case .blob = row.values["failure"] { failure = try db.decode(SafeFailure.self, row, "failure") } else { failure = nil }
            return FailureRow(cursor: row.int("cursor"), job: try loadJob(id), asset: try db.decode(AssetIdentity.self, row, "asset_body"), failure: failure,
                              confirmedResources: Int(row.int("confirmed")), requiredResources: Int(row.int("required")))
        }
    }
}
