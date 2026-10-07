# Build location and repository setup

Decision recorded 2026-10-07: keep the small main checkout on the Mac and build
with GitHub-hosted Xcode. User explicitly permits GitHub Actions as an alternative
to installing Xcode on the connected pendrive.

## Inspected environment

- Local checkout: `/Users/naman/Documents/App Projects/Cloudified`.
- Mac free storage: approximately 41 GiB at inspection.
- Full Xcode application absent; active developer directory is CommandLineTools.
- USB volume: `/Volumes/God Drive`, 250.3 GB total, approximately 205.1 GB free,
  ExFAT, writable. The drive contains existing user data.
- GitHub CLI authentication works with approved network access for tinyredphoenix.
- No existing `tinyredphoenix/Cloudified` repository found before creation.

No disk files, partitions or formatting are changed by the chosen setup. ExFAT
is not the preferred filesystem for a full Apple development bundle, symlinks and
heavy dependency builds. Cloud builds avoid resolving that issue and avoid large
simulator/SDK/cache allocations on the Mac. This decision does not prevent a future
local Xcode installation on a separately provisioned APFS volume or disk image if
interactive Instruments/simulator work becomes necessary; that is a separate task.

## Hosted build contract

Use the standard `macos-26` arm64 runner, with Xcode 26.6 explicitly selected via
DEVELOPER_DIR. The inspected [official runner manifest](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)
lists that version. The workflow must fail clearly if the pinned toolchain disappears,
not silently select a different release. Record image/toolchain versions in logs.

The checked-in manual workflow:

1. Validates documentation and presence of the real Xcode project on a Linux runner.
2. Builds the shared Cloudified scheme for generic iOS without certificate secrets.
3. Packages the resulting app as an unsigned IPA for local SideStore signing.
4. Retains build evidence/artifacts for three days. Timeout limits runaway jobs.

It is infrastructure for the builder, not proof that the app can currently compile:
no Xcode project is present at the architecture milestone. Future batches must add
meaningful unit/state-machine tests and simulator checks to CI. Cloud compile/tests
cannot replace physical iPhone authentication, background, quota and preservation tests.

SideStore re-signing and supported entitlements must be verified on the actual
device. Do not publish an unsigned IPA as already installable. Keep certificates,
profiles and passwords out of GitHub by default.

## Cost controls

[GitHub's billing documentation](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
states that standard public-repository builds are free; private repositories use
the owner's included allowance, with excess usage/storage billed. Keep this personal
repository private by default. This is not an unlimited-free-build claim.

No automatic macOS build on every commit, no larger runner, no long-lived cache or
automatic release. Check current allowance/budget before manually dispatching.
Artifact cleanup is separate from preserving source history. The workflow cannot
itself enforce the account's billing budget; configure a budget through GitHub if
necessary. No cloud workflow was dispatched at initial setup.

## History and tags

Main is the source history. Annotated `v0.0.1-plan` is architecture and CI scaffold.
Tag later integration/application milestones only after their checks pass. Record
dependency source SHAs and artifact checksums in version control once selected.
The GitHub remote is the durable source backup; the USB drive is not required.
