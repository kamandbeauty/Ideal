# Ideal — Island Watch: design notes

## The loop

1. Land on the island. 220 gold, a core at 20 integrity and nine empty build
   pads along a winding path.
2. Between waves there is a countdown (15 s before the first wave, 9 s after
   that). Towers can be bought and upgraded at any time.
3. A wave spawns groups of enemies at the portal. Every enemy that reaches the
   core takes integrity away; every kill pays gold.
4. Clearing a wave pays a reward and starts the next countdown. Ten waves, with
   a boss on the fifth and the tenth; clearing the tenth wins the run.
5. Losing all core integrity ends the run. The best wave reached is stored in
   `user://settings.cfg`.

## Economy

| Item | Value |
| --- | --- |
| Starting gold | 220 |
| Wave reward | 30 + 10 × wave |
| Early start bonus | 2 gold per remaining second |
| Sell refund | 60 % of everything invested |

## Towers

| Tower | Build | L2 | L3 | Damage 1/2/3 | Range 1/2/3 | Shots per second 1/2/3 |
| --- | --- | --- | --- | --- | --- | --- |
| Sentry | 60 | 80 | 130 | 10 / 17 / 27 | 7 / 8 / 9 | 1.4 / 1.6 / 1.8 |
| Cannon | 110 | 130 | 190 | 34 / 52 / 82 | 6.5 / 7 / 7.5 | 0.6 / 0.6 / 0.7 |
| Frost | 90 | 100 | 150 | 5 / 8 / 12 | 6 / 6.6 / 7.2 | 0.7 / 0.7 / 0.8 |

- **Sentry** fires fast homing bolts at a single target.
- **Cannon** lobs shells with splash damage (2.6 → 3.4 radius).
- **Frost** damages and slows everything in range for 1.6 → 2.2 s (40 → 60 %).

Towers scale up 7 % per level, and three pips on the base show the level.

## Enemies

| Enemy | Health | Speed | Gold | Core damage |
| --- | --- | --- | --- | --- |
| Grunt | 46 | 2.1 | 7 | 1 |
| Runner | 28 | 4.3 | 6 | 1 |
| Tank | 190 | 1.35 | 22 | 3 |
| Boss | 950 | 1.1 | 120 | 8 |

## Waves

`WaveData` builds each wave from one formula:

- grunts: `3 + wave`, interval `max(0.4, 0.95 − 0.05 × wave)`
- runners from wave 2: `1 + floor(0.8 × wave)`
- tanks from wave 4: `1 + floor((wave − 4) / 2)`
- boss on every fifth wave
- reward `30 + 10 × wave`

Enemy totals run 4, 6, 9, 12, 15, 16, 18, 21, 23, 26. The formula is the single
place to rebalance difficulty, and `tests/suites/test_wave_data.gd` guards its
shape.

## Presentation

- Low-poly island generated in code (`Battlefield`): box ground, sand path,
  cone trees, sphere rocks, a crystal core, a portal, a tinted directional sun,
  fog and a deep-blue sea plane. No imported art is needed to run the game.
- Every string lives in `scripts/core/l10n.gd` with a Persian and an English
  entry; `L10n.is_complete()` and the localization suite keep it honest.
- Vazirmatn (SIL OFL, see `assets/fonts/OFL.txt`) is the default font so the
  Persian text is shaped and rendered properly. Persian switches the whole UI
  to right-to-left layout.
- HUD: resources on top, contextual panel at the bottom (tower choice, upgrade,
  sell), wave status and the early-start button on the left. Large touch
  targets, designed for 16:9 and 20:9 landscape.

## Next steps

1. **Audio** — turret shots, impacts, wave horn, UI clicks; a small mixer.
2. **Save/progress** — stars per map, unlocked tower tiers, persisted runs.
3. **More maps** — a second and third island (fork `LevelData` into a resource).
4. **Android delivery** — export preset, signed ARM64 APK built in CI, and the
   first run on a real device.
5. **Balance pass** with play-test data from the first device session.
