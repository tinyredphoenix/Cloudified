#!/usr/bin/env python3
"""Stage one manual iOS build for the SideStore source repository.

The release is a CI prerelease, never device or service acceptance.  Only the
small manifest is pushed across repositories; the source repo fetches public
release assets and checks their bytes before publishing them again.
"""

import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import zipfile


APP_REPO = "tinyredphoenix/Cloudified"
BUNDLE_ID = "com.tinyredphoenix.Cloudified"
IPA_NAME = "Cloudified-unsigned.ipa"


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=True, text=True, capture_output=True)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def app_info(ipa: Path) -> dict:
    with zipfile.ZipFile(ipa) as archive:
        data = archive.read("Payload/Cloudified.app/Info.plist")
        if "Payload/Cloudified.app/Assets.car" not in archive.namelist():
            raise ValueError("Compiled app asset catalog is missing")
    return plistlib.loads(data)


def stage_success(args: argparse.Namespace, manifest: dict) -> None:
    ipa = args.artifact_dir / IPA_NAME
    checksum_file = args.artifact_dir / (IPA_NAME + ".sha256")
    if not ipa.is_file() or not checksum_file.is_file():
        raise ValueError("Successful build has no IPA or checksum")
    checksum = sha256(ipa)
    declared = checksum_file.read_text().split()[0]
    if checksum != declared:
        raise ValueError("IPA checksum does not match the build artifact")
    info = app_info(ipa)
    version = str(info.get("CFBundleShortVersionString", ""))
    build = str(info.get("CFBundleVersion", ""))
    if (info.get("CFBundleIdentifier") != BUNDLE_ID or version != "1.0"
            or build != str(args.run_number)
            or info.get("CloudifiedRevision") != args.head_sha):
        raise ValueError("IPA identity, version, build number, or source revision differs from the completed run")

    tag = f"ci-run-{args.run_id}-untested"
    stage_url = f"https://github.com/{APP_REPO}/releases/download/{tag}/{IPA_NAME}"
    existing = subprocess.run(
        ["gh", "api", f"repos/{APP_REPO}/releases/tags/{tag}"],
        capture_output=True, text=True, check=False,
    )
    if existing.returncode == 0:
        assets = {asset["name"]: asset for asset in json.loads(existing.stdout)["assets"]}
        asset = assets.get(IPA_NAME)
        if not asset or asset.get("digest") != "sha256:" + checksum:
            raise ValueError("Existing staged release does not match this IPA")
    else:
        attachments = [str(ipa), str(checksum_file)]
        log = args.artifact_dir / "xcodebuild.log"
        if log.is_file():
            attachments.append(str(log))
        run(
            "gh", "release", "create", tag, *attachments,
            "--repo", APP_REPO, "--target", args.head_sha,
            "--title", f"Cloudified {version} ({build}) — CI build, untested",
            "--notes", f"Unsigned IPA from successful manual build {args.run_id}. Compiled and packaged; device, Google and Telegram behavior remain unverified.\n\n{manifest['runURL']}",
            "--prerelease",
        )
    manifest.update({
        "version": version,
        "buildVersion": build,
        "bundleIdentifier": BUNDLE_ID,
        "sha256": checksum,
        "size": ipa.stat().st_size,
        "stageURL": stage_url,
        "stageTag": tag,
    })


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id", required=True, type=int)
    parser.add_argument("--run-number", required=True, type=int)
    parser.add_argument("--head-sha", required=True)
    parser.add_argument("--conclusion", choices=("success", "failure", "cancelled", "timed_out"), required=True)
    parser.add_argument("--artifact-dir", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()
    if len(args.head_sha) != 40 or any(c not in "0123456789abcdef" for c in args.head_sha):
        raise ValueError("Invalid source commit SHA")
    manifest = {
        "schema": 1,
        "runId": args.run_id,
        "runNumber": args.run_number,
        "headSha": args.head_sha,
        "runURL": f"https://github.com/{APP_REPO}/actions/runs/{args.run_id}",
        "status": args.conclusion,
    }
    if args.conclusion == "success":
        stage_success(args, manifest)
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n")


if __name__ == "__main__":
    main()
