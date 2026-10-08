# P8-R1 — first-run access, linking and presentation

Architect-owned batch, 2026-10-08. User tried build 1.0 (6): no Photos prompt,
overloaded/ugly screens; neither destination linked. User requests separate Google
login and better linking. This is first-run user evidence, not upload evidence.

Reserved paths: `App/Application/AppEnvironment.swift`, its `+Backup`,
`+Presentation`, `+Lifecycle` extensions; Dashboard view/state and four component
files; Settings view and new `GoogleAccountLoginView.swift`; Logs and NotUploaded
views; `scripts/generate_xcode_project.py` and generated project source registration;
`dependencies/google-vendor.json`; this document and README. No active Builder
assignment; earlier P7 build-log reservation is left untouched. No Core retry,
receipt, export or provider upload-protocol changes and no cloud dispatch here.
Also reserve `Packages/CloudifiedCore/Sources/CloudifiedCore/Snapshots.swift` for
photo/video totals from the existing completed-scan aggregate, independent of a
mapped provider; no database schema or queue transition changes.

## Diagnosis and decisions

- Photos authorization was requested only inside the backup drain. Back Up requires
  a connected destination, creating a setup dead end for this user. Permission and
  metadata scan must be explicit, provider-independent and available offline.
  Denied access needs an iOS Settings route, restricted access an honest explanation,
  limited access a clear scope. Zero accessible items and an unscanned library differ.
- Unconfigured screens displayed complete runtime dashboards, repeated status chips,
  large cards, empty session metrics and implementation explanations. Show setup
  actions first. Use system typography/colors, native lists and progressive detail;
  preserve all actual counts, concurrent transfers and actionable errors.
- Google currently accepts a manually pasted login token; there is no shared iOS
  Google account integration to isolate in build 6. Add the pinned upstream
  `EmbeddedSetup` browser route with a newly created nonpersistent WKWebView store
  for each sign-in. No Safari/native-Google cookie import, URL-scheme token handoff,
  broad cookie clearing, app-owned password form or ordinary OAuth substitution.
  User-selected password autofill/passkeys are distinct from imported login cookies.
- Source: [AccountConnectWebView.swift at the existing pin](https://github.com/g8row/PhotosBackup/blob/3c88269e18b9d4515e97d846c5816bd836285c3e/App/Sources/AccountConnectWebView.swift),
  [upstream auth rationale](https://github.com/g8row/PhotosBackup/blob/3c88269e18b9d4515e97d846c5816bd836285c3e/docs/ADR-001-auth-route.md).
  License retained; source and adapted-file digests go in google-vendor.json.
  No dependency revision changes. Adapt with strict cookie-domain checks,
  one-shot capture, visible sanitized errors, bounded foreground-only cookie checks
  and complete timer/observer/webview teardown. Existing protected token exchange,
  same-token identity verification and account-scoped reconciliation remain.
- Apple's [nonpersistent store](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/nonpersistent())
  holds website data in memory. A system ephemeral authentication session can isolate
  cookies for ordinary OAuth, but cannot expose this private flow's HttpOnly token.
  Google's [standard OAuth guidance](https://developers.google.com/identity/protocols/oauth2/native-app)
  disallows embedded OAuth user agents. This is the selected upstream private route,
  not a supported public OAuth flow; acceptance/challenges on this iPhone are still
  unverified. Display real failures rather than changing quota/upload semantics.
- Keep manual token entry under Advanced, not the default. Show verified account
  after successful linking. Linking alone never starts a backup; the user starts it.

## Linking improvements to implement next, after this correction is observed

1. Telegram: credentials once, then phone, code/2FA, channel selection and confirmation.
   Existing authentication already shows the current step; shorten technical copy.
   Fetch/paginate actual owned private channel candidates through TDLib and verify
   creator permissions/auto-delete at selection. Retain manual numeric ID under
   Advanced. Do not infer ownership from a channel name or invent a channel list.
2. Optionally create a private archive channel after an explicit user action; confirm
   account/name before creation. Do not create channels as an invisible login side effect.
3. Both providers: separate “Signed in”, “Destination verified”, “Checking existing
   uploads” and “Ready” states. Keep account selection separate from the enable switch.
   Clear retry/repair guidance and preserve the healthy provider during errors.
4. Offer an account review before the first backup; cloud destination and accessible
   Photos scope should be visible together. Canceling login must not unlink a working
   account; switching must settle old transfers and keep receipts destination-scoped.
5. After initial setup is stable, review real screenshots for spacing/Dynamic Type,
   wording and the least information needed per screen. No fake dashboard previews.

Channel picker/creation and a pre-mapping Google account confirmation are proposals,
not features claimed in this batch. The Google success screen reviews an already
verified/mapped account; no upload starts merely from showing that success screen.

## Validation and device recheck

Implemented source changes:

- Allow Photos access and local metadata scan before linking, with serialized task
  ownership, shutdown cancellation, live permission refresh and source error logs.
  Completed-scan aggregate supplies Photos/Videos totals even with no mapped account.
- Native list dashboard, explicit setup rows, one state-appropriate backup action,
  compact provider/transfer rows, expandable media/detail data; short Settings root
  with separate destination pages. Log/failure filters collapse; pagination only
  appears when available and a toolbar action always returns to newest records.
- Isolated Google browser flow and verified-account success state; manual token
  import under Advanced. Cookie observer supplementation stops on background,
  capture, cancellation, failure or ten-minute deadline; numeric network failure
  codes enter existing safe Google diagnostics. No credential-bearing URLs logged.
- Telegram remains a real current-step form with one-time credential link, input
  validation and code/password autofill hints. Channel mapping still requires a
  numeric ID; the candidate picker above remains future work.

Static/compiler evidence (no device/account execution):

1. `swift build --package-path Packages/CloudifiedCore --disable-sandbox` with
   temporary module caches: exit 0. Existing inaccessible user-cache/CLT linker
   path warnings remain; no Core tests or schema migration.
2. The 48-source portable Swift 6 typecheck from P5-P6-INTEGRATION: exit 0 after
   the new scan totals/control ownership. Seven existing macOS27 Photos filename
   deprecation warnings; no new errors.
3. Real DashboardViewState and all four dashboard component sources typechecked
   against macOS SwiftUI in Swift 6 with warnings-as-errors: exit 0. No mock modules.
4. The exact production Google cookie Coordinator declaration, extracted unchanged
   into a temporary file with its Foundation/WebKit/Core imports, typechecked
   against macOS WebKit in Swift 6 with warnings-as-errors: exit 0. Corrected the
   navigation decision handler's MainActor/Sendable signature during this check.
   This does not check UIViewRepresentable/UIKit or an iOS SDK.
5. All 59 app Swift files parsed; generated source registration adds exactly one
   new browser source. Project/Info.plist lint, 30 Markdown files' local targets,
   four adapted Google file SHA-256 entries and `git diff --check`: pass.

This batch has no new IPA until a separately coordinated manual build. Build 6
cannot contain these fixes. Full iOS/SwiftUI/UIKit compilation, installed visual
review, live Google challenge/cookie compatibility, Photos prompt/scan and provider
behavior remain unverified. No local Xcode download or USB change.

On the next build, check without linking first: Allow Photos access opens the iOS
prompt; limited access scans real counts; denied/restricted states are actionable;
no account/network is required for local scan. Then connect Google while Safari and
other Google apps are signed in: the new browser should require its own sign-in,
cancel/reopen should discard browser state, errors should be readable, and Settings
should show the verified identity. Never put tokens/passwords/screenshots containing
them in Git. Upload integrity, quota, dedup/reinstall/background claims remain P7/P8
runtime checks after linking succeeds.
