import { useState, useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import { installCommand, REPO_URL, RELEASES_URL } from "./data";
import { 
  ParticleBackground, 
  OrbitingIcons, 
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
  WaveAnimation 
} from "./animations";

const features = [
  {
    icon: "🎯",
    title: "AI Activity Classification",
    description: "Classifies your work as focused, warning, or blocked every 2 seconds using intelligent rules and semantic analysis.",
    color: "#ff6b35"
  },
  {
    icon: "📅",
    title: "Schedule-First Enforcement",
    description: "Set your weekly schedule once. FocusMac automatically enforces focus during work blocks and respects free time.",
    color: "#9b59b6"
  },
  {
    icon: "🔒",
    title: "Uncheatable Lock",
    description: "Password-protected quit and camera controls. No recovery backdoor. Built so you can't cheat.",
    color: "#3498db"
  },
  {
    icon: "📸",
    title: "Camera Attendance",
    description: "YOLO-powered checks verify you're present, eyes on screen, and not using your phone. All local, never leaves your Mac.",
    color: "#2ecc71"
  },
  {
    icon: "🚫",
    title: "Distraction Blocking",
    description: "Automatically closes distracting tabs in Chrome, Brave, Arc, Edge, and Safari. Pauses background media.",
    color: "#e91e63"
  },
  {
    icon: "🎮",
    title: "Gamification",
    description: "Earn XP for focused work, lose points for distractions. Track daily, session, and lifetime totals with a 0-100 focus score.",
    color: "#00bcd4"
  }
];

const steps = [
  { number: "1", title: "Lock Password", description: "Protects quit, pause, and camera-off" },
  { number: "2", title: "Weekly Schedule", description: "Set your work and free time blocks" },
  { number: "3", title: "Permissions", description: "Screen, camera, browser access" },
  { number: "4", title: "AI Brain", description: "Ollama offline or cloud API key" },
  { number: "5", title: "Start Session", description: "Begin your first focused session" }
];

const metrics = [
  { value: 1.5, suffix: "%", label: "Idle CPU" },
  { value: 85, suffix: " MB", label: "Memory Usage" },
  { value: 1, suffix: "ms", label: "Rule Classification" },
  { value: 98, suffix: "%", label: "AI Precision" }
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
          <div 
            className={`faq-item ${openIndex === index ? 'open' : ''}`}
          >
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

export function HomePage({ onCopy }) {
  return (
    <>
      <ParticleBackground />
      <MorphingBackground />
      
      <section className="hero">
        <div className="container hero-content">
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
              speed={30}
            />
          </p>
          
          <div className="hero-buttons">
            <MagneticButton onClick={onCopy}>
              <Shimmer>Get Started</Shimmer>
            </MagneticButton>
            <Link className="animated-btn" to="/features" style={{ background: 'transparent', border: '2px solid var(--accent)' }}>
              Learn More
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
              <span className="section-tag">How It Works</span>
              <h2 className="gradient-text">Five minutes to setup</h2>
              <p>Then automatic focus enforcement for life.</p>
            </div>
            
            <div className="steps">
              {steps.map((step, index) => (
                <FloatingElement key={index} delay={index * 0.3} duration={5}>
                  <div className="step">
                    <div className="step-number">{step.number}</div>
                    <h3>{step.title}</h3>
                    <p>{step.description}</p>
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
              Or <a href={RELEASES_URL} target="_blank" rel="noreferrer" className="text-accent">download from GitHub Releases</a>
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
                  </div>
                </Card3D>
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
            <div className="steps">
              {steps.map((step, index) => (
                <FloatingElement key={index} delay={index * 0.3} duration={5}>
                  <div className="step">
                    <div className="step-number">{step.number}</div>
                    <h3>{step.title}</h3>
                    <p>{step.description}</p>
                  </div>
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
              <h2 className="gradient-text">The Runtime Loop</h2>
              <p>Snapshot → Classify → Enforce → Verify, every 2 seconds.</p>
            </div>
            <div className="features-grid">
              <Card3D>
                <div className="feature-card glass-card">
                  <div className="feature-icon" style={{ background: 'linear-gradient(135deg, #ff6b35, #f7931e)' }}>
                    📸
                  </div>
                  <h3>Snapshot</h3>
                  <p>Capture frontmost app, window title, browser site, and media playback state.</p>
                </div>
              </Card3D>
              <Card3D>
                <div className="feature-card glass-card">
                  <div className="feature-icon" style={{ background: 'linear-gradient(135deg, #9b59b6, #8e44ad)' }}>
                    🧠
                  </div>
                  <h3>Classify</h3>
                  <p>Rules first (&lt;1ms), LLM for ambiguous cases, vision analysis when needed.</p>
                </div>
              </Card3D>
              <Card3D>
                <div className="feature-card glass-card">
                  <div className="feature-icon" style={{ background: 'linear-gradient(135deg, #3498db, #2980b9)' }}>
                    ⚡
                  </div>
                  <h3>Enforce</h3>
                  <p>Warn → alarm → block → close tabs. Escalates based on persistence.</p>
                </div>
              </Card3D>
              <Card3D>
                <div className="feature-card glass-card">
                  <div className="feature-icon" style={{ background: 'linear-gradient(135deg, #2ecc71, #27ae60)' }}>
                    ✅
                  </div>
                  <h3>Verify</h3>
                  <p>Camera + idle tracking confirm you're actually working and present.</p>
                </div>
              </Card3D>
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
                maxWidth: '600px',
                margin: '0 auto'
              }}>
                <code style={{ wordBreak: 'break-all', textAlign: 'left', fontSize: '14px' }}>{installCommand}</code>
                <MagneticButton className="copy-btn" onClick={onCopy} style={{ marginTop: '20px', alignSelf: 'flex-start' }}>
                  <Shimmer>Copy Command</Shimmer>
                </MagneticButton>
              </div>
            </GradientBorder>
            
            <div style={{ maxWidth: '600px', margin: '80px auto 0' }}>
              <h3 style={{ marginBottom: '32px', fontSize: '28px', fontWeight: '800' }} className="gradient-text">Installation Steps</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
                {[
                  { num: 1, title: 'Copy the command', desc: 'Click the copy button above' },
                  { num: 2, title: 'Paste in Terminal', desc: 'Open Terminal and paste the command' },
                  { num: 3, title: 'Run the setup wizard', desc: 'Set your password, schedule, and preferences' }
                ].map((step, index) => (
                  <FloatingElement key={index} delay={index * 0.2} duration={4}>
                    <div className="glass-card" style={{ 
                      display: 'flex', 
                      gap: '20px', 
                      alignItems: 'flex-start',
                      padding: '24px'
                    }}>
                      <div style={{ 
                        width: '48px', 
                        height: '48px', 
                        background: 'linear-gradient(135deg, var(--accent), var(--purple))', 
                        color: 'white', 
                        borderRadius: '50%', 
                        display: 'flex', 
                        alignItems: 'center', 
                        justifyContent: 'center',
                        fontWeight: 800,
                        fontSize: '20px',
                        flexShrink: 0,
                        animation: 'pulse-glow 2s ease-in-out infinite'
                      }}>
                        {step.num}
                      </div>
                      <div>
                        <h4 style={{ marginBottom: '8px', fontSize: '18px', fontWeight: '700' }}>{step.title}</h4>
                        <p style={{ fontSize: '15px', margin: 0 }}>{step.desc}</p>
                      </div>
                    </div>
                  </FloatingElement>
                ))}
              </div>
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