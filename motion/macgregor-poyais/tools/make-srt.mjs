#!/usr/bin/env node
/**
 * content/timeline.js → subtitles/macgregor-poyais.srt
 *
 *   node tools/make-srt.mjs
 *
 * Each SENTENCES row is one cue; it is displayed from `start` to `hold`
 * (the same window the engine uses for the on-screen subtitle).
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const PROJECT = resolve(HERE, '..');
const { SENTENCES } = await import(pathToFileURL(join(PROJECT, 'content', 'timeline.js')).href);

const tc = (s) => {
  const ms = Math.round(s * 1000);
  const h = String(Math.floor(ms / 3600000)).padStart(2, '0');
  const m = String(Math.floor((ms % 3600000) / 60000)).padStart(2, '0');
  const sec = String(Math.floor((ms % 60000) / 1000)).padStart(2, '0');
  return `${h}:${m}:${sec},${String(ms % 1000).padStart(3, '0')}`;
};

const out = SENTENCES.map((s, i) => {
  const end = Math.min(s.hold ?? s.end - 0.3, s.end);
  return `${i + 1}\n${tc(s.start)} --> ${tc(end)}\n${s.text}\n`;
}).join('\n');

const dir = join(PROJECT, 'subtitles');
mkdirSync(dir, { recursive: true });
const file = join(dir, 'macgregor-poyais.srt');
writeFileSync(file, out);
console.log(`wrote ${file} (${SENTENCES.length} cues)`);
