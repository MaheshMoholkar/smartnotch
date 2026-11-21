'use client';

import { useEffect, useRef, useState } from 'react';
import Icon from './icons';

const modes = {
  Read: {
    icon: 'read',
    title: 'Find your flow.',
    description: 'Keep your script close to the lens. Set your pace, jump to any word, or let voice follow keep up with you on Mac.',
    image: '/assets/read-preview.jpg',
    alt: 'The SmartNotch teleprompter showing an active word and playback controls below the Mac camera notch',
    chips: ['Auto-scroll & manual', 'Saved reading position', 'Voice follow on Mac'],
  },
  Cards: {
    icon: 'cards',
    title: 'Leave room for the unexpected.',
    description: 'A little structure, without a word-for-word script. Keep talking points in a deck, add context, and check them off as you go.',
    image: '/assets/cards-preview.jpg',
    alt: 'SmartNotch cue cards with a question, notes, and navigation between cards',
    chips: ['Multiple decks', 'Card notes', 'Completion tracking'],
  },
  Notes: {
    icon: 'note',
    title: 'Keep the good stuff close.',
    description: 'A thought, a name, a detail you can’t forget. Keep notes for every meeting or recording, then edit them right in the panel.',
    image: '/assets/notes-preview.jpg',
    alt: 'SmartNotch Notes mode with meeting notes in the floating panel',
    chips: ['Independent notes', 'Edit in the panel', 'Automatic local saving'],
  },
};

function navigateTabs(event, active, onChange) {
  const names = Object.keys(modes);
  const index = names.indexOf(active);
  let next;
  if (event.key === 'ArrowRight' || event.key === 'ArrowDown') next = (index + 1) % names.length;
  else if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') next = (index - 1 + names.length) % names.length;
  else if (event.key === 'Home') next = 0;
  else if (event.key === 'End') next = names.length - 1;
  else return;
  event.preventDefault();
  onChange(names[next]);
  event.currentTarget.querySelectorAll('[role="tab"]')[next].focus();
}

export function PageMotion() {
  useEffect(() => {
    const media = window.matchMedia('(prefers-reduced-motion: reduce)');
    if (media.matches || !('IntersectionObserver' in window)) return;
    const elements = document.querySelectorAll('[data-reveal]');
    document.documentElement.classList.add('motion-ready');
    const observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('revealed');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.08 });
    elements.forEach(element => observer.observe(element));
    return () => {
      observer.disconnect();
      document.documentElement.classList.remove('motion-ready');
    };
  }, []);
  return null;
}

export function ProductDemo() {
  const [mode, setMode] = useState('Read');
  const [playing, setPlaying] = useState(false);
  const [word, setWord] = useState(0);
  const [pinned, setPinned] = useState(true);
  const [expanded, setExpanded] = useState(true);
  const [card, setCard] = useState(0);
  const [notes, setNotes] = useState('A good opening.\nOne clear idea.\nSomething worth remembering.');
  const words = 'Your next great story starts with one clear idea. Take a breath. Look up. Make it yours.'.split(' ');
  const cards = [
    ['The opening', 'What’s the one idea you want people to remember?'],
    ['The turning point', 'Tell us about a moment that changed your perspective.'],
    ['The takeaway', 'Leave your audience with something they can use.'],
  ];
  useEffect(() => {
    if (!playing || mode !== 'Read' || !expanded) return;
    if (word >= words.length - 1) { setPlaying(false); return; }
    const timer = setTimeout(() => setWord(value => value + 1), 550);
    return () => clearTimeout(timer);
  }, [playing, mode, expanded, words.length, word]);
  function switchMode(value) { setMode(value); setPlaying(false); }
  return (
    <div className="demo-area" data-reveal>
      <div className="desktop-frame">
        <div className="desktop-screen">
          <div className="wallpaper" aria-hidden="true"><div className="dune dune-one" /><div className="dune dune-two" /><div className="dune dune-three" /><div className="wallpaper-grain" /></div>
          <div className="desktop-menubar" aria-hidden="true"><span className="desktop-app-name"><img src="/assets/icon.png" alt="" /> SmartNotch <span>File</span><span>Edit</span><span>Window</span></span><span className="desktop-time">Sat 9:41</span></div>
          <button className={`camera-notch ${expanded ? 'is-open' : ''}`} onMouseEnter={() => setExpanded(true)} onClick={() => setExpanded(value => !value)} aria-label={expanded ? 'Collapse interactive preview' : 'Open interactive preview'} aria-expanded={expanded}><span /></button>
          <div className={`demo-panel ${expanded ? '' : 'is-collapsed'}`} onMouseLeave={() => { if (!pinned) { setExpanded(false); setPlaying(false); } }} inert={!expanded ? true : undefined}>
            <div className="demo-toolbar">
              <div className="demo-brand"><img src="/assets/icon.png" alt="" /><span>SmartNotch</span></div>
              <div className="demo-tabs" role="tablist" aria-label="Try a workspace" onKeyDown={event => navigateTabs(event, mode, switchMode)}>
                {Object.keys(modes).map(item => <button key={item} role="tab" tabIndex={mode === item ? 0 : -1} aria-selected={mode === item} aria-controls="demo-workspace" id={`demo-tab-${item}`} onClick={() => switchMode(item)}>{item}</button>)}
              </div>
              <div className="demo-window-actions"><button className={pinned ? 'is-pinned' : ''} onClick={() => setPinned(value => !value)} aria-label={pinned ? 'Unpin demo panel' : 'Pin demo panel'} aria-pressed={pinned}><Icon name="pin" size={16} /></button><button onClick={() => { setExpanded(false); setPlaying(false); }} aria-label="Close demo panel"><Icon name="close" size={17} /></button></div>
            </div>
            <div className={`demo-content demo-content-${mode.toLowerCase()}`} id="demo-workspace" role="tabpanel" aria-labelledby={`demo-tab-${mode}`}>
              {mode === 'Read' && <p>{words.map((text, index) => <button key={index} className={word === index ? 'current-word' : ''} onClick={() => setWord(index)} aria-label={`Read from ${text}`}>{text}</button>)}</p>}
              {mode === 'Cards' && <div className="demo-card" key={card}><span className="demo-card-index">TALKING POINT {card + 1} / 3</span><h3>{cards[card][0]}</h3><p>{cards[card][1]}</p></div>}
              {mode === 'Notes' && <textarea value={notes} onChange={event => setNotes(event.target.value)} aria-label="Try editing a note" spellCheck="false" />}
            </div>
            <div className="demo-controls">
              <span className="demo-mode-caption"><Icon name={mode === 'Read' ? 'wave' : modes[mode].icon} size={15} /> {mode === 'Read' ? 'Your pace. Your words.' : mode === 'Cards' ? 'Room to be yourself.' : 'Try typing here.'}</span>
              <div className="demo-transport">
                {mode === 'Read' && <><button onClick={() => { setWord(0); setPlaying(false); }} aria-label="Restart demo script"><Icon name="repeat" size={17} /></button><button className="demo-play" onClick={() => { if (word === words.length - 1) setWord(0); setPlaying(value => !value); }} aria-label={playing ? 'Pause demo script' : 'Play demo script'}><Icon name={playing ? 'pause' : 'play'} size={21} /></button><button onClick={() => setWord(value => Math.min(words.length - 1, value + 1))} aria-label="Next demo word"><Icon name="next" size={17} /></button></>}
                {mode === 'Cards' && <><button disabled={card === 0} onClick={() => setCard(value => value - 1)} aria-label="Previous demo card"><Icon name="previous" size={17} /></button><span>{card + 1} / 3</span><button disabled={card === 2} onClick={() => setCard(value => value + 1)} aria-label="Next demo card"><Icon name="next" size={17} /></button></>}
                {mode === 'Notes' && <span className="demo-local-note"><Icon name="lock" size={14} /> Preview only</span>}
              </div>
              <span className="demo-grip" aria-hidden="true" />
            </div>
          </div>
          {!expanded && <button className="demo-reopen" onClick={() => setExpanded(true)}>Open SmartNotch <Icon name="cursor" size={16} /></button>}
          <div className="desktop-note" aria-hidden="true"><span>SPACE TO THINK.</span><p>Nothing between<br />you and your story.</p></div>
          <div className="desktop-bottom-label"><Icon name="monitor" size={15} /><span>Right under your camera. Right where you need it.</span></div>
        </div>
      </div>
      <div className="demo-caption"><span><Icon name="cursor" size={15} /> Go ahead. Try the tabs and press play.</span><span>Interactive preview · Desktop app</span></div>
    </div>
  );
}

export function WorkspaceExplorer() {
  const [active, setActive] = useState('Read');
  const selected = modes[active];
  return (
    <div className="workspace-explorer" data-reveal>
      <div className="workspace-selector" role="tablist" aria-label="Explore SmartNotch workspaces" aria-orientation="vertical" onKeyDown={event => navigateTabs(event, active, setActive)}>
        {Object.entries(modes).map(([name, mode]) => <button key={name} role="tab" tabIndex={active === name ? 0 : -1} id={`workspace-tab-${name}`} aria-selected={active === name} aria-controls="workspace-preview" onClick={() => setActive(name)}><span className="workspace-tab-icon"><Icon name={mode.icon} size={22} /></span><span><strong>{name}</strong><span>{name === 'Read' ? 'For the words you want to get right.' : name === 'Cards' ? 'For a little direction, not a script.' : 'For the details worth keeping.'}</span></span><span className="workspace-tab-indicator" /></button>)}
      </div>
      <div className="workspace-display" id="workspace-preview" role="tabpanel" aria-labelledby={`workspace-tab-${active}`}>
        <div className={`workspace-image workspace-image-${active.toLowerCase()}`}><img key={selected.image} src={selected.image} alt={selected.alt} width="880" height={active === 'Read' ? 366 : active === 'Cards' ? 456 : 490} loading="lazy" /></div>
        <div className="workspace-detail" key={active}><h3>{selected.title}</h3><p>{selected.description}</p><div className="feature-chips">{selected.chips.map(chip => <span key={chip}><Icon name="check" size={13} />{chip}</span>)}</div></div>
      </div>
    </div>
  );
}

export function ProductFilm({ compact = false }) {
  const dialog = useRef(null);
  const video = useRef(null);
  function show() {
    dialog.current.showModal();
    video.current.play().catch(() => {});
  }
  function close() { video.current.pause(); dialog.current.close(); }
  return (
    <>
      {compact ? <button className="watch-link" onClick={show}><span><Icon name="play" size={14} /></span>See it in action</button> : <button className="film-card" onClick={show} aria-label="Play the SmartNotch product film"><img src="/assets/film-poster.jpg" alt="Preview of the SmartNotch product film" width="1280" height="720" loading="lazy" /><span className="film-shade" /><span className="film-play"><Icon name="play" size={27} /></span><span className="film-caption"><span>LESS FRICTION. MORE FLOW.</span><strong>Meet your new<br />on-camera companion.</strong><span className="film-watch-label">Watch SmartNotch in action</span></span></button>}
      <dialog className="film-dialog" ref={dialog} aria-label="SmartNotch product film" onCancel={() => video.current.pause()} onClose={() => video.current.pause()} onClick={event => { if (event.target === event.currentTarget) close(); }}><button className="film-close" onClick={close} aria-label="Close product film"><Icon name="close" size={22} /></button><video ref={video} controls playsInline preload="none" poster="/assets/film-poster.jpg"><source src="/assets/smartnotch.mp4" type="video/mp4" />Your browser does not support video playback.</video></dialog>
    </>
  );
}

export function AppearanceDemo() {
  const [size, setSize] = useState(22);
  return <div className="appearance-demo"><div className="appearance-sample" style={{ fontSize: `${size}px` }}>A little more<br /><span>your style.</span></div><label><span>Make room for your words</span><input type="range" min="18" max="30" value={size} onChange={event => setSize(Number(event.target.value))} aria-label="Try adjusting the preview text size" /><span>{size} pt</span></label></div>;
}
