# P4-A — pinned dependencies and secure native client foundation

Current handoff: Builder submitted P4-A; Architect requires P4-A-R1 corrections
in P4-REVIEW.md before accepting this foundation or starting P4-B. This original
assignment remains the foundation contract, not evidence of completion.

Assigned 2026-10-08 by Architect following P3-R2 review/direct completion.
P3 is ready for the next implementation handoff with static/compiler evidence;
original quality, iOS lifecycle, source storage peaks and reinstall behavior remain
untested until P7. This assignment authorizes **P4-A only**. The Architect owns
P4-B's critical upload/acceptance/receipt/reconciliation integration and reviews
this foundation before that work. P5/P6 are not assigned yet.

## Read and claim

Read AGENTS/README, this file, dependencies/pins.json, the provider/recovery
sections of CORE-INTEGRATION, and relevant RUNTIME/RELIABILITY contracts. Claim
paths in handbook 3. Allowed: provider adapters, a credential store/native TDLib
package/bridge, dependency metadata/licenses, reproducible dependency build script,
necessary project/generator/package links and handbook 3. Changes to the existing
manual cloud workflow may add deterministic dependency assembly before xcodebuild;
do not dispatch it or introduce scheduled/separate automatic jobs. Source PhotoKit
files and Packages/CloudifiedCore remain Architect-owned/read-only for this batch.
No dashboard/settings UI work or real account/media operations during development.

## Immutable source inputs

The Architect resolved and recorded exact source pins via public git ls-remote:

- PhotosBackup: `3c88269e18b9d4515e97d846c5816bd836285c3e`.
- Official TDLib: `42e6a5259551178d1dab54a22ad96d14bd906e20`.

These are selected source revisions, not known-good release/artifact claims.
Fetch exact commits into a bounded reference/vendor location; verify HEAD equals
its pin. Do not fetch moving main/master for integration. Inspect license text at
those revisions before copying code; retain notices and record vendored file paths,
source hashes and focused patches. gunshot remains a reference, not another app/UI
or injected Google Photos host. Inspect dependencies from the pinned source and
freeze their exact source/artifact revisions/checksums before adding any of them.
Do not invent transitive pins or mark license/build checks completed in advance.

## Implement this batch

1. **Google dependency boundary.** Bring in only the necessary pinned GPMC/auth
   implementation and its real dependencies. Preserve upstream licenses and original
   request behavior; no recreation of the non-quota protocol from memory. Isolate
   it behind an app-owned module/interface and record how the future adapter calls
   its auth/hash/transfer/finalization operations. Do not connect real uploads,
   emit receipts, declare remote absence or patch quality/device/commit semantics
   in this batch. Record unsafe logging/persistence or API/interface needs for the
   Architect; any compatibility/redaction patch must be small and documented.
   Do not copy upstream app views, gallery/export pipeline, demo records or scheduler.
2. **Real TDLib native package.** Provide deterministic assembly for the pinned
   JSON C ABI and a narrow Swift bridge. Use the documented ABI/ownership rules
   from the exact header, not guessed function declarations or fake C functions.
   Build under a no-space temporary directory for the selected future cloud build,
   target the required iPhone device architecture, and describe packaging/linkage.
   Keep generated native artifacts in ignored build/cache paths; never commit them.
   Record the output checksum and build/toolchain provenance when actually produced
   at P7. Missing artifacts must fail clearly, not silently substitute a fake client.
   Do not download/build Xcode, SDKs or large native artifacts on this Mac/USB.
3. **TDLib lifecycle/JSON plumbing.** Implement one owned client/session lifecycle
   with off-main receiving, bounded request/update handling, correlation, deadlines,
   cancellation and a terminal close path. Follow the pinned C pointer lifetimes;
   copy/decode while valid and do not leak native allocations. Deliver critical
   auth/send/control updates without silently dropping them; coalesce noisy progress
   separately before UI/task creation. Correctly preserve integer account/chat/message
   IDs without Double rounding. Do not create a TDLib client per file. Expose real
   native updates and initialization/error state for P4-B; don't fabricate Connected,
   send success, receipt, history completeness or terminal reader ownership.
4. **Credential vault.** Implement native Keychain storage for future Google tokens,
   user-supplied Telegram API credentials and a securely generated TDLib database
   encryption key. Protect items for device use after first unlock; distinguish
   not configured, locked/access denied and storage failure. Bind credentials by
   an explicit private session/profile reference, never display name/token hash.
   Server-verified account/channel identity and Core Destination selection belong
   to P4-B/P5. Never infer connected/recovered from a saved token. Keep secrets out
   of UserDefaults, SQLite ledger, source files, logs and diagnostics exports.
   Do not reuse example Telegram credentials or inspect/write the user's existing
   Keychain through tools to try this code. Inputs/login UI are connected in P5.
5. **Safe foundation diagnostics.** Instrument real client initialization/close,
   request correlation/timeouts, auth-state transitions and classified native errors
   with the whitelisted diagnostic API. Do not log raw JSON, phone numbers, channel
   titles, cookies, request bodies, headers, tokens, database keys or local media
   paths. Report persistence failures; no fake logs generated for screenshots.
   Respect separate native auth database, native media cache and source staging roots.
6. **Project/build integration.** Add actual package/target/header references and
   regenerate project source entries as needed. Document exact prerequisites and
   fail-fast errors for the manual P7 workflow. Keep all heavy dependency assembly
   on the chosen cloud runner, with exact source/dependency pins and licenses.
   No cloud dispatch, paid runner, schedule, signing material or USB installation.

## Boundary and handoff

P4-A provides dependency/native/credential primitives. It does not implement or
claim completion of ProviderAdapter.inspect/upload, final Google mediaKey receipts,
Telegram final send receipts, startup transport/history reconciliation, mapping
recovery attestations or user settings commands. The Architect implements/reviews
those critical P4-B paths using the real primitives supplied here. Supply a compact
API/file map: request methods, update stream, session/close state, credential refs,
native build/ABI inputs and unresolved blockers. No second ledger or retry scheduler.
Three logical attempts and source/transport ownership remain the Core contract.

No demo/mock data, runtime/unit/simulator/device/account tests or cloud build cycles.
Use necessary compiler/header/typecheck/syntax/docs/project checks only. An iOS-only
native artifact may prevent full local typecheck; record that precisely, without
inventing an SDK/binary or treating parse as linkage evidence. Do not claim all
features work because a compiler check passes. Commit/push coherent changes, release
claimed paths and stop for Architect review before P4-B or any later batch.
