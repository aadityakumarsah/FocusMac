#!/bin/bash
# FocusMac one-line installer.
#   curl -fsSL https://raw.githubusercontent.com/aadityakumarsah/FocusMac/main/scripts/remote-install.sh | bash
set -euo pipefail

APP_NAME="FocusMac"
REPO="aadityakumarsah/FocusMac"
URL="https://github.com/${REPO}/releases/latest/download/${APP_NAME}.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "⬇️  Downloading ${APP_NAME}…"
curl -fSL --progress-bar -o "$TMP/${APP_NAME}.zip" "$URL"

echo "📦 Unpacking…"
ditto -x -k "$TMP/${APP_NAME}.zip" "$TMP"

SRC_APP="$(find "$TMP" -maxdepth 1 -name "${APP_NAME}.app" | head -1)"
[ -n "$SRC_APP" ] || { echo "Downloaded archive did not contain ${APP_NAME}.app"; exit 1; }

echo "🛑 Stopping any running copy…"
osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
pkill -f "${APP_NAME}.app/Contents/MacOS" 2>/dev/null || true
sleep 1

echo "💾 Installing to /Applications…"
rm -rf "/Applications/${APP_NAME}.app"
cp -R "$SRC_APP" /Applications/
xattr -cr "/Applications/${APP_NAME}.app"

echo "🚀 Launching…"
open "/Applications/${APP_NAME}.app"
echo "✅ ${APP_NAME} installed — the setup wizard will guide you."
