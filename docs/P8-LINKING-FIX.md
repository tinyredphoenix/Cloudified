# P8 linking correction — pending version 1.1

2026-10-09 IST. User reports Google device-addition wording and Telegram linking
failure `sourceUnavailable/fileSystem/unknown` on published 1.0 build 8. Architect
claims this document, docs/03-BUILD-LOG.md, docs/04-DECISIONS.md,
App/Adapters/Telegram/TDLibClient.swift, App/Adapters/System/FailureExplanation.swift,
Packages/CloudifiedCore/Sources/Diagnostics/DiagnosticEvent.swift,
App/Presentation/Settings/GoogleAuthSheet.swift, App/Resources/Info.plist,
scripts/generate_xcode_project.py and Cloudified.xcodeproj/project.pbxproj.
Ownership extends to distribution/stage_build.py: its hard-coded 1.0 gate must
validate the version from the exact built commit before a 1.1 IPA can publish.
No active Builder writer. No account access, credential commits, cloud dispatch or
upload-protocol changes in this batch. User-supplied Telegram credentials remain
outside source/logs. Untracked scratch/ remains untouched.

## Diagnosis and scope

Telegram startup prepares Application Support/Cloudified, already created by the
app's storage layout, using createDirectory(withIntermediateDirectories: false).
That operation rejects an existing directory. Its generic error mapper drops the
numeric code, hiding useful evidence. Prepare existing real directories idempotently,
retain canonical/no-symlink checks and protection/backup exclusion, and fail closed
on a file or redirected path. Preserve safe numeric error codes and readable local
storage explanations. Do not remove/reset the native database or input files.

Google uses the selected upstream EmbeddedSetup browser and Android master-token
route with add_account=1 and an app-generated Android ID. A separate Google-side
session/device is expected with this route; private browser storage does not prevent
it. No verified compatible device-less route is established. Do not remove wire
fields speculatively or promise suppression of Google security challenges. Explain
this before sign-in; app does not implement a Google prompt receiver. Keep protocol
and isolation machinery unchanged in this correction.

Update the pending release short version to 1.1 for these bug fixes, per D41.
Validation and exact evidence follow below.

## Implemented correction and evidence

- TDLib directory setup accepts only Cocoa 516/POSIX EEXIST from creation, then
  verifies a real canonical non-symlink directory. Existing directories still get
  the required protection and backup exclusion. Other failures remain errors.
  No files/database are removed, no profile scope is changed, and no receipt/retry
  or transfer logic is changed.
- Safe storage failures retain the numeric OS code. Closed diagnostic causes
  storageUnavailable/storagePathConflict give readable local-storage explanations;
  filesystem permission errors no longer incorrectly send users to Photos settings.
  Raw NSError prose, private paths and credentials remain excluded.
- Google setup explains the possible separate session/device and that Cloudified
  cannot receive Google verification prompts. Browser/cookie/token/HTTP/device
  identity machinery is unchanged. This does not claim device-less authentication
  or control over Google's challenge/recovery selection.
- Info.plist, both generated project configurations and generator now use 1.1.
  Staging validates IPA version against Info.plist fetched at the completed run's
  exact source SHA, replacing its obsolete hard-coded 1.0 gate. Existing checksum,
  bundle, revision and build-number checks stay enforced. A later main commit
  cannot substitute its release version for the built revision.

The original Foundation operation was reproduced in a disposable temporary
directory: the second create with intermediate directories disabled returned
NSCocoaErrorDomain 516. Temporary data was removed; no app/native/account execution.
This confirms the code defect, not an on-device diagnosis from exported logs.

`python3 scripts/check_swift_source.py --sdk
/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk --cache-dir
/private/tmp/cloudified-catalyst-cache --emit-ir` passed parsing, real Core/Diagnostics
module compilation, typechecking all 64 app sources and optimized whole-module IR.
Python AST syntax, plist/project lint, version agreement, documentation targets and
diff whitespace checks passed. The final source publisher was read-only inspected;
its version validation uses the incoming manifest rather than hard-coded 1.0.

At source handoff, pending release 1.1 had no cloud build or published IPA; SideStore
still offered 1.0 build 8. The subsequent authorized publication is recorded below.
The next integrated device session must verify
first/repeated Telegram setup reaches its real auth step, preserves its database,
and shows a usable error if local storage genuinely fails. Then verify normal
phone/code/2FA and owned-private-channel mapping with the user's credentials entered
only in the app. Google device/session and actual recovery behavior remain service
observations. Do not assume API credential validity from this local-storage failure.

## Research sources

- [Pinned upstream auth decision](https://github.com/g8row/PhotosBackup/blob/3c88269e18b9d4515e97d846c5816bd836285c3e/docs/ADR-001-auth-route.md):
  EmbeddedSetup/Android master-token flow; ordinary Photos API scopes are not equivalent.
- [Google account sessions](https://support.google.com/accounts/answer/3067630?hl=en):
  apps and private sign-ins can create sessions, including multiple on one device.
- [Google prompts](https://support.google.com/accounts/answer/7026266?hl=en):
  prompt eligibility and alternate verification methods are controlled by Google;
  keep functioning backup verification methods to avoid dependence on one session.
- [Apple directory creation](https://developer.apple.com/documentation/foundation/filemanager/createdirectory(at:withintermediatedirectories:attributes:)):
  read official DocC content and observed the numeric existing-directory error locally.

Firecrawl CLI unavailable; official web documentation and the pinned upstream raw
document were retrieved instead. No new dependency/revision. Claimed paths release
after commit/push; Builder holds. Untracked scratch/ remains untouched.

## Authorized build and publication — 2026-10-09 IST

User explicitly requested build and publish. Manual build
[37832459359](https://github.com/tinyredphoenix/Cloudified/actions/runs/37832459359)
passed from `e20c25c741d4bb98b982942b9cb388e1baded938`, preflight 6s and macOS
build job 2m22s. Exact native cache hit/verification passed. Compiler cache missed
after the project/version contract changed, then saved successfully. Final cache
usage was 211,468,946 bytes across five caches, within the configured 10 GB limit.
Public standard runners and existing manual workflow were used.

App publisher 37832804683 and source publisher 37832844600 published version 1.1
build 9. The public raw source entry matches the run manifest: 17,414,506-byte IPA,
SHA-256 `eb9e98ff6dc3bdb9f8482f85c89fab514da8a15eec84e7a8c0a42d6f183e4861`.
Exact release URLs and install guidance are in [distribution](DISTRIBUTION.md).
No device/account/service execution occurred; the acceptance checks above remain.
