# Art direction: کاخ شازده (Prince's Palace)

Input: `replica/recon.md` (screen inventory + component list), `replica/design/tokens.json`.
This document is the brief an artist can work from, not a mood board. Everything here is **ours**:
the original's art, characters, gem designs, UI frames, fonts and copy are never traced, recoloured
or "referenced closely". Royal Kingdom's look is European storybook cartoon on saturated greens and
blues; ours is Persian royal on lapis and firouzeh. A player should be able to tell them apart from
a thumbnail.

## 1. Pillars

1. **Tilework, not toon.** Ornament is structural: arches, shamse stars, muqarnas steps and boteh
   paisley carry the identity, not cute faces on furniture.
2. **Jewel-lit.** The board is a jeweller's case: gems are cabochons in gold bezels, lit by one warm
   key light and a cool skylight rim. Depth comes from light, not from black outlines everywhere.
3. **Calm luxury.** Restraint beats sparkle. Gold is 10% of the frame, never 40%. No lens flares,
   no confetti storms, no gradients on gradients.
4. **Readable first.** Every gem, obstacle and goal must be identifiable in 120 ms at 96 px on a
   5-inch screen, in sunlight, for a colour-blind player. Beauty that fails this is a bug.

## 2. Palette

From `tokens.json` — the UI palette; the art palette is the same families, wider range.

| role | hex | used for | share |
| --- | --- | --- | --- |
| lapis night `bg` | `#0B1A2F` | modal scrim, deep backgrounds, board shadow | 35% |
| panel `surface` | `#14294A` | HUD panels, cards | 20% |
| raised `surface-raised` | `#1D3A61` | pressed/inner panels, tooltips | 8% |
| firouzeh `accent` | `#23B5B0` | primary CTA, progress fill, focus | 12% |
| firouzeh deep `accent-strong` | `#12857F` | pressed CTA, progress track end | 5% |
| gold `gold` | `#E0A93F` | rewards, chests, coins, chapter medals | 8% |
| ivory `text` | `#F7F2E6` | type, tile glaze highlights | 8% |
| muted `text-muted` | `#BFCBDB` | secondary type | 3% |
| terracotta `danger` | `#F0735A` / `#B33A24` | failure, "no moves" | 1% |
| pistachio `success` | `#58C98A` | task complete, chest opened | 1% |

Support hues for art only (not UI text): plaster `#EADFC8`, tile blue `#2C6FA6`, copper `#B4703C`,
pomegranate `#8E2C36`, saffron `#E8B84B`. Never let a support hue carry meaning on its own.

## 3. The five match items

Five types, five places in the value range, five outlines, so shape alone can carry a match. Each
also carries a small emblem inside the stone for colour-blind players (a second code, always on).

| # | name (fa) | stone | shape | base hue | emblem |
| --- | --- | --- | --- | --- | --- |
| 1 | فیروزه *Firouzeh* | turquoise cabochon, gold bezel | round, 3 veins | `#2EC4B6` | three dots |
| 2 | لاجورد *Lajvard* | lapis, cut | 8-point shamse | `#2F5FD0` | star |
| 3 | عقیق *Aqiq* | carnelian | shield / teardrop | `#D2553F` | drop |
| 4 | زمرد *Zomorrod* | emerald | octagon (emerald cut) | `#2E9E5B` | hexagon line |
| 5 | مروارید *Morvarid* | pearl | pear-shaped drop | `#EFE3C8` | crescent |

Rules: no two stones share a silhouette; the pearl is the only light stone (so the board always has
an obvious light value); each stone gets a specular dot top-right and a rim light from the left, all
at the same angle, or the board looks noisy. 96 px at 2× = 192 px source, 4 states: idle (2 frames
breathing, 12 fps), selected (scale 1.06 + gold rim), match-pop (6 frames), hint (pulse).

## 4. Board and obstacles

Board background: warm plaster with a tile border and a subtle geometric pattern at 6% opacity —
never a photo texture. Grid 9×9 (up to 10×10 later), 96 px cells, 2 px inner bevel.

Obstacles are Persian objects, not generic crates:

| obstacle | art | damage stages |
| --- | --- | --- |
| crate / جعبه | inlaid wood chest with turquoise studs | 3 + break |
| frost / شبنم | salted glaze creeping from edges | 3 (cracks) |
| ivy / پیچک | boteh vine with leaves | 3 (leaves stripped) |
| potion vial / شیشه | glass flask with glowing liquid | 3 |
| steam bomb / سماور | copper samovar with pressure gauge | 4 + blast |
| flower pot / گلدان | glazed ceramic pot, tulip inside | 2 |
| chain / زنجیر | forged iron links over a stone | 1 |
| magic seal / مُهر | wax seal with calligraphic glyph | 3, breaks only to power-ups |

Every obstacle must read as "this needs X hits" from a glance at its damage stage; no stage may be
distinguishable only by colour.

## 5. Power-ups and boosters

| power-up | our visual | created by |
| --- | --- | --- |
| Rocket (arrow) | winged arrow, gold fletching — points where it fires | 4 in a line |
| Spinner | dervish top with a spinning skirt | 4 in a square |
| Dynamite | brass bomb with a lit fuse and a shamse plate | L / T |
| Electro ball | glowing shamse star, arcs to neighbours | 5 in a line |
| Super electro | the same star, gold-inlaid, double radius | two electro balls |

In-game boosters, renamed so the copy is ours: **Mallet** (hammer, one tile), **Ram** (a row),
**Auger** (a column), **Whirlwind** (shuffle + colour merge), **Falcon** (drops three bombs on 3×3
areas). Pre-level boosters reuse the rocket / bomb / star art placed on the board at start.
Every power-up has a 8-frame creation build-up, a 10-frame trigger, and a screen-shake budget of
one shake per 400 ms maximum.

## 6. Kingdom scenes

One painted scene per chapter, 2× at 2048×2732 portrait, layered for parallax: sky → far city →
mid palace → playfield → foreground frame (arch). Chapter palettes:

1. **شهرِ فیروزه** — turquoise dome city, morning. Teaches the loop.
2. **باغِ لاجورد** — night garden, lanterns, water channels.
3. **کویرِ طلا** — desert caravanserai, sunset ochre.

~6–8 buildable tasks per district, each with: rubble state → scaffolding state → finished state,
plus a 12-frame build VFX (dust puff, tiles flying into place, a small sparkle on the gold) and a
5-second camera push-in when a district completes. Buildings are not grid-placed by the player
(the original's meta is a guided sequence too); the satisfaction comes from the animation quality,
so it gets the most polish per asset in the whole project.

## 7. Cast (ours)

| character | role | design notes |
| --- | --- | --- |
| شاهزاده کامران | the young prince the player builds for | 17, ink-blue qaba with firouzeh trim, no crown at first (he earns it), 5 expressions |
| بانو شیرین، معمار | the architect who explains tasks | 30s, drafting tube, saffron shawl, the "help" voice |
| وزیر دارا | comic antagonist inside the court | tall, over-dressed, gold everything, eyebrows do the acting |
| شاهزادهٔ رقیب | rival prince for leaderboard flavour later | mirror palette: copper and pomegranate |

Spine 4.2 rigs: idle loop, talk (3 mouth shapes), 4 gestures, blink; portraits at 3 sizes. No VO
in v1; all dialogue is written Persian with a clear speaker tag. Our copy is authored fresh — no
translated lines from the original.

## 8. UI skin

- Panels: ivory plaster face, 2 px turquoise tile border, gold rivets at corners, radius 22–28.
- Primary button: enamelled firouzeh (میناکاری) with a 1 px gold inner rule; pressed state sinks 2 px
  and darkens to `accent-strong`. Text `on-accent` at 17 dp, weight 800.
- Secondary button: ivory face, `text` ink, gold hairline.
- HUD currency pills: small gold-framed cabochon with the amount at 18 dp; lives pill shows a
  countdown ring that refills clockwise.
- Goal chips: single ceramic tile each, 44 px tall, goal icon + count, tick animation on complete.
- Modals: muqarnas arch crown (three steps), scrim `bg` at 72%, content panel `surface`.
- Every control ≥ 48 dp touch target; 16 dp safe margins; respects notch and RTL mirroring.

## 9. Type and numerals

`Vazirmatn` (UI, 500/700/800) and `Estedad` (display chapter titles, 900). Both SIL OFL — the fonts
ship with the game and are attributed in an in-game licenses screen. Minimum 13 dp for goal labels,
16 dp body, 34 dp counters. Persian numerals everywhere in gameplay; Latin digits only in the store
listing, crash logs and debug. Bidi care: "۱۲ از ۲۰" must not reorder at runtime — test with mixed
strings, never build numbers by concatenating digits into a translated sentence.

## 10. Motion

| event | duration / curve |
| --- | --- |
| swap | 140 ms, ease-out; invalid swap returns in 120 ms with a 3 px shake |
| fall | 220 ms per tile, 40 ms stagger, ease-in then ease-out |
| match pop | 6 frames @12 fps, scale 1→0.2 with a gold ring |
| power-up create | 8 frames, 220 ms, plus a 1-frame screen flash at 20% |
| power-up trigger | 10 frames; screen shake 4 px, 120 ms, max one per 400 ms |
| reward burst | 600 ms, staggered coins; no more than 12 particles per coin |
| screen transition | 280 ms arch-wipe (the arch shape carries between screens) |
| idle | 2-frame breathing on gems, 4 s period; board never fully static |

Everything is Spine or code-driven tween — no baked video, so it stays crisp at 3× density.

## 11. Audio

Santur, tar, ney and a soft frame drum; 60–70 BPM; nothing "orientalist" cliché (no generic
hijaz scales over darbuka). SFX: gem sounds map to five notes of a scale, so a cascade plays a
melody rather than noise; UI clicks are ceramic, not synthetic. Music: one loop per chapter (90 s,
seamless), one win sting, one fail sting, one chest fanfare. Licensed or commissioned — no library
tracks we cannot clear for worldwide store distribution.

## 12. Asset production rules

- Sources: Illustrator/Figma (vectors) and Spine projects; PNG exports at 2× only.
- Atlases ≤ 2048², one atlas per board screen; UI atlas ≤ 1024². ASTC 6×6 (Android), ASTC/PVRTC (iOS).
- Naming: `ch01_gem_firouzeh_idle@2x.png`, `ui_panel_arch_9s.png`, `spine/ch01_prince.skel`,
  `vfx_powerup_shamse_08.png`. No spaces, no non-ASCII in asset names (Persian names live in the
  content JSON, not in file names).
- 9-slice every panel; no stretched ornament; test at 3 aspect ratios (19.5:9, 16:9, 4:3 tablet).
- Every asset's source file goes to Artifactory or Git LFS — never only the PNG.
- AI-generated images are **concept references only**. Nothing generated goes into the shipped game
  without an artist rebuilding it; keep provenance notes with each shipped asset.

## 13. Quality gate (same numbers the build will be measured against)

60 fps on a 2021 mid-range Android (Redmi Note 10 class) with a 9×9 board and FX; 0 B/frame
allocation in the board loop; ≤150 draw calls on the board; base install ≤150 MB; cold start ≤3 s;
WCAG AA on every text/button pair (`contrast.py`, 19 pairs, 0 failures as of today); every screen
reviewed in Persian RTL; every gem distinguishable in a deuteranopia simulation.

## 14. Production plan and honest cost

1. **Style frame** — done 2026-11-01: two concepts chosen by the user
   (`replica/design/concepts/01-home-kingdom.jpg`, `02-board.jpg`) and reviewed in
   `replica/design/concepts/README.md`. Cheap, fast, not shippable.
2. **Style sheet** (artist, ~1 week): one gem sheet, one obstacle sheet, one UI panel set, one
   character turnaround, one kingdom paint-over — painted by hand over the chosen concept.
3. **Production** (≈3 months for chapter 1): 2 senior 2D artists + 1 UI artist + 1 Spine animator +
   art director part-time + audio. ≈350–450 polished assets.

Anything shorted here is visible next to the original in the first three seconds — and the
entrepreneur pass cannot save a game that looks indie on the store page.

## 15. Never

- Never trace, recolour or "close-reference" Royal Kingdom / Royal Match art, characters, gem
  designs, UI frames, icons or level layouts.
- Never ship their names, their cast, their copy, or anything that reads as the same universe.
- Never ship a font, music track or texture whose licence does not cover worldwide mobile
  distribution.
- Never let colour alone carry a game state.
