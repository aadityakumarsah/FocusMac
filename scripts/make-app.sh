#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/FocusMac.app"
DMG="build/FocusMac.dmg"
ZIP="build/FocusMac.zip"
IDENTITY="${CODESIGN_IDENTITY:-}"
ROOT="$(pwd)"
SERVICE_STAGE="$(mktemp -d)"

# Finder/File Provider metadata can survive ordinary recursive xattr cleanup
# and makes `codesign --strict` reject an otherwise valid app bundle.
clean_bundle_attributes() {
  local target="$1"
  find "$target" -name ".DS_Store" -delete
  find "$target" -name "._*" -delete 2>/dev/null || true
  xattr -dr com.apple.FinderInfo "$target" 2>/dev/null || true
  xattr -dr 'com.apple.fileprovider.fpfs#P' "$target" 2>/dev/null || true
  xattr -cr "$target"
}

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
# Application Support on first camera-enabled launch. node_modules ships in
# the archive because the service runs without a network npm install; it is
# packed from a staged copy with native libraries stripped so the bundle
# stays a sane size.
echo "→ Packing human-service…"
COPYFILE_DISABLE=1 ditto human-service "$SERVICE_STAGE/human-service"
find "$SERVICE_STAGE" -type f \( -name "*.dylib" -o -name "*.node" \) -exec chmod u+w {} +
find "$SERVICE_STAGE" -type f \( -name "*.dylib" -o -name "*.node" \) -exec strip -x {} + 2>/dev/null || true
tar -zcf "$ROOT/$APP/Contents/Resources/human-service.tar.gz" -C "$SERVICE_STAGE" human-service
echo "   Archive $(du -h "$APP/Contents/Resources/human-service.tar.gz" | awk '{print $1}')"

# Clean all extended attributes that might cause quarantine issues
echo "→ Cleaning extended attributes…"
clean_bundle_attributes "$APP"

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
# `codesign` itself can cause Finder/File Provider metadata to reappear on
# this machine. It is not part of the signature, so remove it immediately
# before strict verification.
clean_bundle_attributes "$APP"
codesign --verify --deep --strict "$APP" 2>&1 || {
  echo "   codesign verify reported issues — clearing xattrs and retrying…"
  clean_bundle_attributes "$APP"
  if [ -n "$IDENTITY" ] && security find-identity -v -p codesigning | grep -qF "$IDENTITY"; then
    codesign --force --deep --options runtime --entitlements Resources/FocusMac.entitlements --sign "$IDENTITY" "$APP"
  elif security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')
    codesign --force --deep --options runtime --entitlements Resources/FocusMac.entitlements --sign "$IDENTITY" "$APP"
  else
    codesign --force --deep --options runtime --sign - "$APP"
  fi
  clean_bundle_attributes "$APP"
  codesign --verify --deep --strict "$APP"
}

# Clear extended attributes again after signing to prevent quarantine
clean_bundle_attributes "$APP"

echo "→ Creating DMG…"
DMG_ROOT="$(mktemp -d)"
cleanup_dmg() { rm -rf "$DMG_ROOT" "$SERVICE_STAGE"; }
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
