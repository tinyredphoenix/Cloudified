# P8 Architect direct corrections

2026-10-08: user requested Architect to fix the remaining review findings directly.
Starting from `523e6bb`. Builder correction ownership is superseded for this batch.

## Exact ownership

Architect claims these paths before editing:

- App/Adapters/Telegram/TelegramChannelDiscovery.swift
- App/Application/AppEnvironment+TelegramChannels.swift
- App/Presentation/Settings/TelegramChannelPicker.swift
- App/Presentation/Settings/TelegramAuthSheet.swift
- App/Presentation/Settings/GoogleAuthSheet.swift
- App/Presentation/Settings/SettingsView.swift
- App/Presentation/Dashboard/Components/OverallActivityCard.swift
- App/Presentation/NotUploaded/NotUploadedView.swift
- App/Presentation/Logs/LogsView.swift
- README.md, docs/P8-BUILDER.md, docs/03-BUILD-LOG.md,
  docs/04-DECISIONS.md and this document.

No active Builder editing is reported. Leave untracked scratch/ untouched. No
dependency/Core changes, device/account tests or cloud dispatch.

Additional critical ownership claimed before editing: App/Adapters/Telegram/
TDLibSession.swift, TDLibClient.swift, TelegramProviderAdapter.swift and
App/Application/AppEnvironment.swift. Existing consumers will explicitly filter
their required update types before bounded-stream enqueue, so chat-list loading
cannot overflow receipt/auth delivery with irrelevant updates. Default raw stream
behavior and critical overflow fences remain unchanged; no additional consumer.

Also claimed: App/Adapters/System/BackupContinuation.swift. Its iOS-only continued
processing API is explicitly unavailable on Catalyst; tighten the compile-time gate
to exclude Catalyst without changing the iPhone implementation. This permits actual
UIKit/SwiftUI source typechecking using the already installed SDK's Catalyst surface,
with no replacement types or availability-check suppression.

Also claimed before creation: scripts/check_swift_source.py, to make the verified
parse/package/UI compiler sequence repeatable for Builder without Xcode or a cloud
build. It invokes only compilers, uses existing SDKs and keeps caches outside Git.

## Discovery decision

Replace false full-list paging with explicitly scoped recent candidates (up to 50
main + 50 archived chats), server-side title search (up to 50 candidates), and manual
ID verification. Inspect at most 10 candidates per user page and retain only that
bounded candidate/result window. This supersedes P8-B2's exhaustive enumeration
proposal; no complete-account discovery claim. The pinned getChats API is a prefix,
not a cursor. Search/manual verification supplies the path beyond the recent window
without another native update consumer or an unbounded index.

## Completed source corrections — 2026-10-09

- Discovery has no child/unstructured worker or actor reset call. Each caller owns
  cancellation; actor operations reject overlap. UI cancel/join, request generation,
  client/auth/command context and visibility fence every applied result/error. New
  context or dismissal discards bounded discovery state without closing TDLib.
- Recent window: one load/get per list, at most 50 main + 50 archive candidates.
  Explicit server title search: at most 50 channel matches. At most ten candidate
  inspections per user page, ten-second request timeouts and a thirty-second
  monotonic operation budget. No automatic whole-account scan or periodic polling.
- Malformed responses and all actionable classified failures surface. Unknown
  eligibility does not mean ineligible. Verified partial candidates/cursor survive
  a later failure and are displayed; retry resumes the bounded window. Current
  errors go to sanitized Telegram remoteCheck diagnostics without lane failure.
- Read-only identity review fetches the actual account and channel/ownership/retention
  state, including manual IDs. User confirms before the existing map command performs
  authoritative verification and remote reconciliation. Discovery cancels/joins first.
  Mapping owns its task and shows real checking/error states with repeated taps gated.
- Existing native subscriber filters run before bounded stream enqueue. App consumer
  receives auth/connection updates; adapter receives precisely its handled message,
  receipt, file and connection types. Default raw subscriptions, max-two consumers,
  critical overflow fencing and receipt processing remain intact.
- Telegram authentication has its own navigation/cancel behavior, visible sanitized
  command errors, real confirmed logout, actionable API help and secret cleanup.
  All authentication steps remain supported. Settings presents both auth flows as
  modals, avoiding Google nested-stack/back-pop behavior during exchange.
- Settings preserves access/scan, independent switches, account/channel changes,
  disconnect versus this-app logout, Wi-Fi and original Live Photo choices. Live
  Photo options have their own page; status labels distinguish disabled/disconnected.
  Version, build and revision support device reports. Command gates/confirmations
  are applied at the actions. Google browser/token implementation is unchanged.
- Logs now have quiet rows and a real event detail destination with complete safe
  codes/message/time. Filters, bounded pages, export and memory-only fallback remain.
  Not uploaded shows thumbnail/name/provider/reason rows; full remedy, permitted
  retry/recovery, resource coverage and durable attempt history live in details.
  History tasks cancel and fence late errors. No viewer or media playback added.
- Dashboard still displays independent provider details and actual component/attempt
  progress. Its intersection label now explicitly says saved to both destinations.

## Actual checks

Passed on the final working source:

1. `python3 scripts/check_swift_source.py --sdk
   /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk --cache-dir
   /private/tmp/cloudified-catalyst-cache` (one shell command): parses all 64 app
   sources, emits actual Diagnostics/Core modules, then typechecks all 64 app Swift
   files against real installed UIKit/SwiftUI in Swift 6. Exit 0, no diagnostics.
   It does not link or run the app. No mocked modules/types or suppressed availability.
2. Existing portable production typecheck passed after the discovery/facade rewrite
   (seven existing macOS 27 originalFilename warnings). Final complete Catalyst
   source check additionally covers the later native subscription/UI corrections.
3. Project and Info.plist plutil lint; 64 actual/64 unique generator sources, no
   missing/stale names; Python script syntax; local Markdown targets; diff whitespace.

The installed macOS 27 SDK lacks the usable SwiftUI State macro plugin in this
Command Line Tools environment. The already installed macOS 26.5 Catalyst surface
provides real UIKit/SwiftUI and permits the broader check. Initial attempts correctly
reported missing module/framework setup and Catalyst-unavailable continued processing;
the final command compiles the real package modules, includes iOSSupport frameworks
and uses the correct platform gate. No full Xcode/SDK installation was performed.

## Boundaries and next evidence

No updated IPA, account interaction, runtime tests, screenshots, USB changes or
cloud run in this batch. Catalyst typechecking excludes the iPhone-only background
branch and proves neither device linking nor service behavior, original preservation,
quota treatment, reinstall deduplication or visual quality. Google HTTP-session
isolation research remains a separate future critical batch; no ban-containment claim.

The next coordinated manual iPhone build/device session should check both linking
entry points, wrong credentials and retry, dismissal/reentry during discovery,
zero recent matches followed by title/manual lookup, real identity confirmation,
mapping failure/progress, remap and this-app-only logout. Also inspect long names,
Dynamic Type, dark mode, empty/error/log details and both independent backup lanes.
Use the existing private test-results template; do not publish personal diagnostics.
Builder holds pending explicit further assignment. Claimed paths are released after
this batch's commit/push; scratch/ remains untracked and untouched.

Pinned protocol evidence: [TDLib schema](https://github.com/tdlib/td/blob/42e6a5259551178d1dab54a22ad96d14bd906e20/td/generate/scheme/td_api.tl#L10080)
defines prefix chat retrieval, bounded loads, server known-chat title search and the
channel type filter. No dependency revision changed.
