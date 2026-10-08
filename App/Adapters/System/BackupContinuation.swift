import Foundation
#if os(iOS)
import BackgroundTasks
#endif

/// One registered workload and at most one continued task. No scheduled backups,
/// GPU entitlement, fake keepalive or assumption that submit implies a launch.
@MainActor
final class BackupContinuation {
    enum State: Equatable { case unavailable, idle, requested, running, expired }
    private(set) var state: State = .unavailable
    var onChange: (@MainActor () -> Void)?
    var onExpiration: (@MainActor () -> Void)?
    #if os(iOS)
    private let identifier = "com.tinyredphoenix.Cloudified.backup"
    private var task: BGContinuedProcessingTask?
    #endif
    init() {
        #if os(iOS)
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { [weak self] task in
            MainActor.assumeIsolated {
                guard let self, let continued = task as? BGContinuedProcessingTask,
                      self.state == .requested else { task.setTaskCompleted(success: false); return }
                self.task = continued; self.state = .running
                continued.expirationHandler = { [weak self] in
                    Task { @MainActor in
                        guard let self else { return }
                        self.state = .expired; self.onChange?(); self.onExpiration?()
                    }
                }
                self.onChange?()
            }
        }
        state = registered ? .idle : .unavailable
        #endif
    }
    /// Called only from explicit Back Up/Resume while foregrounded.
    func request() throws {
        #if os(iOS)
        guard state == .idle || state == .expired else { return }
        state = .requested
        let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: "Cloudified backup", subtitle: "Checking originals")
        request.strategy = .fail // No surprise queued launch after user leaves.
        do { try BGTaskScheduler.shared.submit(request) }
        catch { state = .idle; onChange?(); throw error }
        onChange?()
        #endif
    }
    func update(confirmed: Int, total: Int?, subtitle: String) {
        #if os(iOS)
        guard let task, state == .running else { return }
        if let total {
            task.progress.totalUnitCount = Int64(max(1, total))
            task.progress.completedUnitCount = Int64(min(max(0, confirmed), total))
        } else { task.progress.totalUnitCount = -1 }
        task.updateTitle("Cloudified backup", subtitle: subtitle)
        #endif
    }
    /// Owner joins actual workers first; retained receipts/inputs are never erased.
    func finish(success: Bool) {
        #if os(iOS)
        guard state != .idle && state != .unavailable else { return }
        if let task { task.expirationHandler = nil; task.setTaskCompleted(success: success); self.task = nil }
        else if state == .requested { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier) }
        if state != .unavailable { state = .idle }
        onChange?()
        #endif
    }
    var allowsBackgroundExecution: Bool { state == .running }
    var summary: String {
        switch state {
        case .unavailable: return "Keep Cloudified open; background continuation unavailable"
        case .idle: return "Background continuation requested when you start a backup"
        case .requested: return "Waiting for system background continuation"
        case .running: return "System allows this backup to continue in background"
        case .expired: return "System continuation ended; resume to continue"
        }
    }
}
