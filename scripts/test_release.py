import base64
from copy import deepcopy
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

from release_config import validate, mac_plist
from make_appcast import make_feed, SPARKLE


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.config = {"version": "0.2.0", "build": 2,
                       "updateBaseURL": "https://updates.example.com/smartnotch/",
                       "sparklePublicKey": base64.b64encode(bytes(32)).decode()}

    def test_release_requires_host_and_mac_key(self):
        for field in ["updateBaseURL", "sparklePublicKey"]:
            config = deepcopy(self.config)
            config[field] = None
            with self.assertRaises(ValueError):
                validate(config, require_updates=True)

    def test_rejects_invalid_release_metadata(self):
        for field, values in {
            "updateBaseURL": ["http://example.com", "file:///tmp/updates", "https://a:b@example.com/", "https://example.com/?token=a", "https://example.com/#x"],
            "sparklePublicKey": ["bad", base64.b64encode(bytes(64)).decode()],
            "build": [0, -1, True], "version": ["0.2", "v0.2.0", "0.2.0-beta"]
        }.items():
            for value in values:
                with self.subTest(field=field, value=value):
                    with self.assertRaises(ValueError):
                        validate({**self.config, field: value}, require_updates=True)

    def test_windows_release_does_not_require_mac_key(self):
        validate({**self.config, "sparklePublicKey": None}, require_updates=True, platform="windows")

    def test_plist_uses_monotonic_build_and_does_not_enable_silent_install(self):
        info = mac_plist(validate(self.config, True))
        self.assertEqual(info["CFBundleVersion"], "2")
        self.assertEqual(info["CFBundleShortVersionString"], "0.2.0")
        self.assertEqual(info["SUFeedURL"], "https://updates.example.com/smartnotch/mac/appcast.xml")
        self.assertFalse(info["SUAutomaticallyUpdate"])
        self.assertTrue(info["SUEnableAutomaticChecks"])
        self.assertNotIn("SUFeedURL", mac_plist({**self.config, "sparklePublicKey": None}))

    def test_feed_escapes_notes_and_uses_signed_archive_length(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "SmartNotch-0.2.0.dmg"
            archive.write_bytes(b"test archive")
            signature = base64.b64encode(bytes(64)).decode()
            attributes = f'sparkle:edSignature="{signature}" length="{archive.stat().st_size}"'
            notes = "Notes with <markup> & special characters"
            feed = ET.fromstring(make_feed(self.config, archive, attributes, notes))
            self.assertEqual(feed.findtext("./channel/item/description"), notes)
            self.assertEqual(feed.findtext(f"./channel/item/{{{SPARKLE}}}version"), "2")
            self.assertEqual(feed.find("./channel/item/enclosure").get("url"),
                             "https://updates.example.com/smartnotch/mac/SmartNotch-0.2.0.dmg")
            with self.assertRaises(ValueError):
                make_feed(self.config, archive, attributes.replace('length="12"', 'length="1"'), notes)
            with self.assertRaises(ValueError):
                make_feed(self.config, archive, 'sparkle:edSignature="bad" length="12"', notes)


if __name__ == "__main__":
    unittest.main()
