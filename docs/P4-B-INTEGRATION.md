# P4-B provider implementation and P5/P6 integration map

Architect, 2026-10-08. Source implementation with local Swift 6 compiler/static
checks only. No native/iOS build, service/account upload, device, quality, quota,
reinstall or background evidence. These APIs do not make the current shell a
working backup app; P5 composition and P6 lifecycle integration remain required.

## Files and responsibility

- Core `ProviderPersistence.swift`: private immutable profile/scope bindings,
  durable component/transfer checkpoints, paged retained-transfer inventory,
  disk-backed remote document index and persistent transport copy reservations.
  SQLite v3 preserves existing jobs, attempts, receipts and source recipes.
- `GooglePhotosProviderAdapter.swift`: actual Core ProviderAdapter; same-token
  verified account scope, original/non-quota preparation/PUT/commit, durable
  per-component finalization and exact-scope hash reconciliation.
- `ForegroundFileUploadTransport.swift`: owned URLSession requests/file readers,
  <=1 MiB response body, cancellation through real task completion, no redirects,
  one operation per transport. HTTP/auth work uses <=120 s resource timeout;
  foreground media uses <=3,600 s. No whole-media Data or retained completed tasks.
- `TelegramProviderAdapter.swift`: actual Core ProviderAdapter, one TDLib update
  consumer, <=8 retained sends, correlation before dispatch, final message
  confirmation, late receipts/rejections, paged document history and recovery.
- `TelegramDocumentReference.swift`: strict versioned caption/final-document
  identities. Uploaded bytes/temporary IDs are never saved receipts.
- `TelegramInputFiles.swift`: protected original-filename hard links in our
  staging root; remove only the exact terminal transfer directory. Unknown
  native ownership keeps these links and the Core holds.
- `ProviderSupport.swift`: safe failures, canonical scope hashes, cancellable
  joined utility hashing and one latest-value progress consumer per upload.
- `ArchiveManifestBuilder.validate`: <=1 MiB manifest-v2, recipe/tag validation,
  exact reference coverage and complete contiguous lossless part associations.
  Reconciliation additionally checks every referenced final remote document.
- `Ledger.invalidateCurrentCoverage`: disabled/settled mapping only, clears
  current scan aliases/source failures, retains historical jobs/receipts/attempts.

## Mapping and startup sequence

Create one real Ledger/FileLeaseStore/PhotoLibraryPipeline/BackupEngine for the
app. Supply the same Ledger and FileLeaseStore to both providers. Inject the
existing durable diagnostic sink into GooglePhotosClientSession and TDLibClient;
never install a logging closure that silently discards persistence failures.
Scope bindings/checkpoints/native paths/opaque references are PRIVATE; do not
include them in diagnostic export or public Git history.

Google: create a protected Keychain profile, then loadSavedSession or connect
with the actual acquired credential. Construct GooglePhotosProviderAdapter and
call mapVerifiedAccount. The Photos token calls Google's HTTPS OpenID userinfo;
`sub` defines the immutable scope. A claimed email/imported label never proves
identity. The account must also pass the pinned hash-read capability check.
Unsupported identity verification blocks the mapping (identityUnverified), rather
than silently using an email. No user account was contacted during development.

Telegram: persist real API credentials, start TDLibClient and complete its actual
native auth state machine. `authorizationStateReady` and actual synchronized
`connectionStateReady` are separate prerequisites. Construct TelegramProviderAdapter
and call mapVerifiedChannel(chatID:). getMe/getChat/getSupergroup/full-info must
establish a regular user, owned private channel, creator membership and zero
message auto-delete. Public/shared/member-only channel mapping is deliberately
blocked (privateChannelRequired). P5 must state this setup requirement clearly.
Names are labels; verified user/channel IDs define identity.

For existing mappings, reuse the stored profile reference and real credential;
call each adapter's recover(destination), independently. Google foreground readers
cannot survive process death, but a possibly accepted commit stays uncertain.
Telegram reads actual retained message state; it can rediscover a response-less
pending send only through its exact owned local input path. A missing correlation
is pendingSendUnmatched, never permission to resend. Complete paginated history
and settled native readers precede completeDestinationRecovery. One provider's
recovery failure must not stop recovery/operation of the other.

Only after inventory of BOTH providers/source writers is reconciled call
FileLeaseStore.completeStartupInventory. It is not a UI convenience flag. Do not
clear holds/reservations or sweep files to get past a recovery blocker. Persisted
transport reservations protect conservative additional copy space across crashes.
A protocol that cannot prove acceptance or absence exposes a concrete waiting
state; this implementation does not promise every ambiguous service failure can
be automatically resolved.

## Upload, originals and receipts

Call BackupEngine.runReadyBatch with BOTH adapters in the same batch and the real
PhotoLibraryOriginalPreparer. The existing core creates both workers before
awaiting results. Do not add provider drains, adapter retries or local Saved
counters. Attempts belong to the parent job/provider; confirmed components survive.

Google uploads verified unchanged bytes, original filename and capture date,
with PhotosBackup `useQuota=false`/`saver=false` and unchanged original-quality
wire fields. SHA-256/SHA-1 verification runs once off the actor before preparing.
The receipt/committing fence is durable BEFORE finalization; a PUT response alone
cannot confirm media. Ambiguous commits are queried in the same account/content
scope; no blind replacement commit/send. A known completed still can be reused
while a missing motion is retried. Server Retry-After is propagated.

New Live Photo default: nativePair, distinct frozen google-live-nativePair-v1
coverage containing both unchanged originals. It requests pinned motion pairing
and requires both hashes to identify the same final media item. The protocol's
ability to satisfy this check is UNVERIFIED. pairingUnverified exposes the problem;
P5 offers explicit both-separately/key-image/motion-video alternatives. Never
silently lower quality or change coverage after a rejection. Existing separate
coverage tags/policies remain unchanged. Telegram always archives all originals,
including motion and reconstruction metadata, independent of Google fallback.

Telegram uses the exact pinned nested inputDocument schema, local file input and
disable_content_type_detection. No photo/video conversion, thumbnail or generated
media is sent. The app hard-links a leased original under its actual filename;
parts get an explicit part suffix. Manifests use Cloudified-manifest-v2.json.
Native media/cache copy cost remains a conservative one-original reservation,
not a measured guarantee. P6 cache controls and P7 measurements remain required.

Send registration/checkpoint precedes native dispatch. updateMessageSendSucceeded
or an actual final Message plus validated getMessage readback establishes a
receipt. A native request Error is distinct from a bridge timeout/cancellation:
at the pinned Requests.cpp/MessagesManager.cpp send_message implementation it
returns before enqueue/save-log/do_send_message. Local document/no-thumbnail
rejection has no upload reader and can safely advance. Send-failed updates also
require actual failed state and inactive file ownership before release. Unknown
outcomes retain input, wait for real late updates and do not trigger a resend.
Late confirmation is committed to the original immutable job; late rejection
wins over an older uncertain worker result within the Ledger transaction.

## Reconciliation and bounds

Telegram's server-backed searchChatMessages/document filter is paged <=10. Only
its explicit next_from_message_id=0 establishes traversal completion; short
pages/approximate total_count never do. Every cloudified-v1 marker is parsed
strictly. An incomplete/changed/oversized history, connection transition, delivery
gap, malformed caption/manifest or missing referenced message yields Unknown.
The SQL index holds full history on disk, with bounded page/lookup memory; it has
no small-library cap. Each process starts a fresh epoch. Connection/deletion/edit
updates invalidate the epoch. The synchronized native connection is checked before
absence is exposed. Native pending work for that tag additionally prevents absence.

Manifest reconciliation downloads only the matched <=1 MiB document, validates
its canonical recipe hash, all parts and final references, and checks every linked
message in the same channel. Native downloaded paths must be canonical protected
TD cache files; stale/outside paths block rather than reading arbitrary files.
File IDs may change on reinstall; persistent remote unique IDs/message IDs matter.
No media gallery, full photo/video download or whole-library array is introduced.

## P5 presentation and P6 lifecycle hooks

- Ledger/Engine snapshots supply counts. Remaining includes unresolved/unplanned
  assets; native byte completion never changes Saved. Photos/videos remain separate.
- Merge EngineSnapshot.active with Telegram nativeTransferSnapshot by job/mapping.
  A retained native send may still upload after its Core worker returns. Display
  actual bytes and awaiting-acknowledgement/uncertain states independently.
- Telegram statusEvents is one bounded UI invalidation stream; it does NOT start
  backups. recoveryEvents is the coordinator's bounded terminal/reconnected signal
  for a requested recovery/drain. Each stream has one coordinator consumer.
- ProviderProgressPump joins on return; native session progress is already bounded.
  Do not turn source/network callbacks into one unbounded Task per chunk.
- Unlink/change mapping: disable, settleProvider, inventory retained inputs, close
  native ownership where required, then change credentials. An unresolved Telegram
  profile/database key must remain recoverable. Never delete remote content.
- Coverage change: disable/settle, invalidateCurrentCoverage, persist the explicit
  new policy, reset the planning cursor, replan bounded assets, then resume if the
  user enabled it. A planning failure cannot leave old coverage counted as Saved.
- Initial Google adapter accepts ONLY terminal foreground transport. Injected
  continuesAfterProcessExit transports are blocked until Architect P6 supplies
  durable OS-task inventory/ownership semantics. Builder must not remove this
  guard or invent a background session. iOS 26 lifecycle/continued processing,
  allowed network policy, native pause/expiry and idle cache maintenance remain P6.

## Source evidence and remaining acceptance

Exact source pins remain unchanged. Vendored Google digests are refreshed, with
patch provenance in dependencies/google-vendor.json. OpenID subject semantics:
[Google OpenID Connect documentation](https://developers.google.com/identity/openid-connect/openid-connect).
Identity availability with the selected mobile token is a P7 service question.
Telegram request/cursor/state/input schemas and synchronous enqueue boundary were
read directly at pinned TDLib 42e6a5259551178d1dab54a22ad96d14bd906e20.

P7 must verify true concurrent operation, native/iOS linking, real auth, original
HEIC/JPEG/HEVC/HDR/video/Live Photo bytes and external metadata, Google pairing and
storage accounting, all crash/late-reply/reinstall/cancellation races, stale cache
paths, hard-link behavior, memory/disk/cache peaks and server history freshness.
No universal cross-device/concurrent-external-writer deduplication guarantee is
asserted: neither destination offers this app a content-key conditional write.
