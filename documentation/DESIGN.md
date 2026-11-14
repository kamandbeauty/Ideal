# Ideal — Island City Builder: design notes

## The loop

1. A new city starts with 5,000 gold, a town hall at the centre of a 24×24
   island and no roads.
2. The player picks a structure at the bottom of the screen and taps a cell.
   Roads cost 30, homes 120–300, a workshop 220, parks and paving 10–90.
3. A building only works when one of its four sides touches a road that is
   connected — through other roads — to the town hall. Unconnected buildings
   hold nobody, earn nothing and cost 4 happiness each.
4. Connected homes add capacity; people move in over time and pay tax.
   Connected workshops add a flat income but a little pollution.
5. Goals at 20, 50, 100 and 200 people pay 400, 800, 1,500 and 2,500 gold.
6. The city is saved automatically every 20 seconds, on pause and on exit, and
   can be continued from the main menu.

## Numbers

| Thing | Value |
| --- | --- |
| Starting gold | 5,000 |
| Road | 30 |
| Small house | 120 → 4 people, +0.3 income |
| Town house | 170 → 7 people, +0.6 income |
| Apartment | 300 → 15 people, +1.4 income |
| Workshop | 220 → +2.2 income, pollution 2 |
| Lawn / trees / tall trees | 10 / 30 / 50 → +1 / +3 / +4.5 happiness |
| Pavement / fountain | 20 / 90 → +1.5 / +8 happiness |
| Refund on demolition | 50 % |
| Milestones | 20, 50, 100, 200 people |

Derived values, recomputed on every grid change (`CityState.recompute`):

```
capacity  = Σ population of connected buildings
income    = Σ income of connected buildings
happiness = clamp(45 + green bonuses − 4 × unconnected buildings − pollution, 0, 100)
income/s  = (income + population × 0.06) × (0.4 + 0.6 × happiness / 100)
```

Population grows at `0.9 × happiness/100` people per second towards capacity
when happiness is at least 45, and falls at 0.25 per second when the town is
unhappier than that. Capacity removed by demolition is shed at 0.6 per second.

## Road auto-tiling

Roads are one build tool, not four. When a road is placed, the view asks
`CityData.road_piece(mask)` for the piece that matches its neighbours:

| Neighbours | Piece |
| --- | --- |
| north + south, or east + west | straight |
| two adjacent sides | corner |
| three sides | T junction |
| four sides | crossroads |
| none / one | straight (a dead end) |

Masks use `N=1, E=2, S=4, W=8`. Each road model has a base mask measured from
the kit's geometry (`corner` opens south-west, `split` opens east/west/south),
and the chosen quarter-turn is the one that rotates the base mask onto the real
one. `tests/suites/test_roads.gd` checks all sixteen arrangements.

## Presentation

- Kenney's low-poly kit is drawn through two `GridMap`s (roads, everything
  else) built from a `MeshLibrary` generated at runtime, so a filled city is a
  handful of draw calls rather than hundreds of nodes.
- A soft sky, one shadow-casting sun, a grass ground box, a sand shore and a
  water plane; a thin grid overlay marks buildable cells.
- The camera orbits a focus point at a fixed 55° pitch: drag to pan, pinch or
  wheel to zoom (11–44), quarter-turn button to rotate.
- The ghost preview is drawn in place of the mouse cursor on desktop; on touch
  the tap commits immediately and a 50-deep undo stack takes it back.
- All text lives in `scripts/core/l10n.gd` with Persian and English entries.
  Vazirmatn is the default font and Persian switches the UI to RTL.

## Next steps

1. **Android delivery** — export preset, signed ARM64 APK built in CI, first
   run on a device.
2. **A reason to plan** — block-level land value, service radius (park, school),
   traffic on busy roads.
3. **More content** — second island with a river, larger buildings, milestones
   that unlock new structures instead of only paying gold.
4. **Presentation** — day/night cycle, citizens walking the streets, richer
   build effects.
5. **Balance pass** with real play-test data.
