import { useState, useEffect } from "react";
import { Route, Routes, useLocation } from "react-router-dom";
import { Footer, Header, Toast, copyInstall } from "./components";
import { FeaturesPage, HomePage, HowItWorksPage, InstallPage } from "./pages";

function ScrollManager() {
  const { pathname, hash } = useLocation();
  const location = useLocation();
  
  // Scroll to top on route change
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [location.pathname]);

  // Handle hash scrolling
  useEffect(() => {
    if (hash) {
      const id = hash.slice(1);
      requestAnimationFrame(() => document.getElementById(id)?.scrollIntoView({ behavior: "smooth" }));
    }
  }, [hash]);
  
  return null;
}

export default function App() {
  const [toast, setToast] = useState("");
  const onCopy = () => copyInstall(setToast);

  return (
    <div className="app" style={{ backgroundColor: 'var(--bg)', color: 'var(--ink)' }}>
      <Header />
      <ScrollManager />
      <main>
        <Routes>
          <Route path="/" element={<HomePage onCopy={onCopy} />} />
          <Route path="/features" element={<FeaturesPage onCopy={onCopy} />} />
          <Route path="/how-it-works" element={<HowItWorksPage onCopy={onCopy} />} />
          <Route path="/install" element={<InstallPage onCopy={onCopy} />} />
        </Routes>
      </main>
      <Footer />
      <Toast message={toast} />
    </div>
  );
}