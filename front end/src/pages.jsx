import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { Logo, Reveal } from "./components";
import {
  benches,
  faq,
  featureList,
  flow,
  installCommand,
  proof,
  RELEASES_URL,
  REPO_URL,
  stories,
  wizard,
} from "./data";
import { useHashScroll } from "./hooks";

function MacFrame({ children, title = "FocusMac — demo" }) {
  return (
    <div className="mac">
      <div className="mac-bar">
        <div className="traffic" aria-hidden="true">
          <span />
          <span />
          <span />
        </div>
        <p>{title}</p>
        <i />
      </div>
      <div className="mac-body">{children}</div>
    </div>
  );
}

function Demo() {
  const ref = useRef(null);
  const [playing, setPlaying] = useState(false);

  useEffect(() => {
    const video = ref.current;
    if (!video) return undefined;
    const tryPlay = async () => {
      try {
        video.muted = true;
        await video.play();
        setPlaying(true);
      } catch {
        /* autoplay blocked — user can tap */
      }
    };
    tryPlay();
    return undefined;
  }, []);

  return (
    <MacFrame>
      <div className={`stage ${playing ? "on" : ""}`}>
        <video
          ref={ref}
          muted
          playsInline
          loop
          preload="auto"
          poster="/focusmac-logo.png"
          onPlay={() => setPlaying(true)}
          onPause={() => setPlaying(false)}
        >
          <source src="/demo-video.mov" type="video/mp4" />
          <source src="/demo-video.mov" type="video/quicktime" />
        </video>
        {!playing && (
          <button
            type="button"
            className="play"
            onClick={async () => {
              const v = ref.current;
              if (!v) return;
              v.muted = false;
              await v.play();
            }}
          >
            <b />
            Watch demo
          </button>
        )}
        {playing && (
          <button
            type="button"
            className="sound"
            onClick={() => {
              const v = ref.current;
              if (!v) return;
              v.muted = !v.muted;
            }}
          >
            Unmute / mute
          </button>
        )}
      </div>
    </MacFrame>
  );
}

function Term({ onCopy }) {
  const [pct, setPct] = useState(0);
  const [phase, setPhase] = useState("idle"); // idle | download | open | done
  const [frame, setFrame] = useState(0);

  useEffect(() => {
    let raf;
    let start;
    const loop = (t) => {
      if (start == null) start = t;
      const elapsed = (t - start) % 5200;
      setFrame(Math.floor(t / 80));
      if (elapsed < 2800) {
        setPhase("download");
        setPct(Math.min(100, Math.round((elapsed / 2800) * 100)));
      } else if (elapsed < 3600) {
        setPhase("open");
        setPct(100);
      } else {
        setPhase("done");
        setPct(100);
      }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, []);

  const filled = Math.round((pct / 100) * 22);
  const bar = "█".repeat(filled) + "░".repeat(22 - filled);
  const spin = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"[frame % 10];

  return (
    <div className="term">
      <div className="term-top">
        <div className="traffic">
          <span />
          <span />
          <span />
        </div>
        <p>zsh — FocusMac</p>
        <button type="button" onClick={onCopy}>
          Copy
        </button>
      </div>
      <pre>
        <code>
          <span className="p">➜</span> curl -fsSL …/download.sh | bash{"\n\n"}
          {phase === "download" && (
            <>
              <span className="g">↓</span>  <span className="p">{bar}</span>  {pct}%{"\n"}
              {"  "}
              <span className="p">{spin}</span> downloading FocusMac.dmg{"\n"}
            </>
          )}
          {phase === "open" && (
            <>
              <span className="g">✓</span>  download complete{"\n"}
              {"  "}
              <span className="p">{spin}</span> opening disk image…{"\n"}
            </>
          )}
          {phase === "done" && (
            <>
              <span className="g">✓</span>  download complete{"\n"}
              <span className="g">✓</span>  opened ~/Downloads/FocusMac.dmg{"\n\n"}
              <span className="g">Ready.</span> Drag FocusMac → Applications
            </>
          )}
        </code>
      </pre>
    </div>
  );
}

function FaqBlock() {
  const [open, setOpen] = useState(0);
  return (
    <div className="faq" id="faq">
      {faq.map(([q, a], i) => (
        <div key={q} className={open === i ? "open" : ""}>
          <button type="button" onClick={() => setOpen(open === i ? -1 : i)}>
            <span>{q}</span>
            <em>{open === i ? "−" : "+"}</em>
          </button>
          <p>{a}</p>
        </div>
      ))}
    </div>
  );
}

export function HomePage({ onCopy }) {
  useHashScroll();

  return (
    <>
      <section className="hero">
        <div className="hero-glow" aria-hidden="true" />
        <div className="wrap hero-copy">
          <Reveal>
            <img className="hero-mark" src="/focusmac-logo.png" alt="focusmac" />
            <h1>
              The focus app that
              <br />
              <span>won’t let you quit.</span>
            </h1>
            <p className="sub">
              AI watches your work, enforces your schedule, checks you’re at your desk, and
              password-locks itself so distractions don’t win.
            </p>
            <div className="row">
              <button type="button" className="btn primary" onClick={onCopy}>
                Copy install command
              </button>
              <Link className="btn ghost" to="/features">
                Explore features
              </Link>
            </div>
            <p className="micro">macOS 13+ · local-first · MIT · no account</p>
          </Reveal>
        </div>
        <div className="wrap hero-demo">
          <Reveal>
            <Demo />
          </Reveal>
        </div>
      </section>

      <section className="proof">
        <div className="wrap proof-grid">
          {proof.map((item) => (
            <div key={item.label}>
              <strong>{item.value}</strong>
              <span>{item.label}</span>
            </div>
          ))}
        </div>
      </section>

      <section className="wrap stories">
        {stories.map((s, i) => (
          <Reveal key={s.tag} className={`story ${i % 2 ? "flip" : ""}`} as="article">
            <div className="story-text">
              <p className="tag">{s.tag}</p>
              <h2>{s.title}</h2>
              <p>{s.text}</p>
            </div>
            <div className={`story-art art-${i}`} aria-hidden="true">
              {i === 0 && (
                <div className="day">
                  <b>Deep work</b>
                  <b className="free">Free</b>
                  <b className="live">Build · now</b>
                  <b className="gym">Gym</b>
                </div>
              )}
              {i === 1 && (
                <div className="classify">
                  <div>
                    <span>Cursor</span>
                    <em className="good">aligned</em>
                  </div>
                  <div>
                    <span>YouTube Shorts</span>
                    <em className="bad">blocked</em>
                  </div>
                  <div>
                    <span>docs · ambiguous</span>
                    <em className="mid">semantic</em>
                  </div>
                </div>
              )}
              {i === 2 && (
                <div className="cam">
                  <div className="face" />
                  <div className="states">
                    <i className="g">attentive</i>
                    <i className="a">phone</i>
                    <i className="r">away</i>
                  </div>
                </div>
              )}
              {i === 3 && (
                <div className="lock">
                  <div className="ring">LOCK</div>
                  <ul>
                    <li>quit → password</li>
                    <li>pause → password</li>
                    <li>camera → password</li>
                  </ul>
                </div>
              )}
            </div>
          </Reveal>
        ))}
      </section>

      <section className="install-band">
        <div className="wrap install-grid">
          <Reveal>
            <p className="tag">Install in 30 seconds</p>
            <h2>
              One paste.
              <br />
              Then Applications.
            </h2>
            <p className="sub tight">
              Copy the command, open Terminal, hit return. Watch the download, then drag FocusMac
              into Applications.
            </p>
            <div className="row">
              <button type="button" className="btn primary" onClick={onCopy}>
                Copy command
              </button>
              <a className="btn ghost" href={RELEASES_URL} target="_blank" rel="noreferrer">
                Releases
              </a>
            </div>
          </Reveal>
          <Reveal>
            <Term onCopy={onCopy} />
          </Reveal>
        </div>
      </section>

      <section className="wrap block">
        <Reveal className="block-head">
          <p className="tag">Runtime</p>
          <h2>Snapshot → classify → enforce → verify.</h2>
        </Reveal>
        <div className="flow">
          {flow.map((f, i) => (
            <Reveal key={f.title} className="flow-card" as="article">
              <span>0{i + 1}</span>
              <h3>{f.title}</h3>
              <p>{f.text}</p>
            </Reveal>
          ))}
        </div>
      </section>

      <section className="wrap block">
        <Reveal className="block-head">
          <p className="tag">FAQ</p>
          <h2>Straight answers.</h2>
        </Reveal>
        <FaqBlock />
      </section>

      <section className="finale">
        <div className="wrap">
          <Reveal>
            <Logo large />
            <h2>Protect the next deep hour.</h2>
            <div className="row center">
              <button type="button" className="btn primary" onClick={onCopy}>
                Install FocusMac
              </button>
              <a className="btn ghost" href={REPO_URL} target="_blank" rel="noreferrer">
                Star on GitHub
              </a>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}

export function FeaturesPage({ onCopy }) {
  return (
    <>
      <section className="wrap page">
        <Reveal>
          <p className="tag">Features</p>
          <h1>
            Every guardrail,
            <br />
            <span>named.</span>
          </h1>
          <p className="sub">
            From classification to camera lock — the full system that keeps deep work honest.
          </p>
        </Reveal>
      </section>

      <section className="wrap block">
        <div className="feat-grid">
          {featureList.map(([title, text]) => (
            <Reveal key={title} className="feat" as="article">
              <h3>{title}</h3>
              <p>{text}</p>
            </Reveal>
          ))}
        </div>
      </section>

      <section className="soft">
        <div className="wrap block">
          <Reveal className="block-head">
            <p className="tag">Benchmarks</p>
            <h2>Light footprint. Hard enforcement.</h2>
          </Reveal>
          <div className="bench">
            {benches.map(([metric, value]) => (
              <Reveal key={metric} className="bench-card" as="article">
                <span>{metric}</span>
                <strong>{value}</strong>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="finale slim">
        <div className="wrap">
          <Reveal>
            <h2>Install it.</h2>
            <div className="row center">
              <button type="button" className="btn primary" onClick={onCopy}>
                Copy install command
              </button>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}

export function HowItWorksPage({ onCopy }) {
  return (
    <>
      <section className="wrap page">
        <Reveal>
          <p className="tag">How it works</p>
          <h1>
            Five minutes once.
            <br />
            <span>Then automatic.</span>
          </h1>
        </Reveal>
      </section>

      <section className="wrap block">
        <div className="wizard">
          {wizard.map(([n, title, text]) => (
            <Reveal key={n} className="wiz" as="article">
              <span>{n}</span>
              <div>
                <h3>{title}</h3>
                <p>{text}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </section>

      <section className="soft">
        <div className="wrap block">
          <div className="flow">
            {flow.map((f, i) => (
              <Reveal key={f.title} className="flow-card" as="article">
                <span>0{i + 1}</span>
                <h3>{f.title}</h3>
                <p>{f.text}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="finale slim">
        <div className="wrap">
          <Reveal>
            <h2>Run the wizard tonight.</h2>
            <div className="row center">
              <button type="button" className="btn primary" onClick={onCopy}>
                Copy install command
              </button>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}

export function InstallPage({ onCopy }) {
  const parts = installCommand.split(" && ");
  return (
    <>
      <section className="wrap page">
        <Reveal>
          <p className="tag">Install</p>
          <h1>
            Copy.
            <br />
            <span>Paste. Focus.</span>
          </h1>
          <p className="sub">One Terminal paste. Beautiful progress, then drag into Applications.</p>
        </Reveal>
      </section>

      <section className="wrap install-page">
        <Reveal className="prompt">
          <p className="tag on-dark">Your prompt</p>
          {parts.map((line, i) => (
            <p key={line}>
              <span>{i === 0 ? "$" : "↳"}</span> {line}
            </p>
          ))}
          <button type="button" className="btn light" onClick={onCopy}>
            Copy command
          </button>
        </Reveal>
        <Reveal>
          <Term onCopy={onCopy} />
          <ol className="howto">
            <li>
              <b>1</b> Copy the prompt
            </li>
            <li>
              <b>2</b> Paste in Terminal — watch the download
            </li>
            <li>
              <b>3</b> Drag FocusMac → Applications
            </li>
          </ol>
          <p className="micro">
            Or download from{" "}
            <a href={RELEASES_URL} target="_blank" rel="noreferrer">
              GitHub Releases
            </a>
            .
          </p>
        </Reveal>
      </section>
    </>
  );
}
