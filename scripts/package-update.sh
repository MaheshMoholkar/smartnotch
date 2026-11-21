#!/bin/zsh
set -eu
cd "${0:A:h}/.."
python3 scripts/release_config.py validate --require-updates
version=$(python3 scripts/release_config.py get version)
output="$PWD/dist/updates/mac"
mkdir -p "$output"
archive="$output/SmartNotch-$version.dmg"
[[ ! -e "$archive" ]] || { echo "Version $version already exists; increment version and build in release.json." >&2; exit 1; }
./scripts/package-dmg.sh "$@"

if [[ -n "${SMARTNOTCH_NOTARY_PROFILE:-}" ]]; then
    # Staple before signing the archive for Sparkle; later byte changes invalidate it.
    xcrun notarytool submit dist/SmartNotch.dmg --keychain-profile "$SMARTNOTCH_NOTARY_PROFILE" --wait
    xcrun stapler staple dist/SmartNotch.dmg
fi
tools=(.build/artifacts/**/bin/sign_update(N))
[[ ${#tools} == 1 ]] || { echo 'Cannot locate Sparkle sign_update; resolve the Sparkle package first.' >&2; exit 1; }
signature=$(mktemp "${TMPDIR:-/tmp}/smartnotch-signature.XXXXXX")
completed=0
trap 'rm -f -- "$signature"; if [[ "$completed" == 0 ]]; then rm -f -- "$archive"; fi' EXIT
cp dist/SmartNotch.dmg "$archive"
"${tools[1]}" "$archive" > "$signature"
python3 scripts/make_appcast.py "$archive" "$signature" "$output/appcast.xml"
completed=1
python3 scripts/sync_site_downloads.py
echo "Upload binaries from dist/github-release/$version to GitHub Releases. Keep the small appcast.xml on Vercel."
