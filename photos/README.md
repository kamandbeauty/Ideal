# Photo set — store studio background

Eight clothing shots, re-shot on a white studio wall with a cream ceramic
tile floor for the shop.

| What | Where |
| --- | --- |
| Originals (untouched) | [`source/`](source/) |
| Finished shots, 1:1 | [`edited/`](edited/) |
| Contact sheet | [`contact-sheet.jpg`](contact-sheet.jpg) |

## Output spec

* **Aspect ratio** 1:1 — the eight uploads were already square, so nothing
  was cropped and no part of the model was cut off.
* **Sizes** 600×600 (seven files), 963×963 (`IMG_E2372-Copy.jpg`); pixel size
  and framing of the originals are kept, no resampling.
* **Wall** plain white, very slight studio falloff, no cast shadow.
* **Floor** cream ceramic tiles in one-point perspective (soft joints, light
  sheen), no shadow of the model on it.
* **Model** unchanged — see the check below.
* **Format** JPEG, quality 96.

## How the model was kept unchanged

The background was replaced, not re-rendered: the person was cut out with a
segmentation model plus a graph-cut refinement at the feet, and the original
pixels were composited over the new background. No generative model touched
the garment. Checked automatically on every file: for pixels that belong to
the person (alpha ≥ 0.999 and either dark or saturated — trousers, sweater,
skin) the difference to the original is **exactly 0** before JPEG encoding.

## Known soft spots

* `IMG_E2367-600x600.jpg` — the gap between the crossed legs is real
  background and now shows the white wall; the foot that points at the
  camera keeps a small contact shade.
* In a few frames a faint contact shade is still visible right under a
  sole. It can be painted out completely on request.
