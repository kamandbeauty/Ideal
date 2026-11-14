# Roadstop Tycoon — رودستاپ تایکون

A hybrid idle tycoon for **Android**, built with **Godot 4.7**. You run a chain of
roadside towns: buy businesses, upgrade their capacity, speed and quality, hire
managers so they keep earning while you are away, and grow your reputation until
the next town on the highway unlocks.

بازی مدیریتی و آیدل برای اندروید: شهرک‌های بین‌راهی را می‌سازی، کسب‌وکارها را
ارتقا می‌دهی، مدیر استخدام می‌کنی و حتی وقتی بازی بسته است درآمد می‌گیری.

## What is in this vertical slice

- **One playable town** (desert) on a 3D isometric map: highway with moving cars,
  six plots, six businesses.
- **Six businesses** — gas station, restaurant, store, workshop, motel, car wash —
  each with 5 levels, 3 upgrade branches (capacity / speed / quality) and 4
  manager ranks.
- **Idle economy** — cash, reputation, gems, per-minute profit shown live.
- **Offline income** — managed businesses keep earning for up to 8 hours away,
  credited when you come back, with a report in the HUD.
- **Saving** — versioned JSON in `user://saves/`, a rolling backup, autosave every
  20 seconds, and a corrupted save falls back to the backup.
- **Persian and English** UI, switchable at any time, with Vazirmatn for proper
  right-to-left shaping.
- **Touch first** — tap to manage, drag to pan, pinch to zoom; Q/E, R and the mouse
  wheel work on desktop too.
- **Town completion meter** — opening all six businesses, maxing their levels and
  branches fills a bar; a full bar pays 25 gems, turns the meter gold and means
  the town is ready for the next stop.
- **Desert presentation** — textured sand with noise, dunes, scattered rocks and
  scrub, totem signs per business, three vehicle silhouettes with working wheels
  and lights, a vignette, and a short camera pull-in on load.

## Controls

| Action | Touch | Desktop |
| --- | --- | --- |
| Manage a business | tap the building or its card | click |
| Pan | drag with one finger | drag |
| Zoom | pinch | wheel |
| Rotate the view | camera buttons in the HUD | Q / E |
| Reset the view | — | R |
| Close / leave | system back | Esc |

## Run it

```bash
godot --path .                     # play
godot --headless --path . --script res://tests/run_tests.gd   # tests
xvfb-run godot --path . res://tools/smoke.tscn                # screenshots
```

The full-resolution screenshots land in `documentation/qa/` (ignored by git) and
CI publishes small stills to `documentation/qa/preview/` after every run, e.g.
[`07-town-en.jpg`](documentation/qa/preview/07-town-en.jpg). CI runs the same
three steps on every push; the `Project check` workflow is the authority on
whether the project imports and plays.

## Economy at a glance

```
served/min   = min(demand × traffic × (1 + 0.15 (level − 1)), capacity × throughput)
revenue/min  = served/min × price
profit/min   = max(0, revenue/min − upkeep/min)
net/min      = profit/min × (0.6 + 0.1 × manager_rank) × town income multiplier
```

Capacity grows 30 % per level and 20 % per capacity branch; speed adds 8 % per
level and 12 % per branch; quality adds 10 % per level and 15 % per branch and
raises the price. Upgrades cost ×1.75 per level, branches ×1.6 per step, manager
ranks ×2. A branch may never be ahead of the building's level.

## Screenshots

`documentation/qa/preview/` holds the stills CI captures on every push:

| File | Scene |
| --- | --- |
| `00-menu-fa.jpg` / `01-menu-en.jpg` | title screen in Persian and English |
| `02-town-fa.jpg` | the desert town, Persian HUD |
| `03-business-panel-fa.jpg` | detail panel with level meter and branches |
| `04-town-turned.jpg` / `05-town-close.jpg` | quarter turn and close zoom |
| `06-offline-fa.jpg` | offline income report |
| `07-town-en.jpg` | English HUD and panel |

## Project layout

| Path | Contents |
| --- | --- |
| `scripts/core/` | data (`business_data`, `town_data`), simulation (`business_state`, `town_state`), `save_manager`, autoloads (`app`, `game`, `sound`, `l10n`) |
| `scripts/town/` | 3D view, isometric camera, traffic, scene controller |
| `scripts/ui/` | HUD, detail panel, menu, theme |
| `tests/` | headless suites run by `tests/run_tests.gd` |
| `tools/smoke.gd` | scripted play-through that saves screenshots |
| `assets/` | Kenney models and audio, Vazirmatn font (see `ATTRIBUTION.md`) |
| `documentation/DESIGN.md` | design notes, numbers, save format, roadmap |

## Next milestones

1. World map for the five towns (forest, mountain, coast, highway) with
   reputation gates.
2. Managers as visible characters and timed contracts instead of a flat purchase.
3. Missions and a first-time flow.
4. Android export presets, signed APK/AAB, and an on-device performance pass.

Licences for the art, audio and fonts are listed in [`ATTRIBUTION.md`](ATTRIBUTION.md).
