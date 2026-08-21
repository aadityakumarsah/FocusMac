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
# The phone/attendance detector ships as a real directory inside the bundle so
# installed apps are fully self-contained (node_modules includes the native
# tfjs/onnxruntime bindings; models add ~40MB). Build/sign get slower — that's
# the price of a working drag-and-drop install.
rm -rf "$APP/Contents/Resources/human-service"
COPYFILE_DISABLE=1 ditto "human-service" "$APP/Contents/Resources/human-service"

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

echo "Built $APP"
echo "Run with: open $APP"
