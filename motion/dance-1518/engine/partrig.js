// Articulated cutout rig for the hero.
//
// The painted construction sheet was cut into pieces (tools/build-part-rig.py)
// and re-assembled here. Every piece gets ONE absolute matrix per frame, computed
// by the same maths as tools/preview-partrig.py:
//
//     frame(piece) = frame(parent) @ T(attach) @ R(rest + angle) @ S(k) @ T(-pivot)
//
// Using flat matrices instead of nested SVG groups means the rig can be verified
// against the PIL preview frame for frame — nested groups are convenient but it
// is far too easy to shift a pivot twice in them.

import { PARTS_DATA } from './partrig-data.js';

const BASE = 'assets/parts/';

export const RIG_H = 791;            // rig px, top of head → sole
export const STAGE_H = 726;          // on-stage height at scale 1.0
const SOLE = 405.0;                  // hip → sole, rig px

const K = { head: 0.92, bodice: 0.95, apron: 0.88, skirt: 0.92, arm: 0.85, fore: 0.85, leg: 1.0 };
const TILT = { arm: 1.1, fore: 1.6, leg: -8.4 };

// bodice-local px (the frame children of the bodice inherit)
const NECK = [88.5, 26.0];
const SHOULDERS = { L: [26.0, 28.0], R: [150.0, 28.0] };
const APRON_AT = [89.0, 172.0];
const ELBOW = 106.0;                       // arm-local px: shoulder cap → elbow cap
// rig px (hip = 0,0)
const SKIRT_AT = [0.0, 8.0];
const LEG_AT = { L: [-46.0, 150.0], R: [52.0, 150.0] };

/* ---------------------------------------------------------------- matrices - */

const mul = (a, b) => [
  a[0] * b[0] + a[1] * b[3], a[0] * b[1] + a[1] * b[4], a[0] * b[2] + a[1] * b[5] + a[2],
  a[3] * b[0] + a[4] * b[3], a[3] * b[1] + a[4] * b[4], a[3] * b[2] + a[4] * b[5] + a[5],
  0, 0, 1,
];
const T = (x, y) => [1, 0, x, 0, 1, y, 0, 0, 1];
const Sc = (k) => [k, 0, 0, 0, k, 0, 0, 0, 1];
const R = (deg) => {
  const a = (deg * Math.PI) / 180;
  return [Math.cos(a), -Math.sin(a), 0, Math.sin(a), Math.cos(a), 0, 0, 0, 1];
};
const MIRROR = [-1, 0, 0, 0, 1, 0, 0, 0, 1];
const attr = (m) => `matrix(${m[0].toFixed(4)} ${m[3].toFixed(4)} ${m[1].toFixed(4)} ${m[4].toFixed(4)} ${m[2].toFixed(2)} ${m[5].toFixed(2)})`;

/** rotate about a piece's own joint cap, scale, and put the pivot at the origin */
function joint(name, angle, k, mirrored) {
  const px = PARTS_DATA.parts[name].px;
  let m = mul(R(angle), mul(Sc(k), T(-px[0], -px[1])));
  if (mirrored) m = mul(m, MIRROR);
  return m;
}

/* ------------------------------------------------------------------ build -- */

const NS = 'http://www.w3.org/2000/svg';
const sizes = {};

export async function preloadParts() {
  await Promise.all(Object.keys(PARTS_DATA.parts).map((n) => new Promise((res) => {
    const im = new Image();
    im.onload = () => { sizes[n] = { w: im.naturalWidth, h: im.naturalHeight }; res(); };
    im.onerror = () => { sizes[n] = { w: 1, h: 1 }; res(); };
    im.src = BASE + n + '.png';
  })));
}

function pieceNode(root, name) {
  const p = PARTS_DATA.parts[name];
  const sz = sizes[name] || { w: p.w, h: p.h };
  const g = document.createElementNS(NS, 'g');
  const im = document.createElementNS(NS, 'image');
  im.setAttribute('href', BASE + name + '.png');
  im.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', BASE + name + '.png');
  im.setAttribute('width', String(sz.w));
  im.setAttribute('height', String(sz.h));
  g.appendChild(im);
  root.appendChild(g);
  return g;
}

export function buildRig() {
  const root = document.createElementNS(NS, 'g');
  root.setAttribute('class', 'partrig');
  // Draw order is doing real work here:
  //   upper arms sit BEHIND the bodice, so their shoulder caps are hidden and
  //   there is no seam at the joint; forearms sit IN FRONT of the apron so the
  //   hands are never swallowed by the cloth.
  root.__nodes = {
    legL: pieceNode(root, 'leg'),
    legR: pieceNode(root, 'leg'),
    skirt: pieceNode(root, 'skirt'),
    armL: pieceNode(root, 'arm'),
    armR: pieceNode(root, 'arm'),
    bodice: pieceNode(root, 'bodice'),
    apron: pieceNode(root, 'apron'),
    foreL: pieceNode(root, 'fore'),
    foreR: pieceNode(root, 'fore'),
    head: pieceNode(root, 'head'),
  };
  return root;
}

/* ----------------------------------------------------------------- motion -- */

/**
 * Joint angles over time, in degrees. Sign convention: on the left side a
 * positive angle swings the limb away from the body, on the right side a
 * negative one does.
 *
 * Speeds are slow on purpose (≈0.2–0.4 Hz) and every joint reads its driver a
 * beat late, so limbs trail instead of snapping.
 */
export function poseValues(mood, t, seed = 0.3, energy = 1) {
  const ph = seed * Math.PI * 2;
  const slow = 0.42 * Math.PI * 2;
  const armW = 0.29 * Math.PI * 2;
  const stepW = 0.31 * Math.PI * 2;
  const LAG = 0.16;

  const sway = Math.sin(slow * t + ph);
  const swayLag = Math.sin(slow * (t - LAG) + ph);
  const swayLag2 = Math.sin(slow * (t - LAG * 2) + ph);

  const v = {
    hipY: 0, hipRot: 0, hipX: 0, torso: 0, head: 0, skirt: 0, apron: 0,
    armL: 4, armR: -4, foreL: 6, foreR: -6,
    legL: 0, legR: 0, legLx: 0, legRx: 0,
  };
  const e = energy;

  if (mood === 'dance') {
    v.hipX = 11 * swayLag * e;
    v.hipY = -3.4 + 3.4 * Math.cos(2 * slow * t + ph);
    v.hipRot = 2.8 * swayLag2 * e;
    v.torso = -4.6 * swayLag * e;
    v.head = 3.6 * Math.sin(0.21 * Math.PI * 2 * t + ph) + 2 * swayLag2;
    v.skirt = -5 * swayLag2 * e;
    v.apron = -3.4 * swayLag2 * e;
    const rise = Math.sin(armW * t + ph);
    const riseLag = Math.sin(armW * (t - LAG * 1.6) + ph);
    v.armL = 8 + 30 * e * (0.5 + 0.5 * rise);
    v.armR = -8 - 30 * e * (0.5 + 0.5 * rise);
    v.foreL = 10 + 24 * e * (0.5 + 0.5 * riseLag);
    v.foreR = -10 - 24 * e * (0.5 + 0.5 * riseLag);
    const sL = Math.sin(stepW * t + ph);
    const sR = Math.sin(stepW * t + ph + Math.PI);
    v.legL = 11 * Math.max(0, sL) * e;
    v.legR = -11 * Math.max(0, sR) * e;
    v.legLx = 13 * Math.max(0, sL) * e;
    v.legRx = -13 * Math.max(0, sR) * e;
  } else if (mood === 'still') {
    v.hipY = 1.1 * Math.sin(0.31 * Math.PI * 2 * t);
    v.torso = -1.4 * sway;
    v.head = 1.6 * Math.sin(0.23 * Math.PI * 2 * t + ph);
    v.armL = 4 + 2.2 * sway;
    v.armR = -4 - 2.2 * sway;
    v.foreL = 6 + 1.6 * swayLag;
    v.foreR = -6 - 1.6 * swayLag;
    v.skirt = -1.2 * swayLag2;
    v.apron = -0.9 * swayLag2;
  } else if (mood === 'tired') {
    v.hipY = 12 + 1.4 * Math.sin(0.3 * Math.PI * 2 * t);
    v.torso = 7 + 1.4 * sway;
    v.head = 12 + 1.8 * Math.sin(0.25 * Math.PI * 2 * t + ph);
    v.armL = 3; v.armR = -3;
    v.foreL = -14; v.foreR = 14;
    v.skirt = -1.6 * swayLag;
  } else if (mood === 'collapse') {
    const k = Math.min(1, Math.max(0, (t - 0.4) / 2.4));
    const q = k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;
    v.hipY = 12 + 74 * q;
    v.torso = 7 + 26 * q;
    v.head = 12 + 18 * q;
    v.armL = 4 - 10 * q; v.armR = -4 + 10 * q;
    v.foreL = -14 - 8 * q; v.foreR = 14 + 8 * q;
    v.legL = 8 * q; v.legR = -6 * q;
    v.skirt = -2 * q;
  } else if (mood === 'wave') {
    const w = Math.sin(0.55 * Math.PI * 2 * t);
    v.hipY = -1 + 1.6 * Math.cos(0.42 * Math.PI * 2 * t);
    v.torso = -2 * sway;
    v.head = 2 * Math.sin(0.24 * Math.PI * 2 * t + ph);
    v.armL = 4 + 2 * sway;
    v.foreL = 6 + 2 * swayLag;
    v.armR = -4 - 116 - 6 * w;
    v.foreR = -6 + 34 + 24 * Math.sin(0.9 * Math.PI * 2 * t);
    v.skirt = -1.4 * swayLag;
  }
  return v;
}

/** Stage scale of the rig for an actor def (also used to size the shadow). */
export const rigScale = (def) => (def.scale ?? 1) * STAGE_H / RIG_H;

/** Pose the rig. (X, Y) is the ground point under her feet. */
export function poseRig(root, def, t, X, Y) {
  const n = root.__nodes;
  const v = poseValues(def.mood || 'still', t, def.seed ?? 0.3, def.energy ?? 1);
  const s = rigScale(def);
  const flip = def.flip ? -1 : 1;

  const rootM = mul(T(X + v.hipX * flip, Y - SOLE * s + v.hipY), mul(R(v.hipRot * flip), Sc(s * flip)));
  // NB: Sc(s*flip) mirrors horizontally when flipped; heights stay positive.

  const set = (node, m) => node.setAttribute('transform', attr(mul(rootM, m)));

  // ---- legs, skirt (children of the hip) --------------------------------
  for (const side of ['L', 'R']) {
    const m = side === 'R' ? 'R' : 'L';
    const mirrored = m === 'R';
    const ang = (side === 'L' ? v.legL : v.legR) + (mirrored ? TILT.leg : -TILT.leg);
    const dx = side === 'L' ? v.legLx : v.legRx;
    set(n['leg' + side], mul(T(LEG_AT[m][0] + dx, LEG_AT[m][1]), joint('leg', ang, K.leg, mirrored)));
  }
  set(n.skirt, mul(T(SKIRT_AT[0], SKIRT_AT[1]), joint('skirt', v.skirt, K.skirt, false)));

  // ---- torso: bodice sits on the hip, everything else rides on it --------
  // The frame INCLUDES the bodice's own -pivot shift, so every child below can
  // speak bodice-local px — the same convention the PIL preview uses.
  const bp = PARTS_DATA.parts.bodice.px;
  const bodiceFrame = mul(R(v.torso), mul(Sc(K.bodice), T(-bp[0], -bp[1])));
  set(n.bodice, bodiceFrame);
  set(n.apron, mul(bodiceFrame, mul(T(APRON_AT[0], APRON_AT[1]), joint('apron', v.apron, K.apron, false))));
  set(n.head, mul(bodiceFrame, mul(T(NECK[0], NECK[1]), joint('head', v.head, K.head, false))));

  for (const side of ['L', 'R']) {
    const m = side === 'R' ? 'R' : 'L';
    const mirrored = m === 'R';
    const armAng = (side === 'L' ? v.armL : v.armR) + (mirrored ? TILT.arm : -TILT.arm);
    const foreAng = (side === 'L' ? v.foreL : v.foreR) + (mirrored ? TILT.fore : -TILT.fore);
    const armFrame = mul(bodiceFrame, mul(T(SHOULDERS[m][0], SHOULDERS[m][1]), joint('arm', armAng, K.arm, mirrored)));
    set(n['arm' + side], armFrame);
    const foreFrame = mul(armFrame, mul(T(0, ELBOW), joint('fore', foreAng - armAng, K.fore / K.arm, mirrored)));
    set(n['fore' + side], foreFrame);
  }
}
