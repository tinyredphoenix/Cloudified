# Cloudified shared handbook 2 — phases and ownership

Updated 2026-10-07. Architect means this AI; Builder means the user's separate
implementation AI. No subagent is automatically launched by these instructions.
The architect directly authors the most critical engine phase, not just its review.

Latest user direction supersedes earlier plans: no demo/mock/seeded app data or
simulated uploads. Implement and connect every feature before the first app test.
Phase boundaries are ownership/code-review handoffs, not intermediate test gates.
Use necessary static review/syntax/compiler checks; do not run per-phase unit,
simulator/device tests or cloud IPA builds. P7 is the first complete app build/test.

## Current handoff

P0, P1 shell and P2 critical core implementation are complete; P2 has local Swift 6
compiler/static evidence only. **Builder may start P3 now.** P2 remains Architect-owned.
Other phases remain planned and become executable after
their prerequisites pass and the architect assigns the next numbered batch.
Do not interpret the handbook as permission to implement all phases at once.

Before editing, inspect git status and handbook 3's active-batch/ownership record.
Claim the assigned batch there. Do not reset another AI's work or edit its reserved
files. The two AIs share one checkout/branch; no simultaneous Git mutation.

## Implementation phases, followed by the first complete app test

| Phase | Owner | Deliverable | Handoff / completion record |
| --- | --- | --- | --- |
| P0: contracts and repository | Architect | Four handbooks, dashboard/concurrency contract, private remote and build scaffold | Documentation checks, clean Git history, planning tag |
| P1: app structure | Builder | iOS 26 target/shared scheme, four screens with genuine unconnected/unknown states | File map and static review; no demo records or cloud test build |
| P2: critical core and diagnostics | Architect directly | Durable SQLite queue/receipts, account scoping, three-attempt reducer, independent lanes, recovery, counters, file leases and structured logs | Critical code review and documented invariants; runtime behavior remains untested |
| P3: original media pipeline | Builder; architect reviews | PhotoKit scan, streaming export/hash, metadata, resource roles and bounded staging | Implementation review and diagnostic event coverage |
| P4: real provider adapters | Builder; architect owns critical protocol corrections | Pinned PhotosBackup original-mode and TDLib document/history bridges | Dependency provenance, real auth/receipt/reconciliation paths and diagnostic coverage |
| P5: wire all presentation and controls | Builder | Real dashboard snapshots, settings, failures/logs and concurrent dual backup | No simulated records; commands/status wired to real components |
| P6: complete lifecycle/media behavior | Architect on critical fixes; Builder on assigned wiring | Live Photo coverage/fallback, large-file recovery, iOS 26 background work, memory/cache cleanup | Full feature integration and logging coverage; no unfinished feature stubs |
| P7: first complete app build and test | Architect directs; Builder packages; user/device performs real use | Full IPA, SideStore install and real Google/Telegram backup with every feature present | Full functional/resource/quality/recovery matrix and persistent diagnostic export |
| P8: debugging iterations and release | Architect on critical fixes; Builder on assigned fixes | Fix failures from the real test, recheck affected behavior and package accepted release | Evidence of resolved issues; release tag only after acceptance |

P1 and P2 can overlap only after explicitly coordinating file ownership. P3/P4
use the architect's approved P2 interfaces. Implementing an adapter before another
adapter is allowed; production execution must still run both lanes concurrently.
Google uploads may never finish the whole library before Telegram starts.

## P1 — exact instruction for the Builder

Purpose: create a small presentation/composition shell that later receives
the core. Do not implement retries, deduplication or a second database yourself.

Allowed files: `Cloudified.xcodeproj/`, `App/`, shared scheme, app assets/configuration,
and the P1 log section. Keep adapter paths as empty interfaces/placeholders until
assigned. Do not change core paths, quality policy, handbooks 1/2/4, cloud billing
policy or existing critical contracts without coordination.

Tasks:

1. Create the native Swift/SwiftUI iOS 26 target and shared Cloudified scheme.
   Follow the existing CI/project naming contract. Full Xcode stays in cloud CI.
2. Add Dashboard, Not uploaded, Logs and Settings navigation. No gallery/viewer.
3. Build the dashboard layout for concurrent Google/Telegram state, overall activity,
   `X remaining out of Y`, confirmed counts, Photos/Videos and active-file bytes.
   Until real components are connected, show Not connected/Not scanned/Unavailable.
   Do not fabricate counts, transfers, accounts, errors, logs or preview records.
4. Settings includes separate provider switches and account/channel connection
   placeholders. No fake authentication and no hard-coded secrets.
5. Do not create a demo layer or import a missing core package. Preserve unknown/
   optional values in presentation interfaces; P2 supplies production snapshots.
   Do not create duplicate production engine types.
6. Add necessary project permission descriptions/capabilities deliberately. Do
   not prompt for Photos/login until real integration is assigned.
7. Use necessary static checks; defer cloud IPA build and app testing to P7.
   Do not install full Xcode locally. Allowance is checked before the P7 build.
8. Report files, implementation/static-review status and unresolved work. Update
   P1 log, commit/push and hand off by ownership; do not request an intermediate
   device/simulator test. Do not describe untested behavior as working.

## P3 — exact next instruction for Builder

Implement P3 only in this checkout. Read README, AGENTS, this section,
CORE-INTEGRATION.md and the source/resource contracts in RUNTIME-SPEC.md and
RELIABILITY-SPEC.md. Inspect core public contracts; do not reread every UI file.
Claim ownership in handbook 3 before editing. Allowed: `App/Adapters/PhotoLibrary/`,
one Foundation storage-layout helper under `App/Adapters/System/`, the Xcode
project/shared package reference and generator, and the P3 build-log section.
Do not edit Architect-owned core files or provider/auth/UI orchestration paths.

1. Add the local CloudifiedCore package product to the app project and deterministic
   project generator. Implement real PhotoKit interfaces against its public types.
2. Enumerate photos/videos and access scope in <=200-item pages, using canonical
   IDs returned by Ledger. Complete the metadata scan before incremental content
   planning; do not export/hash the entire library before upload-ready work exists.
3. Build a source-v1 Codable recipe and one shared export permit for planning and
   prepare. Use cancellable PhotoKit original-resource callbacks, streamed disk
   writes and SHA-256/SHA-1, with terminal callback fencing and bounded buffers.
   Verify actual lengths/hashes; no private fileSize KVC or whole-media Data.
4. Preserve original formats/embedded metadata and accessible external metadata.
   Enumerate all required original resources deliberately, including Live Photo
   still/motion and RAW/JPEG combinations where applicable. Use current Apple
   primary documentation to distinguish originals from adjusted render resources.
   Unsupported originals remain explicit; no conversion or silent omission.
5. Generate provider-specific frozen coverage plans using ContentIdentity. Support
   Google still/video original obligations and frozen Live Photo fallback choices;
   do not assert unverified native pairing. Telegram requires every original/part
   plus association/metadata manifest. Define deterministic lossless part recipes
   and incremental part extraction; P4 will validate actual transport limits.
6. Use admission/reservations, ExportFileOwnership, atomic publication and acquired
   LeasedFiles exactly as CORE-INTEGRATION specifies. Cache only bounded staging,
   reuse shared verified files and re-export unchanged originals after cleanup.
   Preserve identity on retries; if the source changes, report that mismatch.
7. Persist private source recipes through Ledger, not a second retry database.
   Instrument real scan/export/iCloud/hash/source/space/cancel events. Do not log
   filenames, GPS, PhotoKit IDs, paths or raw errors in diagnostic fields.
8. No demo data, mocks, unit/app tests, cloud IPA dispatch, full local Xcode install
   or drive changes. Necessary syntax/compiler/project checks only. Local CLT has
   no iOS SDK: record any unavailable iOS typecheck instead of claiming a compile.
9. Update handbook 3 with paths, source recipe schema, event coverage, static checks,
   limitations and commit. Make coherent commits and push main. Stop after P3;
   report interface needs to Architect. P4–P6 and first full app test remain later.

Do not start a second queue or replace the core. Presentation still stays genuinely
unconnected until P5 wiring; do not expose partially functioning backup controls.

## P2 — architect's direct implementation scope

Implemented in the local package. Public APIs, integration obligations and limits:
[core integration contract](CORE-INTEGRATION.md). Compiler success is not runtime
acceptance. The P7 scenarios below remain untested.

Core public contracts include immutable destination/asset/resource/job identities,
confirmed receipts, classified failures, per-provider runtime state, dashboard
snapshots and progress events. SQLite uniqueness/transactions are authoritative;
UI counters and local filenames are not. Adapter capability/preflight evidence
must distinguish Present, Verified absent, and Unknown.

Required implementation invariants, reviewed directly now and exercised on the
first complete app at P7:

- Both real providers can transfer concurrently; production events capture lane
  start/progress/end times and active jobs so the first real test exposes serialization.
- Google fails while Telegram confirms. Google processes the next ready asset;
  Telegram completion and attempts remain untouched.
- Exactly three total automatic parent-asset attempts; relaunch/reopen cannot
  reset the budget. Live Photo/part successes survive retry and exhaustion.
- Unknown acceptance enters Reconciling; failed remote lookup never means Absent.
- Account/channel changes cannot inherit or overwrite another mapping's receipts.
- SQLite transaction/reopen checks preserve receipts before Saved is observable.
- Counters and saved-to-both intersection stay correct for photos, videos,
  duplicate aliases, partial Live Photos and disabled providers.
- File leases protect a shared file while another consumer remains active;
  interrupted cleanup is repeatable and cannot delete transport-owned bytes.

No synthetic/demo adapters or intermediate test suites are introduced in P2.
Implementation review does not prove service/device behavior; record that distinction.
Critical Google finalization/auth mapping or bridge ownership defects discovered
later are also architect-owned direct fixes.

## Production diagnostics required before the first app test

Implement the persistent logger in P2; add event emission as each real component
is implemented in P3–P6. No sample log entries, automatic private-data uploads or
raw credential-bearing response dumps.

Every structured event carries: event sequence/time, app version/source revision,
run ID, origin (Google/Telegram/source/system), safe destination-mapping ID,
job/asset/resource reference, retry-cycle ID, attempt number, operation/stage,
state transition, duration, safe error domain/code, known cause or Cause unknown,
and the retry/wait/skip/reconcile decision. Relevant events include measured
bytes/expected size and component/part. Use stable references, not auth tokens,
phone numbers, GPS, network SSIDs/IPs or raw opaque receipts.

Required coverage:

- App start/relaunch, scan/scope changes and batch start/pause/resume/end.
- Export/iCloud/hash start, completion, cancellation and source/disk errors.
- Per-provider lane start, actual transfer progress, finalization and confirmation.
- Remote duplicate lookup/history recovery with Present/Verified absent/Unknown.
- Attempt start/failure, retry scheduling, exhaustion and user-initiated retry.
- Account/channel mapping changes and provider enable/disable, without secrets.
- Network-policy/background expiration, file-lease acquisition/release and cleanup.
- Database persistence failure and receipt reconciliation, preserving uncertainty.

Receipt/attempt/failure records and critical transition events are durable; commit
receipt state before announcing Saved. Diagnostic log rotation cannot erase these
records. High-volume byte events are coalesced; no per-chunk log storm. Initial
diagnostic budget remains 10 MiB/seven days; expose capture limits rather than
claim a truncated log is complete. Retain the first test's durable run summary,
failures and attempts until reviewed, separate from rotating diagnostics.

The Logs screen shows real chronological events with All/Google/Telegram/System
filters, severity/run filters, readable cause/action and detailed codes. A redacted
export includes version, run summary, coverage/gaps and correlated failures. It
must explain both providers independently and allow analysis of concurrent activity.

P7 begins only after all requested features are connected, logging is instrumented
throughout, no functional stubs remain, and the full IPA can be packaged. Its first
run uses real Photos resources and mapped accounts. Then debug from observed
errors/logs at P8 and recheck the affected behavior; no earlier app-test sessions.

## Reports, commits and handoff

Each report: batch ID, objective, changed paths, dependency SHAs, checks and exact
outcomes, useful screenshots, unresolved risks, next suggested batch. No full
repository dumps. Architect reads critical diffs directly and UI evidence selectively.
Update handbook 3 after meaningful work, preserving previous results.

One active writer owns the build-log update. Handbooks 1/2/4 are architect-owned;
request a change rather than silently redefine contracts. Commit only the batch's
files, push main, and tag milestones only after their stated acceptance evidence
exists. Do not rewrite published tags. P1–P6 implementation tags must explicitly
say Untested; no release tag before complete-app acceptance.
