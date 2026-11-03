#!/usr/bin/env node
/**
 * One command from "I dropped a VO" to "the film is timed, subtitled and mixed".
 *
 *   npm run story:build -- <slug> [--lang fa|en]
 *
 * Steps: timeline → words → audio. If content/transcript.json is present (an
 * ASR pass with word timestamps), align.py replaces timeline + words so every
 * cue starts exactly where the voice starts. Rendering is deliberately NOT
 * automatic (a 3-minute film is thousands of frames); run story:stills for a
 * quick look and story:render when the illustrated plates are in place.
 */
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { ENGINE, parseArgs, project } from './lib.mjs';

const A = parseArgs();
const P = project(A);
const L = A.flags.lang || P.config.lang || 'fa';
const args = process.argv.slice(2);
const asr = existsSync(join(P.dir, 'content', 'transcript.json'));

const steps = asr
  ? ['align.py', 'audio.mjs']
  : ['timeline.mjs', 'words.mjs', 'audio.mjs'];

if (asr) console.log('ASR transcript found → exact word-level alignment');

for (const step of steps) {
  console.log(`\n─── ${step} ───`);
  const bin = step.endsWith('.py') ? 'python3' : process.execPath;
  const cmdArgs = step.endsWith('.py')
    ? [join(ENGINE, step), ...args]
    : [join(ENGINE, step), ...args];
  const r = spawnSync(bin, cmdArgs, { stdio: 'inherit' });
  if (r.status !== 0) {
    if (r.status === 2) {
      console.log('\nمتن نریشن رو پر کن و دوباره `npm run story:build` رو اجرا کن.');
    }
    process.exit(r.status || 1);
  }
}

console.log(`\n✅ ${P.slug} (${L}) آمادهست:`);
console.log(`   projects/${P.slug}/subtitles/${L}.srt`);
console.log(`   projects/${P.slug}/audio/mix.${L}.wav`);
console.log('\nبعدیش: تصویرها رو بذار تو projects/' + P.slug + '/assets/plates/hd/ و:');
console.log(`   npm run story:stills -- ${P.slug}`);
console.log(`   npm run story:render -- ${P.slug} --fast`);
