# Cloudified — dual photo uploader (draft)

Status: discussion draft, not authorization to implement. Updated 2026-10-07.

Target confirmed by user: iOS 26. Every eligible asset should be queued for both
destinations; preserve Live Photos wherever the destination integration permits.
Original quality is mandatory. The user accepts gunshot and PhotosBackup as
working references; use PhotosBackup as the standalone integration foundation.
Detailed evidence: [RESEARCH.md](RESEARCH.md). Counting/UI contract:
[STATUS-SPEC.md](STATUS-SPEC.md). Reliability/account contract:
[RELIABILITY-SPEC.md](RELIABILITY-SPEC.md).
Runtime/cleanup contract: [RUNTIME-SPEC.md](RUNTIME-SPEC.md). Build placement:
[BUILD-SETUP.md](BUILD-SETUP.md).
Current shared handoff and phase ownership: [handbook 1](01-ARCHITECTURE.md) and
[handbook 2](02-BUILD-PHASES.md). The architect directly implements critical P2.

## Agreed purpose

Personal, standalone, sideloadable iPhone app. Upload photos and videos to
Google Photos and one free second destination. Upload new/non-uploaded bytes;
avoid duplicates, including after reinstall with the same destinations. No gallery,
editing, sharing, or media-management UI. Small identification thumbnails are
allowed in failed-upload rows; full-screen photos and video playback are excluded.
Google integration must be based on g8row/PhotosBackup's implementation.

## Proposed decisions

- Native Swift + SwiftUI + PhotoKit; durable local SQLite ledger; Keychain.
- Keep source on the Mac; use manual GitHub Actions Xcode builds to conserve local
  space. Leave the connected ExFAT pendrive and its existing data unchanged.
- Reference repositories inform implementation only. Design the small native UI
  independently; no reference-project UI inspiration or copying is required.
- Second destination: Telegram private channel, accessed on-device via TDLib
  with the owner's user account. No Cloudflare, VPS, S3 gateway, or Premium.
- Pin a tested PhotosBackup revision; preserve its MIT notices. Reuse its
  authentication, GPMC protocol, duplicate lookup, and background transport.
  Audit those parts before modifying them. Do not copy the whole UI blindly.
- Keep Google and Telegram adapters isolated behind a small upload interface.
- Original-quality mode only: no Storage Saver switch, automatic recompression,
  HEIC-to-JPEG conversion, or quality downgrade after a failure.
- Google and Telegram each have their own enable switch, account mapping, queue,
  error state, retry budget and confirmation records.
- Default proposal: original resources, Wi-Fi only, manual Back Up button.
  Scan all accessible photos/videos; clearly show any limited-permission scope.
  Automatic scheduled backup remains an optional later decision.
- Use iOS 26 continued processing for explicitly started backup batches; retain
  Google's background URLSession transport and persist both providers' state.
  Automatic scheduling, if added, uses a different background mechanism.

## Integration checks before the full build

These checks validate our new app's integration and preservation of the existing
implementations' behavior; they do not reopen the chosen storage architecture.

1. Build and sideload the Google baseline. Prove sign-in, stored credentials
   after restart, upload, and remote hash lookup with the user's account.
2. Confirm Google's requested no-quota/original profile on a fresh test batch.
   Independently check storage accounting and download original bytes to
   compare checksums. Upload acceptance or a quality label alone is insufficient.
   If this gate fails, report the evidence; do not silently use ordinary quota.
3. Build/package TDLib for simulator and physical iPhone. Prove Telegram login,
   document upload, confirmed message receipt, and history-based reconciliation.
4. Download Telegram test documents outside the production UI and compare hashes.
   Exercise a large video and restart recovery. Verify split-file reconstruction
   for a fixture beyond Telegram's free per-file limit.

## Data flow and completion rules

PhotoKit scan -> bounded staging of original resources -> streaming hashes ->
independent Google and Telegram jobs -> durable confirmed receipts.

- Do not queue or export the whole library into RAM or temporary disk at once.
- Use PhotoKit IDs/change tracking for efficient scans, content hashes for byte
  identity. Never identify duplicates by filename or date alone.
- Compute SHA-256 for our identity and the SHA-1 required by Google's protocol.
  Reuse staged bytes across providers and avoid repeated reads where practical.
- Ledger identity includes destination account/channel and resource content.
  A change of account cannot inherit another account's completed status.
- Freeze media policy and destination identity for each job. A setting change
  must not change the meaning of a transfer already in progress.
- One upload per destination initially; both destinations may progress together.
  One provider's failure must not block the other or trigger its re-upload.
  Both enabled lanes start in the same batch; do not drain Google's whole library
  before starting Telegram. Prove concurrency with controlled adapter barriers.
- Track pending, preparing, sending, finalizing, confirmed, retryable failure,
  and unknown outcome per destination. Persist checkpoints at network boundaries.
- Unknown outcomes must be reconciled remotely before retrying. Promise duplicate
  prevention for confirmed/reconciled content, not unconditional exactly-once
  delivery across undocumented APIs and ambiguous network failures.
- Google: retain upstream remote content-hash check, including existing Google
  content when its hash is discoverable. Never treat a failed lookup as absent.
- Telegram: send original bytes as documents, tag messages with versioned content
  identity, and retain manifests describing resource/pair identities and receipts.
  Rebuild app-managed completion records from channel history after reinstall.
  Existing arbitrary Telegram uploads without these identifiers are outside v1
  deduplication guarantees.
- Reinstall recovery is a required feature: identify the account/channel, rebuild
  Telegram's app-managed content index from remote captions/manifests, and use
  Google's remote hash lookup. A failed/incomplete recovery is not evidence that
  content is absent; affected uploads wait for reconciliation rather than resend.
- Split documents exceeding the free per-file limit into deterministic bounded
  parts; record part hashes/order/length and a complete-file hash in a manifest.
  An item is confirmed only after every part and manifest are remotely confirmed.
- Both complete means every required resource is confirmed at both destinations.
  Show per-provider counts and explicit partial/failure states.
- Maximum three total automatic attempts per asset per provider (initial attempt
  plus two retries), persisted across relaunches. Retry only missing obligations.
  After exhaustion, mark Not uploaded with a reason and continue to the next asset.
  No error popups for automatic retries. Use a delayed retry queue so an asset
  waiting for backoff does not hold the front of the provider's queue.
- Unsupported/permanent asset errors go directly to Not uploaded. Account-wide
  auth/quota/rate restrictions enter a provider-specific waiting state; avoid
  spending every remaining asset's attempts on the same unusable account.
  The other provider continues. Explicit user Retry starts a new bounded cycle.
- Keep staging bounded, check available disk, and remove files only when no
  transfer needs them. Never delete originals from Apple Photos.
- Track file consumer leases and reconcile live transports before crash cleanup.
  Release buffers/handles/job objects on every outcome. Finished/blocked providers
  retain small receipt/obligation records rather than unlimited exported media.

## Media scope

Preserve original HEIC/HEIF, JPEG, PNG, MOV/MP4 and other accessible PhotoKit
resources without recompression. Validate representative codecs, HDR, slow-motion,
and RAW/ProRAW separately; never claim blanket Google format support.
Telegram can preserve arbitrary resource bytes as documents. A Google rejection
must remain visible rather than silently converting or omitting the resource.

Live Photos require both still and paired video resources. The referenced
PhotosBackup README reports still-only behavior, so extend resource extraction
and test Google pairing before claiming support. Telegram always archives both
original components with their association recorded. For Google, prefer verified
native pairing; otherwise expose a choice: key image only, motion video only, or
both original components as separate items. The third option is recommended for
preservation when native pairing cannot be achieved. Never silently choose a
fallback. Reduced coverage is shown even when the selected fallback has finished.

Use the original captured still for unmodified mode. A later user-selected key
frame or rendered edit can require a derivative and must be labeled accordingly.
No automatic HEIC-to-JPEG conversion or video re-encoding. Preserve embedded
metadata by copying original bytes. Telegram also receives a versioned JSON
manifest of accessible Photos metadata, resource hashes, and relationships.
Google receives supported capture metadata; its library representation is tested
separately. Do not promise complete restoration of Apple's edit history or library.

## Minimal UI

- Setup: Google connection, Telegram connection/private channel, Photos access.
- Overall Dashboard is the first screen: Uploading/Preparing/Checking/Finalizing/
  Waiting/Paused/Complete/Needs attention, with precise provider-specific reasons.
- Distinct Google and Telegram panels with `X remaining out of Y`, confirmed counts, photos
  and videos remaining, blocked items, current stage, and transfer progress.
  Live Photos count as one photo asset; their component progress is secondary.
  Counts come from the durable ledger, not network callbacks or UI-only counters.
  Both-complete is the intersection of confirmed assets, not the smaller count.
- Photos and Videos are separate dashboard sections, both enabled for backup by
  default. Video totals/progress/errors must be first-class, not hidden in photos.
- Not uploaded: provider and Photos/Videos filters, small optional thumbnail,
  filename/date, status, attempts, understandable reason and detailed error code.
- Logs: chronological events filtered by provider and severity; bounded storage,
  redacted export, persistent actionable failure records outside log retention.
- Settings: independent provider switches; Google account link/reconnect/unlink;
  Telegram account link/reconnect/unlink and private-channel mapping; visible
  account/channel identities, Wi-Fi policy and Live Photo fallback policy.
  Disabling/unlinking preserves receipt history and never deletes cloud media.

Credentials never appear in logs or checked-in files. Telegram cloud channels are
not end-to-end encrypted; optional client-side archive encryption and key recovery
remain a separate decision, not an assumed requirement.

## Verification and division of work

Architect directly authors the critical P2 queue/receipt/recovery/concurrency/cleanup
engine and important protocol corrections. Builder executes the other assigned
small numbered batches and records changed files, check commands,
results, screenshots/recordings, and unresolved issues. Architect reviews summaries
first; directly reads protocol/auth, persistence, resource extraction, retry/recovery,
background lifecycle, and packaging changes. Do not simultaneously edit shared files.

Required checks: rerun without new media transfers; identical bytes under different
local IDs; one destination complete and the other failing; lost response after
remote acceptance; restart/force-quit; offline and rate limiting; revoked auth;
low disk; iCloud-only resources; Live Photo partial failure; account change; reinstall
and manifest reconciliation; persisted three-attempt exhaustion; independent
disable/unlink and correct account/channel remapping. Preserve upstream meaningful tests, add state-machine
failure tests, and verify on the signed physical iPhone.

Background scheduling is opportunistic. TDLib transfers do not automatically gain
URLSession background-transfer behavior. On iOS 26, explicitly initiated finite
backup batches can use BGContinuedProcessingTask with system progress and
cancellation. Checkpoint on expiration and cancellation; never promise indefinite
execution. Evaluate the newer PhotoKit resource-upload extension separately if
the installed OS/SDK, signing, and Google receipt handling support it.

Efficiency priorities: incremental PhotoKit scans, one bounded export worker,
streaming dual hashes, shared staging, one transfer per provider initially,
rate-aware retries, and UI progress updates at a modest cadence. Enforce Wi-Fi
policy in both URLSession and TDLib, including network changes mid-transfer.

## Unanswered details

- Exact iOS 26 minor version/device, library size/largest videos, Telegram login acceptance.
- Automatic scheduled backup, originals versus rendered edits, archive encryption.

## Sources

- https://github.com/g8row/PhotosBackup/blob/main/README.md
- https://github.com/g8row/PhotosBackup/blob/main/GPMC/Core/GPMCClient.swift
  (commitProfile and prepareUpload inspected; live device behavior unverified here.)
- https://github.com/tqmane/gunshot (comparison only, not chosen app foundation).
- https://core.telegram.org/tdlib
- https://core.telegram.org/tdlib/getting-started
- https://telegram.org/faq (free file limit and cloud-chat encryption model).
- https://core.telegram.org/bots/faq (why the cloud Bot API is not proposed).

No provider's future free service or Google's private quota treatment is guaranteed.
