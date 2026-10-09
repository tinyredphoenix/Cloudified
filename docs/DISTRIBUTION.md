# Cloudified SideStore distribution

The currently published app's short version is **2.1**. Each manual GitHub Actions
build supplies its run number as `CFBundleVersion` to distinguish build attempts.
This is version identity, not an assertion of device or service
acceptance. The first native/Xcode IPA build succeeded in run 37778211603;
real iPhone, Google, Telegram, quality and reinstall checks remain P7 work.

## Version policy — user instruction

Bug-fix releases increment the minor version: **1.0 → 1.1 → 1.2**. Feature releases
increment the major version and reset the minor: **1.x → 2.0**, then **3.0** for
the next feature release. A release containing both uses the feature bump. This
deliberately follows the user's convention rather than semantic versioning.

Before the next release build, update `CFBundleShortVersionString` and the project
generator's version consistently. The actual packaged IPA, Settings and SideStore
metadata must show the same visible version; CI build number remains separate.
Retries of a failed build retain the pending release version. Never change source
metadata to relabel an already published IPA. Version 1.0 build 8 stays as published.
Current version is 2.1 build 11; the next bug-fix release is 2.2, or 3.0 if it
introduces features.

## Source and publication

Add this URL in SideStore > Sources:

https://raw.githubusercontent.com/tinyredphoenix/Cloudified-Source/main/source.json

SideStore supports AltStore sources. The source repository contains the public
icon, source JSON, run history and permanent successful-build IPA prereleases.
Failed, cancelled or timed-out manual build runs enter `builds.json` without
an app version. IPA and checksum never enter Git history.

The existing `Manual iOS build` workflow remains manual. Its
`Publish SideStore builds` companion executes after completion and only
accepts runs from this repository's main branch and `workflow_dispatch`.
For success, it checks the artifact SHA-256 and the IPA's bundle identifier,
short version, build number, asset catalog and embedded source revision.
It then creates a clearly **untested** CI prerelease in this repository.
It writes a small run manifest into Cloudified-Source using a deploy key
restricted to that one repository. The source repository fetches the public
staged IPA, checks SHA-256 and Info.plist again, publishes its own permanent
prerelease, and updates the JSON with the exact `version`, `buildVersion`,
size, URL and SHA-256. Newest build goes first as required by SideStore.

The publisher has write access to only the source repository through its
deploy key. The private key lives in the Cloudified Actions secret named
`CLOUDIFIED_SOURCE_DEPLOY_KEY`, with no local copy retained. The publisher
workflow uses a write-scoped `GITHUB_TOKEN` only for its own staging release;
the separate source workflow uses its own token for its final release.
Neither workflow runs cloud-service uploads or signs the app.

## First published build

Manual build [37785528077](https://github.com/tinyredphoenix/Cloudified/actions/runs/37785528077)
passed preflight and iOS packaging from commit
`683668e4f381bb605da420c1315c3e6d8be65c20`. Its compiled Info.plist
was verified by both publication stages as bundle
`com.tinyredphoenix.Cloudified`, version `1.0`, build `6`, with that
source revision and a compiled asset catalog. The
[app publisher](https://github.com/tinyredphoenix/Cloudified/actions/runs/37785927107)
and [source publisher](https://github.com/tinyredphoenix/Cloudified-Source/actions/runs/37785965420)
both passed. The [source prerelease](https://github.com/tinyredphoenix/Cloudified-Source/releases/tag/ci-run-37785528077-untested)
contains a 17,265,113-byte unsigned IPA with SHA-256
`a87a9403fd4e9962c06c2046e1a247cb4cdf8d9a3ae5c0a09f56dfaaa0a616f8`.
The public raw source URL served one app and version `1.0` build `6`.

The installed icon and source behavior still need a SideStore/iPhone check.
Build compilation and release checksum do not establish account uploads,
original quality, background reliability or reinstall deduplication.

## Previous published build — P8 corrections

Version **1.0 build 8** is published after the P8 source review and compiler
recovery. Manual build [37828111234](https://github.com/tinyredphoenix/Cloudified/actions/runs/37828111234)
passed from exact source `0ebb2e3eb721dfb0e2e6294cc6b6d0633ec5e3f9`.
The [app publisher](https://github.com/tinyredphoenix/Cloudified/actions/runs/37828500291)
and [source publisher](https://github.com/tinyredphoenix/Cloudified-Source/actions/runs/37828535144)
both passed. The [permanent prerelease](https://github.com/tinyredphoenix/Cloudified-Source/releases/tag/ci-run-37828111234-untested)
contains the 17,412,620-byte unsigned IPA with SHA-256
`48b42a79b004c025b40ccd14de2460853807ac226d0a380f591a83c9db00c293`.
Refresh the existing SideStore source, then install/update Cloudified and confirm
Settings shows version 1.0 build 8. No manual IPA download is required.

Build 7 failed in compiler IR generation and added no installable version. Build 8
fixes that failure; [recovery evidence](P8-BUILD-RECOVERY.md) distinguishes local
compiler checks from the successful iPhone build. Real-device/service acceptance
remains pending; use P8-FIRST-RUN.md and the P7 device/result documents to record it.

## Previous published build — 1.1 linking corrections

Version **1.1 build 9** passed manual build
[37832459359](https://github.com/tinyredphoenix/Cloudified/actions/runs/37832459359)
from exact source `e20c25c741d4bb98b982942b9cb388e1baded938` (macOS job 2m22s).
The [app publisher](https://github.com/tinyredphoenix/Cloudified/actions/runs/37832804683)
and [source publisher](https://github.com/tinyredphoenix/Cloudified-Source/actions/runs/37832844600)
published the [permanent untested prerelease](https://github.com/tinyredphoenix/Cloudified-Source/releases/tag/ci-run-37832459359-untested).
The unsigned IPA is 17,414,506 bytes, SHA-256
`eb9e98ff6dc3bdb9f8482f85c89fab514da8a15eec84e7a8c0a42d6f183e4861`.
The unauthenticated public raw source serves 1.1 build 9 with matching size/checksum.
Version verification uses the actual built source SHA rather than a fixed 1.0 gate.

Refresh Cloudified's existing SideStore source and update. Confirm Settings shows
**1.1 (9)**, then retry Telegram linking. The existing-folder correction and clearer
errors are compiled; actual authentication/channel linking still need device evidence.
Google's current session/device behavior is explained before sign-in; its auth
protocol is unchanged. See [linking correction](P8-LINKING-FIX.md).


## Previous published build — 2.0 public diagnostics

User authorized build and publication for testing. Manual build
[37891550316](https://github.com/tinyredphoenix/Cloudified/actions/runs/37891550316)
passed from exact source `f080be2bd533f4d45401ff57a90988cb4e4be694`: preflight 3s,
macOS job 2m06s. Native dependency cache hit; compiler cache missed after project
changes and was saved. Final cache use 259,935,038 bytes / configured 10 GB.
The [app publisher](https://github.com/tinyredphoenix/Cloudified/actions/runs/37891757475)
and [source publisher](https://github.com/tinyredphoenix/Cloudified-Source/actions/runs/37891781253)
both passed. The [permanent untested prerelease](https://github.com/tinyredphoenix/Cloudified-Source/releases/tag/ci-run-37891550316-untested)
contains the 17,495,366-byte unsigned IPA with SHA-256
`4324dc5c788fe61a3c9dc910f80897467add589e3d8d71d127d820d15eab93a3`.
The unauthenticated public feed was verified as **2.0 (10)** with matching bundle,
size, checksum and exact run download URL. No signing credentials were used.

Refresh the existing SideStore source and update. Confirm Settings shows 2.0 (10),
launch twice, retry both account connections, then Logs → Upload public diagnostics.
Share the returned link in this chat. Real device/service behavior remains unverified;
see [P9 implementation and device checks](P9-DIAGNOSTICS.md).


## Latest published build — 2.1 Telegram startup and report delivery

User authorized publication. Build
[37897046071](https://github.com/tinyredphoenix/Cloudified/actions/runs/37897046071)
passed from `2dc17a0b95baf962685c7051b35793c3e95230cb` (preflight 4s, macOS 1m46s).
Native dependency cache hit; compiler cache missed after version/project changes
and saved successfully. Final cache use 308,428,160 bytes across seven caches / 10 GB.
Both [app publisher](https://github.com/tinyredphoenix/Cloudified/actions/runs/37897241252)
and [source publisher](https://github.com/tinyredphoenix/Cloudified-Source/actions/runs/37897264180)
passed. The [permanent untested prerelease](https://github.com/tinyredphoenix/Cloudified-Source/releases/tag/ci-run-37897046071-untested)
contains the 17,507,901-byte unsigned IPA, SHA-256
`64e741155880b7c93a5faabc8777b046ea29924359896e6b5867099c5a5acee6`.
Unauthenticated SideStore feed was verified as **2.1 (11)** with exact manifest
bundle, version, build, size, checksum and run download URL agreement.

Refresh the existing SideStore source and update. Confirm Settings shows 2.1 (11),
retry Telegram linking, then Logs → Upload public diagnostics and send its link here.
The approved dpaste route has non-private desktop service evidence; actual iPhone
report delivery and account linking remain device checks. See P9-R1.md.
