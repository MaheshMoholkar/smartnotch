"""Verify a Velopack Windows release before changing the website download."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import zipfile

from release_config import ROOT, validate
from release_assets import stage_asset, render_routes


def sha256(file):
    digest = hashlib.sha256()
    with file.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def pe_machine(data):
    if len(data) < 64 or data[:2] != b"MZ":
        raise ValueError("Expected a Windows PE executable")
    offset = struct.unpack_from("<I", data, 60)[0]
    if offset + 6 > len(data) or data[offset:offset + 4] != b"PE\0\0":
        raise ValueError("Invalid Windows PE header")
    return struct.unpack_from("<H", data, offset + 4)[0]


def verify_release(source, runtime, version):
    feed_file = source / "releases.win.json"
    feed = json.loads(feed_file.read_text(encoding="utf-8-sig"))
    assets = feed.get("Assets", [])
    if not assets:
        raise ValueError("The Windows update feed contains no packages")
    current = None
    for asset in assets:
        name = asset.get("FileName", "")
        if not name or Path(name).name != name or "/" in name or "\\" in name or not name.endswith(".nupkg"):
            raise ValueError("Invalid update-package filename in the feed")
        package = source / name
        if not package.is_file() or package.stat().st_size != asset.get("Size"):
            raise ValueError(f"Missing or truncated update package: {name}")
        digest = asset.get("SHA256", "")
        if len(digest) != 64 or sha256(package).lower() != digest.lower():
            raise ValueError(f"Update-package checksum failed: {name}")
        if asset.get("Version") == version and name.lower().endswith("-full.nupkg"):
            if asset.get("PackageId") != "SmartNotch":
                raise ValueError("The update package belongs to another application")
            current = package
    if current is None:
        raise ValueError(f"No full update package for SmartNotch {version}")
    with zipfile.ZipFile(current) as archive:
        main = [name for name in archive.namelist() if Path(name).name == "SmartNotch.exe"]
        if len(main) != 1:
            raise ValueError("The update package must contain one SmartNotch.exe")
        expected_machine = {"win-x64": 0x8664, "win-arm64": 0xAA64}[runtime]
        if pe_machine(archive.read(main[0])) != expected_machine:
            raise ValueError("The update package targets the wrong processor")
    installers = [file for file in source.iterdir() if file.is_file() and file.name.lower().endswith("setup.exe")]
    if len(installers) != 1:
        raise ValueError("Expected one generated Setup.exe")
    pe_machine(installers[0].read_bytes())
    return installers[0], feed_file


def stage(source, runtime, version, public, manifest, output=None):
    # Validate the complete feed and current package before changing download links.
    installer, feed = verify_release(source, runtime, version)
    target = public / "updates/windows" / runtime
    target.mkdir(parents=True, exist_ok=True)
    site = public.parent
    output = output or ROOT / "dist/github-release"
    versions = {asset["FileName"]: asset["Version"]
                for asset in json.loads(feed.read_text(encoding="utf-8-sig"))["Assets"]}
    for file in sorted(source.iterdir()):
        if not file.is_file() or file.name == feed.name:
            continue
        if file.suffix.lower() in {".exe", ".nupkg"}:
            # GitHub assets share a flat namespace: separate ARM64 from x64 names.
            name = ("SmartNotch-Windows-x64-Setup.exe" if file == installer else file.name) if runtime == "win-x64" else "win-arm64-" + file.name
            asset_version = versions[file.name] if file.suffix.lower() == ".nupkg" else version
            stage_asset(file, f"/updates/windows/{runtime}/{file.name}", asset_version, name, site, output)
        elif file.name in {"RELEASES", "assets.win.json"} or file.suffix == ".sha256":
            shutil.copy2(file, target / file.name)
    shutil.copy2(feed, target / feed.name)
    if runtime == "win-x64":
        assets = public / "assets"
        assets.mkdir(parents=True, exist_ok=True)
        download = assets / "SmartNotch-Windows-x64-Setup.exe"
        stage_asset(installer, "/assets/" + download.name, version, download.name, site, output)
        checksum = sha256(installer)
        download.with_suffix(".exe.sha256").write_text(f"{checksum}  {download.name}\n")
        downloads = json.loads(manifest.read_text(encoding="utf-8-sig"))
        downloads["windows"].update(format="EXE", file="/assets/SmartNotch-Windows-x64-Setup.exe",
                                     version=version, inAppUpdates=True)
        manifest.write_text(json.dumps(downloads, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runtime", choices=["win-x64", "win-arm64"])
    args = parser.parse_args()
    config = validate(json.loads((ROOT / "release.json").read_text()), require_updates=True, platform="windows")
    source = ROOT / "dist/updates/windows" / args.runtime
    for file in source.iterdir():
        if file.is_file() and file.suffix != ".sha256":
            file.with_name(file.name + ".sha256").write_text(f"{sha256(file)}  {file.name}\n")
    stage(source, args.runtime, config["version"], ROOT / "landing/public", ROOT / "landing/app/downloads.json")
    render_routes()
    print(f"Verified {args.runtime}: binaries in dist/github-release; small feeds in landing/public.")


if __name__ == "__main__":
    main()
