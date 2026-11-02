#!/usr/bin/env node
/**
 * THE ODD FILE — renderer.
 *
 *   node render.mjs --sample        # review stills (PNG) in stills/
 *   node render.mjs                 # 1080x1920 MP4 + 4K upscale, with audio
 *   node render.mjs --limit 60      # quick benchmark
 *   node render.mjs --no-audio      # silent master
 *
 * Deterministic: every frame is captured by calling window.__MOTION__.seek(i).
 */
import { existsSync, mkdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '../..');
const argv = process.argv.slice(2);
const sample = argv.includes('--sample');
const beats = argv.includes('--beats');
const silent = argv.includes('--no-audio');
const fast = argv.includes('--fast');
const no4k = argv.includes('--no-4k');
const limitIdx = argv.indexOf('--limit');
const limit = limitIdx !== -1 ? Number(argv[limitIdx + 1]) : null;

const FRAME_DIR = '/tmp/odd-file-frames';
const { EPISODE } = await import(pathToFileURL(join(HERE, 'content', 'episode.js')).href);
const SLUG = `file-${String(EPISODE.code || '000').replace(/[^0-9]/g, '').padStart(3, '0')}`;
const EXPORTS = join(HERE, 'exports');
const STILLS = join(HERE, 'stills');
const AUDIO = join(HERE, 'audio', 'mix.wav');
const SAMPLE_FRACTIONS = [0.06, 0.13, 0.2, 0.28, 0.36, 0.45, 0.55, 0.66, 0.78, 0.9];

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
  process.env.LD_LIBRARY_PATH = ['/tmp/al2023/lib', process.env.LD_LIBRARY_PATH || '']
    .filter(Boolean)
    .join(':');
  const executablePath = await Chromium.executablePath();
  const { chromium } = await import('playwright-core');
  return chromium.launch({
    executablePath,
    headless: true,
    args: Chromium.args,
    env: { ...process.env },
  });
}

async function openScene(b) {
  const context = await b.newContext({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  const page = await context.newPage();
  page.on('pageerror', (e) => console.error(`[page error] ${e.message}`));
  page.on('console', (m) => {
    if (m.type() === 'error') console.error(`[console] ${m.text()}`);
  });
  await page.goto(pathToFileURL(join(HERE, 'index.html')).href + '?frame=0', { waitUntil: 'load' });
  await page.waitForFunction(() => window.__MOTION__?.ready === true, null, { timeout: 30000 });
  if (fast) {
    // Full-screen CSS noise is expensive to rasterise every frame; the same
    // grain is added at encode time with ffmpeg's noise filter instead.
    await page.addStyleTag({ content: '.grain, .scan { display: none !important; }' });
  }
  const meta = await page.evaluate(() => {
    const m = window.__MOTION__;
    return { fps: m.fps, frames: m.frames, width: m.width, height: m.height, duration: m.duration };
  });
  // the scene declares its own format; resize the page to match
  await page.setViewportSize({ width: meta.width, height: meta.height });
  const cdp = await context.newCDPSession(page);
  await cdp.send('Emulation.setDeviceMetricsOverride', {
    width: meta.width,
    height: meta.height,
    deviceScaleFactor: 1,
    mobile: false,
  });
  return { context, page, cdp, meta };
}

async function sampleStills(b) {
  mkdirSync(STILLS, { recursive: true });
  const { context, page, meta } = await openScene(b);
  console.log(
    `Scene: ${meta.frames} frames @ ${meta.fps} fps (${(meta.frames / meta.fps).toFixed(2)} s)`,
  );
  const picks = SAMPLE_FRACTIONS.map((f) => Math.min(Math.round(f * meta.frames), meta.frames - 1));
  for (let i = 0; i < picks.length; i++) {
    await page.evaluate((fr) => window.__MOTION__.seek(fr), picks[i]);
    await page.screenshot({ path: join(STILLS, `s${String(i + 1).padStart(2, '0')}.jpg`), type: 'jpeg', quality: 92 });
    console.log(`  s${i + 1}: frame ${picks[i]} (${(picks[i] / meta.fps).toFixed(2)} s)`);
  }
  await context.close();
}

async function beatStills(b) {
  const out = join(STILLS, `ep${String(EPISODE.code).replace(/[^0-9]/g, '')}`);
  mkdirSync(out, { recursive: true });
  const { TIMELINE } = await import(pathToFileURL(join(HERE, 'timeline.js')).href);
  const { context, page, meta } = await openScene(b);
  for (const bt of TIMELINE.beats) {
    const at = bt.start + Math.min(1.9, bt.dur * 0.55);
    const fr = Math.min(meta.frames - 1, Math.round(at * meta.fps));
    await page.evaluate((f) => window.__MOTION__.seek(f), fr);
    await page.screenshot({ path: join(out, `${bt.id}.jpg`), type: 'jpeg', quality: 92 });
    console.log(`  ${bt.id} @ ${(fr / meta.fps).toFixed(2)}s`);
  }
  await context.close();
}

async function fullRender(b) {
  mkdirSync(EXPORTS, { recursive: true });
  const useAudio = !silent;
  if (useAudio && !existsSync(AUDIO)) {
    throw new Error(`Missing ${AUDIO}. Run: npm run odd-file:audio && npm run odd-file:timeline`);
  }
  rmSync(FRAME_DIR, { recursive: true, force: true });
  mkdirSync(FRAME_DIR, { recursive: true });

  const first = await openScene(b);
  const meta = first.meta;
  const total = limit ? Math.min(limit, meta.frames) : meta.frames;
  console.log(
    `Rendering ${total} frames at ${meta.width}x${meta.height} @ ${meta.fps} fps ` +
      `(${(total / meta.fps).toFixed(2)} s)`,
  );

  const t0 = Date.now();
  for (let i = 0; i < total; i++) {
    await first.page.evaluate((fr) => window.__MOTION__.seek(fr), i);
    const { data } = await first.cdp.send('Page.captureScreenshot', {
      format: 'jpeg',
      quality: fast ? 86 : 93,
      optimizeForSpeed: fast,
      captureBeyondViewport: false,
      fromSurface: true,
    });
    writeFileSync(join(FRAME_DIR, `f_${String(i).padStart(5, '0')}.jpg`), Buffer.from(data, 'base64'));
    if ((i + 1) % 120 === 0 || i + 1 === total) {
      console.log(`  ${i + 1}/${total} frames (${((Date.now() - t0) / 1000).toFixed(0)} s)`);
    }
  }
  await first.context.close();
  console.log(`  captured in ${((Date.now() - t0) / 1000).toFixed(0)} s`);
  if (limit) return;

  const ff = ffmpegPath();
  const input = join(FRAME_DIR, 'f_%05d.jpg');
  const small = join(EXPORTS, `${SLUG}-1080p.mp4`);
  const big = join(EXPORTS, `${SLUG}-4k.mp4`);
  const upscale = meta.width > meta.height ? 'scale=3840:2160:flags=lanczos' : 'scale=2160:3840:flags=lanczos';
  const audioArgs = useAudio ? ['-i', AUDIO] : [];
  const common = [
    '-c:v', 'libx264', '-preset', 'slow', '-pix_fmt', 'yuv420p',
    '-movflags', '+faststart',
    ...(useAudio ? ['-c:a', 'aac', '-b:a', '192k', '-shortest'] : []),
  ];

  console.log(`Encoding ${meta.width}x${meta.height}…`);
  let r = spawnSync(ff, [
    '-y', '-framerate', String(meta.fps), '-i', input, ...audioArgs,
    ...(fast ? ['-vf', 'noise=alls=9:allf=t'] : []),
    '-crf', '18', ...common, small,
  ], { stdio: 'inherit' });
  if (r.status !== 0) { console.error('1080p encode failed; frames kept in', FRAME_DIR); process.exit(r.status || 1); }

  if (!no4k) {
  console.log(`Encoding 4K (${meta.width > meta.height ? '3840x2160' : '2160x3840'})…`);
  r = spawnSync(ff, [
    '-y', '-framerate', String(meta.fps), '-i', input, ...audioArgs,
    '-vf', `${upscale},unsharp=5:5:0.4:5:5:0.0`,
    '-crf', '23', ...common, big,
  ], { stdio: 'inherit' });
  if (r.status !== 0) { console.error('4K encode failed; frames kept in', FRAME_DIR); process.exit(r.status || 1); }
  }

  console.log(`1080p  ${small}  ${(statSync(small).size / 1048576).toFixed(1)} MB`);
  if (!no4k) console.log(`4K     ${big}  ${(statSync(big).size / 1048576).toFixed(1)} MB`);
  rmSync(FRAME_DIR, { recursive: true, force: true });
}

const b = await browser();
try {
  if (beats) await beatStills(b);
  else if (sample) await sampleStills(b);
  else await fullRender(b);
} finally {
  await b.close();
}
