import {useRef} from 'react';
import {createRoot} from 'react-dom/client';
import {Player} from '@remotion/player';
import {ExistingAd} from './ExistingAd';

const Preview = () => {
  const player = useRef(null);
  return <main>
    <header><span className="eyebrow">SMARTNOTCH · ORIGINAL AD EDIT</span><h1>Same ad. <em>One visual language.</em></h1><p>20 seconds · Original cuts and soundtrack · Hero-style titles and mockups</p></header>
    <section className="viewer"><Player ref={player} component={ExistingAd} compositionWidth={1920} compositionHeight={1080} durationInFrames={600} fps={30} controls loop initiallyMuted={false} initialFrame={75} style={{width: '100%'}} /></section>
    <nav aria-label="Jump to a scene">
      <button onClick={() => player.current?.seekTo(75)}>Hover</button>
      <button onClick={() => player.current?.seekTo(135)}>The notch</button>
      <button onClick={() => player.current?.seekTo(195)}>Read</button>
      <button onClick={() => player.current?.seekTo(250)}>Question</button>
      <button onClick={() => player.current?.seekTo(310)}>Cards</button>
      <button onClick={() => player.current?.seekTo(395)}>Notes</button>
      <button onClick={() => player.current?.seekTo(480)}>Montage</button>
      <button onClick={() => player.current?.seekTo(560)}>Closing</button>
    </nav>
    <p className="hint">Press play to review the film, or use the scene buttons to inspect a shot.</p>
  </main>;
};

createRoot(document.getElementById('root')).render(<Preview />);
