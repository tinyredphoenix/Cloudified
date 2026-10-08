# Cloudified agent instructions

Implement only the batch the user/architect has authorized. Read README.md and the
contracts relevant to that batch; do not reread every file for routine changes.
The root docs are planning contracts, not evidence of working app features.

Start with docs/01-ARCHITECTURE.md and docs/02-BUILD-PHASES.md. Use
docs/03-BUILD-LOG.md for active ownership/evidence and docs/04-DECISIONS.md for why.
Architect completed P4-B provider source integration and reviewed Builder P5.
User assigned Architect direct P5-R1 and critical P6; source integration is implemented.
Read docs/P5-P6-INTEGRATION.md for evidence and P7 boundaries. Builder holds until
an explicit packaging/debugging handoff; no automatic cloud dispatch. Architect owns critical Core,
provider/native internals. Claim exact paths before editing.

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
  Cloud workflow is manual. Public standard runners do not consume private minutes;
  verify public visibility and storage/budget limits before dispatch. Keep caching
  within the existing free limit and follow docs/BUILD-CACHE.md. Never use a larger
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
- User's visible release convention: bug fixes increment minor (1.0 → 1.1 → 1.2);
  features increment major and reset minor (1.x → 2.0). Update the app short version
  and project generator before a release build; IPA, Settings and SideStore must agree.
  CI build numbers still distinguish attempts; retries retain the pending version.
  Never relabel an existing published IPA. See docs/DISTRIBUTION.md and D41.

User explicitly authorized Architect to complete P5 corrections and critical P6.
Read docs/P5-REVIEW.md and docs/P5-R1.md for correction scope; runtime contracts
apply to P6. No active Builder assignment. Source findings are not device evidence.
Core/provider/native internals remain Architect-owned.
No app/account/runtime tests or cloud IPA builds before P7.
