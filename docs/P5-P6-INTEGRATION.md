# P5-R1 and critical P6 — source integration

Architect direct implementation, authorized by the user on 2026-10-08.
This closes the implementation assignment for source handoff only. The app has
not been built with the iOS SDK, installed, or verified against either service.
P7 is the first complete native/app/device verification; no release acceptance.

## Files and responsibilities

| Files | Purpose / ownership |
| --- | --- |
| `App/Application/AppEnvironment.swift` | Composition, bounded subscriptions, per-provider recovery task ownership, visible persistence fallback |
| `AppEnvironment+Backup.swift`, `DemandSourceProducer.swift` | Explicit backup intent, canonical metadata scans/resume, demand source admission, frozen cursors/policy, pause/resume, retry/recovery commands |
| `AppEnvironment+Accounts.swift`, `AppEnvironment+Recovery.swift` | Serialized mapping/profile commands, real authentication updates, selected AND deselected-reader recovery, actual native close/reconnect/logout |
| `AppEnvironment+Lifecycle.swift`, `CloudifiedApp.swift` | Passive network/thermal/scene events, one retry deadline, expiration and idle cleanup |
| `AppEnvironment+Presentation.swift`, `AppEnvironment+Pages.swift` | Ledger-backed snapshots, simultaneous worker/native progress, bounded failure/log/run/attempt queries and safe export ownership |
| `App/Adapters/System/BackupContinuation.swift` | One iOS26 continued workload, explicit foreground submit, real progress, expiration callback |
| `NetworkPolicyMonitor.swift`, `FailureExplanation.swift` | One passive path monitor and closed-enum reasons/remedies; no internet polling or invented error prose |
| `RowThumbnailLoader.swift` | Local 96px previews, main-actor cache, decoded pixel costs, cancellation/generation fences, pressure/off-screen release |
| `DiagnosticFallback.swift`, `DiagnosticExportStore.swift` | <=50 safe memory-only persistence faults; protected/excluded app-owned export directory, failure/share/stale cleanup |
| `Packages/CloudifiedCore/.../BackupEngine.swift`, `Contracts.swift` | Demand-producer boundary, adapter capacity backpressure, frozen destination lanes and idle-lane wake inside an existing batch |
| Core `Snapshots.swift`, `Diagnostics.swift`, `Ledger.swift`, `FileLeases.swift` | Bounded filtered/history/alias queries, accurate source attempts, System+Source log filtering, protected streaming exports, honest revision and inventory-fenced cleanup |
| `App/Presentation/` | Separate provider progress and photo/video sections, real settings actions, keyset page controls, nullable dates/attempts, recovery instead of blind Retry |
| `Info.plist`, project generator/project, `scripts/build_unsigned_ipa.sh` | Register all production sources and continued workload; stamp the actual build HEAD into app/ledger metadata |

Application extension paths above are under `App/Application/`; System helper paths
are under `App/Adapters/System/`. No second queue or database was introduced.

## Critical behavior in source

- Google and Telegram recover independently. A completed provider recovery can
  start requested work while its sibling continues remote-history recovery.
  Relevant auth/connection/native events arriving during recovery are coalesced
  and retained. UI subscriptions alone never initiate a backup.
- Both enabled/recovered adapters enter the same batch. One planner measures only
  the next canonical asset on lane demand, with zero speculative prefetch. A source
  error advances that cursor; the other lane can continue. Google/TG file I/O and
  original preparation retain the existing bounded streaming/lease rules.
- A single deadline uses Core's actual retry dates. Native completion or a due
  deadline can wake an idle lane while its sibling is still uploading. Frozen
  destination closures prevent that wake from switching to a replacement mapping.
  Telegram's eight retained sends backpressure only Telegram before further source
  measurement. Three automatic logical attempts remain exclusively in Core.
- Credential/channel/coverage changes disable and settle the target worker and
  join the planner before mutation. Retained inputs from any old profile mapping
  block credential replacement/unlink. Ordinary enable/disable and an unrelated
  asset's explicit Retry do not require every other asset's native send to finish.
  Explicit Retry still checks the actual job's holds; unknown work offers recovery.
- Live Photo policy invalidates old coverage before re-enabling demand admission.
  No old smaller coverage remains Saved. The new frozen policy replans on demand;
  there is no all-library hashing barrier. Telegram retains both originals.
- Dashboard shows simultaneous worker/native cards, actual attempt/byte/component
  state, separate provider totals/remaining/confirmed/failed/waiting, and photo/video
  breakdowns. An acknowledgement wait is not Saved or a fabricated transfer.
- Failures use separate source/job keyset cursors (<=50 each); logs <=100, run choices
  <=20 plus the selected identity, attempt history <=25. Older pages replace visible
  windows. Filter changes query immediately; stale/cancelled generations cannot
  publish. Source failures have no invented upload attempt or capture date.
- Native auth updates advance the form before channel mapping. API hash is secure
  input, passwords are passed unchanged, secret fields clear on completion/dismissal.
  App unlink, same-account reconnect, channel remap and actual Telegram logout are
  distinct operations. Provider failures are persisted/displayed separately.
- Diagnostic export streams redacted records, preserves pruning/coverage disclosure,
  and removes partial/finished/old app-owned exports. Failed ledger writes expose a
  bounded memory-only fallback in Logs; that fallback is explicitly outside export.
  Build metadata uses the actual build HEAD, or honest `unknown` for unstamped builds.

## Selected P6 transport/lifecycle decision

See D38 in [decisions](04-DECISIONS.md) and the updated [runtime contract](RUNTIME-SPEC.md).
Keep Google's process-owned file URLSession and TDLib under ONE
BGContinuedProcessingTask. No persistent background URLSession is injected; its
existing safety guard remains. This avoids a second transport queue and reader
inventory. Process death still requires remote receipt/hash/history reconciliation;
it is never proof that the service rejected a send.

Register one workload once, submit only on foreground user Back Up/Resume, fail
instead of queue if unavailable, display real ledger progress, and cancel/join on
expiration. The app falls back to foreground execution if continuation is declined.
No automatic schedule, force-quit bypass or background availability guarantee.

One NWPathMonitor supplies eligibility, not internet/auth proof. Google requests
apply cellular/expensive preferences and disallow constrained access. Real TDLib
setNetworkType(None/WiFi/Mobile) runs before persistent queue initialization and on
policy changes. Wi-Fi/Low Data, thermal, pause and background gates preserve attempt
budgets and unknown inputs. Existing zero prefetch is the conservative Low Power
policy. Thermal/scene/memory notifications update eligibility and clear disposable
pages/previews. Idle cleanup and native optimizeStorage run only under the actual
inventory/reader guards; neither originals, native auth DB nor remote media are deleted.

## Evidence and remaining verification

Static/compiler checks are recorded with exact outcomes in [build log](03-BUILD-LOG.md).
The portable production check includes all 48 non-SwiftUI sources, including the
coordinator/extensions, provider/source/System implementations and presentation
models. It uses the real Core/CTDLib modules; no compiler stubs or demo adapters.
All 58 app Swift files are separately parsed and registered exactly once.

The macOS CLT check does NOT typecheck SwiftUI/UIKit/iOS-only BackgroundTasks branches,
link TDLib's device archives, or validate service behavior. Known macOS27 PhotoKit
originalFilename deprecations retain iOS26 compatibility. Source review/compilation
cannot establish zero duplicates, originals/metadata/Live Photo preservation,
Google quota treatment, native closure, background execution, resource peaks or UI
quality on an iPhone.

Next authorized phase must be P7 packaging/complete verification, not another demo
or intermediate app test. Before manual cloud dispatch, verify public visibility,
standard runner and free cache/storage allowance under BUILD-CACHE. Keep existing
cache validation/native closure gates. Full iOS compilation fixes, native assembly,
SideStore installation and real mixed-media dual-provider tests happen there.
Retain safe diagnostic export/run/attempt evidence for P8 debugging, including
independent provider failures, retry deadlines/exhaustion, toggles/mappings,
large videos/parts, Live Photo policies, network/thermal/expiration, memory/storage,
crash/relaunch and reinstall reconciliation. No cloud workflow was dispatched by
this P5/P6 assignment; no local Xcode/SDK installation or USB changes.
