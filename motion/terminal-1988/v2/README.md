# Terminal — two scenes, vector figures in a photographic airport

Built from the briefs of 2026-11-03 (concourse + passport control) and the
supplied character sheet. 37.0 s, 1080×1920, 30 fps, no audio, no text.

## What is here

| path | what |
|---|---|
| `src/index.html` | the whole film: plates, rig, faces, shots, timeline |
| `render.mjs` | `--sample` stills, or the full MP4 through Playwright → ffmpeg |
| `assets/plates/raw/` | the generated 9:16 plates, untouched |
| `assets/plates/sh/` | the same plates at 1080×1920, lightly sharpened |
| `assets/character-sheet.png` | the character sheet this design is locked to |
| `exports/terminal-scenes-1080p.mp4` | 37.0 s, H.264, 17 MB |
| `stills/` | eight review frames, one per shot |

## Design lock

Round white head, very large eyes, white body, heavy ink outline, thin limbs.
The man: dark-brown jacket with collar and zip, dark trousers, hair tuft,
black shoes, old brown suitcase. The officer: navy shirt, open white collar,
ink bob. The same `HIM` object is spread into every pose, so he cannot drift.

## The rig

`RIG` is a real skeleton in units where the feet are 0 and up is negative:
legs 390, torso 310, head 310, total ≈ 1035. Arms and legs are two-bone IK with
an analytic middle joint, so an elbow always bends instead of kinking. The hip
sits a full leg-length above the feet — the earlier version had the hip on the
floor, which made every figure a dwarf with splayed legs.

## Camera

Plates and figures share one homography (`withPlate`): zoom and pan are applied
to the plate image and to the characters together, so nobody slides over the
floor. The counter in `scene-09` (top edge at y ≈ 1492) is repainted over the
officer's lower body to occlude it — no clipping hack, the plate is the mask.

## Honest state

- Two scenes, not one: the briefs described one concourse scene and one
  passport-control scene, so they are stitched at 18.0 s.
- No audio, because neither brief asked for narration and the earlier VO does
  not match these two beats.
- The crowd in scene 1 is a layer of flat figures, not the hundreds of
  travellers the brief imagines; at this scale the difference is visible.
- The plates are AI renders, not photographs — the reference's look is a real
  photo of a real hospital room.
