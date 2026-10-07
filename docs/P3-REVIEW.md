# P3 architectural reviews and correction assignments

Current next batch: **P4-A provider foundations** in P4-FOUNDATIONS.md. Architect
reviewed P3-R2 and directly completed the remaining critical paths below. P3 is
ready for the implementation handoff with compiler/static evidence only. Previous
P3 correction assignments remain historical; they are no longer the next batch.

2026-10-08. Builder commits `7d53faf`/`b7523e4` are present and pushed. They contain
real implementation work, but P3 is **not accepted** for the P4 handoff. Syntax
parsing does not typecheck access control, Sendable or cross-module interfaces.
No runtime/device/service tests have run, as requested. Findings below come from
focused code review and compiler checks, not generated demo assets.

## Critical findings and direct Architect corrections

| Finding | Review evidence / direct correction |
| --- | --- |
| Cancellation/write failure released export before PhotoKit was terminal | Exporter onCancel only aborted the writer; write-error callback resumed early. Architect replaced it with lock-protected request-ID publication/cancel races and terminal-only close/continuation. Cancellation now requests PhotoKit cancellation and retains ownership until completion. Real iOS behavior remains untested. |
| Writer race, stale-file risk and misleading causes | Writer was mutable/non-Sendable, could race abort with write, opened existing paths, and called every disk error Disk full. Architect added synchronized ownership, exclusive non-symlink creation, bounded writes, guaranteed close attempts and whitelisted known/unknown classifications. |
| Reinstall archive identity depended on local ID | Manifest hashed local generation, and generation contains PhotoKit localIdentifier. Architect removed local generation from remote recipe identity, whitelisted original descriptors, added full original hashes/UTIs/names and final remote references outside the stable association hash. Archive timestamps use Unix milliseconds with fractional values. |
| Plan crossed an internal module API | App called internal `UploadPlan.validate()`. Architect removed those calls; public ContentIdentity.plan already validates. Google planning now includes every selected original and rejects incomplete requested Live Photo coverage. |
| Splitter accepted short reads and unsafe parameters | Architect added length/parameter/cancellation checks, bounded part count, terminal writer cleanup and conservative 1,900,000,000-byte default parts. Actual part hashes still must be connected by Builder. |
| Canonical scanned IDs had no paging path | Scanner discarded returned canonical IDs. Architect added Ledger.scannedAssetPage; Builder must plan those stored identities rather than manufacture new UUIDs. |
| Pre-hash source failures had no durable visible obligation | Architect added scoped recordSourceFailure/sourceFailurePage and aggregate counts without inventing a content hash/job. Enqueue clears a repaired source failure; budgets/receipts stay independent. P5 must merge source/job rows by asset+destination when both describe one asset. |
| Physical staging could not be shared reliably | Requirement UUID differs between providers; master used randomized hashValue. Architect added stable stagingFileID, indexed full-content lookup/acquireContent, verified cache metadata, and distinct stagedUnavailable. Builder must consume these APIs and never treat DB errors as cache misses. |
| Oversized original blocked every other preparation | Architect corrected ordinary staging accounting and admitted one bounded derived part of a verified original. The soft allowance is 1 GiB ordinary staging, one oversized original and one <=1.9-billion-byte part; real disk reserve/copy overhead still apply. Source wiring remains pending. |

Core schema v2 migrates v1 without erasing receipts, attempts or transport holds.
Existing unverified cache rows are not automatically trusted as verified content.
Schema/reopen behavior and filesystem ownership still require P7 evidence.

The Apple request/cancel API surface is referenced in
[requestData](https://developer.apple.com/documentation/photos/phassetresourcemanager/requestdata(for:options:datareceivedhandler:completionhandler:))
and [cancelDataRequest](https://developer.apple.com/documentation/photos/phassetresourcemanager/canceldatarequest(_:)).
The corrections follow conservative ownership rules: request cancellation does not
authorize file deletion, and only an observed terminal callback finishes an export.

## Builder batch P3-R1 — do this next, then stop

Read README/AGENTS, this file, CORE-INTEGRATION and the P3 sections of handbook 2.
Claim paths in handbook 3. Core files remain Architect-owned. Allowed: source
pipeline/preparer/scanner/recipe/permit, StorageLayout, necessary source-plan loops,
project/generator source references and the build-log section. Preserve the directly
corrected exporter/writer/manifest identity/splitter invariants; report needed API
changes rather than replacing them. No provider/auth/UI implementation yet.

1. **Actual part hashes.** Remove the pipeline's full-video-hash placeholders for
   individual parts. While a verified full original is leased, call planSplit on
   its actual file and store measured part offsets/lengths/hashes BEFORE enqueue.
   Recipe must support splitting each required oversized original independently,
   including additional resources; carry the correct resource role. Include every
   other original and full-original reconstruction hashes in the manifest. Validate
   source recipe version, hash shapes, contiguous part order/length and limits on
   encode/decode. Never update frozen jobs with invented later hashes.
2. **Admitted, tracked measurement.** Remove unregistered `measure_*.tmp` exports.
   Use reservations, fresh UUID ExportFileOwnership, publication and content metadata
   for planning as well as re-export. For unknown size, reserve a conservative finite
   upper bound from real capacity (including source/transport/cache copy allowances),
   enforce that cap and measured capacity through exporter's synchronous beforeWrite
   hook, then resize the reservation to measured bytes before registration. Do not
   create a Task per chunk or block MainActor. If it cannot fit safely, retain a
   truthful source wait and continue other assets; never compress or fill the disk.
3. **Shared cache and bounded staging.** After export/hash, registerPublished with
   measured OriginalContent. Reuse `acquireContent` for both providers; known hashes
   may also use stagingFileID. A cache miss is `CoreError.stagedUnavailable`, not
   every error swallowed by try?. Validate full byte identity on publication/re-export.
   Each input in a future paired obligation needs its own lease/file, not the same
   resource.id path twice. Keep at most one small ready original ahead and cooperate
   with safe cleanup; never retain the whole library's measured files.
4. **Derived parts.** Keep a verified master lease while slicing. Reserve a part
   with `derivedFromFileID: masterLease.fileID`; at most one part can be staged/
   reserved globally, bounded to 1.9 billion bytes. Release/sweep safely terminal
   earlier parts before admitting the next; startup inventory remains mandatory.
   Actual available space, 512 MiB reserve and predicted copy overhead still apply.
   Remove hashValue-derived master IDs and asynchronous cleanup Tasks in defer.
5. **Exact source selection and cleanup.** Match the frozen source descriptor using
   resource type/UTI/original filename plus deterministic disambiguation, not just
   first resource with the same role. Check generation before and after measurement;
   verify hashes before publication. Private selector fields must stay out of remote
   manifest identity. Release every accumulated lease if multi-input prepare fails;
   cleanup must not unlink registered/shared files while any lease/transport holds
   them. Release reservations even when beginExport fails. Regenerate manifests
   from current confirmed receipts instead of returning a stale resource.id cache.
6. **Canonical producer and failure isolation.** Filter scan to image/video media,
   paginate actual Ledger.scannedAssetPage identities after metadata scan, and expose
   a finite bounded planning producer usable by P5. One shared permit covers planning
   and prepare across awaits. Handle one asset/resource error without aborting the
   library. Catch provider-plan errors separately: Google planning rejection must
   not prevent Telegram enqueue. Record pre-job failures with recordSourceFailure
   for only the affected immutable destination IDs. Never create fake jobs/hashes.
7. **Truthful storage/errors/logs.** Storage creation/protection/capacity failures
   must throw a classified safe error; do not silently ignore them or manufacture
   a Disk full diagnosis from an unavailable capacity query. Emit actual source
   scan/export/iCloud/hash/split/publication/cancel/error events and measured progress,
   coalesced before task creation. Do not swallow diagnostic persistence failures.
   Current Builder report claims hashing/cleanup coverage, but reviewed source has
   only one try?-wrapped export event. Correct the coverage report to actual code.
8. **Interface checks and handoff.** No demo data, mocks, runtime/unit/app tests,
   cloud builds or Xcode/drive changes. Portable Swift 6 typechecks are allowed;
   PhotoKit/iOS typecheck remains unavailable locally. Conform the real pipeline
   to its intended interface without returning an incompatible concrete property.
   Inspect project/package references and regenerate only if sources change. Record
   exact checks, remaining SDK limitations, event coverage and commits in handbook 3;
   commit/push coherent changes. Stop after P3-R1 for architect review before P4.

## Verification scope

Architect's core compiler check and Foundation/CryptoKit/source-planning Swift 6
typecheck passed; the latter includes SourceRecipe, StreamingHasher, SharedExportPermit,
ArchiveManifestBuilder, UploadPlanProducer, LosslessVideoPartSplitter, StorageLayout
and the existing SettingsViewState enum declarations. Syntax parsing covers the
PhotoKit-dependent files but does not establish their iOS type/concurrency correctness.
The exact compiler commands are recorded in handbook 3. All runtime scenarios,
real media bytes, original quality and reinstall behavior remain P7 work.

## P3-R1 review — 2026-10-08

Report read and compared with `377b647`/`5253218`, not treated as acceptance.
Real part hashing, canonical paging, protocol conformance, verified cache lookup
and normal per-provider plan rejection handling are present. Important omissions:

| Reviewed defect | Disposition |
| --- | --- |
| Every unknown original reserves up to 2,000,000,000 bytes; larger originals are cancelled as disk full even with ample capacity | Builder P3-R2 must replace the arbitrary cap. Architect added `Ledger.reserveSourceStorage` for a finite real-capacity bound, allowing ordinary allocations while an oversized root exists. |
| Post-registration errors remove published files and lose acquired leases | Architect added/wired `FileLeaseStore.rollbackExport`, tracked acquired leases and export completion, and fenced rollback against the durable staged record. Registered files are released, never unlinked by source catches. Failed rollback retains its pin for recovery. |
| Same PHAsset instance checked before/after export | Architect added refetch-based `verifyGeneration` and wired post-export checks. Frozen recipe identity also must match the job. |
| Same-role/same-length OR matching selects another original's split | Architect requires exact master SHA-256/role/length and complete part identity; validates mandatory master associations, duplicate splits, aggregate requirement count and overflow-safe lengths. |
| Manifest retry republishes at the old requirement UUID | Architect uses a fresh physical UUID per document; its stable remote tag remains recipe-derived. |
| Part setup capacity-query failures leak master; sweep errors ignored | Architect widened tracked cleanup over all setup operations and made sweep failures visible. Startup inventory remains a prerequisite. |
| Planner exports up to 50 assets in one call, never sweeps, and does not yield an enqueue/drain opportunity between assets | Builder P3-R2 must expose bounded demand-driven production and idle-file reclamation. A durable recipe is not a media cache obligation. |
| Re-export chooses first candidate when descriptors tie | Builder P3-R2 must freeze a private selector; sorting identical candidates does not disambiguate them. |
| `.progress`/2 Hz coverage claimed, but no source `.progress` emission, coalescer or onProgress use exists | Build log corrected to actual evidence. Builder P3-R2 must implement this wiring. Ledger scan/lease events exist, but do not establish iCloud/cancel/preparer-failure coverage. |
| Cancellation and persistence failures swallowed or called unsupported format | Architect added scan/batch cancellation checks; Builder must finish error propagation and classification below. |
| StorageLayout singleton fatal-errors, and availableDiskSpace still converts unknown to zero | Builder must use throwing composition and remove misleading convenience paths. |

The direct fixes are compiler/static-reviewed only. No actual media, SQLite
runtime, iOS SDK, cancellation, account or provider tests have run. The storage API
is new and must be consumed by Builder; it is not evidence of device performance.

## Builder batch P3-R2 — implement this, then stop

Read README/AGENTS, this current assignment and CORE-INTEGRATION. Claim paths in
handbook 3. Allowed source paths: PhotoLibrary adapters, StorageLayout, related
protocols/project/generator references and build log. Core remains Architect-owned.
Preserve exporter terminal fencing, rollback registration checks, hash identities,
archive whitelist and strict multipart association. Do not start P4/provider/auth/UI.

1. **Unknown size admission.** Replace the 2 GB cap with
   `ledger.reserveSourceStorage(availableBytes:additionalCopyCount:fixedOverheadBytes:)`.
   Its returned `byteCount` is the maximum permitted write. The API accounts for
   actual capacity, outstanding reservations, the 512 MiB reserve and ordinary
   staging room if an oversized root exists. Use conservative enabled-transport
   copies (up to two additional full copies); separately admit a derived part and
   its cache/copy allowance. Recheck actual capacity synchronously during bounded
   writes, not only the nominal cap. No KVC/undocumented file size, async per-chunk
   tasks or main-thread blocking. Resize to measured bytes with conservative
   overhead before publication. Known-original, manifest and part admissions also
   need truthful copy allowances; current zero-overhead exports/parts are unfinished.
   Do not invent a global 2 GB source format limit. An original that cannot fit
   safely waits visibly and permits other assets to proceed without recompression.
2. **Bounded producer/cache.** Plan at most one asset per demand/return to P5,
   with accurate cursor/more/planned/failed results; do not export 50 assets before
   returning or require uploads to wait for an entire-library measurement pass.
   Expose each enqueue to the caller so P5 can merge a ready drain immediately;
   never wait for network completion while holding the source permit. Retain at
   most one small ready original ahead, reclaim older idle originals through the
   fenced store after startup inventory, and respect active leases/holds. Avoid
   duplicate exports using a matching validated persisted recipe/content when safe;
   never assume old remote absence or reset attempts. Preserve large master leases
   while preparing parts, and don't sweep useful masters on every part if avoidable.
   Both empty destination arguments must cause no export/enqueue work.
3. **Exact selector.** Freeze private resource type and deterministic enumeration
   selector/disambiguation in SourceResourceDescriptor when measuring. Resolve the
   same descriptor on re-export, validate type/UTI/filename and current generation,
   then prove byte identity. Ambiguity or selector mismatch must be explicit, never
   choose `first` after sorting equal keys. Keep private selectors out of remote
   manifest association and diagnostic logs. Legacy recipes without an unambiguous
   selector need safe remeasurement/rejection without resetting frozen jobs.
4. **Genuine independence.** Compute Telegram splits only when required by its
   selected destination. A split/hash failure must not prevent Google from planning
   the already verified full original. Likewise, a failed Live motion component
   must not block a Google key-image-only plan whose entire required coverage is
   available. Catalogue each provider's required original coverage before export;
   accumulate resource/provider failures and reject incomplete plans for only those
   destinations. Telegram always requires every original, including Live still and
   motion; never enqueue partial Telegram coverage or an oversized unsplit document
   after split planning failed. Common inability to access an asset affects both;
   database failure is a shared persistence stop, not provider format rejection.
5. **Failure truth/cancellation.** Remove `try? recordSourceFailure` and ordinary
   catch-all swallowing in the producer. Propagate ledger/persistence/invalid-contract
   failures with safe codes so composition can stop/report a broken ledger. Persist
   a recoverable/permanent source failure as appropriate for an actual source error,
   then continue the next asset. Never call an enqueue/SQLite failure unsupported
   original or permanently mark it format-rejected. Record Google errors only for
   Google, Telegram only for Telegram; don't overwrite successful peer bindings with
   an outer catch. Cancellation stops producer work and is not sourceMissing; preserve
   outstanding obligations. Recipe decode errors retain their real category. Handle
   errors after registration by releasing owned leases and using rollbackExport only
   while its export token is active; no raw published-file deletion or silent cleanup.
6. **Source logging/progress.** Implement real start/terminal/failure/cancellation
   events for planning and preparer exports, iCloud download activity, measured hash/
   split work and storage waits. Connect actual received bytes to `.progress`; unknown
   byte totals remain nil, and iCloud fraction is not upload-byte progress. Coalesce
   before asynchronous scheduling with one bounded latest-value consumer, about
   2 Hz maximum, drain/terminate it at completion and propagate diagnostic persistence
   errors. No Task per chunk, timers/closures retained after completion or per-tick
   library enumeration. Ledger scan/lease/cleanup events can be reused; list exact
   emitted coverage in the report instead of claiming instrumentation from interfaces.
7. **Throwing layout/shared permit.** Remove fatalError-based StorageLayout.shared
   and the zero-on-error availableDiskSpace convenience; inject a successfully
   constructed layout from throwing composition. Classify known permission/space
   failures accurately and retain unknown rather than guessing. Serialize manifest
   publication/admission with other source preparations using the shared permit.
   A cancelled queued permit waiter must not later start expensive work; cancellation
   checks already added to scan/batch must remain. Keep Swift 6 Sendable/captured
   immutable snapshot rules intact; don't use unchecked Sendable to mask mutable state.
8. **Checks/handoff.** Compiler/typecheck/parse/docs/project/whitespace checks only,
   no demo data, app/runtime/unit tests, cloud builds or Xcode/USB changes. Portable
   typecheck must use the newly built core; iOS/Photos-dependent typecheck remains
   unverified without an SDK. Report exact event coverage and remaining limitations,
   commit/push coherent batches and stop for Architect review. P4 is not authorized.

Architect verification: core Swift 6 build passed; portable eight-file Swift 6
adapter typecheck passed; parsing all 30 app Swift files, project plist lint and
whitespace checks passed. CLT linker warned about its absent Developer/Library/
Frameworks search path but returned success. Commands/evidence are in handbook 3.

## P3-R2 architectural completion — 2026-10-08

Reviewed Builder `d0c00fe`/`fc2c282` against actual source. Real admission,
private selectors, one-asset demand and progress wiring were added; the report
also concealed significant regressions. Architect directly completed the critical
source paths so another P3 correction handoff is not needed before P4-A:

- Restore throwing recipe decode/frozen job validation and complete lease/reservation
  cleanup. No source catch converts SQLite/recovery/invariant failures into disk full,
  unsupported format or a successfully handled asset. Cancellation stops production.
- Google refuses incomplete selected coverage, including failed auxiliary/second
  originals. Key-only legitimately ignores motion failure. Telegram keeps the real
  split error, splits every oversized role (including Live motion/alternate originals),
  requires full Live components and rejects unsplit oversized inputs. Telegram archive
  limits don't invalidate Google's verified original plan.
- Progress is measured after each successful bounded write/hash, not before it.
  One bounded consumer per export coalesces progress, observes resource-download
  activity separately and is closed/awaited on every success/error/cancellation path.
  No late task can report progress after terminal cleanup or hide a persistence error.
- Planner and preparer log real preparation/export/hash/download/failure events;
  source control/persistence errors remain typed. Unknown totals stay nil.
- Known-original/part writers recheck real capacity and copy allowances during writes;
  arithmetic is overflow-checked. Planning reuses a matching complete verified recipe
  without re-export; otherwise matching cached content is acquired before sweep.
  Idle files are swept under startup/reader/transport fences, not directly unlinked.
- Cancelled queued source-permit waiters are removed promptly; only live waiters
  inherit the permit. The bounded queue cannot accumulate unlimited cancelled work.
- Remote plan/manifest order is canonical by content/role/descriptor, not private
  enumeration selectors. Unique content obligations may share one upload while every
  archived original name/descriptor remains represented. Manifest-v2 records exact
  original SHA-256 and byte offset for each part; shared parts retain each parent's
  binding. Planning/preparation use the same expansion and verify frozen media tags.
  Telegram policy is now telegram-archive-v2; media caption/tag version stays unchanged.

Verification: portable eight-file Swift 6 typecheck passed; all 30 app files parsed.
Full 13-file source/Photos Swift 6 typecheck passed against the available **macOS**
SDK, with originalFilename deprecation warnings from macOS 27. This is stronger than
parse but is not iOS SDK/link/device/runtime proof; preconcurrency import is not a
concurrency test. Source property remains compatible with the iOS 26 target API.
Core was unchanged this batch; typechecks used the previously compiled current core.
No app/media/database/provider/quality/reinstall tests, cloud runs or drive changes.

P5 must give the one-asset producer explicit demand/credits, complete actual startup
inventory before sweeps, merge ready drains after enqueues and present source failures
alongside job failures. Coverage/account changes must settle affected work before
replanning, preserve historical receipts and invalidate obsolete active bindings so
old confirmed coverage cannot mask a new pre-job failure. This needs Architect-owned
Core integration during P5; source code alone doesn't establish dashboard behavior.
P6 owns source-change observation/reexportability and complete background/cache lifecycle.
All functional/resource/failure scenarios remain the first integrated P7 test.
