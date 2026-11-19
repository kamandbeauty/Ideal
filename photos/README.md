# Photo set — light grey studio wall, original floor

Eight clothing shots for the shop: the wall behind the model is a soft light
grey, the floor and the model are the original photograph, untouched.

| What | Where |
| --- | --- |
| Originals (untouched) | [`source/`](source/) |
| Finished shots, 1:1 | [`edited/`](edited/) |
| Contact sheet | [`contact-sheet.jpg`](contact-sheet.jpg) |

## Output spec

* **Aspect ratio** 1:1 — the uploads were already square, nothing was cropped.
* **Sizes** 600×600 (seven files), 963×963 (`IMG_E2372-Copy.jpg`); the pixel
  size of the originals is kept, no resampling.
* **Wall** light grey, a gentle backdrop gradient: RGB 229 at the top edge to
  239 just above the floor line (neutral, no colour cast), no cast shadow.
* **Floor** the floor of the original photo, **not touched** — the shop's own
  cream ceramic tile, pixel for pixel (its natural reflection/shade under the
  shoes included). The wall/floor line is feathered over ~9 px.
* **Model** untouched: the wall colour is only applied outside the person,
  and the space between the legs is cleaned too (see below).
* **Format** JPEG, quality 96.

## What is verified, per file

* Every pixel of the floor (below the wall/floor line): **identical** to the
  original, max |Δ| = 0.
* The person's cloth and skin (sweater, trousers, shoes, hands): **identical**
  to the original — the only change is a soft 1–2 px anti-aliasing at the
  silhouette edge, which is where the wall colour meets the cut-out.
* Above the wall/floor line every background pixel is the grey gradient, so
  no beige patch of the old wall is left — including the narrow slot between
  the crossed legs, which the cut-out mask used to swallow.

## Buttons to turn (in the generator)

* wall tones are the two numbers `top=229`, `bottom=239` — raise/lower them
  for a lighter/darker grey.
* the floor line comes from `studio_bg.detect_horizon`, per photo.
