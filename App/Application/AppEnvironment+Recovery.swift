import Foundation
import CloudifiedCore

extension AppEnvironment {
    func requestRecovery(_ provider: Provider) {
        guard bootstrapComplete, allowedNetwork, policyGate == nil, !shuttingDown else { return }
        if commandProvider != nil || recoveryTasks[provider] != nil { recoveryWake.insert(provider); return }
        recoveryWake.remove(provider)
        recoveryTasks[provider] = Task { [weak self] in
            guard let self else { return }
            defer {
                self.recoveryTasks[provider] = nil; self.scheduleThrottledRefresh()
                if self.recoveryWake.remove(provider) != nil { self.requestRecovery(provider) }
            }
            do {
                guard let ledger = self.ledger else { return }
                let snapshot = try await ledger.snapshot()
                var recoveredNow = false
                if snapshot.providers.first(where: { $0.provider == provider })?.recoveryComplete == true && snapshot.providers.first(where: { $0.provider == provider })?.blockedReason == nil {
                    if let destination = try await ledger.selectedDestination(provider) {
                        try await ledger.wakeWaiting(destinationID: destination.id)
                    }
                } else { await self.recoverProvider(provider); recoveredNow = true }
                if self.backupRequested { self.requestDrain() }
                await self.establishStartupInventory()
                if recoveredNow { await self.refreshStoredSettings() }
            } catch { await self.report(error, provider: provider) }
        }
    }
    func recoverProvider(_ provider: Provider) async {
        guard let ledger, let engine = backupEngine else { return }
        do {
            guard try await engine.snapshot().active[provider] == nil else { return }
            if provider == .google {
                guard let session = googleSession else { throw SafeFailure(.invariant, domain: .core, cause: .setupUnavailable) }
                if !(await session.hasConfiguredCredential) {
                    do { try await session.loadSavedSession() }
                    catch CredentialError.notConfigured {
                        if try await ledger.selectedDestination(provider) == nil { return }
                        throw CredentialError.notConfigured
                    }
                }
            } else {
                do { try await ensureTelegramStarted() }
                catch CredentialError.notConfigured {
                    if try await ledger.selectedDestination(provider) == nil { return }
                    throw CredentialError.notConfigured
                }
            }
            guard allowedNetwork else { throw SafeFailure(.connectivity, domain: .core, cause: settingsState.isWiFiOnlyEnabled && network?.available == true ? .wifiRequired : .offline) }
            // Old retained mappings must settle before changing the adapter's scope
            // to the selected mapping. The adapter owns only one verified scope.
            var cursor: UUID?
            var selected: Destination?
            while true {
                let page = try await ledger.destinationInventoryPage(afterID: cursor)
                if page.isEmpty { break }
                for row in page where row.destination.provider == provider {
                    guard let binding = try await ledger.providerBinding(destinationID: row.destination.id), binding.profileID == "primary" else { throw CoreError.staleMapping }
                    if row.selected { selected = row.destination }
                    else if row.retainedTransferCount > 0 { try await recoverMapping(row.destination) }
                }
                cursor = page.last?.destination.id
            }
            if let selected {
                // Never inventory/recover over an active foreground reader.
                guard try await engine.snapshot().active[provider] == nil else { return }
                try await recoverMapping(selected)
                try await ledger.unblockDestination(selected.id)
            }
            providerErrors.removeValue(forKey: provider)
            if provider == .google { settingsState.googleAuthErrorMessage = nil }
            else { settingsState.telegramAuthErrorMessage = nil }
        } catch { await report(error, provider: provider) }
    }
    func recoverMapping(_ destination: Destination) async throws {
        switch destination.provider {
        case .google:
            guard let googleAdapter else { throw CoreError.recoveryRequired }
            try await googleAdapter.recover(destination)
        case .telegram:
            guard let telegramAdapter else { throw CoreError.recoveryRequired }
            try await telegramAdapter.recover(destination)
        }
    }
    func ensureTelegramStarted() async throws {
        guard let client = tdlibClient else { throw SafeFailure(.invariant, domain: .core, cause: .setupUnavailable) }
        let auth = await client.authorizationState
        if auth == .uninitialized || auth == .waitTdlibParameters {
            try await client.setNetworkPolicy(allowed: policyGate == nil && !pausedByUser, wifi: network?.wifi == true)
            try await client.start()
        }
        updateTelegramAuthStep(await client.authorizationState)
    }
    func establishStartupInventory() async {
        guard !startupInventoryCompleted, let ledger, let files = fileLeaseStore else { return }
        do {
            let live = await telegramAdapter?.nativeTransferSnapshot() ?? []
            let owned = Set(live.map(\.transferID))
            var cursor: UUID?
            while true {
                let page = try await ledger.destinationInventoryPage(afterID: cursor)
                if page.isEmpty { break }
                for row in page where row.retainedTransferCount > 0 {
                    guard row.destination.provider == .telegram else { return }
                    var transferCursor: UUID?
                    while true {
                        let transfers = try await ledger.retainedTransfers(destinationID: row.destination.id, afterID: transferCursor)
                        if transfers.isEmpty { break }
                        guard transfers.allSatisfy({ owned.contains($0.id) }) else { return }
                        transferCursor = transfers.last?.id
                    }
                }
                cursor = page.last?.destination.id
            }
            // No persistent OS URLSession is injected: Google's real foreground
            // transports cannot outlive this process. Native paths are either
            // absent or covered by the live adapter above. No other startup writer.
            await files.completeStartupInventory(); startupInventoryCompleted = true
        } catch { await report(error, provider: nil) }
    }
    func refreshStoredSettings() async {
        guard let ledger else { return }
        do {
            let epoch = planningEpoch
            let snapshot = try await ledger.snapshot()
            guard epoch == planningEpoch else { return }
            let g = snapshot.providers.first { $0.provider == .google }
            let t = snapshot.providers.first { $0.provider == .telegram }
            settingsState.isGoogleConnected = g?.destinationID != nil
            settingsState.isGoogleEnabled = g?.enabled ?? false
            settingsState.isTelegramConnected = t?.destinationID != nil
            settingsState.isTelegramEnabled = t?.enabled ?? false
            if settingsState.isGoogleConnected {
                do { settingsState.googleAccountEmail = try credentialStore.loadGoogleCredential(forProfile: "primary").email }
                catch { settingsState.googleAccountEmail = nil }
            } else { settingsState.googleAccountEmail = nil }
            if let client = tdlibClient {
                let auth = await client.authorizationState; updateTelegramAuthStep(auth)
                if auth == .ready {
                    let me = try await client.getMe()
                    guard epoch == planningEpoch else { return }
                    settingsState.telegramAccountName = [me["first_name"]?.stringValue, me["last_name"]?.stringValue].compactMap { $0 }.joined(separator: " ")
                    if let id = t?.destinationID, let binding = try await ledger.providerBinding(destinationID: id) {
                        struct Scope: Decodable { let chatID: Int64 }
                        let scope = try JSONDecoder().decode(Scope.self, from: binding.scope)
                        let chat = try await client.request(["@type": "getChat", "chat_id": scope.chatID])
                        guard epoch == planningEpoch else { return }
                        settingsState.telegramChatID = scope.chatID
                        settingsState.telegramChannelName = chat["title"]?.stringValue
                    }
                }
            }
            scheduleThrottledRefresh()
        } catch { await report(error, provider: .telegram) }
    }
    func updateTelegramAuthStep(_ state: TDLibAuthorizationState) {
        switch state {
        case .uninitialized: settingsState.telegramAuthStep = .unconfigured
        case .waitTdlibParameters: settingsState.telegramAuthStep = .initializing
        case .waitPhoneNumber: settingsState.telegramAuthStep = .enterPhoneNumber
        case .waitCode: settingsState.telegramAuthStep = .enterCode
        case .waitPassword: settingsState.telegramAuthStep = .enterPassword
        case .waitEmailAddress: settingsState.telegramAuthStep = .enterEmail
        case .waitEmailCode: settingsState.telegramAuthStep = .enterEmailCode
        case .waitOtherDeviceConfirmation: settingsState.telegramAuthStep = .otherDeviceConfirmation
        case .waitRegistration: settingsState.telegramAuthStep = .registration
        case .waitPremiumPurchase: settingsState.telegramAuthStep = .premiumPurchase
        case .ready: settingsState.telegramAuthStep = settingsState.isTelegramConnected ? .connected : .readyForChannel
        case .loggingOut, .closing: settingsState.telegramAuthStep = .closing
        case .closed: settingsState.telegramAuthStep = .closed
        case .uncertain: settingsState.telegramAuthStep = .error
        }
    }
}
