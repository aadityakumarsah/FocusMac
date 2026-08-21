# MacFocusOS — Feature Report

**Version:** 1.0 (release) · **Date:** 2026-08-21 · **Platform:** macOS

## Feature List

| # | Feature | Description | Tags |
|---|---------|-------------|------|
| 1 | Activity classification | Local rule engine classifies the active app/tab as aligned, neutral, or misaligned with the focus goal | `core` `rules` `offline` |
| 2 | Semantic AI classification | Optional Ollama/Claude/Codex/Gemini reads window titles and classifies ambiguous activity | `ai` `semantic` `optional` |
| 3 | Vision screen analysis | Captures the frontmost window every ~60s during a session and asks a vision model what's on screen | `ai` `vision` `screen-recording` |
| 4 | Focus sessions | Start/end/pause sessions; XP accrues per minute based on alignment | `session` `xp` `gamification` |
| 5 | XP & score | Daily XP, session XP, lifetime XP, 0–100 focus score from focused vs distracted time | `xp` `score` `stats` |
| 6 | Schedule blocks | Deep-work/free-time blocks; matching sites allowed, drift triggers blocking overlay | `schedule` `blocking` |
| 7 | Blocking overlay | Full-screen overlay during focus blocks when activity doesn't match the plan | `blocking` `overlay` `guard` |
| 8 | Media pausing | Pauses background media (music/video) when it becomes a distraction | `media` `automation` |
| 9 | Browser tab scan | Detects social/distracting tabs open in the background | `browser` `tabs` `detection` |
| 10 | Webcam attendance | Live camera panel; flags left-desk, looking-away, and phone use | `camera` `attendance` `live` |
| 11 | YOLOv8 phone detection | ONNX YOLOv8n model (local, no cloud) detects cell phones near the face | `yolo` `onnx` `phone` `local` |
| 12 | Face-match similarity | Compares the current face to a stored reference; EMA-smoothed, frontal-only measurement | `face` `similarity` `smoothing` |
| 13 | Sparse sampling | One camera frame analyzed every 6 minutes by default (1/3/6/10 min options) | `camera` `interval` `power-saving` |
| 14 | Non-mutable alarm | Problem detected → 10-second continuous alarm, cannot be muted, auto-stops | `alarm` `sound` `10s` |
| 15 | Mouse idle tracking | 3+ min without mouse input logged as an idle event | `mouse` `idle` `log` |
| 16 | Attendance report | Checks, distracted/focused counts, quiet periods, similarity history | `report` `attendance` `stats` |
| 17 | Distraction report | Events, minutes, per-site and per-hour breakdowns, top sites | `report` `distraction` `analytics` |
| 18 | Password lock | SHA-256 stored password; blocks quit, focus-mode off, pause, camera off | `security` `password` `lock` |
| 19 | Password change | Only with the current password; no recovery, no backdoor | `security` `password` `change` |
| 20 | Irreversible lock | Once set, the password persists forever and cannot be bypassed | `security` `persistence` `guard` |
| 21 | Quit protection | `applicationShouldTerminate` prompts for the password before quitting | `security` `quit` `gate` |
| 22 | Menu bar app | Status-item control: dashboard, settings, session start/stop, quit | `menubar` `status-item` |
| 23 | Persistent state | All state saved to `~/Library/Application Support/MacFocusOS/state.json` | `persistence` `state` |
| 24 | Ollama installer | One-click download/install/configure of local Ollama + model pull | `ai` `ollama` `installer` |
| 25 | Free-time toasts | Notifications when a scheduled free-time block starts/ends | `schedule` `toast` `notification` |

## Highlights of this release

- **Password lock (new):** set once, stored forever. Without it the app cannot be quit (close button, Cmd+Q, and menu Quit all require the password) and focus mode can never be turned off. Change/removal requires the current password.
- **Focus mode always on by default:** tracking defaults to ON and can only be disabled with the password.
- **Sparse camera sampling:** one frame every 6 minutes instead of a 3-second loop — the check counter no longer races.
- **10-second alarm:** continuous, non-mutable, self-stopping.
- **YOLOv8n phone detection:** local ONNX inference — no cloud dependency, no API key.

## Known limits

- Face-match reference resets per app launch (no persistent embedding file yet).
- YOLO can misclassify in very dark rooms (many borderline 0.5 detections) — mitigated by requiring the phone to be near the face box.
- Password is SHA-256 hashed (not salted with per-user salt); appropriate for local enforcement, not a server credential store.