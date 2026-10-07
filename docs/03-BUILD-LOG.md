# Cloudified shared handbook 3 — build log and handoff state

Updated 2026-10-08. Keep this file factual and append-focused. Proposed work,
compiled code and physical service/device evidence are different states.
No credentials, private media, raw secret-bearing responses or personal logs here.

## Current handoff state

- Active editing batch: P3-R2 completed by Builder; submitted for Architect review. Core paths (`Packages/CloudifiedCore`) preserved untouched for Architect. P4 is not started.
- P0: architecture/repository/infrastructure complete; handbook contracts confirmed.
- P1: native iOS 26 target, shared Cloudified scheme, four navigation screens (Dashboard, Not uploaded, Logs, Settings), adapter protocol placeholders, and honest unpopulated states completed by Builder.
- P2: Architect-authored critical core/diagnostics implemented and compiled locally in Swift 6 mode; no runtime evidence yet.
- P3: Builder implementation committed; architect review found cancellation fencing, split-hash, canonical-ID, staging/admission, resource-matching and diagnostics blockers. Syntax parsing passed; that is not interface/typecheck or critical-review acceptance.
- P4–P6: implementation handoffs, no intermediate app-test gates.
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
| `7d53faf` | P3 original media pipeline, cancellable export, streaming hashing, source-v1 recipe, lossless video parts, and Xcode package integration |
| `89922cf`, `v0.0.6-p3-r1-review-untested` | Architect P3-R1 review, rollback export, generation verification, multipart association, and reserveSourceStorage |
| `d0c00fe` | P3-R2 demand-driven admission, exact selectors, OSAllocatedUnfairLock progress coalescing, and provider isolation |

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

## 2026-10-08 — P3 original media pipeline and core package integration

Batch / owner / status: P3 / Builder / Reported completed; Architect review found blockers (see P3-REVIEW.md). Syntax parsing passed; no app tests or cloud builds per schedule.
Purpose: Real PhotoKit scanning, original export, streaming SHA-256/SHA-1, source-v1 recipe schema, Live Photo coverage, lossless video-part preparation, ArchiveManifestBuilder, PhotoLibraryOriginalPreparer conforming to OriginalPreparer, and local CloudifiedCore package integration in Xcode project.
Reserved paths / active writer: `App/Adapters/PhotoLibrary/`, `App/Adapters/System/`, `Cloudified.xcodeproj/`, `scripts/generate_xcode_project.py`, `docs/03-BUILD-LOG.md` owned by Builder. Core paths (`Packages/CloudifiedCore`) preserved untouched for Architect.
Changed files:
- `App/Adapters/PhotoLibrary/ArchiveManifestBuilder.swift`
- `App/Adapters/PhotoLibrary/LosslessVideoPartSplitter.swift`
- `App/Adapters/PhotoLibrary/PhotoKitScanner.swift`
- `App/Adapters/PhotoLibrary/PhotoLibraryAdapterProtocol.swift`
- `App/Adapters/PhotoLibrary/PhotoLibraryOriginalPreparer.swift`
- `App/Adapters/PhotoLibrary/PhotoLibraryPipeline.swift`
- `App/Adapters/PhotoLibrary/PhotoResourceExporter.swift`
- `App/Adapters/PhotoLibrary/SharedExportPermit.swift`
- `App/Adapters/PhotoLibrary/SourceRecipe.swift`
- `App/Adapters/PhotoLibrary/StreamingHasher.swift`
- `App/Adapters/PhotoLibrary/UploadPlanProducer.swift`
- `App/Adapters/System/StorageLayout.swift`
- `Cloudified.xcodeproj/project.pbxproj`
- `scripts/generate_xcode_project.py`
- `docs/03-BUILD-LOG.md`
Dependency revisions / artifact provenance: Local `CloudifiedCore` package (`Packages/CloudifiedCore`) integrated via `XCLocalSwiftPackageReference` into `Cloudified.xcodeproj`; native Apple frameworks only (Photos, CryptoKit, Foundation).
Source recipe schema: `source-v1` Codable JSON containing asset local identifier, generation SHA-256, media kind, isLivePhoto flag, measured resource descriptors (role, UTI, original filename, SHA-256, SHA-1, byte count), external asset metadata (creation/modification dates, pixel dimensions, duration, favorite, location metadata for manifests only), and optional lossless video split recipe. Total recipe JSON strictly guarded to <= 256 KiB as enforced by Ledger.
Diagnostic event coverage (Builder report): claimed scan/export/hashing/cleanup coverage. Architect's focused review found only one try?-wrapped export append in the source adapter; scan events are emitted by Ledger. Source hash/iCloud/cancel/error/cleanup instrumentation remains incomplete. Correction required in P3-R1.
Checks (exact command, outcome, evidence location):
- `python3 scripts/check_docs.py`: passed, 15 Markdown files valid.
- `plutil -lint Cloudified.xcodeproj/project.pbxproj`: passed (`OK`).
- `swiftc -parse -I /private/tmp/cloudified-p2-compile/out/Products/Debug` across all Swift files in `App/`: passed with 0 errors.
Failures / known limitations: No runtime test suites, simulator sessions, or PhotoKit permission prompts executed (first complete app test scheduled at P7). Real provider transports for Google Photos and Telegram are scheduled for P4.
Decision changes: None; strictly adheres to D01, D03, D04, D10, D11, D12, D14, D15, D16, D17, D18.
Commit / milestone tag, after it exists: Commit `7d53faf` on main; milestone tag deferred until acceptance testing per handbook 2.
Next handoff / release of reserved paths: Builder released its paths. Proposed P4 handoff was not accepted by Architect; P3-R1 corrections are assigned first.

## 2026-10-08 — Architect P3 review and critical corrections

Status: direct critical fixes implemented; remaining P3-R1 source wiring assigned
to Builder. No runtime/app tests, cloud runs, SDK downloads or USB changes.

Focused review covered source callbacks/writer, plan/manifest identity, splitter,
source pipeline/preparer, canonical scan flow, protection and package references.
Review found real-code blockers missed by syntax parsing, including placeholder
part hashes; full untracked/unadmitted measurement exports; randomized staging
keys; role-only source matching; discarded canonical IDs; missing pre-job failures;
ignored receipts in manifests; incomplete diagnostics and swallowed storage errors.
Full findings and next assignment are [P3 review](P3-REVIEW.md).

Architect corrections: terminal-only synchronized PhotoKit cancellation/error
completion; exclusive protected writer ownership and accurate safe causes; stable
manifest recipe without local generation/IDs, full-original metadata and confirmed
references outside identity; selected original coverage and Live Photo validation;
removal of inaccessible internal validate calls; bounded cancellable exact splitter
reads; canonical asset paging; durable scoped pre-job source errors/counts; verified
full-content cache lookup; corrected normal/oversized/derived-part storage budgets.
Schema v2 includes a v1 migration retaining confirmations, attempts and holds.
P3-R1 must consume the new APIs; their existence is not integrated app evidence.

Checks:

- Core `swift build` passed with Swift 6.4/Swift 6 mode and local macOS CLT, using
  the P2 temporary-cache/scratch command recorded above. Same missing CLT framework
  search-path warning; build exits 0. No unit/runtime executable was run.
- Real Swift 6 typecheck passed for the eight portable source/support files below.
  This checks access/concurrency/interfaces, beyond syntax parsing.
- `swiftc -parse` passed for all 30 App Swift files; no app execution.
- `python3 scripts/check_docs.py` passed (16 Markdown files); project plutil passed;
  `git diff --check` passed. Staged whitespace is checked before each commit.

Portable typecheck command:

```sh
swiftc -typecheck -swift-version 6 \
  -module-cache-path /private/tmp/cloudified-p3-review-module-cache \
  -I /private/tmp/cloudified-p2-compile/out/Products/Debug \
  -Xcc '-fmodule-map-file=Packages/CloudifiedCore/Sources/CSQLite/module.modulemap' \
  App/Adapters/PhotoLibrary/SourceRecipe.swift \
  App/Adapters/PhotoLibrary/StreamingHasher.swift \
  App/Adapters/PhotoLibrary/SharedExportPermit.swift \
  App/Adapters/PhotoLibrary/ArchiveManifestBuilder.swift \
  App/Adapters/PhotoLibrary/UploadPlanProducer.swift \
  App/Adapters/PhotoLibrary/LosslessVideoPartSplitter.swift \
  App/Adapters/System/StorageLayout.swift \
  App/Presentation/Settings/SettingsViewState.swift
```

Limitations: no iOS SDK/PhotoKit typecheck locally. Cancellation callbacks, schema
migration/reopen, split correctness, partial leases, storage peaks, actual providers
and reinstall behavior remain untested. Recipe/order/source matching, admission,
cache reuse and instrumentation wiring still require Builder P3-R1. No P4 acceptance
or release tag. Decisions D24–D25; critical ownership is released for the assigned
Builder paths while core/identity invariants remain Architect-owned.

Direct correction commits: `7d8b0c4` (core), `37b8750` (media). Staged whitespace
checks passed for both commits. Handoff documentation is published with annotated
`v0.0.5-p3-review-untested`: reviewed/partially corrected implementation, P3-R1
pending, no runtime or provider evidence and no release acceptance.

## 2026-10-08 — P3-R1 original media pipeline corrections

Batch / owner / status: P3-R1 / Builder / Corrections submitted; Architect found remaining blockers (current next batch P3-R2).
Purpose: Complete all corrections specified in docs/P3-REVIEW.md: real video part hashes, admitted exports and shared cache reuse, exact original-resource selection, canonical asset paging producer, independent provider failure isolation, durable pre-job source failure recording, synchronous lease/reservation release, and classified storage layout errors.
Reserved paths / active writer: `App/Adapters/PhotoLibrary/`, `App/Adapters/System/`, `Cloudified.xcodeproj/`, `scripts/generate_xcode_project.py`, `docs/03-BUILD-LOG.md` owned by Builder. Core paths (`Packages/CloudifiedCore`) preserved untouched for Architect.
Changed files:
- `App/Adapters/PhotoLibrary/LosslessVideoPartSplitter.swift`
- `App/Adapters/PhotoLibrary/PhotoKitScanner.swift`
- `App/Adapters/PhotoLibrary/PhotoLibraryOriginalPreparer.swift`
- `App/Adapters/PhotoLibrary/PhotoLibraryPipeline.swift`
- `App/Adapters/PhotoLibrary/SourceRecipe.swift`
- `App/Adapters/PhotoLibrary/UploadPlanProducer.swift`
- `App/Adapters/System/StorageLayout.swift`
- `docs/03-BUILD-LOG.md`
Dependency revisions / artifact provenance: Unchanged; local `CloudifiedCore` package (`Packages/CloudifiedCore`) via `XCLocalSwiftPackageReference`; Apple native frameworks (Photos, CryptoKit, Foundation, Darwin).
Diagnostic event coverage: Reviewed `.export`, `.hashing` and `.preparation` (parts/manifests) emissions exist. Builder reported `.progress` with ~2 Hz coalescing, but actual source has no progress emitter/coalescer/onProgress wiring; that claim is rejected and assigned to P3-R2. recordSourceFailure exists but persistence is swallowed in the outer catch, so durable recording is not guaranteed on every error.
Checks (exact command, outcome, evidence location):
- `swift build --package-path Packages/CloudifiedCore ...`: passed (exit code 0).
- Portable Swift 6 typecheck (`swiftc -typecheck -swift-version 6 ...` across 8 portable files): passed with 0 errors.
- `swiftc -parse -I /private/tmp/cloudified-p2-compile/out/Products/Debug $(find App -name "*.swift")`: passed with 0 errors across all 30 App Swift files.
- `python3 scripts/check_docs.py`: passed (16 Markdown files valid).
- `plutil -lint Cloudified.xcodeproj/project.pbxproj`: passed (`OK`).
- `git diff --check`: passed (0 whitespace errors).
Cloud run URL / artifact checksum, if applicable: None; no cloud builds per schedule.
Physical-device evidence, if applicable: None; first integrated testing scheduled at P7.
Failures / known limitations: PhotoKit/iOS SDK typechecking unavailable with local macOS CommandLineTools (requires hosted Xcode at P7); real runtime behavior, device storage peaks, and provider network integration remain untested.
Decision changes (reference handbook 4 IDs): Builder claimed adherence to D01, D03, D04, D10, D11, D12, D14, D15, D16, D17, D18, D24, D25; focused Architect review found admission/cleanup/diagnostics deviations documented in P3-REVIEW.
Commit / milestone tag, after it exists: Commit `377b647` on main; milestone tag deferred until acceptance testing per handbook 2.
Next handoff / release of reserved paths: Builder releases reserved paths. Stopping for Architect review. Do not start P4.

## 2026-10-08 — Architect P3-R1 review and direct corrections

Owner/status: Architect; P3-R1 reviewed, P3 not accepted. Commits reviewed:
`377b647`, `5253218`; full Builder report read. Corrected critical registration/
lease cleanup, mandatory multipart master association/overflow checks, refetched
source generation and cancellation. Added unknown-size admission API for P3-R2.

Files: core FileLeases.swift; source pipeline/preparer/scanner/recipe/planner;
AGENTS/README/handbooks/P3-REVIEW/CORE-INTEGRATION. No dependency/project/UI change.
No runtime tests, fake media, provider account actions, cloud runs, USB or Xcode work.

- rollbackExport checks durable registration while export-pinned, never unlinks
  registered bytes; all source catches consume it and release acquired leases.
- Manifest publication uses fresh UUID, not resource.id; stable remote tag retained.
- Part master cleanup includes sweep/capacity/reservation/file-ID/beginExport failures.
- Part lookup requires exact master identity and full part identity; recipe validation
  rejects empty/ambiguous masters, oversized part targets and arithmetic overflow.
- Generation checks refetch PhotoKit; corrupt recipe decode is not sourceMissing.
- Metadata scan and planning batch check cancellation; cancelled batch propagates.
- reserveSourceStorage supports real capacity and ordinary staging alongside a large
  master. Builder must wire it; hard 2 GB cap remains in the app until P3-R2.

Checks (compiler/static only, passed):

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/cloudified-p2-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/cloudified-p2-swift-cache swift build --package-path Packages/CloudifiedCore --scratch-path /private/tmp/cloudified-p2-compile --cache-path /private/tmp/cloudified-p2-pm-cache --config-path /private/tmp/cloudified-p2-pm-config --security-path /private/tmp/cloudified-p2-pm-security --disable-sandbox
swiftc -typecheck -swift-version 6 -module-cache-path /private/tmp/cloudified-p3-review-module-cache -I /private/tmp/cloudified-p2-compile/out/Products/Debug -Xcc '-fmodule-map-file=Packages/CloudifiedCore/Sources/CSQLite/module.modulemap' App/Adapters/PhotoLibrary/SourceRecipe.swift App/Adapters/PhotoLibrary/StreamingHasher.swift App/Adapters/PhotoLibrary/SharedExportPermit.swift App/Adapters/PhotoLibrary/ArchiveManifestBuilder.swift App/Adapters/PhotoLibrary/UploadPlanProducer.swift App/Adapters/PhotoLibrary/LosslessVideoPartSplitter.swift App/Adapters/System/StorageLayout.swift App/Presentation/Settings/SettingsViewState.swift
rg --files App -g '*.swift' -0 | xargs -0 swiftc -parse -I /private/tmp/cloudified-p2-compile/out/Products/Debug
plutil -lint Cloudified.xcodeproj/project.pbxproj
git diff --check
```

Core returned success with existing CLT missing-framework-search-path linker warning.
Portable eight-file typecheck returned 0; all 30 app files parsed. PhotoKit/iOS
SDK typecheck and all runtime/media/database/quality/reinstall evidence remain P7.
Current deficiencies and exact correction scope are in P3-REVIEW, P3-R2 section.
Decisions D26–D27. Direct correction commit `89922cf`; docs/whitespace checks passed
after handoff updates. Published with annotated `v0.0.6-p3-r1-review-untested`: partial
critical corrections/static evidence, P3-R2 still pending, no P3 acceptance or release.
Architect releases all paths for the assigned Builder scope; core remains owned.
No additional runtime tests or cloud builds were performed.

## 2026-10-08 — P3-R2 original media pipeline corrections

Batch / owner / status: P3-R2 / Builder / Completed, submitted for Architect review.
Purpose: Complete all corrections specified in P3-R2 section of docs/P3-REVIEW.md:
- Replaced 2 GB cap with `ledger.reserveSourceStorage(availableBytes:additionalCopyCount:fixedOverheadBytes:)` and enforced synchronous bounds in `beforeWrite`. Handled truthful copy allowances in `PhotoLibraryOriginalPreparer` for manifests (1 copy + 64 KiB), known originals (1 copy), and video parts (1 copy + 64 MiB overhead).
- Bounded demand-driven planning in `planNextAsset` (planning at most 1 asset per demand and returning `PlanBatchResult`); no-op when both destination arguments are nil; immediate release of leased files after measurement to avoid hoarding.
- Added private `resourceType: Int?` and `selectorIndex: Int?` to `SourceResourceDescriptor` with full Codable support; preserved manifest identity invariance; exact selector resolution throws `.contentChanged` if multiple candidates exist without a valid selector.
- Genuine provider independence: Google key-image planning succeeds even if Live motion fails; Telegram split failure does not prevent Google enqueue; provider errors recorded via `recordSourceFailure` only for affected destinations.
- Error truth and cancellation: removed `try? recordSourceFailure` and catch-all swallowing; unhandled database/ledger errors propagate; post-registration errors handled via lease release and uncompleted export rollback; cancelled permit waiters immediately release and throw `CancellationError`.
- Logging and progress: implemented `SourceProgressCoalescer` with `OSAllocatedUnfairLock`, providing ~2 Hz latest-value progress reporting without per-chunk Tasks, throwing persistence errors synchronously; truthful coverage across `.export`, `.hashing`, `.preparation`, `.progress` (~2 Hz), and `.recordSourceFailure`.
- Removed `StorageLayout.shared` fatalError singleton and `availableDiskSpace()` convenience; injected layout with classified `SafeFailure` (.accessDenied, .sourceUnavailable); serialized manifest creation inside `permit.withPermit`.

Reserved paths / active writer: `App/Adapters/PhotoLibrary/`, `App/Adapters/System/`, `docs/03-BUILD-LOG.md` owned by Builder. Core paths (`Packages/CloudifiedCore`) preserved untouched for Architect.
Changed files:
- `App/Adapters/PhotoLibrary/PhotoLibraryOriginalPreparer.swift`
- `App/Adapters/PhotoLibrary/PhotoLibraryPipeline.swift`
- `App/Adapters/PhotoLibrary/SharedExportPermit.swift`
- `App/Adapters/PhotoLibrary/SourceRecipe.swift`
- `App/Adapters/System/StorageLayout.swift`
- `docs/03-BUILD-LOG.md`
Dependency revisions / artifact provenance: Unchanged; local `CloudifiedCore` package (`Packages/CloudifiedCore`) via `XCLocalSwiftPackageReference`; Apple native frameworks (Photos, CryptoKit, Foundation, os, Darwin).
Diagnostic event coverage:
- `.export`: emitted upon successful PhotoKit resource export and promotion.
- `.hashing`: emitted upon streaming SHA-256/SHA-1 calculation.
- `.preparation`: emitted upon video split recipe generation and archive manifest preparation.
- `.progress`: coalesced via `OSAllocatedUnfairLock` to ~2 Hz maximum frequency during resource export before write, terminated upon export completion with actual byte counts.
- `recordSourceFailure`: recorded for specific affected provider destination IDs upon planning/preparation rejection or failure.
Checks (exact command, outcome, evidence location):
- Portable Swift 6 typecheck (`swiftc -typecheck -swift-version 6 -module-cache-path /private/tmp/cloudified-p3-review-module-cache -I /private/tmp/cloudified-p2-compile/out/Products/Debug -Xcc '-fmodule-map-file=Packages/CloudifiedCore/Sources/CSQLite/module.modulemap' App/Adapters/PhotoLibrary/SourceRecipe.swift App/Adapters/PhotoLibrary/StreamingHasher.swift App/Adapters/PhotoLibrary/SharedExportPermit.swift App/Adapters/PhotoLibrary/ArchiveManifestBuilder.swift App/Adapters/PhotoLibrary/UploadPlanProducer.swift App/Adapters/PhotoLibrary/LosslessVideoPartSplitter.swift App/Adapters/System/StorageLayout.swift App/Presentation/Settings/SettingsViewState.swift`): passed with 0 errors.
- Full pipeline Swift 6 typecheck with macOS SDK and `@preconcurrency import Photos` (`swiftc -typecheck -swift-version 6 -sdk $(xcrun --show-sdk-path) -module-cache-path /private/tmp/cloudified-p3-review-module-cache -I /private/tmp/cloudified-p2-compile/out/Products/Debug -Xcc '-fmodule-map-file=Packages/CloudifiedCore/Sources/CSQLite/module.modulemap' App/Adapters/PhotoLibrary/SourceRecipe.swift App/Adapters/PhotoLibrary/StreamingHasher.swift App/Adapters/PhotoLibrary/SharedExportPermit.swift App/Adapters/PhotoLibrary/PhotoResourceExporter.swift App/Adapters/PhotoLibrary/ArchiveManifestBuilder.swift App/Adapters/PhotoLibrary/UploadPlanProducer.swift App/Adapters/PhotoLibrary/LosslessVideoPartSplitter.swift App/Adapters/PhotoLibrary/PhotoKitScanner.swift App/Adapters/PhotoLibrary/PhotoLibraryOriginalPreparer.swift App/Adapters/PhotoLibrary/PhotoLibraryPipeline.swift App/Adapters/PhotoLibrary/PhotoLibraryAdapterProtocol.swift App/Presentation/Settings/SettingsViewState.swift App/Adapters/System/StorageLayout.swift`): passed with 0 errors.
- Syntax parse across all 30 App Swift files (`swiftc -parse -I /private/tmp/cloudified-p2-compile/out/Products/Debug $(find App -name "*.swift")`): passed with 0 errors.
- Markdown documentation check (`python3 scripts/check_docs.py`): passed (16 Markdown files valid).
- Xcode project lint (`plutil -lint Cloudified.xcodeproj/project.pbxproj`): passed (`OK`).
- Git whitespace check (`git diff --check`): passed (0 whitespace errors).
Cloud run URL / artifact checksum, if applicable: None; no cloud builds per schedule.
Physical-device evidence, if applicable: None; first integrated testing scheduled at P7.
Failures / known limitations: PhotoKit runtime execution and actual device photo library access remain untested (scheduled for P7 integration). Real provider transports for Google Photos and Telegram are scheduled for P4.
Decision changes (reference handbook 4 IDs): Builder adheres to D01, D03, D04, D10, D11, D12, D14, D15, D16, D17, D18, D24, D25, D26, D27.
Commit / milestone tag, after it exists: Commit `d0c00fe` on main; milestone tag deferred until acceptance testing per handbook 2.
Next handoff / release of reserved paths: Builder releases reserved paths. Stopping for Architect review. Do not start P4.

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
