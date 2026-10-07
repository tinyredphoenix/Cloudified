# Cloudified shared handbook 2 — phases and ownership

Updated 2026-10-07. Architect means this AI; Builder means the user's separate
implementation AI. No subagent is automatically launched by these instructions.
The architect directly authors the most critical engine phase, not just its review.

## Current handoff

P0 is complete. **Builder may start P1 now.** P2 belongs to the architect and is
not implemented yet. Other phases remain planned and become executable after
their prerequisites pass and the architect assigns the next numbered batch.
Do not interpret the handbook as permission to implement all phases at once.

Before editing, inspect git status and handbook 3's active-batch/ownership record.
Claim the assigned batch there. Do not reset another AI's work or edit its reserved
files. The two AIs share one checkout/branch; no simultaneous Git mutation.

## Phases and acceptance gates

| Phase | Owner | Deliverable | Required evidence |
| --- | --- | --- | --- |
| P0: contracts and repository | Architect | Four handbooks, dashboard/concurrency contract, private remote and build scaffold | Documentation checks, clean Git history, planning tag |
| P1: minimal app shell | Builder | iOS 26 target/shared scheme, four native screens, account/progress placeholders clearly labeled demo | Project structure; unsigned cloud build after allowance check; simulator evidence when available |
| P2: critical core | Architect directly | Durable SQLite queue/receipts, account scoping, three-attempt reducer, two independent lanes, recovery gates, counter snapshots and staged-file leases | Focused invariant tests with SQLite reopen, controlled concurrency and injected failures |
| P3: original media pipeline | Builder; architect reviews | PhotoKit scope/scan, streaming export/hash, metadata, resource roles and bounded staging | Exact-original fixtures, iCloud/cancel/low-disk tests, no whole-video RAM buffering |
| P4: provider adapters | Builder; architect owns critical protocol corrections | Pinned PhotosBackup original-mode bridge and TDLib document/history bridge | Auth, confirmed receipts, downloaded original hashes, reinstall reconciliation fixtures |
| P5: connect dashboard and controls | Builder | Replace demo data with core snapshots; wire settings, failures/logs and simultaneous dual backup | Real independent progress, correct photos/videos counters, pause/disable/account-switch cases |
| P6: lifecycle and media hardening | Architect on critical fixes; Builder on assigned system wiring | Live Photo coverage/fallback, large-file recovery, iOS 26 background work, memory/cache cleanup | Signed-device interruption, partial resource, disk, thermal/network and receipt recovery evidence |
| P7: release candidate | Architect acceptance; Builder packages | Verified IPA, reproducible revisions, concise setup instructions | Physical SideStore install and complete acceptance matrix; release tag only after passing |

P1 and P2 can overlap only after explicitly coordinating file ownership. P3/P4
use the architect's approved P2 interfaces. Implementing an adapter before another
adapter is allowed; production execution must still run both lanes concurrently.
Google uploads may never finish the whole library before Telegram starts.

## P1 — exact instruction for the Builder

Purpose: create a small buildable presentation/composition shell that later receives
the core. Do not implement retries, deduplication or a second database yourself.

Allowed files: `Cloudified.xcodeproj/`, `App/`, shared scheme, app assets/configuration,
and the P1 log section. Keep adapter paths as empty interfaces/placeholders until
assigned. Do not change core paths, quality policy, handbooks 1/2/4, cloud billing
policy or existing critical contracts without coordination.

Tasks:

1. Create the native Swift/SwiftUI iOS 26 target and shared Cloudified scheme.
   Follow the existing CI/project naming contract. Full Xcode stays in cloud CI.
2. Add Dashboard, Not uploaded, Logs and Settings navigation. No gallery/viewer.
3. Dashboard mock states must demonstrate Google and Telegram uploading together,
   and one uploading while the other is waiting/failed/disabled. Show overall
   activity, `X remaining out of Y`, confirmed counts, separate Photos/Videos,
   and active-file bytes. Label all fixture data Demo; do not claim live uploads.
4. Settings includes separate provider switches and account/channel connection
   placeholders. No fake authentication and no hard-coded secrets.
5. Keep demo models in `App/Presentation/Demo/`. Do not import a missing core
   package or create duplicate production engine types; P2 supplies them later.
6. Add necessary project permission descriptions/capabilities deliberately. Do
   not prompt for Photos/login until real integration is assigned.
7. Check local scripts/docs; verify available Actions allowance before dispatching
   the manual standard-runner build. Do not install full Xcode locally.
8. Report changed files, build/simulator evidence, redacted diagnostics and blockers.
   Passing compilation is distinct from screenshots/device proof. Update P1 log,
   make a focused commit, push it, then stop for the next batch assignment.

## P2 — architect's direct implementation scope

Core public contracts include immutable destination/asset/resource/job identities,
confirmed receipts, classified failures, per-provider runtime state, dashboard
snapshots and progress events. SQLite uniqueness/transactions are authoritative;
UI counters and local filenames are not. Adapter capability/preflight evidence
must distinguish Present, Verified absent, and Unknown.

Required tests before handing core to Builder:

- Two controlled adapters both enter transfer before either may finish. Use
  barriers/events, not elapsed-time sleeps, to prove concurrent execution.
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

This phase validates the engine with controlled adapters; it does not by itself
prove Google's service behavior, Telegram login or real-device background runtime.
Critical Google finalization/auth mapping or bridge ownership defects discovered
later are also architect-owned direct fixes.

## Reports, commits and handoff

Each report: batch ID, objective, changed paths, dependency SHAs, checks and exact
outcomes, useful screenshots, unresolved risks, next suggested batch. No full
repository dumps. Architect reads critical diffs directly and UI evidence selectively.
Update handbook 3 after meaningful work, preserving previous results.

One active writer owns the build-log update. Handbooks 1/2/4 are architect-owned;
request a change rather than silently redefine contracts. Commit only the batch's
files, push main, and tag milestones only after their stated acceptance evidence
exists. Do not rewrite published tags. No release tag for a mock-only shell.
