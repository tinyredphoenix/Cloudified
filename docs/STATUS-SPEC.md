# Cloudified status and completion contract

Discussion specification, 2026-10-07. Numbers below are illustrative, not actual uploads.

## Screen example

Accessible library: 3,000 assets · 2,600 photos (including Live Photos) · 400 videos.
Scope: All accessible photos. Permission: Full access. Last scan: timestamp.

| Status | Google Photos | Telegram |
| --- | ---: | ---: |
| Saved | 2,300 / 3,000 | 2,700 / 3,000 |
| Remaining | 700 | 300 |
| Photos remaining | 600 | 260 |
| Videos remaining | 100 | 40 |
| Blocked, included in remaining | 15 | 2 |
| Current operation | Finalizing IMG_0123.HEIC | Sending IMG_0124.MOV |
| Current file | Bytes sent; awaiting confirmation | 38 MB / 60 MB |

Separate detail: Live Photo coverage, already-present assets, bytes transferred,
waiting for Wi-Fi/iCloud, retry time, and last confirmed upload. Main controls:
Back Up, Pause, Retry failed. Provider-specific reconnect/retry in its details.

The combined saved-to-both count is a database intersection. It cannot be
calculated from these two totals alone. A provider can be paused or disconnected
while the other continues. Small local identification thumbnails are allowed in
Not uploaded rows. No gallery, full-screen media, editing, or playback UI.

## Photos and Videos sections

Dashboard has separate Photos and Videos sections. Each shows Google and Telegram
saved/remaining/not-uploaded counters, active operation and byte progress. Both
media types are included by default. Live Photos belong to Photos; their paired
motion component must not inflate the standalone Videos count.

Top-level navigation: Backup, Not uploaded, Logs, Settings. Keep the interface
small and native. Do not add a browsing grid or media-detail viewer.

## Not uploaded and errors

- Separate Google and Telegram outcomes, with Photos/Videos filters. Include
  Failed, Waiting and Pending statuses; failed assets are the default emphasis.
- Row: small thumbnail when permitted, filename/capture date, media type, provider,
  attempts (for example 3/3), plain-language reason and next available action.
  Videos show duration when available, not playback. Missing local source/access
  shows a placeholder rather than fetching a cloud preview.
- Detail: stage, stable error category, technical code, last occurrence, confirmed
  components/parts, missing obligations, and suggested remedy when known.
  Do not invent a root cause from a generic server/network error.
- Retries happen silently; update the screen/log without modal alerts. Exhausted
  failures remain visible and do not prevent processing later assets.
- After account-wide restrictions, display one provider banner and waiting reasons,
  not a misleading pile of individual exhausted failures.
- Log screen filters All/Google/Telegram and severity. Record timestamps, stage,
  attempt number and safe error details; redact credentials, raw responses with
  secrets, and private location data. Log pruning cannot erase failure records.

## Counting units

1. Count distinct selected PHAsset identities, deduplicating album overlaps.
   A Live Photo is one photo asset; its still/video are resources, not two photos.
   A multipart video is one video asset, regardless of part count.
2. Each destination has its own required-resource set and frozen policy version.
   An asset is saved only when all required resources and necessary archive
   metadata have durable confirmation. A half-uploaded pair remains one pending
   asset. Show component detail such as "image saved; motion waiting".
3. Saved includes uploaded and verified already-present content. Keep those
   subtotals separate in details. Identical payloads may satisfy multiple local
   assets after hash verification; upload once but preserve metadata associations.
4. For each provider and stable scan snapshot:
   `selected = saved + remaining + explicitlyExcluded`.
   `remaining = pending + preparing + sending + finalizing + retryWaiting + blocked + unknown`.
   States are disjoint. Blocked/unknown never count as saved. Default exclusions
   are zero; unsupported format or oversized media is blocked, not excluded.
   Not uploaded is an explicit terminal failure state included in blocked.
5. `photosRemaining + videosRemaining = remaining` for the supported image/video
   scope. Separate a Live Photos subset without adding it to the total again.
6. Local asset removed before export: retain a visible source-missing outcome.
   A newly changed scope or asset generation creates a new scan snapshot; do not
   rewrite history or delete remote uploads.
7. Disabling a provider does not erase saved/remaining counts or exclude its
   backlog. Label it Disabled and stop new attempts. "Enabled destinations complete"
   and "Saved to both" have different meanings; keep both-complete literal.
8. An account/channel remap switches to that destination's own counts. Existing
   receipts from a different destination cannot be credited to the new mapping.

## Honest progress

- During scanning: "Discovering assets…" and discovered count. After enumeration,
  the snapshot total is exact for the accessible scope. Limited Photos permission
  must say "Selected/access granted photos", never "Entire library".
- Before content checks: "Checking 120 / 900 candidates". The exact number of
  new payloads is not yet known. A date or local identifier is insufficient to
  call an item new to Google.
- Show stages: Scanning, Downloading original from iCloud, Preparing/hashing,
  Checking destination, Sending, Finalizing, Saved, Waiting, Blocked, Reconciling.
- File percentage measures bytes for that attempt. At 100% show "Finalizing",
  not Saved. Retries can resend bytes; transferred bytes are not backup completeness.
- Total byte size/ETA stays unknown until sufficiently measured. Never invent an
  ETA for iCloud fetches or unknown sizes. Use confirmed assets for overall progress.
- Persist receipts before emitting Saved UI events. On restart recompute counts
  from SQLite. Throttle byte/UI updates while persisting important transitions.
- System continued-processing progress uses the same snapshot and confirmed
  destination obligations. Additions discovered later go into the next batch.

## Live Photo coverage

Google settings: prefer native pairing if verified; fallback choice is key image
only, motion video only, or both originals separately. Telegram archives both
original resources. Explain the Google alternatives in plain language before use.
No silent default that drops motion. The preservation-oriented fallback is both.

Show "Saved using key-image fallback; motion omitted" or "Components saved
separately; native pairing unavailable" as applicable. Saved-under-policy is not
the same as full native Live Photo support. The app never displays "All originals
preserved at both" for a lossy coverage policy or a remuxed derivative.

Changing policy creates only missing obligations; do not re-upload confirmed
unchanged bytes or erase existing remote items. Never apply a new policy halfway
through a committed job.

## Acceptance examples

- Ten assets, one Live Photo: UI total ten. Still confirmed and motion failed:
  Telegram saved nine, remaining one, blocked one; retry only missing component.
- Telegram saved ten, Google saved eight with two failures: Google remaining two,
  Telegram remaining zero. Combined complete eight only if those eight match.
- PUT completes but Google commit fails: remaining unchanged, stage Finalizing
  or Reconciling. Temporary Telegram message is likewise not Saved.
- Two local assets contain identical bytes: saved asset count can increase by two
  after one content transfer; transfers counter records one. Preserve aliases.
- A format rejected by Google remains Google-blocked while Telegram completes.
- Same account/channel after restart retains counts. A different account/channel
  requires a new destination ledger. Reinstall reconciles remote evidence first.
- Three failed attempts at one Google asset: mark it Not uploaded, process the next
  Google asset, and leave Telegram untouched. Relaunch does not reset attempts.
- Google disabled mid-backup: show Disabled, retain receipts, run Telegram normally.
- Lost local database after reinstall: verify remote-managed receipts and hashes;
  send no already-confirmed resource and show Recovering until evidence is complete.
