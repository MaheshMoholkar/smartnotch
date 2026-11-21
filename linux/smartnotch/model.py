"""Local session storage and reading transport, independent of the GUI."""
import json
import math
import os
import re
import tempfile
import uuid
from pathlib import Path

SECTIONS = ("Read", "Cards", "Notes")
WELCOME = "Welcome to SmartNotch.\n\nHover over the tab at the top center of your screen. Pin the panel to keep your words in view.\n\nUse Read for scripts, Cards for talking points, and Notes for anything you want to keep close."


def identifier():
    return str(uuid.uuid4())


def number(value, fallback, low, high):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        return fallback
    return max(low, min(high, value))


def new_title(section, name="Title 1"):
    return dict(id=identifier(), title=name, text="", cards=[], selectedCard=0,
                wordIndex=0, wordProgress=0.0, finished=False)


def new_card(title="New card", details="", notes="", completed=False):
    return dict(id=identifier(), title=title, details=details, notes=notes, completed=completed)


class Session:
    def __init__(self, path=None):
        data_home = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
        self.path = Path(path or os.environ.get("SMARTNOTCH_SESSION_PATH") or
                         data_home / "MaheshLabs/SmartNotch/session.json")
        self.data = dict(schemaVersion=1, section="Read", mode="Auto-scroll", speed=150,
                         rate=1.0, sections={})
        if self.path.exists():
            loaded = json.loads(self.path.read_text(encoding="utf-8"))
            if not isinstance(loaded, dict) or loaded.get("schemaVersion") != 1:
                raise ValueError("Unsupported session format. The original file has been preserved.")
            self.data.update(loaded)
        if self.data.get("section") not in SECTIONS:
            self.data["section"] = "Read"
        if self.data.get("mode") not in ("Auto-scroll", "Manual"):
            self.data["mode"] = "Auto-scroll"
        for key, default, low, high in (("speed", 150, 60, 240), ("rate", 1, .5, 2)):
            self.data[key] = number(self.data.get(key), default, low, high)
        if not isinstance(self.data.get("sections"), dict):
            raise ValueError("Invalid session sections. The original file has been preserved.")
        for section in SECTIONS:
            state = self.data["sections"].setdefault(section, {})
            if not isinstance(state, dict):
                raise ValueError(f"Invalid {section} data. The original file has been preserved.")
            titles = state.setdefault("titles", [])
            if not isinstance(titles, list) or any(not isinstance(t, dict) for t in titles):
                raise ValueError("Invalid title data. The original file has been preserved.")
            if not titles:
                title = new_title(section)
                if section == "Read":
                    title["text"] = WELCOME
                titles.append(title)
            for title in titles:
                defaults = new_title(section)
                for key, default in defaults.items():
                    title.setdefault(key, default)
                for key in ("id", "title", "text"):
                    if not isinstance(title[key], str):
                        raise ValueError("Invalid title text. The original file has been preserved.")
                if not isinstance(title["cards"], list):
                    raise ValueError("Invalid card list. The original file has been preserved.")
                for card in title["cards"]:
                    if not isinstance(card, dict):
                        raise ValueError("Invalid card. The original file has been preserved.")
                    for key, default in new_card().items():
                        card.setdefault(key, default)
                    if any(not isinstance(card[k], str) for k in ("id", "title", "details", "notes")):
                        raise ValueError("Invalid card text. The original file has been preserved.")
                title["selectedCard"] = int(number(title["selectedCard"], 0, 0, max(0, len(title["cards"]) - 1)))
                count = len(re.findall(r"\S+", title["text"]))
                title["wordIndex"] = int(number(title["wordIndex"], 0, 0, max(0, count - 1)))
                title["wordProgress"] = number(title["wordProgress"], 0, 0, .999999)
            if state.get("selected") not in [t["id"] for t in titles]:
                state["selected"] = titles[0]["id"]
            appearance = state.setdefault("appearance", {})
            if not isinstance(appearance, dict):
                raise ValueError("Invalid appearance settings. The original file has been preserved.")
            for key, default, low, high in (("fontSize", 24, 18, 36), ("width", 580, 420, 760),
                                          ("height", 340, 260, 700), ("transparency", 0, 0, 100)):
                appearance[key] = number(appearance.get(key), default, low, high)
            appearance.setdefault("ink", "Soft cyan")
            appearance.setdefault("hover", True)

    @property
    def section(self):
        return self.data["section"]

    @property
    def state(self):
        return self.data["sections"][self.section]

    @property
    def title(self):
        return next(t for t in self.state["titles"] if t["id"] == self.state["selected"])

    @property
    def card(self):
        cards = self.title["cards"]
        return cards[self.title["selectedCard"]] if cards else None

    def save(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        descriptor, temporary = tempfile.mkstemp(prefix=".session-", dir=self.path.parent)
        try:
            with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
                json.dump(self.data, stream, indent=2, ensure_ascii=False, allow_nan=False)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, self.path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


class Script:
    def __init__(self, text):
        self.text = text
        self.words = list(re.finditer(r"\S+", text))

    def paragraph(self, current, forward):
        current = max(0, min(current, len(self.words) - 1))
        for index in range(current + 1 if forward else current - 1,
                           len(self.words) if forward else 0, 1 if forward else -1):
            between = self.text[self.words[index - 1].end():self.words[index].start()]
            if any(c in between for c in "\n\r\u2029"):
                return index
        return current if forward else 0

    def advance(self, title, elapsed, wpm):
        if not self.words or title["finished"]:
            return
        progress = title["wordProgress"] + max(0, elapsed) * wpm / 60
        whole = int(progress)
        index = title["wordIndex"] + whole
        title["wordIndex"] = min(index, len(self.words) - 1)
        title["finished"] = index >= len(self.words)
        title["wordProgress"] = 0 if title["finished"] else progress - whole
