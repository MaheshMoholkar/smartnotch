import json
from pathlib import Path
import tempfile
import unittest

from release_assets import read_registry, release_base, render_routes, sha256, stage_asset, write_json


class ReleaseAssetTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.site = self.root / "landing"
        (self.site / "app").mkdir(parents=True)
        self.output = self.root / "assets"
        self.archive = self.root / "archive.dmg"
        self.archive.write_bytes(b"signed archive bytes")
        write_json(self.site / "vercel.json", {"headers": [{"source": "/updates/(.*)", "headers": []}],
                                              "redirects": [{"source": "/other", "destination": "/", "permanent": False}]})
        write_json(self.site / "app/downloads.json", {"mac": {"file": "/assets/SmartNotch.dmg"}})

    def stage(self, route, version="0.2.0", name="SmartNotch-0.2.0.dmg"):
        return stage_asset(self.archive, route, version, name, self.site, self.output)

    def configure(self, version):
        registry = read_registry(self.site)
        registry["releases"][version] = f"https://github.com/owner/smartnotch/releases/download/v{version}"
        write_json(self.site / "release-assets.json", registry)

    def test_only_specific_github_release_urls_are_accepted(self):
        expected = "https://github.com/owner/smartnotch/releases/download/v0.2.0"
        self.assertEqual(release_base(expected.replace("download", "tag") + "/"), expected)
        self.assertEqual(release_base(expected), expected)
        for bad in ["http://github.com/o/r/releases/tag/v1", "https://github.com/o/r/releases/latest",
                    expected + "?token=secret", "https://github.com@evil.com/o/r/releases/tag/v1"]:
            with self.subTest(url=bad), self.assertRaises(ValueError):
                release_base(bad)

    def test_staging_preserves_signed_bytes_and_rejects_overwrite(self):
        target = self.stage("/updates/mac/SmartNotch-0.2.0.dmg")
        self.assertEqual(target.read_bytes(), self.archive.read_bytes())
        self.assertFalse((self.site / "public").exists())
        self.assertEqual(target.with_name(target.name + ".sha256").read_text().split()[0], sha256(self.archive))
        self.archive.write_bytes(b"altered archive")
        with self.assertRaisesRegex(ValueError, "Never replace"):
            self.stage("/updates/mac/SmartNotch-0.2.0.dmg")
        self.assertEqual(target.read_bytes(), b"signed archive bytes")
        with self.assertRaisesRegex(ValueError, "different bytes"):
            self.stage("/assets/SmartNotch.dmg")

    def test_new_release_updates_download_but_preserves_old_update_redirect(self):
        old = "/updates/mac/SmartNotch-0.2.0.dmg"
        self.stage(old)
        self.stage("/assets/SmartNotch.dmg", name="SmartNotch.dmg")
        self.configure("0.2.0")
        render_routes(self.site)
        self.archive.write_bytes(b"new signed archive")
        self.stage("/updates/mac/SmartNotch-0.2.1.dmg", "0.2.1", "SmartNotch-0.2.1.dmg")
        self.stage("/assets/SmartNotch.dmg", "0.2.1", "SmartNotch.dmg")
        self.configure("0.2.1")
        render_routes(self.site)
        config = json.loads((self.site / "vercel.json").read_text())
        rules = {entry["source"]: entry for entry in config["redirects"]}
        self.assertIn("/v0.2.0/", rules[old]["destination"])
        self.assertIn("/v0.2.1/", rules["/assets/SmartNotch.dmg"]["destination"])
        self.assertTrue(all(rule["permanent"] is False for rule in rules.values()))
        self.assertEqual(rules["/other"]["destination"], "/")
        self.assertIn("headers", config)
        self.assertIn("/v0.2.1/", json.loads((self.site / "app/downloads.json").read_text())["mac"]["file"])

    def test_unconfigured_release_does_not_generate_fake_destinations(self):
        self.stage("/assets/SmartNotch.dmg")
        render_routes(self.site)
        rules = json.loads((self.site / "vercel.json").read_text())["redirects"]
        self.assertEqual([r["source"] for r in rules], ["/other"])
        self.assertEqual(json.loads((self.site / "app/downloads.json").read_text())["mac"]["file"], "/assets/SmartNotch.dmg")

    def test_unversioned_setup_route_can_follow_a_new_release(self):
        route = "/updates/windows/win-x64/SmartNotch-win-Setup.exe"
        self.stage(route, name="SmartNotch-Windows-x64-Setup.exe")
        self.archive.write_bytes(b"new installer")
        self.stage(route, "0.2.1", "SmartNotch-Windows-x64-Setup.exe")
        self.assertEqual(read_registry(self.site)["routes"][route]["version"], "0.2.1")


if __name__ == "__main__":
    unittest.main()
