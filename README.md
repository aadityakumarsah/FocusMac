# MacFocusOS

AI-powered focus tracker for macOS. It watches what you actually do — the active app, browser tabs, your webcam — and keeps you accountable to your focus plan.

## What it does

- **Activity intelligence** — classifies your active app/window as aligned, neutral, or misaligned with your goal (local rules + optional Ollama/Claude/Codex/Gemini AI).
- **Focus sessions & XP** — start a session, stay aligned to earn XP; distractions drain it.
- **Schedule blocks** — plan deep-work vs free-time windows; matching sites are allowed, everything else is blocked.
- **Webcam attendance check** — streams the camera into a floating panel and flags: left the desk, looking away, or **phone detected (YOLOv8n)**. One frame is analyzed every 6 minutes by default.
- **Non-mutable alarm** — when a problem is detected the alarm rings for 10 seconds straight and cannot be muted.
- **Mouse idle tracking** — 3+ minutes without input is logged as not working.
- **Password lock** — once set, the app cannot be quit and focus mode cannot be turned off without the password. Stored forever (SHA-256), only changeable with the current password.
- **Blocking overlay** — a full-screen overlay appears during focus blocks when you drift.
- **Distraction & attendance reports** — see where your time actually went.

## Quick start

### 1. Backend (human detection + YOLO phone detection)

```bash
cd human-service
npm install
node server.cjs            # serves http://127.0.0.1:8765  (/health, /analyze)
```

Requires Node 18+. Uses `onnxruntime-node` with the bundled `models/yolov8n.onnx` and MediaPipe-based face/pose detection — no external API keys.

### 2. Build the app

```bash
./scripts/make-app.sh      # produces build/MacFocusOS.app
open build/MacFocusOS.app
```

First launch will ask for **Camera** and **Screen Recording** permission — allow both.

### 3. Configure an AI model (optional, for semantic classification)

Settings → AI Model: pick a provider from the dropdown — Local Ollama, Claude, OpenAI, OpenRouter, OpenCode Zen, Kimi, Gemini, DeepSeek or Groq — and paste your API key. The key format is detected automatically and the connection is tested as soon as you stop typing. Leave everything on Local Ollama for fully offline use.

## Settings at a glance

| Setting | Default | Notes |
|---|---|---|
| Focus tracking | ON | Can only be turned OFF with the password |
| Camera check | OFF | Turn ON in Settings → Attendance |
| Camera check interval | 6 min | 1 / 3 / 6 / 10 min options |
| Alarm | 10 s | Non-mutable, auto-stops |
| Password lock | OFF | Irreversible to bypass; stored forever |

## Project layout

```
Sources/MacFocusOS          App UI (SwiftUI): dashboard, settings, panels, overlay
Sources/MacFocusOSCore      Logic: rule engine, sessions, XP, persistence, store
human-service               Node backend: face/pose/phone detection, /analyze
scripts/make-app.sh         Build + codesign script
```

## Notes

- State (XP, sessions, attendance log, password hash) persists in `~/Library/Application Support/MacFocusOS/state.json`.
- The password is stored as a SHA-256 hash and cannot be recovered — if you forget it, the app cannot be quit and focus mode cannot be disabled. There is intentionally no backdoor.