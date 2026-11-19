#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
mkdir -p work/module-cache dist
app="$PWD/dist/Burp2Magisk.app"
mkdir -p "$app/Contents/MacOS"
# Remove stale resources left by previous versions of this build.
rm -rf "$app/Contents/Resources"
mkdir -p "$app/Contents/Resources"
sources=()
while IFS= read -r source; do sources+=("$source"); done < <(find Sources -name '*.swift' -type f | sort)
/usr/bin/swiftc "${sources[@]}" -O -target "arm64-apple-macos12.0" \
  -module-cache-path "$PWD/work/module-cache" -framework Cocoa \
  -o "$app/Contents/MacOS/Burp2Magisk"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/*.sh "$app/Contents/Resources/"
mkdir -p "$app/Contents/Resources/ModuleTemplate"
cp -R Resources/ModuleTemplate/. "$app/Contents/Resources/ModuleTemplate/"
cp Resources/Burp2Magisk.icns Resources/Burp2Magisk.png Resources/Burp2MagiskGlyph.png "$app/Contents/Resources/"
/usr/bin/codesign --force --deep --sign - "$app"
/usr/bin/codesign --verify --deep "$app"
/usr/bin/ditto -c -k --keepParent "$app" "$PWD/dist/Burp2Magisk-macOS.zip"
echo "Built: $app"
