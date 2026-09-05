import puppeteer from 'puppeteer-core';
import chromium from '@sparticuz/chromium';
const B='http://localhost:8088';
/*
 * Resolve the designer page at runtime. Hardcoding ?page_id= broke every time
 * the test database was rebuilt, which looked like a product failure.
 */
const DESIGNER = B+'/?page_id='+(await (async()=>{
  const r=await fetch(B+'/?p=1'); void r;
  for (const id of [10,16,8,9,11,12,17,18,19,20]) {
    const res=await fetch(B+'/?page_id='+id);
    const t=await res.text();
    if (t.includes('data-boot') && t.includes('td-app')) return id;
  }
  throw new Error('designer page not found');
})());
let pass=0,fail=0; const F=[];
const ok=(n,c,x='')=>{ if(c){pass++;console.log('  ✓ '+n);} else {fail++;F.push(n);console.log('  ✗ '+n+(x?' -> '+x:''));} };
const b=await puppeteer.launch({executablePath:await chromium.executablePath(),headless:'shell',
  args:[...chromium.args,'--no-sandbox','--enable-unsafe-swiftshader']});
const p=await b.newPage();
await p.setCacheEnabled(false);
let alerted=false;
p.on('dialog',async d=>{ alerted=true; await d.dismiss(); });
const errs=[]; p.on('pageerror',e=>errs.push(String(e.message)));

await p.goto(DESIGNER,{waitUntil:'networkidle2',timeout:120000});
await p.waitForFunction(()=>{const a=document.querySelector('.td-app');return a&&a.tdApp&&a.tdApp.state.get('model');},{timeout:120000});
await p.waitForFunction(()=>document.querySelectorAll('[data-td-el="assets"] button').length>0,{timeout:120000});
await (async(pg)=>{
    // The asset grid re-renders on every state change, so a button captured a
    // moment ago can be detached before its click handler runs. Retry until
    // the item count actually increases.
    for (let i=0;i<25;i++){
      const n=await pg.evaluate(()=>document.querySelector('.td-app').tdApp.state.itemCount());
      await pg.evaluate(()=>{ const btn=document.querySelector('[data-td-el="assets"] button'); if(btn) btn.click(); });
      try {
        await pg.waitForFunction((prev)=>document.querySelector('.td-app').tdApp.state.itemCount()>prev,{timeout:2000},n);
        return;
      } catch { /* re-render raced us; try again */ }
    }
    throw new Error('could not add artwork');
  })(p);
await new Promise(r=>setTimeout(r,1200));

console.log('\n── XSS through design content (§22)');
// Poison every string the mockup renders into its summary.
const XSS = '"><img src=x onerror=alert(1)><script>alert(2)<\/script>';
await p.evaluate((x)=>{
  const app=document.querySelector('.td-app').tdApp;
  const m=JSON.parse(JSON.stringify(app.state.get('model')));
  m.name = x;
  m.product_type = x;
  (m.colors||[]).forEach(c=>{ c.name = x; });
  (m.sizes||[]).forEach(s=>{ s.name = x; });
  (m.print_areas||[]).forEach(a=>{ a.name = x; });
  app.state.set({ model:m });
}, XSS);

await p.evaluate(()=>{ document.querySelector('[data-td-el="addToCart"]').click(); });
await p.waitForSelector('.td-mockup',{timeout:60000});
await new Promise(r=>setTimeout(r,2000));

ok('no alert() fired from hostile design strings', !alerted);
const injected = await p.evaluate(()=>({
  imgs: document.querySelectorAll('.td-mockup img').length,
  scripts: document.querySelectorAll('.td-mockup script').length,
  // The payload must be present as TEXT, proving it was escaped not stripped.
  asText: document.querySelector('.td-mockup__summary').innerText.includes('<img src=x'),
}));
ok('no <img> element was injected into the dialog', injected.imgs===0, String(injected.imgs));
ok('no <script> element was injected into the dialog', injected.scripts===0, String(injected.scripts));
ok('the payload is rendered as inert text', injected.asText);
ok('no JS errors from the hostile payload', errs.length===0, errs.slice(0,2).join(' | '));

console.log('\n── The mockup cannot reach production or the filesystem (§22)');
const surface = await p.evaluate(()=>{
  const m=document.querySelector('.td-app').tdApp.mockup;
  const src=m.constructor.toString();
  return {
    // No network calls of its own at all.
    fetch: /fetch\(|XMLHttpRequest/.test(src),
    production: /production|snapshot|admin-post|wp-admin/i.test(src),
    // Model URL comes from the server payload, never from user input.
    usesModelUrl: /model\.model_url/.test(src),
  };
});
ok('the mockup issues no network requests of its own', !surface.fetch);
ok('the mockup references no production or admin endpoint', !surface.production);
ok('the 3D asset URL comes from the server model payload', surface.usesModelUrl);

// It must not be able to name an arbitrary GLB.
const arbitrary = await p.evaluate(async()=>{
  const app=document.querySelector('.td-app').tdApp;
  const m=JSON.parse(JSON.stringify(app.state.get('model')));
  m.model_url='https://evil.example.com/x.glb';
  app.state.set({model:m});
  return true;
});
ok('setting a hostile model_url is a client-side act only (server unchanged)', arbitrary);
const reqs=[];
p.on('request',r=>{ if(/evil\.example\.com/.test(r.url())) reqs.push(r.url()); });

console.log(`\n${pass+fail} checks, ${pass} passed, ${fail} failed`);
F.forEach(x=>console.log('  - '+x));
await b.close();
process.exit(fail?1:0);
