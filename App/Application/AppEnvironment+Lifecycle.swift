import Foundation
import CloudifiedCore

extension AppEnvironment {
    var allowedNetwork: Bool {
        guard let network, network.available, !network.constrained else { return false }
        return !settingsState.isWiFiOnlyEnabled || (network.wifi && !network.expensive)
    }
    var policyGate: KnownCause? {
        if !isForeground && !continuation.allowsBackgroundExecution { return .backgroundRestricted }
        if ProcessInfo.processInfo.thermalState == .critical || ProcessInfo.processInfo.thermalState == .serious { return .thermalPressure }
        if network?.available != true { return .offline }
        if network?.constrained == true { return .lowDataMode }
        if !allowedNetwork { return .wifiRequired }
        return nil
    }
    func schedulePolicyUpdate() {
        policyDirty = true
        guard policyTask == nil, !shuttingDown else { return }
        policyTask = Task { [weak self] in
            while self?.policyDirty == true && !Task.isCancelled {
                self?.policyDirty = false
                await self?.applyPolicy()
            }
            self?.policyTask = nil
        }
    }
    func applyPolicy() async {
        guard let engine = backupEngine else { return }
        let cause = policyGate
        var old: KnownCause?
        do {
            old = try await engine.snapshot().systemGate
            if cause != old { try await engine.setSystemGate(cause) }
        } catch { await report(error, provider: nil) }
        // Enforce the native network gate even if SQLite/logging fails.
        do { try await tdlibClient?.setNetworkPolicy(allowed: cause == nil && !pausedByUser, wifi: network?.wifi == true) }
        catch { await report(error, provider: .telegram) }
        if cause != nil {
            if let sourceProducer { _ = await sourceProducer.stop() }
        } else {
            if old != nil { requestRecovery(.google); requestRecovery(.telegram) }
            if backupRequested && (old != nil || needsWake) { requestDrain() }
        }
        scheduleThrottledRefresh()
    }
    public func applicationActive() {
        isForeground = true
        schedulePolicyUpdate(); scheduleThrottledRefresh()
        if backupRequested { requestDrain() }
    }
    public func applicationBackgrounded() {
        isForeground = false
        onMemoryPressure?()
        // Pages are disposable; durable failures/receipts remain in SQLite.
        failurePageTask?.cancel(); logPageTask?.cancel(); runPageTask?.cancel()
        failureQueryGeneration += 1; logQueryGeneration += 1
        notUploadedState.items.removeAll(); logsState.entries.removeAll()
        notUploadedState.isLoading = false; logsState.isLoading = false
        schedulePolicyUpdate()
    }
    public func resourcePressureChanged() { schedulePolicyUpdate(); scheduleThrottledRefresh() }
    public func memoryWarning() {
        onMemoryPressure?()
        failurePageTask?.cancel(); logPageTask?.cancel(); runPageTask?.cancel()
        failureQueryGeneration += 1; logQueryGeneration += 1
        notUploadedState.items.removeAll(); logsState.entries.removeAll()
        notUploadedState.isLoading = false; logsState.isLoading = false
        scheduleThrottledRefresh()
    }
    func backgroundExpired() {
        backupRequested = false; needsWake = false
        retryTask?.cancel(); retryTask = nil
        Task { [weak self] in
            guard let self else { return }
            do { try await self.backupEngine?.setSystemGate(.backgroundExpired) } catch { await self.report(error, provider: nil) }
            if let source = self.sourceProducer { _ = await source.stop() }
            let run = self.backupExecutionTask; run?.cancel(); await run?.value
            do { try await self.tdlibClient?.setNetworkPolicy(allowed: false, wifi: false) } catch { await self.report(error, provider: .telegram) }
            do {
                try await self.ledger?.appendEvent(.backgroundExpiration, context: EventContext(), decision: .reconcile,
                    severity: .warning, failure: SafeFailure(.connectivity, domain: .core, cause: .backgroundExpired))
            } catch { await self.report(error, provider: nil) }
            self.continuation.finish(success: false)
            self.dashboardState.waitingOrErrorReason = "Background time ended. Resume to continue safely."
            self.scheduleThrottledRefresh()
        }
    }
    func idleCleanup() async {
        guard cleanupTask == nil, commandProvider == nil else { return }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performIdleCleanup()
        }
        cleanupTask = task; await task.value; cleanupTask = nil
    }
    func performIdleCleanup() async {
        guard !isScanning, planningProvider == nil, let ledger, let files = fileLeaseStore else { return }
        do {
            if startupInventoryCompleted {
                _ = try await files.sweep(limit: 20)
                _ = try await files.reclaimOrphans(limit: 20)
            }
            _ = try await ledger.pruneDiagnostics()
            var cursor: UUID?, hasHolds = false
            while true {
                let page = try await ledger.destinationInventoryPage(afterID: cursor)
                if page.isEmpty { break }
                if page.contains(where: { $0.retainedTransferCount > 0 }) { hasHolds = true; break }
                cursor = page.last?.destination.id
            }
            if !hasHolds { try await telegramAdapter?.trimIdleCache() }
            let snapshot = try await ledger.snapshot()
            if !hasHolds && retryTask == nil && !needsWake && continuation.state != .idle {
                let success = snapshot.providers.filter { $0.destinationID != nil }.allSatisfy { $0.remaining == 0 }
                continuation.finish(success: success && snapshot.scanned)
            }
        } catch { await report(error, provider: nil) }
    }
    /// Explicit owner shutdown. Never discard an unresolved native receiver.
    public func shutdown() async {
        shuttingDown = true; backupRequested = false; needsWake = false
        retryTask?.cancel(); bootstrapTask?.cancel(); policyTask?.cancel()
        refreshTask?.cancel(); cleanupTask?.cancel(); sourceStatusTask?.cancel()
        failurePageTask?.cancel(); logPageTask?.cancel(); runPageTask?.cancel()
        for task in recoveryTasks.values { task.cancel() }
        do { try await backupEngine?.pause() } catch { fallback.record(ProviderSupport.safe(error, domain: .core)) }
        if let sourceProducer { _ = await sourceProducer.stop() }
        backupExecutionTask?.cancel(); await backupExecutionTask?.value
        await bootstrapTask?.value; await policyTask?.value
        for task in recoveryTasks.values { await task.value }
        do { try await telegramAdapter?.close() } catch {
            fallback.record(ProviderSupport.safe(error, domain: .tdlib)); return
        }
        for task in observers + telegramObservers { task.cancel() }
        for task in observers + telegramObservers { await task.value }
        observers.removeAll(); telegramObservers.removeAll()
        networkMonitor.stop(); continuation.finish(success: false)
    }
}
