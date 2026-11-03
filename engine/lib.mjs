/**
 * Shared helpers for the story engine (سبک رقص استراسبورگ).
 *
 * Every project lives in projects/<slug>/ and is described by config.json.
 * Nothing in here knows about a specific film; the film is data, the engine is
 * this folder. See engine/README.md.
 */
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { basename, dirname, extname, isAbsolute, join, relative, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

// CLI errors should read like instructions, not a Node stack trace.
function fail(err) {
  const e = err instanceof Error ? err : new Error(String(err));
  console.error(`\n❌ ${e.message}`);
  if (process.env.DEBUG) console.error(e.stack);
  process.exit(1);
}
process.on('uncaughtException', fail);
process.on('unhandledRejection', fail);

export const ENGINE = dirname(fileURLToPath(import.meta.url));
export const ROOT = resolve(ENGINE, '..');
export const FFMPEG = join(ROOT, 'node_modules', '@ffmpeg-installer', 'linux-x64', 'ffmpeg');
export const AUDIO_EXT = ['.wav', '.mp3', '.m4a', '.aac', '.ogg', '.opus', '.flac', '.webm'];

/** `--flag value`, `--flag`, and positional args. */
export function parseArgs(argv = process.argv.slice(2)) {
  const a = { _: [], flags: {} };
  for (let i = 0; i < argv.length; i++) {
    const t = argv[i];
    if (t.startsWith('--')) {
      const k = t.slice(2);
      const n = argv[i + 1];
      if (n !== undefined && !n.startsWith('--')) { a.flags[k] = n; i++; }
      else a.flags[k] = true;
    } else a._.push(t);
  }
  return a;
}

export function project(a) {
  const raw = a.flags.project || a._[0] || 'next';
  const dir = isAbsolute(raw) ? raw : raw.includes('/') ? resolve(ROOT, raw) : join(ROOT, 'projects', raw);
  const cfgFile = join(dir, 'config.json');
  if (!existsSync(cfgFile)) {
    throw new Error(`پروژه پیدا نشد: ${relative(ROOT, cfgFile)}\n` +
      `اول بسازش: npm run story:new -- <slug>   (یا از projects/next/ استفاده کن)`);
  }
  const config = JSON.parse(readFileSync(cfgFile, 'utf8'));
  return { dir, slug: config.slug || basename(dir), config };
}

export const langOf = (a, p) => a.flags.lang || p.config.lang || 'fa';

/** Resolve the narration file: --vo > config.vo[lang] > vo/<lang>.* > first audio in vo/. */
export function voPath(a, p, L) {
  if (a.flags.vo) {
    const f = isAbsolute(a.flags.vo) ? a.flags.vo : resolve(ROOT, a.flags.vo);
    if (!existsSync(f)) throw new Error(`فایل ویس پیدا نشد: ${f}`);
    return f;
  }
  const override = p.config.vo && p.config.vo[L];
  if (override) {
    const f = resolve(p.dir, override);
    if (!existsSync(f)) throw new Error(`config.vo.${L} اشاره میکنه به فایلی که نیست: ${f}`);
    return f;
  }
  const dir = join(p.dir, 'vo');
  const named = AUDIO_EXT.map((e) => join(dir, `${L}${e}`)).find((f) => existsSync(f));
  if (named) return named;
  const files = existsSync(dir)
    ? readdirSync(dir).filter((f) => AUDIO_EXT.includes(extname(f).toLowerCase())).sort()
    : [];
  if (files.length) return join(dir, files[0]);
  throw new Error(
    `هیچ فایل ویسی تو ${relative(ROOT, dir)}/ پیدا نشد.\n` +
    `ویس پروژهٔ جدید رو اونجا بذار (مثلاً fa.wav یا en.wav) و دوباره اجرا کن.`,
  );
}

/** Resolve the narration text: --script > vo/script.<lang>.txt > vo/script.txt > content/script.txt. */
export function scriptFile(a, p, L) {
  const candidates = a.flags.script
    ? [a.flags.script]
    : [join(p.dir, 'vo', `script.${L}.txt`), join(p.dir, 'vo', 'script.txt'), join(p.dir, 'content', 'script.txt')];
  for (const c of candidates) {
    const f = isAbsolute(c) ? c : resolve(ROOT, c);
    if (existsSync(f)) return { path: f, text: readFileSync(f, 'utf8') };
  }
  return { path: join(p.dir, 'vo', 'script.txt'), text: '' };
}

/** One non-empty, non-comment line = one scene of the film. */
export const scriptLines = (text) => text
  .split(/\r?\n/)
  .map((l) => l.replace(/\s+/g, ' ').trim())
  .filter((l) => l && !l.startsWith('#'));

export function ffmpeg() {
  if (!existsSync(FFMPEG)) {
    throw new Error('ffmpeg باندلشده پیدا نشد — اول `npm install` رو اجرا کن.');
  }
  return FFMPEG;
}

export function durationOf(file, ff) {
  const r = spawnSync(ff, ['-hide_banner', '-i', file], { encoding: 'utf8' });
  const m = `${r.stdout || ''}${r.stderr || ''}`.match(/Duration: (\d+):(\d+):([0-9.]+)/);
  if (!m) throw new Error(`نتونستم مدت صدا رو بخونم: ${file}`);
  return Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3]);
}

export async function loadJs(file, fallback = null) {
  if (!existsSync(file)) {
    if (fallback !== null) return fallback;
    throw new Error(`فایل لازم پیدا نشد: ${relative(ROOT, file)}\nاول تایم لاین رو بساز: npm run story:timeline -- <slug>`);
  }
  return import(`${pathToFileURL(file).href}?v=${Date.now()}`);
}

export function srtTime(t) {
  const h = Math.floor(t / 3600);
  const m = Math.floor((t % 3600) / 60);
  const s = Math.floor(t % 60);
  const ms = Math.round((t % 1) * 1000);
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')},${String(ms).padStart(3, '0')}`;
}

export function ensureProjectDirs(p) {
  return {
    vo: join(p.dir, 'vo'),
    content: join(p.dir, 'content'),
    plates: join(p.dir, 'assets', 'plates', 'hd'),
    subtitles: join(p.dir, 'subtitles'),
    audio: join(p.dir, 'audio'),
    exports: join(p.dir, 'exports'),
    stills: join(p.dir, 'stills'),
  };
}
