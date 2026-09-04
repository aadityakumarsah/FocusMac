import { useState, useEffect } from "react";
import { Link, NavLink, useLocation } from "react-router-dom";
import { installCommand, REPO_URL, RELEASES_URL } from "./data";

export function Logo() {
  return (
    <Link to="/" className="logo" aria-label="FocusMac">
      <img src="/focusmac-icon.png" alt="" />
      <span>focus<span>mac</span></span>
    </Link>
  );
}

export function Header() {
  const [open, setOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const { pathname } = useLocation();

  const nav = [
    { to: "/features", label: "Features" },
    { to: "/how-it-works", label: "How it works" },
    { to: "/install", label: "Install" }
  ];

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 50);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <header className={`header ${scrolled ? 'scrolled' : ''}`}>
      <div className="container header-inner">
        <Logo />
        <nav className={open ? "open" : ""}>
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
          <Link className="cta-button" to="/install">
            Install
          </Link>
        </nav>
        <button
          className="menu-button"
          aria-label="Menu"
          aria-expanded={open}
          onClick={() => setOpen((v) => !v)}
        >
          <span />
          <span />
        </button>
      </div>
    </header>
  );
}

export function Footer() {
  return (
    <footer className="footer">
      <div className="container">
        <div className="footer-grid">
          <div className="footer-brand">
            <Logo />
            <p>AI focus guardian for macOS. Local-first. Open source.</p>
          </div>
          <div className="footer-col">
            <h4>Product</h4>
            <Link to="/features">Features</Link>
            <Link to="/how-it-works">How it works</Link>
            <Link to="/install">Install</Link>
          </div>
          <div className="footer-col">
            <h4>Resources</h4>
            <a href={REPO_URL} target="_blank" rel="noreferrer">
              GitHub
            </a>
            <a href={RELEASES_URL} target="_blank" rel="noreferrer">
              Releases
            </a>
            <Link to="/#faq">FAQ</Link>
          </div>
          <div className="footer-col">
            <h4>Legal</h4>
            <a href="#" onClick={(e) => e.preventDefault()}>Privacy</a>
            <a href="#" onClick={(e) => e.preventDefault()}>Terms</a>
            <a href="#" onClick={(e) => e.preventDefault()}>License</a>
          </div>
        </div>
        <div className="footer-bottom">
          <span>© 2026 FocusMac · MIT</span>
          <span>macOS 13+</span>
        </div>
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
    setToast("Copied to clipboard");
  } catch {
    setToast("Failed to copy");
  }
  window.setTimeout(() => setToast(""), 3000);
}