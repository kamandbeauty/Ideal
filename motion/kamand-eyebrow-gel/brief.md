# KAMAND Eyebrow Lift Gel — commercial brief

Vertical 9:16 premium CGI-style motion graphics commercial. No humans, no face,
no skin, no hands, no body parts anywhere in the film.

## Deliverable

| Item | Value |
| --- | --- |
| Master | `exports/kamand-eyebrow-gel-4k.mp4` — 2160×3840, 24 fps, H.264 yuv420p (lanczos upscale from 1080×1920) |
| Light | `exports/kamand-eyebrow-gel-1080p.mp4` — 1080×1920 |
| Clean master | `exports/kamand-eyebrow-gel-4k-no-text.mp4` (no `.copy` and no `.steps` overlays) |
| Clean light | `exports/kamand-eyebrow-gel-1080p-no-text.mp4` |
| Editable source | `index.html` — deterministic `window.__MOTION__.seek(frame)` |
| Design canvas | 1080×1920 captured, upscaled to 2160×3840 in ffmpeg |
| Length | 662 frames / 24 fps ≈ 27.6 s |
| Audio | none (mux separately) |

## Beat sheet

| # | Scene | Frames | Visual | Camera | Persian copy |
| --- | --- | --- | --- | --- | --- |
| 1 | Product Reveal | 0–108 | Beige + emerald stage, real Kamand jar floating above a travertine pedestal, orbiting leaves and water droplets | push-in 1.20 → 1.03, product rises and scales in | ژل لیفت ابرو کمند / کاملاً گیاهی |
| 2 | Botanical Formula | 94–202 | Green leaves, extract droplets, glowing particles surrounding the product | slow push 1.02 → 1.20 | کاملاً گیاهی / بدون ریزش |
| 3 | No White Residue | 188–296 | Transparent gel ribbon spreading across glass, white powder specks dissolving, glossy clear finish | left-to-right reveal + pull back | بدون سفیدک |
| 4 | Natural Eyebrow Styling | 282–402 | 3D hair-strand eyebrow sculpture + spoolie brush (no face/skin), golden lift glow sweeping through the strands | lateral drift 1.04 → 1.16 | حالتدهی طبیعی و زیبا |
| 5 | How to Use | 388–544 | Floating jar + applicator, five numbered 3D glass cards, closed → open jar crossfade | gentle vertical drift | استفاده آسان، نتیجه جذاب + ۵ مرحله |
| 6 | Final Hero | 530–662 | Product on a stone pedestal, floating leaves, golden particles, cinematic light rays | slow lateral orbit 1.13 → 1.00 | «کمند؛ زیبایی طبیعی ابروها» |

Transitions: 14-frame linear crossfades with sum of opacities = 1, plus a soft
light sweep. Frame 0 and the last frame fade to black.

## Numbered steps (scene 5)

1. درِ محصول را باز کنید
2. مقدار کمی ژل با براش بردارید
3. تارها را رو به بالا و بیرون برس بزنید
4. ابروها را به فرم دلخواه حالت دهید
5. اجازه دهید ژل تثبیت شود

## Persian text supplied by the client

```
ژل لیفت ابرو کمند
کاملاً گیاهی
بدون سفیدک
بدون ریزش
حالتدهی طبیعی و زیبا
استفاده آسان، نتیجه جذاب
«کمند؛ زیبایی طبیعی ابروها»
```

All of these are rendered in Vazirmatn (bundled locally) and live inside
`.copy` elements only. For post-production, render with `--no-text` or open
`index.html?frame=120&noText=1` — this also hides the five numbered step cards, so the clean master has no baked text at all.

## Product assets — unchanged

Official product photography from
`https://kamandbeauty.com/shop/cosmetic/eyebrow-cosmetics/eyebrow-lift-gel/kamand-eyebrow-lift-gel/`:

| File | Use |
| --- | --- |
| `../../assets/kamand/product-open.jpg` | open jar + red spoolie, white studio background |
| `../../assets/kamand/product-closed.jpg` | closed jar + black spoolie |
| `../../assets/kamand/product-macro.jpg` | macro cap / logo photo (reference) |
| `../../assets/kamand/product-tube.jpg` | jar + tube photo (reference) |
| `assets/product-open.png`, `assets/product-closed.png` | transparent cutouts used in the scene |

`scripts/make-cutout.py` removes only the white studio background by flood
fill; the jar, gel, brush, `K` logo and `Kamand` typography are the original
pixels. No new package design, logo, or wordmark was created.

## QA checklist

- [x] 9:16 vertical, 2160×3840 master (upscaled), 24 fps
- [x] Six scenes with crossfades and a readable final frame
- [x] No humans, faces, skin, hands, or body parts in any plate
- [x] Original Kamand packaging/logo/typography preserved
- [x] All requested Persian lines + final tagline present
- [x] Five numbered step cards
- [x] Deterministic timeline (`seek(frame)` gives identical pixels)
- [x] Offline render (no CDN, no remote fonts, no network at frame time)
- [x] Text layer isolated for post-production
- [ ] Client review / final colour grade / sound design
- [ ] Optional upgrade to true realtime 3D (Blender or Remotion + Three.js)

## Known scope

This is a cinematic 2.5D motion graphic: AI-generated ultra-realistic CGI
plates + the real product cutout + frame-accurate camera, parallax, particle
and light animation. Approximated with a plate plus effect rather than a
realtime simulation: the fluid gel spread, the physical spoolie pass through
individual strands, per-strand hair lift, and the 3D camera orbit (implemented
as a lateral pan + scale). The beat sheet and `seek(frame)` contract are the
handoff spec for upgrading those shots to Blender or Remotion + Three.js.
