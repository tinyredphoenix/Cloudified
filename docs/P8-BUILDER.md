# P8-B2 — Builder assignment: Telegram destination selection and setup clarity

Assigned by Architect at the user's request on 2026-10-08. Baseline `d048b8b`.
This file is the current Builder handoff; research proposals are not a blanket
assignment. Google isolation, Core/protocol/background optimization remain separate
Architect batches. No concurrent Architect edits to this batch's files while claimed.

## Objective

Replace Telegram's primary numeric channel-ID entry with a real, bounded picker of
eligible owned private archive channels. Keep manual ID under Advanced. Simplify
the destination setup/error flow using native SwiftUI and existing truthful state.
Do not rewrite the app or implement the entire improvement roadmap.

## Read first

Read AGENTS.md, README, docs/01-ARCHITECTURE.md, docs/02-BUILD-PHASES.md,
docs/P8-FIRST-RUN.md and the relevant linking/ownership sections of
docs/P8-IMPROVEMENT-RESEARCH.md. Use docs/03-BUILD-LOG.md for historical ownership;
its old P7 active entry is not authorization for cloud dispatch or unrelated edits.
Read existing SettingsView/SettingsViewState, AppEnvironment account commands and
TelegramProviderAdapter.mapVerifiedChannel/verifyChannel to understand boundaries.
Read only relevant TDLib request/auth APIs and runtime/diagnostic rules.

## Exact allowed paths

Claim these paths and actual start HEAD in this document before editing:

- `App/Presentation/Settings/SettingsView.swift`
- `App/Presentation/Settings/SettingsViewState.swift`
- New `App/Presentation/Settings/TelegramChannelPickerView.swift`
- New `App/Adapters/Telegram/TelegramChannelDiscovery.swift` — read-only helper
  using existing TDLibClient.request, not a native/session/protocol rewrite
- New `App/Application/AppEnvironment+TelegramChannels.swift` — narrow discovery
  facade using existing client and diagnostics; no replacement command/backup owner
- `Cloudified.xcodeproj/project.pbxproj` and `scripts/generate_xcode_project.py` only to
  register these new production Swift files consistently
- `docs/P8-BUILDER.md` for ownership, findings, implementation/checks and handoff

Do not edit GoogleAccountLoginView, Google adapter/token exchange, Core packages,
TDLibClient/TDLibSession/TDLibBridge/TelegramProviderAdapter, credential storage,
existing AppEnvironment files, runtime contracts, dependency pins, workflows or
distribution repositories. No app-version bump or release tag in this batch.

If a required interface change falls outside scope, document the exact missing
interface for Architect. Continue independent allowed work; do not invent fake
data, reach into another native client or bypass verification to hide the gap.

## Implementation requirements

1. Use the existing authenticated TDLib client. There is already an internal
   `TDLibClient.request` interface and `getMe`; do not create another TDLib instance
   or update consumer. Request shapes must match the pinned TDLib source/schema
   and supported response types. Consult official/pinned source as needed; do not
   change dependencies or assume newer documentation fields exist at the pin.
2. Discovery starts only while the Telegram mapping UI is visible and the actual
   authorization/connection state permits it. Use bounded requests/timeouts, modest
   page sizes, cancellation and generation checks. No full account-history scan,
   unbounded per-chat tasks, periodic polling or collecting all chats into memory.
3. Enumerate/load the real chat list incrementally through supported TDLib methods,
   fetch candidate details and offer only private channels owned by the current
   authenticated user with membership and auto-delete disabled. Distinguish genuine
   end-of-list from cancellation, network/error or an incompletely loaded list.
   Display Load more/Retry as appropriate. Clear discovery state across dismissal,
   auth/client replacement and account changes; late responses cannot repopulate it.
4. Do not claim candidate filtering is final authorization. Selection shows the
   real account/channel identity, then invokes existing
   `environment.mapTelegramChannel(chatID:)`. That method's verification,
   destination-scoped reconciliation and control ownership remain authoritative.
   No direct ledger writes, receipt mutation or upload trigger from the picker.
5. Keep a working mapping until the existing switch command owns the transition.
   Dismissing discovery does not disconnect or log out. Respect command/settling/
   shutdown gates, prevent repeated taps and cancel discovery before submitting a
   map. Read-only query cancellation must not cancel backup transfers or close TDLib.
6. Retain manual numeric ID under Advanced, routed through the same mapping command.
   If no eligible channel is found, explain that an owned private channel with
   auto-delete off is needed. Do not auto-create channels, send probe messages,
   change permissions/retention or show fabricated candidates.
7. Keep phone/code/2FA authentication step-driven. Present short progress labels
   for actual operations: signing in, loading channels, checking destination,
   checking existing uploads and ready only where existing state supports them.
   The current map command does not expose separate verification/recovery stages;
   use one honest “Checking destination and existing uploads” state while it runs,
   rather than fabricate stages or modify the coordinator to animate them.
8. Simplify Google destination copy/layout only; leave GoogleAuthSheet logic,
   account-changing semantics, embedded browser and token handling intact. Google
   identity confirmation before mapping and complete HTTP isolation are Architect
   work. Do not claim this batch makes account enforcement isolated or guaranteed.
9. Display sanitized discovery/mapping errors beside the relevant action. Offline
   is not “no channels”; loading is not “ready”; an empty filtered list is not
   “backup complete.” Distinguish app-only disconnect from Telegram native logout.
   Never display raw TDLib/auth responses or use `String(describing:)` for them.
10. Route discovery failure diagnostics through the existing safe reporting path.
    Do not log channel titles, chat IDs, phone numbers, credentials, private paths
    or response bodies. Avoid reporting a canceled read as a provider-wide backup
    failure. No new logging database or automatic log upload.
11. Native Form/List/navigation and semantic colors/fonts; Dynamic Type, VoiceOver,
    dark mode, readable error states and adequate touch targets. Keep detailed
    setup data behind disclosure. No gallery, new dashboard tiles, image mockups,
    hard-coded sample accounts, seeded channels, demo progress or fake previews.

## Required invariants

Original photos/videos and Live Photo plans remain unchanged. Both enabled lanes
still execute concurrently. Google failure cannot stop Telegram and vice versa.
Three total automatic logical attempts, uncertain-outcome reconciliation, scoped
receipts and file leases remain untouched. Mapping selection never grants “Saved.”

The helper must not weaken authoritative private-channel/creator checks, fetch
history for unrelated chats, enable automatic downloads or retain discovery state
after the relevant UI lifecycle. Account/channel text in UI should be privacySensitive.

## Validation schedule and handoff

Do necessary static checks only: Swift parsing of changed/new production files,
project/plist/source-registration consistency, local docs links and diff whitespace.
Use available real compiler checks where applicable, without fake modules/stubs or
claiming macOS/parse checks prove an iOS build. No local full Xcode download, unit/
simulator/device/account tests, live login, real provider calls, cloud dispatch,
IPA publishing, cache purge or USB changes in this assignment. The coordinated
integrated build/device session follows Architect review and critical corrections.

Record in this document: ownership, actual files changed, pinned request-schema
evidence, paging/cancellation and stale-result handling, diagnostics, exact checks,
unavailable checks and unresolved gaps. Check for concurrent Git changes before
staging; commit only assigned files in coherent commits and push main. Do not
overwrite another writer's changes or amend shared history. No milestone/release
tag merely for source completion.

Final Builder response: commit IDs, concise changes, static evidence, remaining
limitations and exact interfaces needed from Architect. Stop for Architect review;
do not advance into Google isolation, incremental scans, background scheduling,
custom Live Activity or other research proposals.

## Ownership / implementation / evidence

Unclaimed at handoff. Builder appends its claim and evidence here before editing
application files. This document is authorization for the exact scope above, not
evidence the picker or any proposed behavior works.
