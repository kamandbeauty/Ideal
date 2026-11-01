#!/usr/bin/env node
// Dependency-free preview server for motion scenes.
// Usage: npm run motion:preview   (PORT=8080 by default, binds 0.0.0.0)
import { createServer } from 'node:http';
import { createReadStream, existsSync, readdirSync, statSync } from 'node:fs';
import { extname, join, normalize, resolve, sep } from 'node:path';

const ROOT = process.cwd();
const PORT = Number(process.env.PORT || 8080);
const SKILL_ASSETS = join(ROOT, '.agents', 'skills', 'motion-graphics', 'assets');
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.mp4': 'video/mp4',
  '.webm': 'video/webm',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.ttf': 'font/ttf',
};

function safeJoin(base, rel) {
  const target = resolve(base, normalize(rel));
  return target === base || target.startsWith(base + sep) ? target : null;
}

function sendFile(res, file) {
  if (!file || !existsSync(file) || !statSync(file).isFile()) {
    res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
    res.end('Not found');
    return;
  }
  res.writeHead(200, {
    'content-type': MIME[extname(file).toLowerCase()] || 'application/octet-stream',
    'cache-control': 'no-store',
  });
  createReadStream(file).pipe(res);
}

function scenes() {
  const dir = join(ROOT, 'motion');
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true })
    .filter((e) => e.isDirectory() && existsSync(join(dir, e.name, 'index.html')))
    .map((e) => e.name);
}

function campaignLinks() {
  const base = '/motion/kamand-eyebrow-gel';
  const links = [];
  const cands = [
    ['1080p MP4', `${base}/exports/kamand-eyebrow-gel-1080p.mp4`],
    ['4K MP4', `${base}/exports/kamand-eyebrow-gel-4k.mp4`],
    ['Contact sheet', `${base}/stills/contact-sheet.jpg`],
    ['Clean 1080p', `${base}/exports/kamand-eyebrow-gel-1080p-no-text.mp4`],
    ['Clean 4K', `${base}/exports/kamand-eyebrow-gel-4k-no-text.mp4`],
  ];
  for (const [label, href] of cands) {
    const rel = href.replace('/motion/', '');
    if (existsSync(join(ROOT, 'motion', rel))) links.push(`<a href="${href}">${label}</a>`);
  }
  return links.length
    ? `<h2>KAMAND campaign</h2><p>${links.join(' · ')}</p>`
    : '';
}

function indexPage() {
  const items = scenes();
  const list = items.length
    ? items.map((s) => `<li><a href="/motion/${s}/index.html">${s}</a> <span>· <a href="/motion/${s}/index.html?frame=90">single frame</a></span></li>`).join('\n')
    : '<li><em>No scenes yet. Run <code>npm run motion:new -- my-scene</code></em></li>';
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>Ideal motion preview</title>
<style>body{font:16px/1.6 system-ui,sans-serif;max-width:760px;margin:60px auto;padding:0 24px;background:#0b0d14;color:#f7f8fc}
a{color:#ff5c8a}code{background:#141828;padding:2px 6px;border-radius:4px}li{margin:8px 0}span{color:#a6adbf}</style>
</head><body><h1>Ideal · motion preview</h1>
<p>Starter template: <a href="/starter.html">starter.html</a> (plays in real time; append <code>?frame=90</code> for a single frame).</p>
${campaignLinks()}<h2>Scenes</h2><ul>${list}</ul>
<p>Exports live in <code>motion/&lt;slug&gt;/exports/</code>. Frames are driven by <code>window.__MOTION__.seek(frame)</code>.</p>
</body></html>`;
}

createServer((req, res) => {
  const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  if (pathname === '/' || pathname === '/index.html') {
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
    res.end(indexPage());
    return;
  }
  if (pathname === '/starter.html') {
    sendFile(res, join(SKILL_ASSETS, 'starter.html'));
    return;
  }
  // Only whitelisted trees are exposed; .git, node_modules, etc. stay private.
  const roots = [
    ['/motion/', join(ROOT, 'motion')],
    ['/out/', join(ROOT, 'out')],
    ['/assets/', SKILL_ASSETS],
  ];
  for (const [prefix, base] of roots) {
    if (pathname.startsWith(prefix)) {
      sendFile(res, safeJoin(base, pathname.slice(prefix.length)));
      return;
    }
  }
  res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
  res.end('Not found');
}).listen(PORT, '0.0.0.0', () => {
  console.log(`Motion preview listening on http://0.0.0.0:${PORT}/`);
});
