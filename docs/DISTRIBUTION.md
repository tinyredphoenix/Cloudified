# Cloudified 1.0 SideStore distribution

The app's short version is **1.0**. Each manual GitHub Actions build supplies its
run number as `CFBundleVersion` so SideStore can distinguish successive
1.0 builds. This is version identity, not an assertion of device or service
acceptance. The first native/Xcode IPA build succeeded in run 37778211603;
real iPhone, Google, Telegram, quality and reinstall checks remain P7 work.

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

## Latest published build — P8 corrections

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
