import { readdir, readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const site = fileURLToPath(new URL('..', import.meta.url));
const ready = process.argv.includes('--ready') || process.env.VERCEL === '1';
const binary = /\.(dmg|exe|msi|msix|pkg|nupkg|snupkg|appimage|deb|rpm|zip|tar|tar\.gz|tgz|7z)$/i;
const json = async name => JSON.parse(await readFile(path.join(site, name), 'utf8'));
const errors = [];

async function inspect(directory) {
  let total = 0;
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isSymbolicLink()) { errors.push(`Unexpected public symlink: ${file}`); continue; }
    if (entry.isDirectory()) { total += await inspect(file); continue; }
    const size = (await stat(file)).size;
    total += size;
    if (binary.test(entry.name)) errors.push(`Release binary must be outside the website: ${file}`);
    if (size > 10 * 1024 * 1024) errors.push(`Website asset exceeds 10 MiB: ${file}`);
  }
  return total;
}

const total = await inspect(path.join(site, 'public'));
if (total > 20 * 1024 * 1024) errors.push('public/ exceeds the 20 MiB website budget');
if (process.argv.includes('--output')) {
  const size = await inspect(path.join(site, 'out'));
  if (size > 20 * 1024 * 1024) errors.push('out/ exceeds the 20 MiB website budget');
}

const registry = await json('release-assets.json');
const vercel = await json('vercel.json');
const redirects = new Map((vercel.redirects || []).map(rule => [rule.source, rule]));
const pending = [];
for (const [route, asset] of Object.entries(registry.routes)) {
  const base = registry.releases[asset.version];
  if (!base) { pending.push(asset.version); continue; }
  const expected = `${base}/${asset.asset}`;
  const rule = redirects.get(route);
  if (!rule || rule.destination !== expected || rule.permanent !== false) errors.push(`Missing or stale redirect: ${route}`);
}

const downloads = await json('app/downloads.json');
for (const platform of Object.values(downloads)) {
  if (ready && !platform.file.startsWith('https://github.com/')) errors.push(`Configure the GitHub download for ${platform.label}`);
}

// Check unchanged feeds against registered binary paths; never rewrite signed metadata.
const appcast = await readFile(path.join(site, 'public/updates/mac/appcast.xml'), 'utf8');
for (const [, url] of appcast.matchAll(/\burl="([^"]+)"/g)) {
  const route = new URL(url).pathname;
  if (!registry.routes[route]) errors.push(`Unregistered Mac archive: ${route}`);
}
for (const runtime of await readdir(path.join(site, 'public/updates/windows'))) {
  const prefix = `/updates/windows/${runtime}/`;
  const feed = await json(`public${prefix}releases.win.json`);
  for (const asset of feed.Assets) {
    const entry = registry.routes[prefix + asset.FileName];
    if (!entry || entry.sha256.toLowerCase() !== asset.SHA256.toLowerCase()) errors.push(`Unregistered or mismatched Windows package: ${prefix}${asset.FileName}`);
  }
}

if (pending.length) {
  const message = `GitHub release URL pending for ${[...new Set(pending)].join(', ')}. Configure it before deploying.`;
  if (ready) errors.push(message); else console.warn(message);
}
if (errors.length) {
  for (const error of errors) console.error(error);
  process.exitCode = 1;
} else {
  console.log(`Website verified: ${(total / 1024 / 1024).toFixed(2)} MiB public assets, no installers or update packages.`);
}
