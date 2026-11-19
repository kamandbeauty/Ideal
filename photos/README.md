# Photo set — white wall, original floor

Eight clothing shots for the shop: the wall behind the model is pure white,
everything else is the original photograph.

| What | Where |
| --- | --- |
| Originals (untouched) | [`source/`](source/) |
| Finished shots, 1:1 | [`edited/`](edited/) |
| Contact sheet | [`contact-sheet.jpg`](contact-sheet.jpg) |

## Output spec

* **Aspect ratio** 1:1 — the uploads were already square, nothing was
  cropped and no part of the model is cut off.
* **Sizes** 600×600 (seven files), 963×963 (`IMG_E2372-Copy.jpg`); the pixel
  size of the originals is kept, no resampling.
* **Wall** pure white: RGB 255/255/255 behind every background pixel, no
  cast shadow, no vignette.
* **Floor** the floor of the original photo, **not touched** — it is already
  the cream ceramic tile of the shop's floor, so it is kept pixel for pixel
  (its own reflection/shadow under the shoe included). The wall/floor line
  is feathered over a few pixels so the white does not cut into the tiles.
* **Model** untouched — see the check below.
* **Format** JPEG, quality 96.

## What is verified, per file

* Every pixel of the floor (below the wall/floor line) is **identical** to
  the original: max |Δ| = 0.
* Every pixel of the person (sweater, trousers, shoes, skin) is
  **identical** to the original: max |Δ| = 0.
* Background above the wall/floor line is 100 % pure white (255,255,255).

Nothing was regenerated with an image model; the only operation is
"background → white".
