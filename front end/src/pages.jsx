import { useRef, useState } from "react";
import { Link } from "react-router-dom";
import { Reveal } from "./components";
import {
  benchmarks,
  faq,
  features,
  installCommand,
  loop,
  pillars,
  RELEASES_URL,
  REPO_URL,
  setupWizard,
  stats,
  steps,
} from "./data";
import { useHashScroll } from "./hooks";

function DemoVideo() {
  const ref = useRef(null);
  const [playing, setPlaying] = useState(false);

  return (
    <div className={`demo ${playing ? "playing" : ""}`}>
      <video
        ref={ref}
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
        <button type="button" className="demo-play" onClick={() => ref.current?.play()}>
          <span>Play demo</span>
        </button>
      )}
    </div>
  );
}

function Terminal({ onCopy }) {
  return (
    <div className="term">
      <div className="term-bar">
        <div className="dots" aria-hidden="true">
          <i />
          <i />
          <i />
        </div>
        <span>install — zsh</span>
        <button type="button" onClick={onCopy}>
          Copy
        </button>
      </div>
      <pre>
        <code>
          <span className="c">$</span> git clone https://github.com/aadityakumarsah/FocusMac.git{"\n"}
          <span className="c">$</span> cd FocusMac && ./scripts/install.sh{"\n"}
          <span className="ok">✓ Installed → /Applications/FocusMac.app</span>
        </code>
      </pre>
    </div>
  );
}

function FaqList() {
  const [open, setOpen] = useState(0);

  return (
    <div className="faq" id="faq">
      {faq.map((item, i) => (
        <div key={item.q} className={`faq-item ${open === i ? "open" : ""}`}>
          <button type="button" onClick={() => setOpen(open === i ? -1 : i)}>
            {item.q}
            <span>{open === i ? "−" : "+"}</span>
          </button>
          <p>{item.a}</p>
        </div>
      ))}
    </div>
  );
}

export function HomePage({ onCopy }) {
  useHashScroll();

  return (
    <>
      <section className="hero shell">
        <Reveal className="hero-text">
          <p className="kicker">FocusMac for macOS</p>
          <h1>
            Deep work that
            <br />
            <em>actually sticks.</em>
          </h1>
          <p className="lede">
            An AI focus guardian that watches what you do, enforces your schedule, checks you’re at
            your desk, and locks itself so you can’t cheat.
          </p>
          <div className="actions">
            <button type="button" className="btn btn-dark" onClick={onCopy}>
              Copy install command
            </button>
            <Link className="btn btn-line" to="/features">
              See features
            </Link>
          </div>
          <p className="fine">macOS 13+ · local-first · MIT · no account</p>
        </Reveal>

        <Reveal className="hero-visual">
          <DemoVideo />
        </Reveal>
      </section>

      <section className="stats-band">
        <div className="shell stats">
          {stats.map((s) => (
            <div key={s.label}>
              <strong>{s.value}</strong>
              <span>{s.label}</span>
            </div>
          ))}
        </div>
      </section>

      <section className="shell section">
        <Reveal className="section-head">
          <p className="kicker">Why FocusMac</p>
          <h2>Four systems. One guardrail.</h2>
        </Reveal>
        <div className="pillars">
          {pillars.map((p) => (
            <Reveal key={p.n} className="pillar" as="article">
              <span>{p.n}</span>
              <h3>{p.title}</h3>
              <p>{p.text}</p>
            </Reveal>
          ))}
        </div>
      </section>

      <section className="band">
        <div className="shell section split">
          <Reveal>
            <p className="kicker">Install</p>
            <h2>
              One paste in
              <br />
              Terminal.
            </h2>
            <p className="lede narrow">
              No account wall. Copy the command, paste it, open FocusMac from Applications. Prefer a
              zip? Use GitHub Releases.
            </p>
            <div className="actions">
              <button type="button" className="btn btn-dark" onClick={onCopy}>
                Copy command
              </button>
              <a className="btn btn-line" href={RELEASES_URL} target="_blank" rel="noreferrer">
                Releases
              </a>
            </div>
            <ol className="steps">
              {steps.map((s) => (
                <li key={s.n}>
                  <b>{s.n}</b>
                  <div>
                    <strong>{s.title}</strong>
                    <span>{s.text}</span>
                  </div>
                </li>
              ))}
            </ol>
          </Reveal>
          <Reveal>
            <Terminal onCopy={onCopy} />
          </Reveal>
        </div>
      </section>

      <section className="shell section">
        <Reveal className="section-head">
          <p className="kicker">How it works</p>
          <h2>Snapshot → classify → enforce → verify.</h2>
        </Reveal>
        <div className="loop">
          {loop.map((item, i) => (
            <Reveal key={item.title} className="loop-item" as="article">
              <span>0{i + 1}</span>
              <h3>{item.title}</h3>
              <p>{item.text}</p>
            </Reveal>
          ))}
        </div>
        <div className="actions center">
          <Link className="btn btn-line" to="/how-it-works">
            Full setup guide
          </Link>
        </div>
      </section>

      <section className="shell section">
        <Reveal className="section-head">
          <p className="kicker">FAQ</p>
          <h2>Practical details.</h2>
        </Reveal>
        <FaqList />
      </section>

      <section className="shell cta">
        <Reveal>
          <h2>Protect your next deep hour.</h2>
          <p>Free, open source, and designed to stay out of your way until you drift.</p>
          <div className="actions center">
            <button type="button" className="btn btn-dark" onClick={onCopy}>
              Install FocusMac
            </button>
            <a className="btn btn-line" href={REPO_URL} target="_blank" rel="noreferrer">
              Star on GitHub
            </a>
          </div>
        </Reveal>
      </section>
    </>
  );
}

export function FeaturesPage({ onCopy }) {
  return (
    <>
      <section className="shell page-top">
        <Reveal>
          <p className="kicker">Features</p>
          <h1>
            Everything that keeps
            <br />
            <em>deep work honest.</em>
          </h1>
          <p className="lede">
            Classification, schedule, camera attendance, overlays, XP, and a password lock — built
            for people who are serious about what comes next.
          </p>
        </Reveal>
      </section>

      <section className="shell section">
        <div className="feature-grid">
          {features.map((f) => (
            <Reveal key={f.title} className="feature" as="article">
              <h3>{f.title}</h3>
              <p>{f.text}</p>
            </Reveal>
          ))}
        </div>
      </section>

      <section className="band">
        <div className="shell section">
          <Reveal className="section-head">
            <p className="kicker">Benchmarks</p>
            <h2>Quiet when you work.</h2>
            <p className="lede narrow">Apple M2 Pro · macOS 15 · release build · 8-hour simulation.</p>
          </Reveal>
          <div className="bench">
            {benchmarks.map((b) => (
              <Reveal key={b.metric} className="bench-item" as="article">
                <span>{b.metric}</span>
                <strong>{b.value}</strong>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="shell cta">
        <Reveal>
          <h2>Ready to install?</h2>
          <div className="actions center">
            <button type="button" className="btn btn-dark" onClick={onCopy}>
              Copy install command
            </button>
            <Link className="btn btn-line" to="/install">
              Install guide
            </Link>
          </div>
        </Reveal>
      </section>
    </>
  );
}

export function HowItWorksPage({ onCopy }) {
  return (
    <>
      <section className="shell page-top">
        <Reveal>
          <p className="kicker">How it works</p>
          <h1>
            Set it up once.
            <br />
            <em>Then forget setup.</em>
          </h1>
          <p className="lede">
            First launch is five clear steps. After that, sessions start from your schedule — not
            from willpower.
          </p>
        </Reveal>
      </section>

      <section className="shell section">
        <div className="wizard">
          {setupWizard.map((s) => (
            <Reveal key={s.n} className="wizard-row" as="article">
              <span>{s.n}</span>
              <div>
                <h3>{s.title}</h3>
                <p>{s.text}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </section>

      <section className="shell section">
        <Reveal className="section-head">
          <p className="kicker">Runtime</p>
          <h2>The loop.</h2>
        </Reveal>
        <div className="loop">
          {loop.map((item, i) => (
            <Reveal key={item.title} className="loop-item" as="article">
              <span>0{i + 1}</span>
              <h3>{item.title}</h3>
              <p>{item.text}</p>
            </Reveal>
          ))}
        </div>
      </section>

      <section className="shell cta">
        <Reveal>
          <h2>Install and run the wizard.</h2>
          <div className="actions center">
            <button type="button" className="btn btn-dark" onClick={onCopy}>
              Copy install command
            </button>
          </div>
        </Reveal>
      </section>
    </>
  );
}

export function InstallPage({ onCopy }) {
  const lines = installCommand.split(" && ");

  return (
    <>
      <section className="shell page-top">
        <Reveal>
          <p className="kicker">Install</p>
          <h1>
            Copy. Paste.
            <br />
            <em>Start focusing.</em>
          </h1>
          <p className="lede">
            Terminal install is the recommended path. Or download a release zip and drag FocusMac.app
            into Applications.
          </p>
        </Reveal>
      </section>

      <section className="shell section install-layout">
        <Reveal>
          <div className="prompt-box">
            <p className="kicker light">Install prompt</p>
            {lines.map((line, i) => (
              <p key={line} className="prompt-line">
                <span>{i === 0 ? "$" : "↳"}</span> {line}
              </p>
            ))}
            <button type="button" className="btn btn-light" onClick={onCopy}>
              Copy command
            </button>
          </div>
        </Reveal>
        <Reveal>
          <Terminal onCopy={onCopy} />
          <ol className="steps tight">
            {steps.map((s) => (
              <li key={s.n}>
                <b>{s.n}</b>
                <div>
                  <strong>{s.title}</strong>
                  <span>{s.text}</span>
                </div>
              </li>
            ))}
          </ol>
          <p className="fine">
            Prefer a binary?{" "}
            <a href={RELEASES_URL} target="_blank" rel="noreferrer">
              GitHub Releases →
            </a>
          </p>
        </Reveal>
      </section>
    </>
  );
}
