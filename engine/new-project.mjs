#!/usr/bin/env node
/**
 * Scaffold a new illustrated-story project.
 *
 *   npm run story:new -- <slug> [--title "..."] [--lang fa|en]
 *
 * Creates projects/<slug>/ with a vo/ drop zone, a script template, config and
 * all output folders. Nothing heavy is copied: the engine is shared.
 */
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join, relative } from 'node:path';
import { ROOT, parseArgs } from './lib.mjs';

const A = parseArgs();
const slug = A._[0];
if (!slug || !/^[a-z0-9][a-z0-9-]*$/.test(slug)) {
  throw new Error('اسم پروژه لازمه، فقط حروف کوچک انگلیسی/عدد/خط تیره: npm run story:new -- my-story');
}
const dir = join(ROOT, 'projects', slug);
if (existsSync(join(dir, 'config.json'))) throw new Error(`این پروژه از قبل هست: projects/${slug}`);

const L = A.flags.lang || 'fa';
const title = A.flags.title || slug;
const dirs = [
  'vo', 'content', 'assets/plates/hd', 'subtitles', 'audio', 'exports', 'stills',
];
for (const d of dirs) mkdirSync(join(dir, d), { recursive: true });

const config = {
  slug,
  title,
  titleNum: '',
  titleSub: '',
  lang: L,
  fps: 30,
  tail: 1.1,
  minScene: 1.4,
  beat: 1.42,
  vo: {},
};
writeFileSync(join(dir, 'config.json'), `${JSON.stringify(config, null, 2)}\n`);

const script = [
  '# متن نریشن — هر خط = یک صحنه / یک جمله.',
  '# خطهایی که با # شروع میشن خونده نمیشن.',
  '# اگر متن نداری، `npm run story:timeline` خودش اسکلتشو میسازه.',
  '#',
  '',
].join('\n');
writeFileSync(join(dir, 'vo', 'script.txt'), script);

for (const d of ['content', 'assets/plates/hd', 'subtitles', 'audio', 'exports', 'stills']) {
  writeFileSync(join(dir, d, '.gitkeep'), '');
}

const readme = [
  `# ${title} — projects/${slug}`,
  '',
  '## ۱. ویس رو بذار',
  '',
  `فایل نریشن رو بریز تو \`projects/${slug}/vo/\` — نام پیشنهادی \`${L}.wav\``,
  '(wav / mp3 / m4a / aac / ogg / flac / opus / webm).',
  `متنش رو هم تو \`vo/script.txt\` بنویس: هر خط = یک صحنه.`,
  `برای نسخهٔ دوم زبان: \`vo/en.wav\` + \`vo/script.en.txt\` و اجرا با \`--lang en\`.`,
  '',
  '## ۲. بساز',
  '',
  '```bash',
  `npm run story:build  -- ${slug}        # تایم لاین + زیرنویس + میکس صدا`,
  `npm run story:stills -- ${slug}        # ۸ فریم مرور`,
  `npm run story:render -- ${slug} --fast # MP4 نهایی`,
  '```',
  '',
  '## ۳. تصویرها',
  '',
  `پلیتهای نقاشیشده رو بذار تو \`assets/plates/hd/\` با نام \`p01.jpg\`, \`p02.jpg\` …`,
  '(همون نامهایی که تو `content/scenes.js` نوشته شده). تا وقتی تصویر نذاری،',
  'رندر با گرادیان جایگزین کار میکنه ولی خروجی نهایی نیست.',
  '',
  'قوانین سبک: `style/STYLE.md` · جزئیات موتور: `engine/README.md`',
  '',
].join('\n');
writeFileSync(join(dir, 'README.md'), readme);

console.log(`ساخته شد: ${relative(ROOT, dir)}/`);
console.log(`ویس پروژه رو بذار تو: ${relative(ROOT, join(dir, 'vo'))}/`);
console.log(`متن نریشن:            ${relative(ROOT, join(dir, 'vo', 'script.txt'))}`);
console.log(`بعد: npm run story:build -- ${slug}`);
