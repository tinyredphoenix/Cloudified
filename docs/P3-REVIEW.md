# P3 architectural review and correction assignment

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
