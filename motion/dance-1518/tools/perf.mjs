import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
const HERE = '/home/user/Ideal/motion/dance-1518';
const ROOT = '/home/user/Ideal';
const timeline = await import(pathToFileURL(join(HERE, 'content/timeline.js')).href);
const { SCENES } = await import(pathToFileURL(join(HERE, 'content/scenes.js')).href);
const DATA = { FPS: timeline.FPS, FRAMES: timeline.FRAMES, DURATION: timeline.DURATION, SENTENCES: timeline.SENTENCES, CUES: timeline.CUES, SCENES };
const Chromium = (await import('@sparticuz/chromium')).default;
const { inflate, setupLambdaEnvironment } = await import('@sparticuz/chromium');
await inflate(join(ROOT, 'node_modules', '@sparticuz', 'chromium', 'bin', 'al2023.tar.br'));
setupLambdaEnvironment('/tmp/al2023/lib');
process.env.LD_LIBRARY_PATH = '/tmp/al2023/lib';
const exe = await Chromium.executablePath();
const { chromium } = await import('playwright-core');
const b = await chromium.launch({ executablePath: exe, headless: true, args: Chromium.args, env: { ...process.env } });
const ctx = await b.newContext({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
const page = await ctx.newPage();
await page.addInitScript(`window.__DATA__ = ${JSON.stringify(DATA)};`);
await page.goto(pathToFileURL(join(HERE, 'index.html')).href, { waitUntil: 'load' });
await page.evaluate(() => window.__ENGINE_START__(window.__DATA__));
await page.waitForFunction(() => window.__MOTION__?.ready === true);
await page.addStyleTag({ content: '.grain { display: none !important; }' });
const stage = await page.$('#stage');
async function bench(label, n = 30) {
  const t0 = Date.now();
  for (let f = 0; f < n; f++) { await page.evaluate((i) => window.__MOTION__.seek(i), f); await stage.screenshot({ path: '/tmp/p.jpg', type: 'jpeg', quality: 95 }); }
  console.log(label, (n / ((Date.now() - t0) / 1000)).toFixed(2), 'fps');
}
await bench('baseline');
await page.addStyleTag({ content: '#plate { display:none !important }' });
await bench('no-plate');
await page.addStyleTag({ content: '#vig, #subScrim, #fogRect, #crowdHaze { display:none !important }' });
await bench('no-overlays');
await page.addStyleTag({ content: 'svg#scene { display:none !important }' });
await bench('no-svg');
await b.close();
