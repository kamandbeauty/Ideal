// Painted sprite actors — the cast is made of hand-painted pose frames that were
// generated on-model and cut out by tools/build-sprites.py.
//
// A "pose swap" is not a morph: each pose is drawn with the same body scale and
// registered on the same sole line, so the character can cut between poses at
// animation rate and still be the same person standing on the same stone. What
// sells the life between the cuts is the small stuff: line boil, a bounce on the
// beat, weight shift, breathing.

import { SPRITES } from './sprites-data.js';

const BASE = 'assets/sprites/';
export const STAGE_H = 726;      // on-stage height of a scale-1.0 character (px)

/* ---------------------------------------------------------------- preload -- */

const sizes = {};
export async function preloadSprites() {
  const files = new Set();
  for (const c of Object.values(SPRITES)) for (const p of Object.values(c.poses)) files.add(p.file);
  await Promise.all([...files].map((f) => new Promise((res) => {
    const im = new Image();
    im.onload = () => { sizes[f] = { w: im.naturalWidth, h: im.naturalHeight }; res(); };
    im.onerror = () => { sizes[f] = { w: 1, h: 1 }; res(); };
    im.src = BASE + f;
  })));
}

/* ------------------------------------------------------------------ poses -- */

/** mood → [pose, seconds]. Missing poses fall back inside `resolve`. */
const SEQ = {
  still: [['idle', 2.6]],
  dance: [['dance-a', 0.44], ['dance-c', 0.34], ['dance-b', 0.48], ['dance-c', 0.30]],
  tired: [['tired', 1.7], ['idle', 1.0]],
  collapse: [['tired', 0.6], ['fallen', 3.2]],
  wave: [['wave', 1.9], ['idle', 0.7]],
  play: [['dance-a', 0.5], ['wave', 0.6], ['dance-c', 0.42]],
};

// characters with their own pose set get their own script
const SEQ_BY_CHAR = {
  townsman: {
    dance: [['dance', 0.42], ['dance-2', 0.38], ['dance', 0.46], ['dance-2', 0.30]],
    collapse: [['dance-2', 0.5], ['fallen', 3.0]],
  },
  official: { still: [['idle', 2.6]] },
  musician: { still: [['idle', 2.6]], play: [['idle', 2.6]] },
};

const FALLBACK = {
  'dance-a': ['dance', 'idle'],
  'dance-2': ['dance', 'idle'],
  'dance-b': ['dance', 'idle'],
  'dance-c': ['dance', 'idle'],
  tired: ['idle'],
  fallen: ['idle'],
  wave: ['dance', 'idle'],
  idle: ['idle'],
};

function resolve(char, pose) {
  const c = SPRITES[char];
  if (!c) return null;
  if (c.poses[pose]) return pose;
  for (const alt of FALLBACK[pose] || []) if (c.poses[alt]) return alt;
  return Object.keys(c.poses)[0];
}

/* ------------------------------------------------------------------- boil -- */

function boil(t, seed) {
  const q = Math.floor(t * 11 + seed * 13);
  const r = (k) => {
    const x = Math.sin((q + k * 17.17 + seed * 31.7) * 127.1) * 43758.5453;
    return (x - Math.floor(x)) * 2 - 1;
  };
  return { rot: r(1) * 1.0, dx: r(2) * 2.0, dy: r(3) * 1.3, sc: 1 + r(4) * 0.005 };
}

/* ------------------------------------------------------------------ build -- */

const NS = 'http://www.w3.org/2000/svg';

// 0 = cut on the beat (classic limited animation). Raise for a soft mix.
const CROSSFADE = 0;

function makeImage(name, pose, mirrored) {
  const p = SPRITES[name].poses[pose];
  const sz = sizes[p.file] || { w: p.w, h: p.h };
  const im = document.createElementNS(NS, 'image');
  im.setAttribute('href', BASE + p.file);
  im.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', BASE + p.file);
  im.setAttribute('width', String(sz.w));
  im.setAttribute('height', String(sz.h));
  const k = p.k ?? 1;
  const sx = mirrored ? -k : k;
  im.setAttribute('transform', `translate(${(-p.ax * k * (mirrored ? 1 : 1)).toFixed(2)} ${(-p.ay * k).toFixed(2)}) scale(${sx} ${k})`);
  im.setAttribute('preserveAspectRatio', 'xMidYMid meet');
  im.__pose = pose;
  return im;
}

/** One actor group: every pose stacked, toggled by opacity so nothing decodes mid-frame. */
export function spriteGroup(name) {
  const g = document.createElementNS(NS, 'g');
  g.setAttribute('class', 'sprite');
  g.__name = name;
  g.__layers = {};
  for (const pose of Object.keys(SPRITES[name].poses)) {
    const im = makeImage(name, pose, false);
    im.setAttribute('opacity', '0');
    g.appendChild(im);
    g.__layers[pose] = im;
  }
  return g;
}

/** Silhouette actor for the deep crowd: same art, sunk into shadow. */
export function silhouetteGroup(name, poses = ['dance-a', 'dance-b', 'dance-c', 'idle']) {
  const g = document.createElementNS(NS, 'g');
  g.setAttribute('class', 'silhouette');
  g.__name = name;
  g.__poses = poses.map((p) => resolve(name, p)).filter((p, i, a) => a.indexOf(p) === i);
  const im = makeImage(name, g.__poses[0], false);
  im.setAttribute('style', 'filter: brightness(.16) saturate(.55)');
  g.appendChild(im);
  g.__im = im;
  g.__href = SPRITES[name].poses[g.__poses[0]].file;
  return g;
}

/* ------------------------------------------------------------------ frame -- */

// A four-pose loop read twice is already a machine. Every third cycle one of
// the beats is replaced by a stumble, so the dance keeps breaking its own rhythm.
const STUMBLE = [['tired', 0.46], ['dance-c', 0.22]];
const DANCE_BASE = SEQ.dance;

function slot(mood, t, seed, energy, char) {
  let seq = (SEQ_BY_CHAR[char] && SEQ_BY_CHAR[char][mood]) || SEQ[mood] || SEQ.still;
  const own = SEQ_BY_CHAR[char] && SEQ_BY_CHAR[char][mood];
  if (mood === 'dance' && !own) {
    const cycle = DANCE_BASE.reduce((a, s) => a + s[1], 0);
    const vi = Math.floor((t * (0.86 + 0.34 * energy)) / (cycle * 2.5)) % 3;
    if (vi === 2) seq = [...DANCE_BASE, ...STUMBLE];
  }
  const total = seq.reduce((a, s) => a + s[1], 0);
  const speed = mood === 'dance' || mood === 'play' ? 0.86 + 0.34 * energy : 1;
  const tt = ((t * speed + seed * total) % total + total) % total;
  let i = 0;
  let acc = 0;
  while (i < seq.length - 1 && acc + seq[i][1] <= tt) { acc += seq[i][1]; i += 1; }
  const dur = seq[i][1] || 1;
  return { cur: seq[i][0], next: seq[(i + 1) % seq.length][0], local: tt - acc, dur };
}

/**
 * Pose one actor at time t. (X, Y) is the ground point under her feet.
 * def: { mood, seed, energy, scale, flip }
 */
export function poseSprite(g, def, t, X, Y) {
  const name = g.__name;
  const meta = SPRITES[name];
  const seed = def.seed ?? 0.2;
  const energy = def.energy ?? 1;
  const mood = def.mood || 'still';
  const { cur, next, local, dur } = slot(mood, t, seed, energy, name);

  // A painted pose swap has to be a hard cut: crossfading two silhouettes this
  // different reads as a double exposure, not as motion.
  const fade = CROSSFADE * Math.min(1, dur);
  const w = fade > 0 && local > dur - fade ? (local - (dur - fade)) / fade : 0;

  const layers = g.__layers;
  const curPose = resolve(name, cur);
  const nextPose = resolve(name, next);
  for (const k of Object.keys(layers)) {
    const el = layers[k];
    let o = 0;
    if (k === curPose) o = nextPose === curPose ? 1 : 1 - w;
    else if (k === nextPose) o = w;
    el.setAttribute('opacity', o.toFixed(3));
    el.setAttribute('display', o > 0.002 ? 'inline' : 'none');
  }

  const b = boil(t, seed);
  const dancing = mood === 'dance' || mood === 'play';
  const beat = dancing ? 1.22 : 0.42;
  const bounce = -Math.abs(Math.sin(Math.PI * beat * 2 * t + seed * 6.283)) * (dancing ? 9 : 2.4) * energy;
  const sway = Math.sin(Math.PI * beat * t + seed * 6.283) * (dancing ? 3.4 : 0.9);
  const lean = Math.sin(Math.PI * beat * t + seed * 6.283 + 0.7) * (dancing ? 0.9 : 0.25);

  // breathing: the chest rises even when she stands still
  const breath = 1 + Math.sin(t * 1.55 + seed * 6.283) * 0.006;

  const s = ((def.scale ?? 1) * STAGE_H / (meta.ref * (meta.height ?? 1))) * b.sc;
  const sx = s * (def.flip ? -1 : 1);
  g.setAttribute('transform',
    `translate(${(X + sway + b.dx).toFixed(2)} ${(Y + bounce + b.dy).toFixed(2)}) ` +
    `rotate(${(b.rot + lean).toFixed(3)}) scale(${sx.toFixed(5)} ${(s * breath).toFixed(5)})`);
  return { pose: curPose, next: nextPose, w };
}

/** Crowd silhouette: cheaper, darker, always dancing, no crossfades. */
export function poseSilhouette(g, def, t, X, Y) {
  const name = g.__name;
  const meta = SPRITES[name];
  const seed = def.seed ?? 0.3;
  const energy = def.energy ?? 1;
  const keys = g.__poses;
  const beat = 1.0 + seed * 0.5;
  const active = keys[Math.floor(t * beat * 2.4 + seed * 11) % keys.length];
  const file = SPRITES[name].poses[active].file;
  if (file !== g.__href) {
    g.__href = file;
    g.__im.setAttribute('href', BASE + file);
    g.__im.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', BASE + file);
    const p = SPRITES[name].poses[active];
    const k = p.k ?? 1;
    g.__im.setAttribute('transform', `translate(${(-p.ax * k).toFixed(2)} ${(-p.ay * k).toFixed(2)}) scale(${k})`);
  }

  const s = ((def.scale ?? 0.35) * STAGE_H / (meta.ref * (meta.height ?? 1)));
  const bounce = -Math.abs(Math.sin(Math.PI * beat * 2 * t + seed * 6.283)) * 6 * energy;
  const sway = Math.sin(Math.PI * beat * t + seed * 6.283) * 5 * energy;
  g.setAttribute('transform',
    `translate(${(X + sway).toFixed(2)} ${(Y + bounce).toFixed(2)}) ` +
    `rotate(${(Math.sin(t * beat * 2.1 + seed * 9) * 2.2).toFixed(2)}) scale(${s.toFixed(5)})`);
  g.setAttribute('opacity', String(0.5 + 0.22 * energy));
}
