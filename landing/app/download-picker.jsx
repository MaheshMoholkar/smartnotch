'use client';

import { createContext, useContext, useEffect, useId, useRef, useState } from 'react';
import platforms from './downloads.json';

const PlatformContext = createContext(null);

export function DownloadPlatformProvider({ children }) {
  const [platform, setPlatform] = useState('mac');

  useEffect(() => {
    const system = navigator.userAgentData?.platform || navigator.platform || navigator.userAgent;
    if (/^win|windows/i.test(system)) setPlatform('windows');
    else if (/linux/i.test(system) && !/android|cros/i.test(navigator.userAgent)) setPlatform('linux');
  }, []);

  return (
    <PlatformContext.Provider value={{ platform, setPlatform }}>
      {children}
    </PlatformContext.Provider>
  );
}

function DownloadIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M12 3v12m-4-4 4 4 4-4M5 16v4h14v-4" />
    </svg>
  );
}

export default function DownloadPicker() {
  const { platform, setPlatform } = useContext(PlatformContext);
  const selected = platforms[platform];
  const descriptionId = useId();
  const disclosure = useRef(null);
  const toggle = useRef(null);

  useEffect(() => {
    function closeOutside(event) {
      const picker = disclosure.current;
      if (picker?.open && !picker.contains(event.target)) picker.open = false;
    }

    document.addEventListener('pointerdown', closeOutside);
    return () => document.removeEventListener('pointerdown', closeOutside);
  }, []);

  function closePicker() {
    disclosure.current.open = false;
    toggle.current.focus();
  }

  function handleKeyDown(event) {
    if (event.key !== 'Escape' || !disclosure.current.open) return;
    event.preventDefault();
    closePicker();
  }

  return (
    <div className="download-picker">
      <div className="download-split">
        <a className="button download-primary" href={selected.file} download aria-describedby={descriptionId}>
          <DownloadIcon /> Download for {selected.label}
        </a>
        <details className="platform-picker" ref={disclosure} onKeyDown={handleKeyDown}>
          <summary className="button platform-toggle" ref={toggle} aria-label="Choose download platform">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="m6 9 6 6 6-6" />
            </svg>
          </summary>
          <div className="platform-options">
            {Object.entries(platforms).map(([key, option]) => (
              <button
                key={key}
                type="button"
                aria-pressed={key === platform}
                onClick={() => {
                  setPlatform(key);
                  closePicker();
                }}
              >
                <span className="platform-option-name">{option.label}</span>
                <small>{option.system}</small>
                <small>{option.architecture} · {option.format}</small>
              </button>
            ))}
          </div>
        </details>
      </div>
      <p className="platform-requirements" id={descriptionId} aria-live="polite">
        <span className="platform-system">{selected.system}</span>
        <span>{selected.architecture} · {selected.format}{selected.version ? ` · v${selected.version}` : ''}</span>
      </p>
    </div>
  );
}
