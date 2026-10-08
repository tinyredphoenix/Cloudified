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

The first build after this distribution change must complete before the new
icon appears inside an IPA and the source has an installable version. Check
the source URL, release asset URL, SHA-256 and IPA Info.plist after publishing.
Only then use SideStore to install and start P7 device verification. The
source icon alone does not prove the installed icon is updated.
