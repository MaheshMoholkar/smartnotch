import {build} from 'esbuild';
import {createReadStream} from 'node:fs';
import {mkdir, stat, writeFile} from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const project = fileURLToPath(new URL('..', import.meta.url));
const output = path.resolve(project, '../dist/ad-preview');
const assets = path.join(project, 'public');
await mkdir(output, {recursive: true});
await build({entryPoints: [path.join(project, 'src/preview.jsx')], outfile: path.join(output, 'app.js'), bundle: true, platform: 'browser', format: 'iife', jsx: 'automatic', minify: false, define: {'process.env.NODE_ENV': '"production"'}});
await writeFile(path.join(output, 'index.html'), `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SmartNotch ad preview</title><style>
*{box-sizing:border-box}body{margin:0;background:#0b0d0c;color:#f4f6f2;font-family:Arial,Helvetica,sans-serif}main{max-width:1360px;padding:40px 36px;margin:auto}header{margin-bottom:26px}.eyebrow{color:#a6efcd;letter-spacing:.15em;font-size:12px}h1{font-size:38px;font-weight:500;letter-spacing:-1.6px;margin:14px 0 10px}em{font-family:Georgia,serif;color:#a6efcd;font-weight:400}p{color:#91a799;font-size:14px}.viewer{overflow:hidden;border:1px solid #a6efcd25;border-radius:16px;box-shadow:0 28px 70px #0006}nav{display:flex;gap:9px;flex-wrap:wrap;margin-top:22px}button{border:1px solid #a6efcd25;background:#17221b;color:#d7eade;padding:10px 18px;border-radius:9px;font:inherit;font-size:13px;cursor:pointer}button:hover{background:#25402e}button:focus-visible{outline:2px solid #a6efcd;outline-offset:3px}.hint{margin-top:18px;color:#7c9685}@media(max-width:600px){main{padding:24px 12px}h1{font-size:28px}nav{gap:6px}button{padding:9px 13px}}
</style></head><body><div id="root"></div><script src="/app.js"></script></body></html>`);

if (process.argv.includes('--build-only')) {console.log('Updated original-ad preview bundle.'); process.exit(0);}

const types = {'.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.png': 'image/png', '.wav': 'audio/wav', '.m4a': 'audio/mp4'};
const server = http.createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url ?? '/', 'http://localhost').pathname);
    let file;
    let info;
    for (const root of [output, assets]) {
      const candidate = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
      if (!candidate.startsWith(root + path.sep)) continue;
      try { const item = await stat(candidate); if (item.isFile()) {file = candidate; info = item; break;} } catch {}
    }
    if (!file || !info) {response.writeHead(404); response.end('Not found'); return;}
    const headers = {'Content-Type': types[path.extname(file)] ?? 'application/octet-stream', 'Accept-Ranges': 'bytes', 'Cache-Control': 'no-store'};
    const range = request.headers.range?.match(/^bytes=(\d+)-(\d*)$/);
    if (range) {
      const start = Number(range[1]);
      const end = Math.min(info.size - 1, range[2] ? Number(range[2]) : info.size - 1);
      if (start >= info.size || end < start) {response.writeHead(416, {'Content-Range': 'bytes */' + info.size}); response.end(); return;}
      response.writeHead(206, {...headers, 'Content-Range': 'bytes ' + start + '-' + end + '/' + info.size, 'Content-Length': end - start + 1});
      createReadStream(file, {start, end}).pipe(response);
    } else {
      response.writeHead(200, {...headers, 'Content-Length': info.size});
      if (request.method === 'HEAD') response.end(); else createReadStream(file).pipe(response);
    }
  } catch {response.writeHead(500); response.end('Preview error');}
});
const port = Number(process.env.SMARTNOTCH_AD_PORT || 4317);
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid SMARTNOTCH_AD_PORT');
server.listen(port, '127.0.0.1', () => console.log('SmartNotch ad preview: http://127.0.0.1:' + port));
