"""Qt desktop editor, top-edge trigger, and floating teleprompter."""
import html
import os
import sys
import time
from pathlib import Path

from PySide6.QtCore import QLockFile, Qt, QTimer
from PySide6.QtGui import QColor, QCursor, QIcon, QKeySequence, QShortcut, QTextCursor
from PySide6.QtWidgets import (QApplication, QCheckBox, QComboBox, QDoubleSpinBox, QFileDialog,
    QFormLayout, QFrame, QHBoxLayout, QInputDialog, QLabel, QListWidget, QMainWindow, QMenu,
    QMessageBox, QPlainTextEdit, QPushButton, QSizeGrip, QSpinBox,
    QSplitter, QSystemTrayIcon, QTextBrowser, QTextEdit, QVBoxLayout, QWidget)

from .model import SECTIONS, Script, Session, new_card, new_title

INKS = {"White": "#f0f3f5", "Gray": "#b9c0c8", "Soft cyan": "#a6efcd", "Yellow": "#f5d778"}
STYLE = """
QWidget { color: #dfe8e3; font-family: 'Inter', 'Noto Sans', sans-serif; font-size: 13px; }
QMainWindow, QDialog { background: #151a18; }
QPushButton, QComboBox, QSpinBox, QDoubleSpinBox { background: #252e29; border: 1px solid #3a4840; border-radius: 7px; padding: 6px 10px; min-height: 19px; }
QPushButton:hover { background: #354c3f; border-color: #82bd9e; }
QPushButton:checked { background: #365746; color: #b8fadd; border-color: #7eae95; }
QPushButton:disabled { color: #6c7e72; }
QLineEdit, QPlainTextEdit, QListWidget, QTextBrowser { background: #1b221e; border: 1px solid #354039; border-radius: 8px; padding: 8px; selection-background-color: #3b6952; }
QListWidget::item { padding: 9px; border-radius: 5px; }
QListWidget::item:selected { background: #304b3c; }
QMenu { background: #222c25; border: 1px solid #485b4d; padding: 5px; }
QMenu::item { padding: 7px 18px; } QMenu::item:selected { background: #365746; }
QToolTip { background: #27372c; color: #e4eee7; border: 1px solid #627e6a; }
"""


def button(label, callback, checkable=False):
    result = QPushButton(label)
    result.setCursor(Qt.CursorShape.PointingHandCursor)
    result.setCheckable(checkable)
    result.clicked.connect(lambda checked=False: callback())
    return result


def row(*widgets):
    result = QHBoxLayout()
    result.setSpacing(6)
    for widget in widgets:
        result.addWidget(widget)
    return result


class Reader(QTextBrowser):
    def __init__(self, workspace):
        super().__init__()
        self.workspace = workspace
        self.setOpenLinks(False)
        self.anchorClicked.connect(self.select_word)

    def select_word(self, url):
        index = url.toString()
        if index.startswith("word:"):
            self.workspace.pause()
            self.workspace.session.title.update(wordIndex=int(index[5:]), wordProgress=0, finished=False)
            self.workspace.save_soon()
            self.workspace.panel.highlight()


class Trigger(QWidget):
    def __init__(self, workspace):
        super().__init__(None, Qt.WindowType.Tool | Qt.WindowType.FramelessWindowHint |
                         Qt.WindowType.WindowStaysOnTopHint | Qt.WindowType.WindowDoesNotAcceptFocus)
        self.workspace = workspace
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating)
        self.setFixedSize(112, 10)
        self.setStyleSheet("background: #293b30; border-bottom-left-radius: 6px; border-bottom-right-radius: 6px;")
        self.setToolTip("SmartNotch · Hover to open; click to pin or hide")
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setAccessibleName("SmartNotch floating panel trigger")

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.workspace.toggle_panel()

    def enterEvent(self, event):
        if self.workspace.session.state["appearance"]["hover"]:
            self.workspace.panel.reveal(False)


class Panel(QWidget):
    def __init__(self, workspace):
        super().__init__(None, Qt.WindowType.Tool | Qt.WindowType.FramelessWindowHint |
                         Qt.WindowType.WindowStaysOnTopHint)
        self.workspace = workspace
        self.pinned = False
        self.editing = False
        self.setWindowTitle("SmartNotch panel")
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setMinimumSize(420, 260)
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        self.frame = QFrame()
        self.frame.setObjectName("panelFrame")
        outer.addWidget(self.frame)
        layout = QVBoxLayout(self.frame)
        self.tabs = []
        tabs = QHBoxLayout()
        for section in SECTIONS:
            tab = button(section, lambda checked=False, s=section: workspace.switch_section(s), True)
            self.tabs.append(tab)
            tabs.addWidget(tab)
        tabs.addStretch()
        self.pin = button("Pin", self.toggle_pin, True)
        tabs.addWidget(self.pin)
        tabs.addWidget(button("Editor", workspace.show_editor))
        tabs.addWidget(button("×", self.dismiss))
        layout.addLayout(tabs)
        self.titles = QComboBox()
        self.titles.setAccessibleName("Selected title")
        self.titles.activated.connect(lambda i: workspace.select_title(self.titles.itemData(i)))
        layout.addWidget(self.titles)
        self.controls_widget = QWidget()
        self.controls = QHBoxLayout(self.controls_widget)
        self.controls.setContentsMargins(0, 0, 0, 0)
        self.previous = button("Previous", lambda: workspace.navigate(False))
        self.play = button("Play", workspace.toggle_play)
        self.next = button("Next", lambda: workspace.navigate(True))
        self.restart = button("Restart", workspace.restart)
        self.complete = button("Mark done", workspace.toggle_card)
        self.edit = button("Edit notes", self.begin_edit)
        self.done = button("Done", self.finish_edit)
        for control in (self.previous, self.play, self.next, self.restart, self.complete, self.edit, self.done):
            self.controls.addWidget(control)
        layout.addWidget(self.controls_widget)
        self.reader = Reader(workspace)
        self.reader.setStyleSheet("QTextBrowser { background: transparent; border: none; }")
        layout.addWidget(self.reader, 1)
        self.notes = QPlainTextEdit()
        self.notes.textChanged.connect(self.save_notes)
        self.notes.hide()
        layout.addWidget(self.notes, 1)
        footer = QHBoxLayout()
        self.status = QLabel()
        footer.addWidget(self.status, 1)
        footer.addWidget(button("Configure", workspace.show_settings))
        grip = QSizeGrip(self)
        grip.setToolTip("Drag to resize the panel")
        footer.addWidget(grip)
        layout.addLayout(footer)
        self.shortcuts = []
        for key, callback in (("Escape", self.finish_edit), ("Left", lambda: self.card_key(False)),
                              ("Right", lambda: self.card_key(True)), ("Space", self.space_key)):
            shortcut = QShortcut(QKeySequence(key), self)
            shortcut.activated.connect(callback)
            self.shortcuts.append(shortcut)

    def card_key(self, forward):
        if not self.editing and self.workspace.session.section == "Cards":
            self.workspace.navigate(forward)

    def space_key(self):
        if not self.editing:
            if self.workspace.session.section == "Cards":
                self.workspace.toggle_card()
            elif self.workspace.session.section == "Read":
                self.workspace.toggle_play()

    def toggle_pin(self):
        if self.editing:
            self.pin.setChecked(True)
            return
        self.pinned = self.pin.isChecked()

    def reveal(self, pinned=False):
        if pinned:
            self.pinned = True
            self.pin.setChecked(True)
        self.show()
        self.raise_()

    def dismiss(self):
        self.workspace.pause()
        self.finish_edit()
        self.pinned = False
        self.pin.setChecked(False)
        self.hide()

    def refresh(self):
        self.finish_edit(refresh=False)
        session = self.workspace.session
        section = session.section
        for tab, name in zip(self.tabs, SECTIONS):
            tab.setChecked(name == section)
        self.titles.clear()
        for title in session.state["titles"]:
            self.titles.addItem(title["title"] or "Untitled", title["id"])
        self.titles.setCurrentIndex(self.titles.findData(session.state["selected"]))
        for control in (self.previous, self.next):
            control.setVisible(section != "Notes")
        for control in (self.play, self.restart):
            control.setVisible(section == "Read")
        self.complete.setVisible(section == "Cards")
        self.complete.setEnabled(session.card is not None)
        self.edit.setVisible(section != "Read")
        self.edit.setEnabled(section == "Notes" or session.card is not None)
        appearance = session.state["appearance"]
        color = INKS.get(appearance["ink"], INKS["Soft cyan"])
        alpha = round(255 * (1 - appearance["transparency"] / 100))
        self.frame.setStyleSheet(f"QFrame#panelFrame {{ background: rgba(20, 27, 23, {alpha}); border: 1px solid rgba(125, 168, 143, {alpha}); border-radius: 14px; }}")
        font = self.reader.font()
        font.setPointSize(int(appearance["fontSize"]))
        self.reader.setFont(font)
        self.reader.document().setDefaultStyleSheet(f"body {{color:{color};}} a {{color:{color};text-decoration:none;}}")
        self.reader.setTextColor(QColor(color))
        if section == "Read":
            script = self.workspace.script
            parts, offset = [], 0
            for i, match in enumerate(script.words):
                parts.append(html.escape(script.text[offset:match.start()]))
                parts.append(f'<a href="word:{i}">{html.escape(match.group())}</a>')
                offset = match.end()
            parts.append(html.escape(script.text[offset:]))
            self.reader.setHtml('<body style="white-space:pre-wrap">' + "".join(parts).replace("\n", "<br>") + '</body>')
            self.highlight()
        elif section == "Cards":
            card = session.card
            self.reader.setPlainText((card["title"] + "\n\n" + card["details"] +
                                     ("\n\nNotes\n" + card["notes"] if card["notes"] else "")) if card else "Add cards in the editor.")
            count = len(session.title["cards"])
            self.status.setText(f'{session.title["selectedCard"] + 1 if count else 0} / {count} cards')
            self.complete.setText("Mark undone" if card and card["completed"] else "Mark done")
        else:
            self.reader.setPlainText(session.title["text"] or "Add notes in the editor.")
            self.status.setText("Notes · saved on this computer")
        self.position()

    def position(self):
        screen = QApplication.primaryScreen().availableGeometry()
        appearance = self.workspace.session.state["appearance"]
        self.resize(min(int(appearance["width"]), screen.width() - 32),
                    min(int(appearance["height"]), screen.height() - 42))
        self.move(screen.center().x() - self.width() // 2, screen.top() + 10)
        self.workspace.trigger.move(screen.center().x() - 56, screen.top())

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if self.isVisible():
            appearance = self.workspace.session.state["appearance"]
            appearance.update(width=self.width(), height=self.height())
            self.workspace.save_soon()

    def highlight(self):
        title = self.workspace.session.title
        words = self.workspace.script.words
        self.reader.setExtraSelections([])
        if words:
            match = words[min(title["wordIndex"], len(words) - 1)]
            # QTextCursor offsets count UTF-16 code units, unlike Python strings.
            start = len(self.workspace.script.text[:match.start()].encode("utf-16-le")) // 2
            end = start + len(match.group().encode("utf-16-le")) // 2
            cursor = QTextCursor(self.reader.document())
            cursor.setPosition(start)
            cursor.setPosition(end, QTextCursor.MoveMode.KeepAnchor)
            selection = QTextEdit.ExtraSelection()
            selection.cursor = cursor
            selection.format.setBackground(QColor("#365746"))
            selection.format.setFontUnderline(True)
            self.reader.setExtraSelections([selection])
            self.reader.setTextCursor(cursor)
            self.reader.ensureCursorVisible()
        self.status.setText("Finished" if title["finished"] else f'{title["wordIndex"] + 1 if words else 0} / {len(words)} words')

    def begin_edit(self):
        session = self.workspace.session
        if session.section == "Read" or (session.section == "Cards" and not session.card):
            return
        self.editing = True
        for shortcut in self.shortcuts[1:]:
            shortcut.setEnabled(False)
        self.pinned = True
        self.pin.setChecked(True)
        self.notes.blockSignals(True)
        self.notes.setPlainText(session.card["notes"] if session.section == "Cards" else session.title["text"])
        self.notes.blockSignals(False)
        self.reader.hide()
        self.notes.show()
        self.edit.hide()
        self.done.show()
        self.activateWindow()
        self.notes.setFocus()

    def save_notes(self):
        if not self.editing:
            return
        session = self.workspace.session
        target = session.card if session.section == "Cards" else session.title
        target["notes" if session.section == "Cards" else "text"] = self.notes.toPlainText()
        self.workspace.sync_editor_text()
        self.workspace.save_soon()

    def finish_edit(self, refresh=True):
        was_editing = self.editing
        self.editing = False
        for shortcut in self.shortcuts[1:]:
            shortcut.setEnabled(True)
        self.notes.hide()
        self.reader.show()
        self.done.hide()
        if was_editing and refresh:
            self.refresh()


class Workspace(QMainWindow):
    def __init__(self, session):
        super().__init__()
        self.session = session
        self.playing = False
        self.last_tick = time.monotonic()
        self.script = Script(session.title["text"])
        self.loading = False
        self.quitting = False
        self.setWindowTitle("SmartNotch · Workspace")
        self.resize(1040, 700)
        icon = QIcon(str(Path(__file__).resolve().parent.parent / "icon.png"))
        self.setWindowIcon(icon)
        self.save_timer = QTimer(self)
        self.save_timer.setSingleShot(True)
        self.save_timer.timeout.connect(self.save)
        self.trigger = Trigger(self)
        self.panel = Panel(self)
        self.build_editor()
        self.tray = QSystemTrayIcon(icon, self)
        menu = QMenu(self)
        for label, callback in (("Open editor", self.show_editor), ("Show / hide panel", self.toggle_panel),
                                ("Quit SmartNotch", self.quit)):
            menu.addAction(label, callback)
        self.tray.setContextMenu(menu)
        self.tray.setToolTip("SmartNotch")
        self.tray.activated.connect(lambda reason: self.show_editor() if reason == QSystemTrayIcon.ActivationReason.Trigger else None)
        if QSystemTrayIcon.isSystemTrayAvailable():
            self.tray.show()
        self.shortcuts = []
        for keys, callback in (("Ctrl+Alt+P", self.toggle_panel), ("Ctrl+Alt+Space", self.toggle_play),
                               ("Ctrl+Alt+Up", lambda: self.navigate(False)),
                               ("Ctrl+Alt+Down", lambda: self.navigate(True)), ("Ctrl+Alt+E", self.show_editor)):
            shortcut = QShortcut(QKeySequence(keys), self)
            shortcut.setContext(Qt.ShortcutContext.ApplicationShortcut)
            shortcut.activated.connect(callback)
            self.shortcuts.append(shortcut)
        self.timer = QTimer(self)
        self.timer.setInterval(40)
        self.timer.timeout.connect(self.tick)
        self.timer.start()
        from .hotkeys import GlobalHotkeys
        self.hotkeys = GlobalHotkeys(self)
        if self.hotkeys.available:
            for shortcut in self.shortcuts:
                shortcut.setEnabled(False)
        self.refresh()
        self.trigger.show()
        QApplication.primaryScreen().availableGeometryChanged.connect(lambda _: self.panel.position())

    def build_editor(self):
        root = QWidget()
        self.setCentralWidget(root)
        layout = QVBoxLayout(root)
        layout.setContentsMargins(20, 20, 20, 20)
        header = row(QLabel("SMARTNOTCH"), button("Show panel", lambda: self.panel.reveal(True)),
                     button("Appearance", self.show_settings), button("Import…", self.import_text),
                     button("Export…", self.export_text))
        layout.addLayout(header)
        self.editor_tabs = []
        tabs = QHBoxLayout()
        for section in SECTIONS:
            tab = button(section, lambda checked=False, s=section: self.switch_section(s), True)
            tabs.addWidget(tab)
            self.editor_tabs.append(tab)
        tabs.addStretch()
        layout.addLayout(tabs)
        splitter = QSplitter()
        layout.addWidget(splitter, 1)
        sidebar = QWidget()
        side = QVBoxLayout(sidebar)
        self.titles = QListWidget()
        self.titles.currentRowChanged.connect(self.title_row_changed)
        side.addWidget(self.titles, 1)
        side.addLayout(row(button("+ Title", self.add_title), button("Rename", self.rename_title), button("Delete", self.delete_title)))
        splitter.addWidget(sidebar)
        content = QWidget()
        body = QVBoxLayout(content)
        self.card_area = QWidget()
        cards = QVBoxLayout(self.card_area)
        self.card_list = QListWidget()
        self.card_list.setMaximumHeight(180)
        self.card_list.currentRowChanged.connect(self.card_changed)
        cards.addWidget(self.card_list)
        cards.addLayout(row(button("+ Card", self.add_card), button("Delete card", self.delete_card), button("Toggle done", self.toggle_card)))
        body.addWidget(self.card_area)
        from PySide6.QtWidgets import QLineEdit
        self.card_title = QLineEdit()
        self.card_title.setPlaceholderText("Card title")
        self.card_title.textEdited.connect(self.edit_card_title)
        body.addWidget(self.card_title)
        self.text = QPlainTextEdit()
        self.text.setPlaceholderText("Your words go here…")
        self.text.textChanged.connect(self.text_changed)
        body.addWidget(self.text, 1)
        self.card_notes = QPlainTextEdit()
        self.card_notes.setPlaceholderText("Card notes…")
        self.card_notes.setMaximumHeight(130)
        self.card_notes.textChanged.connect(self.card_notes_changed)
        body.addWidget(self.card_notes)
        splitter.addWidget(content)
        splitter.setSizes([290, 710])
        self.notice = QLabel("Ctrl + Alt + P: panel · Space: play/pause · E: editor (while SmartNotch is focused)")
        self.notice.setWordWrap(True)
        layout.addWidget(self.notice)
        if os.environ.get("XDG_SESSION_TYPE") == "wayland":
            label = QLabel("Wayland: panel positioning and staying above other apps depend on your compositor. For the full top-edge behavior, use an X11 session.")
            label.setWordWrap(True)
            layout.addWidget(label)

    def refresh(self):
        self.loading = True
        session = self.session
        for tab, name in zip(self.editor_tabs, SECTIONS):
            tab.setChecked(name == session.section)
        self.titles.clear()
        for title in session.state["titles"]:
            self.titles.addItem(title["title"] or "Untitled")
        self.titles.setCurrentRow(next(i for i, t in enumerate(session.state["titles"]) if t["id"] == session.state["selected"]))
        is_cards = session.section == "Cards"
        self.card_area.setVisible(is_cards)
        self.card_title.setVisible(is_cards)
        self.card_notes.setVisible(is_cards)
        self.card_list.clear()
        for card in session.title["cards"]:
            self.card_list.addItem(("✓ " if card["completed"] else "○ ") + (card["title"] or "Untitled card"))
        if session.card:
            self.card_list.setCurrentRow(session.title["selectedCard"])
        self.sync_editor_text()
        self.loading = False
        self.script = Script(session.title["text"])
        self.panel.refresh()

    def sync_editor_text(self):
        previous = self.loading
        self.loading = True
        session = self.session
        card = session.card
        text = (card["details"] if card else "") if session.section == "Cards" else session.title["text"]
        if self.text.toPlainText() != text:
            self.text.setPlainText(text)
        self.text.setEnabled(session.section != "Cards" or card is not None)
        self.card_title.setText(card["title"] if card else "")
        self.card_notes.setPlainText(card["notes"] if card else "")
        self.card_title.setEnabled(card is not None)
        self.card_notes.setEnabled(card is not None)
        self.loading = previous

    def switch_section(self, section):
        self.pause()
        self.panel.finish_edit(refresh=False)
        self.session.data["section"] = section
        self.refresh()
        self.save_soon()

    def title_row_changed(self, index):
        if not self.loading and index >= 0:
            self.select_title(self.session.state["titles"][index]["id"])

    def select_title(self, identity):
        self.pause()
        self.panel.finish_edit(refresh=False)
        self.session.state["selected"] = identity
        self.refresh()
        self.save_soon()

    def add_title(self):
        name, ok = QInputDialog.getText(self, "New title", "Title:")
        if ok:
            title = new_title(self.session.section, name.strip() or "Untitled")
            self.session.state["titles"].append(title)
            self.select_title(title["id"])

    def rename_title(self):
        name, ok = QInputDialog.getText(self, "Rename title", "Title:", text=self.session.title["title"])
        if ok:
            self.session.title["title"] = name.strip()
            self.refresh()
            self.save_soon()

    def delete_title(self):
        if len(self.session.state["titles"]) < 2:
            QMessageBox.information(self, "Keep one title", "Each section keeps at least one title.")
            return
        if QMessageBox.question(self, "Delete title?", "Delete this title and all of its content?") == QMessageBox.StandardButton.Yes:
            self.session.state["titles"].remove(self.session.title)
            self.select_title(self.session.state["titles"][0]["id"])

    def text_changed(self):
        if self.loading:
            return
        if self.session.section == "Cards":
            if self.session.card:
                self.session.card["details"] = self.text.toPlainText()
        else:
            self.session.title["text"] = self.text.toPlainText()
            if self.session.section == "Read":
                self.pause()
                self.session.title.update(wordIndex=0, wordProgress=0, finished=False)
                self.script = Script(self.session.title["text"])
        self.panel.refresh()
        self.save_soon()

    def card_changed(self, index):
        if not self.loading and index >= 0:
            self.panel.finish_edit(refresh=False)
            self.session.title["selectedCard"] = index
            self.sync_editor_text()
            self.panel.refresh()
            self.save_soon()

    def add_card(self):
        self.session.title["cards"].append(new_card())
        self.session.title["selectedCard"] = len(self.session.title["cards"]) - 1
        self.refresh()
        self.save_soon()

    def delete_card(self):
        if self.session.card and QMessageBox.question(self, "Delete card?", "Delete this card and its notes?") == QMessageBox.StandardButton.Yes:
            self.session.title["cards"].pop(self.session.title["selectedCard"])
            self.session.title["selectedCard"] = max(0, self.session.title["selectedCard"] - 1)
            self.refresh()
            self.save_soon()

    def edit_card_title(self, text):
        if not self.loading and self.session.card:
            self.session.card["title"] = text
            self.card_list.currentItem().setText(("✓ " if self.session.card["completed"] else "○ ") + (text or "Untitled card"))
            self.panel.refresh()
            self.save_soon()

    def card_notes_changed(self):
        if not self.loading and self.session.card:
            self.session.card["notes"] = self.card_notes.toPlainText()
            self.panel.refresh()
            self.save_soon()

    def toggle_card(self):
        if self.session.section == "Cards" and self.session.card:
            self.session.card["completed"] = not self.session.card["completed"]
            self.refresh()
            self.save_soon()

    def navigate(self, forward):
        self.pause()
        if self.session.section == "Read":
            title = self.session.title
            title.update(wordIndex=self.script.paragraph(title["wordIndex"], forward), wordProgress=0, finished=False)
            self.panel.highlight()
        elif self.session.section == "Cards" and self.session.card:
            self.session.title["selectedCard"] = max(0, min(len(self.session.title["cards"]) - 1,
                self.session.title["selectedCard"] + (1 if forward else -1)))
            self.refresh()
        self.save_soon()

    def pause(self):
        self.playing = False
        self.panel.play.setText("Play")

    def toggle_play(self):
        if self.session.section != "Read":
            self.panel.reveal(True)
            return
        if self.session.data["mode"] == "Manual":
            self.panel.reveal(True)
            return
        if self.session.title["finished"]:
            self.restart()
        self.playing = not self.playing and bool(self.script.words)
        self.last_tick = time.monotonic()
        self.panel.play.setText("Pause" if self.playing else "Play")
        self.panel.reveal(True)

    def restart(self):
        self.pause()
        self.session.title.update(wordIndex=0, wordProgress=0, finished=False)
        self.panel.highlight()
        self.save_soon()

    def tick(self):
        now = time.monotonic()
        elapsed = min(.2, now - self.last_tick)
        self.last_tick = now
        if self.playing:
            old = self.session.title["wordIndex"]
            self.script.advance(self.session.title, elapsed, self.session.data["speed"] * self.session.data["rate"])
            if old != self.session.title["wordIndex"] or self.session.title["finished"]:
                self.panel.highlight()
                self.save_soon()
            if self.session.title["finished"]:
                self.pause()
        if self.panel.isVisible() and not self.panel.pinned and not self.panel.editing:
            pointer = QCursor.pos()
            if not self.panel.frameGeometry().contains(pointer) and not self.trigger.frameGeometry().contains(pointer):
                self.panel.dismiss()

    def toggle_panel(self):
        if self.panel.isVisible() and self.panel.pinned:
            self.panel.dismiss()
        else:
            self.panel.reveal(True)

    def show_editor(self):
        self.panel.dismiss()
        self.showNormal()
        self.raise_()
        self.activateWindow()

    def show_settings(self):
        from PySide6.QtWidgets import QDialog, QDialogButtonBox
        self.pause()
        self.panel.pinned = True
        self.panel.pin.setChecked(True)
        dialog = QDialog(self)
        dialog.setWindowTitle(f"{self.session.section} · Appearance")
        dialog.setMinimumWidth(400)
        layout = QFormLayout(dialog)
        appearance = self.session.state["appearance"]
        widgets = {}
        for key, label, low, high in (("fontSize", "Text size", 18, 36), ("width", "Panel width", 420, 760),
                                      ("height", "Panel height", 260, 700), ("transparency", "Background transparency (%)", 0, 100)):
            spin = QSpinBox()
            spin.setRange(low, high)
            spin.setValue(int(appearance[key]))
            layout.addRow(label, spin)
            widgets[key] = spin
        ink = QComboBox()
        ink.addItems(INKS)
        ink.setCurrentText(appearance["ink"])
        layout.addRow("Text color", ink)
        hover = QCheckBox("Open on hover")
        hover.setChecked(bool(appearance["hover"]))
        layout.addRow(hover)
        mode = QComboBox()
        mode.addItems(["Auto-scroll", "Manual"])
        mode.setCurrentText(self.session.data["mode"])
        speed = QSpinBox()
        speed.setRange(60, 240)
        speed.setValue(int(self.session.data["speed"]))
        rate = QDoubleSpinBox()
        rate.setRange(.5, 2)
        rate.setSingleStep(.1)
        rate.setValue(self.session.data["rate"])
        if self.session.section == "Read":
            layout.addRow("Reading mode", mode)
            layout.addRow("Words per minute", speed)
            layout.addRow("Playback speed", rate)
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(dialog.accept)
        buttons.rejected.connect(dialog.reject)
        layout.addRow(buttons)
        if dialog.exec():
            appearance.update({key: widget.value() for key, widget in widgets.items()})
            appearance.update(ink=ink.currentText(), hover=hover.isChecked())
            self.session.data.update(mode=mode.currentText(), speed=speed.value(), rate=rate.value())
            self.panel.refresh()
            self.save_soon()

    def import_text(self):
        filename, _ = QFileDialog.getOpenFileName(self, "Import text", "", "Text and Markdown (*.txt *.md)")
        if not filename:
            return
        try:
            text = Path(filename).read_text(encoding="utf-8-sig")
        except (OSError, UnicodeError) as error:
            QMessageBox.warning(self, "Import failed", str(error))
            return
        if self.session.section == "Cards":
            self.session.title["cards"].extend(new_card(line.strip()) for line in text.splitlines() if line.strip())
        else:
            if self.session.title["text"] and QMessageBox.question(self, "Replace content?", "Replace this title's text with the imported file?") != QMessageBox.StandardButton.Yes:
                return
            self.pause()
            self.session.title.update(text=text, wordIndex=0, wordProgress=0, finished=False)
        self.refresh()
        self.save_soon()

    def export_text(self):
        filename, _ = QFileDialog.getSaveFileName(self, "Export text", "SmartNotch.txt", "Text (*.txt);;Markdown (*.md)")
        if filename:
            text = self.session.title["text"]
            if self.session.section == "Cards":
                text = "\n\n".join(f'{"[x]" if c["completed"] else "[ ]"} {c["title"]}\n{c["details"]}\n{c["notes"]}' for c in self.session.title["cards"])
            try:
                Path(filename).write_text(text, encoding="utf-8")
            except OSError as error:
                QMessageBox.warning(self, "Export failed", str(error))

    def save_soon(self):
        # Do not postpone indefinitely during continuous playback or typing.
        if not self.save_timer.isActive():
            self.save_timer.start(500)

    def save(self):
        try:
            self.session.save()
            self.statusBar().clearMessage()
            return True
        except (OSError, ValueError) as error:
            self.pause()
            self.statusBar().showMessage(f"Could not save: {error}")
            return False

    def closeEvent(self, event):
        if not self.quitting and self.tray.isVisible():
            self.save()
            self.hide()
            event.ignore()
        elif self.save():
            self.timer.stop()
            self.hotkeys.close()
            QApplication.quit()
            event.accept()
        else:
            QMessageBox.warning(self, "Unsaved changes", "SmartNotch could not save your changes. Check the status bar and export your content before quitting.")
            event.ignore()

    def quit(self):
        self.quitting = True
        self.close()
        self.quitting = False


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("SmartNotch")
    app.setOrganizationName("MaheshLabs")
    app.setDesktopFileName("in.maheshmoholkar.smartnotch")
    app.setStyle("Fusion")
    app.setStyleSheet(STYLE)
    app.setQuitOnLastWindowClosed(False)
    try:
        session = Session()
        # Session-scoped lock also protects isolated development sessions.
        session.path.parent.mkdir(parents=True, exist_ok=True)
        lock = QLockFile(str(session.path) + ".lock")
        if not lock.tryLock(0):
            QMessageBox.information(None, "SmartNotch is running", "SmartNotch is already open. Use its tray icon or top-edge tab to open it.")
            return 0
    except (OSError, ValueError) as error:
        QMessageBox.critical(None, "Could not open your workspace", str(error))
        return 1
    workspace = Workspace(session)
    workspace.show()
    app.aboutToQuit.connect(workspace.save)
    return app.exec()
