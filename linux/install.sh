#!/bin/sh
# Per-user source installation; scripts and notes live outside the app directory.
set -eu
if [ "$(uname -s)" != Linux ]; then
    echo 'This installer is for Linux. Use the Mac DMG or Windows installer on other systems.' >&2
    exit 1
fi
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"
app_dir="$data_dir/MaheshLabs/SmartNotch/app"
bin_dir="${HOME}/.local/bin"
python_bin=""
for candidate in python3.14 python3.13 python3.12 python3.11 python3.10 python3; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; sys.exit(not ((3, 10) <= sys.version_info[:2] < (3, 15)))'; then
        python_bin="$candidate"
        break
    fi
done
if [ -z "$python_bin" ]; then
    echo 'Install Python 3.10–3.14 with venv support first (Ubuntu/Debian: sudo apt install python3 python3-venv).' >&2
    exit 1
fi
"$python_bin" - <<'PY'
import platform
import sys
machine = platform.machine().lower()
minimum = {'x86_64': (2, 34), 'amd64': (2, 34), 'aarch64': (2, 39), 'arm64': (2, 39)}.get(machine)
libc, version = platform.libc_ver()
if minimum is None:
    sys.exit('This installer supports x86_64 and aarch64 Linux systems only.')
try:
    actual = tuple(map(int, version.split('.')[:2]))
except ValueError:
    actual = ()
if libc != 'glibc' or actual < minimum:
    sys.exit(f'This Qt build requires glibc {minimum[0]}.{minimum[1]} or later on {machine}.')
PY
mkdir -p "$app_dir" "$bin_dir" "$data_dir/applications" "$data_dir/icons/hicolor/256x256/apps"
# Keep the environment at its final path: venv scripts embed absolute paths.
if [ ! -x "$app_dir/.venv/bin/python" ]; then
    "$python_bin" -m venv "$app_dir/.venv" || {
        echo 'Python venv is unavailable. Install python3-venv, then run this installer again.' >&2
        exit 1
    }
fi
"$app_dir/.venv/bin/python" -m pip install --disable-pip-version-check -r "$source_dir/requirements.txt"
cp -R "$source_dir/smartnotch" "$app_dir/"
cp "$source_dir/run.sh" "$source_dir/icon.png" "$source_dir/requirements.txt" "$app_dir/"
chmod +x "$app_dir/run.sh"
# Python quotes paths safely even when the home directory contains spaces or quotes.
"$python_bin" - "$app_dir" "$bin_dir" "$data_dir" <<'PY'
import os
import shlex
import sys
from pathlib import Path
app, binaries, data = map(Path, sys.argv[1:])
launcher = binaries / 'smartnotch'
temporary = launcher.with_suffix('.tmp')
temporary.write_text('#!/bin/sh\nexec ' + shlex.quote(str(app / 'run.sh')) + ' "$@"\n')
temporary.chmod(0o755)
os.replace(temporary, launcher)
# Desktop Exec quoting follows the Desktop Entry specification, not shell syntax.
def quote(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%') + '"'
(data / 'applications/in.maheshmoholkar.smartnotch.desktop').write_text(
    '[Desktop Entry]\nType=Application\nName=SmartNotch\n'
    'Comment=Scripts, cue cards and notes near your camera\n'
    f'Exec={quote(launcher)}\nIcon=in.maheshmoholkar.smartnotch\nTerminal=false\n'
    'Categories=Office;Utility;\nStartupWMClass=SmartNotch\n')
PY
cp "$source_dir/icon.png" "$data_dir/icons/hicolor/256x256/apps/in.maheshmoholkar.smartnotch.png"
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$data_dir/applications" || true
fi
echo 'Installed SmartNotch. Open it from your application menu, or run ~/.local/bin/smartnotch.'
echo 'For top-edge hover and global shortcuts, use an X11 desktop session. See README.md for system libraries.'
