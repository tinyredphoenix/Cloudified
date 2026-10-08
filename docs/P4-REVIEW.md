# P4-A review and historical P4-A-R1 corrections

Current assignment: [Architect P4-B](P4-B.md); [R2](P4-R2.md) and this R1 handoff
are historical after Architect source completion.

2026-10-08. Reviewed Builder commits 9e6fe9e and edb53dd, actual provider/native/
credential/build sources and pinned upstream headers/schema/CMake. The compiler
report is useful syntax evidence, but **P4-A is not accepted for P4-B integration**.
This file assigns Builder P4-A-R1 only. Architect P4-B starts after foundation review.

Architect directly restored the pinned Google per-chunk autoreleasepool and fixed
Keychain database-key creation: corrupt bytes fail without replacement; atomic
insert-if-absent prevents competing vaults overwriting the winning database key.
Keychain updates retain device-only after-first-unlock protection. Google source
hashes are recorded in dependencies/google-vendor.json. Architect restored exact
upstream license bytes: Builder had substituted MIT-style wording into the TDLib
Boost disclaimer. Preserve the actual source license texts and these fixes.

Architect also made the repository public at the user's request, added cache
fingerprinting/validation and removed the swallowed native-assembly failure.
Read BUILD-CACHE.md; it defines the native artifact sealing contract, not working
native assembly evidence. No cloud/native/app/account test ran during this review.

## Corrections and evidence

1. **Native linkage is absent.** CTDLib currently defines weak td_* functions and
   dlsym fallback; Package.swift/project do not link build/tdlib/lib/libtdjson.a.
   Compiling the shim proves no real Telegram implementation. Replace fake/weak
   td_* definitions with genuine declarations/direct linkage. Missing native
   symbols/artifacts must fail link/build clearly; no C fallback client/functions.
   Header syntax-only/Swift typechecks may use declarations without linking;
   do not build a pretend native runtime to make a compiler check pass.
2. **Native assembly is incomplete.** The script has no pinned iOS OpenSSL or
   code-generation host phase, checks the wrong tdjson_static archive paths and
   copies one archive although pinned CMake declares tdjson_private/tdclient/etc.
   dependencies. Inspect pinned CMake/example/ios first; build/install or combine
   the complete JSON static link closure plus iOS OpenSSL/system libraries and
   required C++ linkage, or document a complete equivalent packaging choice.
   Pin actual non-SDK sources/artifacts and checksums/licenses before adding them;
   never link runner/Homebrew macOS crypto libraries into an iPhone binary. Distinguish
   macOS host code generation from arm64 iPhone device compilation. Use deployment
   26.0 and the selected cloud toolchain. Replace destructive fixed /tmp directory
   clearing with an owned mktemp workspace and cleanup trap. Honor build-root and
   cache-seal contract; extend fingerprint for additional recipe files. No heavy
   local/native/cloud assembly before P7. Clearly record unbuilt/linkage limitations.
3. **Deadlines/cancellation can hang.** sendRequest races Task.sleep against an
   unchecked continuation; group cancellation never removes/resumes that pending
   continuation, so task-group exit may wait forever. Use bounded actor-owned
   request records and one terminal resolver for response/error/deadline/cancel/
   native close. Validate finite positive bounded timeouts without UInt64 traps.
   Register and send atomically in session ownership; never send after registration
   fails or after closing. No uncancellable child task, duplicate resume or unbounded
   pending map. Terminal local timeout does not claim remote rejection/absence.
4. **Receiver/close ownership is unsafe.** New JSON td_receive is process-global;
   the pinned header prohibits simultaneous receive calls. Current sessions each
   start a detached loop, ignore @client_id, and close() fabricates .closed after
   ten seconds, without awaiting receiver completion or native closed acknowledgement.
   Provide exactly one owned global receiver with client-ID routing, or enforce a
   single session until its actual terminal acknowledgement and receive-loop join.
   Do not relaunch/hand over ownership while the old receiver/native client is
   uncertain. A close deadline is a classified unresolved-close failure, not proof
   that native readers released source/cache files. Concurrent close callers must
   await the same closure result. Cancellation must not turn the polling loop into
   a busy spin. Keep pointer copy and receive/execute lifetimes safe at the chosen ABI.
5. **Pinned authorization schema differs.** At this pin, setTdlibParameters has
   database_encryption_key:bytes; checkDatabaseEncryptionKey and the old wait-key
   state are absent. Current code sends the removed request, omits the key from
   parameters and includes absent enable_storage_optimizer. Use exact td_api.tl
   request fields/state transitions and base64-encoded vault key. Respond to the
   real wait-parameters event before initialization, handle supported auth states
   honestly, and retain unresolved-session ownership on init errors. Configure
   database/cache roots with required protection/backup exclusion through real
   storage APIs; no account operations while implementing.
6. **Streams/memory/IDs are not bounded safely.** AsyncStream defaults to unlimited
   buffering; listener/progress/pending maps have no caps. Throttling updateFile can
   discard the final reader/cache state. Define bounded critical delivery with
   explicit overflow failure/consumer backpressure, separate latest-value progress
   coalescing and guaranteed terminal updates; never silently drop send/auth/control.
   Evict progress state and bound subscribers/JSON bytes and nesting. Replace public
   @unchecked Sendable [String: Any] with a genuinely immutable Sendable JSON model
   or typed values. Integer identifiers must reject Boolean, fractional/rounded
   floating values and overflowing unsigned numbers rather than truncating/wrapping.
   Preserve exact signed 64-bit/string IDs from the pinned schema.
7. **Diagnostics were claimed but not implemented.** Foundation files currently
   contain no appendEvent/diagnostic sink calls. Inject the actual whitelisted Core
   event path for native init/close, request deadline/cancellation, auth transition
   and classified error. Bound delivery, propagate persistence failures and never
   log raw JSON/phone/API hash/password/key/token/server prose/local private paths.
   Restrict externally surfaced errors to safe classifications; raw TDLib error
   messages may be used privately for known-code classification only.
8. **Provenance and future transport injection.** Record required native transitive
   pins, original source hashes and focused vendoring/ABI patches, including the
   modified td_json_client include and handcrafted/generated export-header status.
   Google wire/profile behavior largely matches the pin; retain original/non-quota
   model/quality semantics and restored memory drain. Expose an initializer that
   lets Architect inject a real durable FileUploadTransport/network policy instead
   of always constructing foreground-only/no-op-cancel transport. No uploads,
   receipts, source exports, background transfer implementation or reconciliation
   in R1. Those remain P4-B/P6. Clarify unused duplicate credential key/bot fields
   and require explicit validated private profile references instead of silently
   using "primary" for every mapping.

## Builder scope and completion

Read AGENTS/README, this file, P4-FOUNDATIONS, BUILD-CACHE, relevant Core diagnostics/
provider/ownership contracts and RUNTIME. Claim only provider/security adapters,
CTDLib, native dependency metadata/licenses/assembly recipe, necessary project/generator
links and handbook 3. Architect owns build_cache.py and the workflow; request a
focused handoff need in the log rather than overwriting their contracts. Source
PhotoKit/Core remain read-only. No UI/P5/P6 or P4-B implementation.

Use necessary static/compiler/header/schema/project/docs checks, record exact
commands and limits. No demo/mock data, unit/runtime/account/device tests, cloud
dispatch or local/USB SDK/native artifact installation. An unavailable genuine
native link is a documented limit until P7, never authorization to add fake symbols.
Commit/push coherent fixes, release paths and supply an API/file map plus remaining
unbuilt evidence. Stop for Architect review before P4-B.
