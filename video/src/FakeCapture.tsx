import type {CSSProperties} from 'react';
import {CanvasImage, Easing, Interactive, interpolate, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {Icon, type IconName} from './Icon';

type Variant = 'hover' | 'read' | 'cards' | 'notes' | 'pin' | 'switching' | 'idea';
type Props = {variant: Variant; style?: CSSProperties};

const Button = ({icon, primary = false, mint = false}: {icon: IconName; primary?: boolean; mint?: boolean}) => <div style={{width: primary ? 83 : 52, height: 52, borderRadius: 32, display: 'grid', placeItems: 'center', background: primary ? '#a6efcd' : '#ffffff08', color: primary ? '#10251b' : mint ? '#a6efcd' : '#c2d2c7'}}><Icon name={icon} size={primary ? 30 : 25} /></div>;

const FakeCaptureInner = ({variant, style}: Props) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const mode = variant === 'cards' ? 'Cards' : variant === 'notes' ? 'Notes' : variant === 'switching' ? ['Read', 'Cards', 'Notes'][Math.floor(frame / (fps * 1.3)) % 3] : 'Read';
  const script = variant === 'idea'
    ? 'Let’s turn one small idea into something worth sharing. Focus on what you learned. Give your audience one useful takeaway.'
    : 'Your next great video starts with one clear idea.';
  const words = script.split(' ');
  const activeWord = variant === 'hover' || variant === 'pin' ? 0 : Math.floor(frame / (fps * 0.275)) % words.length;
  const card = Math.floor((frame - fps * 4.5) / (fps * 1.65) + 1) % 4;
  const cardIndex = (card + 4) % 4;
  const titles = ['The opening', 'The turning point', 'Behind the scenes', 'The takeaway'];
  const questions = ['What’s the one idea you want people to remember?', 'Tell us about an experiment that surprised you.', 'What does your creative routine look like?', 'What would you tell someone starting out?'];
  const baseNote = 'WEEKLY TEAM SYNC\n\nFocus\nSimplify the first-time experience.\n\nNext steps\n';
  const nextSteps = 'Share the prototype Thursday.\nCollect feedback Friday.';
  const characters = Math.min(nextSteps.length, Math.max(0, Math.floor((frame - fps * 5) * 0.27)));
  const show = variant !== 'hover' || frame >= fps * 2;
  return <div style={{...style, position: 'relative', width: 2940, height: 1912, overflow: 'hidden', fontFamily: 'Arial, Helvetica, sans-serif', color: '#e2ece5', background: 'radial-gradient(ellipse at 74% 0%,#dce5a9,transparent 48%),linear-gradient(150deg,#708263,#a0aa78 57%,#344c37)'}}>
    <div style={{position: 'absolute', width: 4200, height: 1500, left: -500, top: 1140, borderRadius: '50% 60% 0 0', rotate: '-9deg', background: 'linear-gradient(130deg,#466243,#a5ad7a)', boxShadow: '0px -2px 0px #eef7c02b'}} />
    <div style={{position: 'absolute', width: 4200, height: 1400, left: -450, top: 1430, borderRadius: '50% 60% 0 0', rotate: '9deg', background: 'linear-gradient(130deg,#1b3526,#526c49 70%,#929c68)'}} />
    <div style={{position: 'absolute', top: 0, left: 0, right: 0, height: 54, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 35px', boxSizing: 'border-box', background: '#17321c20', color: '#eff4e8bb', fontSize: 23}}><span>SmartNotch　 File　 Edit　 Window　 Help</span><span>9:41</span></div>
    <div style={{position: 'absolute', left: 1340, top: 0, width: 260, height: 56, background: '#111612', borderRadius: '0px 0px 21px 21px', zIndex: 3, display: 'grid', placeItems: 'center'}}><div style={{height: 11, width: 11, borderRadius: '50%', background: '#20382a', border: '1px solid #406045'}} /></div>
    <div style={{position: 'absolute', left: 810, top: 56, width: 1320, padding: '24px 29px 27px', boxSizing: 'border-box', border: '1px solid #f3fff226', borderRadius: 30, background: '#171e19', boxShadow: '0px 28px 70px #14271c55', opacity: show ? interpolate(frame, variant === 'hover' ? [2 * fps, 2.35 * fps] : [0, 1], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}) : 0, scale: variant === 'hover' ? interpolate(frame, [2 * fps, 2.4 * fps], [0.93, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.22, 1, 0.36, 1)}) : 1, transformOrigin: '50% 0%'}}>
      <div style={{display: 'grid', gridTemplateColumns: '1fr auto 1fr', gap: 24, alignItems: 'center'}}>
        <div style={{display: 'flex', alignItems: 'center', gap: 12, fontSize: 25, fontWeight: 600, letterSpacing: -0.8}}><CanvasImage src={staticFile('icon.png')} style={{width: 34, height: 34, objectFit: 'contain'}} />SmartNotch</div>
        <div style={{display: 'flex', gap: 4, padding: 5, borderRadius: 36, background: '#ffffff06'}}>{['Read', 'Cards', 'Notes'].map(item => <div key={item} style={{height: 47, minWidth: 108, borderRadius: 31, display: 'grid', placeItems: 'center', background: mode === item ? '#ffffff14' : 'transparent', color: mode === item ? '#f4f7f2' : '#92a397', fontSize: 23, fontWeight: 600}}>{item}</div>)}</div>
        <div style={{display: 'flex', justifyContent: 'flex-end', gap: 10}}><Button icon="pin" mint={variant === 'pin'} /><Button icon="close" /></div>
      </div>
      <div style={{boxSizing: 'border-box', minHeight: mode === 'Notes' ? 620 : mode === 'Cards' ? 440 : 164, padding: '27px 13px 24px'}}>
        {mode === 'Read' && <div style={{fontSize: 43, fontWeight: 500, lineHeight: 1.6, letterSpacing: -1.1}}>{words.map((word, index) => <span key={index} style={{position: 'relative', display: 'inline-block', marginRight: 12, color: index === activeWord ? '#a6efcd' : '#d9e7dd'}}>{word}{index === activeWord && <span style={{position: 'absolute', left: 0, right: 0, bottom: 5, height: 3, borderRadius: 4, background: '#a6efcd'}} />}</span>)}</div>}
        {mode === 'Cards' && <div><div style={{fontSize: 46, fontWeight: 500, letterSpacing: -1.4, marginBottom: 21}}>{titles[cardIndex]}</div><div style={{fontSize: 33, lineHeight: 1.5, color: '#becfc3'}}>{questions[cardIndex]}</div><div style={{marginTop: 39, paddingTop: 19, borderTop: '1px solid #ffffff13', display: 'flex', justifyContent: 'space-between', fontSize: 19, letterSpacing: 1.1, color: '#7f9988'}}><span>NOTES</span><span>Edit notes</span></div></div>}
        {mode === 'Notes' && <div style={{whiteSpace: 'pre-wrap', fontSize: 34, lineHeight: 1.55, letterSpacing: -0.4}}>{baseNote}{nextSteps.slice(0, characters)}<span style={{color: '#a6efcd', opacity: Math.floor(frame / (fps * 0.4)) % 2 ? 0 : 1}}>│</span></div>}
      </div>
      <div style={{display: 'grid', gridTemplateColumns: '1fr auto 1fr', alignItems: 'center', position: 'relative'}}>
        <div style={{display: 'flex', color: '#8da695', gap: 10, alignItems: 'center', fontSize: 20}}><Icon name={mode === 'Read' ? 'read' : mode === 'Cards' ? 'cards' : 'lock'} size={22} />{mode === 'Notes' ? 'Saved locally' : mode === 'Cards' ? 'Your next question' : 'Your pace. Your words.'}</div>
        <div style={{display: 'flex', gap: 14, alignItems: 'center', justifyContent: 'center'}}>
          {mode === 'Read' && <><Button icon="repeat" /><Button icon={variant === 'hover' || variant === 'pin' ? 'play' : 'pause'} primary /><Button icon="next" /></>}
          {mode === 'Cards' && <><Button icon="previous" /><div style={{fontSize: 27, color: '#bdd1c3', minWidth: 88, textAlign: 'center'}}>{cardIndex + 1} / 4</div><Button icon="next" /></>}
          {mode === 'Notes' && <div style={{color: '#a6efcd', display: 'flex', gap: 9, alignItems: 'center', fontSize: 23}}><Icon name="check" size={24} />Done</div>}
        </div><div />
        <div style={{position: 'absolute', left: '50%', bottom: -15, translate: '-50% 0px', width: 75, height: 5, borderRadius: 5, background: '#ffffff25'}} />
      </div>
    </div>
    {(variant === 'hover' || variant === 'pin') && <div style={{position: 'absolute', zIndex: 5, left: variant === 'hover' ? interpolate(frame, [0.6 * fps, 2 * fps], [2020, 1463], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.4, 0, 0.2, 1)}) : interpolate(frame, [8 * fps, 10.3 * fps], [2010, 2440], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}), top: variant === 'hover' ? interpolate(frame, [0.6 * fps, 2 * fps], [720, 16], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.4, 0, 0.2, 1)}) : interpolate(frame, [8 * fps, 10.3 * fps], [105, 720], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}), color: '#f4f6f2', filter: 'drop-shadow(0px 2px 3px #0009)'}}><Icon name="cursor" size={48} style={{fill: '#101811', strokeWidth: 1.8}} /></div>}
  </div>;
};

export const FakeCapture = Interactive.create({Component: FakeCaptureInner, layout: 'none', schema: {
  variant: {type: 'enum', default: 'read', description: 'Recreated original capture', variants: {hover: {}, read: {}, cards: {}, notes: {}, pin: {}, switching: {}, idea: {}}},
}});
