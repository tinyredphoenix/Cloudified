import Foundation

/// The only owner of SQLite. Receipt/attempt/critical event writes share one commit.
/// If a commit fails, callers stop that lane and retain transport ownership; never
/// announce Saved or substitute an in-memory success flag.
public actor Ledger {
    let db: SQLite
    let version: String
    let revision: String
    private var observers: [UUID: AsyncStream<Void>.Continuation] = [:]
    public init(databaseURL: URL, version: String, revision: String) throws {
        guard !version.isEmpty, version.utf8.count <= 64, revision.utf8.count <= 64,
              revision.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw CoreError.invalidContract }
        self.version = version; self.revision = revision
        let connection = try SQLite(url: databaseURL)
        try Schema.install(connection)
        // Runtime ownership must be reconciled on EVERY process start, even if a
        // previous history scan completed. Neither persisted lease counts nor a
        // previously absent remote lookup establish post-crash absence.
        try connection.transaction {
            try connection.execute("UPDATE destinations SET recovered=0")
            try connection.execute("UPDATE obligations SET status='unknown' WHERE status!='confirmed'")
            try connection.execute("UPDATE jobs SET state='reconciling' WHERE state IN ('uploading','preparing','ready','checking')")
            try connection.execute("DELETE FROM reservations")
        }
        db = connection
    }
    /// Bounded invalidation stream for real UI snapshots. It carries no invented
    /// counts and is NOT an automatic backup trigger. P5 commands/producer events
    /// explicitly request drains; progress events cannot start an empty-batch loop.
    public func observeChanges() throws -> AsyncStream<Void> {
        guard observers.count < 4 else { throw CoreError.invalidContract }
        let id = UUID()
        let pair = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        observers[id] = pair.continuation
        pair.continuation.onTermination = { [weak self] _ in Task { await self?.removeObserver(id) } }
        return pair.stream
    }
    private func removeObserver(_ id: UUID) { observers.removeValue(forKey: id) }
    func transaction<T>(_ body: () throws -> T) throws -> T {
        let result = try db.transaction(body)
        for observer in observers.values { observer.yield(()) }
        return result
    }

    public func selectDestination(_ requested: Destination) throws -> Destination {
        guard UploadPlan.hex(requested.verifiedFingerprint, length: 64) else { throw CoreError.invalidContract }
        return try transaction {
            let rows = try db.rows("SELECT body FROM destinations WHERE provider=? AND fingerprint=?", [.text(requested.provider.rawValue), .text(requested.verifiedFingerprint)])
            let destination = try rows.first.map { try db.decode(Destination.self, $0, "body") } ?? requested
            try db.execute("UPDATE destinations SET selected=0 WHERE provider=?", [.text(destination.provider.rawValue)])
            try db.execute("INSERT INTO destinations(id,provider,fingerprint,body,selected) VALUES(?,?,?,?,1) ON CONFLICT(id) DO UPDATE SET selected=1,recovered=0", [destination.id.sql, .text(destination.provider.rawValue), .text(destination.verifiedFingerprint), try db.encode(destination)])
            try record(.mappingChanged, context: EventContext(origin: destination.provider.origin, destinationID: destination.id), decision: .reconcile)
            return destination
        }
    }
    public func selectedDestination(_ provider: Provider) throws -> Destination? {
        try db.rows("SELECT body FROM destinations WHERE provider=? AND selected=1", [.text(provider.rawValue)]).first.map { try db.decode(Destination.self, $0, "body") }
    }
    public func setEnabled(_ id: UUID, _ enabled: Bool) throws {
        try transaction {
            try db.execute("UPDATE destinations SET enabled=? WHERE id=?", [.integer(enabled ? 1 : 0), id.sql])
            try record(.enabledChanged, context: EventContext(destinationID: id), decision: enabled ? .reconcile : .wait)
        }
    }
    public func deselectDestination(_ id: UUID) throws {
        try transaction {
            try db.execute("UPDATE destinations SET selected=0,enabled=0 WHERE id=?", [id.sql])
            try record(.mappingChanged, context: EventContext(destinationID: id), decision: .wait)
        }
    }
    /// P4 calls this only after verified account, complete managed history/hash
    /// preflight and live OS/TDLib transfer reconciliation. It cannot clear holds.
    public func completeDestinationRecovery(_ id: UUID) throws {
        try transaction {
            let holds = try db.rows("SELECT COUNT(*) AS n FROM transfers WHERE destination_id=?", [id.sql]).first!.int("n")
            guard holds == 0 else { throw CoreError.recoveryRequired }
            try db.execute("UPDATE destinations SET recovered=1 WHERE id=?", [id.sql])
            try record(.recovery, context: EventContext(destinationID: id), decision: .proceed)
        }
    }
    public func unblockDestination(_ id: UUID) throws {
        try transaction {
            try db.execute("UPDATE destinations SET blocked=NULL,resume_at=NULL WHERE id=?", [id.sql])
            try db.execute("UPDATE jobs SET state='reconciling',retry_at=NULL WHERE destination_id=? AND state='waiting'", [id.sql])
            try record(.resume, context: EventContext(destinationID: id), decision: .reconcile)
        }
    }
    public func beginScan() throws -> UUID {
        let id = UUID()
        try transaction {
            try db.execute("INSERT INTO scans(id,created) VALUES(?,?)", [id.sql, Date().sql])
            try db.execute("INSERT INTO meta(key,value) VALUES('scan',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", [id.sql])
            try record(.scanStart, decision: .proceed)
        }
        return id
    }
    /// P3 enumerates PhotoKit in bounded pages. Return canonical IDs so rescans
    /// do not manufacture new local asset identities. No media bytes are retained.
    public func registerAssets(_ assets: [AssetIdentity], scanID: UUID) throws -> [AssetIdentity] {
        guard assets.count <= 200 else { throw CoreError.invalidContract }
        return try transaction {
            guard try db.rows("SELECT id FROM scans WHERE id=? AND complete=0", [scanID.sql]).count == 1 else { throw CoreError.invalidTransition }
            var canonical: [AssetIdentity] = []
            for asset in assets {
                guard UploadPlan.hex(asset.generation, length: 64), !asset.localIdentifier.isEmpty,
                      !asset.localIdentifier.contains("\0"), asset.localIdentifier.utf8.count <= 512 else { throw CoreError.invalidContract }
                if let row = try db.rows("SELECT body FROM assets WHERE local_id=? AND generation=?", [.text(asset.localIdentifier), .text(asset.generation)]).first {
                    let existing = try db.decode(AssetIdentity.self, row, "body")
                    guard existing.kind == asset.kind else { throw CoreError.invalidContract }
                    canonical.append(existing)
                    try db.execute("UPDATE assets SET scan_id=? WHERE id=?", [scanID.sql, existing.id.sql])
                } else {
                    try db.execute("INSERT INTO assets(id,local_id,generation,kind,body,scan_id) VALUES(?,?,?,?,?,?)", [asset.id.sql, .text(asset.localIdentifier), .text(asset.generation), .text(asset.kind.rawValue), try db.encode(asset), scanID.sql])
                    canonical.append(asset)
                }
            }
            try record(.scanPage, decision: .proceed, critical: false)
            return canonical
        }
    }
    public func completeScan(_ id: UUID) throws {
        try transaction {
            try db.execute("UPDATE scans SET complete=1 WHERE id=?", [id.sql])
            guard db.changes == 1 else { throw CoreError.invalidTransition }
            try record(.scanComplete, decision: .proceed)
        }
    }
    /// Private, bounded source-v1 JSON recipe: PhotoKit resource descriptors,
    /// measured original hashes, metadata and lossless split recipe. No media
    /// bytes/credentials. P3 owns its Codable schema; diagnostics never export it.
    public func saveSourceRecipe(assetID: UUID, json: Data) throws {
        guard !json.isEmpty, json.count <= 262_144,
              (try? JSONSerialization.jsonObject(with: json)) != nil else { throw CoreError.invalidContract }
        try transaction {
            try db.execute("INSERT INTO source_recipes(asset_id,body) VALUES(?,?) ON CONFLICT(asset_id) DO UPDATE SET body=excluded.body", [assetID.sql, .blob(json)])
        }
    }
    public func sourceRecipe(assetID: UUID) throws -> Data? {
        try db.rows("SELECT body FROM source_recipes WHERE asset_id=?", [assetID.sql]).first.map { try $0.data("body") }
    }
    @discardableResult public func enqueue(assetID: UUID, destinationID: UUID, plan: UploadPlan) throws -> UUID {
        try plan.validate()
        return try transaction {
            let existing = try db.rows("SELECT id,plan FROM jobs WHERE destination_id=? AND coverage=?", [destinationID.sql, .text(plan.coverageHash)]).first
            let id: UUID
            if let existing {
                guard let storedID = UUID(uuidString: try existing.string("id")) else { throw CoreError.invalidContract }
                let stored = try db.decode(UploadPlan.self, existing, "plan")
                // Resource UUIDs can differ after reinstall/rescan; deterministic
                // tags, ordering, originals and frozen policy must still agree.
                guard stored.policyVersion == plan.policyVersion,
                      stored.resources.map(\.tag) == plan.resources.map(\.tag),
                      stored.resources.map(\.originals) == plan.resources.map(\.originals),
                      stored.resources.map(\.role) == plan.resources.map(\.role) else { throw CoreError.invalidContract }
                id = storedID
            } else {
                id = UUID()
                try db.execute("INSERT INTO jobs(id,destination_id,asset_id,coverage,plan,state,cycle) VALUES(?,?,?,?,?,'checking',?)", [id.sql, destinationID.sql, assetID.sql, .text(plan.coverageHash), try db.encode(plan), UUID().sql])
                for resource in plan.resources {
                    try db.execute("INSERT INTO obligations(job_id,resource_id,tag) VALUES(?,?,?)", [id.sql, resource.id.sql, .text(resource.tag)])
                }
            }
            try db.execute("INSERT INTO aliases(job_id,asset_id,destination_id) VALUES(?,?,?) ON CONFLICT(asset_id,destination_id) DO UPDATE SET job_id=excluded.job_id", [id.sql, assetID.sql, destinationID.sql])
            // Deliberately do not reset failed/exhausted/unknown jobs on a rescan.
            return id
        }
    }
    func loadJob(_ id: UUID) throws -> JobRecord {
        guard let row = try db.rows("SELECT j.*,d.body AS destination_body,a.body AS asset_body FROM jobs j JOIN destinations d ON d.id=j.destination_id JOIN assets a ON a.id=COALESCE((SELECT x.asset_id FROM aliases x JOIN assets ax ON ax.id=x.asset_id WHERE x.job_id=j.id ORDER BY (ax.scan_id=(SELECT value FROM meta WHERE key='scan')) DESC,x.asset_id LIMIT 1),j.asset_id) WHERE j.id=?", [id.sql]).first,
              let cycle = UUID(uuidString: try row.string("cycle")), let state = JobState(rawValue: try row.string("state")) else { throw CoreError.invalidContract }
        return JobRecord(id: id, destination: try db.decode(Destination.self, row, "destination_body"), asset: try db.decode(AssetIdentity.self, row, "asset_body"), plan: try db.decode(UploadPlan.self, row, "plan"), state: state, cycleID: cycle, attempts: Int(row.int("attempts")), retryAt: row.double("retry_at").map(Date.init(timeIntervalSince1970:)))
    }
    public func job(_ id: UUID) throws -> JobRecord { try loadJob(id) }
    func context(_ job: JobRecord, runID: UUID? = nil, resource: UUID? = nil) -> EventContext {
        EventContext(runID: runID, origin: job.destination.provider.origin, destinationID: job.destination.id,
                     jobID: job.id, assetID: job.asset.id, resourceID: resource, cycleID: job.cycleID, attempt: job.attempts)
    }
    public func receipts(for jobID: UUID) throws -> [RemoteReceipt] {
        try db.rows("SELECT r.body FROM receipts r JOIN jobs j ON j.destination_id=r.destination_id JOIN obligations o ON o.job_id=j.id AND o.tag=r.tag WHERE j.id=?", [jobID.sql]).map { try db.decode(RemoteReceipt.self, $0, "body") }
    }
    public func missingResources(for jobID: UUID) throws -> [ResourceRequirement] {
        let job = try loadJob(jobID)
        let tags = try Set(db.rows("SELECT tag FROM obligations WHERE job_id=? AND status!='confirmed'", [jobID.sql]).map { try $0.string("tag") })
        return job.plan.resources.filter { tags.contains($0.tag) }
    }
}
