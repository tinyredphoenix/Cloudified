import Foundation
import CloudifiedCore

/// Original/non-quota wire behavior comes from pinned PhotosBackup. This actor
/// adds verified account scope and durable evidence; it never retries an asset.
actor GooglePhotosProviderAdapter: ProviderAdapter {
    nonisolated let provider = Provider.google
    private struct Scope: Codable, Equatable { let version: Int; let subject: String }
    private struct State: Codable {
        var prepared: [PreparedUpload?]
        var mediaKeys: [String?]
        var commitIndex: Int?
    }
    private let session: GooglePhotosClientSession
    private let ledger: Ledger
    private let files: FileLeaseStore
    private var destination: Destination?
    private var busy = false
    init(session: GooglePhotosClientSession, ledger: Ledger, files: FileLeaseStore) {
        self.session = session; self.ledger = ledger; self.files = files
    }
    /// Call after loading/connecting the actual credential. Settings must settle
    /// the previous mapping before switching the session's credential.
    func mapVerifiedAccount() async throws -> Destination {
        guard !busy else { throw CoreError.invalidTransition }; busy = true; defer { busy = false }
        let scope = try await verifiedScope()
        try await session.validateReadAccess()
        let mapped = try await ledger.selectDestination(Destination(provider: .google, verifiedFingerprint: ProviderSupport.fingerprint(scope)))
        try await ledger.bindProviderProfile(destination: mapped, profileID: session.profileID, scope: scope)
        destination = mapped
        return mapped
    }
    private func verifiedScope() async throws -> Data {
        try ProviderSupport.canonical(Scope(version: 1, subject: await session.verifiedSubject()))
    }
    private func verify(_ requested: Destination) async throws {
        guard requested.provider == .google else { throw CoreError.staleMapping }
        let scope = try await verifiedScope()
        guard ProviderSupport.fingerprint(scope) == requested.verifiedFingerprint,
              let binding = try await ledger.providerBinding(destinationID: requested.id),
              binding.profileID == session.profileID, binding.scope == scope else { throw CoreError.staleMapping }
        // P6 must supply reader/OS inventory for background transports. Until that
        // is wired, do not accept an injected background transport as foreground.
        guard !(await session.usesBackgroundTransfers) else { throw CoreError.recoveryRequired }
        destination = requested
    }
    /// Foreground readers cannot survive process death. This is not proof that a
    /// commit was rejected: ambiguous finalization checkpoints remain uncertain.
    func recover(_ requested: Destination) async throws {
        guard !busy else { throw CoreError.invalidTransition }; busy = true; defer { busy = false }
        try await verify(requested)
        var cursor: UUID?
        while true {
            let page = try await ledger.retainedTransfers(destinationID: requested.id, afterID: cursor)
            if page.isEmpty { break }
            for transfer in page {
                if let checkpoint = try await ledger.providerCheckpoint(destinationID: requested.id, tag: transfer.resource.tag) {
                    let phase: ProviderCheckpointPhase
                    switch checkpoint.phase {
                    case .prepared, .transferring: phase = .rejected // No media commit was submitted.
                    case .committing, .uncertain: phase = .uncertain
                    case .confirmed, .rejected: phase = checkpoint.phase
                    }
                    try await ledger.saveProviderCheckpoint(ProviderCheckpoint(destinationID: requested.id, tag: checkpoint.tag,
                        transferID: checkpoint.transferID, jobID: checkpoint.jobID, phase: phase, inputsTerminal: true, payload: checkpoint.payload))
                }
                try await files.transportFinished(transfer.id)
                cursor = transfer.id
            }
        }
        try await session.validateReadAccess()
        try await ledger.completeDestinationRecovery(requested.id)
    }
    func inspect(destination requested: Destination, resource: ResourceRequirement) async -> RemotePresence {
        guard !busy else { return .unknown(SafeFailure(.reconciliation, domain: .google, cause: .outcomeUnknown)) }
        busy = true; defer { busy = false }
        do {
            try await verify(requested)
            let keys = try await remoteKeys(resource)
            if let keys {
                let checkpoint = try await ledger.providerCheckpoint(destinationID: requested.id, tag: resource.tag)
                let knownUpload = checkpoint.map { $0.phase == .confirmed || $0.phase == .committing || $0.phase == .uncertain } ?? false
                let receipt = try makeReceipt(requested, resource, keys, kind: knownUpload ? .uploaded : .alreadyPresent)
                if let old = try await ledger.providerCheckpoint(destinationID: requested.id, tag: resource.tag) {
                    let state = State(prepared: Array(repeating: nil, count: keys.count), mediaKeys: keys.map(Optional.some))
                    try await save(old.jobID, requested, resource, old.transferID, .confirmed, state)
                }
                return .present(receipt)
            }
            if let checkpoint = try await ledger.providerCheckpoint(destinationID: requested.id, tag: resource.tag) {
                switch checkpoint.phase {
                case .confirmed:
                    return .unknown(SafeFailure(.reconciliation, domain: .google, cause: .outcomeUnknown))
                case .committing, .uncertain:
                    var state = try JSONDecoder().decode(State.self, from: checkpoint.payload)
                    guard let index = state.commitIndex, resource.originals.indices.contains(index),
                          state.mediaKeys.count == resource.originals.count else { return .unknown(SafeFailure(.reconciliation, domain: .google, cause: .outcomeUnknown)) }
                    guard let key = try await session.checkPresence(sha1: ProviderSupport.hex(resource.originals[index].sha1, count: 20), asLivePhotoMotion: resource.originals.count == 2 && index == 1) else { return .unknown(SafeFailure(.reconciliation, domain: .google, cause: .outcomeUnknown)) }
                    state.mediaKeys[index] = key; state.commitIndex = nil
                    try await save(checkpoint.jobID, requested, resource, checkpoint.transferID, .rejected, state)
                case .prepared, .transferring:
                    let state = try JSONDecoder().decode(State.self, from: checkpoint.payload)
                    try await save(checkpoint.jobID, requested, resource, checkpoint.transferID, .rejected, state)
                case .rejected: break
                }
            }
            return .verifiedAbsent
        } catch { return presenceFailure(error) }
    }
    private func remoteKeys(_ resource: ResourceRequirement) async throws -> [String]? {
        guard resource.role != .manifest, (1...2).contains(resource.originals.count) else { throw CoreError.invalidContract }
        var keys: [String] = []
        for (index, content) in resource.originals.enumerated() {
            let key = try await session.checkPresence(sha1: ProviderSupport.hex(content.sha1, count: 20),
                                                     asLivePhotoMotion: resource.originals.count == 2 && index == 1)
            guard let key else { return nil }
            guard !key.isEmpty, key.utf8.count <= 2048 else { throw CoreError.invalidContract }; keys.append(key)
        }
        // A motion hash existing somewhere is insufficient to establish pairing
        // with this still. Require the same final media identity for both hashes.
        if keys.count == 2, keys[0] != keys[1] {
            throw SafeFailure(.reconciliation, domain: .google, cause: .pairingUnverified)
        }
        return keys
    }
    func upload(job: JobRecord, resource: ResourceRequirement, files inputs: [LeasedFile], transferID: UUID,
                progress: @escaping @Sendable (TransferProgress) async -> Void) async -> CloudifiedCore.UploadOutcome {
        guard !busy else { return .failed(UploadFailure(SafeFailure(.invariant, domain: .core, cause: .invalidContract), disposition: .waiting, acceptance: .definitelyNotAccepted, didStartTransfer: false), .terminal) }
        busy = true; defer { busy = false }
        let pump = ProviderProgressPump(resourceID: resource.id, report: progress); pump.start()
        var state = State(prepared: Array(repeating: nil, count: resource.originals.count), mediaKeys: Array(repeating: nil, count: resource.originals.count))
        var commitSubmitted = false
        var wroteCheckpoint = false
        var didStartTransfer = false
        do {
            try await verify(job.destination)
            guard inputs.count == resource.originals.count, (1...2).contains(inputs.count), resource.role != .manifest,
                  resource.originals.allSatisfy({ $0.partIndex == nil }) else {
                throw SafeFailure(.unsupportedOriginal, domain: .google, cause: .formatRejected)
            }
            if inputs.count == 2 {
                guard resource.originals[0].role == .still, resource.originals[1].role == .motion else { throw CoreError.invalidContract }
            }
            if let old = try await ledger.providerCheckpoint(destinationID: job.destination.id, tag: resource.tag), old.phase != .rejected {
                throw SafeFailure(.reconciliation, domain: .google, cause: .outcomeUnknown)
            }
            let overhead = inputs.reduce(Int64(0)) { $0 + $1.byteCount }
            try await ledger.reserveTransport(transferID, bytes: overhead, availableBytes: ProviderSupport.availableBytes(at: inputs[0].url))
            guard let recipeData = try await ledger.sourceRecipe(assetID: job.asset.id) else { throw CoreError.invalidContract }
            let recipe = try JSONDecoder().decode(SourceRecipe.self, from: recipeData); try recipe.validate()
            try await save(job.id, job.destination, resource, transferID, .prepared, state); wroteCheckpoint = true
            var completedBytes: Int64 = 0
            let total = inputs.reduce(Int64(0)) { $0 + $1.byteCount }
            for (index, input) in inputs.enumerated() {
                try Task.checkCancellation()
                let original = resource.originals[index]
                let measured = try await ProviderSupport.hashFile(input.url)
                guard measured.sha256 == original.sha256, measured.sha1 == original.sha1,
                      measured.byteCount == original.byteCount, input.byteCount == original.byteCount,
                      let descriptor = recipe.resources.first(where: { $0.originalContent == original }) else { throw CoreError.invalidContract }
                let base = completedBytes
                let phase: @Sendable (UploadPhase) -> Void = { value in
                    if case .sending(let bytes, _) = value { pump.offer(base + bytes, total) }
                }
                let preparation = try await session.prepareVerifiedUpload(file: input.url, filename: descriptor.originalFilename,
                    modified: recipe.metadata.creationDate ?? recipe.metadata.modificationDate,
                    hash: ProviderSupport.hex(original.sha1, count: 20), byteCount: original.byteCount,
                    stillHash: inputs.count == 2 && index == 1 ? ProviderSupport.hex(resource.originals[0].sha1, count: 20) : nil, phase: phase)
                switch preparation {
                case .alreadyBackedUp(let key): state.mediaKeys[index] = key
                case .ready(let prepared):
                    guard prepared.hash == (try ProviderSupport.hex(original.sha1, count: 20)), prepared.byteCount == original.byteCount else { throw CoreError.invalidContract }
                    state.prepared[index] = prepared
                    try await save(job.id, job.destination, resource, transferID, .transferring, state)
                    try Task.checkCancellation()
                    didStartTransfer = true
                    let received = try await session.transfer(prepared: prepared, file: input.url, transferID: transferID, phase: phase)
                    state.prepared[index] = received
                    state.commitIndex = index
                    // Write receipt and committing fence BEFORE submitting RPC.
                    try await save(job.id, job.destination, resource, transferID, .committing, state)
                    commitSubmitted = true
                    let result = try await session.commit(prepared: received, useQuota: false, saver: false,
                        pairedStillHash: inputs.count == 2 && index == 1 ? ProviderSupport.hex(resource.originals[0].sha1, count: 20) : nil, phase: phase)
                    state.mediaKeys[index] = result.mediaKey
                    commitSubmitted = false
                    try await save(job.id, job.destination, resource, transferID, .prepared, state)
                }
                completedBytes += input.byteCount; pump.offer(completedBytes, total)
            }
            guard let keys = try await remoteKeys(resource) else { throw SafeFailure(.finalization, domain: .google, cause: .outcomeUnknown) }
            let receipt = try makeReceipt(job.destination, resource, keys, kind: didStartTransfer ? .uploaded : .alreadyPresent)
            state.mediaKeys = keys.map(Optional.some)
            try await save(job.id, job.destination, resource, transferID, .confirmed, state)
            await pump.stop()
            return .confirmed(receipt, .terminal)
        } catch {
            let safe = ProviderSupport.safe(error, domain: .google)
            if wroteCheckpoint {
                do { try await save(job.id, job.destination, resource, transferID, commitSubmitted ? .uncertain : .rejected, state) }
                catch { await pump.stop(); return .failed(UploadFailure(ProviderSupport.safe(error, domain: .google), disposition: .waiting, acceptance: .unknown), .terminal) }
            }
            await pump.stop()
            return .failed(UploadFailure(safe, disposition: ProviderSupport.disposition(safe),
                           acceptance: commitSubmitted || safe.category == .reconciliation ? .unknown : .definitelyNotAccepted,
                           retryAfter: (error as? SafeProviderFailure)?.retryAfter, didStartTransfer: didStartTransfer), .terminal)
        }
    }
    private func save(_ jobID: UUID, _ destination: Destination, _ resource: ResourceRequirement,
                      _ transfer: UUID, _ phase: ProviderCheckpointPhase, _ state: State) async throws {
        try await ledger.saveProviderCheckpoint(ProviderCheckpoint(destinationID: destination.id, tag: resource.tag,
            transferID: transfer, jobID: jobID, phase: phase, inputsTerminal: phase != .transferring, payload: ProviderSupport.canonical(state)))
    }
    private func makeReceipt(_ destination: Destination, _ resource: ResourceRequirement, _ keys: [String], kind: ConfirmationKind) throws -> RemoteReceipt {
        guard keys.count == resource.originals.count, keys.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 2048 }) else { throw CoreError.invalidContract }
        return RemoteReceipt(destinationID: destination.id, tag: resource.tag, opaqueReference: try ProviderSupport.canonical(keys), kind: kind)
    }
    private func presenceFailure(_ error: any Error) -> RemotePresence {
        let safe = ProviderSupport.safe(error, domain: .google)
        if safe.category == .authentication || safe.category == .accessDenied || error is CoreError {
            return .destinationBlocked(safe, resumeAt: nil)
        }
        return .unknown(safe)
    }
}
