// Articulated cutout rig for the hero.
//
// The painted construction sheet was cut into pieces (tools/build-part-rig.py)
// and re-assembled here as nested SVG groups: hip → torso → (shoulders → elbows,
// neck), plus skirt and legs hanging off the hip. Rotating a parent carries its
// children, so an elbow always follows its shoulder and the head always rides on
// the spine.
//
// The motion is deliberately slow: one sway every ~2.4 s, arms breathing on top
// of it, and every joint lagging its driver by a fraction of a second so the
// limbs trail instead of snapping. See .agents/skills/spine-animation for the
// follow-through / stagger reasoning.

import { PARTS_DATA } from './partrig-data.js';

const BASE = 'assets/parts/';

// measured in tools/preview-partrig.py, tuned by eye
export const RIG_H = 791;            // rig px from the top of the head to the sole
export const STAGE_H = 726;          // on-stage height at scale 1.0

const K = { head: 0.92, bodice: 0.95, apron: 0.8, skirt: 0.92, arm: 0.85, fore: 0.85, leg: 1.0 };
const TILT = { arm: 1.1, fore: 1.6, leg: -8.4 };
const NECK = [88.5, 26.0];                                  // bodice-local px
const SHOULDERS = { L: [40.0, 20.0], R: [136.0, 20.0] };    // bodice-local px
const APRON_AT = [89.0, 168.0];                             // bodice-local px
const ELBOW = 106.0;                                        // arm-local px
const SKIRT_AT = [0.0, 8.0];                                // rig px
const LEG_AT = { L: [-46.0, 150.0], R: [52.0, 150.0] };     // rig px
const SOLE = 405.0;                                         // hip → sole, rig px

const NS = 'http://www.w3.org/2000/svg';
const sizes = {};

export async function preloadParts() {
  const names = Object.keys(PARTS_DATA.parts);
  await Promise.all(names.map((n) => new Promise((res) => {
    const im = new Image();
    im.onload = () => { sizes[n] = { w: im.naturalWidth, h: im.naturalHeight }; res(); };
    im.onerror = () => { sizes[n] = { w: 1, h: 1 }; res(); };
    im.src = BASE + n + '.png';
  })));
}

function piece(name) {
  const p = PARTS_DATA.parts[name];
  const sz = sizes[name] || { w: p.w, h: p.h };
  const g = document.createElementNS(NS, 'g');
  const im = document.createElementNS(NS, 'image');
  im.setAttribute('href', BASE + name + '.png');
  im.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', BASE + name + '.png');
  im.setAttribute('width', String(sz.w));
  im.setAttribute('height', String(sz.h));
  im.setAttribute('preserveAspectRatio', 'none');
  g.appendChild(im);
  g.__pivot = p.px;
  return g;
}

const G = (parent, transform) => {
  const g = document.createElementNS(NS, 'g');
  if (transform) g.setAttribute('transform', transform);
  if (parent) parent.appendChild(g);
  return g;
};

/**
 * Build the rig. Returns the root <g>; poseRig() drives it.
 */
export function buildRig() {
  const root = document.createElementNS(NS, 'g');
  root.setAttribute('class', 'partrig');

  const legs = {
    L: G(root), R: G(root),
  };
  for (const side of ['L', 'R']) {
    const g = piece('leg');
    legs[side].appendChild(g);
    legs[side].__img = g;
    legs[side].__mirror = side === 'R';
  }

  const skirt = G(root);
  skirt.appendChild(piece('skirt'));

  const body = G(root);            // the hip frame: the torso rotates here
  const bodice = G(body);          // carries scale + the pivot shift: children are bodice-local
  bodice.appendChild(piece('bodice'));
  const apron = G(bodice, `translate(${APRON_AT[0]} ${APRON_AT[1]})`);
  apron.appendChild(piece('apron'));

  const head = G(bodice, `translate(${NECK[0]} ${NECK[1]})`);
  head.appendChild(piece('head'));

  const arms = {};
  for (const side of ['L', 'R']) {
    const arm = G(bodice, `translate(${SHOULDERS[side][0]} ${SHOULDERS[side][1]})`);
    arm.appendChild(piece('arm'));
    const fore = G(arm, `translate(0 ${ELBOW})`);
    fore.appendChild(piece('fore'));
    arms[side] = { arm, fore };
  }

  root.__rig = { legs, skirt, body, bodice, apron, head, arms };
  return root;
}

/* ------------------------------------------------------------------ motion - */

const rad = Math.PI / 180;

/** smooth 0..1..0 hump, used for lifts and steps */
const hump = (x) => Math.sin(Math.PI * ((x % 1) + 1) % 1);

function ease(p) { return p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2; }

/**
 * All joints as a function of time. `t` in seconds, `mood` in
 * still | dance | tired | collapse | wave.
 *
 * Everything is slow on purpose: the base sway runs at ~0.42 Hz, the arms at
 * ~0.29 Hz, the head at ~0.21 Hz, and each joint reads its driver a beat late
 * (LAG) so nothing moves in lock-step.
 */
export function poseValues(mood, t, seed = 0.3, energy = 1) {
  const ph = seed * Math.PI * 2;
  const slow = 0.42 * Math.PI * 2;       // body sway
  const armW = 0.29 * Math.PI * 2;       // arm rise/fall
  const stepW = 0.31 * Math.PI * 2;      // weight shift
  const LAG = 0.16;

  const sway = Math.sin(slow * t + ph);
  const swayLag = Math.sin(slow * (t - LAG) + ph);
  const swayLag2 = Math.sin(slow * (t - LAG * 2) + ph);

  // sign convention: for the left limb a positive angle swings AWAY from the
  // body, for the right limb a negative one does. Keeps the poses readable.
  const v = {
    hipY: 0, hipRot: 0, hipX: 0,
    torso: 0, head: 0, skirt: 0, apron: 0,
    armL: 4, armR: -4, foreL: 6, foreR: -6,
    legL: 0, legR: 0, legLx: 0, legRx: 0,
  };

  if (mood === 'dance') {
    const e = energy;
    // weight shifts from one leg to the other; the hips lead, the shoulders follow
    v.hipX = 11 * swayLag * e;
    v.hipY = -3.4 + 3.4 * Math.cos(2 * slow * t + ph);          // soft dip between shifts
    v.hipRot = 2.8 * swayLag2 * e;
    v.torso = -4.6 * swayLag * e;                                // the body leans against the sway
    v.head = 3.6 * Math.sin(0.21 * Math.PI * 2 * t + ph) + 2 * swayLag2;
    v.skirt = -5 * swayLag2 * e;
    v.apron = -3.4 * swayLag2 * e;
    // arms: a long, tired rise and fall, elbows trailing the shoulders
    const rise = Math.sin(armW * t + ph);
    const riseLag = Math.sin(armW * (t - LAG * 1.6) + ph);
    v.armL = 6 + 34 * e * (0.5 + 0.5 * rise);
    v.armR = -6 - 34 * e * (0.5 + 0.5 * rise);
    v.foreL = 8 + 26 * e * (0.5 + 0.5 * riseLag);
    v.foreR = -8 - 26 * e * (0.5 + 0.5 * riseLag);
    // feet: a small step on the off-beat, one foot at a time
    const sL = Math.sin(stepW * t + ph);
    const sR = Math.sin(stepW * t + ph + Math.PI);
    v.legL = 11 * Math.max(0, sL) * e;
    v.legR = -11 * Math.max(0, sR) * e;
    v.legLx = 13 * Math.max(0, sL) * e;
    v.legRx = -13 * Math.max(0, sR) * e;
  } else if (mood === 'still') {
    v.hipY = 1.1 * Math.sin(0.31 * Math.PI * 2 * t);
    v.torso = -0.7 * sway;
    v.head = 1.1 * Math.sin(0.23 * Math.PI * 2 * t + ph);
    v.armL = 3 + 1.6 * sway;
    v.armR = -3 - 1.6 * sway;
    v.foreL = 5 + 1.2 * swayLag;
    v.foreR = -5 - 1.2 * swayLag;
    v.skirt = -0.8 * swayLag2;
    v.apron = -0.6 * swayLag2;
  } else if (mood === 'tired') {
    v.hipY = 12 + 1.4 * Math.sin(0.30 * Math.PI * 2 * t);
    v.torso = 7 + 1.2 * sway;
    v.head = 12 + 1.8 * Math.sin(0.25 * Math.PI * 2 * t + ph);
    v.armL = 2; v.armR = -2;
    v.foreL = -14; v.foreR = 14;   // elbows fold in: the arms hang dead
    v.skirt = -1.2 * swayLag; v.apron = -1 * swayLag;
  } else if (mood === 'collapse') {
    const k = Math.min(1, Math.max(0, (t - 0.4) / 2.4));
    const e = ease(k);
    v.hipY = 12 + 74 * e;
    v.hipRot = 0;
    v.torso = 7 + 26 * e;
    v.head = 12 + 18 * e;
    v.armL = 4 - 10 * e; v.armR = -4 + 10 * e;
    v.foreL = -14 - 8 * e; v.foreR = 14 + 8 * e;
    v.legL = 8 * e; v.legR = -6 * e;
    v.skirt = -2 * e; v.apron = -1.5 * e;
  } else if (mood === 'wave') {
    const w = Math.sin(0.55 * Math.PI * 2 * t);
    v.hipY = -1 + 1.6 * Math.cos(0.42 * Math.PI * 2 * t);
    v.torso = -1.4 * sway;
    v.head = 2 * Math.sin(0.24 * Math.PI * 2 * t + ph);
    v.armL = 4 + 2 * sway;
    v.foreL = 6 + 2 * swayLag;
    v.armR = -4 - 116 - 6 * w;          // raised out to the side, waving from the elbow
    v.foreR = -6 + 34 + 24 * Math.sin(0.9 * Math.PI * 2 * t);
    v.skirt = -1.2 * swayLag; v.apron = -1 * swayLag;
  }
  return v;
}

/** Stage scale of the rig for a given actor def (use it to place a shadow). */
export const rigScale = (def) => (def.scale ?? 1) * STAGE_H / RIG_H;

/** Apply a pose. (X, Y) is the ground point under her feet. */
export function poseRig(root, def, t, X, Y) {
  const r = root.__rig;
  const v = poseValues(def.mood || 'still', t, def.seed ?? 0.3, def.energy ?? 1);
  const s = (def.scale ?? 1) * STAGE_H / RIG_H;
  Y -= SOLE * s;                      // (X, Y) is the ground, the rig turns about the hip

  // the whole figure: weight shift, dip, and a lean that reads as hips, not knees
  root.setAttribute('transform',
    `translate(${(X + v.hipX * (def.flip ? -1 : 1)).toFixed(2)} ${(Y + v.hipY).toFixed(2)}) ` +
    `rotate(${v.hipRot.toFixed(3)}) scale(${(s * (def.flip ? -1 : 1)).toFixed(5)} ${s.toFixed(5)})`);

  const mir = (a) => (def.flip ? -a : a);

  // the torso rotation lives on the hip frame, so arms, apron and head ride on it
  r.body.setAttribute('transform', `rotate(${mir(v.torso).toFixed(2)})`);

  const bp = PARTS_DATA.parts.bodice.px;
  r.bodice.setAttribute('transform',
    `scale(${K.bodice}) translate(${-bp[0]} ${-bp[1]})`);
  const ap = PARTS_DATA.parts.apron.px;
  r.apron.setAttribute('transform',
    `translate(${APRON_AT[0]} ${APRON_AT[1]}) rotate(${mir(v.apron).toFixed(2)}) scale(${K.apron}) translate(${-ap[0]} ${-ap[1]})`);
  const hp = PARTS_DATA.parts.head.px;
  r.head.setAttribute('transform',
    `translate(${NECK[0]} ${NECK[1]}) rotate(${mir(v.head).toFixed(2)}) scale(${K.head}) translate(${-hp[0]} ${-hp[1]})`);

  for (const side of ['L', 'R']) {
    const m = def.flip ? (side === 'L' ? 'R' : 'L') : side;
    const ang = (side === 'L' ? v.armL : v.armR) + (m === 'R' ? TILT.arm : -TILT.arm);
    const fAng = (side === 'L' ? v.foreL : v.foreR) + (m === 'R' ? TILT.fore : -TILT.fore);
    const sh = SHOULDERS[m];
    const a = r.arms[side].arm;
    const f = r.arms[side].fore;
    const apx = PARTS_DATA.parts.arm.px;
    a.setAttribute('transform',
      `translate(${sh[0]} ${sh[1]}) rotate(${mir(ang).toFixed(2)}) scale(${K.arm}) translate(${-apx[0]} ${-apx[1]})` + (m === 'R' ? ' scale(-1 1)' : ''));
    f.setAttribute('transform',
      `translate(0 ${ELBOW}) rotate(${mir(fAng - ang).toFixed(2)}) scale(${(K.fore / K.arm).toFixed(3)}) translate(${-PARTS_DATA.parts.fore.px[0]} ${-PARTS_DATA.parts.fore.px[1]})` + (m === 'R' ? ' scale(-1 1)' : ''));
  }

  const sp = PARTS_DATA.parts.skirt.px;
  r.skirt.setAttribute('transform',
    `translate(${SKIRT_AT[0]} ${SKIRT_AT[1]}) rotate(${mir(v.skirt).toFixed(2)}) scale(${K.skirt}) translate(${-sp[0]} ${-sp[1]})`);

  for (const side of ['L', 'R']) {
    const leg = r.legs[side];
    const m = def.flip ? (side === 'L' ? 'R' : 'L') : side;
    const ang = (side === 'L' ? v.legL : v.legR) + (m === 'R' ? TILT.leg : -TILT.leg);
    const dx = side === 'L' ? v.legLx : v.legRx;
    const lp = PARTS_DATA.parts.leg.px;
    leg.setAttribute('transform',
      `translate(${LEG_AT[m][0] + dx} ${LEG_AT[m][1]}) rotate(${mir(ang).toFixed(2)}) scale(${K.leg}) translate(${-lp[0]} ${-lp[1]})` + (m === 'R' ? ' scale(-1 1)' : ''));
  }
}
