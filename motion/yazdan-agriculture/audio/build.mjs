#!/usr/bin/env node
/**
 * Narration + light score → audio/mix.wav
 *
 * The bed is synthesised: a warm major-chord pad, slow breathing, and a quiet
 * room tone. Nothing rhythmic — this is a friendly classroom lesson, the voice
 * must stay the only thing you actively listen to.
 *
 *   node audio/build.mjs
 */
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const PROJECT = resolve(HERE, '..');
const ROOT = resolve(PROJECT, '../..');
const FFMPEG = join(ROOT, 'node_modules', '@ffmpeg-installer', 'linux-x64', 'ffmpeg');
const VO = join(ROOT, 'Generated Audio November 08, 2026 - 8_16PM.wav');
const OUT = join(HERE, 'mix.wav');

const { DURATION, VO_DURATION } = await import(pathToFileURL(join(PROJECT, 'content', 'timeline.js')).href);
const D = DURATION.toFixed(3);

if (!existsSync(FFMPEG)) throw new Error('missing bundled ffmpeg — run npm install');
mkdirSync(HERE, { recursive: true });

// warm C-major pad (C3, G3, C4, E4), slowly breathing
const pad = `(0.030*sin(2*PI*130.81*t)+0.024*sin(2*PI*196.00*t)+0.020*sin(2*PI*261.63*t)+0.016*sin(2*PI*329.63*t))*(0.62+0.38*sin(2*PI*0.07*t))`;
// a very soft high shimmer, one octave above the root, breathing in counter-phase
const shim = `0.006*sin(2*PI*523.25*t)*(0.5+0.5*sin(2*PI*0.05*t+2.1))`;
// room tone: pink noise, band-limited, breathing
const air = `0.8*(0.60+0.40*sin(2*PI*0.045*t))`;

const filter = [
  `[0:a]aresample=48000,aformat=channel_layouts=mono,highpass=f=85,` +
    `acompressor=threshold=-18dB:ratio=3:attack=8:release=180,volume=1.0[vo]`,
  `aevalsrc=exprs='${pad}':s=48000:d=${D}:c=mono[pad]`,
  `aevalsrc=exprs='${shim}':s=48000:d=${D}:c=mono[shim]`,
  `anoisesrc=c=pink:r=48000:a=0.030:d=${D},bandpass=f=720:width_type=h:w=1100,` +
    `volume='${air}':eval=frame[air]`,
  `[pad][shim][air]amix=inputs=3:duration=longest,lowpass=f=2400,volume=2.2[bed]`,
  `[vo]asplit[voice][key]`,
  `[bed]aformat=sample_fmts=fltp:channel_layouts=mono[bedM]`,
  `[bedM][key]sidechaincompress=threshold=0.02:ratio=9:attack=15:release=320[bedDucked]`,
  `[voice]aformat=sample_fmts=fltp:channel_layouts=mono[vm]`,
  `[vm][bedDucked]amix=inputs=2:duration=longest,volume=2,` +
    `apad,atrim=0:${D},asetpts=N/SR/TB,` +
    `loudnorm=I=-14:TP=-1.5:LRA=9,alimiter=limit=0.92,aformat=channel_layouts=stereo[out]`,
].join(';');

const args = ['-y', '-hide_banner', '-loglevel', 'error', '-i', VO, '-filter_complex', filter, '-map', '[out]', '-ar', '48000', '-c:a', 'pcm_s16le', OUT];
const r = spawnSync(FFMPEG, args, { stdio: 'inherit' });
if (r.status !== 0) throw new Error('ffmpeg mix failed');

const probe = spawnSync(FFMPEG, ['-hide_banner', '-i', OUT], { encoding: 'utf8' });
const dur = `${probe.stdout}${probe.stderr}`.match(/Duration: (\d+):(\d+):([0-9.]+)/);
console.log(`mix.wav  ${dur ? `${dur[1]}:${dur[2]}:${dur[3]}` : '?'}  ${(statSync(OUT).size / 1048576).toFixed(1)} MB  (voice ${VO_DURATION}s → film ${D}s)`);
