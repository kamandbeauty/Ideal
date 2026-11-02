#!/usr/bin/env node
// Renders the film:  node render.mjs [--sample] [--sheet] [--from A --to B]
import { existsSync, mkdirSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '../..');
const args = process.argv.slice(2);
const num = (n, d) => { const i = args.indexOf(n); return i >= 0 ? Number(args[i + 1]) : d; };
const SAMPLE = args.includes('--sample');
const FPS = num('--fps', 30);
const FRAMES = '/tmp/t1988-frames';
const EXPORTS = join(HERE, 'exports');
const STILLS = join(HERE, 'stills');

function ff(bin) {
  const p = join(ROOT, 'node_modules', '@ffmpeg-installer', 'linux-x64', bin);
  return existsSync(p) ? p : bin;
}

async function open() {
  const lib = '/tmp/al2023/lib';
  if (existsSync(lib)) process.env.LD_LIBRARY_PATH = [lib, process.env.LD_LIBRARY_PATH || ''].filter(Boolean).join(':');
  const { chromium } = await import('playwright-core');
  const exe = ['/tmp/chromium', join(ROOT, 'node_modules', '@sparticuz', 'chromium', 'bin', 'chromium')].find(existsSync);
  const browser = await chromium.launch({
    executablePath: exe, headless: true, env: { ...process.env },
    args: ['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(pathToFileURL(join(HERE, 'src', 'index.html')).href, { waitUntil: 'load' });
  await page.evaluate(() => window.__ready);
  await page.waitForTimeout(300);
  return { browser, page, errors };
}

const { browser, page, errors } = await open();
const duration = await page.evaluate(() => window.__duration);
const shots = await page.evaluate(() => window.__shots.map((s) => [s.id, s.start, s.end, s.plate]));

if (SAMPLE) {
  mkdirSync(STILLS, { recursive: true });
  const times = args.includes('--at')
    ? args[args.indexOf('--at') + 1].split(',').map(Number)
    : shots.map(([id, a, b]) => a + (b - a) * 0.55);
  for (const t of times) {
    await page.evaluate((x) => window.__render(x), t);
    await page.waitForTimeout(70);
    await page.screenshot({ path: join(STILLS, `still-${t.toFixed(2).replace('.', '_')}.png`) });
  }
  console.log(`stills: ${times.length} · ${errors.length ? errors[0] : 'no page errors'}`);
} else {
  rmSync(FRAMES, { recursive: true, force: true });
  mkdirSync(FRAMES, { recursive: true });
  mkdirSync(EXPORTS, { recursive: true });
  const from = num('--from', 0), to = num('--to', duration);
  const total = Math.round((to - from) * FPS);
  const t0 = Date.now();
  for (let f = 0; f < total; f++) {
    await page.evaluate((t) => window.__render(t), from + f / FPS);
    await page.screenshot({ path: join(FRAMES, `f-${String(f).padStart(6, '0')}.png`) });
    if (f % 120 === 0) process.stdout.write(`  ${f}/${total}  ${((Date.now() - t0) / 1000).toFixed(0)}s\n`);
  }
  const out = join(EXPORTS, 'terminal-scenes-1080p.mp4');
  const r = spawnSync(ff('ffmpeg'), [
    '-y', '-loglevel', 'error',
    '-framerate', String(FPS), '-i', join(FRAMES, 'f-%06d.png'),
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-pix_fmt', 'yuv420p',
    '-movflags', '+faststart', out,
  ], { encoding: 'utf8' });
  if (r.status !== 0) { console.error(r.stderr); process.exit(1); }
  console.log('rendered', out, errors.length ? `(page errors: ${errors.slice(0, 2)})` : '(clean)');
}
await browser.close();
