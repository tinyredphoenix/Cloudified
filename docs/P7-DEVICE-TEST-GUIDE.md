# P7 — first iPhone test guide

Architect-owned documentation batch, 2026-10-08. Reserved paths for this batch:
this guide, `P7-TEST-RESULTS-TEMPLATE.md` and the README test-guide link. No app
changes, test data, account operations or additional build dispatch. Builder's
reserved build-log/workflow paths are unchanged.

The published baseline is **Cloudified 1.0 (6)**, built from
`683668e4f381bb605da420c1315c3e6d8be65c20`; see [distribution evidence](DISTRIBUTION.md).
Compilation/package/publication passed. Every device/service check below remains
**NOT RUN** until evidence is recorded. Older planning documents saying no IPA
exists describe an earlier checkpoint. This guide does not certify working uploads.

## Before starting

1. Copy the [blank results template](P7-TEST-RESULTS-TEMPLATE.md) into a private
   folder outside either public repository. Use aliases for assets/accounts/channel;
   keep photos, tokens, log exports, crash reports and screenshots private.
2. Install through the [SideStore source](https://raw.githubusercontent.com/tinyredphoenix/Cloudified-Source/main/source.json).
   Record the installed About version/build, iPhone model, exact iOS version,
   available storage, Wi-Fi, Low Power/Low Data Mode, battery and time zone.
3. Use iOS **limited Photos access** to select about 12–20 existing real assets.
   Cloudified scans accessible Photos, not a selectable album inside the app.
   Keep the first selection small; expand only after integrity checks pass.
4. Include HEIC, JPEG, a PNG screenshot, Live Photos and ordinary videos. Include
   HEVC/HDR/4K, an edited item and an iCloud-only original if already available.
   RAW/ProRAW, slow motion, Cinematic, bursts and unusual imported formats need
   separate evidence if present; mark missing types NOT RUN rather than claiming
   universal format support. Reserve a few existing assets for later additions.
5. Record the number of Photos assets and standalone Videos assets. A Live Photo
   counts as one photo asset with two original components, not an extra video asset.
   Note originals already present remotely; ideally include previously unbacked items.
6. Use your intended Google account and an owned private Telegram archive channel
   with auto-delete off. Record aliases and current Google storage usage. Pause
   other automatic uploaders during the observation window so upload attribution
   is clear; note and restore any settings you change afterward.

Keep Apple originals and existing cloud records. No cloud deletions are needed.
Do not deliberately fill storage or overheat the phone to generate failures.

## First session — follow this order

For every test, record PASS / FAIL / BLOCKED / NOT RUN plus evidence. BLOCKED means
a prerequisite prevented the check; NOT RUN includes a failure condition that did
not occur. Passing a nearby scenario does not establish an unexercised one.

For your requirement to preserve all original components on both destinations,
keep **Both originals separately** unless native Google pairing is verified.
Key-image-only and motion-only are deliberate Google coverage reductions; a Saved
label under one of those policies does not mean both Live Photo components are there.

| ID | What to do | Expected result / evidence |
| --- | --- | --- |
| T01 Install and empty state | Add the source, install, launch, visit all four screens and Settings > About. | Correct icon, version 1.0 (6), responsive navigation, genuine disconnected/unscanned states; no sample accounts, progress or logs. Record source/signing/install errors separately from app errors. |
| T02 Photo permission | First decline Photos access if prompted; then allow the small limited selection through iOS Settings and start/rescan. | Denial has a readable source/access reason. Counts describe only the accessible scan and its scope; denied access never looks like successful backup of the entire library. |
| T03 Connect Google | Settings > Sign In with Google > enter your PhotosBackup login token > Connect with Token. | Account identity verified and displayed correctly, or a separate actionable Google error. This build requires the `oauth2_4…` PhotosBackup login token, not a generic Google Photos OAuth access token. Never paste it into a report. If obtaining/verifying it blocks you, record that exact setup blocker. |
| T04 Connect Telegram | Connect Telegram > API ID/API Hash > Save & Initialize TDLib; complete phone/code/2FA as requested. Enter the numeric Channel Chat ID > Verify & Map Channel. | Correct account/channel displayed. An owned private channel with no auto-delete maps; unsuitable mapping is rejected clearly. Obtain your API credentials using [Telegram's official instructions](https://core.telegram.org/api/obtaining_api_id). Missing channel-ID discovery is a setup usability issue to report, not an instruction to invent an ID. |
| T05 Real dual backup | Enable both providers and Wi-Fi Only. Set Live Photo Fallback to **Both originals separately** for the first preservation run. On normal-temperature Wi-Fi, tap Back Up and stay foreground. | Both lanes start in the same batch; one never waits for the other's entire library to finish. Capture dashboard during transfer and after completion, plus exported logs. A short batch may finish too fast to observe simultaneous cards; use a real longer video/log timestamps before judging concurrency. |
| T06 Status accuracy | Compare selected total, Photos/Videos breakdown, each provider's confirmed/remaining/failed/waiting and saved-to-both against observed assets. | No missing videos. During a stable scan, each provider's remaining = total minus confirmed; failed/waiting are within remaining. Saved-to-both is the asset intersection, not the sum or automatically the smaller count. Bytes at 100% may still be Finalizing; Saved requires durable remote confirmation. Unknown sizes/speed/ETA remain unknown. |
| T07 Original quality | Download originals from both destinations and compare with the matching source originals using the method below. | Exact byte lengths and SHA-256 match for each required component; formats, embedded metadata and video characteristics survive. Google preview quality or Telegram thumbnails do not prove this. Do this before expanding the selected library. |
| T08 No-op repeat | With the same selection, mappings and Live Photo policy, tap Back Up again; close/reopen normally and repeat. | Existing confirmed content is not sent again. Reconciliation/API traffic is allowed. Counts remain consistent and cloud content has no extra copies. Record before/after remote evidence and logs. |
| T09 Incremental addition | Add one reserved existing photo to limited access; Back Up. Then add one existing video; Back Up. | Each addition increases accessible total appropriately and uploads only missing required content to both. Previously saved assets stay saved. Record old/new totals and cloud receipts. |

If an upload/quality blocker appears, export evidence and start P8 debugging before
attempting the dependent checks. One destination can still be tested independently;
do not mark the blocked destination or dual concurrency PASS.

## Verify originals and metadata

Use matching **unmodified source files**, including video originals, as the
reference. In Mac Photos, File > Export > Export Unmodified Original preserves
original format; a Live Photo exports a still and a video. Avoid a rendered/converted
export when checking bytes. See [Apple's export instructions](https://support.apple.com/guide/photos/pht6e157c5f/mac).
If this Mac does not contain the same originals and you cannot obtain them without
conversion, mark byte verification BLOCKED and record how the reference was obtained.

Download Google files from photos.google.com using More > Download, following
[Google's instructions](https://support.google.com/photos/answer/7652919?co=GENIE.Platform%3DDesktop&hl=en).
Download the Telegram **document**, not its preview or a re-saved image. Keep each
provider's files in a separate private folder. For each original/component run:

```sh
shasum -a 256 '/absolute/path/to/the/file'
stat -f '%z bytes' '/absolute/path/to/the/file'
```

Record source/Google/Telegram byte lengths and hashes, component role, dimensions,
video duration/codec/HDR where applicable, orientation and embedded capture time.
Verify the small first batch in full if possible; at minimum cover every available
format and both Live Photo components. Missing verification stays explicit.

Separate embedded metadata from Photos-library-only information such as albums,
favorites and subsequent date/location edits. Record what is embedded, what the
provider displays, and what an archive manifest preserves; do not promise a Photos
library clone. An edited asset's underlying original can differ from its rendered
appearance. A downloaded file's filesystem creation/modification date can change
without its embedded capture metadata changing, as Google documents above.

Check Google storage usage again after service accounting has settled, with the
observation time and other account activity recorded. Also inspect any available
quality/quota labels. No observed small storage delta is **not proof of permanent
unlimited storage**, and a label alone is not proof of original bytes.

## Second session — controls, interruptions and diagnostics

Use newly admitted real assets where actual transfer is needed. Retain the original
selection and receipts for later duplicate/reinstall checks.

| ID | What to do | Expected result / evidence |
| --- | --- | --- |
| T10 Pause/Resume | During a longer transfer, Pause, observe settling, then Resume. | New work stops; in-flight/unknown outcomes settle or reconcile honestly. Resume preserves confirmed work and attempt budgets; no duplicate content. Capture before/pause/resume states. |
| T11 Independent switches | Disable Google during a batch; let Telegram finish. Re-enable Google and complete its backlog. Repeat with Telegram disabled. | Healthy enabled lane continues, disabled backlog/receipts survive, and re-enabling sends only missing obligations. Settling callbacks may still arrive. This checks controls, not provider-failure isolation. |
| T12 Connectivity | With Wi-Fi Only on, remove Wi-Fi while cellular remains available; then restore Wi-Fi. Separately test airplane mode before Back Up and during transfer. | Appropriate waiting reasons, no new cellular uploads under Wi-Fi Only, no retry storm; reconnect reconciles uncertain sends before content resend. Offline before admission does not consume a logical upload attempt. Previously submitted bytes may settle. |
| T13 Background/lock | Start with foreground Back Up/Resume, then switch apps/lock for about 1, 5 and 15 minutes while enough real work remains; return and record counts/time/logs. | Granted iOS continuation makes measured progress; denial/expiration shows truthful foreground-only/waiting/paused behavior and safe resume. No indefinite-background promise. A batch that finishes before the interval does not establish that interval's continuation. |
| T14 Termination recovery | After saving current diagnostics, force-quit once during an actual transfer, reopen and resume. Later repeat during a different observable stage if practical. | Existing receipts survive; uncertain acceptance is checked before sending again. No corrupt local published file or duplicate remote content. Force-quit is a recovery test, not a background-upload expectation. Stage-specific crash recovery remains NOT RUN when that stage was not interrupted. |
| T15 Errors and independence | For naturally occurring real Google/Telegram errors, leave both enabled and observe later ready assets in each lane. | An asset-specific failure does not prevent the next ready asset; the other lane continues. Auth/rate restrictions may pause the affected provider globally. Shared Photos-source/network restrictions can affect both legitimately. Capture exact reason, stage, code, affected provider and later successes. If no safe real failure occurs, mark NOT RUN. |
| T16 Retry limit | On a real retryable per-asset/provider failure, inspect Details > Attempt history (durable), including after relaunch and another Back Up. | At most **three total automatic logical attempts** in the same cycle: initial + two retries. Exhaustion remains visible in Not uploaded. Permanent rejection may stop earlier; native HTTP/TDLib retries are not additional Core attempts. Provider auth failure is not evidence of asset retry exhaustion. Export before explicit Retry, which may start a user-requested cycle. Unknown outcomes use Recover rather than blind Retry. |
| T17 Error/log screens | Filter Not uploaded by Destination/Media/Status; open Details. Filter Logs by Run/Origin/Severity; use Newest/Older page and Export. | Correct provider, asset, reason, stage, attempts, confirmed/missing components and remedy; small identifying thumbnails only. Filters/pages show actual records, not invented rows. Empty/short lists cannot establish pagination at scale. Export opens a usable share sheet; save its file outside the app. |
| T18 UI usability | Try light/dark appearance, large text and VoiceOver on Dashboard, Settings, failure details and logs. | Controls/errors/counts stay readable, tappable and understandable without color; no full-screen gallery. Record clipped labels, inaccessible controls or misleading success text. |

Do not force three retries by repeatedly submitting bad credentials. Rate limits,
auth failures, permanent format rejection and unknown acceptance have different
handling. Server retry dates can supersede ordinary backoff; record the actual times.

## Later checks — after the first two sessions

| ID | What to do | Expected result / evidence |
| --- | --- | --- |
| T19 Live Photo policies | With recorded real Live Photos, test Paired originals (where supported), Both originals separately, Key image only and Motion video only. Record each policy and asset explicitly; preserve separate before/after evidence. | Native Google pairing either confirms both originals as one paired result or shows an actionable failure requiring an explicit policy choice; no silent conversion. Separate mode preserves both files; single-component modes deliberately omit the selected other component on Google. Telegram always preserves both originals. Policy changes can legitimately add missing coverage and replan old assets; they are not the unchanged-policy no-op test. |
| T20 iCloud and permission changes | Include an iCloud-only original on Wi-Fi; later reduce/regrant limited Photos access and Back Up. | Actual original download/preparation is represented honestly. Inaccessible sources show the correct source reason; no rendered thumbnail uploaded as an original. Updated scans describe their permission scope and do not falsely claim old inaccessible assets were newly saved. |
| T21 Large video and cleanup | Use an existing long video and, if available with sufficient free space, one above 1,900,000,000 bytes. Observe both lanes, part progress, final confirmation and later idle storage. | Google receives the whole original; Telegram lossless parts, when used, have complete manifest/order/hash evidence. Download parts and reassemble in manifest order before whole-original SHA-256 comparison. Parts are byte slices, not independently playable encoded videos. Confirmed parts must survive retry. Lack of a suitable file/space is BLOCKED/NOT RUN, not a passing multipart test. |
| T22 Mapping isolation | At idle, disconnect/reconnect the same Google account and Telegram channel. If another account/channel is available, switch, run a small real batch, then switch back. | Remote data remains. New destination has its own receipts; old Saved counts cannot credit another account/channel. Switching back reconciles its existing content. Record aliases only. Mid-transfer remapping is an additional check after idle mapping succeeds. |
| T23 Reinstall — LAST | Export logs/results first. Record hashes/remote records and exact policies/mappings/selection. Delete the app, reinstall via SideStore, restore the same limited selection and reconnect the same destinations/policy; Back Up. | With local app ledger removed, remote reconciliation precedes absent-content upload. Existing content is rediscovered without duplicate sends. Credentials surviving in Keychain do not prove the ledger survived. Offload/ordinary update does not establish reinstall recovery. Preserve Telegram captions/manifests; deleting them invalidates this test's recovery prerequisites. |
| T24 Next-build update — deferred | When a later debug build is published, refresh the SideStore source and update in place. | New build number/install succeeds; account mappings, ledger and confirmed work survive; no new copies of unchanged content. No extra cloud build is required just to perform this check now. |

Remote message/item counts differ from asset counts: a Live Photo may have two
files; Telegram adds archive metadata and may split videos. Identify duplicates by
the same content/role/destination/coverage, not merely by counting channel messages.

## Resource measurements

For small, larger and large-video runs record start/end time, confirmed assets,
network, battery/charging/Low Power state, heat symptoms and UI responsiveness.
From iOS Settings > General > iPhone Storage > Cloudified, note app size and
Documents & Data before, during if available, immediately after, and after about
10 minutes of genuine idle. Let iOS storage figures refresh; label them approximate.
Repeat comparable new-asset batches and compare idle footprints. No-op repeats do
not measure upload resource growth. Receipts/auth/log metadata legitimately remain;
uncertain active readers can temporarily protect staged files. Persistent large
growth after known readers settle is evidence to investigate, not proof of its cause.

Phone storage/battery observations do **not** measure RAM, ARC release, leaked
handles or peak native allocations. Those acceptance checks need a later focused
Instruments/physical-device diagnostic session if the available evidence cannot
resolve them. Mark them unmeasured; do not install a large local Xcode download
as part of this checklist. Thermal, low-space, memory-warning, long-history and
partial-finalization paths not actually exercised remain explicit coverage gaps.

## What to send back when something fails

1. Test ID, version/build, iPhone/iOS, exact local time/time zone and reproducible
   actions; expected versus actual behavior. Note provider, policy, permission
   selection, network and foreground/background state.
2. Dashboard screenshot showing both provider cards and counts. Failure Details
   screenshot with reason/code/stage/attempts and confirmed/missing components.
   Crop/obscure private filenames, media, account identities and channel details.
3. Logs > Export > save to a private Files location outside the app or AirDrop to
   this Mac. Preserve promptly after the incident and before update/reinstall.
   Include the displayed run ID and relevant event times when available. Screen
   filters do not guarantee the export contains only those visible rows.
4. If Logs shows **Persistence failures — memory only; excluded from export**,
   screenshot that section before relaunch; the file export cannot capture it.
5. For unexpected exits, look in Settings > Privacy & Security > Analytics &
   Improvements > Analytics Data for a matching Cloudified report; save privately.
   [Apple documents this location](https://www.apple.com/legal/privacy/data/en/device-analytics/).
   Record that no matching report exists if unavailable. OS reports/screenshots
   are not covered by Cloudified's export redaction; inspect before sharing.

Never send API hash, Google login/master tokens, Telegram codes/passwords, signing
certificates or private originals in a public GitHub issue. Review even redacted
exports before sharing. A short private report plus relevant diagnostic files is
enough; no full media-library dump is needed.

If missing/partial content is marked Saved, bytes differ, content goes to the wrong
destination, or unchanged content duplicates, pause further bulk backup and preserve evidence before retries,
deletions or reinstall. These are critical P8 issues. Connection blockers come
before deeper checks; cosmetic issues can be recorded while safe tests continue.

## Acceptance and handoff

The user records device observations; Architect reviews Core/provider integrity,
unknown-outcome recovery and independent retries, then assigns focused P8 fixes.
Builder receives a specific reproduction/evidence/fix batch. Fixes are followed by
the failing scenario and affected integrity/dedup checks, not an unrelated rebuild
loop. Source and CI status remain separate from device/service results.

Full acceptance needs recorded dual-provider photo/video originals, truthful counts,
unchanged-policy deduplication, error/retry isolation, interruptions, intended Live
Photo coverage and genuine reinstall recovery. Resource/format/background claims
must state their measured scope and outstanding gaps. No PASS is entered for you,
and the CI prerelease stays untested until device evidence supports a new status.
