# Cloudified agent instructions

Implement only the batch the user/architect has authorized. Read README.md and the
contracts relevant to that batch; do not reread every file for routine changes.
The root docs are planning contracts, not evidence of working app features.

- Swift/SwiftUI native iOS 26. Original quality only. Both photos and videos.
- Reuse the pinned PhotosBackup implementation for Google; TDLib for Telegram.
  Reference projects supply implementation, not UI inspiration.
- Preserve independent providers, three total automatic attempts per asset/provider,
  accurate ledger-backed counts, and reinstall reconciliation before absent-content
  uploads. No blind resends after unknown outcomes.
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

No app implementation is authorized merely by opening these instructions. The
current batch establishes architecture, repository and build infrastructure.
