import { chromium } from '/tmp/styka/node_modules/playwright/index.mjs';
const browser = await chromium.launch({ executablePath: '/tmp/chromium', headless: true,
  args: ['--no-sandbox','--use-gl=swiftshader','--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
const errs = [];
page.on('pageerror', e => errs.push(e.message));
page.on('console', m => { if (m.type()==='error') errs.push(m.text().slice(0,140)); });
await page.goto('file://' + process.cwd() + '/index.html', { waitUntil: 'load' });
await page.waitForTimeout(1500);
for (const t of [1.0, 5.0, 12.0, 19.0, 26.0, 34.0, 41.0, 48.0]) {
  await page.evaluate((tt) => window.__render(tt), t);
  await page.waitForTimeout(120);
  await page.screenshot({ path: `/tmp/term/t${t}.png` });
}
console.log('errors:', errs.slice(0,4));
await browser.close();
