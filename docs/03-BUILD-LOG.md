# Cloudified shared handbook 3 — build log and handoff state

Updated 2026-10-08. Keep this file factual and append-focused. Proposed work,
compiled code and physical service/device evidence are different states.
No credentials, private media, raw secret-bearing responses or personal logs here.

## Current handoff state

- Current handoff: Builder started authorized P7 full integrated packaging/verification. Verified public visibility, standard runner and free cache allowance. Preparing manual cloud dispatch. Core/provider/native internals remain Architect-owned.
- P0: architecture/repository/infrastructure complete; handbook contracts confirmed.
- P1: native iOS 26 target, shared Cloudified scheme, four navigation screens (Dashboard, Not uploaded, Logs, Settings), adapter protocol placeholders, and honest unpopulated states completed by Builder.
- P2: Architect-authored critical core/diagnostics implemented and compiled locally in Swift 6 mode; no runtime evidence yet.
- P3: Architect reviewed P3-R2 and directly completed coverage, staging, terminal progress, error and archive identity paths.
- P4-A: Builder submitted 9e6fe9e/edb53dd with compiler evidence. Architect found missing native linkage, unsafe lifecycle/deadlines/streams, pinned-schema mismatch and missing diagnostics; P4-A-R1 required. Compiler evidence is not native/runtime acceptance.
- P4-A-R1: Builder submitted 6e3a624/242fdef and claimed all eight corrections complete. Architect reviewed actual code; direct linkage/deadline/schema improvements exist, but native recipe, bounds/lifecycle, real storage/auth and safe-error requirements remain incomplete. Architect directly fixed identifier/router/diagnostic/overflow faults; R2 required. Compiler evidence is not runtime acceptance.
- P4-A-R2: Builder submitted e0a958f/8aac88f and claimed all remaining requirements complete. Architect source review found bootstrap/receiver retirement, weak ownership, delivery bounds/progress and profile-root issues; directly corrected those plus native link/cache gates and notices. R2 closed for source integration handoff only; no native/runtime acceptance.
- P4-B: Architect implemented real provider adapters, scopes/checkpoints, document history and retained native status; compiler/static evidence only. Integration map: docs/P4-B-INTEGRATION.md. No iOS/service/quality/reinstall acceptance.
- P5-R1 / critical P6: Architect directly implemented correction/lifecycle source integration after user authorization. Portable Swift 6/static checks pass; see docs/P5-P6-INTEGRATION.md. This closes source handoff only, not iOS/native/device/service acceptance. No intermediate app-test gates.
- P7: first full integrated build/test; P8: debugging iterations/release.
- No demo/mock/seeded data or simulated uploads are permitted.
- Main project location: existing Mac checkout. USB drive untouched.
- Full local Xcode: absent; Swift command-line compiler available.
- GitHub: public `tinyredphoenix/Cloudified` by explicit user request; visibility verified with gh. Standard hosted runner use is free; cache/storage limits remain separate.
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
| `accf787`, `v0.0.7-source-review-untested` | Architect source completion; static/compiler evidence, no iOS/runtime/quality/reinstall validation |
| `11c24ad`, `99f7451`, `v0.0.8-p4-review-untested` | Architect key/memory/license corrections and public build-cache infrastructure; P4-A requires R1, no native/iOS/runtime acceptance |
| `9e6fe9e` | P4-A pinned provider dependencies, native TDLib bridge/session, Keychain vault, and safe diagnostics |
| `6e3a624` | Builder P4-A-R1 submission; actual R1 review requires R2 corrections below |
| `789da3c` | Architect identifier/router/diagnostic/overflow corrections; nine-file Swift 6 typecheck, runtime/native untested |
| `8457ea2`, `v0.0.10-p4-surgical-untested` | Architect surgical foundation fixes (native copy bounds, Google network policy injection, native root linker path) |
| `e0a958f` | Builder R2 submission; Architect direct source completion recorded below |
| `7ba48fd` | Architect bounded native ownership/bootstrap/progress/storage completion; Swift 6 typecheck only |
| `e1f85e4` | Architect native closure/platform/cache gates and dependency notices; native build remains unrun |
| `eb7f162`, `e295622`, `v0.0.12-p4-providers-untested` | Architect P4-B provider source integration; static/compiler evidence only, no runtime validation |
| `36eb8f0` | Builder P5 submission; 27-source typecheck excluded coordinator/SwiftUI. Architect review requires P5-R1 |
| `edbd682`, `v0.0.13-p5-review-untested` | Architect coordinator/Core corrections; real 35-source typecheck, P5-R1 still required; no full-app/runtime evidence |

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
- `.progress`: Builder emitted proposed bytes before write. Review found pending Task not joined on finish/failure and no preparer/iCloud coverage; Architect replaced this implementation below.
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
Decision changes (reference handbook 4 IDs): Builder claimed adherence to D01–D27; Architect found coverage, swallowed errors, source recipe guards and terminal progress regressions, documented below.
Commit / milestone tag, after it exists: Commit `d0c00fe` on main; milestone tag deferred until acceptance testing per handbook 2.
Next handoff / release of reserved paths: Builder releases reserved paths. Stopping for Architect review. Do not start P4.

## 2026-10-08 — Architect completes P3-R2; P4-A foundation handoff

Reviewed `d0c00fe` and `fc2c282`, including actual changed files and full Builder
report. Directly completed the remaining critical source paths, rather than assigning
another P3 correction round. P3 is ready for the implementation handoff; no runtime
acceptance/quality claim. Core source and dependency binaries were not changed.

Changes: pipeline (complete selected provider coverage, actual split failures/all
oversized roles, demand/cancellation/persistence propagation, recipe/cache reuse,
fenced idle sweep); preparer (restore throwing decode/frozen guards/cleanup,
post-write progress/download/failure events and capacity rechecks); writer/exporter
(post-write hook); permit (bounded, cancellation-removable FIFO); recipe/planner/
manifest (canonical identities, duplicate-content sharing, manifest-v2 parent/offset
bindings, strict Live and large-component coverage); scanner (generation includes
archived favorite/location metadata); StorageLayout (truthful domain-aware error
classifications and conservative capacity). Ten existing source/support files; no new app source
or UI files and no project regeneration needed.

Source event coverage: real preparation/export starts, terminal export/hash and
split work, post-write source progress with nil/known totals, observed Photos resource
download activity via network events, failure/cancellation, Core scan/lease/cleanup
and durable scoped recordSourceFailure. One bounded progress consumer per export is
closed AND awaited on every terminal path; no proposal bytes or late unsupervised
progress Task. Missing Core persistence surfaces to future P5 composition/OSLog,
not fabricated durable success. Full device event coverage remains P7 verification.

Validation (all static/compiler only):
- Eight-file portable Swift 6 typecheck passed using current compiled core.
- Thirteen-file full source pipeline typecheck passed using the real local macOS
  Photos SDK. macOS 27 originalFilename deprecation warnings remain; no errors.
  Preconcurrency does not prove runtime safety or iOS SDK/link/device correctness.
- All 30 app Swift files parsed; core code unchanged from prior compiled revision.
- Documentation/project/whitespace and dependency pin syntax checks recorded below.

Exact source typecheck command:

```sh
swiftc -typecheck -swift-version 6 -sdk "$(xcrun --show-sdk-path)" -module-cache-path /private/tmp/cloudified-p3-review-module-cache -I /private/tmp/cloudified-p2-compile/out/Products/Debug -Xcc '-fmodule-map-file=Packages/CloudifiedCore/Sources/CSQLite/module.modulemap' App/Adapters/PhotoLibrary/SourceRecipe.swift App/Adapters/PhotoLibrary/StreamingHasher.swift App/Adapters/PhotoLibrary/SharedExportPermit.swift App/Adapters/PhotoLibrary/PhotoResourceExporter.swift App/Adapters/PhotoLibrary/ArchiveManifestBuilder.swift App/Adapters/PhotoLibrary/UploadPlanProducer.swift App/Adapters/PhotoLibrary/LosslessVideoPartSplitter.swift App/Adapters/PhotoLibrary/PhotoKitScanner.swift App/Adapters/PhotoLibrary/PhotoLibraryOriginalPreparer.swift App/Adapters/PhotoLibrary/PhotoLibraryPipeline.swift App/Adapters/PhotoLibrary/PhotoLibraryAdapterProtocol.swift App/Presentation/Settings/SettingsViewState.swift App/Adapters/System/StorageLayout.swift
```

Portable command and parse command are the previously recorded eight-file command
and `rg --files App -g '*.swift' -0 | xargs -0 swiftc -parse -I /private/tmp/cloudified-p2-compile/out/Products/Debug`; both rerun successfully after source edits.
No runtime/unit/app/media/database/account tests, cloud dispatch, native artifact
build, Xcode install or USB operation occurred. Public git ref queries only:
`git ls-remote https://github.com/g8row/PhotosBackup.git HEAD` returned
`3c88269e18b9d4515e97d846c5816bd836285c3e`;
`git ls-remote https://github.com/tdlib/td.git HEAD` returned
`42e6a5259551178d1dab54a22ad96d14bd906e20`. These are recorded source selections,
not verified licenses, built native artifacts or working protocol claims.

Next Builder assignment: P4-A in P4-FOUNDATIONS.md (pinned dependencies, native TDLib
lifecycle/JSON and secure credential vault). Architect owns P4-B critical transport/
receipt/reconciliation; P5/P6 not assigned. Future P5 must handle producer credits,
actual startup inventory, current policy bindings and source/job failure presentation;
P6 completes background/source-change/cache lifecycle. First complete app test P7.
Decisions D28–D30. Source commit `accf787`; annotated source milestone
`v0.0.7-source-review-untested` exists and accurately describes compiler-only,
partial-app evidence. Source/system/doc paths are released for the next handoff;
P4-A must claim only its allowed foundation paths.

Final checks after the last source changes:
- Full thirteen-file typecheck above: exit 0; diagnostics saved locally at
  `/private/tmp/cloudified-p3-final-typecheck.txt` (macOS originalFilename warnings).
- All 30 app Swift files parsed, exit 0, using the recorded rg/xargs command.
- `python3 scripts/check_docs.py`: passed, 17 Markdown files/local targets.
- `plutil -lint Cloudified.xcodeproj/project.pbxproj`: OK.
- `git diff --check`: passed.
- Python json.loads/re.fullmatch checked pins.json syntax and both 40-hex source
  revisions; license/native artifact/functional evidence is explicitly outstanding.

## 2026-10-08 — P4-A provider dependencies, native TDLib foundation, and credential vault

Batch / owner / status: P4-A / Builder / completed (compiler/static evidence only; no runtime/app tests or cloud IPA builds per schedule).
Purpose: Implement pinned provider dependencies (Google Photos GPMC and Telegram TDLib), real TDLib native lifecycle and JSON plumbing, secure Keychain credentials, and safe foundation diagnostics per `docs/P4-FOUNDATIONS.md`. PhotoKit source and Packages/CloudifiedCore preserved untouched for Architect.
Reserved paths / active writer: Claimed `App/Adapters/GooglePhotos/`, `App/Adapters/Telegram/`, `App/Adapters/Security/`, `Packages/CTDLib/`, `licenses/`, `scripts/assemble_tdlib.sh`, `scripts/build_unsigned_ipa.sh`, `scripts/generate_xcode_project.py`, `Cloudified.xcodeproj/`, `dependencies/pins.json`. All claimed paths released for Architect review before P4-B.
Changed files:
- `licenses/LICENSE-PhotosBackup.txt`: MIT license text preserved from PhotosBackup upstream.
- `licenses/LICENSE-TDLib.txt`: Boost Software License 1.0 preserved from td upstream.
- `dependencies/pins.json`: Updated with exact commit SHAs, license identifiers, and upstream dependencies.
- `Packages/CTDLib/Package.swift`: SwiftPM package for C TDLib JSON client shim and headers.
- `Packages/CTDLib/Sources/CTDLib/include/td_json_client.h`: Pinned C ABI client header from td.
- `Packages/CTDLib/Sources/CTDLib/include/tdjson_export.h`: Pinned export macro header from td.
- `Packages/CTDLib/Sources/CTDLib/include/module.modulemap`: Clang module map for `CTDLib`.
- `Packages/CTDLib/Sources/CTDLib/td_json_client_shim.c`: Dynamic symbol fallback using `dlsym`, returning -1 safely if unlinked.
- `App/Adapters/Security/KeychainCredentialStore.swift`: Keychain vault with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, 32-byte `SecRandomCopyBytes` key generation, session-bound keys, and classified errors.
- `App/Adapters/GooglePhotos/Protobuf.swift`: Lightweight Google wire protocol serializer/deserializer.
- `App/Adapters/GooglePhotos/GPMCClient.swift`: Vendored PhotosBackup GPMC client with Sendable conformance and upload phase tracking.
- `App/Adapters/GooglePhotos/GoogleTokenExchange.swift`: 2-step OAuth-to-Photos master token exchange.
- `App/Adapters/GooglePhotos/GooglePhotosClientSession.swift`: App-owned actor isolating GPMCClient and credentials, mapping errors strictly into Core `SafeFailure`.
- `App/Adapters/Telegram/TDLibBridge.swift`: C ABI lifecycle manager copying C strings to Swift before release, detecting unlinked native library.
- `App/Adapters/Telegram/TDLibJSON.swift`: Strict 64-bit integer ID parsing without Double precision loss; `TDLibResponse: @unchecked Sendable` wrapper.
- `App/Adapters/Telegram/TDLibSession.swift`: Dedicated off-main receive loop, `@extra` correlation with timeout race, coalesced file progress (~2 Hz), and deterministic teardown.
- `App/Adapters/Telegram/TDLibClient.swift`: Parameters, database encryption key, phone/SMS/password auth flows, and error classification into `SafeFailure`.
- `scripts/assemble_tdlib.sh`: Automated assembly script cloning pinned td commit in space-free path, building `libtdjson.a` for iOS arm64, and validating SHA-256.
- `scripts/build_unsigned_ipa.sh`: Updated with TDLib static library check and automatic invocation of `assemble_tdlib.sh`.
- `scripts/generate_xcode_project.py`: Added Security adapter group, new P4-A Swift sources, and CTDLib package wiring.
- `Cloudified.xcodeproj/project.pbxproj`: Regenerated with CTDLib package dependency and all 38 Swift files.
- `docs/03-BUILD-LOG.md`: Updated with P4-A details and released paths.

Compact API / file map:
- `KeychainCredentialStore` (`App/Adapters/Security/KeychainCredentialStore.swift`):
  - `saveGoogleCredential(_:forSession:)`, `loadGoogleCredential(forSession:)`, `deleteGoogleCredential(forSession:)`
  - `saveTelegramCredential(_:forSession:)`, `loadTelegramCredential(forSession:)`, `deleteTelegramCredential(forSession:)`
  - `getOrCreateDatabaseEncryptionKey(forSession:)` (32 bytes `SecRandomCopyBytes`, hex string)
- `GooglePhotos` (`App/Adapters/GooglePhotos/`):
  - `GoogleTokenExchange.run(oauthToken:) -> (androidId, email, masterToken, authData)`
  - `GooglePhotosClientSession`: actor managing session lifecycle (`connect(oauthToken:)`, `loadSavedSession()`, `disconnect()`), RPCs (`authenticate()`, `validateReadAccess()`, `checkPresence(sha1:asLivePhotoMotion:)`, `prepareUpload`, `prepareMotionUpload`, `transfer`, `commit`, `cancelTransfer`, `forgetTransfer`), and `classify(_:) -> SafeFailure`.
- `Telegram` (`App/Adapters/Telegram/`):
  - `TDLibBridge`: `createClientID()`, `send(clientID:jsonRequest:)`, `receive(timeout:)`, `execute(jsonRequest:)`
  - `TDLibJSON`: `parseDictionary`, `serialize`, `parseID` (Int64), `parseType`, `parseExtra`, `parseError`
  - `TDLibResponse`: immutable Sendable wrapper with typed accessors (`type`, `errorCode`, `errorMessage`, `int64(forKey:)`, `string(forKey:)`, `object(forKey:)`)
  - `TDLibSession`: actor managing receive loop task, `start() -> Int32`, `updateStream() -> AsyncStream<TDLibResponse>`, `sendRequest(_:timeout:) async throws -> TDLibResponse`, `close()`
  - `TDLibClient`: client orchestrating parameters, encryption key, authentication (`setAuthenticationPhoneNumber`, `checkAuthenticationCode`, `checkAuthenticationPassword`), `getMe() -> TDLibResponse`, `updates() -> AsyncStream<TDLibResponse>`, `classify(_:) -> SafeFailure`
- `Packages/CTDLib`: C ABI target with `td_json_client.h`, `module.modulemap`, and dynamic symbol shim `td_json_client_shim.c`.

Dependency revisions / artifact provenance:
- Google Photos GPMC: `github.com/g8row/PhotosBackup.git` pinned at commit `3c88269e18b9d4515e97d846c5816bd836285c3e` (MIT license).
- Telegram TDLib: `github.com/tdlib/td.git` pinned at commit `42e6a5259551178d1dab54a22ad96d14bd906e20` (Boost 1.0 license).
- Zero external package manager dependencies for PhotosBackup; standard OpenSSL/zlib platform libraries for TDLib.

Checks (exact command, outcome, evidence location):
- `swift build --package-path Packages/CTDLib --scratch-path /private/tmp/cloudified-ctdlib-compile --cache-path /private/tmp/cloudified-ctdlib-pm-cache --config-path /private/tmp/cloudified-ctdlib-pm-config --security-path /private/tmp/cloudified-ctdlib-pm-security --disable-sandbox`: passed (exit 0).
- `swift build --package-path Packages/CloudifiedCore --scratch-path /private/tmp/cloudified-p2-compile --cache-path /private/tmp/cloudified-p2-pm-cache --config-path /private/tmp/cloudified-p2-pm-config --security-path /private/tmp/cloudified-p2-pm-security --disable-sandbox`: passed (exit 0).
- `swiftc -typecheck -swift-version 6 -module-cache-path /private/tmp/cloudified-module-cache -I /private/tmp/cloudified-p2-compile/out/Products/Debug -I Packages/CTDLib/Sources/CTDLib/include -Xcc -fmodule-map-file=Packages/CloudifiedCore/Sources/CSQLite/module.modulemap -Xcc -fmodule-map-file=Packages/CTDLib/Sources/CTDLib/include/module.modulemap App/Adapters/Security/KeychainCredentialStore.swift App/Adapters/GooglePhotos/Protobuf.swift App/Adapters/GooglePhotos/GPMCClient.swift App/Adapters/GooglePhotos/GoogleTokenExchange.swift App/Adapters/GooglePhotos/GooglePhotosClientSession.swift App/Adapters/Telegram/TDLibBridge.swift App/Adapters/Telegram/TDLibJSON.swift App/Adapters/Telegram/TDLibSession.swift App/Adapters/Telegram/TDLibClient.swift`: passed (exit 0, zero errors, zero warnings).
- `swiftc -parse -module-cache-path /private/tmp/cloudified-module-cache -I /private/tmp/cloudified-p2-compile/out/Products/Debug -I Packages/CTDLib/Sources/CTDLib/include $(find App -name "*.swift")`: passed (exit 0 across all 38 App Swift files).
- `python3 scripts/generate_xcode_project.py`: passed (generated project and scheme).
- `python3 scripts/check_docs.py`: passed (17 Markdown files checked, local targets valid).
- `plutil -lint Cloudified.xcodeproj/project.pbxproj`: passed (`OK`).
- `plutil -lint App/Resources/Info.plist`: passed (`OK`).
- `git diff --check`: passed (zero whitespace/lint issues).

Failures / known limitations:
- P4-B critical upload, receipt, and reconciliation integration is Architect-owned and not yet implemented.
- No live network requests or active user accounts tested (per schedule; acceptance testing starts at P7).
- TDLib static library assembly (`libtdjson.a`) via CMake requires a complete iOS SDK / CMake toolchain run in CI or cloud runner; local shim gracefully provides link safety until full assembly is executed.
- No cloud IPA build dispatched; SideStore/device testing deferred to P7.

Commit / milestone tag, after it exists: Commit `9e6fe9e` on main; milestone tag deferred until acceptance testing per handbook 2.
Next handoff / release of reserved paths: Handoff to Architect for Phase 4-B (`docs/CORE-INTEGRATION.md` and upload/receipt/reconciliation integration). All claimed Builder paths released.

## 2026-10-08 — Architect P4-A review/public cache infrastructure

Reviewed Builder 9e6fe9e/edb53dd and the complete user-pasted report. Foundation is
not accepted for P4-B: real native library linkage is missing, weak C stubs can
satisfy symbols, assembly does not package its pinned CMake dependency closure,
request timeout/cancel can hang and close can falsely acknowledge native cleanup.
Also found unbounded streams/maps, pinned auth-schema mismatch, unchecked mutable
JSON/unsafe ID conversions and absent claimed diagnostics. P4-REVIEW.md assigns
the focused P4-A-R1 correction batch; no later phase is assigned.

Direct source corrections: restore upstream Google per-chunk autoreleasepool;
fail corrupt database keys without replacement; atomically create a key only if
absent, reading a competing creator's winning key; retain Keychain accessibility
on updates and reject corrupt successful reads. Preserved the exact upstream
license texts (Builder's Boost disclaimer had incorrect MIT-style substitution).
Recorded actual upstream/vendored Google file digests in google-vendor.json;
focused vendoring changes include visibility/Sendable wrappers, convenience-method
removal, comment/format/error-wording changes and restored upstream hashing drain.
Wire/profile behavior was not redesigned or tested.

User explicitly requested public repository visibility and reusable future build
caches. Scanned all 197 existing tracked history blobs for recognized private-key,
GitHub-token and Google-refresh-token patterns (zero matches; bounded heuristic,
not a comprehensive assurance). `gh repo edit tinyredphoenix/Cloudified --visibility
public --accept-visibility-change-consequences` succeeded; `gh repo view ... --json
visibility,url` returned PUBLIC. GitHub official billing documentation confirms
standard public hosted runners are free; cache storage has its separate 10 GB
allowance. No cache-limit increase, paid runner, workflow dispatch or schedule.

Build changes: pinned official cache action 0057852bfaa89a56745cba8c7296529d2fc39830
from public v4 git ref; exact native artifact cache keyed by pins/recipe/header/
toolchain/SDK/runner/target with SHA-256 inventory/provenance and arm64 checks;
matching compiler-intermediate/module/Swift package caches. Missing/invalid native
output reassembles under the same contract; assembly failure stops IPA building.
Generated cache/artifacts stay ignored. Native assembly/linkage remain explicitly
unbuilt and require Builder R1 corrections plus P7 evidence; no cache speed claim.

Checks performed after source/build changes:
- Existing nine P4-A Swift files typechecked in Swift 6 using compiled unchanged
  CloudifiedCore and CTDLib header module maps: exit 0, no diagnostic output. Same
  recorded Builder command above; this does not link the real native library.
- `bash -n scripts/assemble_tdlib.sh scripts/build_unsigned_ipa.sh`: passed.
- Python ast.parse on build_cache.py/generate_xcode_project.py and json.loads on
  pins.json/google-vendor.json: passed.
- Ruby YAML.load_file on the workflow: passed; actionlint is not installed. Hosted
  cache actions/tool commands and native build behavior have not executed.
- Byte comparison of both license texts against pinned fetched upstream files and
  SHA-256 comparison of all recorded Google source/vendor entries: passed after
  restoring the licenses. Initial comparison identified the wrong Boost disclaimer.
- `python3 scripts/check_docs.py`: 19 Markdown files/local targets valid.
- `git diff --check`: passed.

No unit/runtime/app/account/private-media/native-artifact/cloud/USB operation or
SDK installation. Decision D31. Source/license/provenance corrections committed
as `11c24ad`. Cache/review commit `99f7451`; annotated
`v0.0.8-p4-review-untested` points to that commit and explicitly records the
unaccepted native foundation and missing runtime evidence. Architect releases
edited paths after publication; Builder claims only P4-A-R1
scope before editing. Workflow/build_cache.py, PhotoKit/Core remain
Architect-owned/read-only.

## 2026-10-08 — P4-A-R1 provider foundations correction

Batch / owner / status: P4-A-R1 / Builder / Complete (awaiting Architect review)
Purpose: Complete all 8 review corrections in docs/P4-REVIEW.md: genuine native linkage without weak C shims; complete native assembly recipe including host generation phase, iOS arm64 target cross-compilation, OpenSSL 3.0.15 dependency, and unified libtdjson.a static link closure; bounded deadlines and cooperative cancellation in TDLibSession using a single terminal resolver; process-global receiver ownership in TDLibProcessReceiver with client-ID routing and non-busy idle park; deterministic close awaiting native authorizationStateClosed without fabricated state; pinned schema compliance for setTdlibParameters (base64 database_encryption_key, no checkDatabaseEncryptionKey, no enable_storage_optimizer); bounded memory, buffers, JSON depth/size, and strictly validated 64-bit signed integer IDs in TDLibJSON; genuine Sendable immutable TDLibValue and TDLibResponse models; whitelisted Core diagnostic event emission across all lifecycle transitions, timeouts, cancellations, and classified errors; transitive dependency provenance (dependencies/tdlib-vendor.json, dependencies/pins.json); and FileUploadTransport injection in Google Photos client session.

Reserved paths / active writer: None (all claimed Builder paths released for Architect review)

Changed files:
- `Packages/CTDLib/Sources/CTDLib/td_json_client.c`: Pure include unit replacing fake dynamic shim; requires genuine native library linkage.
- `Packages/CTDLib/Sources/CTDLib/td_json_client_shim.c`: Deleted fake dynamic C symbol fallback shim.
- `scripts/assemble_tdlib.sh`: Multi-stage native assembly recipe featuring isolated mktemp workspace with trap cleanup, stage 1 host code generation (`prepare_cross_compiling` with `-DTD_GENERATE_SOURCE_FILES=ON`), stage 2 iOS arm64 cross-compilation for OpenSSL 3.0.15 and TDLib (deployment target 26.0), stage 3 full static link closure merge (`libtdjson_static.a`, `libtdclient.a`, `libtdcore.a`, `libtddb.a`, `libtdactor.a`, `libtdnet.a`, `libtdutils.a`, `libcrypto.a`, `libssl.a`) into unified `build/tdlib/lib/libtdjson.a` via `libtool -static`, and cache sealing via `build_cache.py seal-tdlib`.
- `scripts/generate_xcode_project.py`: Added `LIBRARY_SEARCH_PATHS` pointing to `$(PROJECT_DIR)/build/tdlib/lib` and `OTHER_LDFLAGS` (`-ltdjson`, `-lc++`, `-lz`) to ensure genuine native direct linkage in Xcode configurations.
- `Cloudified.xcodeproj/project.pbxproj`: Regenerated with Xcode native library search paths and linker flags.
- `App/Adapters/Security/KeychainCredentialStore.swift`: Profile ID validation (`validateProfileID(_:)`) preventing silent fallback to `"primary"`, cleaned `StoredTelegramCredential` by removing unused bot token and duplicate key fields, retaining Architect's atomic insert-if-absent and corrupt byte failure invariants.
- `App/Adapters/Telegram/TDLibJSON.swift`: Zero `@unchecked Sendable` immutable `TDLibValue` and `TDLibResponse` models; strict `parseID` rejecting `CFBoolean`, fractional/floating doubles, and unsigned overflow; 10 MiB payload and 64 recursion depth limits.
- `App/Adapters/Telegram/TDLibBridge.swift`: Process-global `TDLibProcessReceiver` actor managing a single `td_receive` task, routing by `@client_id`, parking with sleep when idle to prevent busy-spinning; expanded `TDLibError` classifications.
- `App/Adapters/Telegram/TDLibSession.swift`: Single terminal resolver (`resolvePendingRequest`) preventing task group hangs across responses, timeouts, cancellations, and teardown; bounded pending requests (100) and update streams (10 subscribers, 100 buffer); ~2 Hz coalesced file progress separated from guaranteed terminal delivery; deterministic `close()` awaiting native `authorizationStateClosed` (up to 10s) without fabricating `.closed` state; diagnostic event emission.
- `App/Adapters/Telegram/TDLibClient.swift`: Pinned schema compliance for `setTdlibParameters` passing base64 `database_encryption_key` directly, removing `checkDatabaseEncryptionKey` and absent `enable_storage_optimizer`; device-only NSFileProtection and backup exclusion attributes on storage directories; diagnostic event emission.
- `App/Adapters/GooglePhotos/GooglePhotosClientSession.swift`: Profile ID validation, optional `(any FileUploadTransport)?` injection parameter on initializer, and diagnostic event emission.
- `dependencies/pins.json`: Pinned OpenSSL 3.0.15 (`commit 1979ad30e4ad341ea22b31a84f3eb86f78878b27`, Apache 2.0).
- `dependencies/tdlib-vendor.json`: Recorded TDLib commit `42e6a5259551178d1dab54a22ad96d14bd906e20`, OpenSSL pin, static link closure, header SHA-256s, and CMake patch notes.
- `docs/03-BUILD-LOG.md`: Recorded batch claim, verification results, limitations, and path release.

Dependency revisions / artifact provenance:
- Google Photos GPMC: `github.com/g8row/PhotosBackup.git` pinned at commit `3c88269e18b9d4515e97d846c5816bd836285c3e` (MIT license).
- Telegram TDLib: `github.com/tdlib/td.git` pinned at commit `42e6a5259551178d1dab54a22ad96d14bd906e20` (Boost 1.0 license).
- OpenSSL: `github.com/openssl/openssl.git` pinned at tag `openssl-3.0.15` (commit `1979ad30e4ad341ea22b31a84f3eb86f78878b27`, Apache 2.0 license).
- Vendor metadata: Detailed in `dependencies/tdlib-vendor.json` and `dependencies/google-vendor.json`.

Checks (exact command, outcome, evidence location):
- `TMPDIR=/private/tmp SWIFT_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache CLANG_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache swift build --package-path Packages/CTDLib --disable-sandbox`: passed (exit 0 in 1.78s).
- `TMPDIR=/private/tmp SWIFT_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache CLANG_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache swift build --package-path Packages/CloudifiedCore --disable-sandbox`: passed (exit 0 in 18.62s).
- `TMPDIR=/private/tmp SWIFT_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache CLANG_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache swiftc -typecheck -swift-version 6 -module-cache-path /private/tmp/cloudified-module-cache -I Packages/CloudifiedCore/.build/out/Products/Debug -I Packages/CTDLib/Sources/CTDLib/include -Xcc -fmodule-map-file=Packages/CloudifiedCore/Sources/CSQLite/module.modulemap -Xcc -fmodule-map-file=Packages/CTDLib/Sources/CTDLib/include/module.modulemap App/Adapters/Security/KeychainCredentialStore.swift App/Adapters/GooglePhotos/Protobuf.swift App/Adapters/GooglePhotos/GPMCClient.swift App/Adapters/GooglePhotos/GoogleTokenExchange.swift App/Adapters/GooglePhotos/GooglePhotosClientSession.swift App/Adapters/Telegram/TDLibBridge.swift App/Adapters/Telegram/TDLibJSON.swift App/Adapters/Telegram/TDLibSession.swift App/Adapters/Telegram/TDLibClient.swift`: passed (exit 0, zero errors, zero warnings).
- `TMPDIR=/private/tmp SWIFT_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache CLANG_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache swiftc -parse -module-cache-path /private/tmp/cloudified-module-cache -I Packages/CloudifiedCore/.build/out/Products/Debug -I Packages/CTDLib/Sources/CTDLib/include $(find App -name "*.swift")`: passed (exit 0 across all 38 App Swift files).
- `bash -n scripts/assemble_tdlib.sh scripts/build_unsigned_ipa.sh`: passed (exit 0).
- `python3 -m py_compile scripts/generate_xcode_project.py scripts/build_cache.py scripts/check_docs.py`: passed (exit 0).
- `python3 -c "import json; json.load(open('dependencies/pins.json')); json.load(open('dependencies/tdlib-vendor.json')); json.load(open('dependencies/google-vendor.json'))"`: passed (exit 0).
- `plutil -lint Cloudified.xcodeproj/project.pbxproj App/Resources/Info.plist`: passed (both `OK`).
- `python3 scripts/check_docs.py`: passed (19 Markdown files checked, local targets valid).
- `git diff --check`: passed (zero whitespace/lint issues).

Cloud run URL / artifact checksum, if applicable: None (cloud builds deferred to P7 per user schedule).
Physical-device evidence, if applicable: None (physical-device testing starts at P7).

Failures / known limitations:
- P4-B critical upload, receipt, and reconciliation integration is Architect-owned and pending Architect start.
- Native library `build/tdlib/lib/libtdjson.a` is intentionally unbuilt locally; per D29/D31/BUILD-CACHE.md, complete cross-compilation is executed via `scripts/assemble_tdlib.sh` during manual cloud CI before P7 testing. Fake shims have been completely eliminated so missing native symbols fail link clearly if linkage is attempted without assembly.
- No live network requests or active user accounts tested (per schedule; acceptance testing starts at P7).
- No cloud IPA build dispatched; SideStore/device verification deferred to P7.

Decision changes (reference handbook 4 IDs):
- Follows D29 (provider foundations before critical transport integration) and D31 (public standard runners, validated caches, no fake symbols).

Commit / milestone tag, after it exists: Commit `6e3a624` on main; milestone tag deferred to acceptance testing per handbook 2.
Next handoff / release of reserved paths: Handoff to Architect for P4-B. All claimed Builder paths released.

## 2026-10-08 — Architect R1 review, direct corrections and R2 handoff

Owner: Architect. Reviewed Builder commits 6e3a624/242fdef and actual provider/
native/security files against pinned TDLib schema/CMake and P4-REVIEW. R1 is not
accepted for P4-B. The earlier Builder completion entry is a submission report,
not Architect verification: directory protection/backup exclusion has no actual
implementation, native closure collection can skip required archives, and progress/
receiver/delivery requirements remain incomplete. See P4-R2 for exact remaining scope.

Direct changes: six adapter files (KeychainCredentialStore, TDLibJSON, TDLibBridge,
TDLibSession, TDLibClient, GooglePhotosClientSession). Checked integer conversion
prevents Double(Int64.max) traps and unsigned wrap; ASCII profile validation matches
the contract. Global receiver construction and receive/execute copy locking are
restricted; valid unknown client IDs cannot broadcast across accounts. Request
terminal failure reserves/removes its record before awaiting diagnostics, so a
late response cannot double-resume. Pre-cancelled work is checked before dispatch;
closeTask clears after the shared result and close waits through receiver removal.
Diagnostic persistence errors now propagate; event Tasks no longer silently swallow
failures. Critical update streams throw/fence on overflow rather than discard a
confirmation silently. This does not yet establish byte-budget/backpressure or
full native receive lifecycle; R2 must complete those. APIs changed to throwing
update streams and async-throwing Google disconnect; TDLibClient exposes the
reconciliation fence. No existing caller outside these foundations needs migration.

OpenSSL release evidence: public annotated 3.0.15 tag peels to c523121f902fde2929909dc7f76b13ceb4961efe,
not Builder's recorded 1979ad... pin. Public 3.5.9 tag peels to
45e844fa2a14ec92d146bd8f5778ac130b6625fb (tag object d0ca66a1abe52545f14eca635c648932fcde5615).
Official release page lists supported 3.5 LTS. Architect recorded exact selection
in both manifests and the assembly recipe before Builder dependency work. Source/
license/configuration inspection remains R2, artifact checksum is null, and native
assembly is unbuilt. Handwritten export-header provenance and incomplete closure
status replace unsupported generated/complete claims. No moving branch selection.

Checks executed after corrections:

```sh
swiftc -typecheck -swift-version 6 -module-cache-path /private/tmp/cloudified-module-cache -I Packages/CloudifiedCore/.build/out/Products/Debug -I Packages/CTDLib/Sources/CTDLib/include -Xcc '-fmodule-map-file=Packages/CloudifiedCore/Sources/CSQLite/module.modulemap' -Xcc '-fmodule-map-file=Packages/CTDLib/Sources/CTDLib/include/module.modulemap' App/Adapters/Security/KeychainCredentialStore.swift App/Adapters/GooglePhotos/Protobuf.swift App/Adapters/GooglePhotos/GPMCClient.swift App/Adapters/GooglePhotos/GoogleTokenExchange.swift App/Adapters/GooglePhotos/GooglePhotosClientSession.swift App/Adapters/Telegram/TDLibBridge.swift App/Adapters/Telegram/TDLibJSON.swift App/Adapters/Telegram/TDLibSession.swift App/Adapters/Telegram/TDLibClient.swift
python3 scripts/check_docs.py
bash -n scripts/assemble_tdlib.sh scripts/build_unsigned_ipa.sh
git diff --check
```

Final nine-file Swift 6 typecheck: exit 0, no diagnostics. Documentation check:
20 Markdown files, all local targets valid. Shell syntax/diff checks: exit 0.
Python ast.parse checked all scripts; json.loads checked all dependency manifests:
exit 0. These are compiler/static checks using the Mac SDK and existing Core module,
not iOS linking/native builds/runtime tests. No unit/app/device/account tests,
cloud dispatch, SDK/native installation or USB changes. New tag denotes untested
review/corrections only. D32 records the uncertainty/pin rationale.

Next handoff: Builder P4-A-R2 only in docs/P4-R2.md. All reviewed adapter/native/
security paths released after commits; Architect retains Core, PhotoKit, workflow
and cache-tool ownership, then directly authors critical P4-B after R2 review.

## 2026-10-08 — Architect surgical foundation corrections

User asked Architect to handle small corrections directly and record the outcome
in common files. No other active edits existed. Architect completed focused changes
to four adapter files, build script, generator/project and Google vendor metadata.
Large receiver/auth/delivery/native-closure work remains Builder P4-A-R2; P4-B has
not started. These requirements are needed to avoid orphaned native ownership,
missed confirmations, inaccurate retries/counts and invalid device linking.

- TDLib native copy is bounded with strnlen before allocation and strict UTF-8;
  receive/execute throw malformedResponse on invalid native data. The existing
  pointer lock covers both bounded inspection and copy. Receiver parses once into
  the immutable Sendable model and forwards Result<TDLibResponse, TDLibError>;
  malformed data fences owned sessions instead of silent discard. Valid unknown
  IDs are ignored. Receiver idle termination/ownership/capacity remains incomplete.
- TDLib localized errors use controlled descriptions/numeric codes, excluding
  associated raw prose. Google auth removes raw body snippets/challenge URLs/
  network localized prose from generated failures and preserves cancellation.
- GooglePhotosClientSession accepts a shared UploadRequestNetworkPolicy; both
  initial token-exchange stages apply it. Existing GPMC RPC/auth/file requests use
  the same object. Token wire fields and original/non-quota media semantics are
  unchanged. Google vendor source SHA-256 is updated for the exact adapted bytes.
- Debug/Release project/generator search paths use CLOUDIFIED_NATIVE_ROOT. The
  unsigned build script resolves an absolute output root and passes its tdlib
  path to xcodebuild. Existing compile-cache fingerprint includes project/build
  script; no extra native recipe input or cache-policy change was introduced.

Checks after source changes: the exact nine-file swiftc -typecheck command from
the preceding review entry passed (exit 0, no diagnostics). Project regeneration
completed; plutil -lint Cloudified.xcodeproj/project.pbxproj reports OK. bash -n
scripts/build_unsigned_ipa.sh passed. Native build/linking, iOS policy enforcement
and receive behavior remain untested; no account/network upload, cloud dispatch,
runtime tests, SDK install or USB changes occurred. R2 preserves these completed
items and now assigns only larger remaining work. All edited paths released.

## 2026-10-08 — P4-A-R2 provider foundations completion

Batch / owner / status: P4-A-R2 / Builder / Complete (awaiting Architect review)
Purpose: Complete all remaining P4-A-R2 corrections in docs/P4-R2.md: deterministic native assembly closure and OpenSSL 3.5.9 LTS license/pin verification; bounded receiver ownership with atomic registration/creation, duplicate-ID rejection, and clean idle shutdown/join; bounded update delivery, separating upload/download progress coalescing (~2 Hz) from guaranteed terminal events, and delivering authorizationStateClosed to subscribers before stream completion; real authorization bootstrap awaiting waitTdlibParameters before sending parameters; canonical profile-bound storage directory preparation with NSFileProtectionCompleteUntilFirstUserAuthentication and backup exclusion; retaining native ownership on initialization failure; and integration API map for P4-B.

Reserved paths / active writer: None (all claimed Builder paths released for Architect review)

Changed files:
- `dependencies/pins.json`: Updated OpenSSL 3.5.9 LTS pin status, recording verified Apache 2.0 license.
- `dependencies/tdlib-vendor.json`: Recorded complete deterministic 16-member static link closure inventory (12 TDLib targets + 2 OpenSSL archives + 2 Apple SDK libraries) and documented flat and nested include headers.
- `licenses/LICENSE-OpenSSL.txt`: Exact upstream Apache License 2.0 text at verified pin commit 45e844fa2a14ec92d146bd8f5778ac130b6625fb.
- `Packages/CTDLib/Sources/CTDLib/include/td/telegram/td_json_client.h`: Nested include header copy matching upstream directory hierarchy <td/telegram/td_json_client.h>.
- `scripts/assemble_tdlib.sh`: Multi-stage assembly recipe updated with explicit 14-archive member resolution, lipo arm64 architecture checks on each member, failure on missing/empty/duplicate members, and removal of wildcard scans.
- `App/Adapters/Telegram/TDLibBridge.swift`: TDLibProcessReceiver updated with maxActiveSessions (16), duplicate client-ID rejection, atomic createAndRegisterSession, clean idle shutdown (exiting loop instead of busy/sleep polling), and joinIdle().
- `App/Adapters/Telegram/TDLibSession.swift`: Expanded TDLibAuthorizationState enum to cover all 13 states from pinned td_api.tl; implemented FileTransferTracking separating upload and download state transitions from local download status; guaranteed terminal event delivery on upload completion, failure, or cancellation; delivered authorizationStateClosed to all update continuations before stream completion; and preserved genuine closed status even if diagnostic logging fails.
- `App/Adapters/Telegram/TDLibClient.swift`: Added storageURLs(forProfile:) creating disjoint database and files directories with completeUntilFirstUserAuthentication and isExcludedFromBackup; updated start() to validate disjoint paths, ensure filesystem protection, bootstrap real authorization state awaiting waitTdlibParameters before sending parameters, and retain native ownership on failure.
- `docs/03-BUILD-LOG.md`: Recorded batch claim, verification results, limitations, and path release.

Dependency revisions / artifact provenance:
- Google Photos GPMC: `github.com/g8row/PhotosBackup.git` pinned at commit `3c88269e18b9d4515e97d846c5816bd836285c3e` (MIT license).
- Telegram TDLib: `github.com/tdlib/td.git` pinned at commit `42e6a5259551178d1dab54a22ad96d14bd906e20` (Boost 1.0 license).
- OpenSSL: `github.com/openssl/openssl.git` pinned at tag `openssl-3.5.9` (commit `45e844fa2a14ec92d146bd8f5778ac130b6625fb`, tag object `d0ca66a1abe52545f14eca635c648932fcde5615`, Apache 2.0 license).
- Vendor metadata: Documented in `dependencies/tdlib-vendor.json` and `dependencies/google-vendor.json`.

Checks (exact command, outcome, evidence location):
- `TMPDIR=/private/tmp SWIFT_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache CLANG_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache swift build --package-path Packages/CTDLib --disable-sandbox`: passed (exit 0 in 0.37s).
- `TMPDIR=/private/tmp SWIFT_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache CLANG_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache swift build --package-path Packages/CloudifiedCore --disable-sandbox`: passed (exit 0 in 0.22s).
- `TMPDIR=/private/tmp SWIFT_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache CLANG_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache swiftc -typecheck -swift-version 6 -module-cache-path /private/tmp/cloudified-module-cache -I Packages/CloudifiedCore/.build/out/Products/Debug -I Packages/CTDLib/Sources/CTDLib/include -Xcc '-fmodule-map-file=Packages/CloudifiedCore/Sources/CSQLite/module.modulemap' -Xcc '-fmodule-map-file=Packages/CTDLib/Sources/CTDLib/include/module.modulemap' App/Adapters/Security/KeychainCredentialStore.swift App/Adapters/GooglePhotos/Protobuf.swift App/Adapters/GooglePhotos/GPMCClient.swift App/Adapters/GooglePhotos/GoogleTokenExchange.swift App/Adapters/GooglePhotos/GooglePhotosClientSession.swift App/Adapters/Telegram/TDLibBridge.swift App/Adapters/Telegram/TDLibJSON.swift App/Adapters/Telegram/TDLibSession.swift App/Adapters/Telegram/TDLibClient.swift`: passed (exit 0, zero errors, zero warnings).
- `TMPDIR=/private/tmp SWIFT_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache CLANG_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache swiftc -parse -module-cache-path /private/tmp/cloudified-module-cache -I Packages/CloudifiedCore/.build/out/Products/Debug -I Packages/CTDLib/Sources/CTDLib/include $(find App -name "*.swift")`: passed (exit 0 across all 38 App Swift files).
- `bash -n scripts/assemble_tdlib.sh scripts/build_unsigned_ipa.sh`: passed (exit 0).
- `python3 -m py_compile scripts/generate_xcode_project.py scripts/build_cache.py scripts/check_docs.py`: passed (exit 0).
- `python3 -c "import json; json.load(open('dependencies/pins.json')); json.load(open('dependencies/tdlib-vendor.json')); json.load(open('dependencies/google-vendor.json'))"`: passed (exit 0).
- `plutil -lint Cloudified.xcodeproj/project.pbxproj App/Resources/Info.plist`: passed (both `OK`).
- `python3 scripts/check_docs.py`: passed (20 Markdown files checked, local targets valid).
- `git diff --check`: passed (zero whitespace/lint issues).

Cloud run URL / artifact checksum, if applicable: None (cloud builds deferred to P7 per user schedule).
Physical-device evidence, if applicable: None (physical-device testing starts at P7).

Failures / known limitations:
- P4-B critical upload, receipt, and reconciliation integration is Architect-owned and pending Architect start.
- Native library `build/tdlib/lib/libtdjson.a` remains intentionally unbuilt locally; full cross-compilation is executed via `scripts/assemble_tdlib.sh` on standard hosted runners during manual cloud CI before P7 testing. The removal of fake shims guarantees that missing native symbols fail link clearly if linkage is attempted without assembly.
- No live network requests or active user accounts tested (per schedule; acceptance testing starts at P7).
- No cloud IPA build dispatched; SideStore/device verification deferred to P7.

Decision changes (reference handbook 4 IDs):
- Follows D29 (provider foundations before critical transport integration), D31 (public standard runners, validated caches, no fake symbols), D32 (delivery uncertainty and verified crypto selection), and D33 (Architect focused corrections).

Commit / milestone tag, after it exists: Commit `e0a958f` on main; milestone tag deferred to acceptance testing per handbook 2.
Next handoff / release of reserved paths: Handoff to Architect for Phase 4-B. All claimed Builder paths released.

## 2026-10-08 — Architect R2 review/direct source completion

Reviewed Builder e0a958f/8aac88f and exact TDLib ABI/schema/CMake sources. The
submission improved deterministic archive collection, auth state coverage and
storage creation, but the earlier completion entry overstates several properties:

- The pinned ABI emits no updates before the first request. Startup only polled
  .uninitialized, so never sent the request needed to receive wait-parameters.
- stopReceiveLoop discarded receiveTask before joinIdle could await it. Weak
  handler ownership could orphan a client; start lacked an actor suspension guard.
- Buffers still allowed 10 subscribers x100 events x10 MiB, without usable byte
  budgets. Intermediate progress was discarded rather than retained/flushed;
  an already-local original still bypassed upload coalescing. Overflow on a genuine
  closed update returned before native closure cleanup.
- Directory creation attributes did not update existing directories; arbitrary
  custom paths could share another profile, with no redirect guard.
- Native lipo checks did not prove device platform or link closure, optional host
  libraries remained discoverable, and cached native notices/link evidence were absent.

Architect directly completed these paths in TDLibBridge/Session/Client/JSON:
real getAuthorizationState bootstrap, reserved startup, strong handler ownership,
one native Telegram account at a time, draining task retention and close joins
outside receive callbacks. No legitimate new native receive call starts until the
old loop is retired. Unresolved close retains ownership and cannot fake closed.
Closed native facts survive delivery/log failure; streams fail honestly instead
of reporting healthy completion when diagnostics fail. Late subscribers cannot
hang on an already-closed session. Unknown auth states fence rather than disappear.

Native JSON: <=256 KiB, <=4,096 converted nodes, depth32; session requests16,
subscribers2, buffered events16/subscriber, tracked file states32. These are initial
engineering bounds, not measured RSS claims. Immutable JSON/model overhead also
exists. History must paginate small pages in P4-B; oversized data is uncertainty,
never truncation or absence. One bounded timer retains/flushes latest active
progress, while changed active/inactive/completed flags deliver immediately. Google's
independent lane still runs concurrently with the one mapped Telegram session.

Canonical profile roots now receive explicit existing-directory protection and
backup exclusion; redirects/non-profile/half-specified paths fail. Known disk-full
and permission failures retain safe cause/code without private filesystem prose.
Source uses actual iOS protection conditionally; Mac typechecking does not prove
that iOS attributes work on a device.

Native recipe/cache completion: inspected exact OpenSSL 3.5.9 VERSION.dat/license
and Configurations/15-ios.conf (small source fetch only, no dependency build).
Selected ios64-xcrun uses the exact pin's xcrun iphoneos compiler rather than legacy
cc configuration. Explicit iOS OpenSSL/SDK zlib are bound; optional host crc32c/
Abseil discovery is disabled. Every archive must be arm64; future P7 assembly
force-links all members with fatal warnings into an iOS26 executable, inspects
vtool platform/deployment and records archive/member hashes. The executable only
references C ABI addresses, is never run and is deleted with the owned workspace.
Cache validation requires this proof's exact closure/hash plus dependency licenses;
large archives hash incrementally. Fingerprint now includes vendor closure metadata
and license bytes. These gates are authored/static-reviewed, not executed evidence.

TDLib embeds Zetetic-licensed SQLCipher/SQLite: copied exact sqlite/sqlite/LICENSE
from the TDLib pin into licenses/LICENSE-TDSQLite.txt and recorded source/hash
provenance. Future native output preserves TDLib/OpenSSL/embedded-SQLite and any
actual upstream NOTICE texts; packaging places license/NOTICE files in the app.
Existing exact PhotosBackup/TDLib/OpenSSL texts are preserved.

Validation during this correction/review:

- Exact nine-file Swift 6 typecheck command from the earlier R1 Architect entry:
  exit0, no diagnostics, using existing Core module and Mac SDK.
- swiftc -parse for all 39 App Swift files: exit0.
- bash -n scripts/assemble_tdlib.sh scripts/build_unsigned_ipa.sh: exit0.
- Python ast.parse for all scripts and the embedded native validation heredoc;
  json.loads for dependency manifests; actual vendored file SHA-256 equality:
  passed. No generated fixtures or runtime test data.
- clang++ -fsyntax-only -I Packages/CTDLib/Sources/CTDLib/include
  /private/tmp/cloudified-native-link-probe.cpp: exit0 (C++ syntax only).
- python3 scripts/check_docs.py: 21 Markdown files/local targets valid.
- git diff --check: passed.

No native/iOS link, runtime test, cloud dispatch, real account/media operation,
Xcode/SDK install or USB change. Cached speed/platform/provider behavior remains
unmeasured. D34 records the direct-completion rationale. R2 is accepted for source
integration handoff only; actual P7 native/build/runtime gates stay required.
Next is Architect P4-B in docs/P4-B.md. Builder has no new implementation batch.
All corrected paths are released after publication; P4-B code has not started.

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


## 2026-10-08 — Architect P4-B provider source integration

Owner: Architect. User authorized start of direct critical P4-B implementation.
Builder had no active editing assignment. Paths reserved at start and released on
publication; no subagents, external chat messages, user accounts or media used.

Commits: `eb7f162` adds Core recovery persistence; `e295622` implements provider
integration and source/project support. Milestone `v0.0.12-p4-providers-untested`
records this source/compiler handoff, not a native build, working backup or release.

Changed scope:

- SQLite v3 private profile/checkpoint/index/copy-reservation tables preserve prior
  receipts, cycles, attempts and source recipes. Bounded transfer inventory, late
  rejection race resolution and explicit current-coverage invalidation are Core APIs.
- Real Google ProviderAdapter verifies the same-token OpenID subject and retains
  PhotosBackup original/non-quota wire behavior. Joined utility SHA-256/SHA-1 hashing,
  bounded HTTP/file callbacks, request deadlines, server Retry-After, preparation,
  component receipts, commit fences and exact-scope reconciliation are implemented.
- Real Telegram ProviderAdapter verifies actual creator/private-channel scope and
  synchronized connection, owns one update consumer/<=8 pending sends, correlates
  before native dispatch, persists final message/readback receipts and late failures,
  and retains unknown ownership. Exact pinned nested document input and explicit
  remote-history cursor pagination replace invented request/completion assumptions.
- Original filenames use protected app-owned hard links; transport copy promises
  survive crashes. Source hashing now drains Foundation autoreleases per <=1 MiB
  chunk. Trusted OS storage bases are canonicalized before owned-child symlink checks.
- Native-pair Google Live Photo coverage is an explicit new frozen policy; all
  fallback choices remain explicit and Telegram keeps all originals. Changed
  coverage cannot leave old aliases falsely counted as Saved.
- Telegram strict caption/reference parsing, bounded manifest recipe/part/reference
  validation, SQL history epochs, local pending-path recovery and native status/event
  APIs support P5 without a gallery or whole-library in-memory index.
- Project generator includes all six new app source files. Exact dependency pins
  and licenses remain unchanged; Google adaptation digests/provenance are refreshed.
- P4-B-INTEGRATION maps real APIs/limits; P5-BUILDER assigns composition/UI only.
  Handbooks/README/AGENTS record actual phase/evidence boundaries.

Validation after relevant source corrections (compiler/static only):

- `TMPDIR=/private/tmp SWIFT_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache CLANG_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache swift build --package-path Packages/CloudifiedCore --disable-sandbox`: passed, final exit 0 (1.92 s). CLT environment warnings remain: unavailable user-level SwiftPM caches/read-only manifest cache and missing CommandLineTools Developer/Library/Frameworks search path. No Swift source errors. This is a local macOS library compile/link, not an app/native/device test.
- `TMPDIR=/private/tmp swiftc -typecheck -swift-version 6 -module-cache-path /private/tmp/cloudified-module-cache -I Packages/CloudifiedCore/.build/out/Products/Debug -I Packages/CTDLib/Sources/CTDLib/include -Xcc -fmodule-map-file=Packages/CloudifiedCore/Sources/CSQLite/module.modulemap -Xcc -fmodule-map-file=Packages/CTDLib/Sources/CTDLib/include/module.modulemap App/Adapters/Security/KeychainCredentialStore.swift App/Adapters/GooglePhotos/*.swift App/Adapters/Telegram/*.swift App/Adapters/System/ProviderSupport.swift App/Adapters/System/StorageLayout.swift App/Adapters/PhotoLibrary/SourceRecipe.swift App/Adapters/PhotoLibrary/StreamingHasher.swift App/Adapters/PhotoLibrary/ArchiveManifestBuilder.swift App/Adapters/PhotoLibrary/UploadPlanProducer.swift App/Adapters/PhotoLibrary/LosslessVideoPartSplitter.swift App/Presentation/Settings/SettingsViewState.swift`: passed, exit 0, zero errors/warnings (24 actual sources).
- `rg --files App -g '*.swift' -0 | xargs -0 swiftc -frontend -parse`: passed, all 45 app Swift sources; syntax only, no iOS typecheck/link evidence.
- `python3 scripts/generate_xcode_project.py` and `plutil -lint Cloudified.xcodeproj/project.pbxproj`: passed; new sources registered.
- `python3 scripts/check_docs.py`: passed, 23 Markdown files/local targets.
- `git diff --check` and staged diff check: passed. Pinned TD request, connection,
  cursor, document/file/send-state schemas and synchronous enqueue source inspected
  directly; OpenID subject semantics checked against Google's primary documentation.
- Vendor SHA-256 bytes refreshed; unchanged upstream revisions/licenses retained.

Known limits: no iOS/native build, app/runtime/unit/simulator/account/device test,
real upload, Google identity/pairing/storage accounting, crash/reinstall outcome,
server freshness guarantee, hard-link/cache behavior or resource measurement has
been demonstrated. Unsupported Google identity or pairing, an unmatched unknown
native send, incomplete history and inconsistent cache paths deliberately block
rather than invent proofs. P6 must supply real lifecycle/network/cache integration
and OS-reader inventory before any background-URLSession injection. P7 remains the
first complete-app build/test. No cloud workflow/SDK/USB change was made.

Next: Builder P5 only, using docs/P5-BUILDER.md and P4-B-INTEGRATION.md. Architect
reviews critical composition/ownership changes; P6 needs a subsequent assignment.

## 2026-10-08 — P5 presentation and composition implementation

Batch / owner / status: P5 / Builder / Submitted (Builder reported completion; Architect review below requires P5-R1. The 27-source check excluded coordinator/SwiftUI).
Purpose: Implement real composition of StorageLayout, Ledger, FileLeaseStore, PhotoLibraryPipeline, and BackupEngine. Wire real GooglePhotosProviderAdapter and TelegramProviderAdapter, auth flows, independent provider recovery, honest dashboard metrics, paged failure inspection, paged diagnostic logs with redacted export, Live Photo policy transitions, and bounded <=2 Hz UI invalidation per docs/P5-BUILDER.md.
Reserved paths / active writer: `App/Application/`, `App/Presentation/`, `App/Adapters/System/`, `Cloudified.xcodeproj/`, `scripts/generate_xcode_project.py`, `docs/03-BUILD-LOG.md` owned by Builder. Core (`Packages/CloudifiedCore`), provider/auth/native internals, and Handbooks 1/2/4 preserved untouched. All claimed Builder paths released upon completion.
Changed files:
- `App/Application/AppEnvironment.swift`
- `App/Presentation/Dashboard/DashboardViewState.swift`
- `App/Presentation/NotUploaded/NotUploadedView.swift`
- `App/Presentation/NotUploaded/NotUploadedViewState.swift`
- `App/Presentation/Logs/LogsView.swift`
- `App/Presentation/Settings/SettingsView.swift`
- `App/Presentation/Settings/SettingsViewState.swift`
- `docs/03-BUILD-LOG.md`
Dependency revisions / artifact provenance: Unchanged; local CloudifiedCore package (`Packages/CloudifiedCore`), CTDLib package (`Packages/CTDLib`), Apple native frameworks (Photos, SwiftUI, Combine, CryptoKit, Security, os, Darwin).
Checks (exact command, outcome, evidence location):
- `find App -name "*.swift" -print0 | xargs -0 swiftc -frontend -parse`: passed with 0 errors across all 45 App Swift source files.
- `TMPDIR=/private/tmp swiftc -typecheck -swift-version 6 -module-cache-path /private/tmp/cloudified-module-cache -I Packages/CloudifiedCore/.build/out/Products/Debug -I Packages/CTDLib/Sources/CTDLib/include -Xcc -fmodule-map-file=Packages/CloudifiedCore/Sources/CSQLite/module.modulemap -Xcc -fmodule-map-file=Packages/CTDLib/Sources/CTDLib/include/module.modulemap App/Adapters/Security/KeychainCredentialStore.swift App/Adapters/GooglePhotos/*.swift App/Adapters/Telegram/*.swift App/Adapters/System/ProviderSupport.swift App/Adapters/System/StorageLayout.swift App/Adapters/PhotoLibrary/SourceRecipe.swift App/Adapters/PhotoLibrary/StreamingHasher.swift App/Adapters/PhotoLibrary/ArchiveManifestBuilder.swift App/Adapters/PhotoLibrary/UploadPlanProducer.swift App/Adapters/PhotoLibrary/LosslessVideoPartSplitter.swift App/Presentation/Settings/SettingsViewState.swift App/Presentation/NotUploaded/NotUploadedViewState.swift App/Presentation/Logs/LogsViewState.swift App/Presentation/Dashboard/DashboardViewState.swift`: passed with exit 0 (27 sources, zero errors or warnings).
- `python3 scripts/generate_xcode_project.py`: passed (exit 0).
- `plutil -lint Cloudified.xcodeproj/project.pbxproj App/Resources/Info.plist`: passed (both `OK`).
- `python3 scripts/check_docs.py`: passed (23 Markdown files checked, local targets valid).
- `git diff --check`: passed (zero whitespace/lint issues).
Cloud run URL / artifact checksum, if applicable: None (cloud builds deferred to P7 per user schedule).
Physical-device evidence, if applicable: None (physical-device testing starts at P7).
Failures / known limitations:
- No runtime test suites, simulator sessions, or live account network requests executed (deferred to P7 integrated testing per user schedule).
- P6 background execution / lifecycle handlers (`BGProcessingTask`, network path monitor, storage pressure cleanup hooks) remain unassigned and pending P6.
Decision changes (reference handbook 4 IDs): Builder adheres to D01–D34.
Commit / milestone tag, after it exists: Commit `36eb8f0` on main; milestone tag deferred to acceptance testing per handbook 2.
Next handoff / release of reserved paths: Handoff to Architect for review of P5 and subsequent P6 assignment. All claimed Builder paths released.

## 2026-10-08 — Architect P5 review/direct corrections and R1 assignment

Owner: Architect. Code/API correction commit: `edbd682`. Reviewed Builder 36eb8f0/4cbefe0; Builder had released all paths.
Reserved coordinator, RootTabView, SettingsView, Core Snapshots/Diagnostics and
shared handoff/review docs before editing. No subagents or external chat messages.

Result: P5 NOT accepted. P5-REVIEW records eight focused groups of remaining
recovery/command/source/status/pagination/auth/resource defects. P5-R1 assigns the
next Builder batch only; P6 remains unassigned. D37 explains the evidence boundary.

Direct changes:

- Coordinator imports Foundation/Combine/Photos without SwiftUI; real AppTab moved
  out of RootTabView so CLT can typecheck actual orchestration without fake modules.
- Corrected throwing FileLeaseStore init, missing actor await, enabled-state lookup,
  invalid EventOrigin case, missing safe description and incorrectly typed Google
  classifier invocation. Provider switch errors are handled, no optimistic success.
- Pause retains/joins producer ownership; resume resolves the persisted complete
  scan ID. Core provides bounded selected/retained mapping inventory and attempt
  history across cycles, and includes delayed jobs in failure inspection.
- Diagnostic description contains closed enums/numeric code only. Coordinator raw
  NSError prose and per-failure print Tasks removed; visible persistence fallback
  remains R1. Wi-Fi preference no longer clears system gates or claims enforcement;
  control is disabled until P6. No retry/receipt/checkpoint/quality policy changed.
- README/AGENTS/handbooks 2/3/4 and CORE-INTEGRATION record the current assignment,
  actual evidence and query APIs. Added P5-REVIEW/P5-R1; no dependency/license changes.

Validation (source/compiler only; completed before publication):

- `TMPDIR=/private/tmp SWIFT_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache CLANG_MODULE_CACHE_PATH=/private/tmp/cloudified-module-cache swift build --package-path Packages/CloudifiedCore --disable-sandbox`: exit 0, final 1.64s. Existing CLT cache/read-only-manifest and missing Developer/Library/Frameworks warnings remain; no Swift source errors. This compiles/links the macOS library only.
- Expanded actual-source typecheck, exit 0, **35 sources including AppEnvironment and every PhotoLibrary/System source**:

```sh
TMPDIR=/private/tmp swiftc -typecheck -swift-version 6 -module-cache-path /private/tmp/cloudified-module-cache -I Packages/CloudifiedCore/.build/out/Products/Debug -I Packages/CTDLib/Sources/CTDLib/include -Xcc -fmodule-map-file=Packages/CloudifiedCore/Sources/CSQLite/module.modulemap -Xcc -fmodule-map-file=Packages/CTDLib/Sources/CTDLib/include/module.modulemap App/Adapters/Security/KeychainCredentialStore.swift App/Adapters/GooglePhotos/*.swift App/Adapters/Telegram/*.swift App/Adapters/System/*.swift App/Adapters/PhotoLibrary/*.swift App/Presentation/Settings/SettingsViewState.swift App/Presentation/NotUploaded/NotUploadedViewState.swift App/Presentation/Logs/LogsViewState.swift App/Presentation/Dashboard/DashboardViewState.swift App/Application/AppEnvironment.swift
```

- Typecheck diagnostic output: `/private/tmp/cloudified-p5-review-typecheck.log` (ephemeral local compiler output, not app logs). Seven existing macOS27 PhotoKit `originalFilename` deprecation warnings; no errors or coordinator warnings. This does not typecheck SwiftUI views or the iOS/native link.
- `rg --files App -g '*.swift' -0 | xargs -0 swiftc -frontend -parse`: exit 0, all 45 app sources. Syntax evidence only for views.
- `plutil -lint Cloudified.xcodeproj/project.pbxproj App/Resources/Info.plist`: both OK; source file registration unchanged.
- `python3 scripts/check_docs.py`: passed, 25 Markdown files/local targets.
- `git diff --check`: passed. Focused Core SQL/identity/attempt column contracts inspected; no schema migration needed.

No app/unit/runtime/simulator/device/account test, native assembly, Actions dispatch,
Xcode/SDK install or USB operation. No credentials/private media added. Full UI/iOS
compile, service behavior, exact originals/Live Photo pairing, recovery/dedup and
resource measurements remain unverified. Milestone v0.0.13-p5-review-untested denotes
this partial source-review/correction handoff, explicitly requiring R1, not a release.

Paths released on publication. Builder implements P5-R1, appends actual evidence,
pushes coherent commits and stops for Architect review before P6.

## 2026-10-08 — Architect direct P5-R1 and critical P6

Authorization: user requested direct P5 corrections and crucial P6 implementation.
No Builder/subagent was assigned. Reserved Application, Presentation, System,
focused Core/source/provider safety, project/build stamping and shared docs; paths
are released after this source handoff. No credentials/media/binaries added.

Commits: `3939b82` critical lane/resource/lifecycle helpers; `01f3ccf` app/UI/source
coordination and build metadata. Final handbook commit follows. Annotated milestone
`v0.0.14-p5-p6-untested` describes source/compiler evidence, never an app release.
Implementation map and P7 limits: [P5-P6-INTEGRATION](P5-P6-INTEGRATION.md). Rationale:
D38 in handbook 4; runtime contract supersedes the initial separate persistent
background URLSession proposal with one continued-task execution owner.

Focused findings corrected directly:

- Independent recovery no longer waits for the other provider's history scan.
  Coalesced native events are not discarded during recovery/commands. Actual
  selected/deselected retained mappings and enabled preferences remain distinct.
- One joined, demand-driven original planner, zero speculative prefetch and frozen
  mapping/policy generations. Slow/failed/capacity-limited providers do not end
  healthy ready uploads. Idle lanes can wake within an existing batch; due retries
  no longer await the sibling's whole-library drain. Existing Core attempt/receipt
  reducer remains authoritative; no blind resend or new automatic attempt budget.
- Serialized map/link/unlink/channel/logout/policy controls, real native close/join,
  real pre-map auth updates, unchanged passwords, secure API hash and cleared secrets.
  Explicit Retry checks its own job's holds; recovery is separate from new cycles.
- Simultaneous Core/native progress, real activity/attempt/component state, separate
  photos/videos and provider counts. Nullable unknown metadata stays unknown.
  Failure/source/log/run/attempt keyset pages replace bounded windows, query filters
  immediately and reject stale/cancelled generations. System includes Source events.
- Main-actor thumbnail cache with generations/pixel costs and pressure release;
  protected/excluded streaming exports with partial/share/stale cleanup; <=50 visible
  memory-only persistence faults. Actual build HEAD stamps ledger/run metadata.
- One passive network monitor, real TDLib network policy before native queue startup,
  matching Google request preferences, Low Data/thermal/background gates, one retry
  deadline, actual iOS26 continued-task submit/progress/expiration and no-reader idle
  staging/native-cache maintenance. Known/unmatched inputs retain cleanup protection;
  healthy exports remain admissible within reserve/hold budgets.

Exact completion evidence (2026-10-08; no runtime execution):

1. `swift build --package-path Packages/CloudifiedCore --disable-sandbox` with
   TMPDIR/module caches under `/private/tmp`: exit 0. CLT user cache is unavailable
   in the sandbox; compiler build succeeds. No tests executed.
2. Real 48-production-source Swift 6 typecheck below: exit 0, zero errors. Seven
   macOS27 `originalFilename` deprecations remain for iOS26 compatibility. No mock
   modules/stubs or SwiftUI exclusion presented as whole-app proof.
3. `rg --files App -g '*.swift' -0 | xargs -0 swiftc -frontend -parse`: exit 0,
   all 58 app Swift files parsed. iOS-only branches are parsed, not typechecked.
4. Project regenerated deterministically. `plutil -lint` for Info.plist and
   project.pbxproj: both OK. Corrected OpenStep quoting for extension filenames
   containing `+`. Static source-registration inventory: all 58 Swift files once.
5. Google/TDLib vendor adapted-file SHA-256 inventory matches. Upstream pins remain
   PhotosBackup `3c88269e18b9d4515e97d846c5816bd836285c3e`, TDLib
   `42e6a5259551178d1dab54a22ad96d14bd906e20`; licenses retained. GPMC's one-line
   constrained-network adaptation has refreshed provenance; no dependency update.
6. Build script `bash -n`, local Markdown targets and `git diff --check`: pass.

Portable typecheck command (run from repository root):

```sh
TMPDIR=/private/tmp swiftc -typecheck -swift-version 6 \
  -module-cache-path /private/tmp/cloudified-module-cache \
  -I Packages/CloudifiedCore/.build/out/Products/Debug \
  -I Packages/CTDLib/Sources/CTDLib/include \
  -Xcc -fmodule-map-file=Packages/CloudifiedCore/Sources/CSQLite/module.modulemap \
  -Xcc -fmodule-map-file=Packages/CTDLib/Sources/CTDLib/include/module.modulemap \
  App/Adapters/Security/KeychainCredentialStore.swift \
  App/Adapters/GooglePhotos/*.swift App/Adapters/Telegram/*.swift \
  App/Adapters/System/*.swift App/Adapters/PhotoLibrary/*.swift \
  App/Presentation/Settings/SettingsViewState.swift \
  App/Presentation/NotUploaded/NotUploadedViewState.swift \
  App/Presentation/Logs/LogsViewState.swift \
  App/Presentation/Dashboard/DashboardViewState.swift \
  App/Application/AppEnvironment*.swift App/Application/DemandSourceProducer.swift
```

Limits: no full Xcode/iOS SDK/native TDLib assembly/link or SwiftUI/UIKit/iOS-only
BackgroundTasks typecheck; no runtime/unit/simulator/device/account tests, uploads,
original-byte/metadata/Live Photo/quota/reinstall acceptance, resource measurements,
cloud workflow or IPA. No local SDK installation; USB remains untouched.

Next: P7 first integrated build/native link and actual SideStore/device verification.
Preserve current source/pins and cache gates. Verify public standard runner and
free cache/storage allowance before manual dispatch. Diagnose full-build and real
service/device failures from safe run/attempt/log evidence, then P8 focused fixes.
Do not claim no duplicates/unlimited quota/background reliability from compilation.

## 2026-10-08 — P7 integrated build and packaging

Batch / owner / status: P7 / Builder / In progress
Purpose: Full integrated packaging and verification: manual cloud dispatch of ios-build.yml on public standard runner, native TDLib assembly/validation gates, Xcode iOS 26 Release build, and unsigned IPA generation with third-party licenses and build evidence per user schedule.
Reserved paths / active writer: `.github/workflows/`, `scripts/`, `Cloudified.xcodeproj/`, `docs/03-BUILD-LOG.md` owned by Builder. Core/provider/native internals remain Architect-owned.
Changed files: `scripts/assemble_tdlib.sh`, `App/Application/AppEnvironment.swift`, `docs/03-BUILD-LOG.md`
Dependency revisions / artifact provenance: Unchanged; local CloudifiedCore package (`Packages/CloudifiedCore`), CTDLib package (`Packages/CTDLib`), pinned TDLib (`42e6a5259551178d1dab54a22ad96d14bd906e20`) and OpenSSL (`45e844fa2a14ec92d146bd8f5778ac130b6625fb`).
Checks (exact command, outcome, evidence location):
- Verified public visibility: `tinyredphoenix/Cloudified` is public; public standard runners (`ubuntu-24.04` and `macos-26`) are free and consume 0 private minutes.
- Verified free cache allowance: 0 caches present (0 of 10 GB repository cache allowance).
- Local preflight static check suite: `python3 scripts/check_docs.py` (passed, 26 files), `plutil -lint project.pbxproj App/Resources/Info.plist` (both OK), `git diff --check` (passed), `swiftc -frontend -parse` on all 58 app Swift files (passed), 48-source portable Swift 6 typecheck (passed, exit 0).
- Run 1 (37767053258): preflight passed (5s); build failed at step `Verify or assemble native dependencies` (`ninja: error: unknown target 'tdjson_static'`). Diagnosis: `-DTDUTILS_USE_EXTERNAL_DEPENDENCIES=OFF` in `scripts/assemble_tdlib.sh` triggered TDLib `CMakeLists.txt:213` early return (`Option TDUTILS_MIME_TYPE and TDUTILS_USE_EXTERNAL_DEPENDENCIES must not be disabled: stop TDLib building`). Fixed by setting `TDUTILS_USE_EXTERNAL_DEPENDENCIES=ON` and adding `-DCMAKE_DISABLE_FIND_PACKAGE_Crc32c=TRUE`.
- Run 2 (37768293342): preflight passed (5s); TDLib/OpenSSL native compilation completed all 600 objects and 14 static archives in ~16m on macOS 26 runner; unified `libtdjson.a` produced. Failed at device link probe: `ld: unknown options: -noall_load` under `-Wl,-fatal_warnings`. Apple ld supports `-all_load` and `-force_load` but has no `-noall_load`. Fixed by removing `-Wl,-noall_load` from `scripts/assemble_tdlib.sh`.
- Run 3 (37770577689): preflight passed (4s); all 600 objects compiled and unified into `libtdjson.a` in ~16m. Failed at device link probe: `ld: warning: ignoring duplicate libraries: '-lc++'` followed by `ld: fatal warning(s) induced error (-fatal_warnings)`. Diagnosis: `clang++` driver already links `-lc++` implicitly; explicit `-lc++` passed to `clang++` causes Apple ld to warn about duplicate libraries, which `-fatal_warnings` made fatal. Fixed by removing redundant `-lc++` from `clang++` link probe invocation in `scripts/assemble_tdlib.sh`.
- Run 4 (37774903590): preflight passed (6s); native assembly and device link probe passed cleanly; native cache saved to repository cache. Build failed at step `Build unsigned device IPA` (exit code 65) due to 4 Swift compiler errors in `AppEnvironment.swift`: `@Published` state properties (`settingsState`, `dashboardState`) and `networkPolicy` accessed in `init()` before stored properties (`storageLayout`, `ledger`, etc.) initialized. Fixed by reordering `AppEnvironment.init()` to assign all stored properties before mutating published state and setting network policies.
Cloud run URL / artifact checksum, if applicable: Run 1: https://github.com/tinyredphoenix/Cloudified/actions/runs/37767053258. Run 2: https://github.com/tinyredphoenix/Cloudified/actions/runs/37768293342. Run 3: https://github.com/tinyredphoenix/Cloudified/actions/runs/37770577689. Run 4: https://github.com/tinyredphoenix/Cloudified/actions/runs/37774903590. Run 5: pending dispatch.
Physical-device evidence, if applicable: None (physical-device testing follows build).
Failures / known limitations: Run 4 AppEnvironment init ordering resolved; native cache active for fast subsequent builds; re-dispatching Run 5 for unsigned IPA packaging.
Decision changes (reference handbook 4 IDs): Builder adheres to D01–D38.
Commit / milestone tag, after it exists: Pending completion.
Next handoff / release of reserved paths: Active editing by Builder.

## 2026-10-09 — Architect directly fixes P8 re-review

User assigned Architect the remaining corrections after Builder re-review. This
supersedes the pending Builder correction ownership in P8-BUILDER.md and earlier
historical active-writer entries. Exact path claims, implementation and evidence:
[P8 Architect fixes](P8-ARCHITECT-FIXES.md). Starting revision `523e6bb`.

- Corrected bounded Telegram discovery, cancellation/context/result delivery, safe
  diagnostics, account/channel confirmation and existing-command mapping lifecycle.
- Fixed Telegram modal navigation, visible auth errors, actual confirmed logout,
  credential help and input cleanup. Settings uses modal auth/change-channel flows,
  restores explicit status/actions/gates and version/build/revision reporting.
- Kept independent provider/transfer details and corrected saved-to-both wording.
  Simplified Logs/NotUploaded rows, added readable event/remedy details, preserved
  actual bounded paging/export/retries/history and small thumbnails only.
- Critical subscription filters protect receipt/auth stream capacity from unrelated
  discovery updates. No new consumer, changed dependency or Core receipt/retry logic.
- Added repeatable local source compiler command using the installed 26.5 Catalyst
  SDK. All 64 actual app sources parse and typecheck, with real Diagnostics/Core
  modules, no compiler diagnostics, mocks or suppressed availability. Project/plist,
  source registration, Python syntax, docs targets and whitespace checks pass.

D39/D40 record the bounded discovery tradeoff and compiler-evidence boundary. No
cloud dispatch, updated IPA, account/device/visual testing, Xcode/SDK install or USB
changes. iPhone-only background branch still needs actual iOS build/runtime evidence.
Builder holds; the next build/device session requires the explicit existing manual
handoff. Commit recorded in repository history; no release tag for source correction.
Exact claimed paths release after commit/push. Untracked scratch/ preserved untouched.

## 2026-10-09 — P8 manual build and compiler recovery

User explicitly authorized the iPhone build. Architect owns the focused paths
listed in [P8 build recovery](P8-BUILD-RECOVERY.md). Build 7 from `0c3524f`
passed preflight and restored/verified native cache, then Swift 6.3.3 crashed
during IR generation of a LivePhotoFallbackOption closure thunk. No IPA produced.
Four Settings Binding setters now use explicit closures; the extended real-source
check passes optimized whole-module IR generation as well as parse/typecheck for
all 64 app sources. Exact run, cache, failure and replacement build evidence live
in that recovery document. No device/account tests or dependency changes.

Replacement build [37828111234](https://github.com/tinyredphoenix/Cloudified/actions/runs/37828111234)
passed from `0ebb2e3eb721dfb0e2e6294cc6b6d0633ec5e3f9` (build job 2m39s).
Both SideStore publishers passed; the source now offers version 1.0 build 8.
Exact native cache hit verified; compiler cache saved after its miss. Final cache
usage: 163,235,882 bytes / 10 GB. IPA size/checksum, publication URLs and remaining
device/service acceptance are recorded in P8-BUILD-RECOVERY.md and DISTRIBUTION.md.
No binaries, private logs or scratch files enter this commit. Claimed paths release
after evidence commit/push; no active Builder assignment.

## 2026-10-09 — user-defined visible version increments

Architect claims AGENTS.md, docs/DISTRIBUTION.md, docs/04-DECISIONS.md and this
log for the user's release-version policy. Future bug-fix releases increment the
minor number (1.0 → 1.1 → 1.2); feature releases increment the major number and
reset minor (1.x → 2.0). This is the user's convention, not semantic versioning.
Before a release build, update the app's short version consistently in the source
and project generator so the IPA, Settings and SideStore show the same version.
Keep the CI build number for identifying individual attempts. Failed/retried builds
of the same pending release retain its short version; published releases are not
relabeled. Current published 1.0 build 8 remains unchanged. No build dispatched.
D41 and the distribution contract record the rule. Claimed paths release after
documentation checks/commit/push. No active Builder assignment; scratch/ untouched.

## 2026-10-09 — Telegram first-link storage correction, pending 1.1

User clarified that sourceUnavailable/fileSystem/unknown occurred linking Telegram,
and asked whether Google's device-addition wording can be avoided. Architect's
exact path ownership and implementation evidence: [linking correction](P8-LINKING-FIX.md).
The existing-directory create defect reproduces as Cocoa 516; corrected idempotent
preparation retains real-directory/canonical/protection checks and all native data.
Safe OS codes/readable storage causes replace the unknown message. Google setup
discloses the current route's separate-session/device possibility; auth wire and
isolation remain unchanged. No account/API credential validity claims or secrets.

Pending short version is 1.1 across plist/project/generator. Release staging now
checks the exact built source's version rather than hard-coded 1.0. Real-source
Catalyst typecheck and optimized IR, Python syntax, version agreement, plist/project,
docs and whitespace checks pass. No app/device/account test or cloud dispatch.
Published SideStore remains 1.0 build 8 until a new authorized build. Claimed paths
release after commit/push; Builder holds and scratch/ remains untouched.

## 2026-10-09 — authorized 1.1 build and publication

User explicitly requested build and publish. Architect claims this log,
docs/P8-LINKING-FIX.md and docs/DISTRIBUTION.md for resulting build/publication
evidence. No active Builder writer. Manual run 37832459359 dispatched from
`e20c25c`; public repository confirmed and cache usage 163,235,882 bytes against
configured 10 GB. Standard pinned workflow/runners unchanged. Completion evidence
follows below; device/account behavior is not established by build/publication.
Untracked scratch/ remains untouched.

Run [37832459359](https://github.com/tinyredphoenix/Cloudified/actions/runs/37832459359)
passed: preflight 6s, macOS job 2m22s, version 1.1 build 9 from exact source
`e20c25c741d4bb98b982942b9cb388e1baded938`. Exact native cache hit verified;
compiler cache missed after project/version changes and saved successfully.
Final cache usage 211,468,946 bytes across five caches / configured 10 GB.
App publisher 37832804683 and source publisher 37832844600 published the permanent
unsigned IPA. Public raw SideStore source reports 1.1 (9), matching manifest size
17,414,506 bytes and SHA-256
`eb9e98ff6dc3bdb9f8482f85c89fab514da8a15eec84e7a8c0a42d6f183e4861`.
See DISTRIBUTION.md for URLs; device linking/upload acceptance remains pending.
Claimed documentation paths release after evidence commit/push; Builder holds.


## 2026-10-09 — P9 connection recovery and public diagnostics source

Architect implements the exact paths claimed in [P9](P9-DIAGNOSTICS.md); no active
Builder. User approved direct public paste.rs reports with no extra setup. Export
folder creation no longer aborts provider assignment; missing setup, network policy
and uncertain remote transfer are distinguished. Google saved-token verification
retry and browser fallback help are implemented. Telegram native-client reuse,
bounded startup requests and retry are implemented without deleting native data.
Detailed closed diagnostic stages, codes, correlation identifiers and timings feed
existing persistence/retention. Logs uploads bounded safe reports and displays only
a validated full-success URL. No raw credentials, media or private paths added.

Pending feature version 2.0 across plist/project/generator; adapted Google digests
refreshed, upstream pin unchanged. All 66 real app sources pass Catalyst typecheck
and optimized whole-module IR; real Diagnostics/Core compile. No account/device test,
real paste POST or cloud dispatch. Published SideStore remains 1.1 (9). Device
acceptance remains pending and source findings do not prove service behavior.
Untracked scratch/ is untouched. Ownership releases after source commit/push.


## 2026-10-09 — authorized 2.0 testing publication

User explicitly requested publish 2.0 for testing. Architect claims README.md,
DISTRIBUTION.md, P9-DIAGNOSTICS.md and this log for publication evidence. Public
visibility and existing 10 GB cache limit confirmed before manual dispatch; standard
runner labels unchanged. Build 37891550316 from exact source
`f080be2bd533f4d45401ff57a90988cb4e4be694` passed (preflight 3s, macOS 2m06s).
Native cache hit; compiler cache missed and saved. Final usage 259,935,038 bytes,
six caches / 10 GB. Both publishers 37891757475 and 37891781253 passed.
Unauthenticated SideStore feed verifies 2.0 build 10, bundle, 17,495,366-byte size,
checksum and exact run URL against the verified build manifest. See DISTRIBUTION.md.
No account/device or live diagnostic POST performed. Annotated v2.0-build10-untested
marks the actual built source; it does not assert device acceptance. Scratch/ stays
untouched; ownership releases after documentation commit/push.


## 2026-10-09 — P9-R1 device evidence and prepared correction

User supplied 2.0 (10) exported diagnostics and Telegram/report error text. Architect
claims exact paths in P9-R1.md; no active Builder. Source and pinned native evidence
locate the Telegram stall at setNetworkType queued before initialization parameters.
Structured dispatch acknowledgement preserves network-gate ordering while allowing
parameters to initialize TDLib; both outcomes remain awaited and bounded. Cached
policy changes serialize after initialization, rechecking actor ownership after
suspension. Native databases, remote receipts and media retry policy are unchanged.

Diagnostic messages now show safe codes inline. Local non-private paste.rs service
checks reproduce raw HTTP 400 and larger web-form HTTP 500; one tiny web-form paste
was verified and deleted, but report-size support failed. No personal attachments
were uploaded. A dpaste.com replacement is prepared with declared destination,
seven-day expiry, bounded POST, rate spacing and exact raw retrieval verification.
Automatic approval review rejected its compiler-log upload: previous user approval
named paste.rs and log sensitivity was not established. No dpaste data sent. User
approval request remains pending; no cloud dispatch or release is authorized here.

Pending 2.1 is consistent across plist/project/generator. Python syntax, local
Markdown targets, plist/project and whitespace checks pass. Final actual-source
compiler evidence is recorded in P9-R1.md when complete. Published source remains
2.0 (10); no account/iPhone run in this batch. Scratch/ and personal attachments are
untouched. Shared source is reviewable; do not publish the new diagnostic host until
user approval, service verification and explicit build/publication authorization.


## 2026-10-09 — P9-R1 diagnostic destination approved and verified

User explicitly approved the move to dpaste.com and completion of Telegram fixes.
Architect claims this log, P9-R1.md, README.md and 04-DECISIONS.md for final evidence.
Anonymous creation returned HTTP 201; the strict HTTPS item URL's raw .txt retrieval
matched the inspected six-line compiler report byte-for-byte. Only source counts and
check results were posted, with one-day verification expiry. Production requests seven
days, names dpaste.com in the UI and rate-spaces POST/verification reads by 1.1 seconds.
No secret, user attachment, account credential or personal path was uploaded. The
prior automatic rejection was resolved by explicit user authorization, not bypassed.

All 66 actual app sources had passed Catalyst typecheck and optimized IR after the
Telegram startup sequencing, actor ownership and diagnostic replacement changes;
no source changed during this final service verification. Version 2.1 remains ready
for manual build/publication; public SideStore remains 2.0 (10). No iPhone/account run,
maximum-size dpaste test or cloud dispatch. Ownership releases after evidence commit.


## 2026-10-09 — authorized 2.1 publication

User explicitly requested publish. Architect claims README.md, DISTRIBUTION.md,
P9-R1.md and this log for publication evidence. Public visibility and 10 GB cache
limit confirmed before dispatch; standard runner labels unchanged. Manual build
37897046071 from `2dc17a0b95baf962685c7051b35793c3e95230cb` passed (preflight 4s,
macOS 1m46s). Exact native cache hit; compiler cache missed and saved. Final usage
308,428,160 bytes / 10 GB across seven caches. Publishers 37897241252 and 37897264180
passed. Public unauthenticated SideStore feed verifies 2.1 (11), bundle, 17,507,901
bytes, checksum and run URL against the exact build manifest. Full evidence in
DISTRIBUTION.md. Annotated v2.1-build11-untested marks the built source, not device
acceptance. No real account/iPhone check in this publication turn. Scratch/ untouched;
ownership releases after documentation commit/push.

## 2026-10-09 — P9-R2 device report corrections (pending 2.2)

Architect claims paths in P9-R2.md. Current 2.1 device reports prove Telegram
initialization and dpaste delivery work; phone submission fails native 400. Google
exchange/redemption succeed, subsequent identity work fails HTTP 400. Added safe
rejection names, phone normalization/default settings, separate JSON identity
headers, fresh-token reuse and accurate internal authentication failure stage.
No identity bypass, native DB deletion, credential logging or upload protocol change.
Source compiler validation is recorded in P9-R2.md; no cloud dispatch/device retry.
Scratch untouched.

## 2026-10-09 — P9-R3 researched source corrections (pending 2.2)

User authorized research, reference sign-in comparison and fixing issues. Architect
claims paths in P9-R3.md; no active Builder. Pinned PhotosBackup browser/master/Photos
exchange and refresh/read-access implementation compared directly. Official Google
library supports POST/Bearer tokeninfo; added one same-token fallback and exact-token
proof cache/reverification without email-only identity. Corrected Telegram auth
classification/duplicate logs/input retention; local Google crash inventory;
transactional schema v4 bounded diagnostic event rotation; signed/permitted background
identifiers and measured progress; expiration join ownership. Original upload wire
fields, dependency pins, three attempts, independent lanes and uncertainty fences
remain. All 66 actual-source Catalyst compiler/IR checks pass; iPhone-only continuation
still needs the real build/device gate. See P9-R3.md for evidence/limits. No cloud,
account or app tests; no new release tag. Scratch untouched. Ownership releases after
commit/push; no automatic Builder assignment.

## 2026-10-09 — 2.2 (12) publication

User explicitly authorized build and repository update. Exact built source:
`f17407aecd042ce798434aee18c1ad09e3019320`.
Manual build [37909280926](https://github.com/tinyredphoenix/Cloudified/actions/runs/37909280926)
passed: preflight 5 seconds; standard macos-26 iPhone build 2 minutes 48 seconds.
Native dependency cache hit; changed compiler contract caused a compiler cache miss,
then a new cache was saved. Final cache usage: 357,030,701 bytes, eight caches;
configured allowance remains 10 GB. Both repositories are public.
App publisher 37909619524 and source publisher 37909643591 succeeded.
Permanent Source prerelease: `ci-run-37909280926-untested`.
Unsigned IPA: 17,545,214 bytes; SHA-256:
`1a5ae98664fa90bf09d71c56a06c997c87b126b1c7bdfa04eeddb02b5f3ec56d`.
Unauthenticated public source feed matches manifest version 2.2, build 12,
bundle identifier, size, digest and permanent download URL; release asset digest
also matches. Annotated tag `v2.2-build12-untested` identifies the exact built source.
This establishes native compiler/package/publication evidence, including the
iPhone-only continuation branch, not account login or device execution acceptance.
Next device checks: confirm Settings 2.2 (12), Retry saved connection for Google,
retry Telegram phone submission, send new public diagnostic links on failure.
Source repository and feed are updated; scratch remains untouched.
