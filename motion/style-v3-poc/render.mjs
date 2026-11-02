#!/usr/bin/env node
/**
 * style-v3 PoC renderer — 2D cutout rig proof of concept.
 *
 *   node render.mjs --stills 6     # a handful of review PNGs in stills/
 *   node render.mjs                # exports/poc-rig-1080x1920.mp4
 */
import { existsSync, mkdirSync, rmSync, statSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '../..');
const argv = process.argv.slice(2);
const stillsIdx = argv.indexOf('--stills');
const stillsCount = stillsIdx !== -1 ? Number(argv[stillsIdx + 1]) : 0;
const keep = argv.includes('--keep');
const fast = argv.includes('--fast');
const FRAME_DIR = '/tmp/style-v3-poc-frames';
const W = 1080, H = 1920, FPS = 30;

function ffmpegPath() {
  const p = join(ROOT, 'node_modules', '@ffmpeg-installer', 'linux-x64', 'ffmpeg');
  if (!existsSync(p)) throw new Error(`Missing bundled ffmpeg: ${p}. Run npm install.`);
  return p;
}

async function browser() {
  const mod = await import('@sparticuz/chromium');
  const Chromium = mod.default;
  const { inflate, setupLambdaEnvironment } = mod;
  await inflate(join(ROOT, 'node_modules', '@sparticuz', 'chromium', 'bin', 'al2023.tar.br'));
  setupLambdaEnvironment('/tmp/al2023/lib');
  process.env.LD_LIBRARY_PATH = ['/tmp/al2023/lib', process.env.LD_LIBRARY_PATH || ''].filter(Boolean).join(':');
  const executablePath = await Chromium.executablePath();
  const { chromium } = await import('playwright-core');
  return chromium.launch({ executablePath, headless: true, args: Chromium.args, env: { ...process.env } });
}

const b = await browser();
const context = await b.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
const page = await context.newPage();
page.on('pageerror', (e) => console.error(`[page error] ${e.message}`));
await page.goto(pathToFileURL(join(HERE, 'index.html')).href, { waitUntil: 'load' });
await page.waitForFunction(() => window.__MOTION__?.ready === true, null, { timeout: 30000 });
if (fast) await page.addStyleTag({ content: '.grain { display: none !important; }' });
const meta = await page.evaluate(() => {
  const m = window.__MOTION__;
  return { fps: m.fps, frames: m.frames, width: m.width, height: m.height, duration: m.duration };
});
console.log(`scene: ${meta.width}x${meta.height} @ ${meta.fps}fps — ${meta.frames} frames (${meta.duration}s)`);

const stage = await page.$('#stage');

if (stillsCount) {
  const dir = join(HERE, 'stills');
  mkdirSync(dir, { recursive: true });
  for (let i = 0; i < stillsCount; i++) {
    const f = Math.round((i * (meta.frames - 1)) / Math.max(1, stillsCount - 1));
    await page.evaluate((n) => window.__MOTION__.seek(n), f);
    await page.waitForTimeout(60);
    const out = join(dir, `poc-${String(i + 1).padStart(2, '0')}.png`);
    await stage.screenshot({ path: out });
    console.log(`  still ${out} (frame ${f})`);
  }
  await b.close();
  process.exit(0);
}

if (!keep) rmSync(FRAME_DIR, { recursive: true, force: true });
mkdirSync(FRAME_DIR, { recursive: true });
const t0 = Date.now();
for (let f = 0; f < meta.frames; f++) {
  await page.evaluate((n) => window.__MOTION__.seek(n), f);
  await stage.screenshot({ path: join(FRAME_DIR, `f_${String(f).padStart(5, '0')}.png`), type: 'png' });
  if (f % 30 === 0) process.stdout.write(`\r  frame ${f}/${meta.frames}`);
}
console.log(`\n  captured ${meta.frames} frames in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
await b.close();

const out = join(HERE, 'exports', `poc-rig-${W}x${H}.mp4`);
mkdirSync(dirname(out), { recursive: true });
const args = [
  '-y', '-hide_banner', '-loglevel', 'error',
  '-framerate', String(FPS), '-i', join(FRAME_DIR, 'f_%05d.png'),
  ...(fast ? ['-vf', 'noise=alls=7:allf=t'] : []),
  '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p',
  '-movflags', '+faststart', out,
];
const r = spawnSync(ffmpegPath(), args, { stdio: 'inherit' });
if (r.status !== 0) throw new Error('ffmpeg failed');
console.log(`  ${out}  ${(statSync(out).size / 1048576).toFixed(1)} MB`);
