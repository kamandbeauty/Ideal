#!/usr/bin/env node
/**
 * lustig-eiffel — renderer.
 *
 *   node render.mjs --stills 8          # review PNGs spread over the film
 *   node render.mjs --from 0 --to 30    # render a slice (preview)
 *   node render.mjs                     # full film + audio
 *   node render.mjs --encode-only       # reuse the frames already in /tmp
 *
 * Frames are produced by seeking the page: window.__MOTION__.seek(frame), so
 * the render is deterministic and resumable.
 */
import { existsSync, mkdirSync, rmSync, statSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '../..');
const argv = process.argv.slice(2);
const num = (flag, dflt = null) => {
  const i = argv.indexOf(flag);
  return i !== -1 ? Number(argv[i + 1]) : dflt;
};
const stillsCount = num('--stills', 0);
const from = num('--from', 0);
const to = num('--to', null);
const fast = argv.includes('--fast');
const cssIdx = argv.indexOf('--css');
const extraCss = cssIdx !== -1 ? argv[cssIdx + 1] : null;
const qIdx = argv.indexOf('--q');
const jpegQ = qIdx !== -1 ? Number(argv[qIdx + 1]) : 95;
const silent = argv.includes('--no-audio');
const encodeOnly = argv.includes('--encode-only');
const keep = argv.includes('--keep');
const FRAME_DIR = '/tmp/rowling-frames';

const timeline = await import(pathToFileURL(join(HERE, 'content', 'timeline.js')).href);
const { SCENES, SCENE_OF } = await import(pathToFileURL(join(HERE, 'content', 'scenes.fa.js')).href);
const { WORDS } = await import(pathToFileURL(join(HERE, 'content', 'words.js')).href);
const DATA = {
  FPS: timeline.FPS,
  FRAMES: timeline.FRAMES,
  DURATION: timeline.DURATION,
  SENTENCES: timeline.SENTENCES,
  CUES: timeline.CUES,
  SCENES,
  SCENE_OF,
  ENDCARD: timeline.ENDCARD,
  WORDS,
};

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
const context = await b.newContext({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
const page = await context.newPage();
page.on('pageerror', (e) => console.error(`[page error] ${e.message}`));
page.on('console', (m) => { if (m.type() === 'error') console.error(`[console] ${m.text()}`); });
await page.addInitScript(`window.__DATA__ = ${JSON.stringify(DATA)};`);
await page.goto(pathToFileURL(join(HERE, 'index.html')).href, { waitUntil: 'load' });
await page.evaluate(() => window.__ENGINE_START__(window.__DATA__));
await page.waitForFunction(() => window.__MOTION__?.ready === true, null, { timeout: 30000 });
if (fast) await page.addStyleTag({ content: '.grain { display: none !important; }' });
if (extraCss) await page.addStyleTag({ content: extraCss });

const meta = await page.evaluate(() => {
  const m = window.__MOTION__;
  return { fps: m.fps, frames: m.frames, width: m.width, height: m.height, duration: m.duration };
});
const last = to === null ? meta.frames : Math.min(meta.frames, Math.round(to * meta.fps));
console.log(`film: ${meta.duration.toFixed(2)}s · ${meta.frames} frames @ ${meta.fps}fps · rendering ${from}→${last}`);

const stage = await page.$('#stage');

if (stillsCount) {
  const dir = join(HERE, 'stills');
  mkdirSync(dir, { recursive: true });
  for (let i = 0; i < stillsCount; i++) {
    const f = Math.round(from + ((last - from - 1) * i) / Math.max(1, stillsCount - 1));
    await page.evaluate((n) => window.__MOTION__.seek(n), f);
    await page.waitForTimeout(80);
    const out = join(dir, `still-${String(i + 1).padStart(2, '0')}-f${String(f).padStart(5, '0')}.png`);
    await stage.screenshot({ path: out });
    console.log(`  ${out}`);
  }
  await b.close();
  process.exit(0);
}

if (!encodeOnly) {
  if (!keep) rmSync(FRAME_DIR, { recursive: true, force: true });
  mkdirSync(FRAME_DIR, { recursive: true });
  const t0 = Date.now();
  for (let f = from; f < last; f++) {
    await page.evaluate((n) => window.__MOTION__.seek(n), f);
    await stage.screenshot({ path: join(FRAME_DIR, `f_${String(f).padStart(5, '0')}.jpg`), type: 'jpeg', quality: jpegQ });
    if ((f - from) % 60 === 0) process.stdout.write(`\r  frame ${f}/${last}`);
  }
  console.log(`\n  captured ${last - from} frames in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
}
await b.close();

const audio = join(HERE, 'audio', 'mix.wav');
const tag = from === 0 && last === meta.frames ? '1080x1920' : `slice-${from}-${last}`;
const out = join(HERE, 'exports', `rowling-potter-${tag}.mp4`);
mkdirSync(dirname(out), { recursive: true });
const useAudio = !silent && existsSync(audio);
const args = [
  '-y', '-hide_banner', '-loglevel', 'error',
  '-framerate', String(meta.fps), '-start_number', String(from), '-i', join(FRAME_DIR, 'f_%05d.jpg'),
  ...(useAudio ? ['-ss', String(from / meta.fps), '-t', String((last - from) / meta.fps), '-i', audio] : []),
  ...(fast
    ? ['-vf', 'noise=alls=7:allf=t']
    : ['-vf', 'eq=saturation=1.10:contrast=1.03:gamma=0.99,unsharp=5:5:0.35:5:5:0.0']),
  '-c:v', 'libx264', '-preset', 'medium', '-crf', '26', '-pix_fmt', 'yuv420p',
  ...(useAudio ? ['-c:a', 'aac', '-b:a', '192k'] : []),
  '-shortest', '-movflags', '+faststart', out,
];
const r = spawnSync(ffmpegPath(), args, { stdio: 'inherit' });
if (r.status !== 0) throw new Error('ffmpeg failed');
console.log(`  ${out}  ${(statSync(out).size / 1048576).toFixed(1)} MB`);
