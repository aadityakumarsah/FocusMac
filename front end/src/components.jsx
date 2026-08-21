import { useState } from "react";
import { Link, NavLink } from "react-router-dom";
import { installCommand, navLinks, RELEASES_URL, REPO_URL } from "./data";
import { useReveal } from "./hooks";

export function Logo() {
  return (
    <Link to="/" className="logo" aria-label="FocusMac home">
      <img src="/focusmac-icon.png" alt="" />
      <span>
        Focus<b>Mac</b>
      </span>
    </Link>
  );
}

export function Reveal({ as: Tag = "div", className = "", children }) {
  const ref = useReveal();
  return (
    <Tag ref={ref} className={`reveal ${className}`}>
      {children}
    </Tag>
  );
}

export function Header() {
  const [open, setOpen] = useState(false);

  return (
    <header className="header">
      <div className="shell header-inner">
        <Logo />
        <button
          type="button"
          className={`burger ${open ? "on" : ""}`}
          aria-label="Menu"
          aria-expanded={open}
          onClick={() => setOpen((v) => !v)}
        >
          <span />
          <span />
        </button>
        <nav className={open ? "on" : ""}>
          {navLinks.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              onClick={() => setOpen(false)}
              className={({ isActive }) => (isActive ? "active" : undefined)}
            >
              {link.label}
            </NavLink>
          ))}
          <a href={REPO_URL} target="_blank" rel="noreferrer" onClick={() => setOpen(false)}>
            GitHub
          </a>
          <Link className="btn btn-dark nav-cta" to="/install" onClick={() => setOpen(false)}>
            Get FocusMac
          </Link>
        </nav>
      </div>
    </header>
  );
}

export function Footer() {
  return (
    <footer className="footer">
      <div className="shell footer-inner">
        <div>
          <Logo />
          <p>AI focus guardian for macOS. Local-first. MIT.</p>
        </div>
        <div className="footer-links">
          <Link to="/features">Features</Link>
          <Link to="/how-it-works">How it works</Link>
          <Link to="/install">Install</Link>
          <a href={REPO_URL} target="_blank" rel="noreferrer">
            GitHub
          </a>
          <a href={RELEASES_URL} target="_blank" rel="noreferrer">
            Releases
          </a>
        </div>
        <p className="copy">© 2026 FocusMac</p>
      </div>
    </footer>
  );
}

export function Toast({ message }) {
  if (!message) return null;
  return (
    <div className="toast" role="status">
      {message}
    </div>
  );
}

export async function copyInstall(setToast) {
  try {
    await navigator.clipboard.writeText(installCommand);
    setToast("Copied — paste into Terminal on your Mac.");
  } catch {
    setToast("Copy failed — select the command on the Install page.");
  }
  window.setTimeout(() => setToast(""), 3200);
}
