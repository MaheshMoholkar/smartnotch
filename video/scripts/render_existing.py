"""Render the existing edit's visuals and copy the original AAC soundtrack intact."""
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT.parent


def main():
    output = ROOT / 'dist/SmartNotch.mp4'
    output.parent.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix='smartnotch-render-', dir=output.parent) as temporary:
        visuals = Path(temporary) / 'visuals.mp4'
        finished = Path(temporary) / 'SmartNotch.mp4'
        subprocess.run([
            str(PROJECT / 'node_modules/.bin/remotion'), 'render', 'src/index.ts',
            'SmartNotch-Edited-Ad', str(visuals), '--codec=h264', '--crf=20',
            '--pixel-format=yuv420p', '--muted'
        ], cwd=PROJECT, check=True)
        subprocess.run([
            'ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(visuals),
            '-i', str(PROJECT / 'public/original-soundtrack.m4a'),
            '-map', '0:v:0', '-map', '1:a:0', '-c', 'copy', '-movflags', '+faststart', str(finished)
        ], check=True)
        finished.replace(output)
    print(f'Exported {output}; original AAC audio copied without re-encoding.')


if __name__ == '__main__':
    main()
