#!/usr/bin/env node
// Render KAMAND VOX — 37 s Vox-style paper-collage scroll, 9:16, with audio.
//   node render.mjs --sample      # 10 review stills
//   node render.mjs               # 1080p + lanczos 4K MP4 with AAC audio
//   node render.mjs --limit 20    # benchmark
import { existsSync, mkdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '../..');
const args = process.argv.slice(2);
const sample = args.includes('--sample');
const limitIdx = args.indexOf('--limit');
const limit = limitIdx !== -1 ? Number(args[limitIdx + 1]) : null;

const FPS = 24;
const FRAME_DIR = '/tmp/kamand-vox-frames';
const EXPORTS = join(HERE, 'exports');
const STILLS = join(HERE, 'stills');
const AUDIO = join(HERE, 'audio', 'mix.wav');
const SAMPLE_FRAMES = [24, 96, 180, 264, 348, 432, 516, 612, 720, 840];

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
  await inflate(join(binDir, 'al2023.tar.br'));
  setupLambdaEnvironment('/tmp/al2023/lib');
  process.env.LD_LIBRARY_PATH = ['/tmp/al2023/lib', process.env.LD_LIBRARY_PATH || '']
    .filter(Boolean).join(':');
  const executablePath = await Chromium.executablePath();
  const { chromium } = await import('playwright-core');
  return chromium.launch({ executablePath, headless: true, args: Chromium.args, env: { ...process.env } });
}

async function openScene(b) {
  const context = await b.newContext({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
  const page = await context.newPage();
  page.on('pageerror', (e) => console.error(`[page error] ${e.message}`));
  await page.goto(pathToFileURL(join(HERE, 'index.html')).href + '?frame=0', { waitUntil: 'load' });
  await page.waitForFunction(() => window.__MOTION__?.ready === true, null, { timeout: 30000 });
  const meta = await page.evaluate(() => {
    const m = window.__MOTION__;
    return { fps: m.fps, frames: m.frames, width: m.width, height: m.height };
  });
  return { context, page, meta };
}

async function sampleStills(b) {
  mkdirSync(STILLS, { recursive: true });
  const { context, page, meta } = await openScene(b);
  console.log(`Scene: ${meta.frames} frames @ ${meta.fps} fps (${(meta.frames/meta.fps).toFixed(2)} s)`);
  for (let i = 0; i < SAMPLE_FRAMES.length; i++) {
    const f = Math.min(SAMPLE_FRAMES[i], meta.frames - 1);
    await page.evaluate((fr) => window.__MOTION__.seek(fr), f);
    await page.screenshot({ path: join(STILLS, `s${i+1}.jpg`), type: 'jpeg', quality: 90 });
    console.log(`  s${i+1}: frame ${f} (${(f/meta.fps).toFixed(1)} s)`);
  }
  await context.close();
}

async function fullRender(b) {
  mkdirSync(EXPORTS, { recursive: true });
  if (!existsSync(AUDIO)) throw new Error(`Missing audio: ${AUDIO}. Run audio/make-audio.py first.`);
  rmSync(FRAME_DIR, { recursive: true, force: true });
  mkdirSync(FRAME_DIR, { recursive: true });
  const { context, page, meta } = await openScene(b);
  const total = limit ? Math.min(limit, meta.frames) : meta.frames;
  console.log(`Rendering ${total} frames at ${meta.width}x${meta.height} / ${meta.fps} fps`);
  const cdp = await context.newCDPSession(page);
  await cdp.send('Emulation.setDeviceMetricsOverride', {
    width: meta.width, height: meta.height, deviceScaleFactor: 1, mobile: false,
  });
  const t0 = Date.now();
  for (let i = 0; i < total; i++) {
    await page.evaluate((fr) => window.__MOTION__.seek(fr), i);
    const { data } = await cdp.send('Page.captureScreenshot', {
      format: 'jpeg', quality: 93, captureBeyondViewport: false, fromSurface: true,
    });
    writeFileSync(join(FRAME_DIR, `f_${String(i).padStart(5,'0')}.jpg`), Buffer.from(data,'base64'));
    if ((i+1)%24===0 || i+1===total) {
      process.stdout.write(`  ${i+1}/${total} frames (${((Date.now()-t0)/1000).toFixed(0)}s)\r`);
    }
  }
  process.stdout.write('\n');
  await context.close();
  if (limit) { console.log(`Benchmark done: ${total} frames in ${((Date.now()-t0)/1000).toFixed(1)}s`); return; }

  const ff = ffmpegPath();
  const input = join(FRAME_DIR, 'f_%05d.jpg');
  const small = join(EXPORTS, 'kamand-vox-1080p.mp4');
  const big = join(EXPORTS, 'kamand-vox-4k.mp4');
  const common = ['-c:v','libx264','-preset','medium','-pix_fmt','yuv420p',
    '-c:a','aac','-b:a','192k','-movflags','+faststart','-shortest'];

  console.log('Encoding 1080p with audio…');
  let r = spawnSync(ff, ['-y','-framerate',String(meta.fps),'-i',input,'-i',AUDIO,
    '-crf','22',...common,small], { stdio:'inherit' });
  if (r.status !== 0) { console.error('1080p encode failed; frames kept in', FRAME_DIR); process.exit(r.status||1); }

  console.log('Encoding 4K (2160x3840) with audio…');
  r = spawnSync(ff, ['-y','-framerate',String(meta.fps),'-i',input,'-i',AUDIO,
    '-vf','scale=2160:3840:flags=lanczos,unsharp=5:5:0.4:5:5:0.0',
    '-crf','24',...common,big], { stdio:'inherit' });
  if (r.status !== 0) { console.error('4K encode failed; frames kept in', FRAME_DIR); process.exit(r.status||1); }

  console.log(`1080p ${small}  ${(statSync(small).size/1048576).toFixed(1)} MB`);
  console.log(`4K    ${big}  ${(statSync(big).size/1048576).toFixed(1)} MB`);
  rmSync(FRAME_DIR, { recursive:true, force:true });
}

const b = await browser();
try { if (sample) await sampleStills(b); else await fullRender(b); }
finally { await b.close(); }
