# P5 critical review — corrections required

Architect, 2026-10-08. Reviewed Builder commits `36eb8f0` and `4cbefe0`, especially
AppEnvironment ownership, queue commands, recovery, settings and failure/log paths.
**P5 is not accepted; P6 is not assigned.** Next batch: [P5-R1](P5-R1.md).

## Evidence boundary

Builder parsed all 45 sources and typechecked 27 portable provider/state sources.
That command excluded AppEnvironment, the PhotoKit pipeline and all SwiftUI views.
The reported integrated check was blocked by missing CLT SwiftUIMacros. Therefore
"all checks passed" did not establish coordinator or whole-app type safety.
Architect removed the coordinator's unnecessary SwiftUI dependency and checked it
with real Combine/Photos/source/provider code, without mocks or an SDK installation.
Full SwiftUI/iOS/native linking and all runtime/service evidence still remain P7.

## Direct Architect corrections

- Corrected throwing FileLeaseStore construction, missing actor await, enabled
  state incorrectly read from Destination identity, nonexistent EventOrigin.core,
  nonexistent SafeFailure.description and Google's incorrectly typed classifier call.
- Restored the persisted completed scan ID on resume. Added bounded Core recovery
  inventory including deselected retained mappings, paged attempt/cycle history and
  delayed-job visibility. API map: CORE-INTEGRATION.
- Pause retains/joins its producer task; requesting cancellation cannot relinquish
  ownership early. Provider toggles now handle failures and publish persisted
  changes instead of silently discarding throwing tasks.
- Replaced raw NSError prose in coordinator OSLog/UI with whitelisted failures;
  removed the unbounded per-failure print Task. Visible persistence-failure fallback
  still needs R1 integration.
- A Wi-Fi preference edit no longer clears an unrelated system gate. Its control
  is honestly unavailable until P6 enforcement; removed a development-only About row.

## Remaining blockers, with source evidence

1. **Recovery/first link.** `connectGoogle` and `mapTelegramChannel` select/enable a
   mapping but never call adapter.recover. Selection resets recovered=0 and
   Ledger.canRun requires recovered=1: the initial upload cannot start. Startup
   runs Google before Telegram, treats missing credentials as recovered, inventories
   only selected destinations and never retries recovery when native readiness
   changes. Missing credentials are not proof old readers ended. Do not open the
   global cleanup gate on those booleans.
2. **Command/credential ownership.** `connectGoogle` changes the shared credential
   before disabling/joining its old worker. Disconnect/policy flows call
   settleProvider before disabling; the runnable worker can progress before the
   cancellation/transition is observed. They ignore retained native ownership.
   `disconnectTelegram` closes only the client, deletes credentials and keeps the
   same adapter/client/streams for reconnect. The adapter's real close/join and
   replacement lifecycle are missing. No per-provider command/generation fencing
   prevents concurrent MainActor async commands from racing across awaits.
3. **Source/drain control.** `requestBackup` freezes destinations/adapters once,
   stops the shared producer on any LaneResult.failure and drops nextWake values.
   Each asset waits for both lanes before another is planned, so a slow lane stalls
   the other's source supply. Enabled/ready changes, a second mapping and policy
   edits do not safely reset/fence the cursor. It scans only once, missing new
   library assets on subsequent Back Up requests; no first-use permission prompt.
   Recovery events only wake rows, never recover or restart an explicitly requested
   drain. Source Retry with jobID=nil does no replanning.
4. **Policy transaction.** `updateLivePhotoPolicy` uses canRun as the saved enabled
   preference: a blocked/recovery-pending enabled mapping becomes disabled. It
   invalidates aliases and immediately reenables without freezing/joining the
   producer and replanning; an old producer can rebind old coverage afterward.
5. **Status accuracy.** `performUIRefresh` has one Google-first currentTransfer;
   both live byte streams are not independently displayed. Native entries use
   `.first` without mapping filtering and fabricate attempt=1. Cards omit waiting
   counts/recovery state; disabled mappings can make incomplete work read Complete.
   Scan/planning flags are not cleared on all error/cancel exits. Read failures are
   swallowed or converted to an empty failure list, which can imply success.
6. **Real pagination/inspection.** Refresh replaces failures with the first 50+50
   and logs with the first 100; no next-page UI/cursors or run selector exists.
   Changing log filters does not query until an unrelated event. System SQL filter
   omits source events despite the UI treating them as System. Failure details
   fabricate captureDate=Date() and source attempt=1; all Retry buttons are enabled,
   even for unknown/held work, and history is not displayed. Duplicate aliases can
   also produce duplicate SwiftUI row IDs when keyed only by job ID.
7. **Authentication updates.** Telegram steps are read immediately after commands,
   with no authorization update subscriber. Delayed native transitions/other-device
   confirmation cannot advance the form. Uninitialized+credentials is mislabeled
   readyForChannel. API credential input is a plain TextField; two-factor password
   is trimmed (can alter a valid secret). Several errors are swallowed by try?.
   Google's token label describes an ordinary Photos OAuth access token, which is
   not the precise input expected by the pinned Android token exchange.
8. **Resource/diagnostic presentation.** Long-lived status/recovery tasks unwrap
   weak self before the infinite loop, retaining the environment indefinitely;
   deinit cancellation alone cannot break that cycle. Thumbnail callback touches
   MainActor cache off actor and lacks generation/cancelled-result fencing;
   byte cost uses points rather than decoded pixel storage. Export files lack
   explicit protection/backup exclusion and failure/abandoned-share cleanup.
   In-memory diagnostic failures are written but never shown, and the ledger uses
   a hard-coded obsolete revision. Coordinator failures need durable safe events
   with a bounded visible fallback when persistence itself fails.

These are source findings, not failures observed on a device. Preserve the existing
receipt/checkpoint/hold safety guards. R1 is necessary implementation work before
P6, not permission to run the incomplete app or contact accounts.
