# P8-B2 Architect review — corrections required

Reviewed 2026-10-08. Submission `4cec21940ea985525ba18d75cc17747f4b3244dd`;
comparison baseline `4fc0f3e`. Result: **not accepted; do not dispatch a build yet**.
Architect owns this review document, its README link and the appended review status
in P8-BUILDER.md only. No application/source corrections performed in this review.
Builder retains responsibility for the assigned UI/discovery implementation.

The engine/provider/native internals and isolated browser file were left unchanged,
which is appropriate. The submission adds presentation changes and a read-only
discovery helper, but contains reproducible static failures, functionality regressions
and unfinished requirements. A new IPA is not a useful next diagnostic step yet.

## R1 — blocking: source/project integration does not compile

- `GoogleAuthSheet.swift:96`: dangling `@MainActor` after the final declaration.
  Actual all-app Swift parse fails with `expected declaration`. Preserve MainActor
  isolation on the intended view declaration when removing the orphaned attribute.
- `TelegramChannelDiscovery.swift:26`: missing `import CloudifiedCore` for SafeFailure.
  Actual portable production typecheck fails with `cannot find type 'SafeFailure'`.
- `OverallActivityCard.swift:67–69`: references `.completed`, `.runningPhotos`,
  `.runningVideos` and `.runningBoth`; the real enum contains `.complete` and
  `.uploading` plus preparation/checking/finalization/waiting states. Actual SwiftUI
  typecheck fails at `.completed`. Match existing state contracts, not invented ones.
- `SettingsView.swift:43`: nonexistent `setLivePhotoFallback`; real command is
  `updateLivePhotoPolicy`. `SettingsView.swift:78`: nonexistent
  `GoogleAccountLoginView(environment:)`; the existing browser accepts active/token/
  loading/failure callbacks. Route through the real GoogleAuthSheet presentation.
  Do not change the protected browser API to accommodate this mistaken call.
- File splitting deleted the `phoneKeyboard`, `numberKeyboard`, `emailKeyboard`
  and `inlineNavigationTitle` helpers but left call sites in the new auth files.
  Restore appropriately scoped shared presentation helpers or use supported iOS
  modifiers directly. Complete the dependency audit after moving declarations.
- Five production sources are absent from both the generator and checked-in Xcode
  project: TelegramChannelDiscovery, AppEnvironment+TelegramChannels, GoogleAuthSheet,
  TelegramAuthSheet and TelegramChannelPicker. Actual inventory: 64 Swift files,
  59 registered. Register all exactly once in the generator and regenerate the
  project without unrelated build-setting changes.

These are source-contract defects, not merely an unavailable iOS SDK. Compiler
checks stop at initial errors, so the above is not an exhaustive iOS error list.
Keep UIKit-only styling appropriately imported/conditional if retaining portable
component compiler checks; do not substitute mock modules to obtain a green result.

## R2 — high: discovery can miss eligible channels and never finish

`TelegramChannelDiscovery.swift:20–80`:

- `getChats(limit:1000)` repeatedly returns the beginning of the main list, not
  the next page. Loading further chats cannot discover candidates outside that
  prefix. The visited-ID set also grows; the report's “incrementing limits” claim
  does not match the constant in source. Design bounded, explicit discovery coverage.
- `TDLibClient.request()` wraps server errors in `TDLibRequestRejection`. Passing
  that wrapper to `TDLibClient.classify()` discards its contained numeric code, so
  the documented loadChats end-of-list 404 is not recognized. Unwrap safely with
  existing ProviderSupport/error types; do not modify the native client to fix UI code.
- IDs enter `loadedChats` before fetching/verifying them. Any temporary getChat/
  getSupergroup failure is then swallowed and never retried in this discovery.
  Distinguish ineligible candidates from unknown/failed detail requests; do not
  permanently mark unknown candidates as inspected.
- `catch { continue }` also swallows cancellation/auth/network failures. Malformed
  `chat_ids` silently becomes an empty success. Preserve cancellation and classified
  errors, response validation and genuine partial/end-of-list semantics.
- Main-list-only discovery omits archived destinations. Account for relevant archive
  coverage or explicitly expose/select the list; never claim no eligible channel
  exists while an entire supported chat list has not been searched.

At the pinned revision, loadChats can return fewer chats than requested before
exhaustion, 404 denotes all loaded, and getChats returns a prefix for informational
use. See the [exact pinned schema, around lines 10080–10087](https://github.com/tdlib/td/blob/42e6a5259551178d1dab54a22ad96d14bd906e20/td/generate/scheme/td_api.tl#L10080).
No API revision update is assigned. If robust paging requires a critical update-
consumer interface, document the exact Architect dependency; do not create a second
consumer or an unbounded snapshot workaround.

## R3 — high: picker cancellation, stale-result protection and errors are unfinished

`TelegramChannelPicker.swift:96–126` starts an unstructured Task from `.task` via
loadMore and discards the handle. Dismissing the view does not cancel that task.
There is no generation/client/account guard, auth/connection gate, map-in-progress
selection gate, reset on account replacement or cancellation before mapping.
Late results can append to stale UI and a retained helper keeps its client alive.

Make discovery ownership explicit and cancelable; fence every result/error by the
current request and authenticated client context. Clear on dismissal/context changes,
check cancellation around awaited boundaries, and keep cancellation scoped to these
reads. Serialize actor discovery calls across suspension points, not just UI taps.

The Load More control exists only inside the nonempty-channels branch. If the first
page contains no eligible channels, the UI reports “No eligible channels found”
and cannot continue even when hasMore is true. Initial network failure also leaves
no retry control. Loading/more/retry must be available independent of result count.

Render sanitized error explanations with existing safe facilities, route actionable
discovery failures into production diagnostics, and never treat cancellation as a
provider-wide backup failure. `localizedDescription` on an arbitrary Error is not
an intentional privacy/error contract. Selection needs real identity review before
mapping, an in-flight state, disabled repeated submissions and visible mapping errors.
Channel/account text should be privacySensitive.

## R4 — high: Telegram linking has broken navigation and invisible failures

- Dashboard presents TelegramAuthSheet as a sheet, but the sheet is now a bare Form
  with no NavigationStack/cancel toolbar. Its channel picker NavigationLink has no
  navigation container in that path. Supply correct push/sheet navigation and clear
  cancel/back behavior from both Dashboard and Settings.
- Auth and mapping errors are persisted in settingsState, but TelegramAuthSheet
  and the picker do not render them. Failed phone/code/password/map operations can
  look like nothing happened. Show the real sanitized failure beside the action.
- “Log Out to Switch Account” only sets `confirmLogout`; there is no alert or
  command observing it. Wire the real confirmed logout command.
- Mapping is launched in an unowned Task, has no visible checking state or disabled
  picker actions, and dismisses on success without the requested identity review.
  Use existing serialized commands and lifecycle ownership; no invented stage timer.
- Restore secret cleanup on dismissal and keep the real one-time credential help
  link/input behavior. Preserve all supported authentication steps.

## R5 — high: redesign removed required Settings capabilities

`SettingsView.swift` removed Photos permission/access management and explicit local
scan, app build/version, changing a connected Google account, remapping a connected
Telegram channel and reachable native Telegram logout. Some auth controls elsewhere
do not compensate: connected destinations route to login in the dashboard, while
the relevant connected account commands are missing/broken in Settings.

Restore these in the new information architecture, with confirmations for destructive
disconnect/logout actions and correct command/settling gates. Distinguish disconnected
from disabled; currently root rows label an unconnected provider “Off” and connected
disabled providers “Connected” without their enabled status. Preserve privacySensitive
identity handling and communicate Google-only Live Photo fallback versus Telegram
both-original coverage. Do not restore the old visual clutter to restore functions.

## R6 — high: compact dashboard lost truthful provider/transfer detail

`ProviderStatusCard.swift:49–58` renders remaining/total instead of activity whenever
totals exist. Separate Google/Telegram waiting/failure/recovery explanations then
disappear during ordinary scanned use. Confirmed count, waiting count, account
details and last confirmed time were removed with no replacement provider detail
screen. Clicking a connected provider opens authentication instead of status details.

Keep each provider's actual activity and confirmed/remaining/total information
available, with a meaningful detail destination. A single overall reason does not
replace independent lane reasons. Restore actual transfer attempt/component/part
detail currently removed from CurrentTransferCard. “Saved securely” should explicitly
identify the saved-to-both intersection it displays; do not imply a verification or
encryption level the ledger does not establish.

## R7 — required: complete the assigned redesign and real validation

Logs and NotUploaded views/detail sheets have no changes in this submission; Google
auth presentation is largely extracted from the prior monolith. The full app-wide
redesign assignment is not accounted for by the Builder's short design report.
Finish the relevant screens and record where every essential action/status moved.
Builder still has full visual freedom; these findings protect capabilities and truth,
not old layouts. No screenshot/device visual acceptance is claimed by this review.

The report says Swift parsing/compilation was bypassed because Xcode is unavailable.
`/usr/bin/swiftc` is available and reproduced the blockers above. Run the available
real static checks; distinguish them from unavailable iOS/UI/device verification.
Clean whitespace in changed files and make the report match actual results/limitations.
Do not skip verification or dispatch cloud CI merely to discover local parse errors.

## Actual review checks

1. All app Swift parse:
   `rg --files App -g '*.swift' -0 | xargs -0 swiftc -frontend -parse`
   failed at GoogleAuthSheet.swift:97, expected declaration.
2. Existing portable production typecheck from P5-P6-INTEGRATION, including the new
   Telegram discovery and AppEnvironment extension through glob expansion: failed
   at TelegramChannelDiscovery.swift:26, missing SafeFailure import. No fake modules.
3. Actual DashboardViewState + OverallActivityCard + CurrentTransferCard against
   macOS SwiftUI in Swift6: failed at OverallActivityCard.swift:67, unknown enum case.
   This does not typecheck iOS-only UIKit views.
4. Non-mutating AST/source inventory: 64 actual app Swift files versus 59 registered;
   the same five missing from generator and Xcode project.
5. Local docs links: pass, 32 files before adding this review.
6. Project/Info.plist plutil lint: pass. This does not prove source registration.
7. `git diff --check 4fc0f3e..4cec219`: fails for trailing whitespace across changed
   files. No app/account/provider/device tests, cloud build or IPA publication.

## Builder correction handoff

This review assigns corrections to the existing P8-B2 scope. Keep full UI freedom,
finish both deliverables, preserve critical ownership and change no dependency pins.
Fix all R1–R7 findings; document exact missing Architect interfaces if any, rather
than expanding into native/session internals. Update P8-BUILDER.md with truthful
implementation/static evidence, commit/push coherent corrections and stop for
Architect re-review. No cloud build or new feature batch is authorized by this review.
