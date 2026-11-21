"""Build and stage the Linux source installer without pretending to cross-compile Qt."""
import hashlib
import json
import shutil
import tarfile
from pathlib import Path
from release_assets import stage_asset, render_routes

ROOT = Path(__file__).resolve().parent.parent


def main():
    version = json.loads((ROOT / "release.json").read_text())["version"]
    source = ROOT / "linux"
    output = ROOT / "dist/linux"
    output.mkdir(parents=True, exist_ok=True)
    archive = output / "SmartNotch-Linux.tar.gz"
    with tarfile.open(archive, "w:gz") as bundle:
        for path in sorted(source.rglob("*")):
            relative = path.relative_to(source)
            if any(part.startswith(".") or part == "__pycache__" for part in relative.parts):
                continue
            if path.is_file():
                bundle.add(path, arcname=str(Path("SmartNotch-Linux") / relative), recursive=False)
        notes = ROOT / "RELEASE_NOTES.md"
        bundle.add(notes, arcname="SmartNotch-Linux/RELEASE_NOTES.md")
        bundle.add(ROOT / "release.json", arcname="SmartNotch-Linux/release.json")
    # Verify the deliverable before exposing a download link.
    with tarfile.open(archive, "r:gz") as bundle:
        names = set(bundle.getnames())
        for required in ("install.sh", "run.sh", "requirements.txt", "icon.png", "README.md",
                         "smartnotch/app.py", "smartnotch/model.py", "smartnotch/__main__.py"):
            if f"SmartNotch-Linux/{required}" not in names:
                raise ValueError(f"Missing installer file: {required}")
        if json.load(bundle.extractfile("SmartNotch-Linux/release.json"))["version"] != version:
            raise ValueError("Archive version does not match release.json")
    checksum = archive.with_suffix(archive.suffix + ".sha256")
    checksum.write_text(f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n")
    stage_asset(archive, "/assets/SmartNotch-Linux.tar.gz", version)
    assets = ROOT / "landing/public/assets"
    assets.mkdir(parents=True, exist_ok=True)
    shutil.copy2(checksum, assets / checksum.name)
    manifest = ROOT / "landing/app/downloads.json"
    downloads = json.loads(manifest.read_text())
    downloads["linux"] = dict(label="Linux", system="Linux preview · X11 recommended", architecture="x64 / ARM64 · Python 3.10–3.14",
                             format="TAR.GZ installer", file="/assets/SmartNotch-Linux.tar.gz",
                             version=version, inAppUpdates=False)
    manifest.write_text(json.dumps(downloads, indent=2, ensure_ascii=False) + "\n")
    render_routes()
    print(f"Staged Linux preview {version}: {archive}")
    print("Source installer: requires Python, venv, and an internet connection during setup.")


if __name__ == "__main__":
    main()
