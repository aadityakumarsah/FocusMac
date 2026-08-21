#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/FocusMac.app"
DMG="build/FocusMac.dmg"
ZIP="build/FocusMac.zip"
IDENTITY="${CODESIGN_IDENTITY:-}"

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

# Clean all extended attributes that might cause quarantine issues
echo "→ Cleaning extended attributes…"
find "$APP" -name ".DS_Store" -delete
find "$APP" -name "._*" -delete 2>/dev/null || true
xattr -cr "$APP"

# Sign with proper identity or ad-hoc if not available
# Use hardened runtime to prevent malware warnings
echo "→ Signing…"
if [ -n "$IDENTITY" ] && security find-identity -v -p codesigning | grep -qF "$IDENTITY"; then
  codesign --force --deep --options runtime --entitlements Resources/FocusMac.entitlements --sign "$IDENTITY" "$APP"
  echo "   Signed with: $IDENTITY"
else
  # Try to find any valid signing identity
  if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    # Use the first available Developer ID
    IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')
    codesign --force --deep --options runtime --entitlements Resources/FocusMac.entitlements --sign "$IDENTITY" "$APP"
    echo "   Signed with Developer ID: $IDENTITY"
  else
    # Fall back to ad-hoc signing with runtime flag
    codesign --force --deep --options runtime --sign - "$APP"
    echo "   WARNING: signed ad-hoc with runtime flag"
  fi
fi

# Verify the signature
codesign --verify --deep --strict "$APP" 2>&1 || {
  echo "   codesign verify reported issues — clearing xattrs and retrying…"
  xattr -cr "$APP"
  if [ -n "$IDENTITY" ] && security find-identity -v -p codesigning | grep -qF "$IDENTITY"; then
    codesign --force --deep --options runtime --entitlements Resources/FocusMac.entitlements --sign "$IDENTITY" "$APP"
  elif security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')
    codesign --force --deep --options runtime --entitlements Resources/FocusMac.entitlements --sign "$IDENTITY" "$APP"
  else
    codesign --force --deep --options runtime --sign - "$APP"
  fi
  codesign --verify --deep --strict "$APP"
}

# Clear extended attributes again after signing to prevent quarantine
xattr -cr "$APP"

echo "→ Creating DMG…"
DMG_ROOT="$(mktemp -d)"
cleanup_dmg() { rm -rf "$DMG_ROOT"; }
trap cleanup_dmg EXIT
cp -R "$APP" "$DMG_ROOT/FocusMac.app"
ln -s /Applications "$DMG_ROOT/Applications"
rm -f "$DMG"
hdiutil create -volname "FocusMac" -srcfolder "$DMG_ROOT" -ov -format UDZO -imagekey zlib-level=9 "$DMG" >/dev/null

# Clear extended attributes from DMG to prevent quarantine
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