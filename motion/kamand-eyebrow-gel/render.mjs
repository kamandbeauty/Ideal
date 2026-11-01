#!/usr/bin/env node
// Render the KAMAND 9:16 commercial to real MP4 files.
// Uses the bundled headless Chromium (@sparticuz/chromium), playwright-core,
// and the bundled ffmpeg binary (@ffmpeg-installer/linux-x64) — no system
// packages and no CDN downloads required.
//
//   node render.mjs --sample            # 6 review stills at 1080x1920
//   node render.mjs                     # 1080p master + lanczos-upscaled 4K MP4
//   node render.mjs --no-text           # clean master, text added in post
import { existsSync, mkdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '../..');
const args = process.argv.slice(2);
const sample = args.includes('--sample');
const noText = args.includes('--no-text');
const limitIdx = args.indexOf('--limit');
const limit = limitIdx !== -1 ? Number(args[limitIdx + 1]) : null;
const tag = noText ? '-no-text' : '';

const FPS = 24;
const DPR = 1; // source plates are 768x1376; captured at 1080x1920 then lanczos-upscaled to 4K
const SCENE_MIDS = [54, 148, 278, 342, 525, 610]; // one review frame per scene
const FRAME_DIR = '/tmp/kamand-frames';
const EXPORTS = join(HERE, 'exports');
const STILLS = join(HERE, 'stills');

function ffmpegPath() {
  const p = join(ROOT, 'node_modules', '@ffmpeg-installer', 'linux-x64', 'ffmpeg');
  if (!existsSync(p)) throw new Error(`Missing bundled ffmpeg: ${p}. Run npm install.`);
  return p;
}

async function browser() {
  const mod = await import('@sparticuz/chromium');
  const Chromium = mod.default;
  const { inflate, setupLambdaEnvironment } = mod;
  const binDir = join(ROOT, 'node_modules', '@sparticuz', 'chromium', 'bin');
  // The Amazon Linux shared libraries are not inflated automatically on a
  // generic Linux host; inflate them explicitly so Chromium can find libnss3.
  await inflate(join(binDir, 'al2023.tar.br'));
  setupLambdaEnvironment('/tmp/al2023/lib');
  process.env.LD_LIBRARY_PATH = ['/tmp/al2023/lib', process.env.LD_LIBRARY_PATH || '']
    .filter(Boolean).join(':');
  const executablePath = await Chromium.executablePath();
  const { chromium } = await import('playwright-core');
  const instance = await chromium.launch({
    executablePath,
    headless: true,
    args: Chromium.args,
    env: { ...process.env },
  });
  return instance;
}

async function openScene(b, dpr) {
  const context = await b.newContext({
    viewport: { width: 1080, height: 1920 },
    deviceScaleFactor: dpr,
  });
  const page = await context.newPage();
  page.on('pageerror', (e) => console.error(`[page error] ${e.message}`));
  const q = noText ? '?frame=0&noText=1' : '?frame=0';
  await page.goto(pathToFileURL(join(HERE, 'index.html')).href + q, { waitUntil: 'load' });
  await page.waitForFunction(() => window.__MOTION__?.ready === true, null, { timeout: 30000 });
  const meta = await page.evaluate(() => {
    const m = window.__MOTION__;
    return { fps: m.fps, frames: m.frames, width: m.width, height: m.height };
  });
  return { context, page, meta };
}

async function sampleStills(b) {
  mkdirSync(STILLS, { recursive: true });
  const { context, page, meta } = await openScene(b, 1);
  console.log(`Scene: ${meta.frames} frames @ ${meta.fps} fps, ${meta.width}x${meta.height}`);
  for (let i = 0; i < SCENE_MIDS.length; i++) {
    const f = Math.min(SCENE_MIDS[i], meta.frames - 1);
    await page.evaluate((fr) => window.__MOTION__.seek(fr), f);
    const out = join(STILLS, `s${i + 1}.jpg`);
    await page.screenshot({ path: out, type: 'jpeg', quality: 88 });
    console.log(`  still s${i + 1}: frame ${f} -> ${out}`);
  }
  await context.close();
}

async function fullRender(b) {
  mkdirSync(EXPORTS, { recursive: true });
  rmSync(FRAME_DIR, { recursive: true, force: true });
  mkdirSync(FRAME_DIR, { recursive: true });
  const { context, page, meta } = await openScene(b, DPR);
  const total = limit ? Math.min(limit, meta.frames) : meta.frames;
  console.log(`Rendering ${total} frames at ${meta.width * DPR}x${meta.height * DPR} / ${meta.fps} fps (4K master upscaled in ffmpeg)`);
  const cdp = await context.newCDPSession(page);
  // CDP capture works in CSS pixels unless the device metrics are overridden.
  await cdp.send('Emulation.setDeviceMetricsOverride', {
    width: meta.width, height: meta.height, deviceScaleFactor: DPR, mobile: false,
  });
  const t0 = Date.now();
  for (let i = 0; i < total; i++) {
    await page.evaluate((fr) => window.__MOTION__.seek(fr), i);
    // CDP capture avoids Playwright's per-screenshot font/layout waits.
    const { data } = await cdp.send('Page.captureScreenshot', {
      format: 'jpeg', quality: 94, captureBeyondViewport: false, fromSurface: true,
    });
    writeFileSync(join(FRAME_DIR, `f_${String(i).padStart(5, '0')}.jpg`), Buffer.from(data, 'base64'));
    if ((i + 1) % 24 === 0 || i + 1 === total) {
      const secs = ((Date.now() - t0) / 1000).toFixed(0);
      process.stdout.write(`  ${i + 1}/${total} frames (${secs}s)\r`);
    }
  }
  process.stdout.write('\n');
  await context.close();
  if (limit) {
    console.log(`Benchmark/limit done: ${total} frames, ${((Date.now() - t0) / 1000).toFixed(1)}s`);
    return;
  }

  const ff = ffmpegPath();
  const mp4 = join(EXPORTS, `kamand-eyebrow-gel-4k${tag}.mp4`);
  const small = join(EXPORTS, `kamand-eyebrow-gel-1080p${tag}.mp4`);
  const input = join(FRAME_DIR, 'f_%05d.jpg');

  console.log('Encoding native 1080x1920 master…');
  let r = spawnSync(ff, [
    '-y', '-framerate', String(meta.fps), '-i', input,
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '19',
    '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-r', String(meta.fps), small,
  ], { stdio: 'inherit' });
  if (r.status !== 0) { console.error('ffmpeg 1080p encode failed; frames kept in', FRAME_DIR); process.exit(r.status || 1); }

  console.log('Encoding 4K (2160x3840) master with lanczos upscale…');
  r = spawnSync(ff, [
    '-y', '-framerate', String(meta.fps), '-i', input,
    '-vf', 'scale=2160:3840:flags=lanczos,unsharp=5:5:0.4:5:5:0.0',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '20',
    '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-r', String(meta.fps), mp4,
  ], { stdio: 'inherit' });
  if (r.status !== 0) { console.error('ffmpeg 4K encode failed; frames kept in', FRAME_DIR); process.exit(r.status || 1); }

  console.log(`4K    ${mp4}  ${(statSync(mp4).size / 1048576).toFixed(1)} MB`);
  console.log(`1080p ${small}  ${(statSync(small).size / 1048576).toFixed(1)} MB`);
  rmSync(FRAME_DIR, { recursive: true, force: true });
}

const b = await browser();
try {
  if (sample) await sampleStills(b);
  else await fullRender(b);
} finally {
  await b.close();
}
