import { useState, useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import { installCommand, REPO_URL, RELEASES_URL } from "./data";
import {
  ParticleBackground,
  Card3D,
  FloatingElement,
  PulseGlow,
  GradientBorder,
  AnimatedCounter,
  Typewriter,
  MorphingBackground,
  Shimmer,
  MagneticButton,
  RevealOnScroll,
} from "./animations";

const features = [
  {
    icon: "🎯",
    title: "AI Activity Classification",
    description: "Classifies your work as focused, warning, or blocked every 2 seconds using intelligent rules and semantic analysis.",
    details: ["Rule-based classification in < 1ms", "LLM fallback for ambiguous titles", "500-entry semantic cache", "Optional vision analysis"],
    color: "#ff6b35"
  },
  {
    icon: "📅",
    title: "Schedule-First Enforcement",
    description: "Set your weekly schedule once. FocusMac automatically enforces focus during work blocks and respects free time.",
    details: ["Study, work, free, meals, sleep", "Auto-enforces during deep blocks", "Disappears when you're free", "One-time weekly setup"],
    color: "#9b59b6"
  },
  {
    icon: "🔒",
    title: "Uncheatable Lock",
    description: "Password-protected quit and camera controls. No recovery backdoor. Built so you can't cheat.",
    details: ["SHA-256 password hashing", "Quit / pause / camera-off locked", "No recovery backdoor", "Lifelines for honest breaks"],
    color: "#3498db"
  },
  {
    icon: "📸",
    title: "Camera Attendance",
    description: "YOLO-powered checks verify you're present, eyes on screen, and not using your phone. All local, never leaves your Mac.",
    details: ["Person, gaze, phone detection", "100% local — never leaves Mac", "Green / amber / alarm states", "~60s check intervals"],
    color: "#2ecc71"
  },
  {
    icon: "🚫",
    title: "Distraction Blocking",
    description: "Automatically closes distracting tabs in Chrome, Brave, Arc, Edge, and Safari. Pauses background media.",
    details: ["5 major browsers supported", "Full-screen blocking overlay", "Close tab / go back actions", "Media pause on distraction"],
    color: "#e91e63"
  },
  {
    icon: "🎮",
    title: "Gamification",
    description: "Earn XP for focused work, lose points for distractions. Track daily, session, and lifetime totals with a 0-100 focus score.",
    details: ["XP for aligned work", "Penalties for distractions", "Daily / session / lifetime", "0-100 focus score ring"],
    color: "#00bcd4"
  }
];

const supportedBrowsers = [
  { name: "Chrome", icon: "🌐" },
  { name: "Safari", icon: "🧭" },
  { name: "Arc", icon: "🔮" },
  { name: "Brave", icon: "🦁" },
  { name: "Edge", icon: "🔷" },
];

const steps = [
  { number: "1", title: "Lock Password", description: "Protects quit, pause, and camera-off", icon: "🔐" },
  { number: "2", title: "Weekly Schedule", description: "Set your work and free time blocks", icon: "📋" },
  { number: "3", title: "Permissions", description: "Screen, camera, browser access", icon: "⚙️" },
  { number: "4", title: "AI Brain", description: "Ollama offline or cloud API key", icon: "🧠" },
  { number: "5", title: "Start Session", description: "Begin your first focused session", icon: "🚀" }
];

const flowSteps = [
  { title: "Snapshot", text: "Capture frontmost app, window title, browser site, and media playback state.", icon: "📸", color: "#ff6b35" },
  { title: "Classify", text: "Rules first (< 1ms), LLM for ambiguous cases, vision analysis when needed.", icon: "🧠", color: "#9b59b6" },
  { title: "Enforce", text: "Warn → alarm → block → close tabs. Escalates based on persistence.", icon: "⚡", color: "#3498db" },
  { title: "Verify", text: "Camera + idle tracking confirm you're actually working and present.", icon: "✅", color: "#2ecc71" },
];

const metrics = [
  { value: 1.5, suffix: "%", label: "Idle CPU" },
  { value: 85, suffix: " MB", label: "Memory" },
  { value: 1, suffix: "ms", label: "Rule Path" },
  { value: 98, suffix: "%", label: "AI Precision" }
];

const benchmarks = [
  { label: "Idle CPU", value: "< 1.5%" },
  { label: "Peak CPU", value: "~4%" },
  { label: "Memory", value: "~85 MB" },
  { label: "Cold Start", value: "< 1.5s" },
  { label: "Cache Hits", value: "> 80%" },
  { label: "Tab Close", value: "< 600ms" },
];

const faqData = [
  {
    question: "Where does my data live?",
    answer: "On your Mac. Camera frames for attendance never leave for cloud YOLO. API keys stay in Application Support. Nothing is sent anywhere except the AI provider you choose."
  },
  {
    question: "Do I need an API key?",
    answer: "Rules work alone. For semantic titles, use Ollama offline or connect to Anthropic, OpenAI, Gemini, Groq, DeepSeek, Kimi, or OpenRouter."
  },
  {
    question: "Can I turn focus off?",
    answer: "While FocusMac runs, focus stays on. Quitting or disabling camera checks requires your lock password. The system is designed to be uncheatable."
  },
  {
    question: "What if I forget the password?",
    answer: "No recovery backdoor exists. You can only change the password with the current password, or contact the developer if locked out."
  },
  {
    question: "Is free time blocked?",
    answer: "No. Free time, meals, breaks, and sleep blocks are respected. FocusMac only guards during designated work/study blocks."
  },
  {
    question: "Is it free?",
    answer: "Yes. MIT licensed on GitHub. Install with one Terminal command or download the DMG from GitHub Releases."
  }
];

function FAQ() {
  const [openIndex, setOpenIndex] = useState(0);

  return (
    <div className="faq-list">
      {faqData.map((item, index) => (
        <RevealOnScroll key={index} threshold={0.1}>
          <div className={`faq-item ${openIndex === index ? 'open' : ''}`}>
            <button
              className="faq-question"
              onClick={() => setOpenIndex(openIndex === index ? -1 : index)}
            >
              {item.question}
              <span className="faq-icon">+</span>
            </button>
            <div className="faq-answer">
              <p>{item.answer}</p>
            </div>
          </div>
        </RevealOnScroll>
      ))}
    </div>
  );
}

function AppMockup() {
  const [activeTab, setActiveTab] = useState(0);
  const tabs = [
    { title: "YouTube — System Design", status: "aligned", xp: "+21 XP" },
    { title: "Twitter / X — Feed", status: "blocked", xp: "-8 XP" },
    { title: "VS Code — server.swift", status: "focused", xp: "+30 XP" },
  ];

  useEffect(() => {
    const interval = setInterval(() => {
      setActiveTab(prev => (prev + 1) % tabs.length);
    }, 3000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="app-mockup">
      <div className="mockup-titlebar">
        <div className="mockup-dots">
          <span className="dot dot-red" />
          <span className="dot dot-yellow" />
          <span className="dot dot-green" />
        </div>
        <span className="mockup-title">FocusMac</span>
        <div className="mockup-status">
          <span className="status-dot status-active" />
          <span>Session Active</span>
        </div>
      </div>
      <div className="mockup-body">
        <div className="mockup-sidebar">
          <div className="sidebar-item sidebar-active">
            <span>📊</span> Dashboard
          </div>
          <div className="sidebar-item">
            <span>📅</span> Schedule
          </div>
          <div className="sidebar-item">
            <span>📋</span> Reports
          </div>
          <div className="sidebar-item">
            <span>⚙️</span> Settings
          </div>
        </div>
        <div className="mockup-content">
          <div className="mockup-score-ring">
            <svg viewBox="0 0 100 100" className="score-svg">
              <circle cx="50" cy="50" r="45" className="score-bg" />
              <circle cx="50" cy="50" r="45" className="score-fill" />
            </svg>
            <div className="score-value">87</div>
            <div className="score-label">Focus Score</div>
          </div>
          <div className="mockup-stats">
            <div className="stat">
              <span className="stat-num">2h 14m</span>
              <span className="stat-label">Focused</span>
            </div>
            <div className="stat">
              <span className="stat-num">+142</span>
              <span className="stat-label">XP Earned</span>
            </div>
            <div className="stat">
              <span className="stat-num">3</span>
              <span className="stat-label">Blocked</span>
            </div>
          </div>
          <div className="mockup-activity">
            <div className="activity-header">Live Activity</div>
            {tabs.map((tab, i) => (
              <div
                key={i}
                className={`activity-row ${i === activeTab ? 'activity-active' : ''} activity-${tab.status}`}
              >
                <span className={`activity-status status-${tab.status}`} />
                <span className="activity-title">{tab.title}</span>
                <span className="activity-xp">{tab.xp}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

export function HomePage({ onCopy }) {
  return (
    <>
      <ParticleBackground />
      <MorphingBackground />

      <section className="hero">
        <div className="container hero-content">
          <FloatingElement delay={0} duration={6}>
            <div className="hero-badge glass-card">
              <span className="badge-dot" />
              v1.2.0 — Now with instant blocking & entertainment detection
            </div>
          </FloatingElement>

          <div className="hero-logo-container">
            <div className="hero-logo-ring"></div>
            <div className="hero-logo-ring-2"></div>
            <FloatingElement delay={0} duration={6}>
              <PulseGlow>
                <img src="/focusmac-logo.png" alt="FocusMac" className="hero-logo" />
              </PulseGlow>
            </FloatingElement>
          </div>

          <h1>
            The focus app that <span className="highlight">won't let you quit.</span>
          </h1>

          <p>
            <Typewriter
              text="AI watches your work, enforces your schedule, verifies you're at your desk, and password-locks itself so distractions don't win."
              speed={25}
            />
          </p>

          <div className="hero-buttons">
            <MagneticButton onClick={onCopy}>
              <Shimmer>Get Started — Free</Shimmer>
            </MagneticButton>
            <Link className="animated-btn hero-btn-secondary" to="/features">
              See All Features →
            </Link>
          </div>

          <div className="hero-metrics glass-card">
            {metrics.map((metric, index) => (
              <div key={index} className="metric">
                <div className="metric-value">
                  <AnimatedCounter value={metric.value} suffix={metric.suffix} />
                </div>
                <div className="metric-label">{metric.label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <RevealOnScroll threshold={0.1}>
        <section className="section">
          <div className="container">
            <div className="app-mockup-section">
              <div className="mockup-wrapper">
                <AppMockup />
              </div>
            </div>
          </div>
        </section>
      </RevealOnScroll>

      <RevealOnScroll threshold={0.1}>
        <section className="section section-alt">
          <div className="container">
            <div className="section-header">
              <span className="section-tag">Features</span>
              <h2 className="gradient-text">Built for deep work</h2>
              <p>Every guardrail you need to stay focused, nothing you don't.</p>
            </div>
            <div className="features-grid">
              {features.map((feature, index) => (
                <Card3D key={index}>
                  <div className="feature-card glass-card" style={{ borderColor: feature.color + '40' }}>
                    <FloatingElement delay={index * 0.2} duration={4 + index}>
                      <div className="feature-icon" style={{ background: `linear-gradient(135deg, ${feature.color}, ${feature.color}99)` }}>
                        {feature.icon}
                      </div>
                    </FloatingElement>
                    <h3>{feature.title}</h3>
                    <p>{feature.description}</p>
                    <ul className="feature-details">
                      {feature.details.map((detail, i) => (
                        <li key={i}><span className="detail-check">✓</span> {detail}</li>
                      ))}
                    </ul>
                  </div>
                </Card3D>
              ))}
            </div>
          </div>
        </section>
      </RevealOnScroll>

      <RevealOnScroll threshold={0.1}>
        <section className="section">
          <div className="container">
            <div className="section-header">
              <span className="section-tag">Supported</span>
              <h2 className="gradient-text">Works with your browser</h2>
              <p>Tab tracking and distraction blocking across all major browsers.</p>
            </div>
            <div className="browsers-row">
              {supportedBrowsers.map((browser, i) => (
                <FloatingElement key={i} delay={i * 0.15} duration={4}>
                  <div className="browser-chip glass-card">
                    <span className="browser-icon">{browser.icon}</span>
                    <span className="browser-name">{browser.name}</span>
                  </div>
                </FloatingElement>
              ))}
            </div>
          </div>
        </section>
      </RevealOnScroll>

      <RevealOnScroll threshold={0.1}>
        <section className="section section-alt">
          <div className="container">
            <div className="section-header">
              <span className="section-tag">How It Works</span>
              <h2 className="gradient-text">Five minutes to setup</h2>
              <p>Then automatic focus enforcement for life.</p>
            </div>
            <div className="steps">
              {steps.map((step, index) => (
                <FloatingElement key={index} delay={index * 0.3} duration={5}>
                  <div className="step">
                    <div className="step-number">{step.number}</div>
                    <div className="step-icon">{step.icon}</div>
                    <h3>{step.title}</h3>
                    <p>{step.description}</p>
                  </div>
                  {index < steps.length - 1 && <div className="step-connector" />}
                </FloatingElement>
              ))}
            </div>
          </div>
        </section>
      </RevealOnScroll>

      <RevealOnScroll threshold={0.1}>
        <section className="section">
          <div className="container">
            <div className="section-header">
              <span className="section-tag">Performance</span>
              <h2 className="gradient-text">Lightweight by design</h2>
              <p>Near-zero overhead. FocusMac stays out of your way.</p>
            </div>
            <div className="benchmarks-grid">
              {benchmarks.map((bench, i) => (
                <RevealOnScroll key={i} threshold={0.1}>
                  <div className="benchmark-card glass-card">
                    <div className="benchmark-value">{bench.value}</div>
                    <div className="benchmark-label">{bench.label}</div>
                  </div>
                </RevealOnScroll>
              ))}
            </div>
          </div>
        </section>
      </RevealOnScroll>

      <RevealOnScroll threshold={0.1}>
        <section className="install-section section">
          <div className="container">
            <h2 className="gradient-text">Install in seconds</h2>
            <p>One command. No setup required beyond the initial wizard.</p>

            <GradientBorder>
              <div className="install-box">
                <code>{installCommand}</code>
                <MagneticButton className="copy-btn" onClick={onCopy}>
                  <Shimmer>Copy</Shimmer>
                </MagneticButton>
              </div>
            </GradientBorder>

            <p style={{ fontSize: '16px', marginTop: '24px' }}>
              Or <a href={RELEASES_URL} target="_blank" rel="noreferrer" className="text-accent">download the DMG from GitHub Releases</a>
            </p>
          </div>
        </section>
      </RevealOnScroll>

      <RevealOnScroll threshold={0.1}>
        <section className="section section-alt">
          <div className="container">
            <div className="section-header">
              <span className="section-tag">FAQ</span>
              <h2 className="gradient-text">Common questions</h2>
              <p>Everything you need to know about FocusMac.</p>
            </div>
            <FAQ />
          </div>
        </section>
      </RevealOnScroll>
    </>
  );
}

export function FeaturesPage({ onCopy }) {
  return (
    <>
      <ParticleBackground />
      <MorphingBackground />

      <section className="section">
        <div className="container">
          <div className="section-header">
            <span className="section-tag">Features</span>
            <h1 className="gradient-text">Every guardrail, named.</h1>
            <p>From classification to camera lock — the full system that keeps deep work honest.</p>
          </div>
        </div>
      </section>

      <RevealOnScroll threshold={0.1}>
        <section className="section section-alt">
          <div className="container">
            <div className="features-detail-grid">
              {features.map((feature, index) => (
                <RevealOnScroll key={index} threshold={0.1}>
                  <div className="feature-detail-card glass-card">
                    <div className="feature-detail-header">
                      <div className="feature-icon-lg" style={{ background: `linear-gradient(135deg, ${feature.color}, ${feature.color}99)` }}>
                        {feature.icon}
                      </div>
                      <div>
                        <h3>{feature.title}</h3>
                        <p className="feature-detail-desc">{feature.description}</p>
                      </div>
                    </div>
                    <div className="feature-detail-list">
                      {feature.details.map((detail, i) => (
                        <div key={i} className="feature-detail-item">
                          <span className="detail-bullet" style={{ background: feature.color }} />
                          {detail}
                        </div>
                      ))}
                    </div>
                  </div>
                </RevealOnScroll>
              ))}
            </div>
          </div>
        </section>
      </RevealOnScroll>

      <RevealOnScroll threshold={0.1}>
        <section className="section">
          <div className="container">
            <div className="section-header">
              <span className="section-tag">Supported Browsers</span>
              <h2 className="gradient-text">Tab tracking & blocking</h2>
              <p>Works across all major macOS browsers.</p>
            </div>
            <div className="browsers-row">
              {supportedBrowsers.map((browser, i) => (
                <FloatingElement key={i} delay={i * 0.15} duration={4}>
                  <div className="browser-chip glass-card">
                    <span className="browser-icon">{browser.icon}</span>
                    <span className="browser-name">{browser.name}</span>
                  </div>
                </FloatingElement>
              ))}
            </div>
          </div>
        </section>
      </RevealOnScroll>

      <RevealOnScroll threshold={0.1}>
        <section className="install-section section">
          <div className="container">
            <h2 className="gradient-text">Ready to focus?</h2>
            <MagneticButton onClick={onCopy}>
              <Shimmer>Install FocusMac</Shimmer>
            </MagneticButton>
          </div>
        </section>
      </RevealOnScroll>
    </>
  );
}

export function HowItWorksPage({ onCopy }) {
  return (
    <>
      <ParticleBackground />
      <MorphingBackground />

      <section className="section">
        <div className="container">
          <div className="section-header">
            <span className="section-tag">How It Works</span>
            <h1 className="gradient-text">Five minutes once. Then automatic.</h1>
            <p>Set up your system once, let FocusMac handle the rest.</p>
          </div>
        </div>
      </section>

      <RevealOnScroll threshold={0.1}>
        <section className="section section-alt">
          <div className="container">
            <div className="section-header">
              <span className="section-tag">Setup Wizard</span>
              <h2 className="gradient-text">Onboarding in five steps</h2>
              <p>Every screen is a one-time setup. Takes about five minutes.</p>
            </div>
            <div className="steps steps-large">
              {steps.map((step, index) => (
                <FloatingElement key={index} delay={index * 0.3} duration={5}>
                  <div className="step step-detailed">
                    <div className="step-number">{step.number}</div>
                    <div className="step-icon-lg">{step.icon}</div>
                    <h3>{step.title}</h3>
                    <p>{step.description}</p>
                  </div>
                  {index < steps.length - 1 && <div className="step-connector" />}
                </FloatingElement>
              ))}
            </div>
          </div>
        </section>
      </RevealOnScroll>

      <RevealOnScroll threshold={0.1}>
        <section className="section">
          <div className="container">
            <div className="section-header">
              <span className="section-tag">Runtime Loop</span>
              <h2 className="gradient-text">Snapshot → Classify → Enforce → Verify</h2>
              <p>Every 2 seconds, this cycle keeps you honest.</p>
            </div>
            <div className="flow-grid">
              {flowSteps.map((step, index) => (
                <RevealOnScroll key={index} threshold={0.1}>
                  <Card3D>
                    <div className="flow-card glass-card">
                      <div className="flow-number" style={{ background: `linear-gradient(135deg, ${step.color}, ${step.color}99)` }}>
                        {index + 1}
                      </div>
                      <div className="flow-icon">{step.icon}</div>
                      <h3>{step.title}</h3>
                      <p>{step.text}</p>
                      {index < flowSteps.length - 1 && (
                        <div className="flow-arrow">→</div>
                      )}
                    </div>
                  </Card3D>
                </RevealOnScroll>
              ))}
            </div>
          </div>
        </section>
      </RevealOnScroll>

      <RevealOnScroll threshold={0.1}>
        <section className="section section-alt">
          <div className="container">
            <div className="section-header">
              <span className="section-tag">Classification</span>
              <h2 className="gradient-text">How it decides</h2>
              <p>Three tiers of intelligence, from instant rules to optional vision.</p>
            </div>
            <div className="intelligence-tiers">
              <RevealOnScroll threshold={0.1}>
                <div className="tier-card glass-card">
                  <div className="tier-badge tier-fast">Fastest</div>
                  <h3>Rule Engine</h3>
                  <p className="tier-speed">&lt; 1ms</p>
                  <p>Pattern matching on app names, window titles, and known sites. Handles 80%+ of activity with zero latency.</p>
                </div>
              </RevealOnScroll>
              <RevealOnScroll threshold={0.1}>
                <div className="tier-card glass-card">
                  <div className="tier-badge tier-smart">Smart</div>
                  <h3>LLM Classification</h3>
                  <p className="tier-speed">~500ms</p>
                  <p>For ambiguous titles, the AI reads context and decides. Supports Ollama (offline) and 7 cloud providers.</p>
                </div>
              </RevealOnScroll>
              <RevealOnScroll threshold={0.1}>
                <div className="tier-card glass-card">
                  <div className="tier-badge tier-vision">Vision</div>
                  <h3>Screen Analysis</h3>
                  <p className="tier-speed">~2s</p>
                  <p>Optional screenshot analysis when titles aren't enough. Catches content that text alone can't classify.</p>
                </div>
              </RevealOnScroll>
            </div>
          </div>
        </section>
      </RevealOnScroll>

      <RevealOnScroll threshold={0.1}>
        <section className="section">
          <div className="container">
            <div className="section-header">
              <span className="section-tag">Performance</span>
              <h2 className="gradient-text">Lightweight by design</h2>
            </div>
            <div className="benchmarks-grid">
              {benchmarks.map((bench, i) => (
                <RevealOnScroll key={i} threshold={0.1}>
                  <div className="benchmark-card glass-card">
                    <div className="benchmark-value">{bench.value}</div>
                    <div className="benchmark-label">{bench.label}</div>
                  </div>
                </RevealOnScroll>
              ))}
            </div>
          </div>
        </section>
      </RevealOnScroll>

      <RevealOnScroll threshold={0.1}>
        <section className="install-section section">
          <div className="container">
            <h2 className="gradient-text">Start your first session</h2>
            <MagneticButton onClick={onCopy}>
              <Shimmer>Install FocusMac</Shimmer>
            </MagneticButton>
          </div>
        </section>
      </RevealOnScroll>
    </>
  );
}

export function InstallPage({ onCopy }) {
  return (
    <>
      <ParticleBackground />
      <MorphingBackground />

      <section className="section">
        <div className="container">
          <div className="section-header">
            <span className="section-tag">Install</span>
            <h1 className="gradient-text">Copy. Paste. Focus.</h1>
            <p>One Terminal paste. Downloads, installs, and opens FocusMac.</p>
          </div>
        </div>
      </section>

      <RevealOnScroll threshold={0.1}>
        <section className="section section-alt">
          <div className="container">
            <GradientBorder>
              <div className="install-box glass-card" style={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'flex-start',
                maxWidth: '700px',
                margin: '0 auto'
              }}>
                <div className="install-command-row">
                  <span className="prompt-symbol">$</span>
                  <code style={{ wordBreak: 'break-all', textAlign: 'left', fontSize: '15px', flex: 1 }}>{installCommand}</code>
                </div>
                <MagneticButton className="copy-btn" onClick={onCopy} style={{ marginTop: '20px', alignSelf: 'flex-start' }}>
                  <Shimmer>Copy Command</Shimmer>
                </MagneticButton>
              </div>
            </GradientBorder>

            <div style={{ maxWidth: '700px', margin: '80px auto 0' }}>
              <h3 style={{ marginBottom: '40px', fontSize: '32px', fontWeight: '800' }} className="gradient-text">Installation Steps</h3>
              <div className="install-steps">
                {[
                  { num: 1, title: 'Copy the command', desc: 'Click the copy button above to grab the one-liner.' },
                  { num: 2, title: 'Paste in Terminal', desc: 'Open Terminal (or iTerm2) and paste the command.' },
                  { num: 3, title: 'Run the setup wizard', desc: 'Set your password, weekly schedule, and AI preferences.' },
                  { num: 4, title: 'Start your first session', desc: 'FocusMac follows your schedule automatically from here.' }
                ].map((step, index) => (
                  <FloatingElement key={index} delay={index * 0.2} duration={4}>
                    <div className="install-step glass-card">
                      <div className="install-step-num">{step.num}</div>
                      <div className="install-step-content">
                        <h4>{step.title}</h4>
                        <p>{step.desc}</p>
                      </div>
                    </div>
                  </FloatingElement>
                ))}
              </div>
            </div>

            <div className="install-requirements glass-card" style={{ maxWidth: '700px', margin: '60px auto 0' }}>
              <h4>Requirements</h4>
              <ul>
                <li>macOS 13 Ventura or later</li>
                <li>~85 MB disk space</li>
                <li>Screen recording permission</li>
                <li>Camera permission (optional, for attendance)</li>
              </ul>
            </div>

            <p style={{ textAlign: 'center', marginTop: '60px', fontSize: '16px' }}>
              Prefer manual installation? <a href={RELEASES_URL} target="_blank" rel="noreferrer" className="text-accent">Download from GitHub Releases</a>
            </p>
          </div>
        </section>
      </RevealOnScroll>
    </>
  );
}
