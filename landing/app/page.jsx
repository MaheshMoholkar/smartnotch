import DownloadPicker from './download-picker';
import downloads from './downloads.json';
import Icon from './icons';
import { AppearanceDemo, PageMotion, ProductDemo, ProductFilm, WorkspaceExplorer } from './experience';

const questions = [
  ['Will it work on my computer?', <p key="systems">SmartNotch supports Apple silicon Macs running macOS 14 or later. A physical notch isn’t required.</p>],
  ['How does voice follow work?', <p key="voice">On Mac, SmartNotch uses Apple’s on-device speech recognition to follow your script as you speak. Choose English (US), English (India), or Hindi (India). Microphone and speech permissions are requested when you start Voice mode. Auto-scroll and manual reading are also available.</p>],
  ['Do I need an account or internet connection?', <p key="offline">No account needed. Your scripts, cue cards, notes, and settings save on your computer, and the workspace works offline. An internet connection is needed to download updates.</p>],
  ['Can viewers see it when I share my screen?', <p key="sharing">The panel can appear in screen recordings and screen shares. Share a specific application window or browser tab, and check what your audience sees before you go live.</p>],
  ['Can I bring my own scripts and notes?', <p key="files">Absolutely. Import UTF-8 .txt or .md files into Read or Notes. Import a list of talking points into Cards, with one new card per non-empty line. You can export your content back to text whenever you like.</p>],
  ['What are the keyboard shortcuts?', <div key="shortcuts"><p>Use Control + Option together with:</p><dl className="keyboard-help"><div><dt><kbd>P</kbd></dt><dd>Show or hide the panel</dd></div><div><dt><kbd>Space</kbd></dt><dd>Play or pause in Read; open Cards or Notes</dd></div><div><dt><kbd>↑</kbd> <kbd>↓</kbd></dt><dd>Previous or next paragraph or card</dd></div></dl><p>Command + 1 opens the editor.</p></div>],
];

function Brand({ large = false }) {
  return <a className={`brand ${large ? 'brand-large' : ''}`} href="#top" aria-label="SmartNotch home"><span className="brand-mark"><img src="/assets/icon.png" width="30" height="30" alt="" /></span>SmartNotch</a>;
}

function Questions() {
  return <section className="faq section-shell" id="faq" aria-labelledby="faq-title">
    <div className="faq-intro" data-reveal><p className="eyebrow">A FEW GOOD QUESTIONS</p><h2 id="faq-title">Small app.<br /><em>No big mysteries.</em></h2><p>Here’s what to know before<br className="desktop-only" /> your next great take.</p></div>
    <div className="faq-list" data-reveal>
      {questions.map(([question, answer]) => <details key={question}><summary>{question}<span className="faq-toggle"><Icon name="plus" size={17} /></span></summary><div className="faq-answer">{answer}</div></details>)}
      <details id="install"><summary>How do I install SmartNotch?<span className="faq-toggle"><Icon name="plus" size={17} /></span></summary><div className="faq-answer"><p><strong>Mac:</strong> Open SmartNotch.dmg and drag the app into Applications. This release is unnotarized. If macOS blocks the first launch, go to System Settings → Privacy &amp; Security and choose Open Anyway.</p></div></details>
      {downloads.mac.inAppUpdates && <details><summary>How will I get new updates?<span className="faq-toggle"><Icon name="plus" size={17} /></span></summary><div className="faq-answer"><p>SmartNotch checks for new versions and shows an Update available button in the panel. Click it to see what’s new, download the update, and choose when to install and restart. You can also choose Check for Updates from the app menu. Your saved content stays with you.</p></div></details>}
    </div>
  </section>;
}

export default function Home() {
  const version = downloads.mac.version;
  return <>
    <PageMotion />
    <a href="#main" className="skip-link">Skip to content</a>
    <header className="site-header" id="top"><div className="header-inner section-shell"><Brand /><nav aria-label="Main navigation"><a href="#features">Product</a><a href="#workflow" className="nav-workflow">How it works</a><a href="#faq">FAQ</a></nav><span className="header-platforms"><Icon name="monitor" size={15} /> Made for Mac</span></div></header>
    <main id="main">
      <section className="hero" aria-labelledby="hero-title">
        <div className="hero-halo" aria-hidden="true" />
        <div className="hero-copy section-shell">
          <a href="#features" className="release-pill"><Icon name="sparkle" size={14} /><span>A little more presence.{version ? ` Meet v${version}.` : ''}</span></a>
          <h1 id="hero-title">Your words.<br /><em>A glance away.</em></h1>
          <p className="hero-description">Your script, talking points, and notes. Right under your camera.<br className="desktop-only" /> A little less to think about. A lot more you.</p>
          <div className="hero-actions"><DownloadPicker /><ProductFilm compact /></div>
          <p className="hero-assurance"><Icon name="check" size={14} /> No account. No getting in your way.</p>
        </div>
        <div className="hero-product section-shell"><ProductDemo /></div>
      </section>

      <section className="use-cases section-shell" aria-label="Made for your on-camera moments" data-reveal><p>FOR THE THINGS YOU<br />SAY OUT LOUD.</p><div><span>Record a video.</span><span>Lead the conversation.</span><span>Nail the interview.</span></div></section>

      <section className="workspace-section section-shell" id="features" aria-labelledby="workspace-title">
        <div className="section-heading" data-reveal><p className="eyebrow">ONE LITTLE WORKSPACE. THREE WAYS TO USE IT.</p><h2 id="workspace-title">A place for your words.<br /><em>Space to be yourself.</em></h2><p>A full script or just a few reminders.<br />Bring what you need. Leave the overthinking.</p></div>
        <WorkspaceExplorer />
      </section>

      <section className="details-section section-shell" aria-labelledby="details-title">
        <div className="details-heading" data-reveal><p className="eyebrow">THOUGHTFULLY OUT OF THE WAY</p><h2 id="details-title">The little things.<br /><em>They make a difference.</em></h2></div>
        <div className="detail-grid">
          <article className="detail-card privacy-card" data-reveal><div className="privacy-visual" aria-hidden="true"><div className="privacy-orbit orbit-one" /><div className="privacy-orbit orbit-two" /><div className="private-file file-one"><Icon name="note" size={17} /><span>my-next-big-idea.txt</span></div><div className="private-file file-two"><Icon name="cards" size={17} /><span>interview-notes.md</span></div><div className="privacy-lock"><Icon name="lock" size={36} /></div><span className="privacy-local">AT HOME. ON YOUR COMPUTER.</span></div><div className="detail-copy"><h3>Your thoughts stay yours.</h3><p>Your scripts, cards, and notes save locally.<br />No account to create. Just open it and make something.</p></div></article>
          <article className="detail-card shortcut-card" data-reveal><div className="shortcut-visual" aria-hidden="true"><kbd>⌃</kbd><kbd>⌥</kbd><kbd className="key-p">P</kbd></div><div className="detail-copy"><h3>One shortcut.<br />Back in your flow.</h3><p>Bring up the panel with Control + Option + P.</p></div></article>
          <article className="detail-card appearance-card" data-reveal><AppearanceDemo /><div className="detail-copy"><h3>Feels like your space.</h3><p>Text size, color, transparency, and panel size. Each workspace remembers how you like it.</p></div></article>
          <article className="detail-card hover-card" data-reveal><div className="hover-visual" aria-hidden="true"><div className="mini-screen"><div className="mini-notch" /><div className="mini-panel"><span /><span /><span /></div></div><div className="hover-cursor"><Icon name="cursor" size={30} /></div><span className="hover-label"><Icon name="pin" size={14} /> Stay right there.</span></div><div className="detail-copy"><h3>There when you need it.</h3><p>Hover to open. Pin to stay. Move away to clear your view. Your place is remembered.</p></div></article>
        </div>
      </section>

      <section className="workflow-section section-shell" id="workflow" aria-labelledby="workflow-title">
        <div className="workflow-heading" data-reveal><p className="eyebrow">LESS SETUP. MORE SHOWING UP.</p><h2 id="workflow-title">From “what was I saying?”<br /><em>to right in the moment.</em></h2></div>
        <div className="workflow-steps">
          {[['edit', 'Make it yours.', 'Paste a script, build a deck of talking points, or jot down a quick reminder.'], ['pin', 'Keep it close.', 'Hover at the top of your screen. Your words appear just below the camera.'], ['mic', 'Go be yourself.', 'Find your pace, pause when you need to, and pick up right where you left off.']].map(([icon, title, description]) => <article key={title} data-reveal><span className="workflow-icon"><Icon name={icon} size={24} /></span><h3>{title}</h3><p>{description}</p></article>)}
        </div>
      </section>

      <section className="film-section section-shell" id="film" aria-label="Watch SmartNotch in action" data-reveal><ProductFilm /></section>
      <Questions />
      <section className="download-section section-shell" id="download" aria-labelledby="download-title" data-reveal><div className="download-orbit" aria-hidden="true" /><span className="final-app-icon"><img src="/assets/icon.png" width="68" height="68" alt="" /></span><p className="eyebrow">GOOD WORDS DESERVE TO BE HEARD.</p><h2 id="download-title">Your next great take.<br /><em>Starts right here.</em></h2><p>Be prepared. Stay present. Sound like you.</p><DownloadPicker /><a href="#install" className="install-link">A little help getting started</a></section>
    </main>
    <footer className="site-footer section-shell"><div className="footer-top"><div><Brand large /><p>A little space for your next big idea.</p></div><div className="footer-links"><a href="#features">Explore SmartNotch</a><a href="#install">Installation</a><a href="#faq">Questions</a></div></div><div className="footer-bottom"><span>Made with care.</span><span>Made for Mac. Your words, your computer.</span><a href="#top">Back to the beginning</a></div></footer>
  </>;
}
