# Cloudified — private test results template

This is a blank form, not test evidence. Copy outside the public repository before
filling it in. Follow [the ordered guide](P7-DEVICE-TEST-GUIDE.md). Keep original
media, identifiers, screenshots, exported logs and crash reports private; share a
sanitized summary. Do not commit a completed private report.

## Session

- Date/time/time zone:
- App version (build), from Settings > About:
- IPA source/release and source revision, if known:
- iPhone model / exact iOS version:
- Photos permission scope / accessible photos / accessible standalone videos:
- Google account alias / Telegram account and channel aliases:
- Live Photo policy:
- Google enabled / Telegram enabled / Wi-Fi Only:
- Network / Low Data Mode / VPN if used:
- Low Power Mode / battery / charging:
- Free device storage / Cloudified app size / Documents & Data:
- Google storage usage and observation time before run:
- Other automatic uploaders paused / settings to restore afterward:

## Results

Use PASS, FAIL, BLOCKED or NOT RUN. Enter evidence and limitations for each
scenario actually attempted; never infer a PASS from an unexercised condition.

| Test ID | Result | Time / run ID | Actual outcome / evidence file | Limitation or bug ID |
| --- | --- | --- | --- | --- |
| | | | | |

## Dashboard snapshot — repeat before/during/after each relevant run

- Test ID / time / run ID / overall activity:
- Accessible total / scan scope/time:
- Google total / confirmed / remaining / failed / waiting / activity:
- Telegram total / confirmed / remaining / failed / waiting / activity:
- Saved to both:
- Photos breakdown for Google and Telegram:
- Videos breakdown for Google and Telegram:
- Current provider/file alias / bytes sent / total bytes / component or part:
- Session Saved / speed / ETA (including unknown):
- Remote confirmation evidence / screenshot file:

## Original-file verification — one row per resource

Use asset aliases; a Live Photo needs separate still and motion rows. For a
multipart video compare the reconstructed original, and retain the part manifest.
Document any mismatch without replacing the original reference or re-encoding it.

| Asset alias / type / component | Reference acquisition method | Source bytes / SHA-256 | Google bytes / SHA-256 | Telegram bytes / SHA-256 | Result |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

- Dimensions / duration / codec / HDR / orientation comparison:
- Embedded capture-time comparison / time-zone interpretation:
- Other embedded metadata compared (private location checks stay private):
- Library-only metadata or cloud display differences:
- Google storage usage after run / observation time / confounding activity:
- Google quality/quota label if exposed (label is not byte verification):
- Formats/components not checked and why:

## Resource observations — repeat for each comparable batch

| Time / stage | Completed assets / work remaining | App Documents & Data / free device space | Battery / charging / heat | Responsiveness / termination |
| --- | --- | --- | --- | --- |
| | | | | |

- Small/large video sizes / duration / run elapsed time:
- Idle measurement time / whether readers or unknown sends remained:
- Repeated-batch trend / limitations of iOS storage estimates:
- RAM/peak allocations/handles measured with which tool, or UNMEASURED:
- Background intervals actually reached with work remaining:
- Continuation granted/declined/expired evidence, if available:

## Bug report — copy this block for each issue

- Bug ID / title / related test ID:
- Impact: critical integrity/destination/duplicate; upload/setup blocker; status or
  recovery defect; usability/cosmetic:
- Version/build / device/iOS / timestamp/time zone:
- Provider or shared source/system / account-channel aliases:
- Preconditions: selection, Live Photo policy, enabled providers, network, power,
  foreground/background and existing remote content:
- Exact numbered reproduction steps:
- Expected result:
- Actual result:
- Reproduction frequency / last known working version, if any:
- Error reason / category / technical code / stage:
- Asset alias/type / component or part / confirmed and missing obligations:
- Logical attempt numbers / cycle ID / next retry / terminal or unknown outcome:
- Other provider's state and later successes:
- Dashboard totals/confirmed/remaining before and after:
- Run/job IDs if exposed / relevant event times:
- Private screenshot/log-export/crash-report filenames:
- Memory-only persistence-failure screenshot, or not observed:
- Actions already taken after failure (Retry/Recover/relaunch/remap/etc.):
- Workaround / affected or blocked later tests:
- Architect diagnosis / assigned owner / fix commit and build:
- Recheck steps / observed result / remaining gaps:

## Session handoff

- Passed test IDs with evidence:
- Failed IDs / bug IDs:
- Blocked or not-run IDs and reasons:
- Setup prerequisites missing:
- Unverified format/resource/retry/background/reinstall claims:
- Logs exported and readable / saved outside app:
- Sensitive evidence reviewed before sharing:
- Changed external backup/network settings restored:
- Next focused action / owner:
- Overall assessment: first-run observation / blocked / needs P8 fixes / acceptance
  review requested (do not call an untested claim accepted):
