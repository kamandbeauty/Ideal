#!/usr/bin/env node
/**
 * Narration + score → audio/mix.wav
 *
 * The score is synthesised: a low drone, a slow heartbeat and a room-tone
 * bed. The heartbeat is what carries the dread — silence is the subject of
 * this film, so there is no melodic music to fight the voice.
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
const argv = process.argv.slice(2);
const LANG = argv.includes('--lang') ? argv[argv.indexOf('--lang') + 1] : 'fa';
const EN = LANG === 'en';
// این پروژه صداگذاریِ خودش را دارد: روایتِ فارسیِ روی سالیوان
const VO = join(ROOT, 'Generated Audio November 03, 2026 - 3_13PM.wav');
const OUT = join(HERE, 'mix.wav');

const { DURATION, VO_DURATION } = await import(pathToFileURL(join(PROJECT, 'content', 'timeline.js')).href);
const D = DURATION.toFixed(3);
const BEAT = 1.42;                 // one heartbeat every 1.42 s

if (!existsSync(FFMPEG)) throw new Error('missing bundled ffmpeg — run npm install');
mkdirSync(HERE, { recursive: true });

// heartbeat: a 46 Hz thump + its octave, decaying, restarting every BEAT
const hb = `(0.34*sin(2*PI*46*t)+0.11*sin(2*PI*92*t))*exp(-7*mod(t,${BEAT}))*lt(mod(t,${BEAT}),1.1)`;
// drone: two low sines, slowly breathing
const drone = `(0.055*sin(2*PI*55*t)+0.035*sin(2*PI*82.5*t))*(0.75+0.25*sin(2*PI*0.06*t))`;
// room tone: pink noise, band-limited, breathing
const air = `0.9*(0.62+0.38*sin(2*PI*0.05*t))`;

const filter = [
  `[0:a]aresample=48000,aformat=channel_layouts=mono,highpass=f=85,` +
    `acompressor=threshold=-18dB:ratio=3:attack=8:release=180,volume=1.0[vo]`,
  `aevalsrc=exprs='${drone}':s=48000:d=${D}:c=mono[dr]`,
  `aevalsrc=exprs='${hb}':s=48000:d=${D}:c=mono[hb]`,
  `anoisesrc=c=pink:r=48000:a=0.04:d=${D},bandpass=f=620:width_type=h:w=900,` +
    `volume='${air}':eval=frame[air]`,
  `[dr]volume=0.55[dr2]`,
  `[dr2][hb][air]amix=inputs=3:duration=longest,volume=3,lowpass=f=300,volume=0.62[bed]`,
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
