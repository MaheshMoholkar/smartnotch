import React from 'react';
import {AbsoluteFill,Sequence,Interactive,Img,staticFile,useCurrentFrame,useVideoConfig,interpolate,Easing} from 'remotion';
import {Audio} from '@remotion/media';
import {FakeCapture} from './FakeCapture';
const e=Easing.bezier(.22,1,.36,1);
const opts={extrapolateLeft:'clamp',extrapolateRight:'clamp',easing:e} as const;

const Reveal=({children,mark}:{children:string;mark?:string})=>{
 const f=useCurrentFrame();
 return <span>{children.split(' ').map((w,i)=><span key={i} style={{display:'inline-block',marginRight:17,opacity:interpolate(f,[i*2,i*2+8],[0,1],opts),filter:`blur(${interpolate(f,[i*2,i*2+10],[9,0],opts)}px)`,translate:`0 ${interpolate(f,[i*2,i*2+10],[7,0],opts)}px`,color:w===mark?'#a6efcd':undefined,fontFamily:w===mark?'Georgia, serif':undefined,fontStyle:w===mark?'italic':undefined,fontWeight:w===mark?400:undefined}}>{w}</span>)}</span>;
};
const Statement=({children,mark}:{children:string;mark?:string})=><AbsoluteFill style={{alignItems:'center',justifyContent:'center'}}><Interactive.Div name="Statement" style={{fontSize:88,fontWeight:500,letterSpacing:-3.2,lineHeight:1.14,textAlign:'center',maxWidth:1600}}><Reveal mark={mark}>{children}</Reveal></Interactive.Div></AbsoluteFill>;
const Line=({children}:{children:React.ReactNode})=>{
 const f=useCurrentFrame();
 return <Interactive.Div name="Benefit caption" style={{position:'absolute',bottom:100,left:120,right:120,textAlign:'center',fontSize:39,fontWeight:400,lineHeight:1.35,letterSpacing:-1,color:'#dce6de',opacity:interpolate(f,[4,14],[0,1],opts),translate:`0 ${interpolate(f,[4,16],[9,0],opts)}px`,filter:`blur(${interpolate(f,[3,13],[5,0],opts)}px)`}}>{children}</Interactive.Div>;
};
const Accent=({children}:{children:React.ReactNode})=><span style={{color:'#a6efcd',fontFamily:'Georgia, serif',fontStyle:'italic',fontWeight:400}}>{children}</span>;
const Camera=({children,start=.7,end=.9,y=0,endY=0,focus=1470,width=1440,height=740,top=110}:{children:React.ReactNode;start?:number;end?:number;y?:number;endY?:number;focus?:number;width?:number;height?:number;top?:number})=>{
 const f=useCurrentFrame(); const scale=interpolate(f,[0,14,66],[start,start,end],opts);
 return <div style={{position:'absolute',left:(1920-width)/2,top,width,height,borderRadius:28,overflow:'hidden',boxShadow:'0 28px 70px #0005,0 0 0 1px #a6efcd26',opacity:interpolate(f,[0,5],[0,1],opts),filter:`blur(${interpolate(f,[0,7],[6,0],opts)}px)`}}><div style={{position:'absolute',left:width/2-focus*scale,top:interpolate(f,[0,66],[y,endY],opts),width:2940,height:1912,scale,transformOrigin:'0 0'}}>{children}</div></div>;
};
const HoverShot=()=>{
 const {fps}=useVideoConfig();
 return <><Camera start={.5} end={.86}><FakeCapture name="Mockup compact hover reveal" variant="hover" trimBefore={.55*fps} playbackRate={1.1} style={{width:2940,height:1912}}/></Camera><Line>Hover over the notch. Your script is <Accent>right there.</Accent></Line></>;
};
const ReadShot=()=>{
 const {fps}=useVideoConfig();
 return <><Camera start={1} end={1.04} height={620} top={170} y={-18} endY={-30}><FakeCapture name="Compact script follows playback" variant="read" trimBefore={6*fps} playbackRate={1.35} style={{width:2940,height:1912}}/></Camera><Line>Keep your words <Accent>near the camera.</Accent></Line></>;
};
const CardShot=()=>{
 const {fps}=useVideoConfig();
 return <><Camera start={.83} end={.98} height={740}><FakeCapture name="Podcast question changes" variant="cards" trimBefore={6*fps} playbackRate={1.5} style={{width:2940,height:1912}}/></Camera><Line>For podcasts. Interviews. <Accent>The next question.</Accent></Line></>;
};
const NoteShot=()=>{
 const {fps}=useVideoConfig();
 return <><Camera start={.50} end={.62} height={740} top={110}><FakeCapture name="Meeting action typed and saved" variant="notes" trimBefore={4*fps} playbackRate={2.7} style={{width:2940,height:1912}}/></Camera><Line>Catch the action item. <Accent>Keep going.</Accent></Line></>;
};
const Tile=({children}:{children:React.ReactNode})=><div style={{width:730,height:440,borderRadius:17,overflow:'hidden',position:'relative',background:'#171e19',boxShadow:'0 14px 36px #0005,0 0 0 1px #a6efcd20'}}><div style={{position:'absolute',width:2940,height:1912,scale:.53,transformOrigin:'0 0',left:-414,top:0}}>{children}</div></div>;
const Montage=()=>{
 const f=useCurrentFrame();const {fps}=useVideoConfig();
 return <><div style={{position:'absolute',left:-150,top:-200,width:2240,display:'grid',gridTemplateColumns:'repeat(3,730px)',gap:24,rotate:'0deg',translate:`${interpolate(f,[0,78],[160,-100],opts)}px ${interpolate(f,[0,78],[90,-30],opts)}px`,opacity:interpolate(f,[0,9],[0,1],opts)}}>
 <Tile><FakeCapture name="Montage read" variant="read" trimBefore={5*fps} style={{width:2940,height:1912}}/></Tile>
 <Tile><FakeCapture name="Montage cards" variant="cards" trimBefore={8*fps} style={{width:2940,height:1912}}/></Tile>
 <Tile><FakeCapture name="Montage notes" variant="notes" trimBefore={10*fps} style={{width:2940,height:1912}}/></Tile>
 <Tile><FakeCapture name="Montage pin" variant="pin" trimBefore={8*fps} style={{width:2940,height:1912}}/></Tile>
 <Tile><FakeCapture name="Montage three modes" variant="switching" trimBefore={18*fps} style={{width:2940,height:1912}}/></Tile>
 <Tile><FakeCapture name="Montage idea" variant="idea" trimBefore={8*fps} style={{width:2940,height:1912}}/></Tile>
 </div><div style={{position:'absolute',inset:0,background:'linear-gradient(to bottom,#0b120d00 35%,#0b120dd9 72%,#0b120d 88%)'}}/><Line>Scripts, questions, notes. <Accent>All in your notch.</Accent></Line></>;
};
const Close=()=>{
 const f=useCurrentFrame();
 return <AbsoluteFill style={{alignItems:'center',justifyContent:'center'}}><Img name="SmartNotch app icon" src={staticFile('smartnotch-notch-cue.png')} style={{width:112,height:112,opacity:interpolate(f,[0,12],[0,1],opts),translate:interpolate(f,[0,18],['0px 12px','0px 0px'],opts)}}/><Interactive.Div name="SmartNotch" style={{fontSize:82,fontWeight:500,letterSpacing:-3.4,marginTop:28}}><Reveal>SmartNotch</Reveal></Interactive.Div><Interactive.Div name="Read Cards Notes" style={{fontSize:34,color:'#a6efcd',fontFamily:'Georgia, serif',fontStyle:'italic',marginTop:14,opacity:interpolate(f,[8,18],[0,1],opts)}}>Read. Cards. Notes.</Interactive.Div><Interactive.Div name="Free no subscription" style={{fontSize:26,color:'#a6b7aa',letterSpacing:.1,marginTop:32,opacity:interpolate(f,[18,30],[0,1],opts)}}>Free. No subscription.</Interactive.Div></AbsoluteFill>;
};
export const ExistingAd=()=>{
 return <AbsoluteFill style={{background:'#0b120d',backgroundImage:'radial-gradient(ellipse at 50% 0%,#30452b55,transparent 68%)',fontFamily:'Arial, Helvetica, sans-serif',color:'#edf2e7'}}>
 <Sequence name="01 · Hover first" durationInFrames={100}><HoverShot/></Sequence>
 <Sequence name="02 · The notch" from={100} durationInFrames={74}><Statement mark="notch.">A cue from your notch.</Statement></Sequence>
 <Sequence name="04 · Stay near the lens" from={174} durationInFrames={66}><ReadShot/></Sequence>
 <Sequence name="05 · Conversation beat" from={240} durationInFrames={27}><Statement mark="next?">What will you ask next?</Statement></Sequence>
 <Sequence name="06 · Next question" from={267} durationInFrames={90}><CardShot/></Sequence>
 <Sequence name="07 · Capture a thought" from={357} durationInFrames={84}><NoteShot/></Sequence>
 <Sequence name="08 · Everyday moments montage" from={441} durationInFrames={78}><Montage/></Sequence>
 <Sequence name="09 · SmartNotch free" from={519} durationInFrames={81}><Close/></Sequence>
 <Audio name="Original published soundtrack" src={staticFile('original-soundtrack.m4a')} durationInFrames={600} volume={1}/>
 </AbsoluteFill>;
};
