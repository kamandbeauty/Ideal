# KAMAND EYE — 45 s Persian kinetic typography commercial

**Name:** `kamand eye` · **Duration:** 45 s · **Format:** vertical 9:16 ·
**Resolution:** 4K (2160×3840 master) · **Language:** Persian (Iranian Farsi)

Premium, modern, fully animated social-media motion-graphics ad. No real
people, no faces, no hands, no live action, no cartoon characters. Persian
kinetic typography is the hero: words crash, stretch, shake, split, bounce,
mask-reveal and converge on the beat.

## Deliverables

| File | Value |
| --- | --- |
| `exports/kamand-eye-4k.mp4` | 2160×3840, 24 fps, H.264 + AAC, with voiceover & music |
| `exports/kamand-eye-1080p.mp4` | 1080×1920 light version, same audio |
| `index.html` | editable deterministic scene (`window.__MOTION__.seek(frame)`) |
| `audio/mix.wav` | final 45.5 s mono mix (VO + music + SFX) |
| `audio/vo/` | 10 original Persian TTS clips |
| `audio/vo-script.md` | diacritized voiceover script + timecodes |
| `stills/s1.jpg … s10.jpg`, `stills/contact-sheet.jpg` | review frames |

## Storyboard / timeline (1080 frames @ 24 fps)

| Scene | Time | Frames | Visual | On-screen text | Voiceover |
| --- | --- | --- | --- | --- | --- |
| 1 — Hook | 0–5 s | 0–120 | dark stage, giant «ابروهات؟!» crashes, stretches/shakes, splits into two clipped halves, three words fly in from different directions, then freeze | «ابروهات؟!» «نامرتب؟» «بدحالت؟» «سرکش؟!» | «اَبْروهات هَنوز هَر کُدوم یِه طَرَف میرَن؟!» |
| 2 — Solution | 5–12 s | 120–288 | scattered words freeze, emerald liquid wave sweeps, mask-reveal text, product enters with `rotateY` 3D turn + gloss sweep | «وقت یه تغییر قشنگه!» | «دیگِه وَقْتِشِه یِه فِکری بِه حالِشون بِکُنی!» |
| 3 — Benefits | 12–25 s | 288–600 | B1 botanical leaves grow around the word; B2 white powder specks dissolve into a clear liquid ripple; B3 bold stable type with two green sine waves | «کاملاً گیاهی» «بدون سفیدک» «بدون ریزش» | 3 short VO lines |
| 4 — How to use | 25–37 s | 600–888 | 74 animated SVG hair strands gradually align into a groomed arch, a stylized spoolie brush travels through them, 4 numbered glass step cards | «۱. ابروها رو تمیز و خشک کن» … «۴. فرم دلخواهت رو بساز!» | 4 step VO lines |
| 5 — Final | 37–45 s | 888–1080 | 10 word chips converge to center, product on a stone pedestal, leaves + gold particles, three text lines, clean gold-ring logo reveal | «ابروهای مرتب، بدون دردسر!» «ژل لیفت ابرو کمند» «کمند؛ زیبایی طبیعی، هر روز!» | final slogan VO |

Fast transitions: 9-frame bar wipes + light sweep + beat flash at every scene
boundary. 120 BPM beat = 12 frames; words pulse on the beat.

## Voiceover & audio

- **TTS backend (requested):** `nimaone/persian_tts` (پارسیگو) — vendored in
  `third_party/persian_tts/`, wired via `audio/generate-vo-persian-tts.py`
  using its female reference voice `female_narration.wav`. Its ONNX weights
  are hosted on HuggingFace and are **not** in Git; `model/README.md` has the
  one-time `hf download` command. See `SOURCE.md` for licensing (the base
  model is CC-BY-NC-4.0 — check commercial use before publishing).
- **Shipped voice:** because `huggingface.co` is unreachable from this build
  sandbox, the delivered MP4s use the Arena `add_voice` Persian female voice
  `voice-00` (`fa`) as a fallback — warm/energetic advertising tone. Running
  the two commands above swaps in `persian_tts` without changing the timeline.
- **10 clips**, diacritized for correct pronunciation. Full script with
  tashkil lives in `audio/vo-script.md`; on-screen display text has **no**
  unnecessary diacritics.
- `audio/make-audio.py` applies pitch-preserving `atempo` (1.12 general,
  1.20 tutorial), schedules each line to its scene, synthesizes a 120 BPM
  electronic bed (four-on-the-floor kick, claps, 16th hats, plucked bass,
  Am–F–C–G pads, arpeggio), adds impacts/risers/end signature, ducks music
  ~55% under speech, and writes `mix.wav`.
- VO starts: 0.45 / 5.25 / 12.40 / 16.40 / 20.40 / 25.25 / 28.10 / 30.70 /
  35.00 / 37.60 s — aligned with the matching text animations.

## Typography

- **Display:** Estedad 900 / 800 (modern Persian, similar in spirit to Peyda
  ExtraBold / Morabba). Peyda and Morabba were not obtainable from the allowed
  package sources, so a comparable premium modern Persian face was bundled
  locally via `@fontsource/estedad`.
- **Supporting:** Vazirmatn 400/600/700.
- All fonts are local `woff2` (no CDN, no network at render time).
- No diacritics on large display type, no random or misspelled Persian text,
  short bold highly readable lines.

## Product branding

Official KAMAND photography from the brand site is used unchanged: the white
round jar, `K Kamand` cap logo, clear gel and red spoolie. Only the white
studio background was removed (`scripts/make-cutout.py`). No new package,
logo or wordmark was invented.

## Technical

- Design/capture canvas 1080×1920, `deviceScaleFactor=1`, lanczos+unsharp
  upscale to 2160×3840 in ffmpeg (source CGI plates are 768×1376, so this is
  an upscaled 4K master, not native 4K detail).
- Deterministic `seek(frame)` timeline: no `setTimeout`, no live `rAF`, no
  `Math.random()` during render, no remote assets.
- Bundled toolchain: `@sparticuz/chromium` + `playwright-core` +
  `@ffmpeg-installer/linux-x64` — no system packages or CDN downloads.
- Audio: AAC 192 kbps, mono 24 kHz source, muxed with `-shortest`.

## Commands

```bash
npm install
python3 -m pip install -r requirements-persian-tts.txt
npm run kamand-eye:vo:persian-tts   # needs the ONNX weights once
npm run kamand-eye:audio        # rebuild mix.wav
npm run kamand-eye:sample       # 10 review stills
npm run kamand-eye:render       # 1080p + 4K MP4 with audio
python3 scripts/make-contact-sheet.py --dir motion/kamand-eye/stills \
    --cols 5 --rows 2 --labels-file motion/kamand-eye/stills/labels.txt
```

## Honest scope

This is a fully animated 2D/2.5D kinetic-typography film: typography, SVG
waves/strands/brush, CSS 3D product turns, AI-generated CGI plates and the
real product cutout. It is **not** a realtime 3D fluid/hair simulation or a
true 3D camera orbit. The music bed is programmatically synthesized (not a
licensed production track) and the voiceover is TTS, not a studio recording —
both can be swapped in post without touching the video timeline. The `seek()`
contract and VO timecodes are the handoff spec for those upgrades.
