# SmartNotch for Windows

SmartNotch for Windows is a native WPF application. It runs on the primary display. Hover over the slim notch at the top center to open the floating panel. Move away to close it. Click the notch to pin or hide the panel, including when hover is disabled. Close the editor to keep SmartNotch in the notification area. Right-click the tray icon to reopen the editor, toggle the panel, or quit.

- **Read** supports Auto-scroll and Manual modes, paragraph navigation, word selection, and a saved position per title.
- **Cards** supports multiple decks, card navigation, completion, and notes.
- **Notes** supports multiple notes and deliberate in-panel editing. Press Escape or Done to finish editing.
- Each section has its own selected title and panel appearance. Import and export plain text or Markdown from the editor. Cards import one card per nonblank line.
- Voice following is deferred for this release.

| Shortcut | Action |
| --- | --- |
| Ctrl + Alt + P | Show or hide the panel |
| Ctrl + Alt + Space | Play, pause, or open the panel |
| Ctrl + Alt + Up / Down | Previous or next paragraph or card |
| Ctrl + Alt + E | Open the editor |

Data stays in `%LOCALAPPDATA%\MaheshLabs\SmartNotch\session.json`. Set `SMARTNOTCH_SESSION_PATH` before launch to test with an isolated session file.

## Install an updater-enabled release

Use the generated **Setup.exe** for your processor: `win-x64` for Intel and AMD PCs or `win-arm64` for ARM-based PCs. The runtime is included. This packaging produces an unsigned build unless signing is configured separately. Windows may show a reputation warning or block it on managed devices.

Use **Check for Updates…** in the editor or notification-area menu. Automatic checks can be disabled from that menu. Background checks show availability without opening a dialog; downloads and restarts require confirmation. Legacy plain ZIP installations need one manual install of an updater-enabled release. Saved content stays in the same directory.

## Build on Windows

You can also build the installer from a Mac with `./scripts/package-windows.sh` in the project root. It downloads dependencies, cross-builds the Windows application, packages Setup.exe, verifies the update files, and stages GitHub Release assets and the small website feed. A Windows machine is still needed for installation and UI testing. See [UPDATES.md](../UPDATES.md).

With the .NET 10 SDK installed, run these commands from the project root in PowerShell:

```powershell
dotnet run --project windows/SmartNotch
./windows/publish.ps1 -Runtime win-x64
./windows/publish.ps1 -Runtime win-arm64
```

Configure `updateBaseURL` in `release.json` before release packaging. The publish script uses the pinned Velopack tool to produce an installer, update packages, feed, and checksums under `dist/updates/windows/<runtime>`. Use `-Development` to inspect packaging before live configuration; these files go under `dist/development`. The **SmartNotch Windows** GitHub Actions workflow builds both architectures and exposes artifacts without publishing them. See [UPDATES.md](../UPDATES.md) for complete download, publication, and verification steps.

Release binaries are staged under `dist/github-release/<version>/`, never `landing/public`. Native packaging uses Python for the same checksum, architecture, and asset-staging checks as cross-packaging. Upload these assets manually to a GitHub Release and configure its URL before deploying the website.
