# Cloudified

Personal, sideloadable iOS 26 uploader for Google Photos and Telegram.
Original photos and videos, independent destinations, durable progress and
reinstall recovery. No gallery, editing or playback.

## Project status

P1–P6 source integration and the P7 unsigned iOS build have compiler/package
evidence. The [first successful cloud build](https://github.com/tinyredphoenix/Cloudified/actions/runs/37778211603)
does not establish provider service or device behavior.
PhotosBackup supplies the chosen Google implementation reference;
TDLib supplies Telegram's native transport. Reference projects inform implementation
only; the interface is designed independently for this app's upload/status tasks.
Local history and milestone tags are synced to the public
[GitHub repository](https://github.com/tinyredphoenix/Cloudified).
See [actual setup status](docs/SETUP-STATUS.md) and
[SideStore distribution](docs/DISTRIBUTION.md).
For the first actual iPhone session, follow the [ordered device-test guide](docs/P7-DEVICE-TEST-GUIDE.md)
and copy the [results and bug-report template](docs/P7-TEST-RESULTS-TEMPLATE.md)
to a private folder before filling it in. The first device attempt found Photos
permission/setup and presentation blockers before either account was linked;
see [P8 first-run corrections and linking plan](docs/P8-FIRST-RUN.md).
The [improvement research and proposed batches](docs/P8-IMPROVEMENT-RESEARCH.md)
cover Google isolation limits, background/Live Activity choices, efficiency and
recovery; proposals are separate from implemented or device-verified behavior.

## Stack and build location

Swift 6 language mode, SwiftUI, PhotoKit, SQLite, Keychain, file-backed URLSession
and iOS 26 continued processing. C/C++ is limited to the TDLib dependency/bridge.
Keep source in this small local checkout; use manual GitHub Actions macOS builds
to avoid installing the full Xcode suite on this Mac.

The connected ExFAT drive is left unchanged. No formatting, partition changes or
existing-file cleanup is part of this setup. See [build setup](docs/BUILD-SETUP.md).

## Start here — shared four-file handbook

1. [Structure, purpose, files and dashboard](docs/01-ARCHITECTURE.md)
2. [Build phases, ownership and Builder's first batch](docs/02-BUILD-PHASES.md)
3. [Build log, evidence and current handoff](docs/03-BUILD-LOG.md)
4. [Decisions and their reasons](docs/04-DECISIONS.md)

Builder completed P1; Architect directly implemented P2 critical core.
Builder's P3-R2 implementation was reviewed; Architect completed critical source corrections.
Architect completed [P4-B provider integration](docs/P4-B-INTEGRATION.md) with
source/compiler evidence only. Builder submitted P5; [Architect review](docs/P5-REVIEW.md)
found recovery, command ownership and presentation gaps. Architect directly implemented
P5-R1 corrections and critical P6 under the user's subsequent authorization.
See [integration/evidence](docs/P5-P6-INTEGRATION.md). P7 packaging has succeeded;
SideStore installation and real dual-provider device verification are next.
Source/compiler evidence does not establish
service behavior, original quality, quota treatment, reinstall safety or an accepted IPA.
P3 has source/compiler evidence only; see [review history](docs/P3-REVIEW.md), handbook 2 and
the [core integration contract](docs/CORE-INTEGRATION.md).
Application phases are assigned in batches; the handbook is not authorization to
implement every phase at once. Both Google and Telegram execute concurrently once
the real engine/adapters are connected.
No demo data or simulated uploads. Unconnected screens show genuine unavailable/
empty states. The first app test follows complete integration of all features;
development phases use static review and coordinated handoffs rather than repeated
app-test/build cycles. Persistent diagnostics are part of the production engine.

## Detailed contracts — read only for the assigned batch

- [Architecture and integration plan](docs/PLAN-DRAFT.md)
- [Original quality, accounts, retry and recovery](docs/RELIABILITY-SPEC.md)
- [Counters, photos/videos sections and errors](docs/STATUS-SPEC.md)
- [Memory, storage, networking and lifecycle](docs/RUNTIME-SPEC.md)
- [Research and verification evidence](docs/RESEARCH.md)
- [Builder workflow](CONTRIBUTING.md)

## Checks

Run `python3 scripts/check_docs.py` for local documentation checks.
The manual iOS build workflow first requires a real `Cloudified.xcodeproj` with a
shared `Cloudified` scheme. It then uses hosted Xcode to build a device app and
package an unsigned IPA for local SideStore signing. It does not upload signing
credentials or contact Google/Telegram accounts. Device/account tests remain separate.

Standard GitHub-hosted runner use is free for this public repository and does not
consume private-repository minutes. Larger runners remain paid; cache storage has
its own allowance. Manual builds reuse verified native artifacts and compiler/package
caches; see [cache contracts](docs/BUILD-CACHE.md). Keep the free cache limit, short
artifact retention and P7 build schedule; verify visibility/storage before dispatch.

Git milestone `v0.0.1-plan` denotes architecture/infrastructure, not an app release.

The [Cloudified SideStore source](https://raw.githubusercontent.com/tinyredphoenix/Cloudified-Source/main/source.json)
lists permanent unsigned IPA releases after successful manual builds. SideStore
signs the selected IPA with your certificate. Build failures appear in the
[source build history](https://github.com/tinyredphoenix/Cloudified-Source/blob/main/builds.json).
