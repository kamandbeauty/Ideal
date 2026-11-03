#!/usr/bin/env node
// Deterministic frame renderer + voice mux for Terminal 1988.
import { existsSync, mkdirSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '../..');
const FPS = 30;
const FRAMES = Math.round(51.6 * FPS);
const FRAME_DIR = '/tmp/terminal-1988-frames';
const EXPORT_DIR = join(HERE, 'exports');
const STILLS_DIR = join(HERE, 'stills');
const OUT = join(EXPORT_DIR, 'terminal-1988-1080p.mp4');
const FF = join(ROOT, 'node_modules/@ffmpeg-installer/linux-x64/ffmpeg');
const sampleOnly = process.argv.includes('--sample');

if (!existsSync(FF)) {
  console.error('Missing bundled ffmpeg. From repository root run: npm ci');
  process.exit(1);
}

// The project-bundled Chromium includes its Linux runtime libs compressed in al2023.tar.br.
// Extract locally to /tmp; do not add runtime binaries or frames to Git.
const chromiumPackage = (await import('@sparticuz/chromium')).default;
const { inflate } = await import('@sparticuz/chromium');
const { chromium } = await import('playwright-core');
await inflate(join(ROOT, 'node_modules/@sparticuz/chromium/bin/al2023.tar.br'));
process.env.LD_LIBRARY_PATH = ['/tmp/al2023/lib', process.env.LD_LIBRARY_PATH || ''].filter(Boolean).join(':');
const executablePath = await chromiumPackage.executablePath();
const browser = await chromium.launch({
  executablePath,
  args: chromiumPackage.args,
  headless: true,
  env: { ...process.env },
});

const errors = [];
try {
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(pathToFileURL(join(HERE, 'index.html')).href, { waitUntil: 'load' });
  await page.evaluate(() => window.__ready);
  const duration = await page.evaluate(() => window.__duration);
  if (Math.abs(duration - 51.6) > 0.01) throw new Error(`Unexpected timeline duration: ${duration}`);

  if (sampleOnly) {
    mkdirSync(STILLS_DIR, { recursive: true });
    const times = [1.8, 5.5, 10.5, 15.5, 20.0, 25.5, 30.5, 31.8, 35.5, 41.0, 48.5, 51.45];
    for (let i = 0; i < times.length; i++) {
      const t = times[i];
      await page.evaluate((x) => window.__render(x), t);
      await page.screenshot({ path: join(STILLS_DIR, `review-${String(i + 1).padStart(2, '0')}.jpg`), type: 'jpeg', quality: 88 });
    }
    console.log(`Rendered ${times.length} review frames${errors.length ? `; errors: ${errors.join('; ')}` : '; no page errors'}`);
  } else {
    rmSync(FRAME_DIR, { recursive: true, force: true });
    mkdirSync(FRAME_DIR, { recursive: true });
    mkdirSync(EXPORT_DIR, { recursive: true });
    const start = Date.now();
    for (let f = 0; f < FRAMES; f++) {
      const t = f / FPS;
      await page.evaluate((x) => window.__render(x), t);
      await page.screenshot({ path: join(FRAME_DIR, `f-${String(f).padStart(6, '0')}.png`) });
      if ((f + 1) % 120 === 0 || f + 1 === FRAMES) {
        console.log(`frames ${f + 1}/${FRAMES} · ${((Date.now() - start) / 1000).toFixed(0)}s`);
      }
    }
    const result = spawnSync(FF, [
      '-y', '-hide_banner', '-loglevel', 'error',
      '-framerate', String(FPS), '-i', join(FRAME_DIR, 'f-%06d.png'),
      '-i', join(HERE, 'audio/vo.wav'),
      '-map', '0:v:0', '-map', '1:a:0', '-t', '51.6',
      '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-pix_fmt', 'yuv420p',
      '-c:a', 'aac', '-b:a', '192k', '-ac', '2', '-ar', '48000',
      '-movflags', '+faststart', OUT,
    ], { encoding: 'utf8' });
    if (result.status !== 0) throw new Error(result.stderr || `ffmpeg exited ${result.status}`);
    console.log(`Rendered ${OUT}${errors.length ? `; page errors: ${errors.join('; ')}` : '; no page errors'}`);
  }
} finally {
  await browser.close();
}
