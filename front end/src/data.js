export const REPO_URL = "https://github.com/aadityakumarsah/FocusMac";
export const RELEASES_URL = "https://github.com/aadityakumarsah/FocusMac/releases";

export const installCommand =
  "git clone https://github.com/aadityakumarsah/FocusMac.git && cd FocusMac && ./scripts/install.sh";

export const SOCIAL = {
  github: REPO_URL,
  twitter: "https://twitter.com/",
};

export const navLinks = [
  { to: "/features", label: "Features" },
  { to: "/how-it-works", label: "How it works" },
  { to: "/#faq", label: "FAQ", hash: true },
];

export const orbitApps = [
  { name: "Safari", color: "#0A84FF", letter: "S" },
  { name: "Chrome", color: "#4285F4", letter: "C" },
  { name: "YouTube", color: "#FF0000", letter: "Y" },
  { name: "Slack", color: "#611F69", letter: "Sl" },
  { name: "Music", color: "#FC3C44", letter: "♪" },
  { name: "Camera", color: "#34C759", letter: "◉" },
];

export const focusMetrics = [
  { label: "focus score", value: 92 },
  { label: "aligned min", value: 148 },
  { label: "blocked", value: 11 },
  { label: "lifelines", value: 3 },
];

export const activityCards = [
  {
    name: "Cursor — App.jsx",
    role: "Deep work · now",
    trigger: "aligned with Study block",
    score: "✓",
    tone: "good",
  },
  {
    name: "YouTube — Shorts",
    role: "Distraction",
    trigger: "auto-flagged · overlay ready",
    score: "!",
    tone: "bad",
  },
  {
    name: "Safari — docs.rs",
    role: "Ambiguous title",
    trigger: "semantic AI · cached hit",
    score: "~",
    tone: "warn",
  },
  {
    name: "Camera check",
    role: "Attendance",
    trigger: "phone near face · amber",
    score: "⚡",
    tone: "warn",
  },
];

export const scheduleBlocks = [
  { title: "Deep work", time: "09:00 — 11:00", tone: "study" },
  { title: "Breakfast / free", time: "11:00 — 11:30", tone: "free" },
  { title: "Build FocusMac", time: "11:30 — 14:00", tone: "work", live: true },
  { title: "Gym", time: "17:30 — 18:30", tone: "gym" },
];

export const featurePillars = [
  {
    title: "Schedule",
    text: "Weekly blocks decide when FocusMac guards — and when free time stays free.",
  },
  {
    title: "Classify",
    text: "Rules in under 1ms. LLM for ambiguous titles. Optional vision for the screen itself.",
  },
  {
    title: "Enforce",
    text: "Warning → alarm → full-screen block + tab close. Camera verifies you’re actually there.",
  },
];

export const allFeatures = [
  {
    icon: "01",
    title: "AI activity classification",
    text: "Frontmost app + title every 2s as focused, warning, or blocked — with a 500-entry semantic cache.",
  },
  {
    icon: "02",
    title: "Vision screen analysis",
    text: "Optional capture of the frontmost window (~60s) so the model sees what titles miss.",
  },
  {
    icon: "03",
    title: "Schedule-first enforcement",
    text: "Study, work, meals, breaks, sleep — entered once, enforced automatically.",
  },
  {
    icon: "04",
    title: "Uncheatable password lock",
    text: "Quit, pause, and camera-off need your password. SHA-256, no recovery backdoor.",
  },
  {
    icon: "05",
    title: "YOLO phone detection",
    text: "Local ONNX YOLOv8n — person present, eyes on screen, no phone. Frames stay on your Mac.",
  },
  {
    icon: "06",
    title: "Blocking overlay",
    text: "Full-screen interruption with one-click close tab / go back when distraction persists.",
  },
  {
    icon: "07",
    title: "Browser tab scan",
    text: "Social and distracting tabs in Chrome, Brave, Arc, Edge, and Safari.",
  },
  {
    icon: "08",
    title: "Media pausing",
    text: "Background music and video pause when they become a distraction during focus.",
  },
  {
    icon: "09",
    title: "XP & focus score",
    text: "Daily, session, and lifetime XP with a 0–100 focus score ring and weekly insights.",
  },
  {
    icon: "10",
    title: "Non-mutable alarm",
    text: "Problem detected → 10-second continuous alarm you cannot mute. It stops itself.",
  },
  {
    icon: "11",
    title: "Lifelines",
    text: "Limited daily escapes with cooldowns — honest pauses, all logged.",
  },
  {
    icon: "12",
    title: "Local AI choice",
    text: "Ollama offline, or Anthropic, OpenAI, Gemini, Groq, and more — keys stay on your Mac.",
  },
];

export const setupSteps = [
  {
    n: "01",
    title: "Set a lock password",
    text: "Protects quit, pause, and turning camera checks off. Stored as SHA-256 forever.",
  },
  {
    n: "02",
    title: "Add your weekly rhythm",
    text: "Study, work, meals, breaks, sleep. FocusMac analyses every block.",
  },
  {
    n: "03",
    title: "Approve permissions once",
    text: "Screen Recording, Camera, and browser automation — clear macOS prompts.",
  },
  {
    n: "04",
    title: "Choose your AI brain",
    text: "Paste a provider key or run local Ollama. Nothing leaves except the provider you pick.",
  },
  {
    n: "05",
    title: "Start — then forget setup",
    text: "Sessions auto-start from your schedule. macOS won’t ask again.",
  },
];

export const faqItems = [
  {
    q: "Where does my data live?",
    a: "On your Mac. State lives in ~/Library/Application Support/MacFocusOS/. Camera frames are processed locally and never uploaded for YOLO attendance.",
  },
  {
    q: "Do I need an AI API key?",
    a: "Rules work without one. For semantic titles you can use Ollama offline or paste a key for Anthropic, OpenAI, Gemini, Groq, DeepSeek, Kimi, or OpenRouter.",
  },
  {
    q: "Can I turn focus mode off?",
    a: "Focus mode stays on while the app runs. Quitting or disabling camera checks requires your lock password — there is no silent off switch.",
  },
  {
    q: "What if I forget the password?",
    a: "There is no recovery backdoor. Only change it with the current password, or contact the developer if you’re locked out.",
  },
  {
    q: "Does free time still get nagged?",
    a: "No. Free time, meals, breaks, and sleep blocks are respected — no XP penalties, no blocking overlay, background media allowed.",
  },
  {
    q: "How heavy is it on CPU?",
    a: "Idle under ~1.5%, peak around ~4% during camera analysis, roughly ~85 MB RSS on an M2 Pro release build.",
  },
  {
    q: "macOS versions?",
    a: "macOS 13+. Built with Swift 6 and SwiftUI.",
  },
  {
    q: "Is it free / open source?",
    a: "Yes — MIT licensed on GitHub. Clone and install from Terminal, or grab a release build.",
  },
];

export const runtimeBenchmarks = [
  { metric: "Idle CPU", value: "< 1.5%", note: "2s tick loop, mostly parked" },
  { metric: "Peak CPU", value: "~4%", note: "during camera frame analysis" },
  { metric: "Memory (RSS)", value: "~85 MB", note: "incl. semantic cache at cap" },
  { metric: "Cold start → guarding", value: "< 1.5 s", note: "launch to first classified tick" },
  { metric: "Semantic cache", value: "500 entries", note: "LRU clear at cap" },
  { metric: "Cache hit rate", value: "> 80%", note: "ticks without a network call" },
];

export const footerColumns = [
  {
    title: "Product",
    links: [
      { label: "Features", to: "/features" },
      { label: "How it works", to: "/how-it-works" },
      { label: "Install", to: "/install" },
      { label: "Releases", href: RELEASES_URL, external: true },
    ],
  },
  {
    title: "Learn",
    links: [
      { label: "Benchmarks", to: "/features#benchmarks" },
      { label: "FAQ", to: "/#faq" },
      { label: "GitHub", href: REPO_URL, external: true },
    ],
  },
  {
    title: "Company",
    links: [
      { label: "Privacy", to: "/#faq" },
      { label: "License (MIT)", href: `${REPO_URL}/blob/main/LICENSE`, external: true },
      { label: "Contact", href: "https://github.com/aadityakumarsah/FocusMac/issues", external: true },
    ],
  },
];

export const sidebarItems = [
  "Dashboard",
  "Schedule",
  "Session",
  "Attendance",
  "Reports",
  "AI",
  "Lock",
  "Settings",
];
