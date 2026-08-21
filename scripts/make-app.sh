#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release

BIN_DIR=$(swift build -c release --show-bin-path)
APP="build/FocusMac.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/MacFocusOS" "$APP/Contents/MacOS/FocusMac"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
cp "Resources/FocusMac.icns" "$APP/Contents/Resources/FocusMac.icns"
# The phone/attendance detector ships as one gzip archive in Resources. The app
# expands it once into Application Support on first camera-enabled launch
# (HumanServiceManager.installBundledServiceIfNeeded). A single archive keeps
# the build fast and the download small; per-file copies of node_modules are
# pathologically slow on machines that security-scan every new file.
COPYFILE_DISABLE=1 tar -zcf "$APP/Contents/Resources/human-service.tar.gz" "human-service"

find "$APP" -name ".DS_Store" -delete
xattr -cr "$APP"

# Sign with a stable identity when available so macOS TCC permission grants
# (Screen Recording, Camera, Automation) survive rebuilds. Ad-hoc signing gets
# a new cdhash every build and silently invalidates previously granted
# permissions — the reason the app can vanish from the Screen Recording list.
IDENTITY="${CODESIGN_IDENTITY:-Apple Development: Aaditya sah (J59TLR8U4M)}"
if security find-identity -v -p codesigning | grep -qF "$IDENTITY"; then
    codesign --force --options runtime --entitlements Resources/FocusMac.entitlements --sign "$IDENTITY" "$APP"
    echo "Signed with: $IDENTITY"
else
    codesign --force --sign - "$APP"
    echo "WARNING: stable identity not found — signed ad-hoc. Permissions may reset on rebuild."
fi

# Drag-and-drop installer disk image (Applications symlink + app).
DMG_ROOT="$(mktemp -d)"
DMG="build/FocusMac.dmg"
trap 'rm -rf "$DMG_ROOT"' EXIT
cp -R "$APP" "$DMG_ROOT/FocusMac.app"
ln -s /Applications "$DMG_ROOT/Applications"
rm -f "$DMG"
hdiutil create -volname "FocusMac" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG" >/dev/null
xattr -cr "$DMG"

echo "Built $APP"
echo "Built $DMG"
echo "Run with: open $APP"
echo "Install: open $DMG  (drag FocusMac → Applications)"
