# Cloudified runtime resource contract

Decision/specification, 2026-10-07. Defaults below are initial engineering budgets,
not measured performance claims. Tune only from physical-device evidence.
Companion: [reliability contract](RELIABILITY-SPEC.md).
All runtime measurements/scenarios are deferred to the first complete app test
and debugging stage. No demo data or intermediate app-test gates are introduced.

## Language and ownership

Use native Swift 6 with SwiftUI/PhotoKit/Foundation and SQLite. The only native
C/C++ component is TDLib and its narrow bridge. Reusing Apple's APIs and the
existing Swift Google integration avoids a JavaScript/Dart runtime and extensive
platform bridges. No media renderer, web-based UI or custom decoder is needed.

One scheduler owns queue decisions and transactional state transitions. Separate
ledger access, media staging, Google adapter, Telegram adapter and thumbnail cache.
Do not make every byte callback a Task or database transaction. MainActor owns
UI presentation only; hashing, disk I/O and history reconciliation run off it.

## Bounded memory and preparation

- Queue metadata/identifiers on disk, not arrays of full PHAsset objects or bytes.
  Fetch small pages, release completed page/resource references, and keep only
  active work in memory. Paginate error rows and logs as well as library/history.
- One media-export/hash worker, one Google transfer, one Telegram transfer initially.
  Keep at most one small ready resource ahead when the disk budget allows it.
- Stream data through bounded buffers; begin with 1 MiB file-read/hash chunks.
  Never `Data(contentsOf:)` a photo/video or buffer an entire multipart request.
  Compute SHA-256 and SHA-1 in the same pass where possible.
- [PhotoKit requestData](https://developer.apple.com/documentation/photos/phassetresourcemanager/requestdata(for:options:datareceivedhandler:completionhandler:))
  delivers data callbacks on an arbitrary serial queue. A cancellable exporter can
  write/hash each delivered chunk there without accumulating chunks in a second
  unbounded queue. Hold its request ID for cancellation; guard callback/continuation
  completion so every export finishes exactly once. Never decode the original.
- `writeData` is an alternative when its lifecycle fits, but it does not return the
  request ID needed by `cancelDataRequest`. Do not pretend Task cancellation alone
  stops PhotoKit disk writes. Fence outstanding callbacks before closing/deleting.
- Initial thumbnail cache target: 16 MiB, at most 100 entries, visible-row requests
  only at display-appropriate resolution. Clear on memory pressure; cancel vanished
  row requests. No original-sized images or cloud preview fetches for this UI.
- Release request objects, hash buffers, task registries and temporary response data
  on all terminal paths. Keep only small durable receipts. Use scoped autorelease
  pools in measured Objective-C-heavy loops; do not promise immediate RSS reduction
  merely because Swift references were released.
- Remove closures/subscriptions/timers from completed jobs. Keep a single TDLib
  receive loop and reuse provider sessions. Finish continuations once, close file
  handles in cleanup paths, finalize SQLite statements, and free TDLib C results
  according to the actual bridge's ownership rules.

## Disk staging and safe release

Stage original resources in app-owned protected, backup-excluded Application Support.
Use job/content-based internal filenames, not unsanitized original paths. Export
to `.partial`; after terminal success validate length/hash and atomically publish
the complete file. Uploads cannot acquire a partial export.

Each staged resource has durable consumer/transfer associations and runtime leases.
Google, Telegram, a splitter and a retry can need the same bytes at different times.
Acquire before exposing a path to a transport. Release only when that transport
has finished using it, not when progress reaches 100% or a cancel request is issued.
Store response receipts/checkpoints before deciding bytes are no longer necessary.

An original resource can be removed when no active reader/transfer owns it and
future needed content can be re-exported from Photos. This can occur before every
remote obligation is committed: finalization may need only a receipt. However,
do not remove the only copy needed for an ambiguous or non-recoverable transfer.
Background task lifecycle, not assumptions about copying, decides safe release.

If Google is blocked/disabled but Telegram finishes, keep Google's small obligation
and receipt data, not all of its staged media forever. Re-export unchanged bytes
when needed, verifying content identity again. If the source later disappears,
show Source unavailable for the missing obligation. Never delete Apple originals.

Startup reclaims only app-owned orphaned partial files after reconciling PhotoKit
work, URLSession's live tasks and TDLib pending sends. A persisted reference count
alone is insufficient after a crash. Mark eligible files for deletion, unlink them,
and finalize that cleanup record; interruption of cleanup must be safe to repeat.
Unknown/unmatched active tasks protect associated paths until resolved.

## Storage admission and large videos

Initial soft staging target: 1 GiB plus a single explicitly admitted oversized
resource. Never interpret the soft target as permission to fill all free storage.
Maintain a safety reserve (initial proposal 512 MiB) and measured transport overhead.
Use available-capacity APIs and real bytes written, not private PhotoKit `fileSize`
KVC. Unknown resource sizes require progressive checks and cancellable export.
Use conservative ordinary available capacity for this reserve; an important-usage
estimate containing reclaimable space does not prove physical bytes are available.

2026-10-08 clarification: one bounded <=1,900,000,000-byte derived part of a verified
leased original can coexist with the oversized master. Ordinary staging still has
its own 1 GiB soft allowance; this avoids blocking Telegram slicing while Google
owns the master, or starving small work because one large original is active.
At most one part is reserved/staged globally. All allocations still pass actual
capacity/reserve/copy-overhead admission; device peaks remain unmeasured.

[Apple's upload-task documentation](https://developer.apple.com/documentation/foundation/urlsessionuploadtask?changes=_8&language=objc)
says background file uploads copy the source to temporary storage. Budget for
that extra allocation as well as app staging, Telegram's possible cache copies,
and current split parts; shared staging does not mean only one disk copy exists.
Measure these costs on the device and keep concurrent large resources bounded.

Generate at most one or a small bounded number of Telegram parts ahead, delete
unneeded part copies after safe confirmation, and never materialize all parts
beside a huge video at once. Google still requires a full staged file for its
existing background upload path. If disk is insufficient, mark Waiting for space
for that asset and continue other admissible assets; do not compress it to fit.

Device-original size does not imply enough additional staging space. Large-file
support must state and test this constraint, not claim arbitrary videos fit.
Incremental scans/retry records stay small even when media cannot currently stage.

## Telegram cache ownership

Keep TDLib database and media-cache directories separate from our original staging.
Do not enable download-all/history-media behavior for reconciliation; captions and
manifests are enough except explicitly needed small manifests. Bound manifest size
and download concurrency, then release them after validated indexing.

[deleteFile](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1delete_file.html)
clears a TDLib cached file. Test its behavior for locally supplied upload paths;
never invoke it while any consumer still owns the same staged original.
[optimizeStorage](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1optimize_storage.html)
can prune cached media; use controlled cleanup only when relevant transfers are
terminal. Do not prune the authentication database or delete remote messages.
Reconcile actual cached/upload-source paths before assuming they are independent.

## Network policy and resource lifetime

One NWPathMonitor informs policy and shows Waiting for Wi-Fi/connection. A path
being available is not proof of internet reachability or valid credentials. Do
not run a polling ping loop or use repeated failing sends as a network detector.

Configure Google's media transport as file-based background URLSession. Use stable
session identifiers and job IDs mapped to original account identities. Reattach
to existing tasks on relaunch; never create replacement sends until reconciled.
Keep authenticated small RPC requests and their response data bounded/redacted.

Set allowed-cellular and constrained/expensive-network policies on relevant
URLSession requests/configurations, and enforce the same Wi-Fi decision in TDLib.
Network transitions, settings switches and account changes need coordinated
cancellation/checkpoints, including any ambiguous outcome after bytes were sent.
Do not reset attempt budgets on a network change.

[waitsForConnectivity](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/waitsforconnectivity?language=objc)
applies to ordinary sessions; background sessions always wait and ignore that
switch. Therefore display waiting separately from failed requests. Choose explicit
request/resource deadlines rather than assuming their defaults enforce our retry
budget. Active I/O stalls and OS suspension/offline waiting have different meanings.

Use exponential backoff with jitter for retryable failures; initial configurable
retry delays of about 5 and 20 seconds, superseded by server retry instructions.
Account-wide rate delays affect that provider's lane. Delayed retries do not block
other ready assets unless the restriction actually applies to the whole provider.
Pause/stall recovery never blindly resends uncertain remote content.

No busy waiting, sleep loops, forced keep-alive audio/location, or concurrent login
refresh storms. Coordinate one credential refresh per provider. Stop auth failure
cascades as a provider-level Needs attention state. A failed endpoint cannot consume
unbounded response memory or logging volume.

## Battery, temperature and lifecycle

For user-started finite batches, use iOS 26 continued processing with honest progress
and expiration/cancellation handling. Scheduled work, if authorized later, has its
own background scheduling. Force-quit and system suspension are test cases, not
conditions that the app promises to bypass.

Reduce preparation/prefetch under Low Power Mode and serious thermal pressure;
defer new CPU-intensive work at critical thermal state. Persist and present the
waiting reason. Respect completion of system-managed transfers rather than creating
duplicate tasks. Keep hashing off MainActor and avoid rendering original media.

On memory warning/backgrounding, discard thumbnails, nonessential previews,
finished job objects and transient pages. Preserve active transport ownership and
critical receipt state. Do not shut down TDLib each time a file completes, which
would waste reconnection work and risk pending receipt delivery.

On batch completion, end/report the system task, release batch observers/timers,
close unused handles, sweep eligible staging, flush bounded durable logs and leave
idle services event-driven. On unlink/app shutdown, close TDLib safely after
checkpointing and invalidate session resources when no pending work needs them.

## Error and log display without overhead

Use stable error categories: source unavailable/access denied, disk full, unsupported
original, connectivity, timeout, rate limit, authentication, quota, transfer,
finalization, reconciliation and internal invariant failure. Store known causes;
generic server errors must say Cause unknown rather than invent a diagnosis.

Failure rows show provider, Photos/Videos type, small local thumbnail, filename,
stage, attempt count, known reason, confirmed/missing parts and remedy. No popup
for every retry. Transient waiting is different from terminal Not uploaded.

Initial logs budget: 10 MiB or seven days, whichever is reached first. These are
diagnostic logs only: actionable failures and confirmation receipts are retained
separately in SQLite. Redact tokens, cookies, phone numbers, raw secret-bearing
responses and GPS. Show account identity deliberately in Settings, not debug dumps.
Export redacted logs on request; never upload logs automatically.

Emit start/wait/retry/failure/confirmed lifecycle events, not one log per byte/chunk.
Refresh visible byte progress at most about twice per second. Durable transitions
are immediate; coalescing byte progress cannot delay receipt persistence. Query
indexed aggregate counts, paginate lists, and keep view models small.

## Measurements during the first complete app test/debugging

Physical-device evidence must include:

1. Repeated mixed-photo/video batches: live object counts/RSS do not grow with
   completed asset count after warm-up. ARC release does not require RSS to return
   immediately to launch level; retained allocations and growth are what matter.
2. A large original video: memory bounded independently of video size; disk peaks
   include system/cache/part copies; after all consumers finish, eligible staging
   and TDLib media cache are reclaimed while receipts still recover correctly.
3. Google confirmed while Telegram sends, and the reverse: no premature deletion.
4. Error, cancellation, low space and memory-warning paths release handles/chunks
   and do not race late callbacks or delete a transport-owned file.
5. Crash/relaunch during export, transfer, finalization and cleanup: no corrupted
   published file, orphan accumulation, lost receipt or duplicate resend.
6. Wi-Fi to cellular, airplane mode, rate limits and account errors: correct waiting
   reasons, independent providers, three-attempt budget and no busy-spin retries.
7. Large failure/history/log lists: paginated memory usage, accurate counters,
   bounded thumbnails and timely main-screen interaction.
8. Log/thumbnail/cache pruning cannot remove durable receipts or unresolved failures.
9. Low Power Mode/thermal tests and measured network throughput/battery use guide
   concurrency changes; do not raise parallelism from guesses.

Use Instruments when local Xcode becomes available, plus safe device diagnostics
and repeatable measurements meanwhile. Hosted simulator checks cannot establish
real iPhone memory/background/storage characteristics.
