# Cloudified shared handbook 3 — build log and handoff state

Updated 2026-10-07. Keep this file factual and append-focused. Proposed work,
compiled code and physical service/device evidence are different states.
No credentials, private media, raw secret-bearing responses or personal logs here.

## Current handoff state

- Active editing batch: none. P2 implementation complete by Architect; next assigned batch P3 Builder. Core remains Architect-owned; P3 must claim its paths here before editing.
- P0: architecture/repository/infrastructure complete; handbook contracts confirmed.
- P1: native iOS 26 target, shared Cloudified scheme, four navigation screens (Dashboard, Not uploaded, Logs, Settings), adapter protocol placeholders, and honest unpopulated states completed by Builder.
- P2: Architect-authored critical core/diagnostics implemented and compiled locally in Swift 6 mode; no runtime evidence yet.
- P3–P6: implementation handoffs, no intermediate app-test gates.
- P7: first full integrated build/test; P8: debugging iterations/release.
- No demo/mock/seeded data or simulated uploads are permitted.
- Main project location: existing Mac checkout. USB drive untouched.
- Full local Xcode: absent; Swift command-line compiler available.
- GitHub: private `tinyredphoenix/Cloudified`, origin configured, main synced.
- Cloud builds/device integration: no app build or device upload demonstrated.

## Verified earlier milestones

| Commit/tag | Evidence |
| --- | --- |
| `80abd82`, `v0.0.1-plan` | Architecture/specs, resource policy, manual workflow and packaging scaffold; no app target |
| `0090164` | Recorded temporary GitHub server creation errors |
| `2154262` | Private remote created; main and annotated planning tag verified remotely; setup blocker resolved |
| `016e449` | P1 native iOS 26 target, shared Cloudified scheme, four navigation screens, adapter protocol placeholders, and honest unpopulated states |
| `4604c1b` | P2 architect-authored Swift core/diagnostics; local compiler evidence only, runtime untested |

Earlier checks passed: local Markdown targets, shell syntax, workflow YAML parsing
and the missing-project guard. GitHub setup did not dispatch a cloud build.

## 2026-10-07 — P0 handoff/dashboard refinement

Owner: Architect. Purpose: provide four entry-point handbooks, exact module/file
ownership, executable P1 assignment, architect-owned critical P2, and overall
dashboard/concurrent-upload acceptance requirements.

Changed scope: four handbooks; README/AGENTS/CONTRIBUTING entry points; dashboard
status contract. No app implementation, signing, SDK download or disk changes.

Environment evidence: `swift --version` reports Apple Swift 6.4 on this Mac.
This is tool availability, not an app/core compile result.

Checks completed:

- `python3 scripts/check_docs.py`: passed, 14 Markdown files/local targets checked.
- `git diff --check` and `git diff --cached --check`: passed, including the new
  handbooks in the staged check.
- Focused `rg` consistency check: Dashboard naming, P1/P2 ownership, concurrent
  lanes and remaining/total wording align across handbooks and existing contracts.

Milestone scope: handoff documentation only, no app/core implementation evidence.
Open limitations: real Xcode project, core, adapters and device verification remain
unimplemented. Both-lane concurrency is a required test, not yet a demonstrated
feature. Current phase authorization is P1 only for Builder; P2 author is Architect.

## 2026-10-07 — user testing/logging revision

Owner: Architect. User requires no demo/mock/seeded app data, the first app test
only after every feature is built/integrated, then debugging iterations. Previous
per-phase test gates are superseded; static review and necessary compiler checks
remain implementation activities. No app/test/build was executed by this revision.

Updated handbooks and linked contracts remove the demo-model assignment and
intermediate testing/build requirements. P2 now includes structured persistent
diagnostics; P3–P6 must instrument their real paths. P7 is first complete-app
build/test and P8 debugging/release. Removed sample dashboard numbers to prevent
accidental app seed data. Failures/receipts remain separate from rotating logs.

Documentation validation: `python3 scripts/check_docs.py` passed for 14 Markdown
files; `git diff --check` passed. A focused text scan found and removed the old
demo-model assignment, controlled-adapter gate and feasibility-test phase order.
No functional app tests or cloud builds were run.
Implementation status remains unchanged: app/core/provider code is not built yet.

## 2026-10-07 — P1 native app shell and presentation structure

Batch / owner / status: P1 / Builder / Completed (static review passed; no app tests or cloud builds per schedule).
Purpose: Create native Swift/SwiftUI iOS 26 target, shared Cloudified scheme, four navigation screens (Dashboard, Not uploaded, Logs, Settings) with honest unpopulated states, and adapter protocol placeholders.
Reserved paths / active writer: `Cloudified.xcodeproj/`, `App/`, `scripts/generate_xcode_project.py`, `docs/03-BUILD-LOG.md` owned by Builder. Core paths (`Packages/CloudifiedCore`) preserved untouched for Architect.
Changed files:
- `Cloudified.xcodeproj/project.pbxproj`
- `Cloudified.xcodeproj/xcshareddata/xcschemes/Cloudified.xcscheme`
- `App/Application/CloudifiedApp.swift`
- `App/Application/AppEnvironment.swift`
- `App/Presentation/RootTabView.swift`
- `App/Presentation/Dashboard/DashboardView.swift`
- `App/Presentation/Dashboard/DashboardViewState.swift`
- `App/Presentation/Dashboard/Components/OverallActivityCard.swift`
- `App/Presentation/Dashboard/Components/ProviderStatusCard.swift`
- `App/Presentation/Dashboard/Components/MediaSectionCard.swift`
- `App/Presentation/Dashboard/Components/CurrentTransferCard.swift`
- `App/Presentation/NotUploaded/NotUploadedView.swift`
- `App/Presentation/NotUploaded/NotUploadedViewState.swift`
- `App/Presentation/Logs/LogsView.swift`
- `App/Presentation/Logs/LogsViewState.swift`
- `App/Presentation/Settings/SettingsView.swift`
- `App/Presentation/Settings/SettingsViewState.swift`
- `App/Adapters/PhotoLibrary/PhotoLibraryAdapterProtocol.swift`
- `App/Adapters/GooglePhotos/GooglePhotosAdapterProtocol.swift`
- `App/Adapters/Telegram/TelegramAdapterProtocol.swift`
- `App/Adapters/System/SystemAdapterProtocol.swift`
- `App/Resources/Info.plist`
- `App/Resources/Assets.xcassets/Contents.json`
- `App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `App/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
- `scripts/generate_xcode_project.py`
- `docs/03-BUILD-LOG.md`
Dependency revisions / artifact provenance: Native Apple frameworks only (SwiftUI, Combine, Foundation); no third-party packages or moving dependencies added.
Checks (exact command, outcome, evidence location):
- `python3 scripts/check_docs.py`: passed, 14 Markdown files valid.
- `plutil -lint Cloudified.xcodeproj/project.pbxproj`: passed (`OK`).
- `plutil -lint App/Resources/Info.plist`: passed (`OK`).
- Python XML parse of `Cloudified.xcscheme`: passed (`Scheme` root valid).
- `swiftc -parse` across all 19 Swift source files in `App/`: passed with 0 errors.
- Preflight project check (`test -d Cloudified.xcodeproj`): passed.
Cloud run URL / artifact checksum, if applicable: None. Cloud IPA builds and app tests deferred to P7 per user schedule.
Physical-device evidence, if applicable: None. Deferred to P7.
Failures / known limitations: No runtime test suites or simulator sessions executed (first complete app test scheduled at P7). Core database, retry engine, and real provider transports are not yet integrated (pending P2 Architect and P3–P5 Builder). Presentation layer displays honest unpopulated/unconnected states with no demo/mock data.
Decision changes (reference handbook 4 IDs): None; strictly adheres to D01, D04, D08, D09, D10, D14, D15, D16, D17, D18.
Commit / milestone tag, after it exists: Commit `016e449` on main; milestone tag deferred until acceptance testing per handbook 2.
Next handoff / release of reserved paths: Handoff to Architect for Phase 2 (P2: critical core and diagnostics in `Packages/CloudifiedCore/Sources/`). Reserved paths released.

## 2026-10-07 — P2 critical core and production diagnostics

Owner: Architect directly. Status: implemented, compiler/static checks only;
runtime/service acceptance remains P7. No demo records/adapters/test target added.

Changed: local `Packages/CloudifiedCore/` Swift 6 package (core, diagnostics and
platform SQLite shim); CORE-INTEGRATION contract; four handbooks; README, AGENTS
and setup status. P1 App/project files were inspected selectively and not edited.

Implementation: FULL synchronous WAL SQLite transactions, stable canonical v1
content tags/coverage hashes, scoped immutable destinations/jobs, current asset
bindings/duplicate aliases, source recipe persistence, parent attempt cycles,
partial receipts, reconciliation gates and independent ready-work lanes. Both
worker Tasks are created before either result is awaited. Source preparation is
serialized; adapter failures are values isolated to the original provider.

File ownership includes runtime export/reader leases, durable transfer records even
for metadata-only transport, per-destination recovery and deletion fences across
actor awaits. Startup does not clear retained transport ownership. Admission uses
staging/copy allowances and one oversized reservation; cleanup is bounded/repeatable.
SQL snapshots retain unknown totals, Photos/Videos counts, failures and literal
saved-to-both intersection. Logs have whitelisted error causes/codes, correlated
events, progress coalescing, real pages, run summaries and streamed redacted export.
Rotating diagnostic payload and durable history have distinct retention semantics.

Dependency provenance: no external dependency downloaded. Apple Foundation,
CryptoKit and platform SQLite only. Vendor implementations/TDLib remain for P4.

Static review corrected: cross-provider recovery blocking; stale current-policy
bindings; absent-vs-unknown recovery; retained transports falsely declaring absence;
oversized staging permission after publication; cleanup races across actor awaits;
old/disabled retry deadlines; provider-wide preflight restrictions; unbounded log
table scans at every progress tick. These are code-review findings, not tested bugs.

Compiler command (temporary caches/output, no app execution):

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/cloudified-p2-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/cloudified-p2-swift-cache \
swift build --package-path Packages/CloudifiedCore \
  --scratch-path /private/tmp/cloudified-p2-compile \
  --cache-path /private/tmp/cloudified-p2-pm-cache \
  --config-path /private/tmp/cloudified-p2-pm-config \
  --security-path /private/tmp/cloudified-p2-pm-security --disable-sandbox
```

Result: passed with Apple Swift 6.4, Swift 6 language mode, local macOS arm64 target.
CLT linker warns that its Developer/Library/Frameworks search directory is absent;
the package build succeeds. Initial cache/sandbox errors were resolved by keeping
SwiftPM caches in `/private/tmp` and disabling SwiftPM's nested manifest sandbox.
Compiler errors in actor initialization and Foundation async enumeration were
fixed before handoff. No test executables or runtime suites were run.

Remaining: P3 original source recipe/export/split implementations, P4 real provider
auth/history/upload/final receipts, P5 real UI composition and two current transfers,
P6 network/background/cache ownership integration. Full iOS compilation/IPA and
SQLite reopen/concurrency/cancel/reinstall/quality/resource behavior are unverified.
No cloud dispatch, Xcode download or USB changes. Ten MiB limits rotating diagnostic
payload, not durable evidence or entire DB/WAL footprint; measure at P7.

Decisions: D20–D23. Next handoff: Builder P3, exact assignment in handbook 2. Core
paths remain Architect-owned; no active writer remains after this batch commits.
Milestone `v0.0.4-core-untested` describes implementation/compiler evidence only;
it is not an app release. Commit/check outcomes are recorded after publishing.

Core commit: `4604c1b`. Final static checks: `python3 scripts/check_docs.py` passed
(15 Markdown files); `git diff --check` and core `git diff --cached --check` passed;
`plutil -lint Cloudified.xcodeproj/project.pbxproj` passed. Final core compile passed
after the pre-transfer suspended-attempt rule was added: pause/auth/offline before
sending resumes the same logical attempt only with explicit non-start proof;
crash/unknown acceptance cannot invent that proof or reset the three-attempt budget.
The handoff commit and annotated milestone are published together after this record.

## Batch log template

Copy this below when claiming/completing an assigned batch:

```text
Batch / owner / status:
Purpose:
Reserved paths / active writer:
Changed files:
Dependency revisions / artifact provenance:
Checks (exact command, outcome, evidence location):
Cloud run URL / artifact checksum, if applicable:
Physical-device evidence, if applicable:
Failures / known limitations:
Decision changes (reference handbook 4 IDs):
Commit / milestone tag, after it exists:
Next handoff / release of reserved paths:
```

Do not fill successful results in advance. If a check cannot run, record why and
what remains unverified. A generated IPA without SideStore/device verification
is a build artifact, not an accepted release.
