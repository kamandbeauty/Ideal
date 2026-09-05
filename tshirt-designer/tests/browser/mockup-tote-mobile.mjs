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

const firstModelName = async (page)=>page.$eval('[data-td-el="models"] button',e=>e.textContent.trim());
const boot = async (page)=>{
  await page.goto(DESIGNER,{waitUntil:'networkidle2',timeout:120000});
  await page.waitForFunction(()=>document.querySelectorAll('[data-td-el="models"] button').length>0,{timeout:120000});
};
/*
 * Select a model BY NAME and wait until the app has actually swapped to it.
 * Clicking by index and sleeping is not enough: loadModel() has a
 * re-entrancy guard, so a click issued while another load is in flight is
 * silently dropped and the previous model stays selected.
 */
const pickModel = async (page,name)=>{
  await page.waitForFunction(()=>{
    const a=document.querySelector('.td-app');
    return a && a.tdApp && a.tdApp.state.get('model') && !a.tdApp.modelLoading;
  },{timeout:120000});
  await page.evaluate((n)=>{
    const btn=[...document.querySelectorAll('[data-td-el="models"] button')]
      .find(b=>b.textContent.trim()===n);
    if(!btn) throw new Error('no model button named '+n);
    btn.click();
  }, name);
  await page.waitForFunction((n)=>{
    const app=document.querySelector('.td-app').tdApp;
    const m=app.state.get('model');
    return m && m.name===n && !app.modelLoading;
  },{timeout:120000}, name);
  await new Promise(r=>setTimeout(r,1200));
};
const addArtwork = async (page)=>{
  await page.waitForFunction(()=>document.querySelectorAll('[data-td-el="assets"] button').length>0,{timeout:120000});
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
  })(page);
  await new Promise(r=>setTimeout(r,900));
};
const openMockup = async (page)=>{
  await page.evaluate(()=>{ document.querySelector('[data-td-el="addToCart"]').click(); });
  await page.waitForSelector('.td-mockup',{timeout:60000});
  await new Promise(r=>setTimeout(r,2500));
};

// ============================== TOTE BAG ==============================
console.log('\n── Tote Bag flow (§31 product type isolation)');
const p=await b.newPage();
const errs=[]; p.on('pageerror',e=>errs.push(String(e.message)));
await boot(p);
await pickModel(p,'Classic Tote Bag');
await addArtwork(p);
const beforeTote = await p.evaluate(()=>JSON.stringify(document.querySelector('.td-app').tdApp.state.get('areas')));
await openMockup(p);

const tviews = await p.$$eval('[data-td-mk="view"]',els=>els.map(e=>e.dataset.view));
ok('Tote exposes exactly front and back', JSON.stringify(tviews)===JSON.stringify(['front','back']), JSON.stringify(tviews));
ok('Tote mockup shows NO sleeve views', !tviews.includes('left_sleeve') && !tviews.includes('right_sleeve'), JSON.stringify(tviews));
ok('a canvas renders for the Tote', await p.evaluate(()=>{const c=document.querySelector('.td-mockup__stage canvas');return !!c&&c.width>0;}));
ok('no error state for the Tote', await p.evaluate(()=>{const e=document.querySelector('[data-td-mk="error"]');return e&&e.classList.contains('td-hidden');}));

await p.evaluate(()=>{ document.querySelector('[data-td-mk="view"][data-view="back"]').click(); });
await new Promise(r=>setTimeout(r,400));
ok('Tote view switching works', (await p.$eval('[data-td-mk="view"].is-active',e=>e.dataset.view))==='back');
await p.evaluate(()=>{ document.querySelector('[data-td-mk="zoomIn"]').click(); document.querySelector('[data-td-mk="zoomReset"]').click(); });
await new Promise(r=>setTimeout(r,300));
ok('Tote design JSON unchanged by the mockup',
   beforeTote===await p.evaluate(()=>JSON.stringify(document.querySelector('.td-app').tdApp.state.get('areas'))));

// Cancel must NOT go to the cart.
const urlBefore = p.url();
await p.evaluate(()=>{ document.querySelector('[data-td-mk="back3"]').click(); });
await new Promise(r=>setTimeout(r,1200));
ok('declining the mockup closes it', await p.evaluate(()=>!document.querySelector('.td-mockup')));
ok('declining does NOT add to the cart', p.url()===urlBefore, p.url());
ok('declining leaves the design intact',
   beforeTote===await p.evaluate(()=>JSON.stringify(document.querySelector('.td-app').tdApp.state.get('areas'))));

// Confirm the Tote reaches the cart.
await openMockup(p);
await p.evaluate(()=>{ document.querySelector('[data-td-mk="confirm"]').click(); });
await new Promise(r=>setTimeout(r,4000));
const cartText = await p.evaluate(()=>document.body?document.body.innerText:'').catch(()=>'');
ok('Tote approval reaches the cart', /cart/i.test(p.url())||/cart|سبد/i.test(cartText), p.url());
await p.close();

// ============================== MOBILE ==============================
console.log('\n── Mobile viewports (§33)');
for (const [w,h] of [[360,800],[390,844],[412,915]]) {
  const m=await b.newPage();
  const merr=[]; m.on('pageerror',e=>merr.push(String(e.message)));
  await m.setViewport({width:w,height:h,isMobile:true,hasTouch:true,deviceScaleFactor:2});
  await boot(m);
  await pickModel(m,await firstModelName(m));
  await addArtwork(m);
  await openMockup(m);

  const r = await m.evaluate(()=>{
    const d=document.querySelector('.td-mockup__dialog');
    const c=document.querySelector('.td-mockup__stage canvas');
    const confirm=document.querySelector('[data-td-mk="confirm"]');
    const cb=confirm?confirm.getBoundingClientRect():null;
    return {
      overflow: document.documentElement.scrollWidth > window.innerWidth + 1,
      dialogW: d?Math.round(d.getBoundingClientRect().width):0,
      winW: window.innerWidth,
      canvas: !!c && c.width>0,
      confirmVisible: !!cb && cb.width>0 && cb.height>=40,
      views: document.querySelectorAll('[data-td-mk="view"]').length,
    };
  });
  ok(`${w}×${h}: no horizontal overflow`, !r.overflow);
  ok(`${w}×${h}: canvas renders`, r.canvas);
  ok(`${w}×${h}: dialog fits the viewport`, r.dialogW<=r.winW, `${r.dialogW} vs ${r.winW}`);
  ok(`${w}×${h}: confirm button is usable (>=40px tall)`, r.confirmVisible);
  ok(`${w}×${h}: all four views present`, r.views===4, String(r.views));

  await m.evaluate(()=>{ document.querySelector('[data-td-mk="view"][data-view="back"]').click(); });
  await new Promise(r2=>setTimeout(r2,350));
  ok(`${w}×${h}: view switching works`, (await m.$eval('[data-td-mk="view"].is-active',e=>e.dataset.view))==='back');
  ok(`${w}×${h}: no JS errors`, merr.length===0, merr.slice(0,2).join(' | '));
  await m.close();
}

console.log(`\n${pass+fail} checks, ${pass} passed, ${fail} failed`);
F.forEach(x=>console.log('  - '+x));
await b.close();
process.exit(fail?1:0);
