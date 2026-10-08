# Public hosted builds and reusable caches

Updated 2026-10-08. Cloudified is public by explicit user instruction. The manual
workflow uses standard ubuntu-24.04 and macos-26 runners. GitHub currently makes
standard runner use free for public repositories; these runs do not consume the
private-repository included minutes. Larger runners remain paid. Cache storage has
a separate 10 GB repository allowance; do not raise its storage limit or enable a
paid runner. Artifact storage has separate rules; retain build evidence for 3 days.
Sources: [billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions),
[caching](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching).
The [official macOS 26 runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)
currently lists Xcode 26.6, CMake and Ninja. The workflow still verifies the selected
Xcode path at dispatch; image documentation is not a successful build result.

No build was dispatched while adding this infrastructure. Manual P7 remains the
first complete app build/test. Public visibility is not authorization to schedule
builds or start development app-test cycles. Before a future dispatch, confirm the
repository is still public, runner labels are standard, and storage/budget settings
have not enabled paid usage. A workflow preflight stops private-repository builds.

## What is cached

- Native TDLib assembly output only in build/tdlib. Exact fingerprint, no broad
  fallback. Fingerprint includes pinned source/dependency metadata, assembly recipe,
  C/package inputs, TDLib vendor closure metadata/licenses, cache validator,
  Xcode/SDK/compiler/CMake/Ninja versions, target
  platform/architecture/deployment and runner image metadata.
- Compiler intermediates, module/SDK caches and Swift package checkouts under
  build/DerivedData. Key includes the native fingerprint, project/package/build
  contracts and source commit; fallback stays within the same toolchain/contracts.
  Xcode must still decide which changed source files to rebuild.
- IPA, final app products, xcresult, signing credentials, Keychain, provider tokens,
  account data and private media are excluded from these caches.

The official actions/cache v4 source was resolved once via git ls-remote to
`0057852bfaa89a56745cba8c7296529d2fc39830`; workflow restore/save/action references
use that exact commit. Native output is saved immediately after verification, so
a later app compiler failure does not require another native assembly. Compiler
caches are saved after successful jobs. Eviction/misses are normal; correctness
must never depend on a cache being available.

## Native artifact handoff contract

scripts/build_cache.py prepare writes ignored build/cache-inputs.json and outputs
native/compile fingerprints. The assembly script must produce a complete, truly
linked iPhone arm64 artifact and required headers/dependencies under build/tdlib,
then call seal-tdlib. This records every output file's SHA-256 and native fingerprint
in build/tdlib/provenance.json. verify-tdlib checks that complete inventory and
fingerprint, rejects symbolic links and checks arm64 archives before reuse. Assembly
must first force-link all members into an arm64 iOS 26 executable with fatal linker
warnings, inspect its platform/deployment with vtool and record link-validation.json
with archive/member hashes. This executable is never run or kept as a cached binary.
Cache validation requires matching link metadata, exact closure members and dependency
licenses; it hashes large archives incrementally. These gates have not run yet.
A future recorded device link establishes that closure/platform check, not provider
behavior or a working iOS app; P7 supplies actual build/runtime evidence.

Missing/stale/corrupt output is removed only from the owned build/tdlib directory
and rebuilt. Failure stops the build; no weak stub/library-free IPA fallback.
Existing invalid caches cannot be overwritten under an immutable exact key; if
one persists, delete that specific repository cache or bump the cache schema after
investigation. Never restore native output from a different dependency/toolchain key.
Assembly must honor CLOUDIFIED_BUILD_ROOT, pin every non-SDK dependency, and extend
the fingerprint's file inventory when adding another native recipe/config input.

Neither cache hit rate nor speedup has been measured; first real evidence follows
the authorized P7 build. No large local SDK/native build or USB operation occurred.
