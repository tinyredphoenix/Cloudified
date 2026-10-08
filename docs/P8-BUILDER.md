# P8-B2 — Builder assignment: full interface redesign and Telegram selection

Expanded at the user's explicit request on 2026-10-08. Expansion baseline `001c80b`.
Architect owns this handoff/README update before Builder claims implementation.
This replaces the earlier narrow setup-only UI assignment and its layout restrictions.
The user grants Builder full UI design freedom: the installed interface feels ugly,
unstructured and overly complicated. Google isolation, Core/protocol/background
optimization remain separate Architect batches. No concurrent Architect edits to
this batch's files while claimed. Research proposals are not a blanket assignment.

## Objective

Completely revamp the user-facing app in native SwiftUI: Dashboard, navigation,
Photos/Videos status, Settings, both linking flows, Not uploaded, error details and
Logs. Builder owns the information architecture, screen composition, visual style,
spacing, typography, colors, reusable components and appropriate interaction/motion.
Do not preserve the existing view layouts merely because they are implemented.
Builder may replace/split/reorganize the presentation layer freely. Preserve the
underlying production engine and every required capability, not the current UI.

Also replace Telegram's primary numeric channel-ID entry with a real, bounded picker
of eligible owned private archive channels. Keep manual ID under Advanced.
Implement the redesign; do not stop at a proposal or ask for approval of routine
design choices. This does not assign unrelated research features or engine changes.

## Read first

Read AGENTS.md, README, docs/01-ARCHITECTURE.md, docs/02-BUILD-PHASES.md,
docs/P8-FIRST-RUN.md and the relevant linking/ownership sections of
docs/P8-IMPROVEMENT-RESEARCH.md. Use docs/03-BUILD-LOG.md for historical ownership;
its old P7 active entry is not authorization for cloud dispatch or unrelated edits.
Read existing SettingsView/SettingsViewState, AppEnvironment account commands and
TelegramProviderAdapter.mapVerifiedChannel/verifyChannel to understand boundaries.
Read only relevant TDLib request/auth APIs and runtime/diagnostic rules.

## Presentation ownership and allowed paths

Claim these paths and actual start HEAD in this document before editing:

- All `App/Presentation/` views, navigation, reusable components and presentation
  models, including new/renamed files. Preserve real command/state contracts;
  add view-specific formatting/models where useful. See protected browser internals below.
- `App/Resources/Assets.xcassets/` for UI colors and small UI assets. Keep the current
  AppIcon unchanged in this batch; no decorative photo downloads or media samples.
- `App/Application/CloudifiedApp.swift` only for root presentation/theme wiring;
  retain AppEnvironment ownership, startup and scene lifecycle behavior.
- New `App/Adapters/Telegram/TelegramChannelDiscovery.swift` — read-only helper
  using existing TDLibClient.request, not a native/session/protocol rewrite
- New `App/Application/AppEnvironment+TelegramChannels.swift` — narrow discovery
  facade using existing client and diagnostics; no replacement command/backup owner
- `Cloudified.xcodeproj/project.pbxproj` and `scripts/generate_xcode_project.py` only to
  register production presentation/discovery files and UI assets consistently
- `docs/P8-BUILDER.md` for ownership, findings, implementation/checks and handoff

Keep `App/Presentation/Settings/GoogleAccountLoginView.swift` read-only: it contains
security-sensitive WebKit navigation/cookie capture/teardown. Redesign the surrounding
Google screens, presentation and browser container freely while embedding this
existing component unchanged. Do not edit Google adapter/token exchange, Core packages,
TDLibClient/TDLibSession/TDLibBridge/TelegramProviderAdapter, credential storage,
existing AppEnvironment files, runtime contracts, dependency pins, workflows or
distribution repositories. No app-version bump or release tag in this batch.

Do not create another observable upload engine or move ledger logic into a view.
If presentation reshaping needs a missing composition field/command, describe the
exact interface for Architect rather than editing critical AppEnvironment machinery.

If a required interface change falls outside scope, document the exact missing
interface for Architect. Continue independent allowed work; do not invent fake
data, reach into another native client or bypass verification to hide the gap.

## Design freedom and required experience

Start with a focused audit of current screen hierarchy, repetition, clutter,
ambiguous labels, navigation dead ends and disconnected/empty states. Record the
chosen design direction briefly here, then implement it. No separate design approval
gate. Use the existing SwiftUI stack; no web view UI replacement or new UI framework.
Reference repositories supply provider implementation only, not visual inspiration.

Builder may change tab count/names, combine destinations/settings, move secondary
information into detail pages/sheets, replace cards/lists, and create a small coherent
design system. The initial screen must still be the backup dashboard. Logs and
Not uploaded must remain easy to reach; preserve discoverability after moving them.
Do not treat native Form/List as mandatory for every screen or duplicate the previous
layout with new colors. Aim for a calm, polished iPhone utility with deliberate
hierarchy and space, minimal visible controls, and short plain-language copy.

- Dashboard: one clear overall activity and primary action; separate Google and
  Telegram remaining/total/confirmed progress; actual current-file bytes; separate
  Photos and Videos summaries. No wall of chips, duplicate counters or nested cards.
  Make detailed counts/activity/reasons available without crowding the first screen.
- Setup: permission and provider connection actions are understandable before any
  uploads exist. Photos access does not depend on linking a provider. Distinguish
  unread library/limited access from an actual empty library. No onboarding carousel
  or invented success state; reuse real existing commands.
- Settings: sensible groups and concise names. Independent destination enable
  switches, account identity/link/change/disconnect, Wi-Fi policy and Live Photo
  choices remain available. Put technical/manual options under Advanced.
- Linking: one purposeful step at a time, clear cancellation/back behavior, readable
  inline failures and retry actions. Restructure both flows visually, preserving
  isolated Google browser behavior and existing Telegram authentication commands.
- Not uploaded: easy to identify asset, provider, reason and permitted remedy.
  Small thumbnails only. Keep attempts, missing components and safe technical detail
  accessible in details, without a dense troubleshooting report in every row.
- Logs: a quiet chronological view with useful collapsed filters and readable
  event detail. Preserve pagination, safe error codes and redaction.
- Complete all real states: unconfigured, permission denied/limited, scanning,
  linking, reconciling, uploading, waiting, paused, failed, completed and filtered
  empty results. A screen that lacks records must still feel intentional.
- Support Dynamic Type, VoiceOver, dark mode, Reduce Motion, safe areas and the
  keyboard. Avoid color-only status, clipped numbers, tiny controls or low contrast.
  Use restrained motion; no perpetual animations or extra polling to decorate UI.

The previous instruction forbidding new dashboard components is superseded.
New components and presentation structure are welcome; no unrelated product
features, gallery, viewer, editing, fake accounts or fake progress.

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
8. Fully redesign Google destination/auth presentation while preserving existing
   command calls, account-changing semantics, isolated embedded browser and token
   handling. Do not copy auth machinery into another view. Google identity
   confirmation before mapping and complete HTTP isolation are Architect work.
   Do not claim this batch makes account enforcement isolated or guaranteed.
9. Display sanitized discovery/mapping errors beside the relevant action. Offline
   is not “no channels”; loading is not “ready”; an empty filtered list is not
   “backup complete.” Distinguish app-only disconnect from Telegram native logout.
   Never display raw TDLib/auth responses or use `String(describing:)` for them.
10. Route discovery failure diagnostics through the existing safe reporting path.
    Do not log channel titles, chat IDs, phone numbers, credentials, private paths
    or response bodies. Avoid reporting a canceled read as a provider-wide backup
    failure. No new logging database or automatic log upload.
11. Apply the full redesign brief above, using native SwiftUI and genuine state.
    Builder chooses appropriate native/custom compositions. No hard-coded sample
    accounts, seeded channels, demo progress or fake-data previews. No gallery.

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
unavailable checks and unresolved gaps. Also record the design rationale and where
every previous essential action/status moved; identify remaining runtime/visual
acceptance checks without inventing screenshot/device evidence.
Check for concurrent Git changes before
staging; commit only assigned files in coherent commits and push main. Do not
overwrite another writer's changes or amend shared history. No milestone/release
tag merely for source completion.

Final Builder response: commit IDs, redesigned screens/navigation, concise changes,
static evidence, remaining
limitations and exact interfaces needed from Architect. Stop for Architect review;
do not advance into Google isolation, incremental scans, background scheduling,
custom Live Activity or other research proposals.

## Ownership / implementation / evidence

Unclaimed at handoff. Builder appends its claim and evidence here before editing
application files. This document is authorization for the exact scope above, not
evidence the picker or any proposed behavior works.
