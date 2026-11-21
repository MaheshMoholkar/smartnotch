import type {CSSProperties} from 'react';

export type IconName = 'play' | 'pause' | 'pin' | 'close' | 'repeat' | 'previous' | 'next' | 'lock' | 'check' | 'cards' | 'note' | 'read' | 'cursor';

export const Icon = ({name, size = 28, style}: {name: IconName; size?: number; style?: CSSProperties}) => {
  const paths = {
    play: <path d="m9 5 10 7-10 7V5Z" />,
    pause: <path d="M8 5v14M16 5v14" />,
    pin: <path d="M9 3h6l-1 6 4 4v2H6v-2l4-4-1-6ZM12 15v6" />,
    close: <path d="m6 6 12 12M6 18 18 6" />,
    repeat: <path d="M5 8a8 8 0 1 1-1 8M5 3v5h5" />,
    previous: <path d="M5 5v14M19 5 8 12l11 7V5Z" />,
    next: <path d="M19 5v14M5 5l11 7-11 7V5Z" />,
    lock: <><rect x="5" y="10" width="14" height="11" rx="3" /><path d="M8 10V7a4 4 0 0 1 8 0v3M12 14v3" /></>,
    check: <path d="m5 12 4 4L19 6" />,
    cards: <><rect x="3" y="7" width="15" height="14" rx="3" /><path d="M7 3h12a2 2 0 0 1 2 2v12M7 12h7M7 16h4" /></>,
    note: <><path d="M14 3H5v18h14V8l-5-5Z" /><path d="M14 3v6h5M8 13h8M8 17h5" /></>,
    read: <><path d="M4 5h16M4 10h16M4 15h10M4 20h6" /><path d="m17 15 4 3-4 3v-6Z" /></>,
    cursor: <path d="m5 3 14 10-7 1-3 7L5 3Z" />,
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.65} strokeLinecap="round" strokeLinejoin="round" style={style}>{paths[name]}</svg>;
};
