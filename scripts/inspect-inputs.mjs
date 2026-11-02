#!/usr/bin/env node
// Inspect whatever is in motion/painted-story/inputs and report what the
// pipeline can measure. Run it after dropping the voice and the reference clip:
//
//   node scripts/inspect-inputs.mjs
//
// It only reads. Nothing is written outside the project folder.
import { execFileSync } from 'node:child_process';
import { existsSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..');
const PROJECT = join(ROOT, 'motion', 'painted-story');
const VOICE = join(PROJECT, 'inputs', 'voice');
const REFERENCE = join(PROJECT, 'inputs', 'reference');

const MEDIA = /\.(wav|mp3|m4a|flac|ogg|opus|mp4|mov|webm|mkv|gif)$/i;

function ffmpegPath() {
  const bundled = join(ROOT, 'node_modules', '@ffmpeg-installer', 'linux-x64', 'ffmpeg');
  if (existsSync(bundled)) return bundled;
  return 'ffmpeg';
}

function ffprobePath() {
  const bundled = join(ROOT, 'node_modules', '@ffprobe-installer', 'linux-x64', 'ffprobe');
  if (existsSync(bundled)) return bundled;
  return 'ffprobe';
}

function run(bin, args, file) {
  try {
    return execFileSync(bin, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (error) {
    if (error.code === 'ENOENT' && bin === ffprobePath() && bin !== 'ffprobe' === false) return null;
    if (error.code === 'ENOENT') {
      throw new Error(
        `${bin} was not found.\n` +
        '  Install the dev dependencies:  npm install\n' +
        '  Or put ffmpeg/ffprobe on PATH:  which ffprobe',
      );
    }
    throw error;
  }
}

function probe(file) {
  const out = execFileSync(ffprobePath(), [
    '-v', 'error', '-print_format', 'json',
    '-show_format', '-show_streams', file,
  ], { encoding: 'utf8' });
  return JSON.parse(out);
}

function listMedia(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((f) => MEDIA.test(f))
    .map((f) => join(dir, f))
    .sort();
}

const mb = (n) => (n / 1024 / 1024).toFixed(1) + ' MB';
const secs = (n) => Number(n).toFixed(2) + ' s';

// Fail once, clearly, before printing half a report.
for (const [name, bin, args] of [
  ['ffprobe', ffprobePath(), ['-version']],
  ['ffmpeg', ffmpegPath(), ['-version']],
]) {
  try {
    execFileSync(bin, args, { stdio: 'ignore' });
  } catch {
    console.error(`\n  ${name} is not available (looked for: ${bin}).`);
    console.error('  Fix: run `npm install` in the repo root, or install ffmpeg.');
    console.error('  Nothing was measured.\n');
    process.exit(1);
  }
}

let found = 0;

// ---------------------------------------------------------------- voice
console.log('\n=== inputs/voice ===');
const voices = listMedia(VOICE);
if (!voices.length) {
  console.log('  (empty) — drop the narration here: narration.wav');
} else {
  for (const file of voices) {
    found++;
    const info = probe(file);
    const a = info.streams.find((s) => s.codec_type === 'audio');
    const size = statSync(file).size;
    console.log(`\n  ${file.split('/').pop()}`);
    console.log(`    duration     ${secs(info.format.duration)}   (${mb(size)})`);
    if (a) {
      console.log(`    codec        ${a.codec_name} · ${a.sample_rate} Hz · ${a.channels} ch`);
      console.log(`    bitrate      ${Math.round(Number(a.bit_rate || info.format.bit_rate) / 1000)} kb/s`);
    }
    if (!/\.wav$/i.test(file)) {
      console.log('    note         not WAV — it will be decoded to 48k mono WAV first');
    }
  }
  const transcript = join(VOICE, 'transcript.txt');
  console.log(
    transcript && existsSync(transcript)
      ? '\n  transcript.txt found — captions will use it instead of ASR output.'
      : '\n  no transcript.txt — captions will come from ASR (expect a few errors to fix).',
  );
}

// ------------------------------------------------------------ reference
console.log('\n=== inputs/reference ===');
const refs = listMedia(REFERENCE);
if (!refs.length) {
  console.log('  (empty) — drop the style sample here: style-reference.mp4');
} else {
  for (const file of refs) {
    found++;
    const info = probe(file);
    const v = info.streams.find((s) => s.codec_type === 'video');
    const size = statSync(file).size;
    console.log(`\n  ${file.split('/').pop()}`);
    console.log(`    duration     ${secs(info.format.duration)}   (${mb(size)})`);
    if (v) {
      console.log(`    video        ${v.codec_name} · ${v.width}×${v.height} · ${v.r_frame_rate} fps`);
      console.log(`    aspect       ${(v.width / v.height).toFixed(3)} (${v.width > v.height ? 'landscape' : 'vertical'})`);
    }
    const a = info.streams.find((s) => s.codec_type === 'audio');
    console.log(`    audio        ${a ? `${a.codec_name} · ${a.channels} ch` : 'none'}`);
    if (size > 50 * 1024 * 1024) {
      console.log('    note         over 50 MB — keep it local, do not commit it');
    }
  }
}

// --------------------------------------------------------------- brand
const brand = join(PROJECT, 'assets', 'brand');
const brandFiles = existsSync(brand) ? readdirSync(brand).filter((f) => !f.startsWith('.')) : [];
console.log('\n=== assets/brand ===');
console.log(brandFiles.length ? '  ' + brandFiles.join(', ') : '  (empty, optional)');

// ------------------------------------------------------------- summary
console.log('\n=== summary ===');
if (!found) {
  console.log('  Nothing to measure yet. See motion/painted-story/README.md.');
} else {
  console.log(`  ${voices.length} voice file(s), ${refs.length} reference clip(s) ready.`);
  console.log('  Next: say "ready" and the pipeline runs — decode, silence map,');
  console.log('  word timings, shot rhythm, palette, then the plates.');
}
console.log('');
