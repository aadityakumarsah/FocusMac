export const REPO_URL = "https://github.com/aadityakumarsah/FocusMac";
export const RELEASES_URL = "https://github.com/aadityakumarsah/FocusMac/releases";

export const installCommand =
  "curl -fsSL https://raw.githubusercontent.com/aadityakumarsah/FocusMac/main/scripts/download.sh | bash";

export const nav = [
  { to: "/features", label: "Features" },
  { to: "/how-it-works", label: "How it works" },
  { to: "/install", label: "Install" },
];

export const proof = [
  { value: "< 1.5%", label: "idle CPU" },
  { value: "~85 MB", label: "memory" },
  { value: "< 1 ms", label: "rule path" },
  { value: "98%", label: "AI precision" },
];

export const stories = [
  {
    tag: "Schedule",
    title: "Your week writes the rules.",
    text: "Study, work, free time, meals, sleep — set once. FocusMac guards during deep blocks and disappears when you’re free.",
  },
  {
    tag: "Intelligence",
    title: "It knows what you’re doing.",
    text: "Rules classify in under a millisecond. Ambiguous titles hit an LLM. Optional vision reads the screen when titles aren’t enough.",
  },
  {
    tag: "Attendance",
    title: "Present. Eyes up. No phone.",
    text: "Local YOLO checks stay on your Mac. Green means attentive. Amber means put it down. Problems trigger a 10-second alarm you can’t mute.",
  },
  {
    tag: "Lock",
    title: "Built so you can’t cheat.",
    text: "Focus stays on. Quit, pause, and camera-off need your password. SHA-256. No recovery backdoor. Lifelines for honest breaks.",
  },
];

export const featureList = [
  ["Activity classification", "Focused / warning / blocked every 2 seconds"],
  ["Semantic AI + cache", "500-entry cache · Ollama or cloud providers"],
  ["Vision analysis", "Optional screen reads ~every 60s"],
  ["Blocking overlay", "Full-screen stop with close tab / go back"],
  ["Browser scan", "Chrome, Brave, Arc, Edge, Safari"],
  ["Media pause", "Distracting audio/video gets paused"],
  ["Camera attendance", "Person · gaze · phone — all local"],
  ["XP & score", "Daily, session, lifetime · 0–100 ring"],
  ["Menu bar app", "Start, stop, dashboard, quit"],
  ["Password lock", "Quit protection that actually sticks"],
  ["Reports", "Distraction + attendance history"],
  ["Open source", "MIT · no account · macOS 13+"],
];

export const flow = [
  { title: "Snapshot", text: "App, window title, site, media state." },
  { title: "Classify", text: "Rules first. LLM when needed. Vision optional." },
  { title: "Enforce", text: "Warn → alarm → block → close tabs." },
  { title: "Verify", text: "Camera + idle confirm you’re working." },
];

export const wizard = [
  ["01", "Lock password", "Protects quit, pause, camera-off."],
  ["02", "Weekly schedule", "The boundary for the whole week."],
  ["03", "Permissions", "Screen, camera, browser — once."],
  ["04", "AI brain", "Ollama offline or any supported key."],
  ["05", "Start session", "Then it follows your schedule."],
];

export const faq = [
  [
    "Where does my data live?",
    "On your Mac. Camera frames for attendance never leave for cloud YOLO. Keys stay in Application Support.",
  ],
  [
    "Do I need an API key?",
    "Rules work alone. For semantic titles use Ollama offline or Anthropic, OpenAI, Gemini, Groq, DeepSeek, Kimi, OpenRouter.",
  ],
  [
    "Can I turn focus off?",
    "While FocusMac runs, focus stays on. Quitting or disabling camera checks requires your lock password.",
  ],
  [
    "Forgot the password?",
    "No recovery backdoor. Change only with the current password, or contact the developer if locked out.",
  ],
  [
    "Is free time blocked?",
    "No. Free time, meals, breaks, and sleep are respected.",
  ],
  ["Is it free?", "Yes. MIT on GitHub. Paste the Terminal command or download the DMG from Releases."],
];

export const benches = [
  ["Idle CPU", "< 1.5%"],
  ["Peak CPU", "~4%"],
  ["Memory", "~85 MB"],
  ["Cold start", "< 1.5 s"],
  ["Cache hits", "> 80%"],
  ["Tab close", "< 600 ms"],
];
