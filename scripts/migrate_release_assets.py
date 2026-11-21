"""Move existing website binaries to local release storage without rebuilding them."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

from release_assets import SITE, ROOT, sha256, stage_asset, render_routes
from stage_windows_release import verify_release

SUFFIXES = (".dmg", ".exe", ".msi", ".msix", ".pkg", ".nupkg", ".snupkg",
            ".appimage", ".deb", ".rpm", ".zip", ".tar", ".tar.gz", ".tgz", ".7z")


def main():
    config = json.loads((ROOT / "release.json").read_text())
    version = config["version"]
    public = SITE / "public"
    binaries = [p for p in public.rglob("*") if p.is_file() and p.name.lower().endswith(SUFFIXES)]
    if not binaries:
        print("No release binaries remain in landing/public.")
        return
    # Verify all current packages before moving any existing downloads.
    windows = ROOT / "dist/updates/windows/win-x64"
    verify_release(windows, "win-x64", version)
    linux = public / "assets/SmartNotch-Linux.tar.gz"
    if linux.exists():
        expected = linux.with_name(linux.name + ".sha256").read_text().split()[0]
        if sha256(linux) != expected:
            raise ValueError("Linux archive checksum failed")
    for file in binaries:
        relative = file.relative_to(public)
        counterpart = None
        if relative.parts[:2] == ("updates", "mac"):
            counterpart = ROOT / "dist" / relative
        elif relative.parts[:2] == ("updates", "windows"):
            counterpart = ROOT / "dist" / relative
        elif file.name == "SmartNotch.dmg":
            counterpart = ROOT / f"dist/updates/mac/SmartNotch-{version}.dmg"
        elif file.name == "SmartNotch-Windows-x64-Setup.exe":
            counterpart = windows / "SmartNotch-win-Setup.exe"
        if counterpart and sha256(file) != sha256(counterpart):
            raise ValueError(f"Website bytes differ from the verified package: {relative}")
        destination = ROOT / "dist/website-downloads" / relative
        if destination.exists() and sha256(file) != sha256(destination):
            raise ValueError(f"An existing local backup differs: {destination}")
    # Verifies the actual Sparkle Ed25519 signature without signing or changing the DMG.
    subprocess.run([sys.executable, str(ROOT / "scripts/sync_site_downloads.py")], check=True)
    subprocess.run([sys.executable, str(ROOT / "scripts/stage_windows_release.py"), "win-x64"], check=True)
    for file in binaries:
        relative = file.relative_to(public)
        name = "SmartNotch-Windows-x64-Setup.exe" if file.name == "SmartNotch-win-Setup.exe" else file.name
        stage_asset(file, "/" + relative.as_posix(), version, name)
    render_routes()
    for file in binaries:
        relative = file.relative_to(public)
        destination = ROOT / "dist/website-downloads" / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists():
            # The matching-byte check above already verified this backup.
            file.unlink()
        else:
            shutil.move(file, destination)
    print(f"Preserved {len(binaries)} binaries in dist/website-downloads.")
    print(f"Upload the files in dist/github-release/{version}/ to the manually created GitHub Release.")


if __name__ == "__main__":
    main()
