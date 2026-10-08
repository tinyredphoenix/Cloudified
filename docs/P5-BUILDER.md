# P5 — Builder presentation/composition assignment

Architect assignment, 2026-10-08, after P4-B source/compiler handoff. Implement P5
only. No tests, simulator/device/account runs or cloud IPA dispatch before P7.
No demo/mock/seeded records. P4-B source is not proven service/device behavior.

## Read and claim

Read README, AGENTS, P4-B-INTEGRATION, relevant CORE-INTEGRATION presentation/source
contracts and STATUS-SPEC. Claim exact paths in handbook 3 before editing.
Allowed: App/Application/, App/Presentation/, focused composition/settings helpers
under App/Adapters/System/, Xcode project/generator only when adding source files,
and your appended build-log entry. Core, provider/auth/native internals and
handbooks 1/2/4 remain Architect-owned. Do not remove provider safety guards or
replace their checkpoints/receipts/attempts with presentation flags.

## Deliverable

1. Replace the shell's disconnected coordinator with one real protected
   StorageLayout/Ledger/FileLeaseStore/PhotoLibraryPipeline/BackupEngine composition.
   Load actual selected mappings/private profile bindings and non-secret settings.
   Inject a persistent diagnostic sink into both real client sessions. Surface
   persistence failures safely in memory/OSLog when the database cannot record them.
2. Build real independent link/reconnect/unlink/change-channel flows. Google uses
   secure user-provided login-token input calling GooglePhotosClientSession.connect,
   then mapVerifiedAccount. Label this actual flow clearly; no fake OAuth success,
   credential dumps, invented browser login protocol or hard-coded private token.
   Existing stored credentials use loadSavedSession. Telegram uses real stored API
   credentials and native phone/code/password states; additional native email/other
   device/premium/registration requirements must be displayed truthfully, with real
   applicable schema commands or a specific action requirement, never auto-Ready.
   For initial Telegram mapping require an owned private channel with auto-delete
   disabled. Read actual chat/account data for labels; immutable IDs define mapping.
3. Run each provider recovery independently. Failure in one must leave the other
   operable. Startup file cleanup remains gated until all real writer/transport
   inventory is established. Retained native work must remain owned by a live
   coordinator. A recovery blocker never authorizes deleting files/profile keys.
4. Implement Back Up, Pause/Resume, provider enable switches and explicit Retry
   commands against the real APIs. Both adapters go into ONE runReadyBatch; never
   await an entire Google drain before starting Telegram. Use bounded producer
   credits/one-asset source planning with already completed metadata scan, interleave
   ready transfers, and retain canonical IDs/cursors. Do not hash/export all originals
   before starting uploads or create a second retry loop/database.
5. Dashboard: actual overall activity; separate Google/Telegram remaining out of
   total, Saved/failed/waiting counts, both active transfers and current bytes;
   Photos and Videos sections; actual saved-to-both intersection. Merge retained
   Telegram native status by job/mapping so ongoing native bytes remain visible
   after a worker timeout. Never count bytes sent/temporary IDs as Saved. Filter
   old mapping work correctly; show settling old mapping explicitly when needed.
6. Wire Not uploaded to paged actual source/job failures, provider-specific cause,
   code/action, retry-cycle history and explicit Retry. Small cancellable row
   thumbnails only, <=100 cached/16 MiB, visible rows only. No gallery/playback or
   full-screen media view. Unknown acceptance stays a reconciliation state.
7. Wire Logs to paged real Ledger events, All/Google/Telegram/System, severity/run
   filters, useful safe descriptions and redacted streaming JSONL export. Protect
   temporary export files, remove after sharing. Do not expose opaque references,
   profile scopes/paths, filenames, credentials, raw responses or GPS in logs.
   Map identityUnverified, pairingUnverified, pendingSendUnmatched,
   privateChannelRequired and accountChanged to distinct understandable explanations.
8. Persist the selected Live Photo policy; new default is nativePair. Alternatives
   are both originals separately/key image only/motion video only, explicitly for
   GOOGLE. Telegram continues full-original archive coverage. A coverage change
   disables/settles that provider, calls invalidateCurrentCoverage, freezes new
   policy, resets/replans the bounded current scan and resumes only if enabled.
   Old coverage must not conceal a failure to plan the new selection.
9. Subscribe once to bounded ledger invalidation and native statusEvents; refresh
   UI <=2 Hz, cancel on teardown. Status events must not trigger backups. The
   separate recoveryEvents stream is for coordinator recovery/requested drain
   wakeups. Preserve correct source/progress/cleanup ownership and no empty-batch
   invalidation loops. Both providers' errors/status remain independent.
10. Keep P6 lifecycle entry points explicit: allowed network/Wi-Fi gate, foreground
    transitions, background expiration, retry deadlines, retained native inventory
    and idle cleanup. P6 supplies actual iOS 26/background/OS-task semantics; do not
    claim unimplemented behavior as working or remove Google's background guard.
    Any control awaiting a real P6 binding must show its genuine availability/state.

## Report and stop

Use necessary source/compiler/syntax/provenance checks only. Do not install Xcode,
run the app, contact user accounts, seed data or dispatch Actions. Preserve manual
build/cache setup and upstream licenses. Append files, API use, checks, unresolved
integration points and P6 handoff to handbook 3. Make coherent commits and push.
Only tag if the annotation accurately says source/untested. Report to the user;
Architect reviews critical coordinator/ownership diffs before P6 assignment.
