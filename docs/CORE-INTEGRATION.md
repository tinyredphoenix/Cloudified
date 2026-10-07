# P2 core integration contract

Architect-authored, 2026-10-07. Production implementation, compiler/static evidence
only; no device, provider, SQLite runtime or resource measurements yet. P3–P6 must
connect real components before P7. No demo adapters, sample records or test suites.

## File map and ownership

Local Swift package: `Packages/CloudifiedCore/Package.swift`, product `CloudifiedCore`.
Add it to the Xcode target in P3 so adapters can import its types. The separate
`CloudifiedDiagnostics` target is re-exported by the core. CSQLite links platform
SQLite; CryptoKit is Apple's framework. No third-party dependency was fetched.

| Source | Purpose |
| --- | --- |
| `Contracts.swift` | Immutable mappings, assets, plans, originals, receipts, failures and adapter interfaces |
| `ContentIdentity.swift` | Versioned canonical resource/coverage hashes and Telegram caption tags |
| `SQLite.swift` | Bound parameters, statement cleanup, FULL synchronous WAL, schema v1 |
| `Ledger.swift` | Mappings, scan pages, source recipes, frozen jobs, aliases and bounded snapshot invalidation |
| `QueueTransitions.swift` | Claims, reconciliation, persistent attempts, component confirmation, retries and deadlines |
| `Snapshots.swift` | SQL aggregates, literal saved-to-both intersection, paginated failure rows |
| `FileLeases.swift` | Export pins, runtime leases, durable transport ownership, admission and fenced cleanup |
| `Diagnostics.swift` | Transactional events, persistent summaries, rotation, pagination and JSONL export |
| `Sources/Diagnostics/DiagnosticEvent.swift` | Whitelisted production diagnostic/error vocabulary |
| `BackupEngine.swift` | Two concurrent provider workers, one preparation permit, measured progress and control gates |

Core files remain Architect-owned. Builder reports needed interface changes rather
than creating another scheduler/database or silently editing these invariants.

## Composition and scan/plan producer

Create **one** Ledger per protected app-owned database for the process lifetime.
Place database, WAL/SHM and staging in protected, backup-excluded Application
Support. P3/P5 must apply directory protection to the DB location; FileLeaseStore
applies it to its staging root. Credentials stay in Keychain/TDLib, never the ledger.
`version` is the real bundle version/build; `revision` is lowercase Git hex from
build configuration. Catch failed DB opening in composition and display its real
safe code; use OSLog if the DB cannot persist its own failure.

1. `beginScan`, `registerAssets` in pages <=200, then `completeScan`. This first pass
   enumerates actual accessible asset IDs/generations/kinds, without loading media.
   Unknown totals stay nil until completion. Live Photos are `.photo` once.
2. Generation is a lowercase SHA-256 of a canonical local source revision descriptor;
   it detects possible changes cheaply. Exported byte hashes are authoritative.
   Use returned canonical AssetIdentity IDs, not newly proposed UUIDs on every scan.
3. Hash/plan originals incrementally after this metadata scan. Do not hash the whole
   library before allowing uploads. One shared source preparation permit must
   cover BOTH planner export/hash and OriginalPreparer re-export; actors alone are
   reentrant and do not enforce one export across awaits. Avoid holding a permit
   while waiting for an upload to finish or staging space to be freed.
4. `saveSourceRecipe` persists <=256 KiB source-v1 JSON per asset. P3 defines its
   Codable schema: source descriptors/UTIs/filenames, measured SHA-256/SHA-1/length,
   source metadata and deterministic split/association recipe. No media payloads.
   Index resources by stable content/role, not requirement UUIDs. Keep private
   PhotoKit references out of canonical remote identities and diagnostic events.
5. `ContentIdentity.resource` and `.plan` create canonical v1 identities. Ordered
   arrays and policy versions must be deterministic. Manifest associationHash
   hashes its stable archive recipe/metadata, excluding local IDs and eventual
   message IDs. Google/TG plans can differ in coverage; destination scopes cannot.
6. `enqueue` binds one plan to asset+destination. Identical content/policy aliases
   share a parent job. Changing a coverage policy updates the current binding,
   preserving old history. Rescanning does not reset attempts/failures.
7. Producer/commands explicitly request a merged ready drain after enqueue. Never
   trigger backup from every ledger invalidation: batch/progress events would
   cause an empty-run loop. While a drain is active, merge producer wakeups into
   one subsequent request. Required unplanned assets remain counted as remaining.

Do not persist raw Photos resources, arrays of every PHAsset or whole media Data.
Source recipes are private state, not exported log material. Archive metadata in
Telegram manifests; original embedded metadata remains in the unchanged files.

## OriginalPreparer and staging

Implement the core `OriginalPreparer`; the P1 adapter placeholder is superseded.
Engine calls prepare per missing obligation and serializes its own preparation
calls. Resolve the job's frozen source generation/recipe and verify exported bytes
still match the required hashes. Never substitute edited renders or transcoding.

Use `reserveStorage` with actual available capacity and a conservative allowance
for URLSession copies, TDLib cache and current parts. On growth, pass measured
`writtenBytes` and the existing reservation ID; unknown size requires progressive
admission. It reserves a 512 MiB safety margin, a 1 GiB staging target and at most
one oversized allocation. These are defaults, not measured device guarantees.

`beginExport` pins a fresh UUID `.partial` path. Retain its ExportFileOwnership until
PhotoKit callbacks are terminal/fenced. Stream chunks into disk and SHA-256/SHA-1,
handle partial writes, close handles, validate hashes/length, then atomically rename
to its `.original` path. `registerPublished` converts the reservation into staged
state and returns an acquired LeasedFile. Only then `endExport`. On failure fence
callbacks before ending ownership/removing bytes and release the reservation.

Reuse a staged file via `acquire`; shared files may have multiple independent
leases. The Engine acquires a durable transfer hold before sending and releases
worker leases after return. Source must release every lease if prepare throws.
Keep at most one small ready resource ahead; do not pre-export the library.
Manifest input is one bounded file <=1 MiB; ordinary input lengths/order must match
the required originals. Live-pair inputs can contain two unmodified originals.
Generate Telegram parts incrementally, not all beside the complete large video.

`reexportable` is permission to delete idle staging, not proof that Photos can never
change. Source observation calls `setReexportable(false)` if staging becomes the
only recoverable copy. Source loss causes an explicit missing obligation; it cannot
justify deleting protected bytes or accepting a newly changed source as the old one.

Startup must inventory PhotoKit, real URLSession tasks and TDLib sends BEFORE
`completeStartupInventory`. Unknown/unmatched task paths prevent that completion.
Matched retained transfers keep durable holds. `sweep` uses deletion markers and
runtime fences; `reclaimOrphans` recognizes only our UUID `.partial/.original`
filenames. Orphan enumeration checks <=200 entries per call; continue at idle while
`orphanScanInProgress`. Never call deletion APIs on Apple originals or TDLib's
authentication database. Source cancellation requests alone are not cleanup proof.

## Provider adapters and recovery (P4)

Implement `ProviderAdapter`, one real adapter per Provider. A verified destination
fingerprint hashes canonical verified account+channel IDs; never use display names.
`completeDestinationRecovery` is an explicit P4 attestation: verify account, settle
live transports, and establish the managed remote index. It rejects unsettled
transfers in that destination only. Telegram history must be fully paginated;
short pages are not end-of-history. Google uses the pinned original-mode hash path.

Each resource inspect returns Present with final receipt, Verified absent, Unknown,
or Destination blocked with optional server resume date. Errors/failed lookups do
not mean absent. Authentication/quota/flood preflight errors block that lane once,
without exhausting every pending asset. Unknown content waits for a real state
change/user recheck, not a busy polling loop. `wakeWaiting` preserves budgets.

Upload receives an immutable job, resource, leased files and durable transferID.
Use transferID in URLSession task associations/TDLib pending-send mapping. On
relaunch match `retainedTransferIDs` to actual transports; terminal inventory/callback
calls `transportFinished`. Do not remove holds to make recovery pass artificially.
The adapter must preserve transfer identity/account through auth refresh/remapping.

Return Confirmed only after Google's final mediaKey or Telegram's final send-success
message IDs; PUT bytes/temporary TDLib IDs are insufficient. A return also states
Terminal file ownership or Retained by transport. Retained failures are forced to
Unknown acceptance. Every code path/deadline/cancellation returns a classified
outcome; protocol/chunk retry behavior is bounded and documented by P4.

`UploadFailure.didStartTransfer=false` is allowed only with proof that the current
resource did not start sending. Combined with definite nonacceptance and Waiting/
Provider wait, it suspends the existing logical attempt instead of burning another
budget slot on pre-transfer pause/offline/auth. Resume rechecks absence and reuses
that attempt. Crash alone is never suspension proof; interrupted real sends remain
uncertain and retain their consumed budget. Do not use this flag for a failed send.

Three attempts are durable parent cycles. Successful pieces are not resent.
Uncertain third attempts reconcile, and confirmed pieces may still finish the
parent; verified missing content then becomes Failed without a fourth send.
Only explicit Retry creates a new cycle, retaining old failures/receipts. Provider
restrictions and retry delays affect their own lane; source failures identify source.

Google native Live Photo pairing needs a verified protocol path. Otherwise honor
the frozen key-image/motion/both-original-components choice; never silently reduce
coverage. Telegram original documents/parts each carry `telegramCaptionTag` and
the final bounded manifest associates all required pieces and external metadata.
Preserve exact upstream revisions/licenses when implementation is introduced.

## Presentation, lifecycle and diagnostics (P5/P6)

`EngineSnapshot.active` supports TWO independent current transfers. P1's single
currentTransfer slot must be revised in P5. Filter active job mapping against the
selected mapping, or clearly show the old mapping settling. Do not mislabel it.
Use LedgerSnapshot SQL counts; remaining includes unplanned/waiting/failed assets.
Saved-to-both is an actual asset intersection, independent of enable switches.
Uploaded vs already-present refers to confirmed logical asset obligations; duplicate
local aliases can count as separate accessible assets with one remote transfer.

`observeChanges` is a bounded invalidation stream, no progress/count generator.
Refresh real snapshots on commands/invalidation, coalescing presentation ~2 Hz;
unsubscribe on teardown. Failures/logs use keyset pages, not entire-table arrays.
Thumbnail limits remain 16 MiB/100 entries, visible rows only, canceled on disappearance.

Call pause/setSystemGate on network-policy changes or background expiration.
Adapters must fence/cancel correctly; completion may still arrive. Clearing gates
requires waking waiting work and an explicit ready-drain request. `nextWake` gives
eligible future retries/provider deadlines; P6 owns one event-driven timer. No busy
sleep loops, automatic schedules or promises past force-quit. runReadyBatch creates
both workers before awaiting results. It drains ready work, not every future retry;
its end is NOT proof all assets saved or all background readers ended.

Before changing/removing auth, disable/deselect the old mapping and `settleProvider`,
then inventory any retained transports. Unlink never deletes cloud data/history.
Do not replace credentials while an old adapter still uses them. Relinking the same
verified scope reuses its own history; a new account/channel gets its own namespace.

P3–P6 emit whitelisted real events for source/network/background/auth/cleanup stages.
The core logs attempts, lane boundaries, transfers, finalization and confirmations.
Byte events coalesce to ~2 Hz/provider; adapters must coalesce before creating tasks
and must not fire one Task per PhotoKit chunk/network byte. Do not log arbitrary
NSError descriptions/HTTP bodies, filenames/paths or receipt contents.

Diagnostic payload budget is 10 MiB/seven days; bounded pruning occurs on progress
and app-start events, and P6 idle maintenance drains overdue pages. Critical events,
run summaries, attempts, failures and receipts have separate durable retention and
can grow with history. This is not a 10 MiB whole-database guarantee. No auto purge
of first-test evidence. JSONL export states pruning/coverage limits and streams
pages; P5 uses a protected, app-owned sharing file and removes it after sharing.

## Remaining evidence

P7 must establish SQLite reopen/transaction behavior, actual concurrent uploads,
partial/reinstall/account recovery, exact downloaded-original bytes/metadata,
Google storage accounting, file ownership/cancel races and device memory/disk peaks.
Compiler checks cannot establish any of those. Full iOS/Xcode compile also remains
for P7; the current package compiler check targets local macOS CommandLineTools.
