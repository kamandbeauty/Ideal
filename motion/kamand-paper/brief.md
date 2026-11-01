# KAMAND — paper kinetic reel (30 s)

**Third motion graphic.** Built to match the visual language of the reference
reel / screenshots: warm cream "paper" background, one sweeping pale-grey arc,
faint grid, barcode, a small `HD · KAMAND · MOTION 03` watermark, a thin
orange progress line, **huge bold Persian typography in near-black with one
word in vivid orange**, a white rounded product card, a 3D kraft gift box with
an orange satin ribbon, and a rounded orange CTA pill. Fast cuts, elastic
pop-ins, mask reveals, zoom punches, 3D box rotation and beat-synced pulses.

Reference study: `reference/reel-DfNkAVNNVBu.md` and the two screenshots the
client attached. **No humans, faces, hands, live action or cartoon
characters.** Original KAMAND packaging/logo used unchanged (official product
cutouts, only the white studio background removed).

## Deliverables

| File | Value |
| --- | --- |
| `exports/kamand-paper-4k.mp4` | 2160×3840, 24 fps, H.264 + AAC |
| `exports/kamand-paper-1080p.mp4` | 1080×1920, same audio |
| `index.html` | editable deterministic scene (`window.__MOTION__.seek(frame)`) |
| `audio/mix.wav` | 30.5 s mix (5 Persian VO lines + 120 BPM electronic bed) |
| `stills/s1.jpg … s8.jpg`, `stills/contact-sheet.jpg` | review frames |
| `assets/box.png` | transparent cutout of the generated 3D gift box |
| `assets/box-raw.jpg` | original AI-generated plate (provenance) |

## Timeline (720 frames @ 24 fps = 30 s)

| Beat | Time | Frames | Content |
| --- | --- | --- | --- |
| 1 — Hook | 0–5 s | 0–120 | «ابروهات هنوز» → giant orange «سرکشن؟!» crashes in with elastic stretch/skew, sub line «هر کدوم یه طرف میرن؟» |
| 2 — Name card | 5–10 s | 120–240 | «اسمش» + white card slides in: «ژل لیفت ابرو کمند» / «۳۰ میل · گیاهی · بدون سفیدک» / «برای ● ابروهای تو», then «یه ژل کمند» |
| 3 — Gift box | 10–15 s | 240–360 | 3D kraft box drops in with `rotateY`, product rises out of it, «کاملاً گیاهی» (orange word), orange pill «HERBAL 100%» |
| 4 — No residue | 15–20 s | 360–480 | «بدون سفیدک» with white powder specks dissolving into a clear ripple, then stable bold «بدون ریزش» + «شفاف و تمیز · CLEAR» |
| 5 — 3 steps | 20–25 s | 480–600 | «حالتدهی طبیعی» / «فقط ۳ قدم», 52 animated hair strands align into a groomed arch while a spoolie brush sweeps through, three numbered pills «تمیز و خشک / برس بزن / فرم بده» |
| 6 — Final | 25–30 s | 600–720 | «ابروهای مرتب، بدون دردسر!» + slogan «کمند؛ زیبایی طبیعی، هر روز!», box + product inside a thin orange ring, CTA pill «همین حالا · KAMAND» |

Cut transitions at every 5 s: 9-frame cream flash + diagonal orange/grey
wipe. 120 BPM beat = 12 frames; words pulse on the beat.

## Typography / palette

- **Display:** Estedad 900/800 (modern Persian, same family used in
  `kamand-eye`), **supporting:** Vazirmatn 400/600/700. All local `woff2`.
- Cream `#f7f5ef` · ink `#1c1c1a` · orange `#ff5a1f` · grey arc `#e6e4dc`.
- Short, bold, highly readable Persian lines, **no diacritics** on display
  type, no random/misspelled text. Small Latin labels (`HERBAL`, `CLEAR`,
  `KAMAND`) are editorial accents, not a new logo.

## Audio

5 Persian voiceover lines reused from the `kamand-eye` fallback TTS library,
time-stretched (`atempo 1.12`) and scheduled at 0.35 / 10.30 / 15.30 /
18.20 / 25.00 s, over a clean 120 BPM electronic bed (kick, claps, hats,
plucked bass, warm pad, impacts, risers, end shimmer) with ~55% ducking under
speech. `audio/make-audio.py` rebuilds it.

The `nimaone/persian_tts` backend remains wired in `third_party/`; its HF
weights are still unavailable in this sandbox (see
`third_party/persian_tts/model/README.md`), so this film also ships with the
`voice-00` fallback voice.

## Technical

- Design/capture 1080×1920, lanczos+unsharp upscale to 2160×3840 in ffmpeg
  (source box plate is 768×1376 → upscaled 4K, not native 4K detail).
- Deterministic `seek(frame)`: no `setTimeout`, no live `rAF`, no
  `Math.random()` during render, no remote assets.
- Bundled Chromium + ffmpeg toolchain, no system packages or CDN downloads.
- Audio AAC 192 kbps, mono 24 kHz source, muxed with `-shortest`.

## Commands

```bash
npm run kamand-paper:audio
npm run kamand-paper:sample
npm run kamand-paper:render
```

## Honest scope

Fully animated 2D/2.5D kinetic typography: text, SVG strands/brush/arcs/grid,
CSS 3D box turns, an AI-generated 3D gift-box plate and the real product
cutout. Not a realtime 3D fluid/hair simulation. Music is synthesized and VO
is TTS — both swappable in post without changing the timeline.
