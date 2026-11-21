export default function Icon({ name, size = 20, ...props }) {
  const paths = {
    play: <path d="m9 5 10 7-10 7V5Z" />,
    pause: <><path d="M8 5v14M16 5v14" /></>,
    close: <path d="m6 6 12 12M6 18 18 6" />,
    pin: <><path d="m9 3 6 0-1 6 4 4v2H6v-2l4-4-1-6ZM12 15v6" /></>,
    note: <><path d="M14 3H5v18h14V8l-5-5Z" /><path d="M14 3v6h5M8 13h8M8 17h5" /></>,
    cards: <><rect x="3" y="7" width="15" height="14" rx="3" /><path d="M7 3h12a2 2 0 0 1 2 2v12M7 12h7M7 16h4" /></>,
    read: <><path d="M4 5h16M4 10h16M4 15h10M4 20h6" /><path d="m17 15 4 3-4 3v-6Z" /></>,
    lock: <><rect x="5" y="10" width="14" height="11" rx="3" /><path d="M8 10V7a4 4 0 0 1 8 0v3M12 14v3" /></>,
    check: <path d="m5 12 4 4L19 6" />,
    sparkle: <><path d="m12 3 2.4 6.6L21 12l-6.6 2.4L12 21l-2.4-6.6L3 12l6.6-2.4L12 3Z" /></>,
    settings: <><path d="M4 7h16M4 17h16" /><circle cx="9" cy="7" r="3" /><circle cx="15" cy="17" r="3" /></>,
    cursor: <path d="m5 3 14 10-7 1-3 7L5 3Z" />,
    repeat: <><path d="M5 8a8 8 0 1 1-1 8M5 3v5h5" /></>,
    previous: <><path d="M5 5v14M19 5 8 12l11 7V5Z" /></>,
    next: <><path d="M19 5v14M5 5l11 7-11 7V5Z" /></>,
    list: <><path d="M9 6h12M9 12h12M9 18h12M3 6h1M3 12h1M3 18h1" /></>,
    edit: <><path d="M12 5H5v14h14v-7M15 3l6 6M10 14l2-6 5-5 4 4-5 5-6 2Z" /></>,
    mic: <><rect x="9" y="2" width="6" height="13" rx="3" /><path d="M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8" /></>,
    download: <><path d="M12 3v12m-4-4 4 4 4-4M5 16v4h14v-4" /></>,
    monitor: <><rect x="2" y="3" width="20" height="14" rx="3" /><path d="M8 21h8M12 17v4" /></>,
    plus: <path d="M12 5v14M5 12h14" />,
    wave: <path d="M3 10v4M7 6v12M12 2v20M17 6v12M21 10v4" />,
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" {...props}>{paths[name] || paths.sparkle}</svg>;
}
