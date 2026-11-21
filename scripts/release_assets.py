"""Stage immutable GitHub assets outside the website; retain every old update route."""
import hashlib
import json
from pathlib import Path
import re
import shutil
from urllib.parse import urlsplit

from release_config import ROOT

SITE = ROOT / "landing"
OUTPUT = ROOT / "dist/github-release"


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_registry(site=SITE):
    path = site / "release-assets.json"
    return json.loads(path.read_text()) if path.exists() else {"releases": {}, "routes": {}}


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")
    temporary.replace(path)


def release_base(url):
    parts = urlsplit(url)
    match = re.fullmatch(r"/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/releases/(?:tag|download)/([^/]+)", parts.path.rstrip("/"))
    if (parts.scheme != "https" or parts.netloc != "github.com" or parts.query
            or parts.fragment or not match or any(c.isspace() for c in url)):
        raise ValueError("Use https://github.com/OWNER/REPO/releases/tag/TAG (a specific public release)")
    owner, repo, tag = match.groups()
    if any(part in {".", ".."} for part in (owner, repo, tag)):
        raise ValueError("Invalid GitHub release URL")
    return f"https://github.com/{owner}/{repo}/releases/download/{tag}"


def stage_asset(source, route, version, asset_name=None, site=SITE, output=OUTPUT):
    source = Path(source)
    name = asset_name or source.name
    if (not re.fullmatch(r"[A-Za-z0-9_.-]+", name) or name in {".", ".."}
            or not re.fullmatch(r"\d+\.\d+\.\d+", version)
            or not route.startswith(("/assets/", "/updates/"))
            or any(part in {".", ".."} for part in route.split("/"))):
        raise ValueError("Invalid release asset name, version, or route")
    digest = sha256(source)
    record = {"version": version, "asset": name, "sha256": digest}
    registry = read_registry(site)
    previous = registry["routes"].get(route)
    immutable_route = route.startswith("/updates/") and route.lower().endswith((".dmg", ".nupkg"))
    if previous and immutable_route and previous != record:
        raise ValueError(f"Never replace a versioned update route: {route}")
    destination = output / version / name
    if destination.exists() and sha256(destination) != digest:
        raise ValueError(f"Release asset already exists with different bytes: {destination}. Increment the version.")
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.resolve() != destination.resolve() and not destination.exists():
        shutil.copy2(source, destination)
    destination.with_name(name + ".sha256").write_text(f"{digest}  {name}\n")
    registry["routes"][route] = record
    write_json(site / "release-assets.json", registry)
    return destination


def render_routes(site=SITE):
    """Generate only configured destinations; no guessed or placeholder URLs."""
    registry = read_registry(site)
    config_path = site / "vercel.json"
    config = json.loads(config_path.read_text())
    routes = registry["routes"]
    redirects = [r for r in config.get("redirects", []) if r["source"] not in routes]
    for route, entry in sorted(routes.items()):
        base = registry["releases"].get(entry["version"])
        if base:
            redirects.append({"source": route, "destination": release_base(base) + "/" + entry["asset"],
                              "permanent": False})
    config["redirects"] = redirects
    write_json(config_path, config)
    manifest = site / "app/downloads.json"
    downloads = json.loads(manifest.read_text(encoding="utf-8-sig"))
    aliases = {"mac": "/assets/SmartNotch.dmg", "windows": "/assets/SmartNotch-Windows-x64-Setup.exe",
               "linux": "/assets/SmartNotch-Linux.tar.gz"}
    for platform, route in aliases.items():
        entry = routes.get(route)
        if not entry or platform not in downloads:
            continue
        base = registry["releases"].get(entry["version"])
        downloads[platform]["file"] = release_base(base) + "/" + entry["asset"] if base else route
    write_json(manifest, downloads)
