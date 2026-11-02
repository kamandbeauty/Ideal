/**
 * THE ODD FILE — deterministic motion engine.
 *
 * Everything on screen is a pure function of the frame number, so renders are
 * byte-stable and identical whether previewed in a browser or captured by
 * headless Chromium.
 *
 *   window.__MOTION__ = { fps, frames, width, height, ready, seek(frame) }
 *
 * Content lives in ../content/<episode>.js (beats) and ../timeline.js (VO-derived
 * start/dur per beat, written by audio/build-timeline.mjs).
 */

import { EPISODE } from '../content/episode.js';
import { TIMELINE } from '../timeline.js';

const FPS = EPISODE.fps || 30;
const LANDSCAPE = (EPISODE.format || 'vertical') === 'landscape';
const W = LANDSCAPE ? 1920 : 1080;
const H = LANDSCAPE ? 1080 : 1920;
const SAFE = LANDSCAPE ? 132 : 88;
const clamp = (v, a = 0, b = 1) => (v < a ? a : v > b ? b : v);
const seg = (t, a, b) => clamp((t - a) / (b - a || 1e-6));
const easeOutExpo = (t) => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t));
const easeOutCubic = (t) => 1 - Math.pow(1 - t, 3);
const easeInOutCubic = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

/* ------------------------------------------------------------------ beats */

const beats = EPISODE.beats.map((beat, i) => {
  const t = TIMELINE?.beats?.find((b) => b.id === beat.id);
  return {
    ...beat,
    index: i,
    start: t ? t.start : 0,
    dur: t ? t.dur : beat.dur || 3,
  };
});

// Without a timeline yet (first visual pass), lay beats back-to-back.
if (!TIMELINE?.beats?.length) {
  let cursor = 0;
  for (const b of beats) {
    b.start = cursor;
    cursor += b.dur;
  }
}

const TOTAL = beats.length ? beats[beats.length - 1].start + beats[beats.length - 1].dur : 1;
const FRAMES = Math.round(TOTAL * FPS);

/* ------------------------------------------------------------- DOM set-up */

const stage = document.getElementById('stage');
stage.style.width = `${W}px`;
stage.style.height = `${H}px`;
stage.classList.toggle('landscape', LANDSCAPE);
const camera = document.getElementById('camera');
const sceneRoot = document.getElementById('scene-root');
const hudTop = document.getElementById('hud-top');
const hudBottom = document.getElementById('hud-bottom');
const hudFile = document.getElementById('hud-file');
const hudCat = document.getElementById('hud-cat');
const hudCount = document.getElementById('hud-count');
const railFill = document.getElementById('rail-fill');
const sweep = document.getElementById('sweep');

if (EPISODE.code) hudFile.textContent = EPISODE.code;
document.getElementById('hud-tag').textContent = LANDSCAPE ? '16:9' : '9:16';
if (EPISODE.category) hudCat.textContent = EPISODE.category;

/* ------------------------------------------------------------- primitives */

/**
 * Splits text into masked word spans. `*word*` renders in accent purple.
 * Returns [{ el, delay }] so scenes can stagger the reveal themselves.
 */
function buildLines(host, lines, { tag = 'h1', className = 'display' } = {}) {
  host.innerHTML = '';
  const words = [];
  const heading = document.createElement(tag);
  heading.className = className;
  host.appendChild(heading);

  lines.forEach((lineText) => {
    const lineEl = document.createElement('span');
    lineEl.className = 'line';
    // Accent markup can wrap several words: `*plain sight.*`
    let accentOpen = false;
    const rawWords = lineText.trim().split(/\s+/);
    rawWords.forEach((raw, i) => {
      let text = raw;
      let accent = accentOpen;
      if (text.startsWith('*')) {
        accent = true;
        accentOpen = true;
        text = text.slice(1);
      }
      if (text.endsWith('*')) {
        accent = true;
        accentOpen = false;
        text = text.slice(0, -1);
      }
      const w = document.createElement('span');
      w.className = 'w';
      const wi = document.createElement('span');
      wi.className = 'wi' + (accent ? ' hi' : '');
      wi.textContent = text;
      w.appendChild(wi);
      let mk = null;
      if (accent) {
        mk = document.createElement('i');
        mk.className = 'mk';
        w.appendChild(mk);
      }
      lineEl.appendChild(w);
      if (i < rawWords.length - 1) {
        const gap = document.createElement('span');
        gap.className = 'gap';
        lineEl.appendChild(gap);
      }
      words.push({ el: wi, index: words.length, mk, accent });
    });
    heading.appendChild(lineEl);
  });

  heading.dataset.fit = '1';
  return words;
}

/**
 * Shrinks a heading just enough that no line overflows the safe area.
 * Runs synchronously after layout, before the first capture.
 */
function fitHeading(heading, maxWidth = (W - SAFE * 2) * 0.985) {
  const lines = [...heading.querySelectorAll('.line')];
  if (!lines.length) return;
  let ratio = 1;
  for (const line of lines) {
    const kids = [...line.querySelectorAll('.w')];
    if (!kids.length) continue;
    const left = line.getBoundingClientRect().left;
    const right = kids[kids.length - 1].getBoundingClientRect().right;
    const width = right - left;
    if (width > maxWidth) ratio = Math.min(ratio, maxWidth / width);
  }
  if (ratio < 1) {
    const current = parseFloat(getComputedStyle(heading).fontSize);
    heading.style.fontSize = `${Math.max(current * ratio * 0.995, current * 0.55)}px`;
  }
}

function revealWords(words, t, { stagger = 0.055, dur = 0.62, lead = 0.06, mark = 0.5, focus = 0 } = {}) {
  const lastLand = lead + (words.length - 1) * stagger + dur;
  const markStart = Math.max(mark, lastLand * 0.72);
  words.forEach(({ el, index, mk, accent }) => {
    const local = easeOutExpo(seg(t, lead + index * stagger, lead + index * stagger + dur));
    const lift = accent ? focus * -3 : 0;
    const grow = accent ? 1 + focus * 0.014 : 1;
    el.style.transform = `translate3d(0, ${(1 - local) * 118 + lift}px, 0) scale(${grow})`;
    el.style.opacity = local > 0.02 ? String(accent ? 1 : 1 - focus * 0.26) : '0';
    if (mk) mk.style.width = `${easeOutExpo(seg(t, markStart, markStart + 0.45)) * 100}%`;
  });
}

/**
 * Long beats need a second visual event. After the words land, the emphasis
 * phrase takes the light and the rest of the line recedes.
 */
function focusAmount(t, dur) {
  if (dur < 3.1) return 0;
  return easeInOutCubic(seg(t, dur * 0.6, dur * 0.82));
}

function makeEl(tag, className, html) {
  const el = document.createElement(tag);
  if (className) el.className = className;
  if (html != null) el.innerHTML = html;
  return el;
}

function addPlate(sceneEl, src, { opacity = 0.78, grade = 1 } = {}) {
  if (!src) return null;
  const plate = makeEl('div', 'plate');
  plate.style.backgroundImage = `url("${src}")`;
  plate.style.opacity = String(opacity);
  sceneEl.appendChild(plate);
  const gradeEl = makeEl('div', 'plate-grade');
  gradeEl.style.opacity = String(grade);
  sceneEl.appendChild(gradeEl);
  return plate;
}

function addScrim(sceneEl, pos = 'center') {
  const el = makeEl('div', `scrim${pos === 'bottom' ? ' bottom' : ''}`);
  sceneEl.appendChild(el);
  return el;
}

function addGlow(sceneEl, size = 1100) {
  const glow = makeEl('div', 'glowpool');
  glow.style.width = `${size}px`;
  glow.style.height = `${size}px`;
  glow.style.margin = `${-size / 2}px 0 0 ${-size / 2}px`;
  sceneEl.appendChild(glow);
  return glow;
}

/* ---------------------------------------------------------------- scenes */

const SCENES = {
  /* Cold open: the "file" is opened. Editorial title card. */
  code(beat) {
    const el = makeEl('div', 'scene');
    el.style.justifyContent = 'center';
    const plate = addPlate(el, beat.plate, { opacity: beat.plateOpacity ?? 0.8, grade: 0.75 });
    if (plate) addScrim(el);
    const glow = plate ? null : addGlow(el, 1250);

    const kicker = makeEl('div', 'kicker', beat.kicker || 'THE ODD FILE');
    el.appendChild(kicker);

    const titleHost = makeEl('div');
    el.appendChild(titleHost);
    const words = buildLines(titleHost, beat.text, { className: 'display xl' });

    const rule = makeEl('div');
    rule.style.cssText =
      'height:2px;width:0;margin-top:56px;background:linear-gradient(90deg,#a855f7,rgba(109,40,255,0));box-shadow:0 0 24px rgba(124,58,255,.7)';
    el.appendChild(rule);

    if (beat.footnote) {
      const foot = makeEl('div', 'caption-body');
      foot.style.marginTop = '42px';
      foot.textContent = beat.footnote;
      el.appendChild(foot);
    }

    return {
      el,
      update(t) {
        revealWords(words, t, { stagger: 0.06, dur: 0.7, lead: 0.1 });
        kicker.style.opacity = String(easeOutCubic(seg(t, 0, 0.4)));
        rule.style.width = `${easeOutExpo(seg(t, 0.35, 1.15)) * 100}%`;
        if (glow) {
          glow.style.opacity = String(easeInOutCubic(seg(t, 0, 0.9)));
          glow.style.transform = `scale(${0.86 + 0.14 * easeOutCubic(seg(t, 0, 1.4))})`;
        }
        if (plate) plate.style.transform = `scale(${1.06 - 0.05 * clamp(t / 3)})`;
      },
    };
  },

  /* Core beat: big uppercase statement, one purple phrase. */
  statement(beat) {
    const el = makeEl('div', 'scene');
    el.style.justifyContent = 'center';
    const plate = addPlate(el, beat.plate, { opacity: beat.plateOpacity ?? 0.55, grade: 0.78 });
    if (plate) addScrim(el);
    const glow = beat.plate ? null : addGlow(el, 1180);

    if (beat.kicker) {
      const kicker = makeEl('div', 'kicker', beat.kicker);
      el.appendChild(kicker);
      var kickerEl = kicker;
    }

    const titleHost = makeEl('div');
    el.appendChild(titleHost);
    const words = buildLines(titleHost, beat.text, { className: 'display' });

    if (beat.sub) {
      const sub = makeEl('div', 'sub');
      sub.textContent = beat.sub;
      sub.style.marginTop = '44px';
      el.appendChild(sub);
      var subEl = sub;
    }

    return {
      el,
      update(t) {
        revealWords(words, t, { stagger: 0.05, dur: 0.6, focus: focusAmount(t, beat.dur) });
        if (kickerEl) kickerEl.style.opacity = String(easeOutCubic(seg(t, 0, 0.35)));
        if (subEl) {
          const l = easeOutCubic(seg(t, 0.34, 0.86));
          subEl.style.opacity = String(l);
          subEl.style.transform = `translate3d(0,${(1 - l) * 26}px,0)`;
        }
        if (glow) {
          glow.style.opacity = String(0.55 + 0.45 * Math.sin(clamp(t / 4) * Math.PI));
          glow.style.transform = `scale(${1 + 0.06 * t})`;
        }
        if (plate) plate.style.transform = `scale(${1.06 - 0.05 * clamp(t / 4)}) translate3d(0,${clamp(t / 4) * -18}px,0)`;
      },
    };
  },

  /* Typographic breath: serif italic, centred, quiet. */
  serif(beat) {
    const el = makeEl('div', 'scene');
    el.style.justifyContent = 'center';
    el.style.alignItems = 'center';
    el.style.textAlign = 'center';
    const glow = addGlow(el, 1320);
    const plate = addPlate(el, beat.plate, { opacity: 0.52, grade: 0.9 });
    if (plate) addScrim(el);

    if (beat.kicker) el.appendChild(makeEl('div', 'kicker', beat.kicker));

    const host = makeEl('div');
    el.appendChild(host);
    const words = buildLines(host, beat.text, { className: 'serif-line' });

    if (beat.sub) {
      // A mono caption under serif type reads as a filed note, not a subtitle.
      const sub = makeEl('div', 'sub');
      sub.textContent = beat.sub;
      sub.style.margin = '46px auto 0';
      sub.style.textAlign = 'center';
      sub.style.fontFamily = 'var(--mono)';
      sub.style.fontSize = '27px';
      sub.style.letterSpacing = '0.22em';
      sub.style.color = 'rgba(244, 242, 249, 0.82)';
      sub.style.textTransform = 'uppercase';
      el.appendChild(sub);
      var subEl = sub;
    }

    return {
      el,
      update(t) {
        revealWords(words, t, { stagger: 0.075, dur: 0.75, lead: 0.12 });
        host.style.transform = `scale(${0.965 + 0.035 * easeOutCubic(seg(t, 0, 1.6))})`;
        glow.style.opacity = String(0.5 + 0.5 * Math.sin(clamp(t / 5) * Math.PI));
        glow.style.transform = `scale(${0.94 + 0.12 * easeOutCubic(seg(t, 0, 2))})`;
        if (subEl) subEl.style.opacity = String(easeOutCubic(seg(t, 0.5, 1.1)));
        if (plate) plate.style.opacity = String(0.18 + 0.14 * clamp(t / 4));
      },
    };
  },

  /* Data beat: one number, counted up, nothing else. */
  figure(beat) {
    const el = makeEl('div', 'scene');
    el.style.justifyContent = 'center';
    const plate = addPlate(el, beat.plate, { opacity: beat.plateOpacity ?? 0.7, grade: 0.72 });
    if (plate) addScrim(el);
    const glow = plate ? null : addGlow(el, 1150);

    if (beat.kicker) el.appendChild(makeEl('div', 'kicker', beat.kicker));

    const fig = makeEl('div', 'figure');
    el.appendChild(fig);

    const unit = makeEl('div', 'figure-unit', beat.unit || '');
    el.appendChild(unit);

    if (beat.sub) {
      const sub = makeEl('div', 'sub');
      sub.textContent = beat.sub;
      sub.style.marginTop = '56px';
      el.appendChild(sub);
      var subEl = sub;
    }

    const from = beat.from ?? 0;
    const to = beat.to ?? 100;
    const decimals = beat.decimals || 0;

    return {
      el,
      update(t) {
        const p = easeOutCubic(seg(t, 0.12, 1.25));
        const value = from + (to - from) * p;
        fig.textContent = value.toFixed(decimals) + (beat.suffix || '');
        fig.style.opacity = String(clamp(seg(t, 0, 0.25)));
        fig.style.transform = `translate3d(0,${(1 - easeOutExpo(seg(t, 0, 0.5))) * 30}px,0)`;
        unit.style.opacity = String(easeOutCubic(seg(t, 0.45, 1)));
        if (glow) glow.style.opacity = String(0.4 + 0.35 * p);
        if (plate) plate.style.transform = `scale(${1.05 - 0.04 * p}) translate3d(${p * -14}px,0,0)`;
        if (subEl) subEl.style.opacity = String(easeOutCubic(seg(t, 0.7, 1.3)));
      },
    };
  },

  /* Photographic beat: full-bleed plate, slow push, caption anchored low. */
  plate(beat) {
    const el = makeEl('div', 'scene');
    el.style.justifyContent = 'flex-end';
    const plate = addPlate(el, beat.plate, { opacity: 1, grade: 0.72 });
    if (plate) {
      plate.style.opacity = '1';
      // landscape needs both: left for the type column, bottom for the caption edge
      addScrim(el);
      addScrim(el, 'bottom');
    }

    if (beat.kicker) {
      const k = makeEl('div', 'kicker', beat.kicker);
      k.style.position = 'absolute';
      k.style.top = '300px';
      k.style.left = '88px';
      el.appendChild(k);
      var kickerEl = k;
    }

    if (beat.text) {
      const host = makeEl('div');
      host.style.marginTop = 'auto';
      el.appendChild(host);
      const words = buildLines(host, beat.text, { className: 'display small' });
      var wordsRef = words;
    }

    if (beat.caption) {
      const cap = makeEl('div', 'caption');
      cap.innerHTML = `<div class="caption-rule"></div><div class="caption-body"></div>`;
      cap.querySelector('.caption-body').textContent = beat.caption;
      el.appendChild(cap);
      var capEl = cap;
    }

    return {
      el,
      update(t) {
        if (plate) {
          plate.style.transform = `scale(${CONTENT_ZOOM + 0.06 * clamp(t / 4)}) translate3d(0,${-24 * clamp(t / 4)}px,0)`;
        }
        if (wordsRef) revealWords(wordsRef, t, { stagger: 0.05, dur: 0.55, focus: focusAmount(t, beat.dur) });
        if (kickerEl) kickerEl.style.opacity = String(easeOutCubic(seg(t, 0.1, 0.5)));
        if (capEl) {
          const l = easeOutCubic(seg(t, 0.3, 0.9));
          capEl.style.opacity = String(l);
          capEl.style.transform = `translate3d(0,${(1 - l) * 22}px,0)`;
        }
      },
    };
  },

  /* Documentary beat: several text fragments revealed inside one scene. */
  sequence(beat) {
    const el = makeEl('div', 'scene');
    el.style.justifyContent = 'center';
    const plate = addPlate(el, beat.plate, { opacity: beat.plateOpacity ?? 0.55, grade: 0.75 });
    if (plate) addScrim(el);
    const glow = plate ? null : addGlow(el, 1200);

    if (beat.kicker) {
      const k = makeEl('div', 'kicker', beat.kicker);
      el.appendChild(k);
      var kickerEl = k;
    }

    const host = makeEl('div');
    el.appendChild(host);

    const groups = (beat.items || []).map((item) => {
      const wrap = makeEl('div');
      wrap.style.marginTop = item.first ? '0' : '26px';
      host.appendChild(wrap);
      const words = buildLines(wrap, item.text, { className: item.className || 'display' });
      return { words, at: item.at || 0 };
    });

    return {
      el,
      update(t) {
        if (kickerEl) kickerEl.style.opacity = String(easeOutCubic(seg(t, 0, 0.35)));
        groups.forEach((g, i) => {
          if (t < g.at) {
            g.words.forEach((w) => { w.el.style.opacity = '0'; });
            return;
          }
          revealWords(g.words, t - g.at, { stagger: 0.05, dur: 0.55 });
          const next = groups[i + 1];
          const dim = next ? 1 - 0.68 * easeInOutCubic(seg(t, next.at, next.at + 0.55)) : 1;
          if (dim < 1) {
            g.words.forEach((w) => {
              const o = parseFloat(w.el.style.opacity || '1');
              w.el.style.opacity = String(o * dim);
            });
          }
        });
        if (glow) {
          glow.style.opacity = String(0.45 + 0.35 * Math.sin(clamp(t / 6) * Math.PI));
          glow.style.transform = `scale(${1 + 0.05 * clamp(t / 6)})`;
        }
        if (plate) plate.style.transform = `scale(${1.06 - 0.05 * clamp(t / 8)})`;
      },
    };
  },

  /* Outro: brand lockup, tagline tracking in letter by letter. */
  tagline(beat) {
    const el = makeEl('div', 'scene');
    el.style.justifyContent = 'center';
    const plate = addPlate(el, beat.plate, { opacity: beat.plateOpacity ?? 0.8, grade: 0.8 });
    if (plate) addScrim(el);
    const glow = addGlow(el, 1500);

    const host = makeEl('div');
    el.appendChild(host);
    const words = buildLines(host, beat.text, { className: 'display' });

    const lock = makeEl('div', 'lockup');
    lock.style.marginTop = '120px';
    lock.innerHTML = `<div class="lockup-tag"></div><div class="lockup-sub"></div>`;
    lock.querySelector('.lockup-tag').textContent = beat.brand || 'THE ODD FILE';
    lock.querySelector('.lockup-sub').textContent = beat.handle || '';
    el.appendChild(lock);

    const rule = makeEl('div');
    rule.style.cssText =
      'height:2px;width:0;margin-top:52px;background:linear-gradient(90deg,#a855f7,rgba(109,40,255,0))';
    el.insertBefore(rule, lock);

    return {
      el,
      update(t) {
        revealWords(words, t, { stagger: 0.06, dur: 0.7, lead: 0.08 });
        rule.style.width = `${easeOutExpo(seg(t, 0.5, 1.3)) * 46}%`;
        const l = easeOutCubic(seg(t, 0.8, 1.5));
        lock.style.opacity = String(l);
        lock.style.transform = `translate3d(0,${(1 - l) * 20}px,0)`;
        glow.style.opacity = String(0.5 + 0.3 * easeOutCubic(seg(t, 0, 1.2)));
        glow.style.transform = `scale(${1.1 - 0.06 * clamp(t / 3)})`;
      },
    };
  },
};

/* Camera breathing: every photographic beat sits inside a slow push. */
const CONTENT_ZOOM = 1.0;

/* --------------------------------------------------------------- lifecycle */

let current = null; // { index, scene }
let curFrame = -1;

function beatAt(t) {
  for (let i = beats.length - 1; i >= 0; i--) if (t >= beats[i].start - 1e-6) return beats[i];
  return beats[0];
}

function cutIn(index) {
  const beat = beats[index];
  if (current && current.index === index) return;
  const builder = SCENES[beat.scene || 'statement'];
  const scene = builder(beat);
  sceneRoot.innerHTML = '';
  sceneRoot.appendChild(scene.el);
  scene.el.classList.add('active');
  // Type fitting needs real layout, so it runs once the scene is in the DOM.
  scene.el.querySelectorAll('[data-fit]').forEach((h) => fitHeading(h));
  current = { index, scene, beat };
}

function seek(frame) {
  if (frame === curFrame) return;
  curFrame = frame;
  const t = frame / FPS;
  const beat = beatAt(t);
  cutIn(beat.index);

  const local = t - beat.start;
  const p = clamp(local / beat.dur);

  // scene content
  current.scene.update(local, p, beat);

  // scene-level fade at head/tail keeps cuts from strobing
  const fadeIn = clamp(seg(local, 0, 0.12));
  const fadeOut = 1 - clamp(seg(local, beat.dur - 0.18, beat.dur));
  current.scene.el.style.opacity = String(Math.min(fadeIn, fadeOut) * 0.999);

  // camera: slow push + cut punch
  const punch = 1 + 0.022 * (1 - easeOutCubic(seg(local, 0, 0.42)));
  const push = 1 + 0.035 * p;
  camera.style.transform = `scale(${punch * push})`;
  camera.style.transformOrigin = '50% 52%';

  // editorial light line: carries visual information between type reveals
  const sweepPos = seg(local, beat.dur * 0.42, beat.dur * 0.96);
  sweep.style.top = `${-2 + sweepPos * 104}%`;
  sweep.style.opacity = String(Math.sin(sweepPos * Math.PI) * 0.55);

  // HUD
  const hudIn = clamp(seg(t, 0.25, 0.75));
  hudTop.style.opacity = String(hudIn * 0.92);
  hudBottom.style.opacity = String(hudIn);
  hudTop.style.transform = `translate3d(0,${(1 - hudIn) * -12}px,0)`;
  hudCount.textContent = `${String(beat.index + 1).padStart(2, '0')} / ${String(beats.length).padStart(2, '0')}`;
  railFill.style.width = `${clamp(frame / (FRAMES - 1)) * 100}%`;
}

/* --------------------------------------------------------------- bootstrap */

// Grain drift: deterministic, one-frame-per-sample, cheap.
const grain = document.querySelector('.grain');
function driftGrain(frame) {
  const y = Math.round(Math.sin(frame * 0.7) * 14);
  const x = Math.round(Math.cos(frame * 1.13) * 14);
  grain.style.transform = `translate3d(${x}px,${y}px,0)`;
}

window.__MOTION__ = {
  fps: FPS,
  frames: FRAMES,
  width: W,
  height: H,
  ready: false,
  duration: TOTAL,
  seek(frame) {
    const f = Math.max(0, Math.min(FRAMES - 1, Math.round(frame)));
    driftGrain(f);
    seek(f);
  },
};

document.fonts.ready.then(() => {
  // Preload the plate images so capture never grabs an empty frame.
  const srcs = [...new Set(beats.map((b) => b.plate).filter(Boolean))];
  Promise.all(
    srcs.map(
      (s) =>
        new Promise((res) => {
          const img = new Image();
          img.onload = img.onerror = () => res();
          img.src = s;
        }),
    ),
  ).then(() => {
    const params = new URLSearchParams(location.search);
    const startFrame = Number(params.get('frame')) || 0;
    window.__MOTION__.seek(startFrame);
    window.__MOTION__.ready = true;
    document.body.dataset.ready = '1';
  });
});
