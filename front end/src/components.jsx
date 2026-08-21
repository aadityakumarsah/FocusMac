import { useState } from "react";
import { Link, NavLink } from "react-router-dom";
import { footerColumns, installCommand, navLinks, RELEASES_URL, REPO_URL, SOCIAL } from "./data";
import { useReveal } from "./hooks";

export function LogoWord() {
  return (
    <span className="logo-word">
      <img src="/focusmac-icon.png" alt="" className="logo-icon" />
      Focus<span>Mac</span>
    </span>
  );
}

export function AppleIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor" aria-hidden="true">
      <path d="M11.2 7.3c0-1.6 1.3-2.4 1.4-2.5-.8-1.1-2-1.3-2.4-1.3-1-.1-2 .6-2.5.6-.5 0-1.4-.6-2.3-.6-1.2 0-2.3.7-2.9 1.8-1.2 2.2-.3 5.4.9 7.1.6.8 1.2 1.8 2.1 1.7.9 0 1.2-.5 2.2-.5s1.3.5 2.2.5c.9 0 1.5-.8 2.1-1.7.7-1 1-1.9 1-2 0 0-1.9-.7-1.8-2.1ZM9.5 2.7c.4-.5.8-1.4.7-2.2-.7 0-1.5.5-2 1-.4.5-.8 1.3-.7 2.1.8.1 1.6-.4 2-.9Z" />
    </svg>
  );
}

export function GitHubIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.65 7.65 0 0 1 2-.27c.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z" />
    </svg>
  );
}

export function Reveal({ as: Tag = "div", className = "", delay = 0, children }) {
  const ref = useReveal();
  return (
    <Tag
      ref={ref}
      className={`reveal ${className}`}
      style={delay ? { transitionDelay: `${delay}ms` } : undefined}
    >
      {children}
    </Tag>
  );
}

export function InstallButton({ className = "", label = "Install", onCopy }) {
  if (onCopy) {
    return (
      <button type="button" className={`btn btn-primary ${className}`} onClick={onCopy}>
        <AppleIcon />
        {label}
        <span className="btn-arrow">→</span>
      </button>
    );
  }
  return (
    <Link className={`btn btn-primary ${className}`} to="/install">
      <AppleIcon />
      {label}
      <span className="btn-arrow">→</span>
    </Link>
  );
}

export function StarButton({ className = "" }) {
  return (
    <a className={`btn btn-ghost ${className}`} href={REPO_URL} target="_blank" rel="noreferrer">
      <GitHubIcon />
      Star on GitHub
    </a>
  );
}

export function SiteHeader() {
  const [open, setOpen] = useState(false);

  return (
    <header className="site-header">
      <div className="nav-shell">
        <Link to="/" className="logo logo-nav" aria-label="FocusMac home" onClick={() => setOpen(false)}>
          <LogoWord />
        </Link>

        <nav className={`nav-center ${open ? "is-open" : ""}`} aria-label="Primary">
          {navLinks.map((link) =>
            link.hash ? (
              <a key={link.label} href={link.to} onClick={() => setOpen(false)}>
                {link.label}
              </a>
            ) : (
              <NavLink
                key={link.label}
                to={link.to}
                onClick={() => setOpen(false)}
                className={({ isActive }) => (isActive ? "active" : undefined)}
              >
                {link.label}
              </NavLink>
            ),
          )}
          <Link className="btn btn-primary nav-download-mobile" to="/install" onClick={() => setOpen(false)}>
            <AppleIcon />
            Install
            <span className="btn-arrow">→</span>
          </Link>
        </nav>

        <div className="nav-right">
          <InstallButton label="Install" />
          <button
            type="button"
            className={`menu-toggle ${open ? "is-open" : ""}`}
            aria-label="Menu"
            aria-expanded={open}
            onClick={() => setOpen((v) => !v)}
          >
            <span />
            <span />
          </button>
        </div>
      </div>
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="container footer-grid">
        <div className="footer-brand">
          <Link to="/" className="logo logo-nav">
            <LogoWord />
          </Link>
          <p>An AI-powered focus guardian for macOS.</p>
        </div>
        {footerColumns.map((col) => (
          <div key={col.title} className="footer-col">
            <h4>{col.title}</h4>
            <ul>
              {col.links.map((link) => (
                <li key={link.label}>
                  {link.external || link.href ? (
                    <a
                      href={link.href || link.to}
                      {...(link.external ? { target: "_blank", rel: "noreferrer" } : {})}
                    >
                      {link.label}
                    </a>
                  ) : (
                    <Link to={link.to}>{link.label}</Link>
                  )}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>

      <div className="container footer-bottom">
        <p>© 2026 FocusMac · MIT</p>
        <div className="footer-legal">
          <Link to="/#faq">privacy</Link>
          <a href={`${REPO_URL}/blob/main/LICENSE`} target="_blank" rel="noreferrer">
            license
          </a>
          <a href={RELEASES_URL} target="_blank" rel="noreferrer">
            releases
          </a>
        </div>
        <div className="footer-social">
          <a href={SOCIAL.github} target="_blank" rel="noreferrer">
            GitHub
          </a>
        </div>
      </div>
    </footer>
  );
}

export function PageHero({ eyebrow, title, copy }) {
  return (
    <section className="page-hero container">
      <Reveal>
        {eyebrow && <p className="eyebrow">{eyebrow}</p>}
        <h1>{title}</h1>
        {copy && <p className="page-copy">{copy}</p>}
      </Reveal>
    </section>
  );
}

export function CopyToast({ message }) {
  if (!message) return null;
  return (
    <div className="toast" role="status">
      ✦ {message}
    </div>
  );
}

export async function copyInstall(setToast) {
  try {
    await navigator.clipboard.writeText(installCommand);
    setToast("Install command copied — paste it into Terminal.");
  } catch {
    setToast("Select the command on the Install page and copy it manually.");
  }
  window.setTimeout(() => setToast(""), 3600);
}
