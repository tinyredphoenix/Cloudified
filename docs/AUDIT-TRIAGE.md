# Architect triage of the independent audit

2026-10-09. Source baseline 3307274; current HEAD 66509b1 adds only the audit
handoff document. [Independent report](INDEPENDENT-AUDIT.md) is preserved as
external evidence, not a set of implementation instructions. Architect reviewed
the named current source paths, the pinned TDLib schema/JSON parser, local WebKit
SDK headers and Apple background-task documentation. No source changes, account
tests, builds or publications in this review. Current pending version remains 2.2;
latest installed-report evidence is 2.1 (11).

The report is useful but its severity totals are not an accepted bug count.
Several items are hypotheses, duplicates, intentional product differences or
already-corrected 2.1 issues. Do not apply its smallest-fix plan mechanically.

## Findings accepted or narrowed

| Audit item | Architect verdict | Next correction / verification |
| --- | --- | --- |
| AUTH-G1: Android Photos token at OpenID userinfo | Unresolved linking risk, not a confirmed current P0 defect. The 2.1 trace wraps refresh plus identity, so its 400 does not isolate userinfo. 2.2 adds fresh-token reuse and actual refresh failure stage. | Preserve immutable credential binding. Use the next 2.2 device report to determine token-refresh versus identity rejection; research a supported same-credential identity path if token type/scope is rejected. Never substitute unverified email or unrelated-token subject. |
| AUTH-T1 / duplicate P3: unknown auth 400 becomes media-format failure | Confirmed classifier defect. Known names are covered; unmatched 400 still falls through to transfer/formatRejected. | Classify with request/auth context at the session boundary and ensure auth-sheet catches preserve it. Keep media errors distinct. Closed native reasons only; do not infer credentials invalid or ban. |
| REC-1: Google retained row stops startup cleanup inventory | Confirmed cleanup-availability coupling; the return is a fail-closed guard, not proof that recovery is never retried. requestRecovery calls establishStartupInventory again. Google recover verifies identity before releasing dead foreground holds, so failed login/offline state can keep cleanup fenced. | Separate local evidence that old foreground readers are gone from network account verification. Preserve uncertain checkpoints and all native/in-process readers. Do not blindly replace return with continue or release holds without an ownership proof. |
| BG-1: fixed identifier and sideloaded bundle ID | Credible source integration risk. Identifier is a constant in both BackupContinuation and plist; runtime bundle-ID changes can break prefix/permission matching. This app's signed identifier and registration failure are not established by the audit. | Resolve from running bundle plus actual permitted identifiers, validate registration/submission and log safe failure codes. Verify on SideStore-signed app. Do not silently rewrite plist at runtime or update upstream dependency pins. |
| BG-2: no progress during a long individual asset | Confirmed reporting gap with documented expiration risk. AppEnvironment+Presentation passes only confirmed asset counts to BackupContinuation, so genuine byte progress does not advance system progress. | Report actual export/transfer/processing progress separately from confirmed-upload counts. Define monotonic per-run progress and explicit retry/wait behavior. Do not add artificial heartbeat units or guarantee background survival. |
| Critical event growth | Confirmed disk-growth risk, not a proven heap leak. Diagnostics.pruneDiagnostics deletes only critical=0; most operations, including lease events, are critical and excluded from the tracked rotating-byte budget. | Bound diagnostic event history separately from durable receipts, attempts, active failures and uncertain checkpoints. Preserve actionable state and pruning counters. Reconcile with RUNTIME-SPEC's 10 MiB/seven-day diagnostic budget. |
| Auth diagnostic fan-out | Confirmed overlapping emissions in session resolution, auth methods and application reporting. Not itself the cause of phone rejection. | One correlated terminal trace plus one actionable failure; preserve stage/native code rather than suppressing information. |
| Non-phone code/email cleared before await | Confirmed UI behavior. Phone is now retained on failure; other auth inputs still clear before submitting. | Keep retryable input until successful transition; still clear sensitive fields on dismissal/unlink. No credential logging. |
| Raw GPMC error prose | Confirmed construction of bounded provider prose inside LocalizedError, but no demonstrated public-log leak. Current ProviderSupport/session boundaries classify/redact it. | Remove arbitrary server prose at its source as defense in depth; retain closed reasons and safe status codes. Keep diagnostics useful without raw response text. |

## Recommendations rejected or deferred

| Audit item | Reason |
| --- | --- |
| AUTH-T2: ignore every TDLib 406 response | Incorrect interpretation of the pinned contract. td_api.tl line 16 forbids processing/displaying the error **message**, not handling the numeric failure. nativeReason returns nil for 406; TDLibError.errorDescription omits its raw message. Ignoring a correlated failed response can strand a continuation or fabricate success. Do not implement the suggested non-terminal-ignore behavior. |
| CONC-G1: cookie completion is definitely off MainActor | Not supported by the target SDK. WKHTTPCookieStore and getAllCookies completion are explicitly WK_SWIFT_UI_ACTOR; WKFoundation maps that to NS_SWIFT_UI_ACTOR. The local SDK and actual Swift source compiler checks support current isolation. A defensive hop is optional, not evidence of a current race. |
| UPL-G1: unknown commit requires retainedByTransport | Confuses remote acceptance with input ownership. Contracts.swift defines terminal by actual file reader/callback completion. ForegroundFileUploadTransport resolves through didCompleteWithError and invalidates its per-operation session. The adapter separately stores uncertain checkpoint/acceptance, preventing blind resend. Retaining a dead transport would create stuck holds. Keeping an archival local copy after uncertain outcomes would be a separate storage policy, not this ownership fix. |
| shutdown never called proves a production native leak | No reachable in-process app-environment replacement is shown. The single StateObject intentionally lives for process lifetime; OS termination tears down process resources. iOS does not promise a reliable async termination hook. Keep explicit shutdown for genuine owner replacement; do not close TDLib merely on background entry or schedule unsafe deinit cleanup. Review if a restart/multi-owner feature is introduced. |
| Outbound int64 numeric JSON is a current ABI precision bug | The pinned td/tl/tl_json.h accepts Number or String and parses the original decimal text into int64; JSONSerialization receives Swift Int64 here, not JavaScript Double. No demonstrated precision loss in this path. Decimal strings can improve canonical consistency, but are not a login-blocking fix. |
| Orphan native client updates must fail closed | A late update for an unregistered client during close is legitimately discardable; no shown active-client registration-loss path. Optional bounded orphan counters may help diagnostics. Failing a live session because another old client's update arrives would be unsafe. |
| Originals should switch to edited resources | Conflicts with the user's archival-original requirement. Google Photos app recognition/free-up-space parity is not promised. Preserve originals; document recognition limitations if device evidence establishes them. Do not delete local photos or add free-up-space features. |
| Protocol stubs, scratch, PreparationGate capacity, StateObject deinit | Cleanup/future-hardening observations, not release blockers. scratch is untracked and not compiled. Gate is private and used by two provider lanes, so no reachable unbounded caller path was shown. StateObject lifetime duplicates the shutdown observation. |
| AUTH-G2: fixed 2.1 envelope as a new release blocker | Already corrected in pending 2.2. Headers are protocol hygiene; the old 400 alone does not prove the header caused rejection. Do not count it again as a confirmed current defect. |
| Foreground-only Google, task strategy fail | Explicit design limits. Continued processing can help a user-started run; it does not make foreground URLSession durable after process death. Keep truthful UI and reconciliation. |

## Background evidence and constraints

Apple states that minimal/no reported progress can increase termination priority:
https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask .
Apple DTS discusses an unpublished approximate 30-second stalled-progress cadence
and recommends real URLSession progress/delegate or child progress, not invented
completion units: https://developer.apple.com/forums/thread/805554 . A precise
cadence is not a permanent API guarantee. Task execution may still expire under
resource constraints, even with progress.

Identifier documentation requires a prefix containing the submitting app's bundle
ID; validate against the actual signed app. Apple's documentation and WWDC examples
show differing static/wildcard presentations, so do not treat the audit's preferred
wildcard approach as the only proven registration form:
https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/init(identifier:title:subtitle:) ;
https://developer.apple.com/videos/play/wwdc2025/227/ .

PhotosBackup remains pinned at 3c88269. Its release comparisons are useful context,
not permission to update dependencies or adopt edited exports/artificial progress.
No later upstream implementation was imported or treated as this app's runtime
evidence during triage.

## Proposed implementation order

1. Fix auth-context classification, consolidate correlated diagnostics and preserve
   retryable auth input. Keep all safe rejection evidence needed for the next phone
   test. The Google acceptance question remains explicitly unresolved.
2. Remove remote-login dependence from proven-dead foreground-reader inventory,
   then add bounded diagnostic-event retention without touching recovery records.
3. Correct signed-bundle-aware background registration and report measured progress
   throughout long files. Preserve honest confirmed counts and expiration recovery.
4. Finish a single integrated compiler/build pass and publish 2.2 only under explicit
   build/publication authorization. Phone linking is the first device gate, followed
   by simultaneous providers, original byte/metadata checks, failure isolation,
   crash/reinstall reconciliation and large-video background behavior.

No fixes are applied by this document. The independent report's claim of complete
coverage is the auditor's statement; this triage cross-checks its named findings
and does not substitute for runtime leak instrumentation or a new exhaustive audit.
