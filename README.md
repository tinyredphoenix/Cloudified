# Cloudified

Personal, sideloadable iOS 26 uploader for Google Photos and Telegram.
Original photos and videos, independent destinations, durable progress and
reinstall recovery. No gallery, editing or playback.

## Project status

Architecture and build infrastructure only. No application target or working IPA
exists yet. PhotosBackup supplies the chosen Google implementation reference;
TDLib supplies Telegram's native transport. Reference projects inform implementation
only; the interface is designed independently for this app's upload/status tasks.
Local history and the planning tag are synced to the private
[GitHub repository](https://github.com/tinyredphoenix/Cloudified).
See [actual setup status](docs/SETUP-STATUS.md).

## Stack and build location

Swift 6 language mode, SwiftUI, PhotoKit, SQLite, Keychain, background URLSession
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

Builder may start P1 app shell. Architect directly implements P2 critical core.
Application phases are assigned in batches; the handbook is not authorization to
implement every phase at once. Both Google and Telegram execute concurrently once
the real engine/adapters are connected.

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

Private GitHub Actions builds use the account's included allowance and may incur
charges after that allowance. Workflows are manual, bounded and use short artifact
retention. Verify available allowance/budget before starting a cloud build.

Git milestone `v0.0.1-plan` denotes architecture/infrastructure, not an app release.
