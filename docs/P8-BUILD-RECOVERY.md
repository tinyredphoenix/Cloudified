# P8 integrated build and recovery

2026-10-09 IST. User explicitly requested the manual iPhone build after direct P8
corrections. Architect claims this document, docs/03-BUILD-LOG.md,
docs/DISTRIBUTION.md, App/Presentation/Settings/SettingsView.swift and
scripts/check_swift_source.py for focused build recovery/evidence before editing.
No active Builder writer; untracked scratch/ remains untouched.

Build 7: [37827241924](https://github.com/tinyredphoenix/Cloudified/actions/runs/37827241924),
exact source `0c3524fbf03aec8fc444098d38824e31bd842ac1`. Public standard runners,
cache usage 115,001,922 bytes / configured 10 GB. Preflight passed; exact native
cache restored and verified. Compiler cache missed because the project/contracts
fingerprint changed since build 6; no native rebuild was needed.

The iPhone compiler failed during IR generation, not typechecking: Apple Swift
6.3.3 crashed in a generated LivePhotoFallbackOption closure thunk. Direct
MainActor-bound method references in SwiftUI Binding setters are the focused
suspect. Replace them with explicit closures, preserving operations/isolation/
optimization. Extend the real-source check to code generation rather than
claiming typecheck covers compiler emission. Logs stay in private temporary files.

Changed all four direct Settings Binding setters to explicit closures. Local
`python3 scripts/check_swift_source.py --sdk
/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk --cache-dir
/private/tmp/cloudified-catalyst-cache --emit-ir` passed: all 64 actual sources
parse/typecheck and optimized whole-module IR generation succeeds, using real
Core/Diagnostics modules. This is Catalyst compiler evidence, not an iPhone build
or runtime test. Python syntax and diff whitespace checks also pass.

Replacement iPhone run and publication evidence follow below. No dependency,
optimization, native cache recipe or actor-isolation change.

## Build 8 and SideStore publication

[37828111234](https://github.com/tinyredphoenix/Cloudified/actions/runs/37828111234)
passed from exact correction commit `0ebb2e3eb721dfb0e2e6294cc6b6d0633ec5e3f9`.
Preflight took 7 seconds; the macOS build job took 2m39s. iPhone Release compilation,
native link, unsigned IPA packaging and evidence upload passed. Thus the focused
closure correction resolves the observed device compiler crash at this revision.

The exact native cache hit and verification passed. The compiler cache missed,
then successfully saved under the current contract fingerprint for future
compatible restores. After publication, repository cache usage was 163,235,882
bytes across four caches, within its configured 10 GB allowance. No paid runner,
cache purge, dependency rebuild or local Xcode installation was needed.

[App publisher 37828500291](https://github.com/tinyredphoenix/Cloudified/actions/runs/37828500291)
and [source publisher 37828535144](https://github.com/tinyredphoenix/Cloudified-Source/actions/runs/37828535144)
both passed. The source's incoming manifest matches the exact build/source above.
Published source metadata identifies version `1.0`, build `8`, minimum iOS `26.0`,
and a 17,412,620-byte unsigned IPA. SHA-256:
`48b42a79b004c025b40ccd14de2460853807ac226d0a380f591a83c9db00c293`.

[Permanent untested prerelease](https://github.com/tinyredphoenix/Cloudified-Source/releases/tag/ci-run-37828111234-untested).
The unauthenticated public raw source URL also served version 1.0 build 8 with
the same checksum; the release asset size matches the manifest/source metadata.
Refresh the existing Cloudified SideStore source and install/update to build 8.
Physical-device UI, permissions, linking, original-byte uploads, background behavior
and reinstall reconciliation remain acceptance work, not compiler evidence.

No app/account tests or private data were introduced. Logs remain outside Git;
untracked scratch/ remains untouched. Architect releases the claimed paths after
the evidence commit/push; Builder holds pending a new explicit assignment.
