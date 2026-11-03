#!/usr/bin/env node
/**
 * Frame-by-frame renderer for any project in projects/<slug>/.
 *
 *   npm run story:render -- <slug> [--lang fa|en] [--fast] [--stills 8]
 *                         [--from 0 --to 30] [--no-audio] [--keep]
 *
 * The stage is engine/stage.html (the illustrated-story look). Every frame is
 * window.__MOTION__.seek(frame); there is no CSS animation and no randomness,
 * so a render is deterministic and resumable.
 */
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, rmSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  ENGINE, ROOT, ensureProjectDirs, ffmpeg, langOf, loadJs,
  parseArgs, project,
} from './lib.mjs';

const A = parseArgs();
const P = project(A);
const L = langOf(A, P);
const D = ensureProjectDirs(P);
const num = (k, d = null) => (A.flags[k] === undefined ? d : Number(A.flags[k]));
const stillsCount = num('stills', 0);
// --from / --to are SECONDS of film time (both of them).
const from = num('from', 0);
const to = num('to', null);
const fast = A.flags.fast === true;
const silent = A.flags['no-audio'] === true;
const encodeOnly = A.flags['encode-only'] === true;
const keep = A.flags.keep === true;
const FRAME_DIR = join('/tmp', `${P.slug}-${L}-frames`);
const STAGE = join(ENGINE, 'stage.html');

const pick = (name, ext) => {
  const a = join(D.content, `${name}.${L}.${ext}`);
  return existsSync(a) ? a : join(D.content, `${name}.${ext}`);
};
const timeline = await loadJs(pick('timeline', 'js'));
const words = await loadJs(pick('words', 'js'), { WORDS: [] });
const scenes = await loadJs(join(D.content, 'scenes.js'), null)
  .catch(() => loadJs(join(D.content, 'scenes.auto.js')));

// Never index past the camera plan, whatever the sentence count is.
const SCENES = Array.from(scenes.SCENES || []);
if (!SCENES.length) throw new Error('content/scenes.js خالیه — حداقل یک صحنه لازمه.');
const base = SCENES.length;
while (SCENES.length < timeline.SENTENCES.length) {
  SCENES.push({ ...SCENES[SCENES.length % base], id: SCENES.length + 1 });
}

const plateBase = `${pathToFileURL(D.plates).href}/`;
const DATA = {
  FPS: timeline.FPS,
  FRAMES: timeline.FRAMES,
  DURATION: timeline.DURATION,
  SENTENCES: timeline.SENTENCES,
  CUES: timeline.CUES,
  SCENES,
  WORDS: words.WORDS || [],
  plateBase,
  lang: L,
  title: P.config.title || P.slug,
  titleNum: P.config.titleNum || '',
  titleSub: P.config.titleSub || '',
};

function ffmpegPath() { return ffmpeg(); }

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
await page.goto(pathToFileURL(STAGE).href, { waitUntil: 'load' });
await page.evaluate(() => window.__ENGINE_START__(window.__DATA__));
await page.waitForFunction(() => window.__MOTION__?.ready === true, null, { timeout: 30000 });
if (fast) await page.addStyleTag({ content: '.grain { display: none !important; }' });

const meta = await page.evaluate(() => {
  const m = window.__MOTION__;
  return { fps: m.fps, frames: m.frames, width: m.width, height: m.height, duration: m.duration };
});
const startFrame = Math.round(from * meta.fps);
const last = to === null ? meta.frames : Math.min(meta.frames, Math.round(to * meta.fps));
console.log(`project  ${P.slug} · ${L} · ${meta.duration.toFixed(2)}s · ${meta.frames} frames @ ${meta.fps}fps · ${startFrame}→${last}`);
console.log(`stage    ${relative(ROOT, STAGE)}`);
console.log(`plates   ${relative(ROOT, D.plates)}/`);

const stage = await page.$('#stage');

if (stillsCount) {
  mkdirSync(D.stills, { recursive: true });
  for (let i = 0; i < stillsCount; i++) {
    const f = Math.round(startFrame + ((last - startFrame - 1) * i) / Math.max(1, stillsCount - 1));
    await page.evaluate((n) => window.__MOTION__.seek(n), f);
    await page.waitForTimeout(80);
    const out = join(D.stills, `${L}-still-${String(i + 1).padStart(2, '0')}-f${String(f).padStart(5, '0')}.png`);
    await stage.screenshot({ path: out });
    console.log(`  ${relative(ROOT, out)}`);
  }
  await b.close();
  process.exit(0);
}

if (!encodeOnly) {
  if (!keep) rmSync(FRAME_DIR, { recursive: true, force: true });
  mkdirSync(FRAME_DIR, { recursive: true });
  const t0 = Date.now();
  for (let f = startFrame; f < last; f++) {
    await page.evaluate((n) => window.__MOTION__.seek(n), f);
    await stage.screenshot({ path: join(FRAME_DIR, `f_${String(f).padStart(5, '0')}.jpg`), type: 'jpeg', quality: 95 });
    if ((f - startFrame) % 60 === 0) process.stdout.write(`\r  frame ${f}/${last}`);
  }
  console.log(`\n  captured ${last - startFrame} frames in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
}
await b.close();

const audio = join(D.audio, `mix.${L}.wav`);
const audioFallback = join(D.audio, 'mix.wav');
const audioFile = existsSync(audio) ? audio : audioFallback;
const tag = startFrame === 0 && last === meta.frames ? '1080x1920' : `slice-${startFrame}-${last}`;
const out = join(D.exports, `${P.slug}-${L}-${tag}.mp4`);
mkdirSync(dirname(out), { recursive: true });
const useAudio = !silent && existsSync(audioFile);
const args = [
  '-y', '-hide_banner', '-loglevel', 'error',
  '-framerate', String(meta.fps), '-start_number', String(startFrame), '-i', join(FRAME_DIR, 'f_%05d.jpg'),
  ...(useAudio ? ['-ss', String(from), '-t', String((last - startFrame) / meta.fps), '-i', audioFile] : []),
  ...(fast
    ? ['-vf', 'noise=alls=7:allf=t']
    : ['-vf', 'eq=saturation=1.10:contrast=1.03:gamma=0.99,unsharp=5:5:0.35:5:5:0.0']),
  '-c:v', 'libx264', '-preset', 'medium', '-crf', '26', '-pix_fmt', 'yuv420p',
  ...(useAudio ? ['-c:a', 'aac', '-b:a', '192k'] : []),
  '-shortest', '-movflags', '+faststart', out,
];
const r = spawnSync(ffmpegPath(), args, { stdio: 'inherit' });
if (r.status !== 0) throw new Error('ffmpeg encode failed');
console.log(`  ${relative(ROOT, out)}  ${(statSync(out).size / 1048576).toFixed(1)} MB`);
