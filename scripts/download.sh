#!/bin/bash
# FocusMac — beautiful one-line download.
#   curl -fsSL https://raw.githubusercontent.com/aadityakumarsah/FocusMac/main/scripts/download.sh | bash
set -euo pipefail

APP_NAME="FocusMac"
REPO="aadityakumarsah/FocusMac"
URL="https://github.com/${REPO}/releases/latest/download/${APP_NAME}.dmg"
DEST="${HOME}/Downloads/${APP_NAME}.dmg"

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
cleanup() { show_cursor; }
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

# ── progress bar ────────────────────────────────────────────────────────────
# width chars filled with blocks; percent + bytes on the right
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

download() {
  mkdir -p "$(dirname "$DEST")"
  rm -f "$DEST"

  # Resolve final size via redirected HEAD (GitHub assets send Content-Length).
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
}

open_dmg() {
  local i=0
  hide_cursor
  for i in {1..12}; do
    printf "%s  %s%s%s  Opening disk image…" \
      "$CLEAR_LINE" "$CYAN" "${spin_frames[i % ${#spin_frames[@]}]}" "$RESET"
    sleep 0.06
  done
  open "$DEST"
  printf "%s  %s✓%s  Opened  %s%s%s\n" \
    "$CLEAR_LINE" "$GREEN" "$RESET" "$WHITE" "$DEST" "$RESET"
  show_cursor
}

done_msg() {
  printf "\n"
  hr
  printf "\n"
  printf "  %s%sReady.%s  Drag  %sFocusMac%s  into  %sApplications%s.\n" \
    "$BOLD" "$GREEN" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET"
  printf "  %sThen launch it — the setup wizard takes it from there.%s\n" "$DIM" "$RESET"
  printf "\n"
}

banner
download
open_dmg
done_msg
