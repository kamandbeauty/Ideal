#!/usr/bin/env node
// Render a deterministic HTML motion graphic to MP4 (or transparent WebM).
// Usage: node render.mjs <slug> [--keep-frames] [--alpha] [--out <path>]
import { existsSync, mkdirSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const projectRoot = process.cwd();
const args = process.argv.slice(2);
const slug = args.find((a) => !a.startsWith('--'));
const keepFrames = args.includes('--keep-frames');
const alpha = args.includes('--alpha');
const outFlag = args.indexOf('--out');
const outArg = outFlag !== -1 ? args[outFlag + 1] : undefined;

if (!slug || (outFlag !== -1 && !outArg)) {
  console.error('Usage: npm run motion:render -- <slug> [--keep-frames] [--alpha] [--out <path>]');
  process.exit(1);
}

const sceneDir = resolve(projectRoot, 'motion', slug);
const sceneFile = join(sceneDir, 'index.html');
if (!existsSync(sceneFile)) {
  console.error(`Scene not found: ${sceneFile}`);
  console.error(`Create it first: npm run motion:new -- ${slug}`);
  process.exit(1);
}

// ---- Dependencies ---------------------------------------------------------
let chromium;
try {
  ({ chromium } = await import('playwright'));
} catch {
  console.error('Playwright is not installed. Run:');
  console.error('  npm i -D playwright && npx playwright install chromium');
  process.exit(1);
}
const ffmpegCheck = spawnSync('ffmpeg', ['-version'], { stdio: 'ignore' });
if (ffmpegCheck.error || ffmpegCheck.status !== 0) {
  console.error('ffmpeg is not on PATH. Install it (brew install ffmpeg / apt install ffmpeg).');
  process.exit(1);
}

// ---- Open the scene -------------------------------------------------------
const framesDir = join(sceneDir, 'frames');
rmSync(framesDir, { recursive: true, force: true });
mkdirSync(framesDir, { recursive: true });

const browser = await chromium.launch({ headless: true });
let meta;
try {
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
    deviceScaleFactor: 1,
  });
  const page = await context.newPage();
  page.on('pageerror', (err) => console.error(`[page error] ${err.message}`));

  const url = `${pathToFileURL(sceneFile).href}?frame=0`;
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForFunction(() => window.__MOTION__?.ready === true, null, { timeout: 15000 });

  meta = await page.evaluate(() => {
    const m = window.__MOTION__;
    return {
      fps: Number(m.fps) || 30,
      frames: Number(m.frames) || 180,
      width: Number(m.width) || 1920,
      height: Number(m.height) || 1080,
    };
  });
  if (!Number.isFinite(meta.frames) || meta.frames < 1 || meta.frames > 10000) {
    throw new Error(`Invalid frame count from __MOTION__: ${meta.frames}`);
  }

  if (meta.width !== 1920 || meta.height !== 1080) {
    await page.setViewportSize({ width: meta.width, height: meta.height });
    await page.evaluate(() => window.dispatchEvent(new Event('resize')));
  }
  if (alpha) {
    await page.evaluate(() => {
      document.documentElement.style.background = 'transparent';
      document.body.style.background = 'transparent';
      document.getElementById('stage')?.classList.add('transparent');
    });
  }

  console.log(`Rendering ${meta.frames} frames at ${meta.width}x${meta.height} / ${meta.fps} fps`);
  for (let i = 0; i < meta.frames; i++) {
    await page.evaluate((frame) => window.__MOTION__.seek(frame), i);
    await page.screenshot({
      path: join(framesDir, `f_${String(i).padStart(5, '0')}.png`),
      omitBackground: alpha,
      // Do NOT pass animations:'disabled'. The scene drives paused Web
      // Animations API effects itself via seek(frame).
    });
    if ((i + 1) % 30 === 0 || i + 1 === meta.frames) {
      process.stdout.write(`  frame ${i + 1}/${meta.frames}\r`);
    }
  }
  process.stdout.write('\n');
  await context.close();
} finally {
  await browser.close();
}

// ---- Encode ---------------------------------------------------------------
const outFile = resolve(projectRoot, outArg || `out/${slug}.${alpha ? 'webm' : 'mp4'}`);
mkdirSync(dirname(outFile), { recursive: true });

const ffArgs = alpha
  ? [
      '-y', '-framerate', String(meta.fps),
      '-i', join(framesDir, 'f_%05d.png'),
      '-c:v', 'libvpx-vp9', '-pix_fmt', 'yuva420p',
      '-b:v', '0', '-crf', '30', '-auto-alt-ref', '0', outFile,
    ]
  : [
      '-y', '-framerate', String(meta.fps),
      '-i', join(framesDir, 'f_%05d.png'),
      '-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
      '-pix_fmt', 'yuv420p', '-movflags', '+faststart', outFile,
    ];

console.log(`Encoding ${outFile}`);
const result = spawnSync('ffmpeg', ffArgs, { stdio: 'inherit' });
if (result.status !== 0) {
  console.error('ffmpeg failed. Frames were kept for debugging at', framesDir);
  process.exit(result.status || 1);
}

if (!keepFrames) rmSync(framesDir, { recursive: true, force: true });
console.log(`Done: ${outFile}`);
console.log(`Verify: ffprobe -v error -show_entries stream=width,height,r_frame_rate,nb_frames -of default=nw=1 ${outFile}`);
