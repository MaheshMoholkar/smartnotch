#!/bin/zsh
set -eu
cd "${0:A:h}/.."

export SMARTNOTCH_DISTRIBUTION=1
./scripts/build.sh "$@"
codesign --verify --strict dist/SmartNotch.app

staging=$(mktemp -d "${TMPDIR:-/tmp}/smartnotch-dmg.XXXXXX")
trap 'rm -rf -- "$staging"' EXIT
mkdir "$staging/volume"
ditto dist/SmartNotch.app "$staging/volume/SmartNotch.app"
ln -s /Applications "$staging/volume/Applications"

hdiutil makehybrid -hfs -hfs-volume-name SmartNotch \
    -o "$staging/SmartNotch-hfs.dmg" "$staging/volume"
hdiutil convert "$staging/SmartNotch-hfs.dmg" -format UDZO -o "$staging/SmartNotch.dmg"
hdiutil verify "$staging/SmartNotch.dmg"
mv -f "$staging/SmartNotch.dmg" dist/SmartNotch.dmg
echo "Packaged $PWD/dist/SmartNotch.dmg"
