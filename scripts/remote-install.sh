#!/bin/bash
# FocusMac one-line installer (downloads DMG → /Applications → launch).
#   curl -fsSL https://raw.githubusercontent.com/aadityakumarsah/FocusMac/main/scripts/remote-install.sh | bash
set -euo pipefail

APP_NAME="FocusMac"
REPO="aadityakumarsah/FocusMac"
URL="https://github.com/${REPO}/releases/latest/download/${APP_NAME}.dmg"
TMP="$(mktemp -d)"
DMG="$TMP/${APP_NAME}.dmg"
MNT="/Volumes/${APP_NAME}"

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  CYAN=$'\033[38;5;81m'; PINK=$'\033[38;5;205m'; GREEN=$'\033[38;5;114m'
  WHITE=$'\033[38;5;255m'; GRAY=$'\033[38;5;245m'; CLEAR=$'\033[2K\r'
else
  BOLD=""; DIM=""; RESET=""; CYAN=""; PINK=""; GREEN=""; WHITE=""; GRAY=""; CLEAR="\r"
fi

hide() { [[ -t 1 ]] && printf '\033[?25l'; }
show() { [[ -t 1 ]] && printf '\033[?25h'; }
cleanup() {
  show
  hdiutil detach "$MNT" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

SPIN=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

human() {
  local b="$1"
  if (( b >= 1073741824 )); then awk -v b="$b" 'BEGIN{printf "%.1f GB",b/1073741824}'
  elif (( b >= 1048576 )); then awk -v b="$b" 'BEGIN{printf "%.1f MB",b/1048576}'
  elif (( b >= 1024 )); then awk -v b="$b" 'BEGIN{printf "%.0f KB",b/1024}'
  else printf "%d B" "$b"; fi
}

bar() {
  local pct="$1" cur="$2" tot="$3" w=28
  local f=$((pct * w / 100)) e=$((w - f)) s="" i
  for ((i=0;i<f;i++)); do s+="█"; done
  for ((i=0;i<e;i++)); do s+="░"; done
  if (( tot > 0 )); then
    printf "%s  %s↓%s  %s%s%s  %s%3d%%%s  %s%s%s / %s%s%s" \
      "$CLEAR" "$CYAN" "$RESET" "$CYAN" "$s" "$RESET" \
      "$BOLD" "$pct" "$RESET" "$WHITE" "$(human "$cur")" "$RESET" "$GRAY" "$(human "$tot")" "$RESET"
  else
    printf "%s  %s↓%s  downloading…  %s%s%s" \
      "$CLEAR" "$CYAN" "$RESET" "$WHITE" "$(human "$cur")" "$RESET"
  fi
}

step() {
  local i=0 label="$1"
  hide
  for i in {1..14}; do
    printf "%s  %s%s%s  %s" "$CLEAR" "$CYAN" "${SPIN[i % ${#SPIN[@]}]}" "$RESET" "$label"
    sleep 0.05
  done
  show
}

printf "\n"
printf "  %s%sFocusMac%s  %s— installing%s\n\n" "$BOLD" "$PINK" "$RESET" "$DIM" "$RESET"

total="$(
  curl -fsSIL "$URL" 2>/dev/null \
    | awk 'tolower($1)=="content-length:" { v=$2 } END { gsub(/\r/,"",v); print v+0 }'
)" || total=0

printf "  %sDownloading%s  %s.dmg%s\n\n" "$BOLD" "$RESET" "$APP_NAME" "$DIM"

hide
curl -fL --connect-timeout 30 --retry 3 --retry-delay 2 -o "$DMG" "$URL" >/dev/null 2>&1 &
pid=$!
cur=0 pct=0 frame=0
while kill -0 "$pid" 2>/dev/null; do
  cur="$(stat -f%z "$DMG" 2>/dev/null || echo 0)"
  if (( total > 0 )); then pct=$((cur * 100 / total)); (( pct > 100 )) && pct=100; fi
  bar "$pct" "$cur" "$total"
  printf "  %s%s%s" "$PINK" "${SPIN[frame % ${#SPIN[@]}]}" "$RESET"
  frame=$((frame + 1))
  sleep 0.08
done
wait "$pid" || { printf "\n\n  %s✗ Download failed.%s\n\n" "$PINK" "$RESET"; exit 1; }
cur="$(stat -f%z "$DMG" 2>/dev/null || echo 0)"
bar 100 "$cur" "${total:-$cur}"
printf "  %s✓%s\n\n" "$GREEN" "$RESET"
show

step "Mounting disk image…"
hdiutil attach "$DMG" -nobrowse -quiet
SRC="$MNT/${APP_NAME}.app"
[ -d "$SRC" ] || { printf "\n  %s✗ Disk image missing %s.app%s\n\n" "$PINK" "$APP_NAME" "$RESET"; exit 1; }
printf "%s  %s✓%s  Mounted\n" "$CLEAR" "$GREEN" "$RESET"

osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
pkill -f "${APP_NAME}.app/Contents/MacOS" 2>/dev/null || true
sleep 0.5

step "Installing to /Applications…"
rm -rf "/Applications/${APP_NAME}.app"
cp -R "$SRC" /Applications/
xattr -cr "/Applications/${APP_NAME}.app"
printf "%s  %s✓%s  Installed\n" "$CLEAR" "$GREEN" "$RESET"

step "Launching…"
open "/Applications/${APP_NAME}.app"
printf "%s  %s✓%s  Launched\n\n" "$CLEAR" "$GREEN" "$RESET"

printf "  %s%sDone.%s  The setup wizard will guide you.\n\n" "$BOLD" "$GREEN" "$RESET"
