"""Run with an installed Qt runtime: QT_QPA_PLATFORM=offscreen python -m unittest ..."""
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    from PySide6.QtWidgets import QApplication
    from smartnotch.app import Workspace, STYLE
    from smartnotch.model import Session, new_card
except ImportError:
    raise unittest.SkipTest("Qt runtime not installed")


class GuiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])
        cls.app.setStyleSheet(STYLE)
        cls.app.setQuitOnLastWindowClosed(False)

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.session = Session(Path(self.directory.name) / "session.json")
        self.workspace = Workspace(self.session)

    def tearDown(self):
        self.workspace.timer.stop()
        self.workspace.save_timer.stop()
        self.workspace.hotkeys.close()
        self.workspace.tray.hide()
        self.workspace.panel.hide()
        self.workspace.trigger.hide()
        self.workspace.hide()
        self.workspace.deleteLater()
        self.app.processEvents()
        self.directory.cleanup()

    def test_edit_switch_and_persist_without_cross_section_changes(self):
        self.workspace.text.setPlainText("one two\nthree four")
        self.workspace.navigate(True)
        self.assertEqual(self.session.title["wordIndex"], 2)
        self.workspace.switch_section("Notes")
        self.workspace.text.setPlainText("मराठी note 😀")
        self.workspace.switch_section("Read")
        self.assertEqual(self.workspace.text.toPlainText(), "one two\nthree four")
        self.assertEqual(self.session.title["wordIndex"], 2)
        self.workspace.save()
        self.assertEqual(Session(self.session.path).title["wordIndex"], 2)

    def test_card_notes_deliberate_edit_and_completion(self):
        self.workspace.switch_section("Cards")
        self.workspace.add_card()
        self.workspace.card_title.setText("First")
        self.workspace.edit_card_title("First")
        self.workspace.panel.begin_edit()
        self.assertTrue(self.workspace.panel.pinned)
        self.workspace.panel.notes.setPlainText("Notes in panel")
        self.workspace.panel.done.click()
        self.assertFalse(self.workspace.panel.editing)
        self.assertEqual(self.session.card["notes"], "Notes in panel")
        self.assertIn("Notes in panel", self.workspace.panel.reader.toPlainText())
        self.workspace.toggle_card()
        self.assertTrue(self.session.card["completed"])
        self.workspace.add_card()
        self.workspace.navigate(False)
        self.assertEqual(self.session.title["selectedCard"], 0)

    def test_play_hide_resume_and_end(self):
        self.workspace.text.setPlainText("one two three")
        self.workspace.toggle_play()
        self.assertTrue(self.workspace.playing)
        self.workspace.script.advance(self.session.title, .6, 150)
        self.workspace.panel.dismiss()
        self.assertFalse(self.workspace.playing)
        self.assertEqual(self.session.title["wordIndex"], 1)
        self.workspace.toggle_play()
        self.assertEqual(self.session.title["wordIndex"], 1)
        self.workspace.script.advance(self.session.title, 10, 150)
        self.workspace.tick()
        self.assertFalse(self.workspace.playing)
        self.assertTrue(self.session.title["finished"])

    def test_manual_mode_never_starts_playback(self):
        self.session.data["mode"] = "Manual"
        self.workspace.toggle_play()
        self.assertFalse(self.workspace.playing)
        self.assertTrue(self.workspace.panel.isVisible())

    def test_unicode_reader_preserves_text_and_word_highlight(self):
        text = "😀 Start\n\nमराठी text & <tag>"
        self.workspace.text.setPlainText(text)
        self.assertEqual(self.workspace.panel.reader.toPlainText(), text)
        self.session.title["wordIndex"] = 2
        self.workspace.panel.highlight()
        self.assertEqual(self.workspace.panel.reader.textCursor().selectedText(), "मराठी")


if __name__ == "__main__":
    unittest.main()
