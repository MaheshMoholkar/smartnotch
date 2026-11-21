#!/bin/zsh
set -eu
cd "${0:A:h}/.."

if [[ "${SMARTNOTCH_DISTRIBUTION:-0}" == 1 ]]; then
    [[ "${SMARTNOTCH_NO_UPDATER:-0}" != 1 ]] || { echo 'Release builds must include Sparkle.' >&2; exit 1; }
    python3 scripts/release_config.py validate --require-updates
else
    python3 scripts/release_config.py validate
fi
swift build --build-system native -c release "$@"

mkdir -p dist
staging=$(mktemp -d "$PWD/dist/smartnotch-build.XXXXXX")
trap 'rm -rf -- "$staging"' EXIT
bundle="$staging/SmartNotch.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
if [[ ! -f Assets/AppIcon.icns || scripts/make-icon.swift -nt Assets/AppIcon.icns || Assets/SmartNotchLogo.png -nt Assets/AppIcon.icns ]]; then
    swift scripts/make-icon.swift Assets/SmartNotchLogo.png Assets/AppIcon.iconset
    iconutil -c icns Assets/AppIcon.iconset -o Assets/AppIcon.icns
fi
cp Assets/AppIcon.icns "$bundle/Contents/Resources/AppIcon.icns"
cp Assets/SmartNotchLogo.png "$bundle/Contents/Resources/SmartNotchLogo.png"
cp .build/release/SmartNotch "$bundle/Contents/MacOS/SmartNotch"
python3 scripts/release_config.py mac-plist "$bundle/Contents/Info.plist"

if [[ "${SMARTNOTCH_NO_UPDATER:-0}" != 1 ]]; then
    frameworks=(.build/artifacts/**/Sparkle.xcframework/macos-*/Sparkle.framework(N))
    [[ ${#frameworks} == 1 ]] || { echo 'Expected one Sparkle macOS framework in .build/artifacts.' >&2; exit 1; }
    mkdir -p "$bundle/Contents/Frameworks"
    ditto "${frameworks[1]}" "$bundle/Contents/Frameworks/Sparkle.framework"
    if [[ -n "${SMARTNOTCH_SIGNING_IDENTITY:-}" ]]; then
        framework="$bundle/Contents/Frameworks/Sparkle.framework"
        # Sign inside out, preserving Sparkle's helper entitlements.
        for component in "$framework/Versions/B/XPCServices/Installer.xpc" \
                         "$framework/Versions/B/XPCServices/Downloader.xpc" \
                         "$framework/Versions/B/Autoupdate" \
                         "$framework/Versions/B/Updater.app" "$framework"; do
            codesign --force --options runtime --timestamp --preserve-metadata=entitlements \
                --sign "$SMARTNOTCH_SIGNING_IDENTITY" "$component"
        done
    fi
else
    # Offline development builds must never advertise a working updater.
    /usr/libexec/PlistBuddy -c 'Delete :SUFeedURL' "$bundle/Contents/Info.plist" 2>/dev/null || true
fi

if [[ -n "${SMARTNOTCH_SIGNING_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SMARTNOTCH_SIGNING_IDENTITY" "$bundle"
else
    codesign --force --sign - "$bundle"
fi
codesign --verify --deep --strict "$bundle"
# Replace only after a successful build and bundle verification.
rm -rf dist/SmartNotch.app
mv "$bundle" dist/SmartNotch.app
echo "Built $PWD/dist/SmartNotch.app"
