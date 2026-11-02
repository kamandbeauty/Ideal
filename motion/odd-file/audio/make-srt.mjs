#!/usr/bin/env node
/**
 * THE ODD FILE — subtitle generator.
 *
 * Reads the same beat timings the picture uses, so captions can never drift:
 * each caption starts on its beat and ends when that beat's narration ends.
 * Long lines are split into two cards at a word boundary, timed by word share.
 *
 *   node audio/make-srt.mjs            → subtitles/ep-001.srt
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ODDFILE = resolve(HERE, '..');

const { EPISODE } = await import(pathToFileURL(join(ODDFILE, 'content', 'episode.js')).href);
const { TIMELINE } = await import(pathToFileURL(join(ODDFILE, 'timeline.js')).href);

const MAX_CHARS = 46; // per caption card, single line

const font = 'green'; // unused placeholder keeps the file swappable

function stamp(seconds) {
  const ms = Math.round(seconds * 1000);
  const h = Math.floor(ms / 3600000);
  const m = Math.floor((ms % 3600000) / 60000);
  const s = Math.floor((ms % 60000) / 1000);
  const r = ms % 1000;
  const p = (n, w = 2) => String(n).padStart(w, '0');
  return `${p(h)}:${p(m)}:${p(s)},${p(r, 3)}`;
}

function splitCard(text) {
  const words = text.split(/\s+/);
  if (text.length <= MAX_CHARS) return [text];
  // pick the break whose two halves are closest in length
  let best = { diff: Infinity, at: 1 };
  for (let i = 1; i < words.length; i++) {
    const a = words.slice(0, i).join(' ').length;
    const b = words.slice(i).join(' ').length;
    const diff = Math.abs(a - b) + (a > MAX_CHARS || b > MAX_CHARS ? 100 : 0);
    if (diff < best.diff) best = { diff, at: i };
  }
  return [words.slice(0, best.at).join(' '), words.slice(best.at).join(' ')];
}

let i = 0;
const blocks = [];
for (const beat of EPISODE.beats) {
  const t = TIMELINE.beats.find((b) => b.id === beat.id);
  if (!t) throw new Error(`No timeline entry for ${beat.id}. Run: npm run odd-file:audio`);
  const words = beat.vo.split(/\s+/);
  const cards = [];
  if (beat.vo.length <= MAX_CHARS) {
    cards.push({ text: beat.vo, from: 0, to: words.length });
  } else {
    const [a, b] = splitCard(beat.vo);
    const nA = a.split(/\s+/).length;
    cards.push({ text: a, from: 0, to: nA });
    cards.push({ text: b, from: nA, to: words.length });
  }

  for (const card of cards) {
    const start = t.start + (t.voDur * card.from) / words.length;
    const end = t.start + (t.voDur * card.to) / words.length;
    i += 1;
    blocks.push(
      `${i}\n${stamp(start)} --> ${stamp(end)}\n${card.text.toUpperCase()}\n`,
    );
  }
}

const outDir = join(ODDFILE, 'subtitles');
mkdirSync(outDir, { recursive: true });
const out = join(outDir, 'ep-001.srt');
writeFileSync(out, blocks.join('\n'));
console.log(`${out} — ${blocks.length} captions, ${TIMELINE.total.toFixed(2)} s`);
void font;
