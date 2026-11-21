"""Connect staged download/update routes to a manually published GitHub Release."""
import argparse
import json

from release_assets import SITE, read_registry, release_base, render_routes, write_json
from release_config import ROOT


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", help="https://github.com/OWNER/REPO/releases/tag/v0.2.0")
    parser.add_argument("--version", default=json.loads((ROOT / "release.json").read_text())["version"])
    args = parser.parse_args()
    base = release_base(args.url)
    registry = read_registry()
    if not any(entry["version"] == args.version for entry in registry["routes"].values()):
        parser.error("Stage this version's packages before configuring its release URL")
    previous = registry["releases"].get(args.version)
    if previous and release_base(previous) != base:
        parser.error("This version already points at a different release; retain old update destinations")
    registry["releases"][args.version] = base
    write_json(SITE / "release-assets.json", registry)
    render_routes()
    print("Configured GitHub downloads and compatibility redirects. Feeds and signed packages are unchanged.")
    print("Before deploying, confirm every staged asset is uploaded and the public URLs work without login.")


if __name__ == "__main__":
    main()
