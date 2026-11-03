#!/usr/bin/env node
/**
 * VO → timeline + subtitles + camera plan.
 *
 *   npm run story:timeline -- <slug> [--lang fa|en] [--vo path] [--script path]
 *
 * 1. ffmpeg silencedetect finds the speech blocks in the recording
 * 2. the narration lines are spread over those blocks in proportion to their
 *    character count (a narrator keeps an almost constant syllable rate)
 * 3. content/timeline.js (+ timeline.<lang>.js), subtitles/<lang>.srt and a
 *    starter content/scenes.auto.js are written
 *
 * No hand-edited timings: re-recording the VO re-cuts the whole film.
 */
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join, relative } from 'node:path';
import {
  ROOT, durationOf, ensureProjectDirs, ffmpeg, langOf, parseArgs,
  project, scriptFile, scriptLines, srtTime, voPath,
} from './lib.mjs';

const A = parseArgs();
const P = project(A);
const L = langOf(A, P);
const D = ensureProjectDirs(P);
const VO = voPath(A, P, L);
const ff = ffmpeg();
const FPS = Number(A.flags.fps || P.config.fps || 30);
const TAIL = Number(P.config.tail ?? 1.1);
const MIN_SCENE = Number(P.config.minScene ?? 1.4);

console.log(`project  ${P.slug}  ·  lang ${L}`);
console.log(`voice    ${relative(ROOT, VO)}`);

// ------------------------------------------------------------ speech blocks --
const probe = spawnSync(ff, [
  '-hide_banner', '-i', VO,
  '-af', 'silencedetect=noise=-32dB:d=0.28', '-f', 'null', '-',
], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
const log = `${probe.stdout || ''}${probe.stderr || ''}`;
const events = [...log.matchAll(/silence_(start|end): ([0-9.]+)/g)]
  .map((m) => ({ kind: `silence_${m[1]}`, t: Number(m[2]) }));
const total = durationOf(VO, ff);

const blocks = [];
let cur = 0;
for (const { kind, t } of events) {
  if (kind === 'silence_start') {
    if (t - cur > 0.05) blocks.push([cur, t]);
    cur = null;
  } else if (cur === null) {
    cur = t;
  }
}
if (cur !== null && total - cur > 0.05) blocks.push([cur, total]);
if (!blocks.length) blocks.push([0, total]);
const speechTotal = blocks.reduce((a, [s, e]) => a + (e - s), 0);

const toReal = (off) => {
  let acc = 0;
  for (const [s, e] of blocks) {
    const d = e - s;
    if (off <= acc + d) return s + Math.max(0, off - acc);
    acc += d;
  }
  return blocks[blocks.length - 1][1];
};

// --------------------------------------------------------------- sentences --
const S = scriptFile(A, P, L);
let sentences = scriptLines(S.text);

// No script yet? Hand the user a skeleton with one line per speech block.
if (!sentences.length) {
  const skeleton = [
    '# متن نریشن — هر خط = یک صحنه / یک جمله.',
    '# خطهایی که با # شروع میشن خونده نمیشن. این متن جایگزین کن، بعد دوباره اجرا کن:',
    '#   npm run story:timeline -- ' + P.slug + (L !== (P.config.lang || 'fa') ? ` --lang ${L}` : ''),
    '#',
    ...blocks.map((_, i) => (L === 'fa' ? `جملهٔ ${i + 1}` : `Sentence ${i + 1}`)),
    '',
  ].join('\n');
  mkdirSync(D.vo, { recursive: true });
  writeFileSync(S.path, skeleton, 'utf8');
  console.log(`\nvoice    ${total.toFixed(2)}s · ${blocks.length} speech blocks · ${speechTotal.toFixed(2)}s speaking`);
  console.log(`متن نریشن پیدا نشد. اسکلت ${blocks.length} خطی ساخته شد:`);
  console.log(`  ${relative(ROOT, S.path)}`);
  console.log('متن واقعی رو جایگزین کن و دوباره اجرا کن.');
  process.exit(2);
}

const charTotal = sentences.reduce((a, t) => a + t.length, 0);
let acc = 0;
const rows = sentences.map((text, i) => {
  const a = toReal((acc / charTotal) * speechTotal);
  acc += text.length;
  const b = toReal((acc / charTotal) * speechTotal);
  return { i: i + 1, text, start: +a.toFixed(3), end: +b.toFixed(3) };
});

const merged = [];
for (const r of rows) {
  if (merged.length && r.end - r.start < MIN_SCENE) {
    const prev = merged[merged.length - 1];
    prev.text = `${prev.text} ${r.text}`;
    prev.end = r.end;
  } else merged.push({ ...r });
}
merged[0].start = 0;
for (let i = 1; i < merged.length; i++) merged[i].start = merged[i - 1].end;
merged[merged.length - 1].end = total;

// ------------------------------------------------------------ subtitle cues --
const SPLIT_RE = L === 'fa'
  ? /(?<=[،؛؟!:…])\s+|(?<=\.)\s+/u
  : /(?<=[.,;:!?…])\s+/u;
const MAX = L === 'fa' ? 62 : 74;
const WRAP = L === 'fa' ? 56 : 68;
function chunks(text) {
  const parts = text.split(SPLIT_RE).map((p) => p.trim()).filter(Boolean);
  const out = [];
  for (const p of parts) {
    if (p.length <= MAX) { out.push(p); continue; }
    const words = p.split(' ');
    let line = '';
    for (const w of words) {
      if ((`${line} ${w}`).trim().length > WRAP && line) { out.push(line.trim()); line = w; }
      else line = `${line} ${w}`;
    }
    if (line.trim()) out.push(line.trim());
  }
  return out.length ? out : [text];
}

const cues = [];
for (const s of merged) {
  const parts = chunks(s.text);
  const n = parts.reduce((a, p) => a + p.length, 0) || 1;
  let run = 0;
  parts.forEach((p, k) => {
    const a = s.start + (run / n) * (s.end - s.start);
    run += p.length;
    const b = s.start + (run / n) * (s.end - s.start);
    cues.push({
      start: +(k === 0 ? s.start : a).toFixed(3),
      end: +(k === parts.length - 1 ? s.end : b).toFixed(3),
      text: p,
    });
  });
}

// ------------------------------------------------------------- write files --
const filmDuration = +(total + TAIL).toFixed(3);
const frames = Math.round(filmDuration * FPS);
const timelineJs = `// GENERATED by engine/timeline.mjs — do not edit by hand.\n` +
  `export const LANG = ${JSON.stringify(L)};\n` +
  `export const FPS = ${FPS};\n` +
  `export const VO_DURATION = ${total.toFixed(3)};\n` +
  `export const DURATION = ${filmDuration};\n` +
  `export const FRAMES = ${frames};\n` +
  `export const BLOCKS = ${JSON.stringify(blocks.map(([s, e]) => [+s.toFixed(3), +e.toFixed(3)]))};\n` +
  `export const SENTENCES = ${JSON.stringify(merged, null, 2)};\n` +
  `export const CUES = ${JSON.stringify(cues, null, 2)};\n`;

mkdirSync(D.content, { recursive: true });
mkdirSync(D.subtitles, { recursive: true });
mkdirSync(D.exports, { recursive: true });
// The unsuffixed copy is always the project's DEFAULT language, so running
// --lang en never silently replaces the Persian timeline.
if (L === (P.config.lang || 'fa')) writeFileSync(join(D.content, 'timeline.js'), timelineJs);
writeFileSync(join(D.content, `timeline.${L}.js`), timelineJs);

const srt = cues.map((c, i) => `${i + 1}\n${srtTime(c.start)} --> ${srtTime(c.end)}\n${c.text}\n`).join('\n');
writeFileSync(join(D.subtitles, `${L}.srt`), srt);
writeFileSync(join(D.exports, `${P.slug}-${L}.srt`), srt);

// A deterministic camera plan for every sentence. Copy scenes.auto.js to
// scenes.js and edit it once you have the illustrated plates.
const MOVES = ['hook', 'in', 'panR', 'inL', 'tiltU', 'hold', 'out', 'panL', 'tiltD', 'inR', 'push', 'hold'];
const scenes = merged.map((s, i) => {
  const h = (n) => Math.abs(Math.sin((i + 1) * 12.9898 + n * 78.233) * 43758.5453 % 1);
  return {
    id: i + 1,
    plate: `p${String((i % 20) + 1).padStart(2, '0')}`,
    move: MOVES[i % MOVES.length],
    amt: +(0.72 + h(1) * 0.22).toFixed(2),
    a0: [+(0.40 + h(2) * 0.20).toFixed(2), +(0.42 + h(3) * 0.18).toFixed(2)],
    a1: [+(0.42 + h(4) * 0.18).toFixed(2), +(0.46 + h(5) * 0.16).toFixed(2)],
    fog: +(0.10 + h(6) * 0.20).toFixed(2),
    warm: +(0.08 + h(7) * 0.42).toFixed(2),
  };
});
const scenesJs = `// GENERATED by engine/timeline.mjs — starter camera plan.\n` +
  `// کپی کن به scenes.js و ویرایشش کن؛ تا وقتی scenes.js نباشه رندر از این فایل میخونه.\n` +
  `// plate = نام فایل تصویر در assets/plates/hd/<plate>.jpg\n` +
  `export const SCENES = ${JSON.stringify(scenes, null, 2)};\n`;
writeFileSync(join(D.content, 'scenes.auto.js'), scenesJs);
if (!existsSync(join(D.content, 'scenes.js'))) writeFileSync(join(D.content, 'scenes.js'), scenesJs);

console.log(`voice    ${total.toFixed(2)}s · ${blocks.length} speech blocks · ${speechTotal.toFixed(2)}s speaking`);
console.log(`film     ${filmDuration.toFixed(2)}s = ${frames} frames @ ${FPS}fps`);
console.log(`scenes   ${merged.length} · cues ${cues.length}`);
console.log(`wrote    content/timeline.${L}.js · subtitles/${L}.srt · content/scenes.auto.js`);
merged.forEach((s) => console.log(
  `  ${String(s.i).padStart(2)}  ${s.start.toFixed(2).padStart(7)} → ${s.end.toFixed(2).padStart(7)}  ${s.text.slice(0, 48)}`,
));
