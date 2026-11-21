"""Shared release metadata. No private keys or credentials belong in release.json."""
import argparse
import base64
import json
import plistlib
import re
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent.parent


def validate(config, require_updates=False, platform="mac"):
    if not re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", config.get("version", "")):
        raise ValueError("version must be a three-part release number, e.g. 0.2.0")
    if type(config.get("build")) is not int or config["build"] < 1:
        raise ValueError("build must be a positive integer")
    base = config.get("updateBaseURL")
    if base:
        url = urlsplit(base)
        if (url.scheme != "https" or not url.hostname or url.username or url.password
                or url.query or url.fragment or any(c.isspace() for c in base)):
            raise ValueError("updateBaseURL must be an HTTPS directory URL without credentials, query, or fragment")
    elif require_updates:
        raise ValueError("Set a permanent public HTTPS updateBaseURL in release.json before packaging a release")
    key = config.get("sparklePublicKey")
    if key:
        try:
            valid_key = len(base64.b64decode(key, validate=True)) == 32
        except (ValueError, TypeError):
            valid_key = False
        if not valid_key:
            raise ValueError("sparklePublicKey must be a base64-encoded 32-byte Ed25519 public key")
    elif require_updates and platform == "mac":
        raise ValueError("Generate a Sparkle signing key and set sparklePublicKey in release.json")
    return config


def mac_plist(config):
    info = dict(
        CFBundleName="SmartNotch", CFBundleDisplayName="SmartNotch",
        CFBundleIdentifier="in.maheshmoholkar.smartnotch", CFBundleExecutable="SmartNotch",
        CFBundleIconFile="AppIcon", CFBundlePackageType="APPL",
        CFBundleShortVersionString=config["version"], CFBundleVersion=str(config["build"]),
        LSMinimumSystemVersion="14.0", NSHighResolutionCapable=True,
        NSHumanReadableCopyright="MaheshLabs",
        NSMicrophoneUsageDescription="Follow your script as you speak. Audio is processed on this Mac.",
        NSSpeechRecognitionUsageDescription="Match your spoken words to your script using on-device recognition.",
    )
    if config.get("updateBaseURL") and config.get("sparklePublicKey"):
        info.update(
            SUFeedURL=config["updateBaseURL"].rstrip("/") + "/mac/appcast.xml",
            SUPublicEDKey=config["sparklePublicKey"], SUEnableAutomaticChecks=True,
            SUScheduledCheckInterval=86400, SUAutomaticallyUpdate=False,
            SUEnableSystemProfiling=False,
        )
    return info


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["validate", "mac-plist", "get"])
    parser.add_argument("value", nargs="?")
    parser.add_argument("--require-updates", action="store_true")
    parser.add_argument("--platform", choices=["mac", "windows"], default="mac")
    args = parser.parse_args()
    try:
        config = validate(json.loads((ROOT / "release.json").read_text()), args.require_updates, args.platform)
        if args.command == "mac-plist":
            if not args.value:
                parser.error("mac-plist requires an output path")
            Path(args.value).write_bytes(plistlib.dumps(mac_plist(config)))
        elif args.command == "get":
            if args.value not in config:
                parser.error("Unknown release.json field")
            print(config[args.value] or "")
    except (ValueError, OSError) as error:
        parser.exit(1, f"Release configuration: {error}\n")


if __name__ == "__main__":
    main()
