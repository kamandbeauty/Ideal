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
const errs=[];
p.on('pageerror',e=>errs.push(String(e.message)));
p.on('console',m=>{ if(m.type()==='error') errs.push('console: '+m.text()); });

await p.goto(DESIGNER,{waitUntil:'networkidle2',timeout:120000});
// Wait for the app to boot and the model list to populate.
await p.waitForFunction(()=>document.querySelectorAll('[data-td-el="models"] button').length>0,{timeout:120000});
console.log('designer booted');

/*
 * Select a model and wait until loading has FULLY finished.
 *
 * loadModel() resets state.areas to {} when it completes. Waiting only for
 * the print-area buttons to appear is not enough: a load still in flight will
 * finish later and wipe artwork added in the meantime, which shows up as the
 * design-integrity assertion failing and looks exactly like the mockup
 * mutating the design. Wait for modelLoading to clear.
 */
const pickModel = async (idx)=>{
  await p.waitForFunction(()=>{
    const a=document.querySelector('.td-app');
    return a && a.tdApp && a.tdApp.state.get('model') && !a.tdApp.modelLoading;
  },{timeout:120000});
  await p.evaluate((i)=>{ document.querySelectorAll('[data-td-el="models"] button')[i].click(); }, idx);
  await p.waitForFunction(()=>{
    const a=document.querySelector('.td-app');
    if (!a || !a.tdApp || a.tdApp.modelLoading) return false;
    const el=document.querySelector('[data-td-el="areas"]');
    return el && el.querySelectorAll('button').length>0;
  },{timeout:120000});
  await new Promise(r=>setTimeout(r,800));
};

/*
 * Add artwork and wait until the design has actually SETTLED.
 *
 * A fixed sleep is not enough: adding an item kicks off an async price
 * request, and the state snapshot taken while that is in flight differs from
 * the one taken after it resolves. That made the design-integrity assertion
 * fail intermittently and look like the mockup was mutating the design, when
 * really the baseline was captured too early.
 */
const addArtwork = async ()=>{
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
  await p.waitForFunction(()=>{
    const app=document.querySelector('.td-app').tdApp;
    return app.state.itemCount()>0 && app.state.get('price') && !app.state.get('pricePending');
  },{timeout:60000});
  // Two identical reads in a row means nothing else is still mutating state.
  let last=null;
  for (let i=0;i<20;i++){
    const now=await p.evaluate(()=>JSON.stringify(document.querySelector('.td-app').tdApp.state.get('areas')));
    if (now===last) return;
    last=now;
    await new Promise(r=>setTimeout(r,250));
  }
};

const openMockup = async ()=>{
  await p.evaluate(()=>{ document.querySelector('[data-td-el="addToCart"]').click(); });
  await p.waitForSelector('.td-mockup',{timeout:60000});
  await new Promise(r=>setTimeout(r,2500));
};

// ============================== T-SHIRT ==============================
console.log('\n── T-Shirt flow');
await pickModel(0);
await addArtwork();

// Capture design JSON BEFORE opening the mockup (§29/§30).
const before = await p.evaluate(()=>JSON.stringify(document.querySelector(".td-app").tdApp.state.get("areas")));
await openMockup();
ok('the mockup dialog opens', await p.$('.td-mockup')!==null);

const views = await p.$$eval('[data-td-mk="view"]',els=>els.map(e=>e.dataset.view));
ok('T-Shirt exposes all four views', JSON.stringify(views)===JSON.stringify(['front','back','left_sleeve','right_sleeve']), JSON.stringify(views));
ok('the T-Shirt mockup shows no Tote-only areas', !views.includes('tote'), JSON.stringify(views));

const canvasOk = await p.evaluate(()=>{
  const c=document.querySelector('.td-mockup__stage canvas');
  return !!c && c.width>0 && c.height>0;
});
ok('a WebGL canvas is rendered', canvasOk);

const loadingHidden = await p.evaluate(()=>{
  const l=document.querySelector('[data-td-mk="loading"]');
  return l && l.classList.contains('td-hidden');
});
ok('the loading state clears once ready', loadingHidden);
const errShown = await p.evaluate(()=>{
  const e=document.querySelector('[data-td-mk="error"]');
  return e && !e.classList.contains('td-hidden');
});
ok('no error state is shown', !errShown);

// View switching
for (const v of ['back','left_sleeve','right_sleeve','front']) {
  await p.evaluate((vv)=>{ document.querySelector(`[data-td-mk="view"][data-view="${vv}"]`).click(); }, v);
  await new Promise(r=>setTimeout(r,350));
}
const activeView = await p.$eval('[data-td-mk="view"].is-active',e=>e.dataset.view);
ok('view switching updates the active button', activeView==='front', activeView);
const pressed = await p.$eval('[data-td-mk="view"].is-active',e=>e.getAttribute('aria-pressed'));
ok('the active view is announced via aria-pressed', pressed==='true');

// Camera integrity (§30): zoom + reset must not touch the design.
const camBefore = await p.evaluate(()=>{
  const c=(document.querySelector(".td-app").tdApp.mockup||{}).viewer&&document.querySelector(".td-app").tdApp.mockup.viewer.camera;
  return c ? [c.position.x,c.position.y,c.position.z].join(',') : '';
});
await p.evaluate(()=>{ document.querySelector('[data-td-mk="zoomIn"]').click(); });
await new Promise(r=>setTimeout(r,250));
const camAfter = await p.evaluate(()=>{
  const c=(document.querySelector(".td-app").tdApp.mockup||{}).viewer&&document.querySelector(".td-app").tdApp.mockup.viewer.camera;
  return c ? [c.position.x,c.position.y,c.position.z].join(',') : '';
});
ok('zoom actually moves the camera', camBefore!==camAfter, `${camBefore} vs ${camAfter}`);
await p.evaluate(()=>{ document.querySelector('[data-td-mk="zoomOut"]').click(); });
await p.evaluate(()=>{ document.querySelector('[data-td-mk="zoomReset"]').click(); });
await new Promise(r=>setTimeout(r,300));

const afterCam = await p.evaluate(()=>JSON.stringify(document.querySelector(".td-app").tdApp.state.get("areas")));
if (before!==afterCam) {
  const diff = await p.evaluate((b)=>{
    const now=document.querySelector('.td-app').tdApp.state.get('areas'); const old=JSON.parse(b); const out=[];
    for (const k of new Set([...Object.keys(old),...Object.keys(now)])) {
      const a=old[k]||[], n=now[k]||[];
      if (a.length!==n.length) out.push(`area ${k}: ${a.length} -> ${n.length} items`);
      for (let i=0;i<Math.max(a.length,n.length);i++){
        const x=a[i]||{}, y=n[i]||{};
        for (const key of new Set([...Object.keys(x),...Object.keys(y)]))
          if (JSON.stringify(x[key])!==JSON.stringify(y[key]))
            out.push(`area${k}[${i}].${key}: ${JSON.stringify(x[key])} -> ${JSON.stringify(y[key])}`);
      }
    }
    return out;
  }, before);
  console.log('    DIFF:', JSON.stringify(diff).slice(0,400));
}
ok('camera interaction does NOT change the design JSON', before===afterCam);

// Summary content
const summary = await p.$eval('.td-mockup__summary',e=>e.innerText);
ok('the summary names the product', /T-?Shirt|تی/i.test(summary), summary.replace(/\n/g,' | '));
ok('the summary shows a price', /\d/.test(summary), summary.replace(/\n/g,' | '));

// Confirm -> cart
await p.evaluate(()=>{ document.querySelector('[data-td-mk="confirm"]').click(); });
const closed = await p.evaluate(()=>!document.querySelector('.td-mockup'));
ok('approving closes the mockup', closed);

const afterAll = await p.evaluate(()=>JSON.stringify(document.querySelector(".td-app").tdApp.state.get("areas")));
ok('the design JSON is identical after the whole mockup cycle', before===afterAll);

await p.waitForFunction(()=>location.pathname.includes('cart')||document.body.innerText.includes('cart')||document.body.innerText.includes('سبد'),{timeout:60000}).catch(()=>{});
await new Promise(r=>setTimeout(r,2500));
/*
 * Read the page defensively: approval triggers a real navigation to the cart,
 * and evaluating during that navigation throws (body is momentarily null),
 * which previously produced a spurious intermittent failure.
 */
await p.waitForNavigation({waitUntil:'domcontentloaded',timeout:15000}).catch(()=>{});
const url=p.url();
const bodyText = await p.evaluate(()=>document.body?document.body.innerText:'').catch(()=>'');
ok('approval leads to the WooCommerce cart', /cart/i.test(url)||/cart|سبد/i.test(bodyText), url);

console.log(`\n${pass+fail} checks, ${pass} passed, ${fail} failed`);
F.forEach(x=>console.log('  - '+x));
console.log('page errors:', errs.length?errs.slice(0,5):'none');
await b.close();
process.exit(fail?1:0);
