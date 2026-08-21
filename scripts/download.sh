#!/bin/bash
# FocusMac — beautiful one-line install (download → Applications → launch).
# Clears macOS quarantine so Gatekeeper doesn’t false-flag the app as malware.
#   curl -fsSL https://raw.githubusercontent.com/aadityakumarsah/FocusMac/main/scripts/download.sh | bash
set -euo pipefail

APP_NAME="FocusMac"
REPO="aadityakumarsah/FocusMac"
URL="https://github.com/${REPO}/releases/latest/download/${APP_NAME}.dmg"
DEST="${HOME}/Downloads/${APP_NAME}.dmg"
MNT="/Volumes/${APP_NAME}"
TMP_MOUNT=""

# ── colors (only when stdout is a TTY) ──────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
  CYAN=$'\033[38;5;81m'
  PINK=$'\033[38;5;205m'
  GREEN=$'\033[38;5;114m'
  WHITE=$'\033[38;5;255m'
  GRAY=$'\033[38;5;245m'
  CLEAR_LINE=$'\033[2K\r'
else
  BOLD=""; DIM=""; RESET=""; CYAN=""; PINK=""; GREEN=""; WHITE=""; GRAY=""; CLEAR_LINE="\r"
fi

hide_cursor() { [[ -t 1 ]] && printf '\033[?25l'; }
show_cursor() { [[ -t 1 ]] && printf '\033[?25h'; }
cleanup() {
  show_cursor
  if [[ -n "${TMP_MOUNT}" ]]; then
    hdiutil detach "$TMP_MOUNT" >/dev/null 2>&1 || true
  fi
  hdiutil detach "$MNT" >/dev/null 2>&1 || true
}
trap cleanup EXIT

hr() {
  printf "%s──────────────────────────────────────────────────%s\n" "$GRAY" "$RESET"
}

banner() {
  printf "\n"
  printf "%s  ███████╗ ██████╗  ██████╗██╗   ██╗███████╗%s\n" "$PINK" "$RESET"
  printf "%s  ██╔════╝██╔═══██╗██╔════╝██║   ██║██╔════╝%s\n" "$PINK" "$RESET"
  printf "%s  █████╗  ██║   ██║██║     ██║   ██║███████╗%s\n" "$CYAN" "$RESET"
  printf "%s  ██╔══╝  ██║   ██║██║     ██║   ██║╚════██║%s\n" "$CYAN" "$RESET"
  printf "%s  ██║     ╚██████╔╝╚██████╗╚██████╔╝███████║%s\n" "$WHITE" "$RESET"
  printf "%s  ╚═╝      ╚═════╝  ╚═════╝ ╚═════╝ ╚══════╝%s\n" "$WHITE" "$RESET"
  printf "\n"
  printf "  %s%sMac focus guardian%s  %s·%s  %smacOS 13+%s\n" "$BOLD" "$WHITE" "$RESET" "$GRAY" "$RESET" "$DIM" "$RESET"
  printf "\n"
  hr
  printf "\n"
}

draw_bar() {
  local pct="$1" current="$2" total="$3" width=28
  local filled=$((pct * width / 100))
  local empty=$((width - filled))
  local bar="" i
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = 0; i < empty; i++)); do bar+="░"; done

  local cur_h tot_h
  cur_h="$(human_bytes "$current")"
  if (( total > 0 )); then
    tot_h="$(human_bytes "$total")"
    printf "%s  %s↓%s  %s%s%s  %s%3d%%%s  %s%s%s / %s%s%s" \
      "$CLEAR_LINE" "$CYAN" "$RESET" \
      "$CYAN" "$bar" "$RESET" \
      "$BOLD" "$pct" "$RESET" \
      "$WHITE" "$cur_h" "$RESET" "$GRAY" "$tot_h" "$RESET"
  else
    printf "%s  %s↓%s  downloading…  %s%s%s" \
      "$CLEAR_LINE" "$CYAN" "$RESET" "$WHITE" "$cur_h" "$RESET"
  fi
}

human_bytes() {
  local b="$1"
  if (( b >= 1073741824 )); then
    awk -v b="$b" 'BEGIN { printf "%.1f GB", b/1073741824 }'
  elif (( b >= 1048576 )); then
    awk -v b="$b" 'BEGIN { printf "%.1f MB", b/1048576 }'
  elif (( b >= 1024 )); then
    awk -v b="$b" 'BEGIN { printf "%.0f KB", b/1024 }'
  else
    printf "%d B" "$b"
  fi
}

spin_frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

spin_step() {
  local label="$1" i
  hide_cursor
  for i in {1..14}; do
    printf "%s  %s%s%s  %s" \
      "$CLEAR_LINE" "$CYAN" "${spin_frames[i % ${#spin_frames[@]}]}" "$RESET" "$label"
    sleep 0.05
  done
  show_cursor
}

download() {
  mkdir -p "$(dirname "$DEST")"
  rm -f "$DEST"

  local total=0
  total="$(
    curl -fsSIL "$URL" 2>/dev/null \
      | awk 'tolower($1)=="content-length:" { v=$2 } END { gsub(/\r/,"",v); print v+0 }'
  )" || total=0

  printf "  %sDownloading%s  %s%s.dmg%s\n" "$BOLD" "$RESET" "$DIM" "$APP_NAME" "$RESET"
  printf "  %s%s%s\n\n" "$GRAY" "$URL" "$RESET"

  hide_cursor
  curl -fL --connect-timeout 30 --retry 3 --retry-delay 2 \
    -o "$DEST" "$URL" >/dev/null 2>&1 &
  local pid=$!

  local current=0 pct=0 frame=0
  while kill -0 "$pid" 2>/dev/null; do
    current="$(stat -f%z "$DEST" 2>/dev/null || echo 0)"
    if (( total > 0 )); then
      pct=$((current * 100 / total))
      (( pct > 100 )) && pct=100
    else
      pct=0
    fi
    draw_bar "$pct" "$current" "$total"
    printf "  %s%s%s" "$PINK" "${spin_frames[frame % ${#spin_frames[@]}]}" "$RESET"
    frame=$((frame + 1))
    sleep 0.08
  done

  wait "$pid" || {
    printf "\n\n  %s✗ Download failed.%s Check your network and try again.\n\n" "$PINK" "$RESET"
    exit 1
  }

  current="$(stat -f%z "$DEST" 2>/dev/null || echo 0)"
  if (( current < 1000000 )); then
    printf "\n\n  %s✗ Download looks incomplete (%s).%s\n\n" "$PINK" "$(human_bytes "$current")" "$RESET"
    exit 1
  fi

  draw_bar 100 "$current" "${total:-$current}"
  printf "  %s✓%s\n" "$GREEN" "$RESET"
  show_cursor
  printf "\n"

  # Drop Finder quarantine so Gatekeeper doesn’t treat a fresh install as malware.
  xattr -cr "$DEST" 2>/dev/null || true
}

install_app() {
  spin_step "Preparing disk image…"
  # Mount without adding quarantine to the copied app.
  local attach_out
  attach_out="$(hdiutil attach "$DEST" -nobrowse -quiet -mountpoint "$MNT" 2>&1 || true)"
  if [[ ! -d "$MNT/${APP_NAME}.app" ]]; then
    # Fallback if mountpoint was busy — let hdiutil pick a volume name.
    attach_out="$(hdiutil attach "$DEST" -nobrowse 2>&1)"
    TMP_MOUNT="$(echo "$attach_out" | awk '/\/Volumes\//{print $NF; exit}')"
    MNT="${TMP_MOUNT:-$MNT}"
  fi

  local src="$MNT/${APP_NAME}.app"
  if [[ ! -d "$src" ]]; then
    printf "\n  %s✗ Disk image did not contain %s.app%s\n\n" "$PINK" "$APP_NAME" "$RESET"
    exit 1
  fi
  printf "%s  %s✓%s  Disk image ready\n" "$CLEAR_LINE" "$GREEN" "$RESET"

  spin_step "Stopping any running copy…"
  osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
  pkill -f "${APP_NAME}.app/Contents/MacOS" 2>/dev/null || true
  sleep 0.4
  printf "%s  %s✓%s  Ready to install\n" "$CLEAR_LINE" "$GREEN" "$RESET"

  spin_step "Installing to /Applications…"
  rm -rf "/Applications/${APP_NAME}.app"
  # ditto preserves resources better than cp -R for app bundles.
  ditto "$src" "/Applications/${APP_NAME}.app"
  # Critical: remove quarantine / provenance flags Gatekeeper uses to block launch.
  xattr -cr "/Applications/${APP_NAME}.app" 2>/dev/null || true
  printf "%s  %s✓%s  Installed  %s/Applications/%s.app%s\n" \
    "$CLEAR_LINE" "$GREEN" "$RESET" "$WHITE" "$APP_NAME" "$RESET"

  hdiutil detach "$MNT" >/dev/null 2>&1 || true
  TMP_MOUNT=""
}

launch_app() {
  spin_step "Launching FocusMac…"
  open "/Applications/${APP_NAME}.app"
  printf "%s  %s✓%s  Launched\n" "$CLEAR_LINE" "$GREEN" "$RESET"
}

done_msg() {
  printf "\n"
  hr
  printf "\n"
  printf "  %s%sYou’re in.%s  The setup wizard will ask for your lock password.\n" \
    "$BOLD" "$GREEN" "$RESET"
  printf "  %sIf macOS ever blocks it: System Settings → Privacy & Security → Open Anyway.%s\n" \
    "$DIM" "$RESET"
  printf "\n"
}

banner
download
install_app
launch_app
done_msg
