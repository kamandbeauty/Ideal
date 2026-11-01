#!/usr/bin/env node
// Scaffold a new motion graphic from the skill's starter scene.
// Usage: node new-motion.mjs <slug> [--force]
import { copyFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const skillRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const projectRoot = process.cwd();
const args = process.argv.slice(2);
const force = args.includes('--force');
const slug = args.find((a) => !a.startsWith('--'));

if (!slug) {
  console.error('Usage: npm run motion:new -- <slug> [--force]');
  console.error('Example: npm run motion:new -- brand-intro');
  process.exit(1);
}
if (!/^[a-z0-9][a-z0-9-]*[a-z0-9]?$/.test(slug)) {
  console.error(`Invalid slug "${slug}". Use lowercase letters, digits, and hyphens.`);
  process.exit(1);
}

const dest = resolve(projectRoot, 'motion', slug);
if (existsSync(join(dest, 'index.html')) && !force) {
  console.error(`${dest}/index.html already exists. Pass --force to overwrite it.`);
  process.exit(1);
}
mkdirSync(dest, { recursive: true });

const starter = join(skillRoot, 'assets', 'starter.html');
if (!existsSync(starter)) {
  console.error(`Missing starter asset: ${starter}`);
  process.exit(1);
}
copyFileSync(starter, join(dest, 'index.html'));

const brief = `# ${slug}

## Brief

- Deliverable: out/${slug}.mp4
- Canvas: 1920x1080, 30 fps, 6 s (180 frames)
- Copy: _(exact wording from the request)_
- Brand: _(colours / fonts, or the starter palette)_
- Audio: none (mux separately if needed)

## Beat sheet

| Beat | Frames | Element | Motion |
| --- | --- | --- | --- |
| 1 | 0-45 | Eyebrow, accent rule | Slide up + line draw |
| 2 | 18-90 | Title lines | Staggered mask reveal |
| 3 | 54-115 | Subtitle, stat | Fade up, count-up |
| 4 | 120-165 | Accent shapes | Slow deterministic drift |
| 5 | 165-180 | Full composition | Hold readable end card |

## Checklist

- [ ] Copy is verbatim and inside the 10% safe inset
- [ ] Frame 0, frame 90, and frame 179 look intentional
- [ ] No wall-clock animation, randomness, or remote assets
- [ ] \`npm run motion:render -- ${slug}\` produces the requested duration
`;

if (!existsSync(join(dest, 'brief.md')) || force) {
  writeFileSync(join(dest, 'brief.md'), brief);
}

console.log(`Created motion/${slug}/`);
console.log(`  index.html  editable scene (window.__MOTION__ contract)`);
console.log(`  brief.md    beat sheet + QA checklist`);
console.log('');
console.log(`Next:  npm run motion:render -- ${slug}`);
console.log(`       open motion/${slug}/index.html?frame=90 to inspect one frame`);
