import { useEffect, useState } from "react";
import { Link, NavLink, useLocation } from "react-router-dom";
import { installCommand, nav, RELEASES_URL, REPO_URL } from "./data";
import { useReveal } from "./hooks";

export function Logo({ large = false }) {
  return (
    <Link to="/" className={`brand ${large ? "brand-lg" : ""}`} aria-label="FocusMac">
      <img src="/focusmac-icon.png" alt="" />
      <span>
        focus<em>mac</em>
      </span>
    </Link>
  );
}

export function Reveal({ as: Tag = "div", className = "", children }) {
  const ref = useReveal(0.12);
  return (
    <Tag ref={ref} className={`rv ${className}`}>
      {children}
    </Tag>
  );
}

export function Header() {
  const [open, setOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const { pathname } = useLocation();

  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header className={`top ${scrolled ? "scrolled" : ""}`}>
      <div className="wrap top-inner">
        <Logo />
        <button
          type="button"
          className={`menu ${open ? "on" : ""}`}
          aria-label="Menu"
          aria-expanded={open}
          onClick={() => setOpen((v) => !v)}
        >
          <i />
          <i />
        </button>
        <nav className={open ? "on" : ""}>
          {nav.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => (isActive ? "active" : undefined)}
            >
              {item.label}
            </NavLink>
          ))}
          <a href={REPO_URL} target="_blank" rel="noreferrer">
            GitHub
          </a>
          <Link className="pill-btn" to="/install">
            Install
          </Link>
        </nav>
      </div>
    </header>
  );
}

export function Footer() {
  return (
    <footer className="foot">
      <div className="wrap foot-grid">
        <div>
          <Logo />
          <p>AI focus guardian for macOS. Local-first. Open source.</p>
        </div>
        <div className="foot-cols">
          <div>
            <h4>Product</h4>
            <Link to="/features">Features</Link>
            <Link to="/how-it-works">How it works</Link>
            <Link to="/install">Install</Link>
          </div>
          <div>
            <h4>Resources</h4>
            <a href={REPO_URL} target="_blank" rel="noreferrer">
              GitHub
            </a>
            <a href={RELEASES_URL} target="_blank" rel="noreferrer">
              Releases
            </a>
            <Link to="/#faq">FAQ</Link>
          </div>
        </div>
      </div>
      <div className="wrap foot-base">
        <span>© 2026 FocusMac · MIT</span>
        <span>macOS 13+</span>
      </div>
    </footer>
  );
}

export function Toast({ message }) {
  if (!message) return null;
  return <div className="toast">{message}</div>;
}

export async function copyInstall(setToast) {
  try {
    await navigator.clipboard.writeText(installCommand);
    setToast("Copied. Paste into Terminal — watch it download.");
  } catch {
    setToast("Copy failed — use the Install page.");
  }
  window.setTimeout(() => setToast(""), 3000);
}
