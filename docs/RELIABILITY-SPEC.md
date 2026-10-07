# Cloudified reliability, accounts and original quality

User requirements recorded 2026-10-07. This is a build contract, not a report that
these behaviors already exist. Companion documents: PLAN-DRAFT.md and STATUS-SPEC.md.

## Non-negotiable original quality

- Reuse the working PhotosBackup Google integration in original-quality/non-quota
  mode. gunshot is an accepted working reference for behavior, not a requirement
  to turn this standalone app into an injected tweak.
- Send underlying original PhotoKit resources. Never substitute a thumbnail,
  rendered preview, Storage Saver upload, automatic JPEG conversion or re-encoded
  video. A rejected original becomes an explicit provider error.
- Telegram uses file/document upload. Large files are split losslessly, with
  hashes/length/order sufficient to reconstruct the exact original bytes.
- Preserve embedded metadata; record accessible external Photos properties in
  archive manifests. Keep original capture timestamps distinct from upload time.
- Live Photo component fallback is a coverage choice, not permission to lower
  the quality of the chosen image/video. A remux experiment is labeled derivative
  and does not satisfy a claim that the whole original file is unchanged.
- Validate our integration with downloaded-original checksums and metadata fixtures.
  Compare original video bytes, including HEVC/HDR examples, not just a still image.

## Failure isolation and scheduling

Provider job identity includes account/channel, local asset generation, required
resources, and frozen policy. Each provider owns independent outcomes, attempts,
waiting state and receipts. A Google adapter error never writes a Telegram failure
and never cancels Telegram's successful or active job.

Shared source failures such as missing Photos permission, missing original or disk
exhaustion can prevent both destinations from obtaining the file. Report them as
source/preparation errors with the actual affected obligations, not as a Google
error copied into Telegram. Global user Pause is an intentional shared control.

Use a fair ready queue plus delayed retry queue per provider. An asset scheduled
for retry does not hold up other ready assets. Stream bounded progress updates;
serialize transactional state changes through the scheduler/ledger owner.

## Three-attempt contract

Three means **three total automatic logical attempts**, initial plus two retries,
for each asset/provider in a retry cycle. For Live Photos/multipart videos, the
budget belongs to the parent asset, not three attempts for every component.
An attempt executes/resumes only missing obligations and can involve multiple
protocol calls. Do not equate every chunk, progress update or RPC with an attempt.

Persist attemptStarted before starting attempt work; reconcile interrupted work
after relaunch rather than grant a fresh budget. Confirmed components/parts never
consume a new transfer merely because another component failed. Once the third
attempt fails, the asset enters Not uploaded for that provider and its lane
continues. Retain failure information until resolved or explicitly cleared.

Logical budget and protocol retries must be coordinated: an adapter must not hide
unbounded app-level resend cycles behind a single attempt. TDLib/OS transport can
have internal connection/chunk retries; enforce bounded execution/cancellation
and inspect their semantics before claiming three literal wire requests.

Error handling:

| Condition | Outcome |
| --- | --- |
| Retryable asset-specific failure | Delay retry with backoff; other ready assets proceed |
| Three attempts exhausted | Not uploaded, reason retained, next asset proceeds |
| Unsupported original/permanent rejection | Not uploaded immediately; no futile retries |
| Unknown remote acceptance | Reconcile first; do not assume failure/absence and resend |
| No allowed network before attempting | Waiting for connection/Wi-Fi; no attempt spent |
| Provider flood/rate restriction | Respect server delay in that lane; other provider runs |
| Invalid login/account-wide quota or access restriction | Provider Needs attention; pending assets wait, other provider runs |
| User Pause/disable/cancel before transfer | Preserve checkpoints; does not count as a failed upload |

Any automatic retries are silent: no modal errors, repeated alerts or notification
spam. Status and logs still show attempts and failures clearly. A user explicitly
tapping Retry/Reconnect can begin a new three-attempt cycle after reconciliation.
Record its cycle identifier; relaunch, another Back Up tap, or a routine rescan
must not silently reset exhausted jobs. A changed original creates a new content
generation, not a bypass for retrying an unchanged failing file forever.

## Account/settings contract

Google and Telegram each have an independent enable switch and Link, Reconnect,
Unlink actions. Show connected account identity and connection/backup state.
Telegram additionally shows private-channel name and durable channel ID, with
Change channel mapping. Do not identify a destination solely by display name.
Google account identity must be verified from its login/session information;
if it cannot be identified reliably, account isolation is an integration blocker.

- Disable: stop issuing new work and settle/cancel active work safely. Preserve
  auth, receipts, attempts and backlog. The other provider runs normally.
- Enable: reconcile unfinished outcomes and resume that destination only.
- Unlink: disable its work, settle/checkpoint ambiguous outcomes, remove local
  credentials/session as appropriate, and retain receipt history. Never delete
  cloud media, a private channel or an unrelated provider's credentials.
- Relink same verified account/channel: reuse/reconcile its own receipts.
- Link another account/channel: select a distinct ledger namespace and reconcile
  that remote destination. Do not move completion flags from the prior mapping.
- Map channel: validate access before activating it; display recovery/preflight
  state. Retain the old mapping history and never resend to it after switching.
- Preserve job destinations while settling active work; never finalize an old
  upload under a newly selected account. Retired callbacks update only their
  original mapping's history, not the current account's screen totals.

Keychain persistence is useful but is not the reinstall deduplication strategy.
After uninstall/reinstall, expect a new local database and possibly fresh login.

## Reinstall and durable duplicate prevention

Use remote content evidence so changing PhotoKit local identifiers or losing the
local database does not cause a blind re-upload. Do not use filename/date/album
as the sole identity. Scope every remote receipt to its account and channel.

Google: use the upstream content-hash lookup before uploading absent local records.
If lookup is unavailable/errors, hold the affected content in Reconciling rather
than consider it new. Existing receipts count only for the matching content/policy.

Telegram: every resource/part message carries a versioned deterministic content
identifier, independent of an installation's local asset identifier. Manifests
associate resource roles, Live Photo pairing, file parts, metadata and confirmed
message IDs. Record resource identities in their own captions so a lost final
manifest does not make already-sent files invisible during recovery.

On fresh installation, identify the target account/channel, rebuild a managed
content index through complete paginated remote history, then queue only missing
resources/manifests. Recover partial pairs/parts independently. Newer incremental
sync can use a durable cursor; an incomplete history scan must not prove absence.
Show Recovering Telegram history and checked-item progress. Other providers can
continue if their own reconciliation is sound.

Require re-upload avoidance for app-managed backups after reinstall as an acceptance
test. Arbitrary old Telegram uploads without our content tags are outside that
guarantee. Remote deletions and genuinely changed content need new uploads.
Ambiguous acceptance must stay Reconciling until evidence is available; avoid an
unconditional exactly-once guarantee that the private protocols cannot establish.

## Required focused tests and review

1. Google fails repeatedly for asset A while Telegram succeeds; Google processes
   asset B; A ends at three total attempts and Telegram success remains untouched.
2. Relaunch during attempt two, during commit, and after final remote acceptance:
   correct attempts/receipts survive; unknown outcomes reconcile without blind sends.
3. Live Photo/multipart partial success: only missing pieces retry, within the
   shared parent budget; component successes survive exhaustion and manual retry.
4. Reinstall with local DB deleted and original captions/manifests intact: same
   originals and videos cause zero duplicate content transfers on both providers.
5. Reinstall after resource confirmation but before manifest confirmation:
   recover existing resources, upload only missing archive metadata/components.
6. Disable/unlink one provider during active work: other provider progresses;
   stale callbacks cannot credit the new account/channel.
7. Remap channel or switch Google account: history is correctly isolated; returning
   to the prior mapping recovers its own confirmed work.
8. Credential/rate/quota restrictions: one actionable provider state; do not burn
   three attempts for every unrelated pending asset; other provider progresses.
9. Failed rows/logs show separate provider, stage, error, known reason, attempts and
   remedy. Generic errors honestly say the cause is unknown. No secrets are exported.
10. Photos/Videos counters and local thumbnail permissions remain correct across
    retries, limited access, missing source, disable and reinstall recovery.

Architect directly reviews the ledger uniqueness/transaction rules, account
mapping, remote lookup/history recovery, retry-budget transitions, original export
and Google profile/commit path. Builder supplies focused diffs and reproducible
test evidence; screen styling can be reviewed from summaries/screenshots.
