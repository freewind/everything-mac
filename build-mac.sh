#!/usr/bin/env bash
#
# Build Everything-Mac for Intel Macs (x86_64) and package it as a DMG.
#
# Why this script exists:
#   The published release is arm64-only, so it will not run on an Intel Mac.
#   Xcode cannot be used here either: `xcodebuild` and `actool` both crash with
#   SIGBUS on this machine (a broken dyld shared-cache page), so the project is
#   built with SwiftPM instead. `swift build` compiles the IndexCore library and
#   the EverythingMac executable; this script then assembles the .app bundle by
#   hand (Info.plist, icon, ad-hoc signature) and packs it into a DMG.
#
# Usage: ./build-mac.sh   →   prints the built .app and .dmg paths.
set -euo pipefail

cd "$(dirname "$0")"

ARCH="x86_64"
OUT=".build/bundle"
APP="$OUT/EverythingMac.app"
DMG="EverythingMac-intel.dmg"

# Version numbers come from App/project.yml so the Xcode build and this build
# never drift apart.
MARKETING_VERSION="$(awk -F'"' '/MARKETING_VERSION:/{print $2}' App/project.yml)"
BUILD_VERSION="$(awk -F'"' '/CURRENT_PROJECT_VERSION:/{print $2}' App/project.yml)"
BUNDLE_ID="$(awk -F': *' '/PRODUCT_BUNDLE_IDENTIFIER:/{print $2}' App/project.yml)"

echo "Building EverythingMac $MARKETING_VERSION ($BUILD_VERSION) for $ARCH..."
swift build -c release --arch "$ARCH"
BIN="$(swift build -c release --arch "$ARCH" --show-bin-path)/EverythingMac"

echo "Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/EverythingMac"

# App icon. The asset catalog holds plain PNGs; iconutil turns them into the
# .icns a bundle needs. (actool would do this too, but it crashes here.)
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
SRC="App/Assets.xcassets/AppIcon.appiconset"
cp "$SRC/icon_16.png"   "$ICONSET/icon_16x16.png"
cp "$SRC/icon_32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$SRC/icon_32.png"   "$ICONSET/icon_32x32.png"
cp "$SRC/icon_64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$SRC/icon_128.png"  "$ICONSET/icon_128x128.png"
cp "$SRC/icon_256.png"  "$ICONSET/icon_128x128@2x.png"
cp "$SRC/icon_256.png"  "$ICONSET/icon_256x256.png"
cp "$SRC/icon_512.png"  "$ICONSET/icon_256x256@2x.png"
cp "$SRC/icon_512.png"  "$ICONSET/icon_512x512.png"
cp "$SRC/icon_1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Info.plist. The checked-in one carries Xcode build-setting placeholders, so
# substitute them here — this is what Xcode would have done at build time.
sed -e "s|\$(DEVELOPMENT_LANGUAGE)|en|g" \
    -e "s|\$(EXECUTABLE_NAME)|EverythingMac|g" \
    -e "s|\$(PRODUCT_NAME)|EverythingMac|g" \
    -e "s|\$(PRODUCT_BUNDLE_IDENTIFIER)|$BUNDLE_ID|g" \
    -e "s|\$(MARKETING_VERSION)|$MARKETING_VERSION|g" \
    -e "s|\$(CURRENT_PROJECT_VERSION)|$BUILD_VERSION|g" \
    App/Info.plist > "$APP/Contents/Info.plist"
PB=/usr/libexec/PlistBuddy
"$PB" -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
"$PB" -c "Add :LSMinimumSystemVersion string 14.0" "$APP/Contents/Info.plist"
"$PB" -c "Add :NSHighResolutionCapable bool true" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc sign, keeping the entitlements file. A bare re-sign would drop them;
# the app is not sandboxed so whole-disk indexing keeps working.
codesign --force --deep --entitlements App/EverythingMac.entitlements --sign - "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "Architecture:"
lipo -info "$APP/Contents/MacOS/EverythingMac" | sed 's/^/  /'

echo "Packaging $DMG..."
rm -f "$DMG"
hdiutil create -volname "Everything-Mac" -srcfolder "$APP" -ov -format UDZO "$DMG" > /dev/null

echo
echo "Built: $(pwd)/$APP"
echo "Built: $(pwd)/$DMG"

# Reveal the result: open the folder that holds the DMG.
open "$(pwd)"
