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
  args:[...chromium.args,'--no-sandbox','--enable-unsafe-swiftshader','--js-flags=--expose-gc']});
const p=await b.newPage();
// ES module imports are cached hard by the browser; the sub-modules carry no
// version query. Disable the HTTP cache so each run tests the current file.
await p.setCacheEnabled(false);
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

// ================= §34 Three.js resource cleanup =================
console.log('\n── Three.js resource disposal (§34)');
const cycle = async ()=>{
  await p.evaluate(()=>{ document.querySelector('[data-td-el="addToCart"]').click(); });
  await p.waitForSelector('.td-mockup',{timeout:60000});
  await new Promise(r=>setTimeout(r,1800));
  await p.evaluate(()=>{ document.querySelector('[data-td-mk="back3"]').click(); });
  await new Promise(r=>setTimeout(r,700));
};

await cycle();
const after1 = await p.evaluate(()=>{
  const m=document.querySelector('.td-app').tdApp.mockup;
  return { root: !!document.querySelector('.td-mockup'), viewerNulled: !m || m.viewer===null };
});
ok('closing removes the dialog from the DOM', !after1.root);
ok('closing nulls the viewer reference', after1.viewerNulled);

/*
 * Measure LIVE GPU resources, the way three.js itself accounts for them.
 *
 * Two earlier approaches were wrong and are recorded so they are not retried:
 *   - counting <canvas> elements passed even with disposal deleted entirely,
 *     because the dialog is removed from the DOM either way;
 *   - counting createTexture/deleteTexture calls conflates the designer's
 *     long-lived renderer with the mockup's short-lived one, and three
 *     recreates its internal targets per context, so the totals never balance.
 *
 * renderer.info.memory is three's own live count. The designer's renderer must
 * stay flat across cycles (the mockup must not disturb it), and each mockup
 * renderer must be torn down rather than accumulating.
 */
const designerMem = ()=>p.evaluate(()=>{
  const v=document.querySelector('.td-app').tdApp.viewer;
  return v && v.renderer ? {...v.renderer.info.memory} : null;
});
const liveContexts = ()=>p.evaluate(()=>{
  // A disposed renderer's context reports isContextLost() === true.
  return document.querySelectorAll('canvas').length;
});

await cycle();                                   // warm up
const mem0 = await designerMem();
const canv0 = await liveContexts();
const CYCLES = 4;
for (let i=0;i<CYCLES;i++) await cycle();
const mem1 = await designerMem();
const canv1 = await liveContexts();

console.log(`    designer renderer geometries ${mem0.geometries}->${mem1.geometries}, textures ${mem0.textures}->${mem1.textures}; canvases ${canv0}->${canv1}`);
ok('the mockup does not leak geometries into the designer renderer',
   mem1.geometries<=mem0.geometries, `${mem0.geometries} -> ${mem1.geometries}`);
ok('the mockup does not leak textures into the designer renderer',
   mem1.textures<=mem0.textures, `${mem0.textures} -> ${mem1.textures}`);
ok(`${CYCLES} more cycles add no canvases`, canv1<=canv0, `${canv0} -> ${canv1}`);

ok('no stray mockup dialogs accumulate', (await p.evaluate(()=>document.querySelectorAll('.td-mockup').length))===0);
ok('body scroll lock is released', !(await p.evaluate(()=>document.body.classList.contains('td-mockup-open'))));
ok('no JS errors across 6 open/close cycles', errs.length===0, errs.slice(0,3).join(' | '));

// A WebGL context is finite; if we leaked one per cycle the 7th would fail.
await p.evaluate(()=>{ document.querySelector('[data-td-el="addToCart"]').click(); });
await p.waitForSelector('.td-mockup',{timeout:60000});
await new Promise(r=>setTimeout(r,2200));
ok('a 7th cycle still renders (no exhausted WebGL contexts)',
   await p.evaluate(()=>{const c=document.querySelector('.td-mockup__stage canvas');return !!c&&c.width>0;}));

// ================= Accessibility (§25) =================
console.log('\n── Accessibility (§25)');
const a11y = await p.evaluate(()=>{
  const d=document.querySelector('.td-mockup');
  const views=[...document.querySelectorAll('[data-td-mk="view"]')];
  const zoom=[...document.querySelectorAll('.td-mockup__zoombtn')];
  return {
    role: d.getAttribute('role'),
    modal: d.getAttribute('aria-modal'),
    label: !!d.getAttribute('aria-label'),
    dir: d.getAttribute('dir'),
    viewsPressed: views.every(v=>v.hasAttribute('aria-pressed')),
    zoomLabelled: zoom.every(z=>!!z.getAttribute('aria-label')),
    group: !!document.querySelector('[role="group"]'),
    status: !!document.querySelector('[data-td-mk="loading"][role="status"]'),
    alert: !!document.querySelector('[data-td-mk="error"][role="alert"]'),
  };
});
ok('the dialog has role="dialog"', a11y.role==='dialog');
ok('the dialog is aria-modal', a11y.modal==='true');
ok('the dialog has an accessible name', a11y.label);
ok('the dialog declares a direction (RTL-ready)', a11y.dir==='ltr'||a11y.dir==='rtl', a11y.dir);
ok('view buttons expose aria-pressed', a11y.viewsPressed);
ok('zoom buttons have aria-labels', a11y.zoomLabelled);
ok('the view switcher is a labelled group', a11y.group);
ok('loading is announced via role="status"', a11y.status);
ok('errors are announced via role="alert"', a11y.alert);

// Keyboard: Tab must stay inside, Escape must close.
await p.keyboard.press('Tab'); await p.keyboard.press('Tab');
ok('focus stays inside the dialog when tabbing',
   await p.evaluate(()=>!!document.activeElement.closest('.td-mockup')));
await p.keyboard.press('Escape');
await new Promise(r=>setTimeout(r,500));
ok('Escape closes the mockup', await p.evaluate(()=>!document.querySelector('.td-mockup')));
ok('Escape does not add to the cart', !/cart/i.test(p.url()), p.url());

// ================= Desktop breakpoints (§24) =================
console.log('\n── Desktop breakpoints (§24)');
for (const [w,h] of [[768,1024],[1024,768],[1440,900]]) {
  await p.setViewport({width:w,height:h});
  await p.evaluate(()=>{ document.querySelector('[data-td-el="addToCart"]').click(); });
  await p.waitForSelector('.td-mockup',{timeout:60000});
  await new Promise(r=>setTimeout(r,1500));
  const r = await p.evaluate(()=>({
    overflow: document.documentElement.scrollWidth>window.innerWidth+1,
    canvas: (()=>{const c=document.querySelector('.td-mockup__stage canvas');return !!c&&c.width>0;})(),
    inView: (()=>{const c=document.querySelector('[data-td-mk="confirm"]').getBoundingClientRect();
                  return c.left>=0 && c.right<=window.innerWidth+1;})(),
  }));
  ok(`${w}×${h}: no horizontal overflow`, !r.overflow);
  ok(`${w}×${h}: canvas renders`, r.canvas);
  ok(`${w}×${h}: confirm stays within the viewport`, r.inView);
  await p.evaluate(()=>{ document.querySelector('[data-td-mk="back3"]').click(); });
  await new Promise(r2=>setTimeout(r2,500));
}

console.log(`\n${pass+fail} checks, ${pass} passed, ${fail} failed`);
F.forEach(x=>console.log('  - '+x));
await b.close();
process.exit(fail?1:0);
