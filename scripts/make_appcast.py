"""Create a Sparkle feed after sign_update has signed the exact uploaded archive."""
import base64
from datetime import datetime, timezone
from email.utils import format_datetime
import json
from pathlib import Path
import plistlib
import sys
import subprocess
import xml.etree.ElementTree as ET

from release_config import ROOT, validate

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE)


def make_feed(config, archive, signature_output, notes, now=None):
    validate(config, require_updates=True)
    signature = ET.fromstring(f'<enclosure xmlns:sparkle="{SPARKLE}" {signature_output.strip()} />')
    encoded = signature.get(f"{{{SPARKLE}}}edSignature", "")
    if len(base64.b64decode(encoded, validate=True)) != 64:
        raise ValueError("sign_update did not return a valid Ed25519 signature")
    if int(signature.get("length", "0")) != archive.stat().st_size:
        raise ValueError("The signed length does not match the archive")
    root = ET.Element("rss", version="2.0")
    channel = ET.SubElement(root, "channel")
    ET.SubElement(channel, "title").text = "SmartNotch Updates"
    item = ET.SubElement(channel, "item")
    ET.SubElement(item, "title").text = f'SmartNotch {config["version"]}'
    ET.SubElement(item, "pubDate").text = format_datetime(now or datetime.now(timezone.utc))
    for name, value in [("version", str(config["build"])), ("shortVersionString", config["version"]),
                        ("minimumSystemVersion", "14.0.0"), ("hardwareRequirements", "arm64")]:
        ET.SubElement(item, f"{{{SPARKLE}}}{name}").text = value
    ET.SubElement(item, "description", {f"{{{SPARKLE}}}format": "markdown"}).text = notes
    signature.set("url", config["updateBaseURL"].rstrip("/") + "/mac/" + archive.name)
    signature.set("type", "application/octet-stream")
    item.append(signature)
    ET.indent(root)
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)


def main():
    archive, signature_path, output = map(Path, sys.argv[1:])
    config = validate(json.loads((ROOT / "release.json").read_text()), require_updates=True)
    info = plistlib.loads((ROOT / "dist/SmartNotch.app/Contents/Info.plist").read_bytes())
    expected = {
        "CFBundleShortVersionString": config["version"], "CFBundleVersion": str(config["build"]),
        "SUFeedURL": config["updateBaseURL"].rstrip("/") + "/mac/appcast.xml",
        "SUPublicEDKey": config["sparklePublicKey"],
    }
    if any(info.get(key) != value for key, value in expected.items()):
        raise ValueError("Rebuild SmartNotch: the bundle differs from release.json")
    notes = (ROOT / "RELEASE_NOTES.md").read_text()
    feed = make_feed(config, archive, signature_path.read_text(), notes)
    enclosure = ET.fromstring(feed).find("./channel/item/enclosure")
    subprocess.run(["swift", str(ROOT / "scripts/verify-update.swift"), str(archive),
                    config["sparklePublicKey"], enclosure.get(f"{{{SPARKLE}}}edSignature")], check=True)
    if output.exists():
        old = ET.fromstring(output.read_bytes())
        builds = [int(item.text) for item in old.findall(f"./channel/item/{{{SPARKLE}}}version")]
        if builds and max(builds) >= config["build"]:
            raise ValueError("Increase build in release.json before publishing a new update")
    temporary = output.with_suffix(".xml.tmp")
    temporary.write_bytes(feed)
    temporary.replace(output)


if __name__ == "__main__":
    main()
