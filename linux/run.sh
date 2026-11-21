#!/bin/sh
set -eu
app_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -x "$app_dir/.venv/bin/python" ]; then
    cd "$app_dir"
    exec "$app_dir/.venv/bin/python" -m smartnotch "$@"
fi
echo 'Run ./install.sh first to install SmartNotch and its desktop launcher.' >&2
exit 1
