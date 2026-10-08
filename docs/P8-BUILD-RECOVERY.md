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
