import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from smartnotch.model import Script, Session, new_card, new_title


class SessionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "session.json"
        self.session = Session(self.path)

    def test_all_sections_have_independent_titles_settings_and_selections(self):
        self.session.title["text"] = "Reading"
        reading_id = self.session.title["id"]
        self.session.data["section"] = "Cards"
        self.session.title["cards"].append(new_card("Card", "Detail", "Notes", True))
        self.session.state["appearance"]["width"] = 680
        deck = new_title("Cards", "Another deck")
        self.session.state["titles"].append(deck)
        self.session.state["selected"] = deck["id"]
        self.session.save()
        restored = Session(self.path)
        self.assertEqual(restored.title["title"], "Another deck")
        self.assertEqual(restored.state["appearance"]["width"], 680)
        self.assertTrue(restored.state["titles"][0]["cards"][0]["completed"])
        restored.data["section"] = "Read"
        self.assertEqual(restored.title["id"], reading_id)
        self.assertEqual(restored.title["text"], "Reading")
        self.assertEqual(restored.state["appearance"]["width"], 580)

    def test_progress_and_unicode_round_trip(self):
        self.session.title.update(text="मराठी hello 😀 world", wordIndex=2, wordProgress=.7)
        self.session.save()
        restored = Session(self.path)
        self.assertEqual(restored.title["wordIndex"], 2)
        self.assertEqual(restored.title["wordProgress"], .7)
        self.assertEqual(restored.title["text"], "मराठी hello 😀 world")

    def test_corruption_preserved(self):
        self.path.write_text("{broken")
        with self.assertRaises(ValueError):
            Session(self.path)
        self.assertEqual(self.path.read_text(), "{broken")

    def test_failed_replace_keeps_last_session_and_cleans_temporary(self):
        self.session.save()
        before = self.path.read_bytes()
        self.session.title["text"] = "Unsaved"
        with patch("smartnotch.model.os.replace", side_effect=OSError("Disk error")):
            with self.assertRaises(OSError):
                self.session.save()
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(list(self.path.parent.glob(".session-*")), [])

    def test_out_of_bounds_settings_and_indices_are_sanitized(self):
        self.session.title.update(text="one two", wordIndex=999, wordProgress=-10)
        self.session.data.update(speed=-1, rate=99)
        self.session.state["appearance"].update(fontSize=100, height=-4)
        self.session.save()
        restored = Session(self.path)
        self.assertEqual(restored.title["wordIndex"], 1)
        self.assertEqual(restored.title["wordProgress"], 0)
        self.assertEqual(restored.data["speed"], 60)
        self.assertEqual(restored.data["rate"], 2)
        self.assertEqual(restored.state["appearance"]["fontSize"], 36)
        self.assertEqual(restored.state["appearance"]["height"], 260)

    def test_invalid_nested_data_is_not_silently_replaced(self):
        self.session.data["sections"]["Read"]["titles"] = ["broken"]
        self.path.write_text(json.dumps(self.session.data))
        with self.assertRaisesRegex(ValueError, "preserved"):
            Session(self.path)

    def test_xdg_and_session_override(self):
        with patch.dict(os.environ, {"XDG_DATA_HOME": self.directory.name}, clear=True):
            self.assertEqual(Session().path, Path(self.directory.name) / "MaheshLabs/SmartNotch/session.json")
        with patch.dict(os.environ, {"SMARTNOTCH_SESSION_PATH": str(self.path)}):
            self.assertEqual(Session().path, self.path)


class ReadingTests(unittest.TestCase):
    def test_timing_fraction_finish_and_saved_resume(self):
        script = Script("one two three")
        title = new_title("Read")
        script.advance(title, .25, 120)
        self.assertEqual(title["wordIndex"], 0)
        self.assertEqual(title["wordProgress"], .5)
        script.advance(title, .5, 120)
        self.assertEqual(title["wordIndex"], 1)
        self.assertEqual(title["wordProgress"], .5)
        script.advance(title, 10, 120)
        self.assertEqual(title["wordIndex"], 2)
        self.assertTrue(title["finished"])
        self.assertEqual(title["wordProgress"], 0)

    def test_paragraph_navigation_and_empty_script(self):
        script = Script("one two\nthree four\n\nfive")
        self.assertEqual(script.paragraph(0, True), 2)
        self.assertEqual(script.paragraph(2, True), 4)
        self.assertEqual(script.paragraph(4, False), 2)
        self.assertEqual(script.paragraph(2, False), 0)
        self.assertEqual(script.paragraph(4, True), 4)
        self.assertEqual(Script("").paragraph(0, False), 0)
        title = new_title("Read")
        Script("").advance(title, 5, 240)
        self.assertFalse(title["finished"])


if __name__ == "__main__":
    unittest.main()
