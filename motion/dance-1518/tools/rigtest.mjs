import { existsSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
const ROOT = '/home/user/Ideal';
const mod = await import('@sparticuz/chromium');
const Chromium = mod.default;
const { inflate, setupLambdaEnvironment } = mod;
await inflate(join(ROOT, 'node_modules', '@sparticuz', 'chromium', 'bin', 'al2023.tar.br'));
setupLambdaEnvironment('/tmp/al2023/lib');
process.env.LD_LIBRARY_PATH = ['/tmp/al2023/lib', process.env.LD_LIBRARY_PATH || ''].filter(Boolean).join(':');
const executablePath = await Chromium.executablePath();
const { chromium } = await import('playwright-core');
const b = await chromium.launch({ executablePath, headless: true, args: Chromium.args, env: { ...process.env } });
const page = await b.newPage({ viewport: { width: 1400, height: 1500 }, deviceScaleFactor: 1 });
const html = `<!doctype html><html><body style="margin:0;background:#1c1a17">
<svg id="s" width="1400" height="1500" viewBox="0 0 1400 1500"><g id="stage"></g></svg>
<script type="module">
import { buildRig, poseRig, preloadParts } from './engine/partrig.js';
await preloadParts();
const st = document.getElementById('stage');
const defs = JSON.parse(new URLSearchParams(location.search).get('defs') || '[]');
defs.forEach((d, i) => {
  const g = buildRig();
  st.appendChild(g);
  poseRig(g, d, 0, 200 + i * 330, 1400);
});
window.__DONE__ = true;
</script></body></html>`;
writeFileSync('/home/user/Ideal/motion/dance-1518/_rigtest.html', html);
const defs = JSON.stringify([
  { mood: 'neutral', scale: 1.2 },
  { mood: 'dance', scale: 1.2 },
]);
await page.goto('file:///home/user/Ideal/motion/dance-1518/_rigtest.html?defs=' + encodeURIComponent(defs));
await page.waitForFunction(() => window.__DONE__ === true, null, { timeout: 20000 });
await page.waitForTimeout(300);
await page.screenshot({ path: '/tmp/rigtest.png' });
await b.close();
console.log('ok');
