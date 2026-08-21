#!/bin/bash
# Install FocusMac to /Applications from a terminal.
# Usage:  git clone https://github.com/aadityakumarsah/FocusMac.git
#         cd FocusMac && ./scripts/install.sh
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/make-app.sh

echo "Installing to /Applications…"
osascript -e 'tell application "FocusMac" to quit' >/dev/null 2>&1 || true
pkill -f "FocusMac.app/Contents/MacOS" 2>/dev/null || true
sleep 1
rm -rf /Applications/FocusMac.app
cp -R build/FocusMac.app /Applications/
xattr -cr /Applications/FocusMac.app

echo "Installed → /Applications/FocusMac.app"
open /Applications/FocusMac.app
