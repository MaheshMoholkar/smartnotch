#!/bin/zsh
# Run in your own Terminal so macOS can ask for Keychain permission.
set -eu
cd "${0:A:h}/.."
unset SMARTNOTCH_NO_UPDATER
swift package resolve
tools=(.build/artifacts/**/bin/generate_keys(N))
[[ ${#tools} == 1 ]] || { echo 'Expected one Sparkle generate_keys tool.' >&2; exit 1; }
"${tools[1]}"
public_key=$("${tools[1]}" -p)
python3 - "$public_key" <<'PY'
import json
import sys
from pathlib import Path
sys.path.insert(0, 'scripts')
from release_config import validate
file = Path('release.json')
config = json.loads(file.read_text())
config['sparklePublicKey'] = sys.argv[1].strip()
validate(config, require_updates=True)
file.write_text(json.dumps(config, indent=2) + '\n')
print('Saved the public key. The private key remains in Keychain.')
PY
./scripts/package-update.sh
echo 'Mac assets are ready in dist/github-release. Prepare other platforms, upload the assets to a GitHub Release, then configure its URL before deploying landing/ yourself.'
