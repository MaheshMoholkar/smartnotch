# SmartNotch for Linux (preview)

A Qt 6 desktop app with the same Read, Cards, and Notes workspaces as the Mac and Windows editions. It saves scripts, decks, notes, reading position, and per-section appearance locally. No account is required.

## Install

Download **SmartNotch-Linux.tar.gz**, extract it, open a terminal in the extracted folder, and run:

```sh
sh ./install.sh
```

Open **SmartNotch** from your application menu. The installer runs without sudo and installs the app for your user. The first installation needs internet access to download Qt. Python **3.10–3.14**, pip, and venv support are required; after setup the app works offline. This download is a source installer, not an AppImage or a bundled native binary. The [pinned Qt wheels](https://pypi.org/project/PySide6-Essentials/6.10.2/#files) require glibc **2.34+ on x86_64**, or **2.39+ on aarch64**. Other CPU architectures and musl-based distributions are not supported by this installer.

On Ubuntu 24.04 or later (x64/ARM64), or Debian 12 or later (x64), install the runtime libraries if needed:

```sh
sudo apt install python3 python3-venv libegl1 libgl1 libxkbcommon-x11-0 libxcb-cursor0 libxcb-icccm4 libxcb-keysyms1 libxcb-shape0 libxcb-xinerama0 libxcb-render-util0
```

On other distributions, install the equivalent Qt X11/XCB runtime libraries. The preview has not yet been tested on physical Linux desktops.

## Desktop behavior

Use an **X11 desktop session** for top-center positioning, hover opening, and global shortcuts. The slim tab appears at the top of the primary screen's available work area, below any desktop bar. Hover to open; move away to close and pause. Pin keeps the panel open. Click the tab to pin or hide it. Closing the editor keeps the app in the tray when the desktop supports tray icons; otherwise closing exits. Quit is always available from the tray menu.

On **Wayland**, the editor works, but the compositor controls positioning and whether floating windows stay above other applications. Global shortcuts fall back to working while SmartNotch is focused. XWayland does not guarantee full X11 desktop behavior. Desktop-specific rules or an X11 session may be needed. Full-screen apps and screen sharing require real desktop validation. The panel is visible to screen capture.

| Shortcut | Action |
| --- | --- |
| Ctrl + Alt + P | Show or hide panel |
| Ctrl + Alt + Space | Read: play/pause; Cards/Notes: open panel |
| Ctrl + Alt + Up / Down | Previous/next paragraph or card |
| Ctrl + Alt + E | Open editor |
| Left / Right in Cards panel | Previous/next card |
| Space in Cards panel | Toggle completion |
| Escape while editing panel notes | Finish editing |

On X11, conflicts disable global registration and show a message in the editor. Disable conflicting shortcuts in your desktop settings and restart SmartNotch to retry. Global shortcut lock-mask handling assumes the usual X11 Mod1=Alt and Mod2=Num Lock mapping.

Read supports Auto-scroll (60–240 WPM, 0.5×–2×) and Manual modes, paragraph navigation, clickable words, restart, and saved progress. Voice following is available on Mac only. Each section has independent titles and appearance. Use **Appearance** or **Configure** for font size, text color, panel dimensions, background transparency, and hover behavior. Drag the bottom-right grip to resize.

Cards have titles, details, notes, and completion. **Edit notes** explicitly enables typing in the floating panel and pins it. Notes work the same way. Deleting titles or cards requires confirmation. Every section keeps at least one title. Import/export accepts UTF-8 `.txt` and `.md`; Cards imports append one new card per nonblank line and exports include details, notes, and completion markers.

## Data and updates

Data: `${XDG_DATA_HOME:-~/.local/share}/MaheshLabs/SmartNotch/session.json`. `SMARTNOTCH_SESSION_PATH` selects a separate session for development. Writes are atomic and only one app instance can open a session at a time. Invalid sessions are left intact and reported at startup.

Linux updates are manual: quit SmartNotch, download the newer archive, and run its installer again. Your session lives outside the app directory and is preserved. Linux does not use Sparkle or Velopack and does not advertise in-app updates.

To uninstall, remove `~/.local/bin/smartnotch`, the `app` subfolder in the data directory above, `$XDG_DATA_HOME/applications/in.maheshmoholkar.smartnotch.desktop`, and `$XDG_DATA_HOME/icons/hicolor/256x256/apps/in.maheshmoholkar.smartnotch.png` (default XDG data directory: `~/.local/share`). Keep `session.json` to preserve your content.

## Development and packages

```sh
python3.13 -m venv /tmp/smartnotch-venv
/tmp/smartnotch-venv/bin/pip install -r linux/requirements.txt
cd linux
/tmp/smartnotch-venv/bin/python -m smartnotch
```

From the project root:

```sh
python3 -m unittest discover -s linux/tests -v
python3 scripts/package_linux.py
```

Packaging produces and stages the source installer archive plus a SHA-256 checksum in the website assets. CI additionally installs Qt, runs GUI interaction tests under Xvfb on Ubuntu, and builds a portable binary bundle with PyInstaller. Native bundles must be built on Linux; the Mac cannot produce or verify a Linux executable. Qt and PySide are third-party dependencies under their respective licenses; their wheels include license notices. Source installers keep Qt as an independently installed dependency in the app's virtual environment.
