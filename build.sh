#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
mkdir -p work/module-cache dist
app="$PWD/dist/Burp2Magisk.app"
mkdir -p "$app/Contents/MacOS"
# Remove stale resources left by previous versions of this build.
rm -rf "$app/Contents/Resources"
mkdir -p "$app/Contents/Resources"
for arch in arm64 x86_64; do
  /usr/bin/swiftc Sources/main.swift -O -target "$arch-apple-macos12.0" \
    -module-cache-path "$PWD/work/module-cache" -framework Cocoa \
    -o "work/Burp2Magisk-$arch"
done
/usr/bin/lipo -create work/Burp2Magisk-arm64 work/Burp2Magisk-x86_64 -output "$app/Contents/MacOS/Burp2Magisk"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/*.sh "$app/Contents/Resources/"
mkdir -p "$app/Contents/Resources/ModuleTemplate"
cp -R Resources/ModuleTemplate/. "$app/Contents/Resources/ModuleTemplate/"
/usr/bin/codesign --force --deep --sign - "$app"
/usr/bin/codesign --verify --deep "$app"
/usr/bin/ditto -c -k --keepParent "$app" "$PWD/dist/Burp2Magisk-macOS.zip"
echo "Built: $app"
