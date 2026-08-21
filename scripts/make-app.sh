#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/FocusMac.app"
DMG="build/FocusMac.dmg"
ZIP="build/FocusMac.zip"
IDENTITY="${CODESIGN_IDENTITY:-Apple Development: Aaditya sah (J59TLR8U4M)}"

echo "→ Building release binary…"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "→ Assembling FocusMac.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Strip local symbols for a smaller, faster-loading binary.
cp "$BIN_DIR/MacFocusOS" "$APP/Contents/MacOS/FocusMac"
strip -x "$APP/Contents/MacOS/FocusMac" 2>/dev/null || true

cp "Resources/Info.plist" "$APP/Contents/Info.plist"
cp "Resources/FocusMac.icns" "$APP/Contents/Resources/FocusMac.icns"

# Phone/attendance detector as one gzip archive. Expanded once into
# Application Support on first camera-enabled launch. The working tree is
# already pruned to Darwin-only native libs (see human-service/package.json).
echo "→ Packing human-service…"
COPYFILE_DISABLE=1 tar -zcf "$APP/Contents/Resources/human-service.tar.gz" human-service
echo "   Archive $(du -h "$APP/Contents/Resources/human-service.tar.gz" | awk '{print $1}')"

find "$APP" -name ".DS_Store" -delete
find "$APP" -name "._*" -delete 2>/dev/null || true
xattr -cr "$APP"

# Sign with a stable identity when available so macOS TCC permission grants
# (Screen Recording, Camera, Automation) survive rebuilds. Ad-hoc signing gets
# a new cdhash every build and silently invalidates previously granted
# permissions. Deep + hardened runtime + sealed resources required so Finder
# / Gatekeeper don’t reject the bundle after download. Always clear xattrs
# before signing — Finder info / resource forks make codesign fail.
echo "→ Signing…"
if security find-identity -v -p codesigning | grep -qF "$IDENTITY"; then
  codesign --force --deep --options runtime \
    --entitlements Resources/FocusMac.entitlements \
    --sign "$IDENTITY" "$APP"
  echo "   Signed with: $IDENTITY"
else
  codesign --force --deep --sign - "$APP"
  echo "   WARNING: stable identity not found — signed ad-hoc."
fi

codesign --verify --deep --strict "$APP" || {
  echo "   codesign verify reported issues — clearing xattrs and retrying…"
  xattr -cr "$APP"
  if security find-identity -v -p codesigning | grep -qF "$IDENTITY"; then
    codesign --force --deep --options runtime \
      --entitlements Resources/FocusMac.entitlements \
      --sign "$IDENTITY" "$APP"
  else
    codesign --force --deep --sign - "$APP"
  fi
  codesign --verify --deep --strict "$APP"
}
xattr -cr "$APP"

echo "→ Creating DMG…"
DMG_ROOT="$(mktemp -d)"
cleanup_dmg() { rm -rf "$DMG_ROOT"; }
trap cleanup_dmg EXIT
cp -R "$APP" "$DMG_ROOT/FocusMac.app"
ln -s /Applications "$DMG_ROOT/Applications"
rm -f "$DMG"
hdiutil create -volname "FocusMac" -srcfolder "$DMG_ROOT" -ov -format UDZO -imagekey zlib-level=9 "$DMG" >/dev/null
xattr -cr "$DMG"

# Zip for in-app updater (same app, no quarantine).
echo "→ Creating ZIP…"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xattr -cr "$ZIP"

echo
echo "Built $APP"
echo "Built $DMG ($(du -h "$DMG" | awk '{print $1}'))"
echo "Built $ZIP ($(du -h "$ZIP" | awk '{print $1}'))"
echo "Run with: open $APP"
echo "Distribute: upload FocusMac.dmg (+ FocusMac.zip) to the GitHub release"
