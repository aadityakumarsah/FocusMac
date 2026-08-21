export const REPO_URL = "https://github.com/aadityakumarsah/FocusMac";
export const RELEASES_URL = "https://github.com/aadityakumarsah/FocusMac/releases";

export const installCommand =
  "git clone https://github.com/aadityakumarsah/FocusMac.git && cd FocusMac && ./scripts/install.sh";

export const navLinks = [
  { to: "/features", label: "Features" },
  { to: "/how-it-works", label: "How it works" },
  { to: "/install", label: "Install" },
];

export const stats = [
  { value: "<1.5%", label: "Idle CPU" },
  { value: "~85MB", label: "Memory" },
  { value: "<1ms", label: "Rule classify" },
  { value: "98%", label: "AI precision" },
];

export const pillars = [
  {
    n: "01",
    title: "Schedule decides the boundary",
    text: "Set study, work, free time, meals, and sleep once. FocusMac enforces during deep blocks and stays quiet when you’re free.",
  },
  {
    n: "02",
    title: "AI understands what you’re doing",
    text: "Rules catch the obvious in under a millisecond. Ambiguous titles go to an LLM. Optional vision reads the screen when a title isn’t enough.",
  },
  {
    n: "03",
    title: "Camera verifies you’re actually there",
    text: "Local YOLO phone detection, presence, and attention checks. Frames never leave your Mac. Yellow means put the phone down.",
  },
  {
    n: "04",
    title: "A lock you can’t casually undo",
    text: "Focus mode stays on. Quit, pause, and camera-off need your password — SHA-256, no recovery backdoor. Lifelines give honest, timed escapes.",
  },
];

export const features = [
  {
    title: "Activity classification",
    text: "Frontmost app and window title every 2 seconds — focused, warning, or blocked.",
  },
  {
    title: "Semantic AI + cache",
    text: "Ollama, Claude, OpenAI, Gemini, Groq, and more. 500-entry cache keeps repeats free.",
  },
  {
    title: "Vision mode",
    text: "Optional frontmost-window capture (~60s) so the model sees what titles miss.",
  },
  {
    title: "Blocking overlay",
    text: "Full-screen interruption with one-click close tab or go back.",
  },
  {
    title: "Browser tab scan",
    text: "Chrome, Brave, Arc, Edge, Safari — social and distracting tabs get caught.",
  },
  {
    title: "Media pause",
    text: "Background music and video pause when they become a distraction.",
  },
  {
    title: "Attendance panel",
    text: "Green attentive, amber phone, orange looking away, red left desk.",
  },
  {
    title: "XP & focus score",
    text: "Daily, session, and lifetime XP with a 0–100 score and weekly reports.",
  },
  {
    title: "10-second alarm",
    text: "Continuous, non-mutable, self-stopping when a problem is detected.",
  },
  {
    title: "Menu bar control",
    text: "Dashboard, session start/stop, settings, and quit — always one click away.",
  },
  {
    title: "Local persistence",
    text: "State in Application Support. Keys stay on your Mac.",
  },
  {
    title: "Open source MIT",
    text: "Build from source or install from Terminal. No account required.",
  },
];

export const steps = [
  {
    n: "1",
    title: "Copy the install command",
    text: "One click puts clone + install on your clipboard.",
  },
  {
    n: "2",
    title: "Paste into Terminal",
    text: "FocusMac builds and lands in /Applications.",
  },
  {
    n: "3",
    title: "Finish the 5-step wizard",
    text: "Password → schedule → permissions → AI key → start session.",
  },
];

export const setupWizard = [
  { n: "01", title: "Lock password", text: "Protects quit, pause, and camera-off." },
  { n: "02", title: "Weekly schedule", text: "Study, work, meals, breaks, sleep — once." },
  { n: "03", title: "Permissions", text: "Screen Recording, Camera, browser automation." },
  { n: "04", title: "AI provider", text: "Ollama local or paste any supported API key." },
  { n: "05", title: "Start session", text: "After that, sessions follow your schedule." },
];

export const loop = [
  { title: "Snapshot", text: "App, title, site, media — every 2 seconds." },
  { title: "Classify", text: "Rules first. LLM only when needed. Vision optional." },
  { title: "Enforce", text: "Warning → alarm → block + close tabs." },
  { title: "Verify", text: "Camera + idle tracking confirm you’re working." },
];

export const benchmarks = [
  { metric: "Idle CPU", value: "< 1.5%" },
  { metric: "Peak CPU", value: "~4%" },
  { metric: "Memory", value: "~85 MB" },
  { metric: "Cold start", value: "< 1.5 s" },
  { metric: "Rule path", value: "< 1 ms" },
  { metric: "Cache hits", value: "> 80%" },
];

export const faq = [
  {
    q: "Where does my data live?",
    a: "On your Mac. Camera frames for attendance are processed locally. AI keys stay in Application Support.",
  },
  {
    q: "Do I need an API key?",
    a: "Rules work without one. For semantic titles use Ollama offline or Anthropic, OpenAI, Gemini, Groq, DeepSeek, Kimi, or OpenRouter.",
  },
  {
    q: "Can I turn focus mode off?",
    a: "While FocusMac runs, focus stays on. Quitting or disabling camera checks requires your lock password.",
  },
  {
    q: "What if I forget the password?",
    a: "There is no recovery backdoor. Change it only with the current password, or contact the developer if locked out.",
  },
  {
    q: "Does free time get blocked?",
    a: "No. Free time, meals, breaks, and sleep are respected — no overlay, no XP penalties.",
  },
  {
    q: "Is it free?",
    a: "Yes. MIT open source on GitHub. Install from Terminal or grab a release build.",
  },
];
