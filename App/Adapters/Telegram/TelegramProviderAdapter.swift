import Foundation
import CloudifiedCore

/// One native client and one bounded update consumer. Eight uncertain sends may
/// retain ownership without preventing unrelated ready assets from proceeding.
/// Three logical attempts remain exclusively owned by BackupEngine/Ledger.
struct TelegramNativeTransferStatus: Sendable {
    enum Activity: Sendable, Equatable { case uploading, awaitingAcknowledgement, waitingForConnection, uncertain }
    let transferID: UUID
    let destinationID: UUID
    let jobID: UUID
    let resourceTag: String
    let uploadedBytes: Int64
    let expectedBytes: Int64
    let activity: Activity
}
actor TelegramProviderAdapter: ProviderAdapter {
    nonisolated let provider = Provider.telegram
    nonisolated let recoveryEvents: AsyncStream<Void>
    nonisolated let statusEvents: AsyncStream<Void>
    private let statusContinuation: AsyncStream<Void>.Continuation
    private let eventContinuation: AsyncStream<Void>.Continuation
    private struct Scope: Codable, Equatable { let version: Int; let userID: Int64; let chatID: Int64 }
    private struct State: Codable, Sendable {
        let chatID: Int64
        let sendingID: Int32
        let byteCount: Int64
        let filename: String
        var temporaryID: Int64?
        var fileID: Int32?
        var reference: TelegramDocumentReference?
    }
    private enum Resolution: Sendable {
        case confirmed(TelegramDocumentReference)
        case rejected(SafeFailure, TimeInterval?)
        case uncertain(SafeFailure)
    }
    private struct Pending {
        var checkpoint: ProviderCheckpoint
        var state: State
        var resolution: Resolution?
        var waiter: CheckedContinuation<Resolution, Never>?
        var deadline: Task<Void, Never>?
        var pump: ProviderProgressPump?
        var uploadedBytes: Int64 = 0
        var nativeActive = false
    }
    private let client: TDLibClient
    private let ledger: Ledger
    private let files: FileLeaseStore
    private let inputFiles: TelegramInputFiles
    private var mapped: Destination?
    private var scope: Scope?
    private var consumer: Task<Void, Never>?
    private var streamFailure: SafeFailure?
    private var pending: [Int32: Pending] = [:]
    private var nextSendingID: Int32 = 1
    private var busy = false
    private var epoch: UUID?
    private var historyRevision: UInt64 = 0
    private var scanning = false

    init(client: TDLibClient, ledger: Ledger, files: FileLeaseStore) {
        self.client = client; self.ledger = ledger; self.files = files
        let events = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        recoveryEvents = events.stream; eventContinuation = events.continuation
        let status = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        statusEvents = status.stream; statusContinuation = status.continuation
        inputFiles = TelegramInputFiles(stagingRoot: files.root)
    }
    /// Real retained native work remains visible after the Core worker stops
    /// waiting. The UI merges by transfer/job identity, never inventing Saved.
    var canAcceptWork: Bool { get async { pending.count < 8 && streamFailure == nil } }
    func nativeTransferSnapshot() async -> [TelegramNativeTransferStatus] {
        let connected = await client.connectionReady
        return pending.values.filter { $0.checkpoint.phase == .transferring || $0.checkpoint.phase == .uncertain }.map { item in
            TelegramNativeTransferStatus(transferID: item.checkpoint.transferID, destinationID: item.checkpoint.destinationID,
                jobID: item.checkpoint.jobID, resourceTag: item.checkpoint.tag, uploadedBytes: item.uploadedBytes, expectedBytes: item.state.byteCount,
                activity: streamFailure != nil ? .uncertain : (!connected ? .waitingForConnection : (item.nativeActive ? .uploading : .awaitingAcknowledgement)))
        }
    }
    func mapVerifiedChannel(chatID: Int64) async throws -> Destination {
        guard !busy, pending.isEmpty else { throw CoreError.invalidTransition }; busy = true; defer { busy = false }
        try await startConsumer()
        let verified = try await verifyChannel(chatID)
        let body = try ProviderSupport.canonical(verified)
        let destination = try await ledger.selectDestination(Destination(provider: .telegram, verifiedFingerprint: ProviderSupport.fingerprint(body)))
        try await ledger.bindProviderProfile(destination: destination, profileID: client.profileID, scope: body)
        mapped = destination; scope = verified; epoch = nil
        return destination
    }
    private func verifyChannel(_ chatID: Int64) async throws -> Scope {
        guard await client.authorizationState == .ready, !(await client.requiresReconciliation), streamFailure == nil else {
            throw streamFailure ?? SafeFailure(.authentication, domain: .tdlib, cause: .loginRequired)
        }
        guard await client.connectionReady else { throw SafeFailure(.connectivity, domain: .tdlib, cause: .offline) }
        let me = try await client.getMe()
        let chat = try await client.request(["@type": "getChat", "chat_id": chatID])
        guard let userID = me["id"]?.int64Value, userID > 0, me.object(forKey: "type")?.type == "userTypeRegular",
              chat["id"]?.int64Value == chatID, chat["message_auto_delete_time"]?.int32Value == 0,
              let type = chat.object(forKey: "type"), type.type == "chatTypeSupergroup", type["is_channel"]?.boolValue == true,
              let groupID = type["supergroup_id"]?.int64Value else {
            throw SafeFailure(.accessDenied, domain: .tdlib, cause: .privateChannelRequired)
        }
        let group = try await client.request(["@type": "getSupergroup", "supergroup_id": groupID])
        // Creator access gives full channel history, even when it is hidden from
        // new members. Initially require an owned private archival channel.
        guard group["is_channel"]?.boolValue == true,
              group.object(forKey: "status")?.type == "chatMemberStatusCreator",
              group.object(forKey: "status")?["is_member"]?.boolValue == true,
              group.object(forKey: "usernames") == nil || group.object(forKey: "usernames")?.array(forKey: "active_usernames")?.isEmpty == true else {
            throw SafeFailure(.accessDenied, domain: .tdlib, cause: .privateChannelRequired)
        }
        _ = try await client.request(["@type": "getSupergroupFullInfo", "supergroup_id": groupID])
        return Scope(version: 1, userID: userID, chatID: chatID)
    }
    private func verify(_ destination: Destination) async throws {
        guard destination.provider == .telegram,
              let binding = try await ledger.providerBinding(destinationID: destination.id), binding.profileID == client.profileID else { throw CoreError.staleMapping }
        let saved = try JSONDecoder().decode(Scope.self, from: binding.scope)
        let verified = try await verifyChannel(saved.chatID)
        let body = try ProviderSupport.canonical(verified)
        guard verified == saved, ProviderSupport.fingerprint(body) == destination.verifiedFingerprint else { throw CoreError.staleMapping }
        mapped = destination; scope = verified
    }
    private func startConsumer() async throws {
        if consumer != nil { guard streamFailure == nil else { throw streamFailure! }; return }
        let updates = try await client.updates()
        consumer = Task { [weak self] in
            do {
                for try await update in updates { guard let self else { return }; try await self.handle(update) }
                await self?.streamEnded(SafeFailure(.reconciliation, domain: .tdlib, cause: .interrupted))
            } catch { await self?.streamEnded(ProviderSupport.safe(error, domain: .tdlib)) }
        }
    }
    private func streamEnded(_ failure: SafeFailure) {
        streamFailure = failure; epoch = nil; eventContinuation.yield(()); statusContinuation.yield(())
        for id in Array(pending.keys) { resolve(id, .uncertain(failure)) }
    }
    private func scanIndex(destination: Destination, chatID: Int64) async throws {
        guard !scanning else { throw CoreError.invalidTransition }; scanning = true; defer { scanning = false }
        let generation = historyRevision
        let scan = try await ledger.beginRemoteIndex(destinationID: destination.id)
        epoch = nil
        var cursor: Int64 = 0
        while true {
            try Task.checkCancellation()
            let page = try await client.request(["@type": "searchChatMessages", "chat_id": chatID,
                "query": "", "from_message_id": cursor, "offset": 0, "limit": 10,
                "filter": ["@type": "searchMessagesFilterDocument"]])
            guard page.type == "foundChatMessages", let values = page.array(forKey: "messages"), values.count <= 10,
                  let next = page["next_from_message_id"]?.int64Value, next >= 0,
                  next == 0 || (next != cursor && (cursor == 0 || next < cursor)) else { throw incompleteHistory() }
            var entries: [RemoteIndexEntry] = []
            for value in values {
                guard let fields = value.objectValue else { throw incompleteHistory() }
                if let reference = try TelegramDocumentReference.parse(TDLibResponse(fields: fields), chatID: chatID) {
                    entries.append(RemoteIndexEntry(tag: reference.tag, reference: try ProviderSupport.canonical(reference)))
                }
            }
            try await ledger.addRemoteIndex(destinationID: destination.id, epoch: scan, entries: entries)
            if next == 0 { break } // Authoritative cursor, never page length/approximate total_count.
            guard !values.isEmpty else { throw incompleteHistory() }; cursor = next
        }
        _ = try await verifyChannel(chatID)
        guard historyRevision == generation, streamFailure == nil, !(await client.requiresReconciliation) else { throw incompleteHistory() }
        try await ledger.finishRemoteIndex(destinationID: destination.id, epoch: scan)
        epoch = scan
    }
    func inspect(destination: Destination, resource: ResourceRequirement) async -> RemotePresence {
        guard !busy else { return .unknown(incompleteHistory()) }; busy = true; defer { busy = false }
        do {
            try await startConsumer(); try await verify(destination)
            guard let scope else { throw CoreError.staleMapping }
            if epoch == nil { try await scanIndex(destination: destination, chatID: scope.chatID) }
            guard let epoch else { throw incompleteHistory() }
            let lookup = try await ledger.remoteIndex(destinationID: destination.id, epoch: epoch, tag: resource.tag)
            if let encoded = lookup.reference {
                let reference = try JSONDecoder().decode(TelegramDocumentReference.self, from: encoded)
                try await validate(reference, resource: resource)
                // A matching old item does not settle an independently pending
                // send's file reader. The retained job is excluded by Core until settled.
                return .present(try receipt(destination, reference, kind: .alreadyPresent))
            }
            if let old = try await ledger.providerCheckpoint(destinationID: destination.id, tag: resource.tag), old.phase != .rejected { return .unknown(SafeFailure(.reconciliation, domain: .tdlib, cause: .outcomeUnknown)) }
            guard lookup.complete, await client.connectionReady, !pending.values.contains(where: { $0.checkpoint.tag == resource.tag }) else { throw incompleteHistory() }
            return .verifiedAbsent
        } catch {
            let safe = ProviderSupport.safe(error, domain: .tdlib)
            if safe.category == .authentication || safe.category == .accessDenied || error is CoreError { return .destinationBlocked(safe, resumeAt: nil) }
            return .unknown(safe)
        }
    }
    private func validate(_ reference: TelegramDocumentReference, resource: ResourceRequirement) async throws {
        guard let scope else { throw CoreError.staleMapping }
        try reference.validate(chatID: scope.chatID, tag: resource.tag)
        let message = try await client.request(["@type": "getMessage", "chat_id": scope.chatID, "message_id": reference.messageID])
        guard let actual = try TelegramDocumentReference.parse(message, chatID: scope.chatID, expectedTag: resource.tag),
              actual.remoteUniqueID == reference.remoteUniqueID, actual.byteCount == reference.byteCount else { throw incompleteHistory() }
        if resource.role == .manifest {
            let data = try await manifestData(actual)
            let document = try ArchiveManifestBuilder.validate(data, expectedTag: resource.tag)
            for item in document.confirmedReferences {
                let linked = try JSONDecoder().decode(TelegramDocumentReference.self, from: item.finalReference)
                try linked.validate(chatID: scope.chatID, tag: item.tag)
                guard let entry = document.recipe.resources.first(where: { $0.tag == item.tag }), entry.byteCount == linked.byteCount else { throw CoreError.invalidContract }
                let remote = try await client.request(["@type": "getMessage", "chat_id": scope.chatID, "message_id": linked.messageID])
                guard let found = try TelegramDocumentReference.parse(remote, chatID: scope.chatID, expectedTag: linked.tag),
                      found.remoteUniqueID == linked.remoteUniqueID, found.byteCount == linked.byteCount else { throw incompleteHistory() }
            }
        } else {
            guard resource.originals.count == 1, resource.originals[0].byteCount == reference.byteCount else { throw CoreError.invalidContract }
        }
    }
    private func manifestData(_ reference: TelegramDocumentReference) async throws -> Data {
        guard reference.byteCount <= 1_048_576 else { throw CoreError.invalidContract }
        let response = try await client.request(["@type": "downloadFile", "file_id": reference.fileID,
            "priority": 1, "offset": 0, "limit": reference.byteCount, "synchronous": true], timeout: 120)
        guard response.type == "file", response["size"]?.int64Value == reference.byteCount,
              let local = response.object(forKey: "local"), local["is_downloading_completed"]?.boolValue == true,
              let path = local["path"]?.stringValue else { throw incompleteHistory() }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let roots = try TDLibClient.storageURLs(forProfile: client.profileID)
        guard url.resolvingSymlinksInPath() == url, url.path.hasPrefix(roots.filesURL.path + "/") else { throw CoreError.invalidContract }
        let properties = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard properties.isRegularFile == true, properties.isSymbolicLink != true,
              properties.fileSize.map(Int64.init) == reference.byteCount else { throw CoreError.invalidContract }
        let data = try Data(contentsOf: url)
        // Only the validated TD cache copy is removed; staging/Apple originals
        // cannot pass the canonical-root check above.
        _ = try await client.request(["@type": "deleteFile", "file_id": reference.fileID])
        return data
    }
    func upload(job: JobRecord, resource: ResourceRequirement, files inputs: [LeasedFile], transferID: UUID,
                progress: @escaping @Sendable (TransferProgress) async -> Void) async -> CloudifiedCore.UploadOutcome {
        guard !busy, pending.count < 8 else { return .failed(UploadFailure(SafeFailure(.reconciliation, domain: .tdlib, cause: .outcomeUnknown), disposition: .waiting, acceptance: .definitelyNotAccepted, didStartTransfer: false), .terminal) }
        busy = true; defer { busy = false }
        var submitted = false
        var sendReturned = false
        var sendingID: Int32?
        var state: State?
        let pump = ProviderProgressPump(resourceID: resource.id, report: progress); pump.start()
        do {
            try await startConsumer(); try await verify(job.destination)
            guard let scope, inputs.count == 1, let input = inputs.first else { throw CoreError.invalidContract }
            if let old = try await ledger.providerCheckpoint(destinationID: job.destination.id, tag: resource.tag), old.phase != .rejected { throw CoreError.recoveryRequired }
            let filename: String
            if resource.role == .manifest {
                guard input.byteCount <= 1_048_576 else { throw CoreError.invalidContract }
                _ = try ArchiveManifestBuilder.validate(Data(contentsOf: input.url), expectedTag: resource.tag)
                filename = "Cloudified-manifest-v2.json"
            } else {
                guard resource.originals.count == 1, input.byteCount == resource.originals[0].byteCount,
                      let data = try await ledger.sourceRecipe(assetID: job.asset.id) else { throw CoreError.invalidContract }
                let recipe = try JSONDecoder().decode(SourceRecipe.self, from: data); try recipe.validate()
                let content = resource.originals[0]
                let measured = try await ProviderSupport.hashFile(input.url)
                guard measured.sha256 == content.sha256, measured.sha1 == content.sha1, measured.byteCount == content.byteCount else { throw CoreError.invalidContract }
                if let part = content.partIndex {
                    guard let master = recipe.videoSplits.first(where: { $0.parts.contains(where: { $0.originalContent == content }) }),
                          let original = recipe.resources.first(where: { $0.sha256 == master.originalSha256 && $0.role == master.role }) else { throw CoreError.invalidContract }
                    filename = String(decoding: Array(original.originalFilename.utf8.prefix(180)), as: UTF8.self) + ".part-\(part + 1)-of-\(content.partCount ?? 0)"
                } else {
                    guard let original = recipe.resources.first(where: { $0.originalContent == content }) else { throw CoreError.invalidContract }
                    filename = original.originalFilename
                }
            }
            // Account for a possible full native copy while both provider lanes
            // share staging. No second staged media copy is created by this app.
            try await ledger.reserveTransport(transferID, bytes: input.byteCount, availableBytes: ProviderSupport.availableBytes(at: input.url))
            guard nextSendingID < Int32.max else { throw CoreError.invalidTransition }
            let id = nextSendingID; nextSendingID += 1; sendingID = id
            var value = State(chatID: scope.chatID, sendingID: id, byteCount: input.byteCount, filename: filename)
            state = value
            try await save(job: job, resource: resource, transferID: transferID, phase: .prepared, state: value, terminal: true)
            let path = try inputFiles.create(transferID: transferID, input: input, filename: filename)
            let checkpoint = try await save(job: job, resource: resource, transferID: transferID, phase: .transferring, state: value, terminal: false)
            pending[id] = Pending(checkpoint: checkpoint, state: value, pump: pump)
            try Task.checkCancellation()
            submitted = true // Persisted/registered before handing the command to native.
            let sent = try await client.request(["@type": "sendMessage", "chat_id": scope.chatID,
                "options": ["@type": "messageSendOptions", "disable_notification": true, "sending_id": id],
                "input_message_content": ["@type": "inputMessageDocument",
                    "document": ["@type": "inputDocument", "document": ["@type": "inputFileLocal", "path": path.path], "disable_content_type_detection": true],
                    "caption": ["@type": "formattedText", "text": try ContentIdentity.telegramCaptionTag(resource), "entities": []]]])
            sendReturned = true
            try await capture(sent, sendingID: id)
            if let updated = pending[id]?.state { value = updated; state = value }
            let result = await awaitResolution(id)
            await pump.stop()
            switch pending[id]?.resolution ?? result {
            case .confirmed(let reference):
                pending.removeValue(forKey: id)
                return .confirmed(try receipt(job.destination, reference, kind: .uploaded), .terminal)
            case .rejected(let failure, let delay):
                pending.removeValue(forKey: id)
                return .failed(UploadFailure(failure, disposition: ProviderSupport.disposition(failure), acceptance: .definitelyNotAccepted, retryAfter: delay.map { Date().addingTimeInterval($0) }), .terminal)
            case .uncertain(let failure):
                pending[id]?.pump = nil
                return .failed(UploadFailure(failure, disposition: .waiting, acceptance: .unknown), .retainedByTransport)
            }
        } catch {
            await pump.stop()
            let safe = ProviderSupport.safe(error, domain: .tdlib)
            // At the pinned revision, sendMessage returns a native Error before
            // get_message_to_send/save_send_message_log_event/do_send_message.
            // Local document input with no thumbnail/conversion has no upload
            // reader in that branch. Bridge timeouts/cancellation are excluded.
            if submitted, !sendReturned, error is TDLibRequestRejection, let id = sendingID,
               pending[id]?.state.temporaryID == nil { submitted = false }
            if !submitted {
                if let id = sendingID { pending.removeValue(forKey: id) }
                if let state {
                    do {
                        try await save(job: job, resource: resource, transferID: transferID, phase: .rejected, state: state, terminal: true)
                        try inputFiles.remove(transferID: transferID)
                    } catch { return .failed(UploadFailure(ProviderSupport.safe(error, domain: .tdlib), disposition: .waiting, acceptance: .unknown, didStartTransfer: false), .retainedByTransport) }
                }
                return .failed(UploadFailure(safe, disposition: ProviderSupport.disposition(safe), acceptance: .definitelyNotAccepted, didStartTransfer: false), .terminal)
            }
            if let id = sendingID {
                pending[id]?.pump = nil
                if let result = pending[id]?.resolution {
                    switch result {
                    case .confirmed(let reference):
                        pending.removeValue(forKey: id)
                        do { return .confirmed(try receipt(job.destination, reference, kind: .uploaded), .terminal) }
                        catch { return .failed(UploadFailure(ProviderSupport.safe(error, domain: .tdlib), disposition: .waiting, acceptance: .unknown), .terminal) }
                    case .rejected(let failure, let delay):
                        pending.removeValue(forKey: id)
                        return .failed(UploadFailure(failure, disposition: ProviderSupport.disposition(failure), acceptance: .definitelyNotAccepted, retryAfter: delay.map { Date().addingTimeInterval($0) }), .terminal)
                    case .uncertain: break
                    }
                }
            }
            return .failed(UploadFailure(safe, disposition: ProviderSupport.disposition(safe), acceptance: .unknown), .retainedByTransport)
        }
    }
    @discardableResult private func save(job: JobRecord, resource: ResourceRequirement, transferID: UUID,
        phase: ProviderCheckpointPhase, state: State, terminal: Bool) async throws -> ProviderCheckpoint {
        let checkpoint = ProviderCheckpoint(destinationID: job.destination.id, tag: resource.tag, transferID: transferID,
            jobID: job.id, phase: phase, inputsTerminal: terminal, payload: try ProviderSupport.canonical(state))
        try await ledger.saveProviderCheckpoint(checkpoint); return checkpoint
    }
    private func capture(_ message: TDLibResponse, sendingID: Int32) async throws {
        guard var item = pending[sendingID], message["chat_id"]?.int64Value == item.state.chatID,
              try TelegramDocumentReference.captionTag(message) == item.checkpoint.tag else { throw CoreError.invalidContract }
        if item.resolution != nil { return }
        if let final = try? TelegramDocumentReference.parse(message, chatID: item.state.chatID, expectedTag: item.checkpoint.tag) {
            try await finish(sendingID, reference: final); return
        }
        guard let temporary = message["id"]?.int64Value, temporary > 0,
              let sending = message.object(forKey: "sending_state") else { throw incompleteHistory() }
        item.state.temporaryID = temporary
        item.state.fileID = message.object(forKey: "content")?.object(forKey: "document")?.object(forKey: "document")?["id"]?.int32Value
        pending[sendingID] = item
        try await persistPending(sendingID, phase: .transferring, terminal: false)
        if sending.type == "messageSendingStateFailed" { try await reject(sendingID, message: message, error: sending.object(forKey: "error")) }
    }
    private func handle(_ update: TDLibResponse) async throws {
        guard streamFailure == nil else { return }
        switch update.type {
        case "updateNewMessage":
            guard let message = update.object(forKey: "message"), message["chat_id"]?.int64Value == scope?.chatID else { return }
            if let id = message.object(forKey: "sending_state")?["sending_id"]?.int32Value, pending[id] != nil { try await capture(message, sendingID: id) }
            else if message.fields["sending_state"] == .null { try await indexNew(message) }
        case "updateMessageSendSucceeded", "updateMessageSendFailed":
            guard let message = update.object(forKey: "message"), let old = update["old_message_id"]?.int64Value,
                  let tag = try TelegramDocumentReference.captionTag(message),
                  let id = pending.first(where: { $0.value.state.chatID == message["chat_id"]?.int64Value &&
                      $0.value.checkpoint.tag == tag && ($0.value.state.temporaryID == old || $0.value.state.temporaryID == nil) })?.key else { return }
            if pending[id]?.state.temporaryID == nil { pending[id]?.state.temporaryID = old }
            if update.type == "updateMessageSendSucceeded" {
                guard let reference = try TelegramDocumentReference.parse(message, chatID: pending[id]!.state.chatID, expectedTag: pending[id]!.checkpoint.tag) else { throw incompleteHistory() }
                try await finish(id, reference: reference)
            } else { try await reject(id, message: message, error: update.object(forKey: "error")) }
        case "updateFile":
            guard let file = update.object(forKey: "file"), let id = file["id"]?.int32Value,
                  let key = pending.first(where: { $0.value.state.fileID == id })?.key, let item = pending[key],
                  let uploaded = file.object(forKey: "remote")?["uploaded_size"]?.int64Value else { return }
            let bytes = min(max(0, uploaded), item.state.byteCount)
            pending[key]?.uploadedBytes = bytes
            pending[key]?.nativeActive = file.object(forKey: "remote")?["is_uploading_active"]?.boolValue == true
            item.pump?.offer(bytes, item.state.byteCount)
            statusContinuation.yield(())
        case "updateConnectionState":
            historyRevision &+= 1; epoch = nil; statusContinuation.yield(())
            if update.object(forKey: "state")?.type == "connectionStateReady" { eventContinuation.yield(()) }
        case "updateDeleteMessages", "updateMessageContent", "updateMessageEdited":
            if update["chat_id"]?.int64Value == scope?.chatID { historyRevision &+= 1; epoch = nil }
        default: break
        }
    }
    private func indexNew(_ message: TDLibResponse) async throws {
        historyRevision &+= 1
        guard let destination = mapped, let scope else { return }
        if let reference = try TelegramDocumentReference.parse(message, chatID: scope.chatID), let epoch, !scanning {
            try await ledger.addRemoteIndex(destinationID: destination.id, epoch: epoch, entries: [RemoteIndexEntry(tag: reference.tag, reference: ProviderSupport.canonical(reference))])
        }
    }
    private func finish(_ id: Int32, reference: TelegramDocumentReference) async throws {
        historyRevision &+= 1
        guard var item = pending[id] else { return }
        guard reference.byteCount == item.state.byteCount else { throw CoreError.invalidContract }
        let message = try await client.request(["@type": "getMessage", "chat_id": reference.chatID, "message_id": reference.messageID])
        guard let actual = try TelegramDocumentReference.parse(message, chatID: reference.chatID, expectedTag: reference.tag), actual.remoteUniqueID == reference.remoteUniqueID else { throw incompleteHistory() }
        item.state.reference = actual; pending[id] = item
        try await persistPending(id, phase: .confirmed, terminal: true)
        let job = try await ledger.job(item.checkpoint.jobID)
        guard let resource = job.plan.resources.first(where: { $0.tag == item.checkpoint.tag }) else { throw CoreError.invalidContract }
        // Commit actual late confirmations too; Saved never waits for a blind
        // replacement send. Engine may idempotently commit the same receipt later.
        try await ledger.confirm(receipt(job.destination, actual, kind: .uploaded), jobID: job.id, resourceID: resource.id)
        try inputFiles.remove(transferID: item.checkpoint.transferID)
        try await files.transportFinished(item.checkpoint.transferID)
        resolve(id, .confirmed(actual))
        if let destination = mapped, let epoch, !scanning {
            try await ledger.addRemoteIndex(destinationID: destination.id, epoch: epoch, entries: [RemoteIndexEntry(tag: actual.tag, reference: ProviderSupport.canonical(actual))])
        }
        try await ledger.wakeWaiting(destinationID: item.checkpoint.destinationID)
        eventContinuation.yield(()); statusContinuation.yield(())
        if pending[id]?.waiter == nil, pending[id]?.pump == nil { pending.removeValue(forKey: id) }
    }
    private func reject(_ id: Int32, message: TDLibResponse, error: TDLibResponse?) async throws {
        guard let item = pending[id], let fileID = item.state.fileID ?? message.object(forKey: "content")?.object(forKey: "document")?.object(forKey: "document")?["id"]?.int32Value else { throw incompleteHistory() }
        let file = try await client.request(["@type": "getFile", "file_id": fileID])
        guard file.object(forKey: "remote")?["is_uploading_active"]?.boolValue == false,
              message.object(forKey: "sending_state")?.type == "messageSendingStateFailed" else { throw incompleteHistory() }
        let code = error?["code"]?.int32Value ?? 0
        let safe = SafeFailure(code == 429 ? .rateLimit : (code == 401 ? .authentication : (code == 403 ? .accessDenied : (code == 400 ? .unsupportedOriginal : .transfer))), domain: .tdlib, code: Int(code),
                               cause: code == 429 ? .serverRateLimit : (code == 401 ? .loginRequired : .providerRejected))
        let delay: TimeInterval?
        if case .double(let value) = message.object(forKey: "sending_state")?["retry_after"], value > 0, value <= 31_536_000 { delay = value }
        else { delay = code == 429 ? 60 : nil }
        let rejection = UploadFailure(safe, disposition: ProviderSupport.disposition(safe), acceptance: .definitelyNotAccepted,
                                      retryAfter: delay.map { Date().addingTimeInterval($0) })
        try await persistPending(id, phase: .rejected, terminal: true, failure: rejection)
        let job = try await ledger.job(item.checkpoint.jobID)
        guard let resource = job.plan.resources.first(where: { $0.tag == item.checkpoint.tag }) else { throw CoreError.invalidContract }
        try await ledger.appendEvent(.failure, context: ProviderSupport.context(job, resource), decision: .retry, severity: .error, failure: safe)
        if pending[id]?.pump == nil {
            try await ledger.failAttempt(jobID: job.id, failure: rejection, resourceID: resource.id, transferID: item.checkpoint.transferID)
        }
        try inputFiles.remove(transferID: item.checkpoint.transferID)
        try await files.transportFinished(item.checkpoint.transferID)
        resolve(id, .rejected(safe, delay))
        try await ledger.wakeWaiting(destinationID: item.checkpoint.destinationID)
        eventContinuation.yield(()); statusContinuation.yield(())
        if pending[id]?.waiter == nil, pending[id]?.pump == nil { pending.removeValue(forKey: id) }
    }
    private func persistPending(_ id: Int32, phase: ProviderCheckpointPhase, terminal: Bool, failure: UploadFailure? = nil) async throws {
        guard let item = pending[id] else { throw CoreError.invalidTransition }
        let checkpoint = ProviderCheckpoint(destinationID: item.checkpoint.destinationID, tag: item.checkpoint.tag,
            transferID: item.checkpoint.transferID, jobID: item.checkpoint.jobID, phase: phase,
            inputsTerminal: terminal, payload: try ProviderSupport.canonical(item.state), failure: failure)
        try await ledger.saveProviderCheckpoint(checkpoint)
        pending[id]?.checkpoint = checkpoint
    }
    private func awaitResolution(_ id: Int32) async -> Resolution {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard let item = pending[id] else { continuation.resume(returning: .uncertain(incompleteHistory())); return }
                if let result = item.resolution { continuation.resume(returning: result); return }
                pending[id]?.waiter = continuation
                pending[id]?.deadline = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(300)) } catch { return }
                    await self?.resolve(id, .uncertain(SafeFailure(.timeout, domain: .tdlib, cause: .deadlineExceeded)))
                }
                if Task.isCancelled { resolve(id, .uncertain(SafeFailure(.connectivity, domain: .tdlib, cause: .interrupted))) }
            }
        } onCancel: { Task { await self.resolve(id, .uncertain(SafeFailure(.connectivity, domain: .tdlib, cause: .interrupted))) } }
    }
    private func resolve(_ id: Int32, _ resolution: Resolution) {
        guard var item = pending[id] else { return }
        item.resolution = resolution; item.deadline?.cancel(); item.deadline = nil
        let waiter = item.waiter; item.waiter = nil; pending[id] = item
        waiter?.resume(returning: resolution)
    }
    func recover(_ destination: Destination) async throws {
        guard !busy else { throw CoreError.invalidTransition }; busy = true; defer { busy = false }
        try await startConsumer(); try await verify(destination)
        guard let scope else { throw CoreError.staleMapping }
        try await scanIndex(destination: destination, chatID: scope.chatID)
        var cursor: UUID?
        while true {
            let page = try await ledger.retainedTransfers(destinationID: destination.id, afterID: cursor)
            if page.isEmpty { break }
            for transfer in page {
                cursor = transfer.id
                guard let checkpoint = try await ledger.providerCheckpoint(destinationID: destination.id, tag: transfer.resource.tag) else {
                    // Crash before the checkpoint fence: no command could be sent.
                    try inputFiles.remove(transferID: transfer.id); try await files.transportFinished(transfer.id); continue
                }
                let state = try JSONDecoder().decode(State.self, from: checkpoint.payload)
                guard state.chatID == scope.chatID else { throw CoreError.staleMapping }
                if checkpoint.phase == .prepared || checkpoint.phase == .rejected || checkpoint.phase == .confirmed {
                    if checkpoint.phase == .prepared {
                        try await save(job: transfer.job, resource: transfer.resource, transferID: transfer.id, phase: .rejected, state: state, terminal: true)
                    }
                    try inputFiles.remove(transferID: transfer.id); try await files.transportFinished(transfer.id); continue
                }
                var message: TDLibResponse?
                if let temporary = state.temporaryID {
                    do { message = try await client.request(["@type": "getMessage", "chat_id": scope.chatID, "message_id": temporary]) }
                    catch { if ProviderSupport.safe(error, domain: .tdlib).code != 404 { throw error } }
                }
                if message == nil { message = try await findLocalPending(checkpoint: checkpoint, state: state) }
                guard let message else { throw SafeFailure(.reconciliation, domain: .tdlib, cause: .pendingSendUnmatched) }
                let existing = pending.first(where: { $0.value.checkpoint.transferID == transfer.id })?.key
                let id: Int32
                if let existing { id = existing }
                else {
                    guard pending.count < 8, nextSendingID < Int32.max else { throw CoreError.recoveryRequired }
                    id = nextSendingID; nextSendingID += 1
                    pending[id] = Pending(checkpoint: checkpoint, state: state)
                }
                try await capture(message, sendingID: id)
            }
        }
        try await ledger.completeDestinationRecovery(destination.id) // Refuses still-retained native readers.
    }
    /// Search local native history for the exact owned input path, not just a
    /// repeated caption. Failure to find it never proves remote absence.
    private func findLocalPending(checkpoint: ProviderCheckpoint, state: State) async throws -> TDLibResponse? {
        let expected = try inputFiles.url(transferID: checkpoint.transferID, filename: state.filename).path
        var cursor: Int64 = 0
        while true {
            try Task.checkCancellation()
            let page = try await client.request(["@type": "getChatHistory", "chat_id": state.chatID,
                "from_message_id": cursor, "offset": 0, "limit": 10, "only_local": true])
            guard page.type == "messages", let values = page.array(forKey: "messages"), values.count <= 10 else { throw incompleteHistory() }
            var oldest = cursor
            for value in values {
                guard let fields = value.objectValue else { throw incompleteHistory() }
                let message = TDLibResponse(fields: fields)
                guard let id = message["id"]?.int64Value, id > 0 else { throw incompleteHistory() }
                if oldest == 0 || id < oldest { oldest = id }
                if try TelegramDocumentReference.captionTag(message) == checkpoint.tag,
                   message.object(forKey: "sending_state") != nil,
                   message.object(forKey: "content")?.object(forKey: "document")?.object(forKey: "document")?.object(forKey: "local")?["path"]?.stringValue == expected { return message }
            }
            if values.isEmpty || oldest == cursor { return nil }
            cursor = oldest // Inclusive valid ID; no invalid message-id arithmetic.
        }
    }

    /// Settings/P6 call before discarding the adapter. Genuine native close is
    /// required, but uncertain pending paths remain protected for DB resumption.
    func close() async throws {
        guard !busy else { throw CoreError.invalidTransition }
        try await client.close(); consumer?.cancel(); await consumer?.value; consumer = nil; eventContinuation.finish(); statusContinuation.finish()
        streamFailure = SafeFailure(.reconciliation, domain: .tdlib, cause: .interrupted); epoch = nil
    }
    /// Native cache only. No original/DB/remote-message deletion. Called once at
    /// idle after global input inventory proves there are no retained readers.
    func trimIdleCache() async throws {
        guard !busy, pending.isEmpty, await client.authorizationState == .ready,
              await client.connectionReady else { return }
        busy = true; defer { busy = false }
        _ = try await client.request(["@type": "optimizeStorage", "size": 67_108_864,
            "ttl": 604800, "count": 1000, "immunity_delay": 0,
            "file_types": [["@type": "fileTypeDocument"]], "chat_ids": [Int64](),
            "exclude_chat_ids": [Int64](), "return_deleted_file_statistics": false, "chat_limit": 0])
    }
    private func receipt(_ destination: Destination, _ reference: TelegramDocumentReference, kind: ConfirmationKind) throws -> RemoteReceipt {
        RemoteReceipt(destinationID: destination.id, tag: reference.tag, opaqueReference: try ProviderSupport.canonical(reference), kind: kind)
    }
    private func incompleteHistory() -> SafeFailure { SafeFailure(.reconciliation, domain: .tdlib, cause: .incompleteHistory) }
}
