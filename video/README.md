# Existing SmartNotch ad — mockup footage edit

This edits the original published 20-second ad. Its eight sections, cut frames, copy, camera zooms, montage layout, and soundtrack are retained. Titles, benefit captions, and the closing card use a dark olive background, warm white text, and mint serif emphasis to match the hero mockups. The ten recorded-video nodes are replaced with React/SVG app mockups styled like the website hero.

| Frames | Time | Original section |
| --- | --- | --- |
| 0–99 | 0–3.33s | Hover over the notch; popup appears |
| 100–173 | 3.33–5.8s | A cue from your notch. |
| 174–239 | 5.8–8s | Keep your words near the camera. |
| 240–266 | 8–8.9s | What will you ask next? |
| 267–356 | 8.9–11.9s | Podcasts, interviews, the next question |
| 357–440 | 11.9–14.7s | Catch the action item. Keep going. |
| 441–518 | 14.7–17.3s | Original six-tile moving montage |
| 519–599 | 17.3–20s | SmartNotch. Read. Cards. Notes. Free. No subscription. |

`reference/OriginalAd.tsx.txt` retains the original source for comparison. `src/ExistingAd.tsx` is the active edit, and `src/FakeCapture.tsx` supplies the replacement footage. It generates the desktop, hover cursor, popup, script highlighting, question changes, and note typing; none of these are screen recordings.

`public/original-soundtrack.m4a` contains the exact AAC stream from the original published film. The export script copies that stream into the corrected video without re-encoding, retiming, or adding music.

## Preview and edit

```sh
cd /Users/mahesh/portfolio/smartnotch/video
npm install
npm run preview
```

The review player includes jump buttons for all eight sections. `npm run studio` opens the full Remotion timeline when native file watchers are available; choose `SmartNotch-Edited-Ad`. The preview player avoids file watchers if Studio cannot start.

## Verify, export, and stage

```sh
npm run check
npm run bundle
npm run render
npm run stage:website
npm --prefix ../landing run build
npm --prefix ../landing run check:release
```

The final output is `../dist/SmartNotch.mp4` (20 seconds, 1920×1080, 30 fps). Rendering replaces this file only after the export succeeds and automatically removes its temporary visuals. `npm run stage:website` verifies it, preserves the current website film/poster outside `landing/public`, writes a streaming copy, and extracts a matching poster. Staging intermediates are also removed automatically. Neither command pushes source or deploys Vercel. Installers remain separate GitHub Release assets.
