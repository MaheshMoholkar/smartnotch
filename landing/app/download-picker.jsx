'use client';

import { useId } from 'react';
import downloads from './downloads.json';

function DownloadIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M12 3v12m-4-4 4 4 4-4M5 16v4h14v-4" />
    </svg>
  );
}

export default function DownloadPicker() {
  const selected = downloads.mac;
  const descriptionId = useId();

  return (
    <div className="download-picker">
      <div className="download-split">
        <a className="button download-primary" href={selected.file} download aria-describedby={descriptionId}>
          <DownloadIcon /> Download for {selected.label}
        </a>
      </div>
      <p className="platform-requirements" id={descriptionId}>
        <span className="platform-system">{selected.system}</span>
        <span>{selected.architecture} · {selected.format}{selected.version ? ` · v${selected.version}` : ''}</span>
      </p>
    </div>
  );
}
