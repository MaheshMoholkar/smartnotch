#!/bin/zsh
set -eu
cd "${0:A:h}/.."
# The standalone Command Line Tools ship Testing as a framework rather than a
# standard Swift module. Supply those paths when Xcode is not selected.
developer_dir="$(xcode-select -p)"
frameworks="$developer_dir/Library/Developer/Frameworks"
macro="$developer_dir/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ -d "$frameworks/Testing.framework" && -f "$macro" ]]; then
    swift test --build-system native "$@" \
        -Xswiftc "-F$frameworks" \
        -Xswiftc -load-plugin-library -Xswiftc "$macro" \
        -Xlinker -rpath -Xlinker "$frameworks"
else
    swift test "$@"
fi
