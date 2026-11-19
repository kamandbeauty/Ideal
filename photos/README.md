# Photo set — light grey wall, original floor

Six clothing shots for the shop. The wall behind the model is a soft light
grey; the floor and the model are the original photographs.

| What | Where |
| --- | --- |
| Originals (as uploaded, untouched) | [`source/`](source/) |
| Finished shots, 1:1 | [`edited/`](edited/) |
| Contact sheet | [`contact-sheet.jpg`](contact-sheet.jpg) |

## Output spec

| file | source | output |
| --- | --- | --- |
| `IMG_2644.jpg` | 600×579 | 600×600 |
| `IMG_2645.jpg` | 1312×1157 | 1312×1312 |
| `IMG_2646.jpg` | 600×540 | 600×600 |
| `IMG_2648.jpg` | 600×603 | 603×603 |
| `IMG_2650.jpg` | 600×551 | 600×600 |
| `IMG_2652.jpg` | 600×520 | 600×600 |

* **1:1 by padding, never by cropping** — the short side is extended with a
  mirrored border, so the model stays whole and in place.
* **Wall** light grey with a gentle backdrop gradient: RGB 229 at the top
  edge to 239 just above the floor line; no cast shadow, no vignette.
* **Floor** original pixels, **byte-identical** (max |Δ| = 0 on every file) —
  the shop's own cream tiles are kept exactly as photographed.
* **Model** untouched: the wall colour is only applied outside the person.
* **Edges** sub-pixel and smooth — the matte is a continuous 0…1 field, no
  binary mask, no cut-out staircase.
* **Format** JPEG, quality 96.

## How it is made

1. Matte from the segmentation model (soft 0…1, computed at 1024²).
2. Colour split for this wall: the tiles are *warm* (b\* ≈ +5…+8) while the
   trousers and the shirt are *neutral* (b\* ≈ 0), so a smooth colour test
   separates cloth from wall and also frees the slots between the legs and
   between the arms and the body, where the net tends to fill the wall in.
3. Everything at or below the wall/floor line is copied through untouched.
4. Wall grey is painted with the continuous weight, then the wall/floor line
   is feathered over ~9 px.

## Known weak spot

`IMG_2652.jpg`: the soft wall shadow in the narrow slot between the shirt and
the arm is partly kept, so a faint grey smudge is visible there. Everything
else — and every other file — is clean.
