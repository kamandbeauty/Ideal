#!/usr/bin/env node
// Renders the terminal-1988 composition to MP4 with the narration.
//   node render.mjs --sample    # 8 review stills
//   node render.mjs             # 1080x1920 MP4 with audio
import { existsSync, mkdirSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '../..');
const args = process.argv.slice(2);
const SAMPLE = args.includes('--sample');
const FPS = 30;
const DURATION = 51.6;
const VO = join(HERE, 'audio', 'vo.wav');
const FRAMES = '/tmp/terminal-1988-frames';
const EXPORTS = join(HERE, 'exports');
const STILLS = join(HERE, 'stills');

function ff(bin) {
  const p = join(ROOT, 'node_modules', '@ffmpeg-installer', 'linux-x64', bin);
  return existsSync(p) ? p : bin;
}

async function browser() {
  // The bundled Chromium needs the Lambda shared libraries unpacked next to it.
  const libDir = '/tmp/al2023/lib';
  if (existsSync(libDir)) {
    process.env.LD_LIBRARY_PATH = [libDir, process.env.LD_LIBRARY_PATH || ''].filter(Boolean).join(':');
  }
  const { chromium } = await import('playwright-core');
  const candidates = [
    '/tmp/chromium',
    join(ROOT, 'node_modules', '@sparticuz', 'chromium', 'bin', 'chromium'),
  ];
  const executablePath = candidates.find(existsSync) || undefined;
  return chromium.launch({
    executablePath, headless: true,
    env: { ...process.env },
    args: ['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--disable-dev-shm-usage'],
  });
}

const b = await browser();
const page = await b.newPage({ viewport: { width: 1080, height: 1920 } });
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
await page.goto(pathToFileURL(join(HERE, 'index.html')).href, { waitUntil: 'load' });
await page.waitForFunction(() => typeof window.__render === 'function', null, { timeout: 30000 });
await page.waitForTimeout(600);

if (SAMPLE) {
  mkdirSync(STILLS, { recursive: true });
  for (const t of [1.5, 5, 9, 14, 19, 27, 34, 47]) {
    await page.evaluate((tt) => window.__render(tt), t);
    await page.waitForTimeout(120);
    await page.screenshot({ path: join(STILLS, `still-${String(t).replace('.', '_')}.png`) });
  }
  console.log('stills written to', STILLS);
} else {
  rmSync(FRAMES, { recursive: true, force: true });
  mkdirSync(FRAMES, { recursive: true });
  const total = Math.round(DURATION * FPS);
  for (let f = 0; f < total; f++) {
    await page.evaluate((t) => window.__render(t), f / FPS);
    await page.screenshot({ path: join(FRAMES, `f-${String(f).padStart(6, '0')}.png`) });
    if (f % 150 === 0) process.stdout.write(`  ${f}/${total}\n`);
  }
  mkdirSync(EXPORTS, { recursive: true });
  const out = join(EXPORTS, 'terminal-1988-1080p.mp4');
  const r = spawnSync(ff('ffmpeg'), [
    '-y', '-loglevel', 'error',
    '-framerate', String(FPS), '-i', join(FRAMES, 'f-%06d.png'),
    '-i', VO,
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '160k', '-shortest', '-movflags', '+faststart', out,
  ], { encoding: 'utf8' });
  if (r.status !== 0) { console.error(r.stderr); process.exit(1); }
  console.log('rendered', out);
}
if (errors.length) console.log('page errors:', errors.slice(0, 3));
await b.close();
