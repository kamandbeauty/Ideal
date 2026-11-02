#!/usr/bin/env node
/**
 * Builds the sentence timeline from the narration WAV.
 *
 *   node tools/timeline.mjs
 *
 * 1. runs ffmpeg silencedetect to find the speech blocks inside the recording
 * 2. spreads the sentences over those blocks in proportion to their character
 *    count (a TTS voice keeps an almost constant syllable rate)
 * 3. writes content/timeline.js (sentence + subtitle cue times) and
 *    subtitles/fa.srt
 *
 * Because everything is derived from the audio, re-recording the narration
 * re-cuts the film — no hand-edited timings anywhere.
 */
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const PROJECT = resolve(HERE, '..');
const ROOT = resolve(PROJECT, '../..');
const FFMPEG = join(ROOT, 'node_modules', '@ffmpeg-installer', 'linux-x64', 'ffmpeg');
const VO = join(ROOT, 'intake/style-v3/vo/Generated Audio November 02, 2026 - 9_11PM.wav');

const FPS = 30;
const TAIL = 1.1;          // hold the last frame after the final word
const MIN_SCENE = 1.4;     // never flash a scene shorter than this

const { SCRIPT_FA } = await client('../../content/script.js');
async function client(rel) {
  return import(pathToFileURL(join(PROJECT, 'content', 'script.js')).href);
}

if (!existsSync(FFMPEG)) throw new Error('missing bundled ffmpeg — run npm install');

// ---------------------------------------------------------------- speech blocks
const probe = spawnSync(FFMPEG, ['-hide_banner', '-i', VO, '-af', 'silencedetect=noise=-32dB:d=0.28', '-f', 'null', '-'], {
  encoding: 'utf8',
});
const log = `${probe.stdout || ''}${probe.stderr || ''}`;
const events = [...log.matchAll(/silence_(start|end): ([0-9.]+)/g)].map((m) => ({ kind: `silence_${m[1]}`, t: Number(m[2]) }));
const durProbe = spawnSync(FFMPEG, ['-hide_banner', '-i', VO], { encoding: 'utf8' });
const total = Number(`${durProbe.stdout}${durProbe.stderr}`.match(/Duration: (\d+):(\d+):([0-9.]+)/)?.slice(1)
  .reduce((acc, v, i) => acc + Number(v) * [3600, 60, 1][i], 0).toFixed(3));

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
if (!blocks.length) throw new Error('no speech found');

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

// ---------------------------------------------------------------- sentences
const clean = (t) => t.replace(/\s+/g, ' ').trim();
const sentences = SCRIPT_FA.map(clean);
const charTotal = sentences.reduce((a, t) => a + t.length, 0);

let acc = 0;
const rows = sentences.map((text, i) => {
  const a = toReal((acc / charTotal) * speechTotal);
  acc += text.length;
  const b = toReal((acc / charTotal) * speechTotal);
  return { i: i + 1, text, start: +a.toFixed(3), end: +b.toFixed(3) };
});

// merge anything too short into the previous row, then rebuild contiguous times
const merged = [];
for (const r of rows) {
  if (merged.length && r.end - r.start < MIN_SCENE) {
    const prev = merged[merged.length - 1];
    prev.text = `${prev.text} ${r.text}`;
    prev.end = r.end;
  } else {
    merged.push({ ...r });
  }
}
// scene starts snap to the previous end so there is never a gap or overlap
merged[0].start = 0;
for (let i = 1; i < merged.length; i++) merged[i].start = merged[i - 1].end;
merged[merged.length - 1].end = total;

// ---------------------------------------------------------------- subtitle cues
const SPLIT_RE = /(?<=[،؛؟!:…])\s+|(?<=\.)\s+/u;
function chunks(text) {
  const parts = text.split(SPLIT_RE).map(clean).filter(Boolean);
  const out = [];
  for (const p of parts) {
    if (p.length <= 62) { out.push(p); continue; }
    const words = p.split(' ');
    let line = '';
    for (const w of words) {
      if ((`${line} ${w}`).trim().length > 56 && line) { out.push(line.trim()); line = w; }
      else line = `${line} ${w}`;
    }
    if (line.trim()) out.push(line.trim());
  }
  return out;
}

const cues = [];
for (const s of merged) {
  const parts = chunks(s.text);
  const totalChars = parts.reduce((a, p) => a + p.length, 0) || 1;
  const sceneSpeech = (s.end - s.start);
  let run = 0;
  parts.forEach((p, k) => {
    const a = s.start + (run / totalChars) * sceneSpeech;
    run += p.length;
    const b = s.start + (run / totalChars) * sceneSpeech;
    const last = k === parts.length - 1;
    cues.push({ start: +(k === 0 ? s.start : a).toFixed(3), end: +(last ? s.end : b).toFixed(3), text: p });
  });
}

// ---------------------------------------------------------------- write files
const filmDuration = +(total + TAIL).toFixed(3);
const frames = Math.round(filmDuration * FPS);

const timelineJs = `// GENERATED by tools/timeline.mjs — do not edit by hand.
export const FPS = ${FPS};
export const VO_DURATION = ${total.toFixed(3)};
export const DURATION = ${filmDuration};
export const FRAMES = ${frames};
export const BLOCKS = ${JSON.stringify(blocks.map(([s, e]) => [+s.toFixed(3), +e.toFixed(3)]))};
export const SENTENCES = ${JSON.stringify(merged, null, 2)};
export const CUES = ${JSON.stringify(cues, null, 2)};
`;
writeFileSync(join(PROJECT, 'content', 'timeline.js'), timelineJs);

const srtTime = (t) => {
  const h = Math.floor(t / 3600);
  const m = Math.floor((t % 3600) / 60);
  const s = Math.floor(t % 60);
  const ms = Math.round((t % 1) * 1000);
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')},${String(ms).padStart(3, '0')}`;
};
mkdirSync(join(PROJECT, 'subtitles'), { recursive: true });
writeFileSync(
  join(PROJECT, 'subtitles', 'fa.srt'),
  cues.map((c, i) => `${i + 1}\n${srtTime(c.start)} --> ${srtTime(c.end)}\n${c.text}\n`).join('\n'),
);

console.log(`voice    ${total.toFixed(2)}s · ${blocks.length} speech blocks · ${speechTotal.toFixed(2)}s speaking`);
console.log(`film     ${filmDuration.toFixed(2)}s = ${frames} frames @ ${FPS}fps`);
console.log(`scenes   ${merged.length} · cues ${cues.length}`);
merged.forEach((s) => console.log(`  ${String(s.i).padStart(2)}  ${s.start.toFixed(2).padStart(7)} → ${s.end.toFixed(2).padStart(7)}  (${(s.end - s.start).toFixed(2)}s)  ${s.text.slice(0, 42)}…`));
