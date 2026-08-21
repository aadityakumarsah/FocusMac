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

find "$APP" -name ".DS_Store" -delete
xattr -cr "$APP"

codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run with: open $APP"
