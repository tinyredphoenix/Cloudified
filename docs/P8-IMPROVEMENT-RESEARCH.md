# Cloudified improvement research — proposed next batches

Research date: 2026-10-08. Architect owns only this document and its README link
for this research batch. No application, Core, provider, native, CI or distribution
files are assigned for editing. This is a recommendation, not a Builder assignment.

Source baseline: `439a96c`. Installed build 6 predates the P8 first-run corrections.
See [first-run evidence](P8-FIRST-RUN.md) before claiming any new behavior works.

## Recommendation and evidence boundaries

Keep the visible app small. Prioritize isolated account handling, easier linking,
reliable continuation, incremental work and recovery over more screens or higher
parallelism. Neither independent projects' success nor a green compile proves
Google original download quality, quota treatment or account enforcement behavior.
Those need observations on the selected account/device; never label them guaranteed.

| Area | In current source | Proposed improvement |
| --- | --- | --- |
| First setup | P8 Photos access before account linking; simpler native lists | Observe next installed build before another redesign |
| Google browser | Fresh nonpersistent WK store per sign-in, bounded observer/timer teardown | Finish isolation across every HTTP/auth path and account replacement |
| Google HTTP | RPC/file transports default to ephemeral configurations | Remove token exchange's implicit `URLSession.shared`; explicitly disable unnecessary HTTP cookie/credential stores |
| Background | One foreground-started BGContinuedProcessingTask, checkpointed independent lanes | Better real progress and stopped/waiting explanations |
| Resources | One preparation worker, one worker per provider, bounded streaming/staging/leases | Measure repeated work; optimize scans and snapshot queries first |
| Telegram linking | Stepwise real authentication; numeric channel ID mapping | Paginated picker of actual eligible owned private channels |
| Reinstall | Destination-scoped remote reconciliation, manifests, no blind unknown-outcome resend | Optional recovery checkpoint/index and portable receipt export |

These are source observations, not device acceptance. No new feature implementation,
SDK installation, account access or cloud dispatch belongs to this research batch.
Firecrawl CLI/tools were unavailable; research used official documentation and the
existing pinned upstream directly through web search. No new dependencies or pins.

## Google isolation: achievable boundary and remaining gap

Cloudified can isolate its browser state, stored credentials, requests and account
mapping. It cannot guarantee Google treats accounts as unrelated or confines an
enforcement action to one account. Google documents collection of browser/app/device
identifiers and IP/request information. The conclusion that a local cookie boundary
cannot control service-side association is an architectural inference, not a claim
that every account will be banned. A legitimate dedicated backup account separates
what credentials and data this app uses; it is not a ban shield.
[Google privacy policy](https://policies.google.com/privacy?hl=en),
[Google account policy](https://support.google.com/accounts/answer/40695?hl=en).

Recommended isolation contract for the next architect-owned provider batch:

1. Retain a fresh `WKWebsiteDataStore.nonPersistent()` for each sign-in. Import no
   Safari cookies or other Google apps' accounts. Destroy only this browser's store
   on cancellation/completion; never clear other apps' state. OS password autofill
   and passkeys, if the person chooses them, are separate from shared login cookies.
2. Route token exchange, refresh, presence checks, finalization and upload through
   explicit app-owned configurations. `GooglePhotosClientSession.connect()` currently
   omits a session argument to `GoogleTokenExchange.run()`, whose default is `.shared`.
   This singleton is shared within this app; it is not evidence of access to Safari
   or native Google accounts. Remove the implicit shared-store dependency anyway.
3. Outside the temporary login browser, use ephemeral sessions with `urlCache=nil`,
   `httpCookieStorage=nil`, `httpShouldSetCookies=false`, and
   `urlCredentialStorage=nil` where the token/header protocol permits. Ephemeral
   alone provides private in-memory cookies, not an absence of cookies. Keep
   redirect/endpoint validation; avoid forwarding tokens to unexpected destinations.
4. Store only this app's chosen credential in its private Keychain namespace,
   without iCloud synchronization or broad access groups. Preserve the existing
   AfterFirstUnlockThisDeviceOnly accessibility needed for locked-device background
   work. Requiring biometric unlock for each token read would conflict with that use.
5. Before changing a working mapping, verify and show the new account identity;
   cancellation retains the old mapping. Settle old native/file readers before
   replacing credentials. Receipts remain scoped to immutable account identity.
6. Separate Disable, Disconnect from Cloudified, and server-side session revocation.
   Local credential deletion does not prove server revocation. Offer provider account
   security guidance if this private protocol has no verified revocation operation.
   Disconnect must not sign the person out of unrelated apps or erase backup receipts.
7. Keep logs free of credentials, browser URLs/query strings and raw auth responses.
   No analytics SDK or enumeration of other phone accounts is needed. Keep the
   protocol identity stable per stored credential; do not introduce identity rotation
   or automatic account switching as a response to restrictions.

Apple explains [ephemeral session storage](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/ephemeral?changes=_6_2),
[cookie-store defaults and disabling](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/httpcookiestorage?changes=_6),
and [background-accessible device-only Keychain items](https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly?changes=_1).
The existing browser/provenance evidence is in [P8 first-run notes](P8-FIRST-RUN.md).

The selected pinned PhotosBackup EmbeddedSetup route is a private integration.
Google's ordinary public OAuth guidance rejects embedded user agents; this research
does not reclassify our route as supported OAuth or guarantee its acceptance on iOS26.
Keep challenges/errors visible and the Telegram lane independent. Do not silently
substitute a different upload API with different original/quota semantics.
[Google native OAuth guidance](https://developers.google.com/identity/protocols/oauth2/native-app).

## Background execution and Live Activity choice

Retain the existing iOS26 `BGContinuedProcessingTask` as the primary execution owner:
the person taps Back Up/Resume in the foreground, and iOS may allow the same engine
to continue after leaving the app. Apple's system UI already supplies a Live Activity
with progress and cancellation. Resource constraints can end it; reporting little
progress can make termination more likely. This is permission to continue work,
not a promise of unlimited runtime.
[Apple continued task](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask?changes=_2).

Improve its progress before adding an ActivityKit target. Current `BackupContinuation`
reports confirmed obligations only, so a large video can transfer bytes while task
progress stands still. Use measured current-resource work plus durable completion,
with a defined denominator, while retaining exact saved counts separately. Export,
hashing, checking, transferring and finalizing must be distinguishable. No timer-
driven progress, estimated completed work or 100%-sent-as-saved. Throttle/coalesce
title updates and retain an honest indeterminate state when total work is unknown.
The subtitle can summarize both providers' real status within system text limits;
the full two-provider dashboard remains in the app. System cancellation must stop
planning, join readers, preserve receipts and reconcile uncertain sends on resume.

Force-quitting through the app switcher cancels continued processing without a
cancellation callback. On the next launch, recover from the durable ledger rather
than assuming graceful shutdown. Record actual foreground/background, system grant,
expiration and recovery events; say exactly why work stopped when known.
[Apple long-running tasks](https://developer.apple.com/documentation/BackgroundTasks/performing-long-running-tasks-on-ios-and-ipados).

A custom Live Activity is presentation, not extra runtime. It requires a WidgetKit
extension; the Live Activity itself cannot make network requests. Defer until real
use demonstrates the system display is insufficient. No APNs service/backend is
needed for local task progress.
[Apple Live Activity architecture](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities?changes=_6).

| Later option | Value | Constraint / decision |
| --- | --- | --- |
| BGProcessingTask | Opportunistic backup when charging/network conditions permit | Optional, off by default; same engine and ledger, one execution owner. No clock-time guarantee |
| Background URLSession for Google | HTTP file transfers can outlive process suspension/system termination | Separate architect feasibility batch; persistent OS inventory, cancellation, disk copies and finalization recovery required |
| PhotoKit background resource extension | System-managed original-resource uploads, potentially less app staging | Investigate only after current transport works; not a common transport replacement for both providers |
| Custom ActivityKit extension | Rich separate Google/Telegram presentation | Defer; system task display first, no runtime gain |

Scheduled work can require external power/network, but `earliestBeginDate` is only
a lower bound, not a promised launch time. Never display “backs up every night at
02:00” as guaranteed behavior.
[Processing request options](https://developer.apple.com/documentation/backgroundtasks/bgprocessingtaskrequest?changes=_7),
[earliest start semantics](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate?changes=_3).

Background URLSession supports HTTP(S) file uploads, not TDLib's protocol. It can
survive system termination, but user force-quit cancels transfers. It copies upload
files to temporary storage, which changes admission accounting. Its redirect behavior
also differs from our existing strict transport. Adding it requires revisiting D38,
durable OS-task identity/account scoping, exact file ownership and no blind resend.
Do not assume a generic resumable HTTP facility matches Google's private upload
protocol or automatically extends TDLib runtime.
[Apple background sessions](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/background%28withidentifier%3A%29?changes=latest_major),
[background session limitations](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background?changes=latest_minor),
[upload file copying](https://developer.apple.com/documentation/foundation/urlsessionuploadtask?changes=_8&language=objc).

Apple's PhotoKit extension is available via the older protocol from iOS26.1; current
documentation also describes a newer iOS27 protocol. It needs full Photos access,
a registered extension and upload base URL. Jobs send asset resources to URLRequests;
the optional resumable mechanism requires matching server support. Google private
session/finalization compatibility, TDLib incompatibility, shared ledger ownership
and SideStore signing capabilities need investigation. Keep a path for limited Photos
access. Treat this as a research candidate, not “enable one flag for auto backup.”
[PhotoKit background-upload design](https://developer.apple.com/documentation/photokit/uploading-asset-resources-in-the-background?language=ft),
[extension enablement](https://developer.apple.com/documentation/photos/phphotolibrary/setuploadjobextensionenabled%28_%3A%29?changes=_6).

## Efficiency: reduce repeated work before increasing parallelism

1. **Incremental library scan.** Persist PhotoKit change history tokens; process
   inserted/changed/deleted identifiers on a background executor and commit the new
   token only after corresponding ledger changes succeed. Track live changes too.
   The current scanner has no persistent change-token path. Expired/incomplete
   history triggers a bounded full metadata scan; permission scope changes also
   require resync. Missing access is never proof a remote backup is absent.
   [Apple change-history design](https://developer.apple.com/videos/play/wwdc2022/10132/).
2. **Fewer aggregate queries.** UI refresh already coalesces events to 500ms but
   calls `engine.snapshot()` and ledger/source lookups on refresh. Cache expensive
   aggregates against a ledger revision; deliver cheap live-byte snapshots separately.
   Preserve atomic counts and invalidate on mapping, receipt, scope and state changes.
   Skip invisible page work; keep small failure thumbnails visible-row scoped.
3. **Reuse verified preparation.** Export each original once where practical and
   stream SHA-1/SHA-256 together. Retain the current file leases and bounded buffers.
   Reuse digest metadata only when the source/resource generation is trustworthy;
   distinguish metadata-only changes from changed bytes before avoiding a re-export.
   Never deduplicate by filename, size or modification date alone.
4. **Bound every lifecycle.** Release callbacks, task references, stream buffers,
   per-file handles and thumbnail work after terminal callbacks. Native uncertain
   sends retain their reader lease until settled; idle cleanup must not remove them.
   Retain storage reservations and reserve for transport-owned copies. Low disk or
   high thermal pressure should produce a precise wait reason, not repeated exports.
5. **Measure connection reuse.** Current foreground transport recreates a session
   per operation to break delegate retention. A reusable per-profile transport could
   reduce setup overhead, but only after measuring and proving explicit shutdown,
   cancellation and terminal-reader behavior. Do not trade memory correctness for
   an assumed speed improvement.
   Review pinned TDLib options for unnecessary top-chat statistics and inline
   thumbnail downloads as well. Apply only supported, instance-appropriate options;
   do not disable history/update processing needed for reconciliation or change
   account-wide notification preferences on other devices.
   [Official TDLib options](https://core.telegram.org/tdlib/options).
6. **Keep initial concurrency.** One preparation worker and one worker per provider
   already permit simultaneous destinations. Add at most a bounded lookahead only
   if measurements show an idle lane caused by preparation and disk/thermal budgets
   permit it. More parallel uploads may increase throttling, memory and retries.
   Honor server retry delays; disconnected waiting is not a failed content attempt.

All existing [runtime limits](RUNTIME-SPEC.md) remain in force. Measure scan/export/
hash/transfer/finalization time, bytes actually sent including retries, confirmed
original bytes, peak staging, retained-reader count and cleanup outcomes. Report
speed over a meaningful interval; ETA stays unavailable until a credible work-size
and rate estimate exists. Releasing objects does not guarantee RSS immediately falls.
Optional local MetricKit diagnostics can complement these measurements using the
iOS26 API; daily metrics are not a real-time monitor or a telemetry backend.
[Apple MetricKit](https://developer.apple.com/documentation/metrickit?changes=_6__7).

## Features worth adding, mostly behind details

| Priority | Feature | Why / guardrail |
| --- | --- | --- |
| High | Account identity review and clear connection states | Signed in, destination verified, reconciling, ready are distinct; switching never redirects old jobs |
| High | Telegram channel picker | Real eligible owned private channels, paginated; validate write access/ownership and auto-delete; manual ID under Advanced |
| High | Useful failure actions | Reconnect, grant Photos access, wait for Wi-Fi, free staging space, or explicit retry as appropriate; provider-wide issue shown once |
| High | Backup run summary | Separate provider confirmed/already-present/remaining/failed and Photos/Videos; “saved to both” remains receipt intersection |
| High | Preservation details | Original format/size, Live Photo still/motion coverage and Google fallback; distinguish sent bytes, accepted receipt and downloaded-hash verification |
| Medium | Quiet Telegram archive sends | Check/apply per-message silent-send behavior rather than changing global notification settings |
| Medium | Recovery index and encrypted receipt export | Faster reinstall: versioned account-scoped manifests/checkpoints, hash validation and remote reconciliation; missing index never proves absence |
| Medium | Charging-only preference | Simple optional policy; explicit waiting explanation, no new independent queue |
| Medium | One completion/attention notification per run | Opt in contextually; counts only on lock screen, no filenames/identities; native notification permission can be declined |
| Medium | Redacted diagnostic export | Build number, safe failure codes, run timeline and resource summaries; private export, never automatic public Git upload |
| Later | Integrity audit / recovery instructions | Verify selected original downloads by hash and reconstruct split videos/Live Photo components; distinguish provider acceptance from byte verification |
| Later | User-invoked shortcut opening Back Up/Resume | Reuse foreground-start/ownership rules; no duplicate engine or claim of unrestricted background launch |
| Later | Client-encrypted Telegram archive | Cloud channels are not end-to-end encrypted; requires key backup, versioned manifests, streaming authenticated encryption and recovery design |

Telegram documents 2GB files for free accounts and 4GB for Premium. Retain current
conservative lossless splitting for the free target; Premium support is optional,
not a requirement or reason to change the original bytes. Cloud channels differ
from device-specific Secret Chats. An encrypted archive could preserve exact bytes
after decryption but cannot be uploaded as a normal viewable Google Photos original.
No encryption feature should ship without a workable key recovery path.
[Telegram FAQ](https://www.telegram.org/faq),
[Telegram encryption distinction](https://www.telegram.org/faq?setln=en#q-how-are-secret-chats-different).

Destination details should also expose the archive's auto-delete setting and account
inactivity-retention setting when readable, with a link to change them in Telegram.
Telegram currently documents an 18-month default for inactive account deletion;
read the actual setting rather than hard-code it as this person's configuration.
Do not silently alter account settings or promise permanent retention.
[Telegram retention policy](https://telegram.org/privacy/#10-4-account-self-destruction),
[per-message notification option](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1message_send_options.html).

Keep the dashboard to overall state, Google and Telegram progress, Photos/Videos
and the current action. Put troubleshooting/resource detail behind disclosure or
in Logs. Avoid another gallery, many tuning knobs or an unmeasured “turbo mode.”
Do not expand into automatic deletion of phone originals as part of this uploader.

## Proposed execution order and acceptance evidence

1. **P8-R2, Architect: complete Google isolation and linking safety.** Explicit HTTP
   session policy, verified identity review, app-only disconnect semantics, sanitized
   challenge/error handling. Scope must be assigned before edits. Preserve pinned
   wire behavior and update adapted-file hashes if vendored files change.
2. **P8-R3, assigned Builder UI with Architect provider review: Telegram picker and
   concise recovery actions.** Real data only; no account access during development,
   uploads as a link side effect or fabricated connection success.
3. **P8-R4, Architect: progress/efficiency.** Genuine system task progress, incremental
   library history and fewer snapshot queries, each with coherent ownership/commits.
   Keep existing concurrency/retry/reconciliation/lease invariants.
4. **One coordinated full build and device session.** Observe Photos access and
   isolated login first, then both providers uploading together, originals/metadata/
   Live Photos/video splitting, failures, cancellation, backgrounding and recovery.
   Capture measured resource behavior and redacted reasons in a private report.
5. **Later research batch only if evidence warrants:** opportunistic scheduled
   execution, background HTTP/PhotoKit extension, custom Live Activity, encrypted
   recovery export/archive. These need explicit design/protocol/signing review.

Device acceptance must include Safari/Google apps remaining signed in while Cloudified
requires its own browser login; canceled sign-in and account replacement; no secrets
in logs; real video byte progress on the system activity; lock/background and app-
switcher quit recovery; no duplicate resend after uncertain acceptance or reinstall;
one provider failing while the other confirms; unchanged download hashes on supported
originals; repeated-run peak staging/memory trends. Limitations must remain visible.
No source-only check can establish Google's future quota or enforcement decisions.

Research-batch validation: local documentation links and `git diff --check` only.
No executable app changes, account tests, new release/tag or cloud workflow dispatch.
