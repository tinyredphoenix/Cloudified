# Cloudified shared handbook 4 — decisions and reasons

Updated 2026-10-07. This is the decision index; deeper evidence is in RESEARCH.md.
Change decisions deliberately and record the impact in handbook 3. Existing
reference implementations are accepted foundations; verify our integration rather
than repeatedly reconsider the user's chosen storage services.

| ID | Decision | Why / consequence |
| --- | --- | --- |
| D01 | Native Swift 6/SwiftUI, iOS 26 | Direct PhotoKit/background APIs and reuse of existing Swift Google integration; narrow TDLib C/C++ bridge |
| D02 | Google through pinned PhotosBackup; Telegram through TDLib/private channel | Standalone on-device architecture with no paid server/gateway |
| D03 | Original quality mandatory | No silent conversion, recompression or Storage Saver downgrade; unsupported originals stay visible |
| D04 | Independent concurrent provider lanes | Both begin in the same backup batch; Google completion/failure never gates Telegram's whole batch |
| D05 | SQLite receipts/jobs, immutable account/channel identities | Accurate restart-safe state; late callbacks cannot credit a different account |
| D06 | Three total automatic parent-asset attempts per provider | Quiet bounded recovery, persistent budget; failed asset cannot monopolize the queue |
| D07 | Remote reconciliation after unknown outcomes/reinstall | Local DB or PhotoKit ID loss cannot justify blind duplicate uploads |
| D08 | Overall Dashboard plus Not uploaded, Logs, Settings | Every key status has a home without becoming a media browser |
| D09 | Confirmed asset progress and current-attempt byte progress are separate | 100% transfer bytes is not proof of remote save; UI remains honest through retries |
| D10 | Separate Photos and Videos in the dashboard | Videos are equally supported and visibly queued/uploaded; Live Photo components do not inflate totals |
| D11 | Bounded streaming, shared staging with leases | Predictable memory/disk use and safe release while another provider still reads |
| D12 | Original Live Photo pair archived to Telegram; verified Google pairing/fallback | Preserve available originals; clearly distinguish native pairing from separate components/omissions |
| D13 | Source on Mac; manual standard hosted-Xcode builds | Conserve local disk; do not format or change the data-bearing ExFAT USB drive |
| D14 | Architect directly implements critical P2 core and critical protocol fixes | Retry, account isolation, receipt correctness and cleanup need direct careful implementation |
| D15 | Builder starts with P1 shell, then assigned integration/UI batches | Reviewable progress and clear shared-directory ownership; no competing core implementations |
| D16 | Reference projects inform implementation only | UI is native and purpose-built for Cloudified; no reference-screen inspiration required |
| D17 | No demo/mock/seeded app data | User explicitly requires genuine state; unknown/unconnected UI stays honest |
| D18 | First app test after complete P1–P6 integration | User wants the first test to contain every feature; intermediate test gates are superseded |
| D19 | Persistent production diagnostics implemented with P2 | First complete test can be debugged by provider/job/attempt/stage, without retrofitting logs |
| D20 | Versioned canonical content identities; current asset-to-plan bindings | Reinstall IDs cannot change resource tags; duplicate aliases share work; policy changes retain history without inflating current totals |
| D21 | Durable transport holds plus runtime cleanup fences | Protect file ownership across crash and actor reentrancy; one provider's unresolved transfers cannot gate the other's recovery |
| D22 | Ready drains and explicit producer wakeups | Both workers start before either is awaited; one timer handles future deadlines; diagnostic invalidations cannot trigger empty-run loops |
| D23 | Rotating diagnostics separate from durable evidence | Ten MiB is diagnostic payload budget; critical transitions/receipts/attempts/failures and first-test summaries remain reviewable |
| D24 | One bounded derived part alongside the oversized original, ordinary staging accounted separately | Telegram can slice while Google owns the master; small work can proceed; actual disk/copy reserve and one-part cap still apply |
| D25 | Pre-hash source failures are durable scoped obligations without fake jobs | Export failures before identity exists remain visible and counted; provider plan failures stay isolated |

## Version 1 defaults

Manual Back Up for all accessible original photos/videos, Wi-Fi only, both connected
providers enabled. Explicitly started work may continue under iOS 26's system
controls. No promise of indefinite/continuous background execution. Automatic
scheduled backups remain a later decision. A disabled provider retains its backlog
and separate literal saved-to-both status.

For unavailable Google Live Photo pairing, offer key image, motion video, or both
original components separately; recommend both for preservation. Display selected
coverage clearly. Repackaged Motion Photo compatibility remains an isolated
experiment; it cannot be called an unchanged original file.

## Scheduling and efficiency decisions still to measure

Initial limits: one original preparation worker and one transfer per provider.
Use fair deterministic ready-work order, delayed retries and no video starvation.
Priority ordering by size/date can be added only after measured benefit; it must
not change which assets get backed up or promise both lanes send the same file
at the same instant. Real disk overhead includes system/cache copies.

Cache/log budgets in RUNTIME-SPEC.md are starting budgets, not performance claims.
Increase concurrency only after device throughput, memory, battery and thermal
evidence. An available network path is not proof of internet/service access.

## Acceptance distinctions

- Original-byte export test, remotely downloaded-original test and Google's storage
  accounting check establish different facts; none substitutes for the others.
- Real provider events must establish concurrent activity in the first full test;
  direct code review alone is not proof of runtime behavior.
- Local restart persistence and full reinstall remote recovery need separate tests.
- Keychain persistence is not the duplicate-prevention guarantee after reinstall.
- Hosted compile/simulator evidence does not prove iPhone background/cleanup behavior.
- No provider's permanent free service is guaranteed by these implementation choices.

P1–P6 record implementation and static review only, without app-test sessions or
demo data. All functional/quality/resource/recovery scenarios belong to P7 and
subsequent debugging iterations. Necessary compiler checks are distinct from
functional app testing; no repeated cloud build cycles during implementation.

## Revision rule

User instructions override these defaults. Record changed behavior, why, affected
interfaces/tests and acceptance criteria before assigning implementation. State
unknown facts openly; do not turn a proposal or label into a tested capability.

## D26 — publication ownership survives later failures

2026-10-08. Diagnostic/lease/split failures after publication cannot authorize raw
unlinking of a registered original. Rollback checks registration under the export
pin; source releases returned leases and only the fenced store removes registered
bytes. Failed cleanup keeps ownership for explicit recovery. Manifest documents use
fresh physical UUIDs while stable remote association remains recipe-derived.

## D27 — unknown resource bounds follow capacity

2026-10-08. A fixed 2 GB measurement cap incorrectly rejects larger originals and
occupies the oversized slot for tiny photos. Architect provides reserveSourceStorage
for a conservative real-capacity bound and ordinary-room allocation alongside an
oversized root. Builder P3-R2 must consume it, check capacity during writes and
budget known originals/parts and transport copies. This is unmeasured admission
policy, not evidence that all videos fit or that provider limits have been verified.
