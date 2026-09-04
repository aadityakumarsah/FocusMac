import { useEffect, useState, useRef } from "react";

// Particle Background Component
export function ParticleBackground() {
  const particlesRef = useRef(null);
  
  useEffect(() => {
    const container = particlesRef.current;
    if (!container) return;
    
    const particleCount = 50;
    const particles = [];
    
    for (let i = 0; i < particleCount; i++) {
      const particle = document.createElement('div');
      particle.className = 'particle';
      particle.style.left = Math.random() * 100 + '%';
      particle.style.top = Math.random() * 100 + '%';
      particle.style.width = Math.random() * 4 + 2 + 'px';
      particle.style.height = particle.style.width;
      particle.style.animationDelay = Math.random() * 6 + 's';
      particle.style.animationDuration = (Math.random() * 4 + 4) + 's';
      container.appendChild(particle);
      particles.push(particle);
    }
    
    return () => {
      particles.forEach(p => p.remove());
    };
  }, []);
  
  return <div ref={particlesRef} className="particles" />;
}

// Orbiting Icons Component
export function OrbitingIcons({ centerIcon, orbitIcons = [] }) {
  return (
    <div className="orbit-container">
      <div className="orbit-center">{centerIcon}</div>
      {orbitIcons.map((icon, index) => (
        <div key={index} className="orbit-item" style={{ animationDelay: `${index * -2}s` }}>
          {icon}
        </div>
      ))}
    </div>
  );
}

// 3D Card Component
export function Card3D({ children, className = "" }) {
  const [rotation, setRotation] = useState({ x: 0, y: 0 });
  const cardRef = useRef(null);
  
  const handleMouseMove = (e) => {
    if (!cardRef.current) return;
    
    const rect = cardRef.current.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    const centerX = rect.width / 2;
    const centerY = rect.height / 2;
    
    const rotateX = (y - centerY) / 10;
    const rotateY = (centerX - x) / 10;
    
    setRotation({ x: rotateX, y: rotateY });
  };
  
  const handleMouseLeave = () => {
    setRotation({ x: 0, y: 0 });
  };
  
  return (
    <div 
      ref={cardRef}
      className={`card-3d ${className}`}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
    >
      <div 
        className="card-3d-inner"
        style={{
          transform: `perspective(1000px) rotateX(${rotation.x}deg) rotateY(${rotation.y}deg)`
        }}
      >
        {children}
      </div>
    </div>
  );
}

// Floating Elements
export function FloatingElement({ children, delay = 0, duration = 3 }) {
  return (
    <div 
      style={{
        animation: `float ${duration}s ease-in-out infinite`,
        animationDelay: `${delay}s`
      }}
    >
      {children}
    </div>
  );
}

// Pulse Glow Component
export function PulseGlow({ children, color = "var(--accent)" }) {
  return (
    <div style={{ position: 'relative', display: 'inline-block' }}>
      <div style={{
        position: 'absolute',
        inset: -10,
        background: color,
        borderRadius: '50%',
        opacity: 0.3,
        filter: 'blur(20px)',
        animation: 'pulse-glow 2s ease-in-out infinite'
      }} />
      {children}
    </div>
  );
}

// Gradient Border Component
export function GradientBorder({ children, gradient = "linear-gradient(135deg, var(--accent), var(--purple), var(--blue))" }) {
  return (
    <div className="neon-border">
      <div className="neon-content" style={{ background: 'var(--bg)' }}>
        {children}
      </div>
    </div>
  );
}

// Animated Counter
export function AnimatedCounter({ value, duration = 2000, suffix = "" }) {
  const [count, setCount] = useState(0);
  
  useEffect(() => {
    let startTimestamp;
    const step = (timestamp) => {
      if (!startTimestamp) startTimestamp = timestamp;
      const progress = Math.min((timestamp - startTimestamp) / duration, 1);
      setCount(Math.floor(progress * value));
      if (progress < 1) {
        window.requestAnimationFrame(step);
      }
    };
    window.requestAnimationFrame(step);
  }, [value, duration]);
  
  return <span>{count}{suffix}</span>;
}

// Typewriter Effect
export function Typewriter({ text, speed = 50, onComplete }) {
  const [displayText, setDisplayText] = useState("");
  const [index, setIndex] = useState(0);
  
  useEffect(() => {
    if (index < text.length) {
      const timer = setTimeout(() => {
        setDisplayText(text.slice(0, index + 1));
        setIndex(index + 1);
      }, speed);
      return () => clearTimeout(timer);
    } else if (onComplete) {
      onComplete();
    }
  }, [index, text, speed, onComplete]);
  
  return <span>{displayText}</span>;
}

// Morphing Background
export function MorphingBackground() {
  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      background: 'linear-gradient(-45deg, #f7f8fc, #ffffff, #f5f3ff, #fff5f0)',
      backgroundSize: '400% 400%',
      animation: 'gradient-shift 15s ease infinite',
      zIndex: -1
    }} />
  );
}

// Shimmer Effect
export function Shimmer({ children }) {
  return (
    <div style={{ position: 'relative', overflow: 'hidden' }}>
      <div style={{
        position: 'absolute',
        top: 0,
        left: -100,
        width: '100%',
        height: '100%',
        background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.2), transparent)',
        animation: 'shimmer 2s infinite'
      }} />
      {children}
    </div>
  );
}

// Glitch Effect
export function Glitch({ children, intensity = "medium" }) {
  const [isGlitching, setIsGlitching] = useState(false);
  
  useEffect(() => {
    const interval = setInterval(() => {
      setIsGlitching(true);
      setTimeout(() => setIsGlitching(false), 200);
    }, 3000);
    
    return () => clearInterval(interval);
  }, []);
  
  return (
    <span style={{
      position: 'relative',
      display: 'inline-block'
    }}>
      {isGlitching && (
        <>
          <span style={{
            position: 'absolute',
            left: -2,
            top: 0,
            color: '#ff0000',
            clipPath: 'inset(0 0 0 0)',
            animation: 'glitch-1 0.3s infinite'
          }}>{children}</span>
          <span style={{
            position: 'absolute',
            left: 2,
            top: 0,
            color: '#00ff00',
            clipPath: 'inset(0 0 0 0)',
            animation: 'glitch-2 0.3s infinite'
          }}>{children}</span>
        </>
      )}
      {children}
    </span>
  );
}

// Magnetic Button
export function MagneticButton({ children, className = "", ...props }) {
  const buttonRef = useRef(null);
  
  const handleMouseMove = (e) => {
    if (!buttonRef.current) return;
    
    const rect = buttonRef.current.getBoundingClientRect();
    const x = e.clientX - rect.left - rect.width / 2;
    const y = e.clientY - rect.top - rect.height / 2;
    
    buttonRef.current.style.transform = `translate(${x * 0.3}px, ${y * 0.3}px)`;
  };
  
  const handleMouseLeave = () => {
    if (buttonRef.current) {
      buttonRef.current.style.transform = 'translate(0, 0)';
    }
  };
  
  return (
    <button
      ref={buttonRef}
      className={`animated-btn ${className}`}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      {...props}
    >
      {children}
    </button>
  );
}

// Reveal on Scroll
export function RevealOnScroll({ children, threshold = 0.1 }) {
  const [isVisible, setIsVisible] = useState(false);
  const ref = useRef(null);
  
  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
        }
      },
      { threshold }
    );
    
    if (ref.current) {
      observer.observe(ref.current);
    }
    
    return () => observer.disconnect();
  }, [threshold]);
  
  return (
    <div
      ref={ref}
      style={{
        opacity: isVisible ? 1 : 0,
        transform: isVisible ? 'translateY(0)' : 'translateY(50px)',
        transition: 'all 0.8s cubic-bezier(0.4, 0, 0.2, 1)'
      }}
    >
      {children}
    </div>
  );
}

// Wave Animation
export function WaveAnimation({ color = "var(--accent)", count = 5 }) {
  return (
    <div style={{ display: 'flex', gap: '4px', alignItems: 'center' }}>
      {Array.from({ length: count }).map((_, i) => (
        <div
          key={i}
          style={{
            width: '4px',
            height: '20px',
            background: color,
            borderRadius: '2px',
            animation: `wave 1s ease-in-out infinite`,
            animationDelay: `${i * 0.1}s`
          }}
        />
      ))}
    </div>
  );
}