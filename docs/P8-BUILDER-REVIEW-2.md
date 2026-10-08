# P8-B2 Architect re-review — corrections still required

Reviewed 2026-10-08. Submission `2c3aada`, implementation `fbe2a4d`, compared with
prior review `260c313`. **Not accepted; no cloud build/release dispatch.**
Architect claims this review, the appended status in P8-BUILDER.md and the README
review link only. No app source edited. Untracked `scratch/` is left untouched.
Builder retains the existing presentation/read-only discovery correction scope.

## What is fixed

| Previous finding | Verified status |
| --- | --- |
| R1 syntax, imports, enum cases, missing helpers and source registration | Prior defects corrected; all 64 Swift sources parse and are registered exactly once. A new actor-isolation defect remains below. |
| R2 end-of-list error unwrapping and archive coverage | Correct safe unwrap and archive path added; bounded coverage and error handling remain open. |
| R3 empty-result Load More, retry and safe error text | Controls now available without results; task handles added. Cancellation/context lifecycle remains incomplete. |
| R4 Telegram sheet navigation, errors, logout and secret cleanup | Still open. Native keyboard modifiers do not address these findings. |
| R5 missing Settings commands | Photos management/scan, account change/remap and logout restored. Presentation gates and status semantics need completion. |
| R6 provider and current-transfer detail | Activity, confirmed/waiting/failed counts, account/last-saved disclosure and attempt/component details restored. Saved-to-both wording remains. |
| R7 app-wide redesign and accurate evidence | Logs/NotUploaded changes are list styling only. No visual/device acceptance; the claim that all findings are resolved is incorrect. |

## S1 — blocking: actor reset call and lifecycle

`TelegramChannelPicker.swift:97–100` calls `discovery?.reset()` synchronously from
onDisappear. `TelegramChannelDiscovery.reset` is actor-isolated. A narrow Swift 6
compiler probe using the actual production actor and this exact call reports:
`call to actor-isolated instance method 'reset()' in a synchronous main actor-isolated context`.
This is independently reproducible without a SwiftUI macro or iOS SDK stub.

Do not merely wrap this call in an unmanaged Task and declare R3 finished:

- Picker cancellation does not automatically cancel the helper's nested unstructured
  Task. Propagate cancellation and own both lifetimes explicitly.
- Helper reset cancels then immediately clears shared state, but the old operation
  can resume from client.request and mutate that state. Its unconditional defer can
  clear a newer discoveryTask. Fence mutations/cleanup by a request generation.
- Picker dismissal leaves discovery non-nil and isLoading unchanged. Canceling a
  loading picker and returning to the retained view can leave it permanently loading;
  onAppear only starts work when discovery is nil. Reset/recreate UI state coherently.
- A TDLib client reference alone is not an authenticated account/session context.
  Fence results/errors against context replacement, logout and shutdown; gate reads
  using actual ready/settling state. Cancel these reads before mapping.

## S2 — high: discovery is still unbounded and can hide or lose results

`TelegramChannelDiscovery.swift:26–88` raises the fixed getChats prefix to 10,000
and loops until a qualifying channel is found or both lists exhaust. One user page
can scan thousands of chats and perform serial detail requests. Channels outside
that prefix remain undiscoverable. Increasing the cap is not paging.

Bound work and retained state per user operation; report honest coverage/more/partial
states even if a page finds zero eligible channels. Follow the pinned TDLib contract
described in [R2 of the original review](P8-BUILDER-REVIEW.md). If correct discovery
needs an Architect-owned interface, document that exact dependency and stop there;
do not add a second native update consumer or another huge snapshot cap.

Additional correctness problems:

- Missing chat_ids continues the loop instead of surfacing a malformed response.
  Missing eligibility fields can be treated as confirmed ineligible. Distinguish
  invalid/unknown data from verified exclusions.
- Detail-request catch propagates only cancellation/offline/interrupted. Auth expiry,
  rate limits and deadlines can still be swallowed. Preserve classified actionable
  failures, including server wait information, without retrying aggressively.
- Eligible IDs enter loadedChats before results are delivered. If a later detail
  request throws, earlier eligible results in the local array are lost and their IDs
  are skipped on retry. Cancellation between helper return and UI delivery has the
  same problem. Preserve undelivered results or acknowledge them only on delivery.

## S3 — high: Telegram linking fixes from R4 are still missing

`TelegramAuthSheet.swift` is still a bare Form. Dashboard presents it directly as
a sheet (`DashboardView.swift:69`), leaving its Select Channel NavigationLink without
a navigation container. Supply consistent sheet/push navigation and cancel behavior
from both entry points without nesting navigation containers accidentally.

- `TelegramAuthSheet.swift:228` only sets confirmLogout. There is no alert or real
  logout command observing it. Wire confirmed logout through the existing command.
- The auth sheet never renders telegramAuthErrorMessage. Phone/code/password/API
  credential failures can remain invisible. Render the existing sanitized errors.
- Mapping from both this sheet (lines 231–239) and Settings (lines 150–155) uses an
  unowned Task. The picker neither shows stored mapping errors nor an honest checking
  state; Settings errors are behind the pushed picker. Show errors at the action,
  disable repeated submissions and review the account/channel identity before commit.
- Clear secret input state on dismissal; restore the actionable credential help link.
  Preserve every existing TDLib authentication step.
- Send actionable discovery failures to existing privacy-safe production diagnostics
  without turning read cancellation into a provider-wide backup failure.

## S4 — required: finish restored presentation contracts

- Settings pushes GoogleAuthSheet, which owns its own NavigationStack. Its
  interactiveDismissDisabled protects modal dismissal, not the outer navigation
  pop during credential exchange. Use a coherent presentation route with deliberate
  cancellation/settling behavior; keep protected Google browser/auth internals unchanged.
- Root provider rows must distinguish connected/enabled, connected/disabled and
  disconnected. Restore command/settling gates at actions, not only command internals.
- Include CFBundleVersion in the System version display for device bug reports.
- Describe Telegram logout as this app's Telegram session, not the entire account
  across devices. Mapping disconnect is already correctly described separately.
- OverallActivityCard's saved intersection should say saved to both destinations,
  rather than the unsupported assertion "saved securely".
- Account for the full presentation assignment, including Logs/NotUploaded details
  and Google linking. List styling alone does not demonstrate the requested review
  of those flows. Keep full visual freedom; document where essential actions/status
  now live. Visual acceptance awaits the coordinated device session.

## Actual validation and limitations

1. All 64 app Swift files: `swiftc -frontend -parse` passes.
2. Real portable production typecheck, including Telegram discovery and the facade:
   passes in Swift 6 with seven existing macOS 27 originalFilename deprecation warnings.
   Uses the existing built CloudifiedCore module and native module maps; no mocks.
3. Actual DashboardViewState + OverallActivityCard + CurrentTransferCard +
   ProviderStatusCard: macOS SwiftUI typecheck passes with warnings-as-errors.
4. Actual picker cannot be fully checked in this local CLT environment: SwiftUI State
   macro plugin unavailable and iOS keyboardType unavailable on macOS. These environment
   errors are not claimed as iOS app defects. The separate actual-actor probe confirms
   S1 independently; this is not a complete iOS UI typecheck.
5. Generator AST inventory: 64 actual/64 unique registered sources, no missing/stale
   entries; checked-in project contains the names. Project/Info.plist plutil passes.
6. Local Markdown targets: passes, 33 files before this review.
7. `git diff --check 260c313..2c3aada` fails at P8-BUILDER.md:253 (trailing whitespace).
   Architect removes that documentation whitespace in this review batch. Historical
   Builder validation claims above remain historical claims, not acceptance evidence.
8. No app/account/provider/device tests, full iOS build, cloud dispatch or publication.
   Available compiler checks establish only their stated scope.

## Builder correction handoff

Finish S1–S4 and all still-open R1–R7 requirements, preserving completed fixes and
full UI freedom. No Core/provider/native/auth implementation changes or dependency
updates are assigned. Discovery helper and the read-only facade remain the bounded
exception already assigned in P8-BUILDER.md; report missing critical interfaces.
Run real available static checks, update shared evidence truthfully, commit/push
coherent corrections, then stop for Architect re-review. No new IPA build yet.
