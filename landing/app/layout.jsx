import './globals.css';

export const metadata = {
  title: 'SmartNotch — Your words. A glance away.',
  description: 'A little workspace right under your camera. Keep scripts, cue cards, and notes close, stay present, and sound like yourself. For Mac, Windows, and Linux.',
  icons: { icon: '/assets/icon.png', apple: '/assets/icon.png' },
  openGraph: {
    title: 'SmartNotch — Your words. A glance away.',
    description: 'Your script, talking points, and notes. Right under your camera. For Mac, Windows, and Linux.',
    type: 'website',
    images: [{ url: 'https://smartnotch.vercel.app/assets/read-preview.jpg', width: 880, height: 366, alt: 'SmartNotch desktop teleprompter' }],
  },
};

export const viewport = { colorScheme: 'dark', themeColor: '#0b0d0c' };

export default function RootLayout({ children }) {
  return <html lang="en"><body>{children}</body></html>;
}
