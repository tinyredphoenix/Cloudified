# Cloudified agent instructions

Implement only the batch the user/architect has authorized. Read README.md and the
contracts relevant to that batch; do not reread every file for routine changes.
The root docs are planning contracts, not evidence of working app features.

Start with docs/01-ARCHITECTURE.md and docs/02-BUILD-PHASES.md. Use
docs/03-BUILD-LOG.md for active ownership/evidence and docs/04-DECISIONS.md for why.
Builder completed P1 and submitted P3-R2; Architect completed critical source corrections. Next Builder batch is P4-A in docs/P4-FOUNDATIONS.md. Architect directly authors P2 critical
core and critical protocol corrections. Coordinate ownership before overlapping work.

Latest user direction: no demo/mock/seeded data, fake progress, sample logs or fake
accounts in the app. Build and integrate every feature before the first app test.
No per-phase unit/simulator/device test suites or cloud IPA build cycles. Necessary
static review/syntax/compiler checks are allowed; full integrated build/testing
starts at P7, followed by debugging iterations. Earlier test-gate proposals are
superseded by this schedule. Production logging must be implemented with the core,
not postponed until failures occur.

- Swift/SwiftUI native iOS 26. Original quality only. Both photos and videos.
- Reuse the pinned PhotosBackup implementation for Google; TDLib for Telegram.
  Reference projects supply implementation, not UI inspiration.
- Preserve independent providers, three total automatic attempts per asset/provider,
  accurate ledger-backed counts, and reinstall reconciliation before absent-content
  uploads. No blind resends after unknown outcomes.
- Both enabled providers execute concurrently in the same backup batch; never
  upload the entire library to Google before starting Telegram. Dashboard is the
  main screen, with overall activity, separate remaining/total/confirmed counts,
  Photos/Videos sections and honest current-file byte progress.
- Memory/storage/cleanup rules in docs/RUNTIME-SPEC.md are required.
- Small error-list thumbnails only; no gallery or full-screen media viewer.
- Source stays in this checkout. No large local Xcode/SDK download by default.
  Cloud workflow is manual; verify allowance before dispatch. Never use a larger
  paid runner or automatic build schedule without user authorization.
- Never format/repartition the USB drive or remove unrelated files. No drive
  installation is currently part of the selected cloud-build setup.
- Never commit credentials, signing material, private media, logs with personal
  data, or build binaries. Preserve upstream licenses when code is actually added.
- Before a dependency update, pin the exact source/artifact revision and record
  its provenance. Do not silently track a moving main branch.
- Do not edit a file another active agent is editing. Report focused diffs,
  validation evidence and unresolved failures to the architect.
- Make small commits at coherent batches. Annotated milestone tags must accurately
  describe evidence: plan tags are not app releases. Push history and tags to origin.

Opening these instructions does not authorize every phase. Current Builder handoff
is P4-A only as specified in docs/P4-FOUNDATIONS.md and docs/CORE-INTEGRATION.md. Architect owns P4-B critical upload/receipt/recovery integration. P2 core paths remain Architect-owned;
later application phases need their prerequisites and an assigned batch.
