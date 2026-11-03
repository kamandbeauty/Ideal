#!/usr/bin/env node
/**
 * Narration + score → audio/mix.<lang>.wav
 *
 *   npm run story:audio -- <slug> [--lang fa|en]
 *
 * The score is synthesised, not licensed music: a low drone, a slow heartbeat
 * and room tone, sidechain-ducked under the voice. Silence is part of the
 * house style, so there is no melody fighting the narrator.
 */
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { ROOT, ensureProjectDirs, ffmpeg, langOf, loadJs, parseArgs, project, voPath } from './lib.mjs';

const A = parseArgs();
const P = project(A);
const L = langOf(A, P);
const D = ensureProjectDirs(P);
const VO = voPath(A, P, L);
const ff = ffmpeg();

const perLang = join(D.content, `timeline.${L}.js`);
const { DURATION, VO_DURATION } = await loadJs(existsSync(perLang) ? perLang : join(D.content, 'timeline.js'));
const Dur = Number(DURATION).toFixed(3);
const BEAT = Number(P.config.beat || 1.42);       // one heartbeat every 1.42 s
const OUT = join(D.audio, `mix.${L}.wav`);

// heartbeat: a 46 Hz thump + its octave, decaying, restarting every BEAT
const hb = `(0.34*sin(2*PI*46*t)+0.11*sin(2*PI*92*t))*exp(-7*mod(t,${BEAT}))*lt(mod(t,${BEAT}),1.1)`;
// drone: two low sines, slowly breathing
const drone = `(0.055*sin(2*PI*55*t)+0.035*sin(2*PI*82.5*t))*(0.75+0.25*sin(2*PI*0.06*t))`;
const air = `0.9*(0.62+0.38*sin(2*PI*0.05*t))`;

const filter = [
  `[0:a]aresample=48000,aformat=channel_layouts=mono,highpass=f=85,` +
    `acompressor=threshold=-18dB:ratio=3:attack=8:release=180,volume=1.0[vo]`,
  `aevalsrc=exprs='${drone}':s=48000:d=${Dur}:c=mono[dr]`,
  `aevalsrc=exprs='${hb}':s=48000:d=${Dur}:c=mono[hb]`,
  `anoisesrc=c=pink:r=48000:a=0.04:d=${Dur},bandpass=f=620:width_type=h:w=900,` +
    `volume='${air}':eval=frame[air]`,
  `[dr]volume=0.55[dr2]`,
  `[dr2][hb][air]amix=inputs=3:duration=longest,volume=3,lowpass=f=300,volume=0.62[bed]`,
  `[vo]asplit[voice][key]`,
  `[bed]aformat=sample_fmts=fltp:channel_layouts=mono[bedM]`,
  `[bedM][key]sidechaincompress=threshold=0.02:ratio=9:attack=15:release=320[bedDucked]`,
  `[voice]aformat=sample_fmts=fltp:channel_layouts=mono[vm]`,
  `[vm][bedDucked]amix=inputs=2:duration=longest,volume=2,` +
    `apad,atrim=0:${Dur},asetpts=N/SR/TB,` +
    `loudnorm=I=-14:TP=-1.5:LRA=9,alimiter=limit=0.92,aformat=channel_layouts=stereo[out]`,
].join(';');

mkdirSync(D.audio, { recursive: true });
const args = [
  '-y', '-hide_banner', '-loglevel', 'error', '-i', VO,
  '-filter_complex', filter, '-map', '[out]',
  '-ar', '48000', '-c:a', 'pcm_s16le', OUT,
];
const r = spawnSync(ff, args, { stdio: 'inherit' });
if (r.status !== 0) throw new Error('ffmpeg mix failed');

console.log(`voice    ${relative(ROOT, VO)}  (${VO_DURATION}s)`);
console.log(`wrote    ${relative(ROOT, OUT)}  ${(statSync(OUT).size / 1048576).toFixed(1)} MB  ·  film ${Dur}s`);
