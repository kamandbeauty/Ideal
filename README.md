# Roadstop Tycoon — رودستاپ تایکون

A hybrid idle tycoon for **Android**, built with **Godot 4.7**. You run a chain of
roadside towns: buy businesses, upgrade their capacity, speed and quality, hire
managers so they keep earning while you are away, and grow your reputation until
the next town on the highway unlocks.

بازی مدیریتی و آیدل برای اندروید: شهرک‌های بین‌راهی را می‌سازی، کسب‌وکارها را
ارتقا می‌دهی، مدیر استخدام می‌کنی و حتی وقتی بازی بسته است درآمد می‌گیری.

## What is in this vertical slice

- **Five towns on one world map** — desert, forest, mountain, coast and the
  central highway, each with its own ground and sky palette, its own traffic and
  income multipliers and its own reputation gate (0 / 600 / 1400 / 2600 / 4200).
  Everything you own is one profile; travelling saves the town you leave and the
  managed businesses in every town keep earning while you are away.
- **Six businesses per town** — gas station, restaurant, store, workshop, motel,
  car wash — each with 5 levels, 3 upgrade branches (capacity / speed / quality) and 4
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
- **Retro 1950s look** — the chosen art direction: cream walls under cherry and
  teal roofs, chrome skirting, candy-striped awnings, a neon tube along every
  roof edge, googie pylon signs, a double yellow line down the highway and a
  ten-colour retro car park. The kit models are repainted through a recoloured
  palette atlas, so the detail survives the palette change.
- **Visible growth** — every business adds real props at levels 2–5: pumps and a
  canopy, awnings and terraces, shop windows, a lift and tyres, a balcony and a
  pool, wash arches and brushes. Upgrading pops the new stage in with a sparkle
  and a short camera lean.
- **A living stop** — real customers drive in, park beside their business, get
  out, wait in a line that shrinks as service slots free up, hand over cash with
  a floating "+amount", walk back to their car and drive off. Ten highway
  vehicles in six silhouettes (car, SUV, pickup, truck, bus, camper) keep the
  road busy, and people who find the line full drive straight past.
- **Ten pedestrians** stroll the sidewalks with a leg and arm swing, and income
  still pops as floating coins.
- **Staff you can see** — every opened business has a worker at its door with a
  working loop, and a hired manager patrols the plot in a hi-vis vest and a cap.
- **Managers that act** — a managed business spends the takings on its own
  cheapest sensible upgrade (level, branch or rank) every few seconds, always
  keeping a cash reserve of about 90 seconds of income, and toasts what it
  bought. Turn a town idle and it keeps improving itself.
- **Guided missions** — a single next objective at the top of the screen, from
  the first upgrade to opening all six businesses and finishing the town, each
  paying cash or gems when claimed.
- **Roadside events** — rush hour, holidays, rain, breakdowns, a local festival
  and power cuts appear at random, last under two minutes and visibly change
  traffic and income while they run.
- **Day and night** — a 12-minute cycle moves the sun, sky, fog and ambient
  light; at dusk and night the totem boards, canopy strips and warm windows light
  up, one small interior light per open plot, and the completion sequence pulls
  the camera back.
- **A real soundtrack** — three synthesised loops (menu, day, night, cross-faded
  as the sun moves) and fifteen sound effects, all generated from scratch by
  `tools/build_audio.py`: no licensed audio, and the whole audio folder is 728 KB.
- **Haptics and juice** — every purchase, tip, gem and completion has its own
  sound, a short vibration and a floating number.
- **Tap to serve** — tapping the business you already have open pays a tip worth
  two seconds of its income, once every six seconds. Measured effect: the desert
  town finishes in 145 minutes with tips instead of 162 without.
- **The daily chest** — the first launch of the day pays a chest that scales with
  the town's income and grows by 35 % per consecutive day (capped at 7 days, a gem
  every third day). It is the reason to come back tomorrow.
- **Gems buy a rush hour** — five gems start a guaranteed holiday event (traffic
  ×1.5, income ×1.2 for two minutes), so the premium currency is a decision
  instead of a score.
- **Graphics presets** — low, medium and high change how many customers, walkers
  and night lights the town spends, plus a 30/60/free FPS cap, without touching
  the simulation. Also music, effects and vibration sliders, saved to
  `user://settings.cfg`.
- **A launcher icon** — a retro roadside pylon at night, generated once and
  derived to every Android size by `tools/build_icons.py`.

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
| `02-town-fa.jpg` | the desert town in the morning, Persian HUD |
| `03-business-panel-fa.jpg` | detail panel with level meter and branches |
| `04-town-dusk.jpg` / `05-town-night.jpg` | sunset and the lit night town |
| `06-offline-fa.jpg` | offline income report |
| `07-town-complete.jpg` | the completion cinematic and banner |
| `08-town-en.jpg` | English HUD and panel |
| `09-customers.jpg` | close-up of the queue and the service slots |
| `10-world-map.jpg` | the world map with the route and the locked towns |
| `11-staff.jpg` | staff at the door and a manager on patrol |
| `12-settings.jpg` | the settings sheet: volumes, vibration, graphics preset |
| `icon.png` | the launcher icon |

## Project layout

| Path | Contents |
| --- | --- |
| `scripts/core/` | data (`business_data`, `town_data`, `mission_data`), simulation (`business_state`, `town_state`, `profile`), `save_manager`, `daily_bonus`, `quality`, autoloads (`app`, `game`, `sound`, `l10n`) |
| `scripts/town/` | 3D view, isometric camera, traffic, customer flow, staff and managers, person and vehicle meshes, scene controller |
| `scripts/ui/` | HUD, detail panel, menu, world map, settings sheet, theme |
| `tests/` | headless suites run by `tests/run_tests.gd` |
| `tools/smoke.gd` | scripted play-through that saves screenshots |
| `tools/build_audio.py` | synthesises the music and every sound effect |
| `tools/build_icons.py` | derives the launcher icons from the source artwork |
| `tools/balance_report.py` | mirrors the economy and prints the play-through curve |
| `assets/` | Kenney models and audio, Vazirmatn font (see `ATTRIBUTION.md`) |
| `documentation/DESIGN.md` | design notes, numbers, save format, roadmap |

## Android build

`.github/workflows/apk.yml` builds a debug-signed arm64 APK (preset "Android APK",
package `com.roadstop.tycoon`, version 1.0.0). It runs on demand or when a commit
message contains `[apk]`:

```bash
gh workflow run apk.yml                # or: git commit -m "... [apk]"
```

The finished `RoadstopTycoon.apk` is published on the rolling `roadstop-apk`
release, so it downloads as a single file on a phone:

<https://github.com/kamandbeauty/Ideal/releases/tag/roadstop-apk>

To install: download the APK, allow "install unknown apps" for the browser or
file manager, open the file, and accept the Play Protect prompt (the build is
debug-signed, not from the Play Store). Every CI run also keeps the same file as
the `roadstop-apk` artifact.

## Next milestones

1. Time-limited manager contracts and traits instead of a flat purchase.
2. Release-signed AAB for the Play Store (the current build is debug-signed).
3. An on-device performance pass with a debug FPS panel.
4. Text scale, safe-area insets and the remaining items in
   [`documentation/REVIEW.md`](documentation/REVIEW.md).

Licences for the art, audio and fonts are listed in [`ATTRIBUTION.md`](ATTRIBUTION.md).
