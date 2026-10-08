# P4-B — Architect critical provider integration

Assigned to Architect after R2 source review/direct corrections, 2026-10-08.
Builder has no new implementation assignment. No R3 handoff is required for the
completed foundation fixes. R2 is closed for implementation handoff only: iOS/native
linking, services, originals, runtime bounds and reinstall behavior remain untested
until P7. This file records the assigned implementation contract. Architect source/compiler
completion and P5/P6 integration limits are recorded in [P4-B-INTEGRATION](P4-B-INTEGRATION.md).

## Foundation APIs and limits

- TDLibClient.start() prepares canonical protected profile storage, starts the
  owned native session and sends getAuthorizationState as its real first request.
  The pinned ABI emits no updates before a first request. Auth responses/updates
  establish actual wait-parameters state before initialization. Typed auth states
  include email, code, other-device, premium and registration requirements.
- One mapped Telegram native session may exist at a time. The receiver strongly
  owns its session handler until genuine native closed acknowledgement. Creation
  waits for a retiring receiver task; close joins outside receive callbacks.
  Do not initialize replacement accounts while native ownership is unresolved.
  Google's separate worker/session remains concurrent with Telegram.
- Native JSON is capped at 256 KiB, 4,096 converted values, depth 32. Session caps:
  16 requests, two subscribers, 16 buffered updates/subscriber, 32 tracked files.
  Use small paged history (start <=10 messages), no full-library arrays or media
  downloads. Oversized/malformed input and stream overflow fence the session and
  require reconciliation; they never establish absence. Large media uses file
  paths/native file I/O, not JSON payload bytes.
- Progress flags changing active/inactive/completed are immediate control updates;
  only unchanged active intermediate progress is coalesced. One bounded timer
  flushes latest values even when callbacks stop. Closed acknowledgement precedes
  successful stream completion; diagnostic/delivery faults finish with errors.
- TDLibClient.updates() yields AsyncThrowingStream. Check requiresReconciliation
  before commands. Retain transport ownership on uncertainty; restart/reconcile
  only after actual native close. Persistence failures are not transfer rejection.
- GooglePhotosClientSession accepts the real FileUploadTransport and shared network
  policy. Preserve PhotosBackup original/non-quota wire fields and autoreleasepool.
  Google disconnect is async throws. Auth/server prose stays outside public logs.

## Implement directly, in coherent batches

Read relevant CORE-INTEGRATION, RELIABILITY, RUNTIME and current source contracts.
Claim exact edited paths in handbook 3; Core/protocol corrections belong to Architect.

1. Verify actual account/channel identities and permissions, freeze Destination
   scopes and mapping generations, and bind private profile references. Never use a
   profile label, editable account display name or claimed login as identity proof.
   If the selected protocol cannot establish required evidence, expose a concrete
   blocked state; do not invent identity/absence proofs to satisfy an interface.
2. Implement Google ProviderAdapter against the pinned hash/prepare/transfer/commit
   methods. Persist durable transfer/checkpoint/finalization evidence before exposing
   confirmation. A received upload body is not a confirmed final media item. Unknown
   responses reconcile by the same content/account scope before any replacement send.
3. Implement Telegram document sends, send-success/failure correlation, native file
   ownership and strict caption/manifest parsing. Temporary message IDs, uploaded
   bytes and updateFile completion are not final saved receipts. Preserve original
   files and reconstructable multipart/Live Photo manifest associations.
4. Implement complete paged private-channel/history reconciliation and a durable
   bounded index. Require matching destination, content/recipe, validated final
   message identities and settled pending native sends before verifiedAbsent.
   Missing/error/partial history and malformed manifests return Unknown/blocked.
5. Connect actual Core ProviderAdapter outcomes, safe failures, retained/terminal
   input ownership and checkpoint recovery. Keep the three parent-asset attempts
   in the ledger; no second retry counter in adapter loops. Both workers must run
   concurrently and failures stay isolated by destination.
6. Inject durable whitelisted diagnostics with destination/job/component context.
   Confirm before Saved counts; preserve known component receipts across retries
   and reinstall. Hand off a real API map for P5 presentation/P6 lifecycle wiring.

No demo data, mock service/runtime tests, real account uploads, cloud IPA dispatch
or local/USB SDK/native builds during implementation. Necessary compiler/static/
source/schema checks only. The native recipe now includes an all-member device
link/platform validation gate for the first P7 assembly, without executing its
link-only executable. No native-link evidence exists yet. Commit/push coherent
changes; update the shared evidence/decisions and mark untested milestones honestly.
