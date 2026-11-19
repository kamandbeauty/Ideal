# Photo set — light grey wall, original floor, soft silhouette

Eight clothing shots for the shop. The wall behind the model is a soft light
grey; the floor and the model are the original photograph.

| What | Where |
| --- | --- |
| Originals (untouched) | [`source/`](source/) |
| Finished shots, 1:1 | [`edited/`](edited/) |
| Contact sheet | [`contact-sheet.jpg`](contact-sheet.jpg) |

## Output spec

* **Aspect ratio** 1:1 — the uploads were already square, nothing was cropped.
* **Sizes** 600×600 (seven files), 963×963 (`IMG_E2372-Copy.jpg`); the pixel
  size of the originals is kept, no resampling.
* **Wall** light grey, gentle backdrop gradient: RGB 229 at the top edge to
  239 just above the floor line, neutral, no cast shadow.
* **Floor** the floor of the original photo, **byte-identical** — the shop's
  own cream ceramic tile, including its natural reflection under the shoes.
  The wall/floor line is feathered over ~9 px.
* **Model** untouched: cloth, skin and shoes keep their own pixels.
* **Edges** come from the matte itself — a smooth sub-pixel edge, no binary
  mask, no cut-out staircase.
* **Format** JPEG, quality 96.

## How it is made (and why the edges are smooth)

1. The person's matte is the segmentation model's own soft alpha (0…1 per
   pixel, computed at 1024² and resampled) — **no** thresholding, hole
   filling, morphology or graph cut anywhere in the chain, because those
   quantise the outline and that is what produced the staircase edges.
2. The wall is painted with the continuous weight `clip((0.92 − α)/0.55)`:
   fully outside the person, zero on the person, a natural sub-pixel ramp in
   between.
3. Background that the matte swallowed (the narrow slot between the crossed
   legs) is recovered by comparing each pixel with the local background
   colour; that test is a smooth ramp too, and only large patches count, so a
   white shoe or a highlight is never painted over.
4. Nothing at or below the wall/floor line is ever touched, so the floor is
   guaranteed original.

## Verified per file

* floor (below the wall/floor line): max |Δ| = **0**
* the person (α > 0.9): max |Δ| = **0**
* background above the line: the grey gradient only (229…239)

## Numbers to turn (in the generator)

* `top=229`, `bottom=239` — the grey of the wall at the top edge / near the
  floor line.
