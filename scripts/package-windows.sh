#!/bin/zsh
# Cross-build the Windows installer on macOS/Linux using Velopack's [win] directive.
set -eu
cd "${0:A:h}/.."
runtime="${1:-win-x64}"
case "$runtime" in
    win-x64|win-arm64) ;;
    *) echo 'Use win-x64 or win-arm64.' >&2; exit 1 ;;
esac
python3 scripts/release_config.py validate --require-updates --platform windows
version=$(python3 scripts/release_config.py get version)
root="$PWD"
output="$root/dist/updates/windows/$runtime"
mkdir -p "$output"
publish="$root/dist/windows-publish/$runtime"

echo '[1/4] Preparing Windows installer tools…'
python3 scripts/restore_windows_tools.py

echo '[2/4] Compiling the Windows app…'
dotnet publish windows/SmartNotch/SmartNotch.csproj -c Release -r "$runtime" \
    --self-contained true -o "$publish"
echo '[3/4] Packaging Setup.exe and the update files…'
(
    cd windows
    # The Windows executable cannot run on macOS/Linux to validate startup hooks.
    # App.Main explicitly initializes Velopack before WPF and the instance mutex.
    dotnet tool run vpk -- '[win]' pack --skip-updates \
        --packId SmartNotch --packVersion "$version" \
        --packDir "$publish" --mainExe SmartNotch.exe \
        --packTitle SmartNotch --packAuthors MaheshLabs \
        --runtime "$runtime" --channel win --outputDir "$output" \
        --releaseNotes "$root/RELEASE_NOTES.md" \
        --icon "$root/windows/SmartNotch/SmartNotch.ico" \
        --noPortable --skipVeloAppCheck
)
echo '[4/4] Verifying packages and staging GitHub assets and website feeds…'
python3 scripts/stage_windows_release.py "$runtime"
echo "Windows packages are in $output and dist/github-release/$version; only small feeds go to the website."
echo 'Test installation and an update on Windows before distributing the release.'
