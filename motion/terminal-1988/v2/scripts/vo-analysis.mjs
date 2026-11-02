#!/usr/bin/env node
// Lipsync from the narration itself.
//
//   node scripts/vo-analysis.mjs <vo.wav> <out.json> [fps]
//
// Reads the PCM, then for every video frame computes
//   energy  – RMS of a 2-frame window, normalised 0..1
//   open    – how far the mouth should be open, 0..1
//   vowel   – which of a / e / o / i / u the spectrum looks like (0..4)
// Nothing here is hand-keyed: the mouth follows the voice.
import { readFileSync, writeFileSync } from 'node:fs';

const [, , inPath, outPath, fpsArg] = process.argv;
if (!inPath || !outPath) { console.error('usage: vo-analysis.mjs <in.wav> <out.json> [fps]'); process.exit(1); }
const FPS = Number(fpsArg || 30);

// ---- minimal RIFF reader -------------------------------------------------
const buf = readFileSync(inPath);
if (buf.toString('ascii', 0, 4) !== 'RIFF' || buf.toString('ascii', 8, 12) !== 'WAVE') {
  console.error('not a WAV'); process.exit(1);
}
let off = 12, fmt = null, pcm = null;
while (off + 8 <= buf.length) {
  const id = buf.toString('ascii', off, off + 4);
  const size = buf.readUInt32LE(off + 4);
  const body = off + 8;
  if (id === 'fmt ') {
    fmt = {
      format: buf.readUInt16LE(body),
      channels: buf.readUInt16LE(body + 2),
      rate: buf.readUInt32LE(body + 4),
      bits: buf.readUInt16LE(body + 14),
    };
  } else if (id === 'data') {
    pcm = buf.subarray(body, body + size);
  }
  off = body + size + (size % 2);
}
if (!fmt || !pcm) { console.error('no fmt/data'); process.exit(1); }
if (fmt.format !== 1 || fmt.bits !== 16) { console.error(`need 16-bit PCM, got format ${fmt.format} / ${fmt.bits}-bit`); process.exit(1); }

const n = Math.floor(pcm.length / 2);
const mono = new Float32Array(n);
for (let i = 0; i < n; i++) mono[i] = pcm.readInt16LE(i * 2) / 32768;
// downmix if the file is stereo
const spc = fmt.channels;
const samples = spc === 1 ? mono : (() => {
  const m = new Float32Array(n / spc);
  for (let i = 0; i < m.length; i++) {
    let s = 0; for (let c = 0; c < spc; c++) s += mono[i * spc + c]; m[i] = s / spc;
  }
  return m;
})();

const SR = fmt.rate;
const sr = SR / spc > 0 ? SR : SR; // sample rate is per-channel in WAV
const total = samples.length / sr;  // seconds
const frames = Math.ceil(total * FPS);

// ---- window stats --------------------------------------------------------
const hop = sr / FPS;          // samples per video frame
const win = Math.round(hop * 2); // two-frame analysis window

// Vowel detection with a Goertzel probe at six formant-ish frequencies.
// No FFT library needed: for each frame we measure how much energy sits near
// 350 / 500 / 700 / 1200 / 1800 / 2400 Hz, then pick the vowel whose two
// formants best match that pattern. Crude, but it moves with the voice.
const PROBE = [350, 500, 700, 1200, 1800, 2400];
const VOWELS = [
  { name: 'a', f1: 700, f2: 1200 },
  { name: 'e', f1: 500, f2: 1800 },
  { name: 'o', f1: 450, f2: 800 },
  { name: 'i', f1: 300, f2: 2400 },
  { name: 'u', f1: 325, f2: 700 },
];
function goertzel(x, from, len, hz, sr) {
  const k = 2 * Math.cos(2 * Math.PI * hz / sr);
  let s0 = 0, s1 = 0, s2 = 0;
  for (let i = 0; i < len; i++) {
    s0 = x[from + i] + k * s1 - s2;
    s2 = s1; s1 = s0;
  }
  return Math.sqrt(Math.max(0, s1 * s1 + s2 * s2 - k * s1 * s2)) / len;
}

function frameStats(i) {
  const start = Math.max(0, Math.round(i * hop - hop * 0.5));
  const end = Math.min(samples.length, start + win);
  const len = end - start;
  if (len <= 8) return { rms: 0, bands: null };

  let sum = 0;
  for (let k = start; k < end; k++) sum += samples[k] * samples[k];
  const bands = PROBE.map((hz) => goertzel(samples, start, len, hz, sr));
  return { rms: Math.sqrt(sum / len), bands };
}

function vowelOf(bands) {
  if (!bands) return 0;
  const total = bands.reduce((a, b) => a + b, 0) || 1;
  const norm = bands.map((v) => v / total);
  let best = 0, bestScore = -Infinity;
  VOWELS.forEach((v, idx) => {
    const at = (hz) => norm[PROBE.indexOf(PROBE.reduce((p, c) => Math.abs(c - hz) < Math.abs(p - hz) ? c : p, PROBE[0]))];
    const score = at(v.f1) + at(v.f2);        // more energy at its own formants wins
    if (score > bestScore) { bestScore = score; best = idx; }
  });
  return best;
}

const raw = [];
let peak = 0;
for (let i = 0; i < frames; i++) {
  const s = frameStats(i);
  peak = Math.max(peak, s.rms);
  raw.push(s);
}
const noise = (() => {                       // 10th percentile = the room floor
  const sorted = raw.map((s) => s.rms).sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length * 0.10)] || 0;
})();
const loud = Math.max(1e-6, peak - noise);

const out = raw.map((s) => {
  const e = Math.max(0, (s.rms - noise) / loud);          // 0..1
  // the mouth follows a compressed, slightly gated energy curve; a whisper of
  // smoothing stops single frames from flickering the jaw
  const open = Math.min(1, Math.pow(e, 0.7) * 1.22);
  const vowel = e > 0.07 ? vowelOf(s.bands) : 0;
  return [Number(e.toFixed(3)), Number(open.toFixed(3)), vowel];
});
// one-pole smoothing on the opening, then re-quantise
let prev = 0;
for (const f of out) { prev = prev * 0.55 + f[1] * 0.45; f[1] = Number(prev.toFixed(3)); }

const payload = JSON.stringify({ fps: FPS, duration: Number(total.toFixed(3)), noise: Number(noise.toFixed(5)), peak: Number(peak.toFixed(5)), frames: out });
writeFileSync(outPath, payload);
// a JS twin, because file:// pages cannot fetch JSON — a script tag can
if (outPath.endsWith('.json')) {
  writeFileSync(outPath.replace(/\.json$/, '.js'), 'window.__VOICE = ' + payload + ';\n');
}
const speech = out.filter((f) => f[0] > 0.15).length;
console.log(`${frames} frames · ${total.toFixed(2)} s · ${(100 * speech / frames).toFixed(0)}% speech · peak ${peak.toFixed(3)} · noise ${noise.toFixed(4)}`);
console.log('wrote', outPath);
