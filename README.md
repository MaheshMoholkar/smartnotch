# SmartNotch

A local desktop workspace for reading aloud, stepping through cards, and taking notes. Available for Mac and Windows, with a Linux preview. The Mac edition requires macOS 14 or later; building it requires Swift 6.2 or later.

To install on an Apple silicon Mac, open **SmartNotch.dmg** and drag SmartNotch into Applications. If macOS blocks the first launch, go to **System Settings → Privacy & Security → Open Anyway**. Content and preferences save automatically on this Mac.

## Read · Cards · Notes

Choose a section using the pills below SmartNotch in the editor sidebar, or the tabs in the floating popup. Narrow popups use a labeled section menu. Each section has its own title list, selected title, and appearance settings; switching sections pauses reading and restores that section's previous selection.

**Read** contains continuous text for the teleprompter. Each title remembers its active word and completion state, including after reopening the app. Editing reading content or pressing Restart resets only that title. Renaming a title preserves its position. Playback stops at the end of the selected title.

**Cards** contains separate decks of talking points, questions, steps, or reminders. Add cards in the editor and give each a title, details, and optional notes. Use previous/next buttons in the popup, or click the counter to expand a card picker. Click the completion circle to mark an item done. With the card list or popup focused, arrow keys navigate cards; Space in the popup toggles completion. Arrow keys inside a text field continue to edit text normally. Deleting a card requires confirmation.

**Notes** contains independent free-form notes. Prepare them in the editor, or open them in the popup. Choose **Edit notes** to deliberately enable typing; the popup pins itself during editing. Done or Escape ends editing and releases keyboard focus. Card notes use the same explicit editing behavior. Notes and Cards do not start playback, microphone capture, or speech recognition.

The sidebar's + creates a title in the selected section. Hover a title to reveal its trash button; deletion requires confirmation, and each section retains at least one title. Empty titles show no content hint.

Existing reading titles stay in Read. Data from the earlier shared-tab layout is separated into Read, Cards, and Notes without losing text, card IDs, notes, or reading position.

## Floating popup

Hover over the physical camera notch, including the top screen edge, to open the popup. Only the notch triggers it, independent of popup width. On displays without a notch, a small hover strip is used. Opening and closing are immediate.

Moving away closes an unpinned popup and pauses reading. Pin keeps it open. Hiding preserves reading position; reopening stays paused. Show panel opens and pins it. Opening the editor dismisses the popup first.

Configure uses the gear on the left; the selected section's title list is on the right. Reading and card navigation occupy the center. Configure and title lists have separate open states in each section. Expanded controls extend downward, preserving the content area whenever screen space allows. The reading area, card content, and lists scroll independently under the pointer.

Configure contains font size (18–36 pt), text color (White, Gray, Cyan, Yellow), width (Narrow 420, Normal 580, Wide 680), and transparency. Reading mode and playback speed appear only in Read. Buttons use available width and wrap on narrow panels; transparency occupies a separate full-width row.

The popup uses a stable charcoal background across focus changes. Transparency fades the background and border while preserving foreground content. At 100%, the background disappears while scrolling remains available. The editor uses matching charcoal surfaces. Settings opens a modal with the preview and appearance controls on the left and section-specific controls on the right.

Drag the bottom grip to resize from 220–700 points; double-click resets it to 300. Size, width, color, transparency, and open-on-hover settings are remembered independently for each section. Buttons use pointing-hand cursors, text editors use the text cursor, and the resize grip uses grab-hand cursors.

## Reading modes and shortcuts

Auto-scroll advances at 60–240 WPM multiplied by 0.5×–2× playback speed. Manual mode leaves navigation to you. Voice mode uses Apple's on-device recognition in English (US), English (India), or Hindi (India). Permissions are requested only when starting Voice mode; unsupported offline recognition reports an error without uploading audio.

Previous/Next in Read navigate paragraphs separated by line breaks. Clicking a word makes it active. The current word has a rounded, color-matched underline. Long voice sessions, microphone switching, mixed languages, full-screen behavior, and meeting-app coexistence still need real recording validation.

| Shortcut | Action |
| --- | --- |
| Control + Option + Space | Read: play/pause; Cards/Notes: open popup |
| Control + Option + ↑ / ↓ | Read: previous/next paragraph; Cards: previous/next card |
| Control + Option + P | Show/hide popup |
| Command + 1 | Open editor |
| Arrow keys, when Cards popup has focus | Previous/next card |
| Space, when Cards popup has focus | Toggle card completion |
| Escape, during popup note editing | Finish editing |

Shortcuts report conflicts when another application owns them. Quit getcta while using SmartNotch because some shortcuts overlap.

## Import, export, and local data

Import and Export operate on the selected section. Read and Notes accept UTF-8 `.txt` or `.md` and replace the selected content. Cards import one new card per non-empty line, appending to the deck. Card exports include titles, details, notes, and completion markers as plain text.

Local data: `~/Library/Application Support/MaheshLabs/SmartNotch/session.json`. No account is required. Configured release builds contact the update host to check for and download updates; scripts, cards, and notes remain local. Voice never falls back to server recognition. By default the app is locally signed and is not notarized for distribution.

The popup is not guaranteed to be hidden from screen capture. Share an intended application window or tab and check the result from a receiving device. Apple's documentation describes `NSWindow.SharingType.none` as a legacy constant that macOS no longer uses: <https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum>.

## Windows

See the [Windows project](windows/README.md) for supported features and portable build instructions.

## Linux preview

See the [Linux project](linux/README.md) for the Qt desktop app, source installer, X11 and Wayland compatibility, shortcuts, and build instructions. Read, Cards, Notes, local saving, and per-section appearance are supported. Voice following remains Mac-only; Linux updates are manual.

Run `python3 scripts/package_linux.py` to create `dist/linux/SmartNotch-Linux.tar.gz` and stage the verified source installer and SHA-256 checksum under `dist/github-release/<version>/`. The landing page receives download metadata and a small checksum file only. Python 3.10–3.14 and internet access are needed during installation. The Linux CI workflow tests the GUI under Xvfb and builds an additional native x64 portable artifact on Ubuntu.

## Source repository and downloads

This is one monorepo. Keep the following source together in a single public GitHub repository:

| Path | Purpose |
| --- | --- |
| `Sources/`, `Tests/`, `Package.swift`, `Assets/` | Swift macOS app and tests |
| `windows/` | .NET/WPF Windows app and Velopack packaging |
| `linux/` | Python/PySide6 Linux preview and source installer |
| `landing/` | Next.js website, small update feeds, release routing registry |
| `scripts/`, `.github/`, `release.json` | Shared packaging, verification, and CI |

Installers and archives belong in **GitHub Releases**, not source commits or Vercel uploads. Existing local binaries are preserved under `dist/website-downloads/`, and upload-ready copies are under `dist/github-release/0.2.0/`. Both are ignored by Git. Website builds reject bundled release binaries.

The original `landing/.git` contains no commits or remotes. Its metadata was backed up under `dist/repository-backups/`. Run `zsh scripts/prepare-source-repository.sh` once in your Terminal to move that metadata to the root; the script refuses to overwrite an existing root repository. See [UPDATES.md](UPDATES.md) for manual GitHub setup and release publishing. Set the Vercel project's Root Directory to `landing`; deploy it yourself after the release URLs are configured.

## Development

```sh
./scripts/test.sh
./scripts/build.sh
./scripts/package-dmg.sh
```

The packaging script builds the app and writes the drag-to-Applications image to `dist/SmartNotch.dmg`.

## In-app updates

Mac uses Sparkle; Windows uses Velopack. Both expose **Check for Updates…** and an automatic-check preference. Mac uses Sparkle’s update window; Windows shows background availability in the editor and lets users download, then choose when to restart. Failed downloads leave the running version intact. Updates save pending content before restarting. Data directories and the Mac bundle identifier are unchanged.

The update host is configured as `https://smartnotch.vercel.app/updates`, and the Mac public key is configured. The floating panel and editor show an **Update available** button when a newer version is detected. Distribution packaging fails early if required configuration is missing. Verified installers and update packages are staged under `dist/github-release/<version>/` for manual GitHub Release uploads. Vercel serves the website and small update feeds; compatibility redirects preserve existing app-update URLs.

Run `./scripts/package-windows.sh` to cross-build the Windows x64 installer from this Mac, or pass `win-arm64` for ARM64. After checksum and architecture verification, the command stages GitHub release assets and copies only the small update feed to the landing page. Windows is required to test installation and UI behavior, but not to create the package.

See [UPDATES.md](UPDATES.md) for dependency downloads, Keychain signing-key setup, packaging, publication, and an end-to-end verification checklist. Existing 0.1.0 installations require one manual install of an updater-enabled release.

`SMARTNOTCH_SESSION_PATH` optionally selects a separate local session for development checks. Isolated development sessions keep the editor open so pointer automation can inspect it; normal sessions retain the editor's existing hide-on-mouse-leave behavior.

## Product film

The existing 20-second product ad lives in `video/`. Its sequence, captions, cut timing, and original soundtrack are retained; recorded footage is replaced with animated app mockups. Run `npm --prefix video run preview` to review it, or `npm --prefix video run studio` to edit the Remotion timeline. See [video/README.md](video/README.md) for the storyboard and export commands. Video source and generated bundles stay outside the Vercel `landing/` project.
