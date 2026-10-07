# Cloudified research and verification decisions

Researched 2026-10-07. User target: iOS 26. This is a planning artifact;
no app has been built, sideloaded, or tested against the user's accounts here.
Facts supported by documentation/code are distinguished from device-test gates.

Current binding requirements are in [RELIABILITY-SPEC.md](RELIABILITY-SPEC.md):
original quality only; separate photo/video sections; independent provider switches,
account mapping and failures; maximum three total automatic attempts per asset per
provider; visible Not uploaded list and logs; reinstall-safe remote reconciliation.
User accepts both referenced Google implementations as working. Integration checks
verify that this new app preserves their behavior, rather than reconsider the base.

## Architecture recommendation

Native SwiftUI, PhotoKit resource export, SQLite queue, Keychain, and two isolated
provider adapters. Google uses a pinned g8row/PhotosBackup revision. Telegram uses
the official native TDLib client with the owner's account and a private channel.
There is no backend, recurring server bill, S3 gateway, or viewing/editing feature.

GitHub-as-storage adds repository/file restrictions and does not improve this
two-destination design. The Telegram S3 gateway articles introduce infrastructure
that a direct native client avoids. gunshot depends on integration into the Google
Photos app and is a comparison/reference, not the standalone app foundation.

All eligible assets are queued to both destinations. Unsupported media stays
visible as blocked on the affected provider. Do not weaken original quality to
make status green. "Free unlimited forever" is not a testable product guarantee.

## Google: inspected code versus unverified server behavior

The inspected [GPMC core](https://github.com/g8row/PhotosBackup/blob/main/GPMC/Core/GPMCClient.swift)
requests Pixel XL with quality 3 for the non-quota/original mode. Its flow is
hash check, transfer, then commit; a successful transfer alone is insufficient.
Keep this protocol behind an adapter rather than rewriting it during UI work.

The [README](https://github.com/g8row/PhotosBackup/blob/main/README.md) describes
on-device authentication, persistent queues and background transfer support, but
currently exports only the still component of Live Photos. Google's public APIs
are not a substitute for the requested quota behavior. Private endpoints can
change, and this research does not prove the user's account receives free originals.

An [open quality-label report](https://github.com/g8row/PhotosBackup/issues/11)
makes independent testing necessary: neither the UI toggle nor the remote label
proves compression or byte preservation. Test actual downloaded originals.

Build gate: fresh uniquely identifiable HEIC/JPEG/MOV fixtures, non-quota/original
mode, before/after account storage measurements after accounting settles, download
the original rather than a preview, compare hashes and embedded capture metadata.
Record account, source revision, settings, file sizes, and results. Failure blocks
the unlimited-original claim; no silent ordinary-quota switch.

Critical audit item: the inspected commit timestamp includes a fixed fractional
field. Verify the private schema and round-tripped capture time before changing
it; this observation alone does not establish a bug. Pass capture date deliberately
and retain the precise source value in our manifest.

## Original export and metadata

Use [PHAssetResourceManager.writeData](https://developer.apple.com/documentation/photos/phassetresourcemanager/writedata(for:tofile:options:completionhandler:))
to stage underlying resource bytes. Enumerate resources deliberately; do not use
a screen-resolution image request, picker preview, or automatic JPEG conversion.

[Resource types](https://developer.apple.com/documentation/photos/phassetresourcetype)
distinguish originals from modified full-size resources. Include original photo,
original video, paired Live Photo video, and relevant alternate originals such as
RAW/JPEG companions. Define any edited-resource archive as a separate policy.

Original-byte copying preserves embedded EXIF/QuickTime metadata, orientation,
color profiles and embedded auxiliary data. Apple Photos also stores properties
outside those files. Create a versioned archive manifest with accessible
[PHAsset metadata](https://developer.apple.com/documentation/photos/phasset):
creation/modification timestamps, location when available, favorite state, media
type/subtypes, dimensions/duration, and original filename/UTI per resource.
Add hashes, lengths, resource roles, pair identifiers, and remote receipts.
Do not invent missing time zones or change embedded GPS. A manifest contains
private metadata and belongs in the private archive, not diagnostic logs.

Telegram stores original resources plus manifests. Google receives supported
capture metadata through its integration; preservation of Google's displayed date,
location and original download must be tested. Apple edit history, faces, album
semantics and complete Photos-library restoration are not promised by this uploader.

The upstream [exporter](https://github.com/g8row/PhotosBackup/blob/main/App/Sources/MediaExport.swift)
needs adaptation for multi-resource assets and durable PhotoKit access. Avoid a
picker-only fallback for full-library backup. Keep staging in protected, backup-
excluded Application Support with disk limits; cache eviction must not invalidate
a background transfer. Cancellation, iCloud fetching and partial export require
explicit ledger outcomes.

## Live Photo strategy

Google [officially supports Apple Live Photos in its iOS app](https://support.google.com/photos/answer/6193313?co=GENIE.Platform%3DiOS&hl=en).
That does not establish pairing support in PhotosBackup's private client.
Start by exporting original still plus paired MOV. Telegram archives both as
documents and records their association. Test Google native pairing separately.

If Google pairing fails, offer key image only, motion video only, or both
components separately. Recommend both for preservation. The user's request to
upload all photos to both remains the default; fallback coverage is always visible.
Do not call separate items a native Live Photo. Original mode means the captured
still; a later selected key frame/rendered edit may require a derivative.

An optional compatibility experiment can use the documented
[Android Motion Photo container](https://developer.android.com/media/platform/motion-photo-format)
to package still and video without re-encoding their payloads. HEIC requires proper
container structure and metadata; naive concatenation is insufficient. The new
container is a derivative, even if image/video payloads remain unchanged.
[MotionPhoto2](https://github.com/PetrVys/MotionPhoto2) is a reference implementation
to study, not a reason to bundle Python or FFmpeg into this simple app.

Only enable the experiment after native Google recognition, download/payload
comparison, key-frame timing, orientation, audio, HDR/gain-map colors and quota
tests pass. Telegram always keeps the true source pair. Do not let the experiment
delay reliable ordinary-photo/video uploads.

## Media compatibility and limits

| Asset | Telegram plan | Google plan |
| --- | --- | --- |
| HEIC/HEIF, JPEG, PNG and ordinary videos | Original documents | Originals, verified fixtures |
| Live Photo | Original still + MOV + association | Pairing test, then explicit fallback |
| RAW/ProRAW with alternate originals | Archive each selected original | Test actual formats independently |
| HDR/portrait/slow-motion/cinematic | Preserve accessible original bytes | Test rendering and downloaded originals |
| Very large video | Lossless parts + reconstruction manifest | Published limits plus actual endpoint test |
| Rejected format/resource | Archive bytes if accessible | Visible blocked state; no silent conversion |

Published [Google backup limits](https://support.google.com/photos/answer/6193313?co=GENIE.Platform%3DiOS&hl=en)
include 200 MB/200 MP photos, 10 GB videos and minimum dimensions above 256×256.
These are planning checks, not proof that every private endpoint accepts every
listed codec. Videos beyond Google's limit cannot honestly be marked saved there.

Telegram [permits 2 GB per file for free users](https://telegram.org/faq#q-how-is-telegram-different-from-whatsapp).
Use a conservative measured part ceiling below that boundary; 1.9 GB is an initial
proposal, not a protocol constant. Split large documents without transcoding.
Store complete-file hash, part lengths/order/hashes, and versioned reconstruction
instructions. Parts are not individually playable copies of the original video.
Confirm all parts and the final manifest before marking the asset saved.

## Telegram integration and receipts

[TDLib](https://core.telegram.org/tdlib) supplies the native client transport and
state machinery. Obtain the user's own free app API credentials as described in
[getting started](https://core.telegram.org/tdlib/getting-started); do not reuse
public example credentials. Protect authentication and database keys in Keychain.

Send [inputMessageDocument](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1input_message_document.html)
with content-type detection disabled to archive originals as files. Avoid photo
send methods that can create processed image representations. Confirmation comes
from [updateMessageSendSucceeded](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1update_message_send_succeeded.html),
not a temporary sendMessage result or uploaded-byte counter. Persist the final
chat/message identifiers before publishing Saved status.

Put versioned content identities in captions/manifests; maintain a local index.
For recovery, paginate [getChatHistory](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chat_history.html)
using the cursor. It may return fewer than the requested maximum while more
history remains. Never assume a short page is end-of-history. Reconciliation
covers this app's managed archive; arbitrary older uploads are not automatically
identified as duplicates.

The cloud Bot API has lower practical file limits; running a local Bot API server
adds infrastructure. Direct TDLib avoids that tradeoff for this personal app.
Telegram private cloud channels are not end-to-end encrypted. Optional client
archive encryption would require a separate recovery/key design.

Official [iOS build instructions](https://github.com/tdlib/td/blob/master/example/ios/README.md)
warn about paths containing spaces. Our workspace has spaces: build the dependency
in a dedicated no-space temporary path, then copy the pinned XCFramework artifact.
Produce only needed device/simulator slices; record source SHA and dependencies.
Prove packaging, sign-in, logout/reconnect and a physical-device upload first.

## Background and efficient scheduling on iOS 26

Apple's [WWDC25 background guidance](https://developer.apple.com/videos/play/wwdc2025/227/)
introduces continued processing for work explicitly initiated by the user. Use it
for a finite Back Up batch, report progress, and handle expiration/cancellation.
It can support the CPU/network work TDLib needs after backgrounding. Scheduled
automatic backups use BGProcessingTask instead. Runtime remains system-controlled.
Google's existing background URLSession transfer remains useful independently.

The newer [PhotoKit background resource upload](https://developer.apple.com/documentation/photokit/uploading-asset-resources-in-the-background)
is an additional research candidate on compatible OS/SDK versions. It can handle
resource acquisition/upload and requires physical-device testing. Do not add an
extension to v1 until signing and protocol fit are proven. In particular, Google
needs an opaque receipt body for finalization; documented upload-job headers alone
do not establish that our adapter can recover that receipt. TDLib's native
transport is not a drop-in HTTP upload-job destination.

Use [persistent PhotoKit changes](https://developer.apple.com/documentation/photos/phphotolibrary/fetchpersistentchanges(since:))
plus local records to avoid full export/hash scans each launch. Advance a change
token only after applying changes transactionally; invalid token triggers a bounded
rescan. Initial enumeration is required. Limited permission must restrict totals.

One export worker; one active upload per provider initially; shared staging;
streaming SHA-256 and Google SHA-1; bounded disk/RAM. Measure throughput, thermal
state and errors before increasing concurrency. Two cloud copies inherently send
two copies of the data. Never add a speculative backend to avoid that constraint.

Enforce Wi-Fi policy across both transports and on mid-upload network changes.
TDLib exposes [setNetworkType](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_network_type.html)
and [networkTypeNone](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1network_type_none.html);
test actual stop/resume behavior rather than only preventing new jobs.
Respect server delays, use bounded retry/backoff, and pause only the affected
provider for rejected credentials or quota. Checkpoint unknown outcomes and
reconcile before resending. Foreground completion and safe restart are mandatory.

## Implementation order and architect review budget

1. Feasibility spike: pinned Google baseline, quota/original evidence, TDLib
   framework/auth, Live Photo resource export and provider behavior on signed iPhone.
2. Queue and ledger: explicit resource obligations, confirmed receipts, policy
   snapshots, account isolation, deduplication, retry/reconciliation tests.
3. Dual-provider scheduler: shared stage, independently progressing adapters,
   metadata/manifests and large-file recovery.
4. Minimal SwiftUI status screen using STATUS-SPEC.md; setup and small settings.
5. iOS 26 continued processing, interruption tests, packaging and signed IPA.
6. Optional verified native-pairing/remux improvements and compatible upload
   extension, after ordinary uploads and recovery pass.

Each builder batch supplies: intent, changed files, focused diff, checks/results,
redacted evidence and unresolved issues. Architect reads critical auth/protocol,
export, database transactions, completion/retry state and background/signing code.
Routine UI formatting can be reviewed from summaries and device screenshots.
No simultaneous edits to the same files. No future batch before failed gate fixes.

For progress events, prefer one scheduler owner with serialized ledger mutations.
Adapters report capabilities, transfer progress, durable receipts and classified
errors; they do not increment UI totals. Media export, ledger, Google adapter,
Telegram adapter, scheduler and UI remain distinct modules. Avoid a generic plugin
framework or dependency injection system larger than these concrete requirements.

Builder report template: batch identifier; objective; changed paths; source/dependency
revisions; exact checks and outcomes; physical-device evidence; failures/risks;
next proposed batch. Attach focused diffs for the critical modules. This makes
review inexpensive without delegating correctness to a summary alone.

## Required evidence before calling the app reliable

- Physical sideload, app relaunch and credentials retained; no secrets in logs.
- Google fresh-batch quota + downloaded-original checksum/metadata results.
- Telegram downloaded documents match; split parts reconstruct identical bytes.
- Live Photo pair extraction; native pairing or accurately labeled fallback.
- Rerun transfers no already-confirmed bytes; duplicate local IDs/album overlaps.
- One provider fails while the other completes; retry only missing obligations.
- Lost final response, offline, rate limiting, cancellation, restart/force-quit,
  iCloud-only source, low disk, network policy change and expired authentication.
- Correct STATUS-SPEC counters through all above failures and after restart.
- Reinstall can rebuild managed Telegram receipts from captions/manifests/history;
  Google reconciliation checked before claiming an item is new.
- Real-device small/large fixture memory, disk, battery and throughput measurements.

Simulator UI checks complement these tests but cannot prove signed-device
background behavior, service quota accounting, or original preservation.
