import { useEffect, useState } from "react";
import { Route, Routes, useLocation } from "react-router-dom";
import { CopyToast, SiteFooter, SiteHeader, copyInstall } from "./components";
import { FeaturesPage, HomePage, HowItWorksPage, InstallPage } from "./pages";

function ScrollManager() {
  const location = useLocation();

  useEffect(() => {
    if (location.hash === "#faq" || location.hash === "#benchmarks") {
      const id = location.hash.slice(1);
      requestAnimationFrame(() => {
        document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
      });
      return;
    }
    window.scrollTo({ top: 0, behavior: "smooth" });
  }, [location.pathname, location.hash]);

  return null;
}

export default function App() {
  const [toast, setToast] = useState("");
  const onCopy = () => copyInstall(setToast);

  return (
    <div className="site">
      <SiteHeader />
      <ScrollManager />
      <main>
        <Routes>
          <Route path="/" element={<HomePage onCopy={onCopy} />} />
          <Route path="/features" element={<FeaturesPage onCopy={onCopy} />} />
          <Route path="/how-it-works" element={<HowItWorksPage onCopy={onCopy} />} />
          <Route path="/install" element={<InstallPage onCopy={onCopy} />} />
        </Routes>
      </main>
      <SiteFooter />
      <CopyToast message={toast} />
    </div>
  );
}
