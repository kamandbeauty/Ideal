#!/usr/bin/env node
/**
 * Build the final "real photo" plate for the like/follow ending.
 *
 *   npm run story:photo-card -- <slug>
 *
 * config.json → realPhoto: { file, caption, credit, plate }
 * The REAL photograph is embedded untouched (never AI-regenerated); this only
 * lays it on the house-style paper card and writes the Persian label on it:
 *   عکس واقعی (آستین اپلبی)
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { ENGINE, ROOT, parseArgs, project } from './lib.mjs';

const A = parseArgs();
const P = project(A);
const rp = P.config.realPhoto;
if (!rp) throw new Error('config.json: realPhoto لازمه (file, caption, credit, plate).');

const photoFile = join(P.dir, rp.file);
const photoB64 = readFileSync(photoFile).toString('base64');
const photoMime = photoFile.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
const fontFile = join(ENGINE, 'fonts', 'vazirmatn-arabic-700-normal.woff2');
const fontB64 = readFileSync(fontFile).toString('base64');
const grainB64 = readFileSync(join(ENGINE, 'assets', 'grain.png')).toString('base64');

const esc = (s) => String(s || '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
// In an RTL paragraph a plain "(" is mirrored into ")". Isolate the whole
// parenthetical as LTR and the Persian name inside it back as RTL so the card
// literally reads: عکس واقعی (آستین اپلبی)
const caption = esc(rp.caption).replace(
  /\(([^)]*)\)/g,
  '<span dir="ltr" style="unicode-bidi:isolate">(<span dir="rtl" style="unicode-bidi:isolate">$1</span>)</span>',
);
const html = `<!doctype html><html lang="fa"><head><meta charset="utf-8"><style>
@font-face{font-family:'V';src:url(data:font/woff2;base64,${fontB64}) format('woff2');font-weight:700}
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:1080px;height:1920px;overflow:hidden}
#stage{position:relative;width:1080px;height:1920px;overflow:hidden;
  background:radial-gradient(90% 70% at 50% 38%,#e7d3ab 0%,#cdb287 58%,#8c6b45 100%);}
#grain{position:absolute;inset:0;opacity:.13;mix-blend-mode:multiply;
  background-image:url(data:image/png;base64,${grainB64});background-size:256px 256px}
#vign{position:absolute;inset:0;background:
  radial-gradient(110% 78% at 50% 44%,rgba(0,0,0,0) 38%,rgba(28,16,6,.48) 88%,rgba(20,10,3,.72) 100%)}
#card{position:absolute;left:96px;top:300px;width:888px;height:1180px;
  background:#f3e7cf;padding:34px 34px 0;transform:rotate(-1.1deg);
  box-shadow:0 34px 90px rgba(30,16,4,.62),0 4px 0 rgba(255,255,255,.32) inset;
  border:2px solid rgba(84,58,32,.34)}
#ph{width:100%;height:910px;object-fit:cover;object-position:50% 22%;display:block;
  filter:saturate(1.02) contrast(1.02);border:1px solid rgba(50,32,12,.28)}
#cap{margin-top:26px;text-align:center;direction:rtl;font-family:'V',sans-serif;
  font-weight:700;font-size:58px;line-height:1.5;color:#3a2410;letter-spacing:-.4px}
#rule{width:180px;height:2px;margin:20px auto 0;
  background:linear-gradient(90deg,rgba(96,62,28,0),rgba(96,62,28,.85),rgba(96,62,28,0))}
#credit{margin-top:18px;text-align:center;direction:ltr;font-family:'V',sans-serif;
  font-weight:700;font-size:21px;line-height:1.7;color:#7a5a37;opacity:.9}
.tape{position:absolute;width:210px;height:56px;background:rgba(226,196,132,.62);
  box-shadow:0 4px 14px rgba(40,24,6,.28);border:1px solid rgba(255,255,255,.30)}
#t1{left:-58px;top:250px;transform:rotate(-34deg)}
#t2{right:-58px;top:1420px;transform:rotate(-32deg)}
</style></head><body><div id="stage">
<div class="tape" id="t1"></div><div class="tape" id="t2"></div>
<div id="card">
  <img id="ph" src="data:${photoMime};base64,${photoB64}">
  <div id="cap">${caption}</div>
  <div id="rule"></div>
  <div id="credit">${esc(rp.credit)}</div>
</div>
<div id="grain"></div><div id="vign"></div>
</div></body></html>`;

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
await page.setContent(html, { waitUntil: 'load' });
await page.evaluate(() => document.fonts.ready);
const out = join(P.dir, 'assets', 'plates', 'hd', `${rp.plate || 'p17'}.jpg`);
await page.screenshot({ path: out, type: 'jpeg', quality: 92 });
await b.close();
console.log(`real-photo card → ${out}`);
console.log(`caption: ${rp.caption}`);
