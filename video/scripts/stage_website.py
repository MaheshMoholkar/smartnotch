"""Verify the exported ad and stage a streaming copy and matching website poster."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    master = ROOT / 'dist/SmartNotch.mp4'
    if not master.is_file():
        raise SystemExit('Export the ad with npm run render before staging the website.')
    info = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(master)
    ]))
    video = next(stream for stream in info['streams'] if stream['codec_type'] == 'video')
    audio = next((stream for stream in info['streams'] if stream['codec_type'] == 'audio'), None)
    if (video['codec_name'] != 'h264' or video['width'] != 1920 or video['height'] != 1080
            or video['r_frame_rate'] != '30/1' or video['pix_fmt'] != 'yuv420p'
            or abs(float(info['format']['duration']) - 20) > 0.05 or audio is None):
        raise SystemExit('Expected the complete 20-second, 1080p30 H.264 ad with audio.')
    with TemporaryDirectory(prefix='smartnotch-stage-', dir=master.parent) as temporary:
        stage(master, Path(temporary))


def stage(master, output):
    movie = output / 'smartnotch-web.mp4'
    poster = output / 'film-poster.jpg'
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(master),
                    '-map', '0:v:0', '-map', '0:a:0', '-c', 'copy', '-movflags', '+faststart', str(movie)], check=True)
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-ss', '6.5', '-i', str(master),
                    '-vf', 'scale=1280:720', '-frames:v', '1', '-q:v', '3', str(poster)], check=True)
    if movie.stat().st_size > 10 * 1024 * 1024:
        raise SystemExit('The website video exceeds the 10 MiB asset budget; encode a smaller copy first.')
    public = ROOT / 'landing/public/assets'
    old = public / 'smartnotch.mp4'
    backup = ROOT / 'dist/ad-backups' / (digest(old)[:12] if old.exists() else 'before-first-ad')
    backup.mkdir(parents=True, exist_ok=True)
    for name in ('smartnotch.mp4', 'film-poster.jpg'):
        current = public / name
        if current.exists() and not (backup / name).exists():
            shutil.copy2(current, backup / name)
    for source, name in ((movie, 'smartnotch.mp4'), (poster, 'film-poster.jpg')):
        target = public / name
        temporary = target.with_name(target.name + '.tmp')
        shutil.copy2(source, temporary)
        temporary.replace(target)
    print(f'Staged {movie.stat().st_size / 1024**2:.2f} MiB website ad and matching poster.')
    print(f'Previous film and poster preserved in {backup}')


if __name__ == '__main__':
    main()
