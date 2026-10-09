import Foundation
import CloudifiedCore
#if os(iOS) && !targetEnvironment(macCatalyst)
import BackgroundTasks
#endif

/// User-started work only. System progress reflects measured work, never elapsed
/// time or a fabricated heartbeat; confirmed upload counters stay ledger-backed.
@MainActor
final class BackupContinuation {
    enum State: Equatable { case unavailable, idle, requested, running, expired }
    private(set) var state: State = .unavailable
    var onChange: (@MainActor () -> Void)?
    var onExpiration: (@MainActor () -> Void)?
    private(set) var submissionErrorCode: Int?
    #if os(iOS) && !targetEnvironment(macCatalyst)
    private var identifier: String?
    private var registeredIdentifiers: [String: String] = [:]
    private var task: BGContinuedProcessingTask?
    private let prefixes: [String]
    #endif

    /// Prefer the signed bundle when permitted; retain the narrow built-plist
    /// fallback used by pinned PhotosBackup for SideStore's bundle renaming.
    static func identifierPrefixes(bundleID: String?, permitted: [String]) -> [String] {
        let entries = Array(permitted.prefix(32)).filter { $0.hasSuffix(".backup.*") }
        var result: [String] = []
        if let bundleID, !bundleID.isEmpty {
            let own = bundleID + ".backup."
            if entries.contains(where: { own.hasPrefix(String($0.dropLast())) }) { result.append(own) }
        }
        for entry in entries {
            let prefix = String(entry.dropLast())
            if !result.contains(prefix) { result.append(prefix) }
        }
        return Array(result.prefix(4))
    }
    init() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        prefixes = Self.identifierPrefixes(bundleID: Bundle.main.bundleIdentifier,
            permitted: Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? [])
        state = prefixes.isEmpty ? .unavailable : .idle
        #endif
    }
    /// Only explicit Back Up/Resume while foregrounded. Register each concrete
    /// identifier once per process; reuse its handler for subsequent backup runs.
    func request() throws {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard task == nil, state == .idle || state == .expired || (state == .unavailable && !prefixes.isEmpty) else { return }
        submissionErrorCode = nil
        for prefix in prefixes {
            let id: String
            if let registered = registeredIdentifiers[prefix] { id = registered }
            else {
                id = prefix + UUID().uuidString
                let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: .main) { [weak self] task in
                    MainActor.assumeIsolated {
                        guard let self, self.identifier == id, self.state == .requested,
                              let continued = task as? BGContinuedProcessingTask else {
                            task.setTaskCompleted(success: false); return
                        }
                        self.task = continued; self.state = .running
                        continued.expirationHandler = { [weak self] in
                            Task { @MainActor in
                                guard let self, self.identifier == id else { return }
                                self.state = .expired; self.onChange?(); self.onExpiration?()
                            }
                        }
                        self.onChange?()
                    }
                }
                guard registered else { submissionErrorCode = BGTaskScheduler.Error.Code.notPermitted.rawValue; continue }
                registeredIdentifiers[prefix] = id
            }
            identifier = id; state = .requested
            let request = BGContinuedProcessingTaskRequest(identifier: id, title: "Cloudified backup", subtitle: "Checking originals")
            request.strategy = .fail
            do { try BGTaskScheduler.shared.submit(request); onChange?(); return }
            catch {
                identifier = nil; state = .idle
                let code = (error as NSError).code; submissionErrorCode = code
                if code != BGTaskScheduler.Error.Code.notPermitted.rawValue {
                    onChange?()
                    throw SafeFailure(.connectivity, domain: .core, code: code, cause: .backgroundRestricted)
                }
            }
        }
        state = .unavailable; onChange?()
        throw SafeFailure(.connectivity, domain: .core, code: submissionErrorCode, cause: .backgroundRestricted)
        #endif
    }
    /// Fractions include confirmed component receipts and real bytes within each
    /// active asset. A retry may reduce its fraction; it never becomes Saved here.
    func update(confirmed: Int, total: Int?, activeFractions: [Double], subtitle: String) {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard let task, state == .running else { return }
        let units: Int64 = 1_000_000
        if let total, total >= 0, total <= Int(Int64.max / units) {
            let goal = max(1, Int64(total) * units)
            var done = total == 0 ? goal : Int64(max(0, min(confirmed, total))) * units
            for fraction in activeFractions.prefix(64) where fraction.isFinite && fraction > 0 {
                let partial = Int64(min(0.999999, fraction) * Double(units))
                let sum = done.addingReportingOverflow(partial)
                done = sum.overflow ? goal : min(goal, sum.partialValue)
            }
            if confirmed < total { done = min(done, goal - 1) }
            task.progress.totalUnitCount = goal; task.progress.completedUnitCount = done
        } else { task.progress.totalUnitCount = -1 }
        task.updateTitle("Cloudified backup", subtitle: subtitle)
        #endif
    }
    /// Join actual workers first. Recovery records and owned inputs stay durable.
    func finish(success: Bool) {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard state != .idle && state != .unavailable else { return }
        if let task { task.expirationHandler = nil; task.setTaskCompleted(success: success); self.task = nil }
        else if state == .requested, let identifier { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier) }
        identifier = nil; state = .idle; onChange?()
        #endif
    }
    var allowsBackgroundExecution: Bool { state == .running }
    var summary: String {
        if let submissionErrorCode, state == .unavailable || state == .idle {
            return "Keep Cloudified open; system background request failed (code \(submissionErrorCode))"
        }
        switch state {
        case .unavailable: return "Keep Cloudified open; background continuation unavailable"
        case .idle: return "Background continuation requested when you start a backup"
        case .requested: return "Waiting for system background continuation"
        case .running: return "System allows this backup to continue in background"
        case .expired: return "System continuation ended; resume to continue"
        }
    }
}
