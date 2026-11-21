#!/bin/zsh
set -eu
cd "${0:A:h}"
if [[ ! -x dist/SmartNotch.app/Contents/MacOS/SmartNotch ]]; then
    ./scripts/build.sh
fi
open dist/SmartNotch.app
