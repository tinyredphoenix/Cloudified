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

P0 is complete. **Builder may start P1 now.** P2 belongs to the architect and is
not implemented yet. Other phases remain planned and become executable after
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

## P2 — architect's direct implementation scope

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
