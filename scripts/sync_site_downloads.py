"""Stage signed Mac assets for GitHub; copy only the small feed to the website."""
import json
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

from release_config import ROOT, validate
from make_appcast import SPARKLE
from release_assets import stage_asset, render_routes


def main():
    config = validate(json.loads((ROOT / "release.json").read_text()), require_updates=True)
    source = ROOT / "dist/updates/mac"
    archive = source / f'SmartNotch-{config["version"]}.dmg'
    feed = source / "appcast.xml"
    item = ET.fromstring(feed.read_bytes()).find("./channel/item")
    enclosure = item.find("enclosure")
    expected_url = config["updateBaseURL"].rstrip("/") + "/mac/" + archive.name
    if (item.findtext(f"{{{SPARKLE}}}version") != str(config["build"])
            or item.findtext(f"{{{SPARKLE}}}shortVersionString") != config["version"]
            or enclosure.get("url") != expected_url
            or int(enclosure.get("length", "0")) != archive.stat().st_size):
        raise ValueError("Release files differ from release.json; package the release again")
    subprocess.run(["swift", str(ROOT / "scripts/verify-update.swift"), str(archive),
                    config["sparklePublicKey"], enclosure.get(f"{{{SPARKLE}}}edSignature", "")], check=True)
    public = ROOT / "landing/public"
    target = public / "updates/mac"
    target.mkdir(parents=True, exist_ok=True)
    # Retain existing feed URLs; redirects pin each archive to its original release.
    stage_asset(archive, "/updates/mac/" + archive.name, config["version"])
    stage_asset(archive, "/assets/SmartNotch.dmg", config["version"], "SmartNotch.dmg")
    shutil.copy2(feed, target / "appcast.xml")
    manifest = ROOT / "landing/app/downloads.json"
    downloads = json.loads(manifest.read_text())
    downloads["mac"].update(version=config["version"], inAppUpdates=True)
    manifest.write_text(json.dumps(downloads, indent=2) + "\n")
    render_routes()
    print("Staged verified Mac binaries in dist/github-release and the feed in landing/public.")


if __name__ == "__main__":
    main()
