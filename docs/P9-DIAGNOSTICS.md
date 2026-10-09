# P9 — linking recovery and actionable diagnostics

2026-10-09 IST. User reports first-screen reconciliation errors for both providers,
Telegram startup stalled with unknown transfer/TDLib error, and browser Google
sign-in completing but app mapping failing with an offline message. User requests
very detailed redacted logs and a no-extra-iPhone-setup public GitHub report button;
Safari/other-browser fallback may be explained where actually supported.

Architect claims this document, docs/03-BUILD-LOG.md, docs/04-DECISIONS.md, README.md,
App/Application/AppEnvironment.swift, its +Accounts/+Recovery/+Lifecycle/+Pages
extensions and new +Diagnostics extension; App/Adapters/System/StorageLayout.swift,
DiagnosticExportStore.swift, FailureExplanation.swift, ProviderSupport.swift and new
DiagnosticReportUploader.swift; GooglePhotosClientSession.swift, GPMCClient.swift,
GoogleTokenExchange.swift, ForegroundFileUploadTransport.swift; TDLibClient.swift,
TDLibSession.swift; GoogleAuthSheet.swift, TelegramAuthSheet.swift, LogsView.swift;
Packages/CloudifiedCore/Sources/Diagnostics/DiagnosticEvent.swift and
Packages/CloudifiedCore/Sources/CloudifiedCore/Diagnostics.swift; Info.plist,
project.pbxproj, scripts/generate_xcode_project.py and google-vendor.json.
User approved anonymous paste.rs public reports after rejecting extra hosting/setup.
No diagnostic service, bundled GitHub token, new installation or login is required.
No active Builder. No credentials, raw service bodies, cookies, private media,
account/channel names, paths or raw URLs in reports. No blind resend/receipt changes.
No cloud build/account tests/hosting dispatch until separately authorized/configured.
Pending version 2.0: user classifies new diagnostic upload capability as a feature.

Findings: DiagnosticExportStore's existing-folder failure aborts assignment of
provider clients. Remote-outcome recovery errors then misrepresent missing setup.
Auth and transport classifications discard safe OS/native codes. Google browser
success is distinct from token exchange, Photos authentication, identity check and
mapping. Telegram failed wait-parameters state currently has no working retry route.


## Implemented source and limits

The export directory is prepared idempotently while preserving canonical directory,
protection and backup-exclusion checks. Export failure no longer prevents provider
assignment. Missing setup is distinct from unknown remote acceptance. Network-path
arrival can wake recovery; a path is not proof of reachable internet.

Google stages distinguish master exchange, Photos token, authentication, same-token
identity verification, read access, mapping and recovery. Saved credentials can retry
verification without another browser login. App-owned ephemeral HTTP sessions disable
shared cookies/credential storage. The pinned upstream route and upload fields stay
unchanged; Google-side device/session registration is still possible. Browser fallback
help explains the existing Advanced login token field: protected cookies are not
shared automatically by iPhone Safari; an existing desktop browser may expose an
issued oauth_token. Never send any credential through chat, logs or GitHub.

Telegram reuses the existing native client, retains its database, bounds startup
requests and permits retry in the wait-parameters state. Diagnostics record closed
native method/auth-state values, numeric errors and durations, never native bodies.
Pending responses are removed before awaited terminal logging to avoid double resume.
Both media providers retain independent queues, receipts and reconciliation behavior.

Logs now has Upload public diagnostics. One explicit action prepares a maximum
256 KiB JSONL report from at most 1,000 recent events plus 50 safe fallback failures.
A missing/unreadable ledger is reported without making the report depend on the
export folder. Reports contain version/build/revision, numeric OS version, safe
network flags, stages, correlation UUIDs, timings and numeric codes. They exclude
credentials, media, account names, phone/email, filenames and private paths.
Routine native/setup traces participate in existing retention pruning; durable failure
records remain subject to the existing critical-event retention rules.

POST goes directly to https://paste.rs/ without authentication. Only HTTP 201 and a
strictly validated paste.rs HTTPS link count as success; partial HTTP 206 is rejected.
There are no automatic report retries. The returned link is copied and shown for
sharing in this chat. Public reports have no promised retention or availability.
GitHub filing is a later human-authorized action through existing desktop access,
not an embedded write token. Official service contract: [paste.rs](https://paste.rs/).

## Evidence and next device pass

Pending version 2.0 agrees across plist, generator and generated project. All 66
actual app files pass parsing, real package compilation, Catalyst UIKit/SwiftUI
source typechecking and optimized whole-module IR emission using the installed
26.5 SDK. This is not an iPhone link/run, real account test or report-service POST.
No live account, mock-data or cloud build cycle was run for this batch.

After an authorized 2.0 build/install: launch twice; verify no initial remote-unknown
error caused by local setup; attempt Telegram startup/linking and Google login;
record the exact failing screen; use Logs → Upload public diagnostics, then send
its link here. Check cancel, retry saved Google verification, Telegram retry, and
public upload failure messaging. Never paste tokens or account credentials. Account
success, original-quality uploads and device background behavior remain unverified.
