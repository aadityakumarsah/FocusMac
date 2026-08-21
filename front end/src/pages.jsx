import { useRef, useState } from "react";
import { Link } from "react-router-dom";
import {
  AppleIcon,
  InstallButton,
  LogoWord,
  PageHero,
  Reveal,
  StarButton,
} from "./components";
import {
  activityCards,
  allFeatures,
  featurePillars,
  faqItems,
  focusMetrics,
  installCommand,
  orbitApps,
  RELEASES_URL,
  runtimeBenchmarks,
  scheduleBlocks,
  setupSteps,
  sidebarItems,
} from "./data";
import { useHashScroll } from "./hooks";

function TrustPill() {
  return (
    <div className="yc-badge trust-pill">
      <img src="/focusmac-icon.png" alt="" />
      <span>Local-first · macOS 13+ · MIT open source</span>
    </div>
  );
}

function OrbitHero({ onCopy }) {
  return (
    <section className="hero">
      <div className="hero-drops" aria-hidden="true">
        {Array.from({ length: 18 }).map((_, i) => (
          <span key={i} className="float-drop" style={{ "--i": i }} />
        ))}
      </div>

      <div className="hero-orbit" aria-hidden="true">
        <div className="orbit-ring orbit-ring-a" />
        <div className="orbit-ring orbit-ring-b" />
        <div className="orbit-ring orbit-ring-c" />
        {orbitApps.map((app, index) => (
          <div
            key={app.name}
            className="orbit-icon"
            style={{ "--index": index, "--count": orbitApps.length, "--color": app.color }}
            title={app.name}
          >
            <span>{app.letter}</span>
          </div>
        ))}
      </div>

      <div className="container hero-copy">
        <TrustPill />
        <h1>
          <span className="line-ink">stop fighting distractions.</span>
          <span className="line-blue">start protecting focus.</span>
        </h1>
        <p className="hero-pill">
          FocusMac watches what you’re doing, understands it with AI, enforces your weekly schedule,
          verifies you’re at your desk — and makes sure you can’t cheat your way out.
        </p>
        <div className="hero-actions">
          <InstallButton label="Install" onCopy={onCopy} />
          <StarButton />
        </div>
        <p className="hero-micro">
          Copy the Terminal prompt · drag FocusMac to Applications · no account required.
        </p>
      </div>
    </section>
  );
}

function DashboardPreview() {
  return (
    <Reveal className="product-frame agents-frame" as="section">
      <aside className="app-sidebar">
        <div className="sidebar-brand">
          <LogoWord />
        </div>
        <ul>
          {sidebarItems.map((item, index) => (
            <li key={item} className={index === 0 ? "active" : undefined}>
              {item}
            </li>
          ))}
        </ul>
      </aside>

      <div className="app-main">
        <div className="agent-head">
          <div>
            <p className="eyebrow soft">Live session</p>
            <h3>Study — 1:43:09 left</h3>
          </div>
          <span className="status-pill">
            <i /> guarding
          </span>
        </div>

        <div className="metric-row">
          {focusMetrics.map((m) => (
            <div key={m.label}>
              <strong>{m.value}</strong>
              <span>{m.label}</span>
            </div>
          ))}
        </div>

        <div className="trigger-scroll">
          {activityCards.map((card) => (
            <article key={card.name} className={`trigger-card tone-${card.tone}`}>
              <div className="avatar">{card.name.slice(0, 1)}</div>
              <div>
                <b>{card.name}</b>
                <small>{card.role}</small>
                <p>{card.trigger}</p>
              </div>
              <em>{card.score}</em>
            </article>
          ))}
        </div>

        <div className="draft-panel">
          <div className="draft-top">
            <span>Block overlay · ready</span>
            <div>
              <button type="button" className="mini-btn">
                Lifeline
              </button>
              <button type="button" className="mini-btn primary">
                Close tab
              </button>
            </div>
          </div>
          <p>
            YouTube Shorts doesn’t match this Study block. FocusMac can warn, alarm, then full-screen
            block — and close the tab when you approve the escalation.
          </p>
        </div>

        <p className="product-caption">
          your schedule decides the boundary. nothing unlocks without your password — and camera
          checks stay on your Mac.
        </p>
      </div>
    </Reveal>
  );
}

function SchedulePanel() {
  return (
    <Reveal className="split-section container" as="section" delay={80}>
      <div className="split-copy">
        <p className="eyebrow">Schedule-first</p>
        <h2>Your week becomes the boundary.</h2>
        <p>
          Enter study, work, free-time, meals, and sleep once. FocusMac enforces during deep blocks
          and gets out of the way when you’re free.
        </p>
        <Link className="text-link" to="/how-it-works">
          See setup →
        </Link>
      </div>

      <div className="find-card">
        <div className="find-query">THURSDAY · your day</div>
        <div className="schedule-stack">
          {scheduleBlocks.map((block) => (
            <div key={block.title} className={`viz-block ${block.tone} ${block.live ? "is-live" : ""}`}>
              {block.title}
              <small>{block.time}</small>
              {block.live && <i>NOW</i>}
            </div>
          ))}
        </div>
        <div className="chip-row">
          {["Deep work", "Free time", "Meals", "Sleep"].map((chip) => (
            <span key={chip}>{chip}</span>
          ))}
        </div>
      </div>
    </Reveal>
  );
}

function DemoSection() {
  const [playing, setPlaying] = useState(false);
  const videoRef = useRef(null);

  return (
    <Reveal className="review-section container" as="section">
      <div className="section-head center">
        <p className="eyebrow">Product tour</p>
        <h2>See the guardrail in motion.</h2>
      </div>

      <div className={`video-stage ${playing ? "is-playing" : ""}`}>
        <video
          ref={videoRef}
          controls={playing}
          playsInline
          preload="metadata"
          poster="/focusmac-logo.png"
          onPlay={() => setPlaying(true)}
          onPause={() => setPlaying(false)}
        >
          <source src="/demo-video.mov" type="video/quicktime" />
          <source src="/demo-video.mov" type="video/mp4" />
        </video>
        {!playing && (
          <button
            type="button"
            className="play-overlay"
            onClick={() => videoRef.current?.play()}
            aria-label="Play demo"
          >
            <span className="play-orb">▶</span>
            <b>Watch the product tour</b>
          </button>
        )}
        <div className="video-meta">DEMO · replace via public/demo-video.mov</div>
      </div>
    </Reveal>
  );
}

function ReviewLockSection() {
  return (
    <Reveal className="review-section container" as="section">
      <div className="section-head center">
        <p className="eyebrow">Uncheatable lock</p>
        <h2>Focus mode stays on. Quitting needs your password.</h2>
      </div>

      <div className="review-card">
        <div className="review-meta">
          <div className="avatar">⌘</div>
          <div>
            <b>Password gate</b>
            <small>SHA-256 · no recovery backdoor</small>
          </div>
        </div>
        <div className="thread">
          <div className="bubble them">Quit FocusMac? Enter lock password.</div>
          <div className="bubble us">Camera off requires password.</div>
          <div className="bubble draft">
            3 lifelines left today
            <em>honest pauses · all logged</em>
          </div>
        </div>
        <div className="review-actions">
          <Link className="btn btn-primary" to="/features">
            Explore lock & camera
          </Link>
          <Link className="btn btn-ghost" to="/install">
            Install FocusMac
          </Link>
        </div>
      </div>
    </Reveal>
  );
}

function BenchmarkStrip() {
  return (
    <Reveal className="calendar-section container" as="section" id="benchmarks">
      <div className="section-head center">
        <h2>Light on the machine. Heavy on enforcement.</h2>
        <p>Measured on Apple M2 Pro, macOS 15, release build — 8-hour workday simulation.</p>
      </div>
      <div className="metric-row bench-row">
        {runtimeBenchmarks.map((row) => (
          <div key={row.metric} className="bench-tile">
            <span>{row.metric}</span>
            <strong>{row.value}</strong>
            <small>{row.note}</small>
          </div>
        ))}
      </div>
    </Reveal>
  );
}

function IntegrationsSection() {
  return (
    <Reveal className="integrations-section container" as="section">
      <div className="section-head center">
        <h2>Works with the apps you already live in.</h2>
        <p>Browser automation, media pause, menu bar control — plus local camera attendance.</p>
      </div>

      <div className="neural-map" aria-hidden="true">
        <svg className="neural-lines" viewBox="0 0 640 360" preserveAspectRatio="xMidYMid meet">
          {[
            [120, 70],
            [320, 36],
            [520, 70],
            [100, 250],
            [320, 300],
            [540, 250],
          ].map(([x, y], i) => (
            <g key={i}>
              <line x1="320" y1="180" x2={x} y2={y} className="glow-line" />
              <circle cx={x} cy={y} r="3" className="glow-dot" />
            </g>
          ))}
        </svg>

        <div className="neural-core brand-core">
          <img src="/focusmac-icon.png" alt="" />
          <span>FocusMac</span>
        </div>

        {orbitApps.map((app, index) => (
          <div
            key={app.name}
            className="neural-app"
            style={{ "--index": index, "--color": app.color }}
          >
            <span>{app.letter}</span>
            <small>{app.name}</small>
          </div>
        ))}
      </div>
    </Reveal>
  );
}

function Pillars() {
  return (
    <Reveal className="usecase-strip container" as="section">
      {featurePillars.map((pillar) => (
        <div key={pillar.title} className="usecase-card">
          <h3>{pillar.title}</h3>
          <p>{pillar.text}</p>
          <div>
            <Link to="/features">See features</Link>
            <Link to="/how-it-works">How it works</Link>
          </div>
        </div>
      ))}
    </Reveal>
  );
}

function DetailsFaq() {
  const [open, setOpen] = useState(0);

  return (
    <section className="faq-section container" id="faq">
      <Reveal className="section-head">
        <p className="eyebrow">A few practical details</p>
        <h2>Built to protect attention — privately on your Mac.</h2>
      </Reveal>

      <div className="faq-list">
        {faqItems.map((item, index) => {
          const isOpen = open === index;
          return (
            <Reveal key={item.q} className={`faq-item ${isOpen ? "is-open" : ""}`} delay={index * 40}>
              <button type="button" onClick={() => setOpen(isOpen ? -1 : index)}>
                <span>{item.q}</span>
                <i>{isOpen ? "−" : "+"}</i>
              </button>
              <div className="faq-body">
                <p>{item.a}</p>
              </div>
            </Reveal>
          );
        })}
      </div>
    </section>
  );
}

function TerminalInstall({ onCopy }) {
  return (
    <Reveal className="terminal-band container" as="section">
      <div className="terminal-copy">
        <p className="eyebrow">Install from Terminal</p>
        <h2>
          Not a DMG hunt.
          <br />
          <span className="line-blue">One paste.</span>
        </h2>
        <p>
          Copy the prompt, open Terminal, paste it. The script builds FocusMac and drops it in
          Applications.
        </p>
        <div className="hero-actions left">
          <button type="button" className="btn btn-primary" onClick={onCopy}>
            <AppleIcon />
            Copy install command
            <span className="btn-arrow">→</span>
          </button>
          <Link className="btn btn-ghost" to="/install">
            Full install guide
          </Link>
        </div>
      </div>

      <div className="terminal-card">
        <div className="terminal-bar">
          <div className="traffic">
            <i />
            <i />
            <i />
          </div>
          <span>zsh — FocusMac install</span>
          <button type="button" onClick={onCopy}>
            Copy
          </button>
        </div>
        <div className="terminal-body">
          <p>
            <span className="prompt">you@mac</span>
            <span className="dim"> ~ %</span> <b>git clone</b> https://github.com/aadityakumarsah/FocusMac.git
          </p>
          <p>
            <span className="prompt">you@mac</span>
            <span className="dim"> ~ %</span> <b>cd</b> FocusMac && ./scripts/install.sh
          </p>
          <p className="ok">✓ Built FocusMac.app</p>
          <p className="ok">✓ Installed → /Applications/FocusMac.app</p>
          <p className="ok">✓ Opening FocusMac…</p>
        </div>
        <div className="terminal-rail">
          <span>
            <b>01</b> copy
          </span>
          <span>
            <b>02</b> paste in Terminal
          </span>
          <span>
            <b>03</b> open from Applications
          </span>
        </div>
      </div>
    </Reveal>
  );
}

function FinalCta({ onCopy }) {
  return (
    <Reveal className="final-cta container" as="section">
      <h2>Protect your next deep hour.</h2>
      <p>macOS 13+ · no account · your data stays yours.</p>
      <div className="hero-actions">
        <InstallButton label="Install FocusMac" onCopy={onCopy} />
        <StarButton />
      </div>
    </Reveal>
  );
}

export function HomePage({ onCopy }) {
  useHashScroll();

  return (
    <>
      <OrbitHero onCopy={onCopy} />
      <section className="container product-intro">
        <Reveal className="section-head">
          <p className="eyebrow">Dashboard</p>
          <h2>A quiet operating system for attention.</h2>
          <p>
            Classification, schedule enforcement, camera attendance, blocking, XP, and an uncheatable
            lock — designed so good intentions stick.
          </p>
        </Reveal>
        <DashboardPreview />
      </section>
      <SchedulePanel />
      <DemoSection />
      <ReviewLockSection />
      <BenchmarkStrip />
      <IntegrationsSection />
      <Pillars />
      <TerminalInstall onCopy={onCopy} />
      <DetailsFaq />
      <FinalCta onCopy={onCopy} />
    </>
  );
}

export function FeaturesPage({ onCopy }) {
  return (
    <>
      <PageHero
        eyebrow="Features"
        title={
          <>
            Everything that keeps
            <br />
            <span className="line-blue">deep work honest.</span>
          </>
        }
        copy="AI classification, schedule blocks, YOLO attendance, overlays, XP, and a password lock that won’t let you cheat."
      />
      <section className="container feature-mosaic">
        {allFeatures.map((feature, index) => (
          <Reveal key={feature.title} className="mosaic-card" delay={(index % 4) * 40} as="article">
            <span>{feature.icon}</span>
            <h3>{feature.title}</h3>
            <p>{feature.text}</p>
          </Reveal>
        ))}
      </section>
      <div id="benchmarks">
        <BenchmarkStrip />
      </div>
      <FinalCta onCopy={onCopy} />
    </>
  );
}

export function HowItWorksPage({ onCopy }) {
  return (
    <>
      <PageHero
        eyebrow="How it works"
        title={
          <>
            Set it up once.
            <br />
            <span className="line-blue">Then forget the setup.</span>
          </>
        }
        copy="Snapshot → classify → enforce → verify. First launch is five clear steps; after that sessions follow your schedule."
      />
      <section className="container setup-rail">
        {setupSteps.map((step, index) => (
          <Reveal key={step.n} className="setup-step" delay={index * 60} as="article">
            <span className="setup-n">{step.n}</span>
            <div>
              <h3>{step.title}</h3>
              <p>{step.text}</p>
            </div>
            <i aria-hidden="true">{index === setupSteps.length - 1 ? "✓" : "↓"}</i>
          </Reveal>
        ))}
      </section>
      <TerminalInstall onCopy={onCopy} />
      <FinalCta onCopy={onCopy} />
    </>
  );
}

export function InstallPage({ onCopy }) {
  const lines = installCommand.split(" && ");

  return (
    <>
      <PageHero
        eyebrow="Install"
        title={
          <>
            Copy. Paste.
            <br />
            <span className="line-blue">Start your day.</span>
          </>
        }
        copy="No account maze. A Terminal prompt you copy once, paste once, then open from Applications."
      />

      <Reveal className="container download-panel" as="section">
        <div className="install-panel">
          <div className="command-label">YOUR INSTALL PROMPT</div>
          {lines.map((line, index) => (
            <p key={line}>
              <span>{index === 0 ? "$" : "↳"}</span> {line}
            </p>
          ))}
          <button type="button" className="btn btn-primary" onClick={onCopy}>
            <AppleIcon />
            Copy command
            <span className="btn-arrow">→</span>
          </button>
          <small>After install, the 5-step wizard asks for password, schedule, permissions, and AI.</small>
        </div>

        <div className="download-steps">
          <article>
            <span>01</span>
            <h4>Copy the prompt</h4>
            <p>One click puts clone + install on your clipboard.</p>
          </article>
          <article>
            <span>02</span>
            <h4>Paste into Terminal</h4>
            <p>Hit return. FocusMac builds and installs for you.</p>
          </article>
          <article>
            <span>03</span>
            <h4>Open from Applications</h4>
            <p>Or grab a zip from GitHub Releases and drag FocusMac.app in yourself.</p>
          </article>
        </div>

        <div className="download-card">
          <div className="download-icon">
            <img src="/focusmac-icon.png" alt="" />
          </div>
          <div>
            <h3>Prefer a release zip?</h3>
            <p>Download from GitHub Releases, unzip, drag to Applications.</p>
          </div>
          <a className="btn btn-ghost" href={RELEASES_URL} target="_blank" rel="noreferrer">
            Open Releases
          </a>
        </div>
      </Reveal>
    </>
  );
}
