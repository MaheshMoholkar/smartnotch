import json
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

from stage_windows_release import sha256, stage, verify_release


def executable(machine=0x8664):
    data = bytearray(128)
    data[:2] = b"MZ"
    struct.pack_into("<I", data, 60, 64)
    data[64:68] = b"PE\0\0"
    struct.pack_into("<H", data, 68, machine)
    return bytes(data)


class WindowsReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "release"
        self.source.mkdir()
        self.package = self.source / "SmartNotch-0.2.0-full.nupkg"
        with zipfile.ZipFile(self.package, "w") as archive:
            archive.writestr("lib/net10.0/SmartNotch.exe", executable())
        self.installer = self.source / "SmartNotch-win-Setup.exe"
        self.installer.write_bytes(executable())
        self.feed = {"Assets": [{"PackageId": "SmartNotch", "Version": "0.2.0", "Type": "Full",
                                 "FileName": self.package.name, "Size": self.package.stat().st_size,
                                 "SHA256": sha256(self.package)}]}
        self.write_feed()
        self.public = self.root / "public"
        self.manifest = self.root / "downloads.json"
        self.manifest.write_text(json.dumps({"mac": {"version": "0.2.0"}, "windows": {"format": "Portable ZIP", "file": "/old.zip"}}))

    def write_feed(self):
        (self.source / "releases.win.json").write_text(json.dumps(self.feed))

    def test_valid_release_stages_installer_feed_and_matching_site_metadata(self):
        stage(self.source, "win-x64", "0.2.0", self.public, self.manifest, self.root / "github-release")
        result = json.loads(self.manifest.read_text())
        self.assertEqual(result["windows"]["version"], "0.2.0")
        self.assertEqual(result["windows"]["format"], "EXE")
        self.assertTrue(result["windows"]["inAppUpdates"])
        self.assertEqual(result["mac"]["version"], "0.2.0")
        self.assertEqual((self.root / "github-release/0.2.0/SmartNotch-Windows-x64-Setup.exe").read_bytes(), self.installer.read_bytes())
        self.assertFalse((self.public / "assets/SmartNotch-Windows-x64-Setup.exe").exists())
        self.assertFalse(list(self.public.rglob("*.nupkg")))
        self.assertTrue((self.public / "updates/windows/win-x64/releases.win.json").is_file())

    def test_tampered_package_does_not_change_site(self):
        data = bytearray(self.package.read_bytes())
        data[-1] ^= 1
        self.package.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "checksum failed"):
            stage(self.source, "win-x64", "0.2.0", self.public, self.manifest)
        self.assertEqual(json.loads(self.manifest.read_text())["windows"]["file"], "/old.zip")
        self.assertFalse(self.public.exists())

    def test_wrong_processor_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "wrong processor"):
            verify_release(self.source, "win-arm64", "0.2.0")

    def test_wrong_version_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "No full update package"):
            verify_release(self.source, "win-x64", "0.2.1")

    def test_feed_cannot_reference_files_outside_release_directory(self):
        self.feed["Assets"][0]["FileName"] = "../another.nupkg"
        self.write_feed()
        with self.assertRaisesRegex(ValueError, "filename"):
            verify_release(self.source, "win-x64", "0.2.0")

    def test_missing_setup_is_rejected(self):
        self.installer.unlink()
        with self.assertRaisesRegex(ValueError, "Setup.exe"):
            verify_release(self.source, "win-x64", "0.2.0")

    def test_non_executable_setup_is_rejected(self):
        self.installer.write_bytes(b"Not an executable")
        with self.assertRaisesRegex(ValueError, "PE executable"):
            verify_release(self.source, "win-x64", "0.2.0")

    def test_feed_with_older_packages_keeps_each_package_in_its_own_release(self):
        old = self.source / "SmartNotch-0.1.0-full.nupkg"
        old.write_bytes(self.package.read_bytes())
        self.feed["Assets"].append({**self.feed["Assets"][0], "Version": "0.1.0", "FileName": old.name})
        self.write_feed()
        stage(self.source, "win-x64", "0.2.0", self.public, self.manifest, self.root / "github-release")
        registry = json.loads((self.root / "release-assets.json").read_text())
        self.assertEqual(registry["routes"]["/updates/windows/win-x64/" + old.name]["version"], "0.1.0")
        self.assertTrue((self.root / "github-release/0.1.0" / old.name).is_file())

    def test_arm64_assets_cannot_collide_with_x64(self):
        stage(self.source, "win-x64", "0.2.0", self.public, self.manifest, self.root / "github-release")
        x64 = (self.root / "github-release/0.2.0" / self.package.name).read_bytes()
        with zipfile.ZipFile(self.package, "w") as archive:
            archive.writestr("lib/net10.0/SmartNotch.exe", executable(0xAA64))
        self.feed["Assets"][0].update(Size=self.package.stat().st_size, SHA256=sha256(self.package))
        self.write_feed()
        stage(self.source, "win-arm64", "0.2.0", self.public, self.manifest, self.root / "github-release")
        self.assertEqual((self.root / "github-release/0.2.0" / self.package.name).read_bytes(), x64)
        self.assertEqual((self.root / "github-release/0.2.0" / ("win-arm64-" + self.package.name)).read_bytes(), self.package.read_bytes())


if __name__ == "__main__":
    unittest.main()
