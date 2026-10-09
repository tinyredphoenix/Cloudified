---
cursor:
  subagentId: "bc-a847b6df-4b87-5ae9-8976-c21fbff0d84d"
---

# Cloudified independent read-only audit

**Auditor role:** senior iOS / Swift concurrency / native networking / reliability review (fresh eyes).  
**Workspace:** `/Users/naman/Documents/App Projects/Cloudified`  
**Git status:** `main...origin/main`, untracked `scratch/` only.  
**Named baseline in prompt:** `3307274f28b22e94d5c0d71adb2727bbfd544226`.  
**Actual HEAD reviewed:** `66509b1255b7419af75a143737fc3f2d2507eb95` (`docs: add read-only audit handoff`).  
**Delta vs named baseline:** documentation-only (`docs/READ-ONLY-AUDIT-PROMPT.md`). App/Core/adapter sources match `3307274`.  
**Published device build:** **2.1 (11)** from `2dc17a0b95baf962685c7051b35793c3e95230cb`.  
**Current source short version:** **2.2** (pending; not built / published / device-tested).  

**Upstream / inspiration references:**

| Name | Path / URL | Revision / note |
| --- | --- | --- |
| PhotosBackup (local pin) | `/private/tmp/cloudified-audit-references/PhotosBackup` | `3c88269e18b9d4515e97d846c5816bd836285c3e` |
| PhotosBackup **latest release** | https://github.com/g8row/PhotosBackup/releases/latest | **0.3.7** (2026-09-20) — Free-up-space / edited uploads / Live motion / SideStore BGTask |
| TDLib | `/private/tmp/cloudified-audit-references/tdlib` | `42e6a5259551178d1dab54a22ad96d14bd906e20` |
| gunshot | `/private/tmp/cloudified-audit-references/gunshot` | `a3723ef0ccdfb99e1bbcdd11dc8a5d9328718cde` (comparison only) |
| gotohp | https://github.com/xob0t/gotohp | README / oauth_token EmbeddedSetup credential model |
| Telegram-Drive | https://github.com/caamer20/Telegram-Drive | Desktop MTProto workspace (v4.0.0 README) |
| TG-S3 article | https://dev.to/young_gao/i-built-unlimited-free-cloud-storage-using-telegram-and-its-s3-compatible-4p4g | Bot API + Cloudflare Worker S3 façade |

**OpenSSL:** pinned in `dependencies/pins.json` (`45e844fa2a14ec92d146bd8f5778ac130b6625fb` / 3.5.9); **source absent** from the reference bundle. Only pin/license/build-integration evidence reviewed.  
**Google vendor digests:** all four vendored files match `dependencies/google-vendor.json` SHA-256.  
**Method:** read-only source inspection, Git log/diff, local diagnostic JSONL, public TDLib/PhotosBackup sources, fetched upstream READMEs/release notes. No builds, tests, account access, Keychain reads, or edits.

---

## Executive summary

Linking remains blocked on device for **both** providers on published **2.1**. Current **2.2** source addresses several known causes (Telegram init ordering already fixed on 2.1; phone normalization / closed native names; Google JSON identity headers + fresh-token reuse). Independent review still finds **release-blocking residual risks**: Google immutable identity still depends on OpenID `userinfo` with an Android Photos access token (upstream PhotosBackup never does this); Telegram auth `400` still falls through to **formatRejected** when the native message is unknown; TDLib **406** is still classified/emitted as a user-visible failure; startup inventory can abort on Google retained rows.

**Expanded codebase pass** adds further high-severity reliability risks: hardcoded `BGContinuedProcessing` identifier without SideStore-aware bundle matching (class of bug fixed in PhotosBackup 0.3.7), and no continued-processing progress heartbeat during long single-item uploads (iOS ~30s stall expiry documented by PhotosBackup/DTS). Resource/wiring gaps include an unconnected `shutdown()` path that never closes TDLib in production, MainActor-unsafe cookie-store callbacks, and deliberately unbounded critical diagnostic growth.

| Severity | Auth/reliability (prior) | Codebase expansion (new) | Total |
| --- | --- | --- | --- |
| P0 | 1 | 0 | **1** |
| P1 | 4 | 2 | **6** |
| P2 | 5 | 7 | **12** |
| P3 | 3 | 4 | **7** |

**New critical/high from this expansion:** **P0 +0**, **P1 +2** (SideStore BGTask identifier; continued-processing progress heartbeat).

---

## Current auth diagnosis (by provider / version)

### Telegram

| Version / revision | Evidence | Verdict |
| --- | --- | --- |
| **2.0** `f080be2` | Local telegram report: `setNetworkType` / startup `deadlineExceeded` before parameters | **Past failure.** Corrected in P9-R1; do not re-file as current. |
| **2.1** `2dc17a0` | Report metadata build 11; seq 51–63: native create → `getAuthorizationState` → `setNetworkType` (~0.05s) → `setTdlibParameters` → `waitPhoneNumber`. Seq 65–74: `setAuthenticationPhoneNumber` fails twice with TDLib **400**, classified `formatRejected`. Native message omitted from report. | **Init fixed. Phone submit blocked.** 400 alone does **not** prove bad API credentials, ban, or invalid phone. |
| **2.2 source** `3307274` / HEAD | `internationalPhoneNumber`, `settings: NSNull()`, closed `DiagnosticNativeError`, preserve phone field on failed submit (clear only after success) | **Plausible mitigation; device-unverified.** Residual: unmatched 400 → `formatRejected`; 406 still processed. |

### Google

| Version / revision | Evidence | Verdict |
| --- | --- | --- |
| **2.1** `2dc17a0` | Master token HTTP 200; Photos token HTTP 200; credential saved (`googleCredentialAvailable: true`); `googleIdentity` fails HTTP **400** on fresh connect and saved retry; browser completed / popup closed / linking incomplete. Identity stage wraps internal auth + userinfo — **which endpoint 400’d is not proven** by the report. | **Exchange works; mapping blocked at identity.** |
| **2.2 source** | `photosProtocolHeaders: false` for userinfo; fresh unbound token reused in `GPMCClient.init`; authenticate failures keep `.googleAuthenticate` stage | **Header/token-reuse fixes are real source defects relative to 2.1.** Residual: OpenID `userinfo` with Photos Android token may still 400 (upstream never uses this path). |

### Diagnostics host

| Version | Evidence |
| --- | --- |
| 2.0 | paste.rs HTTP 400 (historical) |
| 2.1 | dpaste POST 201 + raw GET 200; body size matched telegram report (~26785 bytes) | **Working on device for 2.1.** |

---

## Release-blocking findings (ordered by severity)

### P0 — Google linking can remain blocked: OpenID `userinfo` on Photos Android access token

1. **Severity / confidence:** P0 — **hypothesis requiring runtime verification**, strongly supported by 2.1 device evidence + upstream comparison.  
2. **Location:** `App/Adapters/GooglePhotos/GPMCClient.swift` `verifiedSubject()` ~327–349; called from `GooglePhotosClientSession.verifiedSubject()` ~116–117 → `GooglePhotosProviderAdapter.mapVerifiedAccount()` / `verifiedScope()` ~24–35. Upstream PhotosBackup pin uses **email from auth fields**, not `userinfo` (`TokenExchange.swift` / `CredentialStore.swift`). gotohp likewise treats account identity as the email returned by the master-token exchange.  
3. **Trigger:** Browser OAuth completes → master + Photos token redeem succeed → `mapVerifiedAccount` → `verifiedSubject` GET `https://openidconnect.googleapis.com/v1/userinfo` with Bearer Photos token.  
   **Observed (2.1):** `googleIdentity` failed HTTP 400 (~0.53s / ~0.15s); connect failed; credential remained saved.  
   **Expected:** immutable `sub` for destination fingerprint, or a proven same-token identity path.  
   **Impact:** Google destination never maps; backups cannot start for Google despite successful exchange.  
4. **Why guards fail:** 2.2 separates JSON headers (`photosProtocolHeaders: false`) and reuses the fresh token — necessary vs 2.1 protobuf envelope — but does **not** prove Google accepts this token type at OpenID userinfo. Closed `unsupported_token_type` / JSON error parsing helps diagnosis only after the next device report. Immutable-sub requirement correctly rejects email-only identity.  
5. **Minimal correction:** Keep same-token immutability; validate on device whether userinfo accepts the redeemed Auth token after header fix. If rejected, obtain a token Google’s OIDC endpoint accepts **without** weakening binding (e.g. separate openid token from the same exchange if available, or documented tokeninfo/`sub` path that is cryptographically bound to the Photos credential). Tradeoff: extra round-trip / protocol research vs forever-blocked linking.  
   **Verify later:** 2.2 device report must include `googleError` closed name + which stage (authenticate vs identity) on failure/success.

---

### P1 — Telegram phone `400` still surfaces as “format unsupported” when native message is unknown

1. **Severity / confidence:** P1 — **confirmed source defect** (UI/classifier); **device-supported** on 2.1 for the symptom.  
2. **Location:** `TDLibClient.classify` ~398–416; `FailureExplanation` `.formatRejected` ~26; phone path `setAuthenticationPhoneNumber` ~225–239.  
3. **Trigger:** User submits phone at `waitPhoneNumber`; TDLib returns error code 400 with a message not exactly matching `DiagnosticNativeError` raw values (or empty/unknown).  
   **Observed (2.1):** two phone attempts → `cause: formatRejected`, `domain: tdlib`, `code: 400`; user-facing copy describes unsupported **media format**.  
   **Expected:** authentication-class cause + closed native name when known; never “original format” for phone auth.  
4. **Why guards fail:** 2.2 maps known names (`PHONE_NUMBER_INVALID`, banned, flood, API id, …) correctly, but `default` + `code == 400` still returns `.formatRejected`. Auth-sheet failures use `ProviderSupport.safe` → this classifier.  
5. **Minimal correction:** For auth methods (or any pre-ready auth state), map unmatched 400 → `.authenticationRejected` (or keep waiting for closed name), never `.formatRejected`. Persist `nativeError` on the failed `nativeRequest` (already wired in `requestTrace`) and show `FailureExplanation` for auth causes.  
   **Verify later:** 2.2 report must show closed `nativeError` on phone failure; UI must not say format unsupported.

---

### P1 — TDLib error 406 is still processed and can be displayed

1. **Severity / confidence:** P1 — **confirmed source defect** vs P9-R2 / audit invariant (“406 must not be processed or displayed”).  
2. **Location:** `TDLibClient.nativeReason` ~369–371 returns `nil` for code 406 (good), but `classify` ~417 still returns `.providerRejected` with code 406; `TDLibSession.resolveFailure` ~297–308 still traces + emits `.failure`.  
3. **Trigger:** Any correlated TDLib response `error` with code 406 (known “must restart worker” / ignore class in TDLib clients).  
   **Impact:** sticky provider error, misleading Logs/UI, possible wrong wait/retry behavior.  
4. **Why guards fail:** Message redaction alone is insufficient; the error remains a first-class failure.  
5. **Minimal correction:** Treat 406 as non-terminal ignore for request correlation (complete without user-facing failure / without writing durable auth failure), matching TDLib client conventions. Tradeoff: must not hide real auth failures that incorrectly use 406.  
   **Verify later:** inject/observe 406 in a controlled native response; confirm no UI/log failure row.

---

### P1 — `establishStartupInventory` aborts on any non-Telegram retained transfer

1. **Severity / confidence:** P1 — **confirmed source defect**.  
2. **Location:** `App/Application/AppEnvironment+Recovery.swift` `establishStartupInventory` ~104–105: `guard row.destination.provider == .telegram else { return }`.  
3. **Trigger:** Crash/kill between `FileLeaseStore.hold` and `transportFinished` for a **Google** transfer (or any non-Telegram retained row) → cold start inventory scan.  
   **Observed/expected:** Comment says Google foreground transports cannot outlive process, so Google rows should be **skipped** (or force-released), not abort the whole function.  
   **Impact:** `startupInventoryCompleted` stays false → `performIdleCleanup` never sweeps/reclaims staged originals (`AppEnvironment+Lifecycle.swift` ~102–105) → disk growth / stuck leases until a later recovery path clears Google retains and retries inventory. Bootstrap calls inventory **before** recovery (`AppEnvironment.swift` ~164–168), so first pass fails closed whenever Google retains exist.  
4. **Why guards fail:** Recovery may heal later, but inventory success depends on recovery ordering/success; `return` is not `continue`.  
5. **Minimal correction:** `continue` for non-Telegram retained rows (optionally mark Google retains terminal immediately given foreground-only transport), then complete inventory.  
   **Verify later:** simulate Google retained row in ledger; assert inventory completes and sweeps run.

---

### P1 — 2.1 Google identity HTTP envelope bug (corrected in 2.2 source; still device-pending)

1. **Severity / confidence:** P1 — **confirmed source defect on 2.1**; **corrected in current source**, acceptance unverified. Listed so architect does not treat 2.1 device 400 as unexplained after shipping 2.2 without a device pass.  
2. **Location (2.2 fix):** `GPMCClient.request` ~375–386 `photosProtocolHeaders`; `verifiedSubject` passes `false`. Fresh token reuse: `GPMCClient.init` ~199–209.  
3. **Trigger:** identity GET previously inherited Photos protobuf `Content-Type` / Android Photos `User-Agent`.  
4. **Guards:** none on 2.1.  
5. **Correction status:** present in pending 2.2; **must not** be claimed fixed until device evidence. If 2.2 still 400s, escalate to P0 finding above.

---

### P1 — Hardcoded BGContinuedProcessing identifier ignores SideStore bundle rename *(new)*

1. **Severity / confidence:** P1 — **hypothesis**, same failure class **confirmed on device** by PhotosBackup 0.3.7 / issue #2.  
2. **Location:** `App/Adapters/System/BackupContinuation.swift` ~15, ~20–42: `identifier = "com.tinyredphoenix.Cloudified.backup"`; `App/Resources/Info.plist` `BGTaskSchedulerPermittedIdentifiers` same string. No use of `Bundle.main.bundleIdentifier`.  
3. **Failure scenario:** SideStore (or similar sideload resign) rewrites the running bundle ID to `com.tinyredphoenix.Cloudified.<TEAMID>` while leaving the built Info.plist identifier unchanged (or rewriting inconsistently). iOS then refuses register/submit because the registered identifier is not a permitted prefix of the **running** bundle ID. `BackupContinuation.init` sets `state = .unavailable` when register fails → every backup stays foreground-only with “background continuation unavailable.”  
4. **Upstream contrast:** PhotosBackup `ContinuedBackupPolicy.identifierPrefixes(bundleIdentifier:permitted:)` tries running-bundle prefix first, then falls back to build-time plist wildcards; 0.3.7 release notes: “Automatic Backup never ran in the background on SideStore installs.”  
5. **Proposed correction:** Derive continued-processing identifiers from `Bundle.main.bundleIdentifier` + permitted Info.plist entries (wildcard-aware), matching PhotosBackup’s SideStore-safe policy; add a unit test for `…Cloudified.TEAMID` vs build-time `…Cloudified.backup`.  
   **Verify later:** SideStore-signed install; assert `BGTaskScheduler.register` succeeds and `continuation.state != .unavailable`.

---

### P1 — No continued-processing progress heartbeat during long uploads *(new)*

1. **Severity / confidence:** P1 — **hypothesis** with strong upstream/device documentation.  
2. **Location:** `BackupContinuation.update` ~48–56 only updates when called; sole caller `AppEnvironment+Presentation.swift` ~115–117 from UI refresh (throttled ~500 ms when snapshots change). No heartbeat timer while a single transfer is in flight.  
3. **Failure scenario:** One Google/Telegram original upload stalls progress reporting for >~30 s (large video, rate-limit wait, slow network). iOS expires the `BGContinuedProcessingTask` (PhotosBackup cites Apple DTS / forums thread 805554). `expirationHandler` → `backgroundExpired()` stops the run even though work was healthy.  
4. **Upstream contrast:** PhotosBackup `ContinuedBackupProgress.nextReported(after:heartbeat:)` artificially advances one unit inside the current item so progress never stalls.  
5. **Proposed correction:** While `state == .running` and a backup is active, run a bounded heartbeat (e.g. 10–15 s) that calls `update` without claiming false completion; keep real snapshot-driven jumps.  
   **Verify later:** background a multi-minute upload; confirm task does not expire solely due to stalled reported progress.

---

## Additional findings

### P2 — Google upload failures always claim `.terminal` ownership even after commit RPC may have been sent

1. **Confidence:** confirmed source defect.  
2. **Location:** `GooglePhotosProviderAdapter.upload` catch ~197–206 always returns `.terminal`; `commitSubmitted` only affects `acceptance`.  
3. **Impact:** `BackupEngine` ~295 releases holds whenever ownership is `.terminal`, including uncertain finalization. Staged bytes may be swept while remote outcome is unknown (mitigated if Photos re-export + hash reconcile works; fails if asset disappears). Telegram path correctly uses `.retainedByTransport` for uncertain.  
4. **Correction:** return `.retainedByTransport` when `commitSubmitted` (or keep hold until inspect confirms). Verify with kill during commit.

### P2 — Auth diagnostic fan-out triples phone failures

1. **Confidence:** confirmed; device-supported on 2.1 (one nativeRequest failed + three `failure` ops per attempt).  
2. **Location:** `TDLibSession.resolveFailure` emits requestTrace + `.failure`; `TDLibClient.setAuthenticationPhoneNumber` catch also `emitDiagnostic(.failure)`.  
3. **Impact:** noise, faster diagnostic pruning pressure, harder reading of public reports.  
4. **Correction:** single terminal emission site for correlated native errors.

### P2 — Verification / email / code fields cleared before await

1. **Confidence:** confirmed.  
2. **Location:** `TelegramAuthSheet` code/email sections clear local `@State` before `perform` (~171–172, ~217–218, ~232–233). Phone clears only after success (~146) — good.  
3. **Impact:** failed code entry forces retype; contradicts “preserve input on failure” spirit for non-phone fields.  
4. **Correction:** clear only after successful step transition.

### P2 — Outbound TDLib `int64` fields sent as JSON numbers

1. **Confidence:** confirmed source vs TDLib JSON ABI docs; practical risk moderated because TDLib `from_json(int64)` accepts Number **or** String (`td/tl/tl_json.h` ~91–100).  
2. **Location:** e.g. `TelegramProviderAdapter` / `TelegramChannelDiscovery` pass `Int64` chat/message IDs into `[String: Any]` → `JSONSerialization`. ABI header states int64 are stored as String.  
3. **Impact:** typical channel IDs fit exact numeric representation; still a contract drift and a footgun for edge IDs / future fields.  
4. **Correction:** encode int64 request fields as decimal strings.

### P2 — Google `GPMCError.explanation` embeds server prose into `LocalizedError`

1. **Confidence:** confirmed.  
2. **Location:** `GPMCClient.explanation` ~262–274 appended into thrown messages (“Google said: …”). SafeFailure path usually strips this, but any localizedDescription/logging escape can leak provider text into UI/OSLog.  
3. **Correction:** keep closed reasons only; never concatenate raw bodies into thrown user/error strings.

### P2 — Critical diagnostic events never rotate *(new)*

1. **Confidence:** confirmed by design comment + prune query.  
2. **Location:** `Packages/CloudifiedCore/.../Diagnostics.swift` ~83–95: prune deletes only `critical=0`; failures/attempts/critical events are “deliberately outside rotation.” Byte budget (`10 MiB`) tracks rotating payload only.  
3. **Failure scenario:** Months of dual-lane backups write unbounded `critical=1` rows (every failure, attempt, receipt-adjacent critical). SQLite/WAL grows without bound → slower Queries, export timeouts, disk pressure. `DiagnosticFallback` is capped at 50 entries (good); durable ledger is not.  
4. **Correction:** age/count cap for non-receipt critical events, or separate receipts from “critical diagnostics”; keep receipts durable, rotate noisy criticals.  
   **Note:** intentional reliability tradeoff for forensics — treat as defect only if unbounded growth is unacceptable for target library sizes.

### P2 — `WKHTTPCookieStore.getAllCookies` callback mutates MainActor state off-actor *(new)*

1. **Confidence:** confirmed source race under Swift 6 isolation.  
2. **Location:** `GoogleAccountLoginView.Coordinator.checkCookie` ~91–103: `store.getAllCookies` completion writes `reading` / `captured` / calls `onToken` without `Task { @MainActor in … }`. Timer path correctly hops to MainActor (~75–76); observer/navigation paths call `checkCookie` on MainActor but the nested cookie callback may not.  
3. **Failure scenario:** Concurrent timer + `cookiesDidChange` overlap; `reading` flag and `captured`/`onToken` race → double token delivery or missed capture; potential EXC_BAD_ACCESS / Swift concurrency runtime traps in strict builds.  
4. **Correction:** hop the cookie callback onto MainActor before touching coordinator state; keep `reading` gate MainActor-only.

### P2 — `shutdown()` never wired; `deinit` cancels tasks but does not close TDLib *(new)*

1. **Confidence:** confirmed wiring gap.  
2. **Location:** `AppEnvironment+Lifecycle.shutdown` ~123–141 closes `telegramAdapter`; **no call sites** in `CloudifiedApp.swift` (only scenePhase active/background). `AppEnvironment.deinit` ~149–155 cancels observers/tasks + `networkMonitor.stop()` only.  
3. **Failure scenario:** Ordered native close (`authorizationStateClosed` wait ≤10 s) never runs in production. Process kill cleans OS resources, but test hosts / future multi-window / in-process restart leave an orphaned TDLib client_id until `TDLibProcessReceiver` capacity (`maxActiveSessions = 1`) blocks recreate.  
4. **Correction:** invoke `shutdown()` from app termination / intentional teardown; or have `deinit` schedule a best-effort close documentation that process death is the only teardown path.

### P2 — Originals-only export vs PhotosBackup 0.3.7 edited recognition *(new; product/correctness)*

1. **Confidence:** confirmed intentional divergence with concrete upstream evidence.  
2. **Location:** `PhotoKitScanner.role` ~54–66 maps only `.photo` / `.pairedVideo` / `.video` / `.alternatePhoto` — **not** `.fullSizePhoto` / `.fullSizeVideo` / `.fullSizePairedVideo`. Commit uses `useQuota: false, saver: false` → Pixel XL / quality 3 (`GooglePhotosProviderAdapter` ~183; `GPMCClient.commitProfile` ~533–534).  
3. **Failure scenario:** Edited library items upload **unedited originals**. Google Photos iOS app may show them as “Not backed up” and omit them from **Free up space** (PhotosBackup 0.3.7 release: library of ~8,500 items, Not backed up 8,145→0 after switching to edits). Users who expect Google-app recognition/free-up behavior will see false “not backed up” despite Cloudified receipts.  
4. **Correction (if product wants Google-app parity):** adopt edited-first resource selection + optional edit-base extra step + optional Live motion backlog setting as in PB 0.3.7. If product insists on archival originals, document the Free-up-space gap explicitly in Settings/README.  
   **Classify:** defect vs nice-to-have depends on product promise; reliability impact is user-trust / storage-management, not silent data loss of originals.

### P2 — Unmatched TDLib `@client_id` updates are silently dropped *(new)*

1. **Confidence:** confirmed.  
2. **Location:** `TDLibProcessReceiver.routeIncomingJSON` ~188–193: unknown `clientID` → `return` (no log).  
3. **Failure scenario:** Race between unregister and late native updates after close; or unexpected second client_id. Updates vanish — usually benign during close, dangerous if registration failed partially.  
4. **Correction:** count/trace closed-name “orphan client update” diagnostics without payloads; fail closed if orphans arrive while a session claims to be active.

### P3 — Unknown Telegram auth 400 also wrong category for non-phone auth steps

Same classifier fallthrough affects code/password/email if TDLib returns unmatched 400.

### P3 — `scratch/` present untracked

Not in production inclusion evidence (`generate_xcode_project.py` / app sources). Treat as non-production; leave untouched per prompt.

### P3 — Background continued processing is iPhone-only and fail-strategy

`BackupContinuation` uses `BGContinuedProcessingTaskRequest.strategy = .fail`. Foreground Google uploads cannot continue after process death (`continuesAfterProcessExit = false`). Documented limitation, not a silent claim of durable background Google transfers — but **background upload reliability remains unverified on device**.

### P3 — Dead / unconnected adapter protocol stubs *(new)*

1. **Confidence:** confirmed.  
2. **Location:** `GooglePhotosAdapterProtocol`, `TelegramAdapterProtocol`, `SystemAdapterProtocol` — each file is the **only** reference; no conformers. `PhotoLibraryAdapterProtocol` **is** implemented by `PhotoLibraryPipeline`. Real Google/Telegram work uses `ProviderAdapter` (`GooglePhotosProviderAdapter`, `TelegramProviderAdapter`).  
3. **Impact:** dead code / misleading architecture surface; not runtime failure.  
4. **Correction:** delete stubs or wire them; avoid dual protocol stories.

### P3 — `PreparationGate` waiters uncapped *(new; low practical risk)*

1. **Location:** `BackupEngine.swift` `PreparationGate` ~28–36. Comment: “FIFO waiters are bounded by the two provider workers.” No hard cap (unlike `SharedExportPermit` max 16 / `DemandSourceProducer` max 1).  
2. **Risk:** if a future caller awaits prepare outside the two-lane model, waiters grow. Today’s engine structure makes this unlikely.  
3. **Correction:** assert `waiters.count < 2` or document as invariant test.

### P3 — `AppEnvironment.deinit` vs long-lived `@StateObject` *(new)*

`deinit` path is effectively unreachable in production (`CloudifiedApp` `@StateObject`). Cleanup must be explicit (`shutdown`) or process-death. Already covered by P2 wiring gap; listed so teardown tests are not assumed to run.

---

## Complete codebase audit (expanded scope)

### Bugs (logic / concurrency / races / error handling / state machines / edge cases)

| ID | Sev | Summary | Refs |
| --- | --- | --- | --- |
| AUTH-G1 | P0 | OpenID userinfo with Photos Android token | `GPMCClient.swift` ~327–349 |
| AUTH-T1 | P1 | Unmatched TDLib 400 → formatRejected | `TDLibClient.swift` ~414–415 |
| AUTH-T2 | P1 | 406 still classified/emitted | `TDLibClient.swift` ~369–417; `TDLibSession.swift` ~297–308 |
| REC-1 | P1 | Startup inventory `return` on Google retain | `AppEnvironment+Recovery.swift` ~104–105 |
| AUTH-G2 | P1 | 2.1 identity envelope (fixed in 2.2 source) | `GPMCClient.swift` ~375–386 |
| BG-1 | P1 | Hardcoded BGTask id / SideStore | `BackupContinuation.swift` ~15; Info.plist |
| BG-2 | P1 | No continued-processing heartbeat | `BackupContinuation.swift`; `AppEnvironment+Presentation.swift` ~115 |
| UPL-G1 | P2 | Google fail always `.terminal` after commit | `GooglePhotosProviderAdapter.swift` ~197–206 |
| AUTH-T3 | P2 | Triple diagnostic fan-out on phone fail | `TDLibSession` + `TDLibClient` phone catch |
| UI-T1 | P2 | Code/email cleared before await | `TelegramAuthSheet.swift` |
| ABI-T1 | P2 | int64 as JSON numbers | Telegram adapters |
| SEC-G1 | P2 | Server prose in GPMCError | `GPMCClient.swift` ~262–274 |
| CONC-G1 | P2 | Cookie callback off MainActor | `GoogleAccountLoginView.swift` ~91–103 |
| MEDIA-1 | P2 | Originals vs edited Free-up-space | `PhotoKitScanner.swift` ~54–66 |
| TD-1 | P2 | Orphan client_id silent drop | `TDLibBridge.swift` ~188–193 |

### Resource leaks (files / sockets / URLSessions / TDLib / PhotoKit / leases / BG / timers / observers / continuations)

| Area | Verdict | Evidence |
| --- | --- | --- |
| Google `URLSession` | **Sound** for per-op sessions | `ForegroundFileUploadTransport` recreates session, `finishTasksAndInvalidate` on complete; `GooglePhotosClientSession` ephemeral + `invalidateAndCancel` in defer |
| PhotoKit export | **Sound** cancel path | `PhotoResourceExporter` install/cancel races lock-protected; `withTaskCancellationHandler` |
| PhotoKit thumbnails | **Sound** | `RowThumbnailLoader` cancels request in `cancel`/`deinit`; NSCache count/cost limited (100 / 16 MiB) |
| Cookie timer / observer | **Mostly sound; race above** | `stop()` invalidates timer + `store.remove(self)`; dismantle clears non-persistent store |
| File leases / reservations | **Sound structure** | Hold/release/fence patterns in `FileLeaseStore`; inventory bug (REC-1) can block sweeps |
| TDLib client close | **Wiring gap** | Close implementation exists; `shutdown()` never called; deinit does not close |
| Ledger observers | **Bounded** | max 4 observers; `onTermination` removes |
| SharedExportPermit | **Bounded** | max 16 waiters; cancel removes continuation |
| DiagnosticFallback stream | **Bounded** | 50 entries; `deinit` finishes continuation |
| Network monitor | **Sound** | `stop()` + deinit cancel |

### Memory leaks / retain cycles / unbounded caches / queue growth

| Item | Sev | Notes |
| --- | --- | --- |
| Critical events never pruned | P2 | `Diagnostics.pruneDiagnostics` only `critical=0` |
| DiagnosticFallback | OK | Cap 50 |
| RowThumbnailLoader cache | OK | NSCache limits + memory-warning clear |
| PreparationGate waiters | P3 | Uncapped but 2-lane bounded in practice |
| URLSession upload response buffer | OK | 1 MiB overflow cancel |
| TDLib pending requests / subscribers | OK | Explicit capacityExceeded limits |
| NotUploaded/Logs pages | OK | Cleared on background; “No unbounded append/cache” comment |

### Dead / unconnected / unreachable / unused paths

| Item | Sev | Notes |
| --- | --- | --- |
| `AppEnvironment.shutdown()` | P2 | Defined, never called from `CloudifiedApp` |
| `GooglePhotosAdapterProtocol` / `TelegramAdapterProtocol` / `SystemAdapterProtocol` | P3 | No conformers; superseded by `ProviderAdapter` |
| `scratch/` | P3 | Untracked; not in Xcode generator evidence |
| Phase-placeholder comments in protocol stubs | P3 | Stale planning prose |

### Improvements / hardening (prioritized)

**Defects (fix before features):**  
1. P0 Google identity path proven on device.  
2. P1 Telegram auth classifier + 406 ignore.  
3. P1 startup inventory `continue`.  
4. P1 SideStore-safe BGTask identifiers.  
5. P1 continued-processing heartbeat.  
6. P2 Google `.retainedByTransport` on uncertain commit.  
7. P2 cookie MainActor hop; wire `shutdown()`; critical-log rotation policy.

**Nice-to-haves / product:**  
- Edited-upload / Free-up-space parity with PhotosBackup 0.3.7 (if desired).  
- Optional Live Photo motion backlog toggle (PB default off).  
- Delete unused adapter protocol stubs.  
- Encode TDLib int64 as strings.  
- Deduplicate auth diagnostics; preserve code/email inputs.

---

## Upstream inspiration comparison

### PhotosBackup latest **0.3.7** (+ local pin)

| Topic | PhotosBackup | Cloudified | Correctness / reliability impact |
| --- | --- | --- | --- |
| Account identity | Email from token exchange | OpenID `userinfo` `sub` with Photos token | **Cloudified P0 risk**; PB never hits userinfo |
| oauth_token capture | In-app WKWebView + cookie poll | Same lineage (`GoogleAccountLoginView` adapted from PB); Cloudified adds MainActor timer hop but cookie callback still off-actor | Race is Cloudified-local |
| Upload version | **Edited** for Google-app recognition / Free up space | **Originals only** (`PhotoKitScanner.role`) | User-visible “not backed up” / Free-up-space gap |
| Live Photo motion | Optional setting (off by default); attach motion to still | Supports still+motion pair in adapter when recipe includes motion; no PB-style backlog toggle | Different product surface |
| SideStore BGTask | Bundle-aware prefixes (0.3.7 fix) | Hardcoded identifier | **Cloudified P1 hypothesis** |
| Continued processing heartbeat | Artificial intra-item progress units | Snapshot-driven update only | **Cloudified P1 hypothesis** |
| Rate limit 429 | Queue-wide backoff | Disposition/retryAfter plumbing present; full queue wait-out not re-audited as PB-parity | Needs device matrix |
| Non-quota quality | Pixel XL / quality 3 path | `useQuota: false, saver: false` → same profile mapping | Wire intent aligned |

### gotohp (https://github.com/xob0t/gotohp)

| Topic | gotohp | Cloudified |
| --- | --- | --- |
| Platform | Desktop GUI/CLI | iOS |
| Credential | Manual `oauth_token` cookie paste **or** ReVanced/root Android capture | Automated EmbeddedSetup WKWebView cookie capture (gotohp Option 1 model) |
| Identity | Account email in credential store | Immutable `sub` via userinfo (stricter; currently blocking) |
| Upload API | Same unofficial Photos Android protocol family | Pinned GPMC from PhotosBackup |

**Matters for reliability:** Cloudified correctly automates gotohp’s EmbeddedSetup cookie path on-device; it then **diverges** by requiring OIDC `sub` instead of exchange email — the main Google linking risk.

### Telegram-Drive (https://github.com/caamer20/Telegram-Drive)

| Topic | Telegram-Drive | Cloudified |
| --- | --- | --- |
| API | MTProto desktop client (user API id/hash) | TDLib JSON C ABI on iOS |
| Storage model | Saved Messages + channels as folders; optional client encryption | Channel destination + caption content tags; dual Google lane |
| File cap | Exactly 2e9 bytes object cap documented | Video split / part threshold in PhotoLibrary planning |
| Background | Desktop background queues | iOS BGContinuedProcessing only |

**Matters for reliability:** Not a drop-in protocol reference. Cloudified’s auth/classifier/406 issues are TDLib-JSON-specific; Telegram-Drive’s desktop MTProto stack does not validate Cloudified’s phone `formatRejected` bug. Shared lesson: treat API id/hash + phone auth failures as **auth-class** errors, never media-format errors.

### TG-S3 DEV.to article (Bot API + Cloudflare Worker S3)

| Topic | TG-S3 | Cloudified |
| --- | --- | --- |
| API | Bot API via Workers; D1 metadata; R2/CDN cache | User TDLib session; durable local SQLite receipts |
| Auth | Bot token / S3 credentials | User phone/QR/password TDLib auth |
| Semantics | Object store façade; latency mitigated by cache tiers | Photo library backup with leases, dual lanes, reconcile |

**Matters for reliability:** Almost no shared failure modes. Do **not** import Bot API retry/cache assumptions into TDLib user-client code. Cloudified’s stronger local ledger/receipt model is appropriate for backup integrity; TG-S3 optimizes for S3 API compatibility and CDN reads.

### Local references still present

`/private/tmp/cloudified-audit-references/{PhotosBackup,tdlib,gunshot,manifest.json}` verified present for this pass. OpenSSL source still absent (pin only).

---

## Past failures / non-findings (do not re-file as current)

| Item | Status |
| --- | --- |
| Telegram `setNetworkType` awaited before parameters (2.0 deadlock) | Fixed in 2.1 device evidence |
| paste.rs diagnostic HTTP 400 | Replaced by dpaste; 2.1 device success |
| Export-folder create aborting provider assignment | Corrected in P9 source narrative; not re-validated as still present |
| Blind resend of unknown remote outcomes | Core `willSend` / reconcile / `acceptance: .unknown` paths look intentionally fail-closed in source |
| Concurrent dual-lane batching | `BackupEngine.runReadyBatch` starts both providers before await; Google failure does not cancel Telegram lane in engine code |
| Foreground Google URLSession retain cycle | Transport breaks delegate ownership via invalidate after each op |
| PhotoKit export cancel before request-ID publish | Lock + `cancelRequested` handles race |
| Thumbnail / fallback unbounded growth | Both capped |
| DiagnosticFallback | Capped at 50; not a leak |

---

## Independently challenged 2.2 changes

| Change | Assessment |
| --- | --- |
| International phone normalize / no country guess | Sound; rejects missing `+` and leading 0 after `+`. Does not by itself explain or fix server 400. |
| `settings: NSNull()` | Compatible with AuthManager null settings; official Python example **omits** the key — null should be fine, device must confirm. |
| Closed native rejection names | Good; incomplete if message ≠ exact enum raw value → still formatRejected. |
| Preserve phone on failure | Implemented correctly (clear after success only). |
| JSON identity headers | Necessary fix for 2.1 envelope bug; insufficient alone if token type rejected. |
| Fresh token reuse | Correct vs discard+immediate reauth; reduces redundant authenticate on connect. |
| Strict same-token `sub` | Correct reliability invariant; currently the linking bottleneck. |
| Ignore/display rules for 406 | **Not fully implemented** (see P1). |

---

## Major open questions

1. Exact TDLib message string for the 2.1 phone 400 (invalid phone vs API id vs flood vs other).  
2. Exact Google endpoint/body for identity 400 after 2.2 headers (authenticate vs userinfo; `unsupported_token_type`?).  
3. Whether OpenID `userinfo` can ever succeed with this Android Photos Auth token.  
4. Google original/non-quota behavior on real accounts (source uses `useQuota: false, saver: false` → Pixel XL / quality 3 — **wire intent only**).  
5. Live Photo native pair acceptance and motion-after-still ordering on device.  
6. Reinstall dedup: content-hash staging IDs + receipt tags look designed for stability; **not device-proven**.  
7. Background continued-processing real behavior on iOS 26 hardware (register success + heartbeat need).  
8. SideStore-signed Cloudified: does BGTask register fail today?  
9. Product intent: archival originals vs Google Photos app Free-up-space recognition.  
10. OpenSSL/TDLib native link closure beyond pin manifests (artifact assembly not re-audited here).

---

## Could not verify (explicit disclosure)

- Any live Google/Telegram account, browser login, or phone verification.  
- iPhone / simulator runs, IPA install, or SideStore update of pending 2.2.  
- Whether 2.2 identity header fix clears the HTTP 400.  
- Whether normalized E.164 phones are accepted by Telegram for this API id/hash pair.  
- Google quota / original-quality server-side treatment; metadata preservation end-to-end.  
- Live Photo pairing on device; HEIC/RAW/HDR byte-identical round trips.  
- Reinstall reconciliation against real remote libraries.  
- Background task grant rates, SideStore identifier match, and expiration under memory pressure / stalled progress.  
- OpenSSL full source / compiled archive member audit (pin only).  
- gunshot behavioral parity (comparison reference only; Photos-app injection assumptions do not apply).  
- Secret values in Actions (`CLOUDIFIED_SOURCE_DEPLOY_KEY` referenced, not read).  
- Completeness of every TDLib internal path beyond ABI/AuthManager/JSON helpers relied on by the app.  
- Telegram-Drive MTProto internals / TG-S3 Worker code (README/article only).  
- Runtime retain-cycle instrumentation (Instruments) — static analysis only.  
- Production multi-month SQLite growth from critical events — inferred from prune rules, not measured.

---

## Coverage table

| Area | Files / evidence reviewed | Upstream compare | Gaps |
| --- | --- | --- | --- |
| Handbook / P9 / distribution | `AGENTS.md`, `README.md`, `01-ARCHITECTURE`, `02-BUILD-PHASES`, latest `03-BUILD-LOG` / `04-DECISIONS`, `P9-*`, `DISTRIBUTION`, specs | n/a | Older planning prose treated as stale |
| Device diagnostics | `/private/tmp/cloudified-{telegram,google}-11.jsonl` version-filtered | n/a | Native phone message absent; identity endpoint ambiguous |
| Google auth / session / GPMC | `GoogleTokenExchange`, `GPMCClient`, `GooglePhotosClientSession`, `GooglePhotosProviderAdapter`, `GoogleAccountLoginView`, vendor digests | PhotosBackup pin + **0.3.7 release**; gotohp oauth_token README | Live token acceptance; quota quality |
| Telegram / TDLib | `TDLibClient`, `TDLibSession`, `TDLibJSON`, `TDLibBridge`, `TelegramProviderAdapter`, discovery, auth sheet | `td_api.tl`, `AuthManager.cpp`, `td_json_client.h`, `tl_json.h`; Telegram-Drive README (MTProto contrast) | Full TDLib internals; device phone cause |
| Core ledger / engine / leases | `BackupEngine`, `QueueTransitions`, `FileLeases`, `Ledger`/SQLite, `ContentIdentity`, diagnostics prune | n/a | Runtime crash races unexecuted; critical DB growth unmeasured |
| PhotoLibrary | Pipeline, preparer, exporter, splitter, scanner, shared permit, recipes | PhotosBackup MediaExport / 0.3.7 edited+motion rules | Device originals / iCloud-only / Free-up-space |
| System / security / BG | Network policy, diagnostics uploader, failure explanation, keychain store, `BackupContinuation`, Info.plist BGTask ids | PhotosBackup ContinuedBackupPolicy / SideStore fix / heartbeat | SideStore install; heartbeat expiry on device |
| App / presentation / lifecycle | `AppEnvironment(+*)`, `CloudifiedApp`, Settings/Dashboard/Logs/NotUploaded | n/a | Visual/UI device pass; `shutdown` never exercised |
| Dead / unused wiring | Adapter `*Protocol.swift` stubs, `shutdown()` call graph | n/a | Generator may still compile stubs |
| Build / CI / pins | `pins.json`, vendor JSON, workflows, Info.plist, generator version 2.2 | OpenSSL pin only | Native archive seal / link not re-run |
| Inspiration (remote) | gotohp README; Telegram-Drive README; TG-S3 DEV.to | Compared for auth/storage model diffs | No source trees cloned for gotohp/Telegram-Drive/TG-S3 |
| scratch/ | presence only | n/a | Not production |

---

## Smallest-fix-first plan (for architect)

1. **Ship/diagnose Google identity on device (2.2):** confirm whether userinfo succeeds with JSON headers + fresh token; if not, replace/augment identity source without dropping immutable binding (P0).  
2. **Fix Telegram auth classifier:** auth-path 400 → authentication causes; ensure closed `nativeError` reaches Logs/UI (P1).  
3. **Ignore TDLib 406** for correlated requests / UI (P1).  
4. **Fix `establishStartupInventory` Google `return` → `continue` / foreground retain handling (P1).**  
5. **SideStore-safe BGTask identifiers** from running bundle + permitted list (P1).  
6. **Continued-processing progress heartbeat** while running (P1).  
7. Align Google uncertain commit with `.retainedByTransport` (P2).  
8. MainActor-hop cookie callback; wire or document `shutdown()`; decide critical-log rotation (P2).  
9. Deduplicate auth failure diagnostics; preserve code/email inputs on failure (P2/P3).  
10. Encode TDLib int64 as JSON strings (P2).  
11. Product decision: originals vs edited Free-up-space parity (P2 product).  
12. Only then: dual-provider upload quality, Live Photo, reinstall, and background device matrix.

---

*End of expanded read-only audit. No code was modified; no PR created; no builds/accounts/publishes.*
