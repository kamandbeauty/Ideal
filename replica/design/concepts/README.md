# Concept frames — direction locked 2026-11-01

Two generated frames, chosen by the user from two options each. **Reference only: nothing here is
shipped, traced or upscaled into the game.** They exist to point an artist at a look and to settle
arguments about tone before a single production asset is drawn.

| file | what it sets | chosen |
| --- | --- | --- |
| `01-home-kingdom.jpg` | the home/kingdom scene: muqarnas arch framing a tiled city at golden hour, a live construction site in the foreground | option 2 |
| `02-board.jpg` | the board screen: ivory plaster playfield, turquoise tile frame, lapis goal panel with muqarnas steps, jewelled pieces on it | option 1 |

## What is right (keep)

- **The frame is the brand.** A muqarnas arch around the scene, ivory plaster with gold rivets, a
  turquoise glazed tile edge. It reads Persian from a thumbnail and it is nothing like the original's
  European storybook castle.
- **Jewels, not candy.** Cabochons in gold bezels with specular highlights and contact shadows; the
  board reads expensive instead of flat.
- **Five silhouettes, five stones.** Round firouzeh, eight-point lapis shamse, carnelian shield,
  emerald octagon, pearl drop — you can tell them apart with the colour removed, which is the whole
  point of the shape rule in `art-direction.md` §3.
- **Obstacles are objects, not crates.** Inlaid chest, tulip in a glazed pot, copper samovar, frost
  creeping from a corner. This is the vocabulary the level designers will write levels with.
- **The build state is visible.** Scaffolding, cut stone, a wheelbarrow and a half-finished pool in
  the palace courtyard: the art already tells the player what the meta loop is.
- **Palette discipline.** Lapis dominates, turquoise accents, gold is a thin line, ivory carries the
  light areas. Nothing is neon, nothing is muddy.

## What an artist must fix before production (do not copy the frame)

1. **Grid truth.** The concept shows a 7-wide board with an inconsistent row count. Production is
   9×9 at 96 dp cells with a 2 dp inner bevel, and the playfield must be perfectly square on 19.5:9,
   16:9 and 4:3.
2. **Emblems.** The colour-blind code from §3 (three dots, star, drop, hexagon, crescent) is missing
   on most stones here. Every gem gets one, at 60% opacity, subtly lit.
3. **Damage states.** Each obstacle needs its 3–4 stages drawn as a set; the concept only shows the
   intact object. A player must read "one hit left" at a glance.
4. **HUD is a placeholder.** The lapis panel and ivory pill are empty on purpose. Real goal chips,
   move counter, currency pills and booster bar come from `components.md`, not from this frame.
5. **Contrast.** The gold-on-ivory pill in the top right is too low-contrast for a control; production
   uses `border-input` on `surface` (checked by `contrast.py`).
6. **Resolution and framing.** These are ~1k references. Production backgrounds are 2048×2732 layered
   parallax paintings, and the arch is a 9-slice frame so it can stretch to any aspect ratio.

## Provenance

Generated with an image model from the prompts recorded in this file's history; the selected frames
are kept in-repo as JPEG/PNG references under the project's own licence. They are **not** derived from
Royal Kingdom, Royal Match or any Dream Games asset. Per `art-direction.md` §12, no generated image
enters the shipped build: a human artist rebuilds every asset from these references.

## Next

`replica-design` is done. The style-sheet week (`art-direction.md` §14 step 2) turns these two frames
into: a gem sheet with emblems and states, an obstacle sheet with damage stages, a UI panel set at
9-slice, a character turnaround for the prince and the architect, and one kingdom paint-over. Then
`/replica-build` starts on the engine while the art runs in parallel.
