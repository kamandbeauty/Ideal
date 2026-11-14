# Roadstop Tycoon — design notes

Hybrid idle tycoon, isometric 3D, Godot 4.7, Android first, offline-first.
This file records what the vertical slice actually implements and the numbers it
runs on.

## The loop

1. A new town starts with **1,500 coins** and one open business: the gas station.
2. The player taps a business (or its card) to open the management panel: level,
   three upgrade branches, the manager slot and the live numbers.
3. Every business turns passing traffic into customers, limited by its capacity,
   and customers into coins. Reputation grows with every served customer.
4. Coins buy more businesses, levels and branches. Managers raise efficiency, so
   a managed business also earns while the game is closed.
5. Reputation opens gems at 100 / 300 / 700 / 1,500 and, later, the next towns on
   the highway.

## Businesses

Every business has the same skeleton so the UI can treat them uniformly:
`base_price`, `base_capacity`, `base_demand`, `base_upkeep`, plus one cost per
upgrade type. All six are defined in `scripts/core/business_data.gd`.

| Business | Unlock | Price/customer | Capacity | Demand/min | Upkeep/min | Upgrade | Branch | Manager |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Gas station | free | 30 | 6 | 10 | 30 | 850 | 480 | 900 |
| Restaurant | 1,400 | 40 | 5 | 9 | 36 | 980 | 520 | 1,000 |
| Store | 1,100 | 25 | 8 | 8 | 24 | 760 | 420 | 800 |
| Workshop | 2,000 | 60 | 3 | 5 | 45 | 1,250 | 620 | 1,200 |
| Motel | 3,500 | 80 | 4 | 4 | 60 | 1,800 | 900 | 1,600 |
| Car wash | 2,600 | 20 | 7 | 7 | 28 | 1,400 | 700 | 1,300 |

## Formulas

```
capacity   = base_capacity × (1 + 0.3 (level − 1)) × (1 + 0.2 capacity_branch)
throughput = 1 + 0.08 (level − 1) + 0.12 speed_branch
quality    = 1 + 0.10 (level − 1) + 0.15 quality_branch
price      = base_price × quality
upkeep/min = base_upkeep × (1 + 0.12 (level − 1))

served/min   = min(base_demand × traffic × (1 + 0.15 (level − 1)), capacity × throughput)
revenue/min  = served/min × price
profit/min   = max(0, revenue/min − upkeep/min)
efficiency   = 0.6 + 0.1 × manager_rank          # 60 % … 100 %
net/min      = profit/min × efficiency × town_income
```

Costs:

```
level upgrade  = base_upgrade × 1.75^(level − 1)
branch upgrade = base_branch × 1.6^(branch_level)
manager rank   = base_manager × 2.0^(rank)
```

Caps: 5 levels, 5 branch steps (a branch may not exceed the building level),
4 manager ranks. Town cost multipliers apply to every purchase.

## Offline income

- Only **managed** businesses keep earning while the game is closed:
  `offline_net/min = Σ net/min of unlocked businesses with a manager`.
- Every save stores `last_seen` (unix seconds). On load, `away = now − last_seen`,
  capped at **8 hours**, and paid at `offline_net/min × away/60 × 0.6`. The HUD
  shows the report once, with a Collect button.
- Managers therefore automate a business rather than merely boosting it, and a
  fresh player has to hire one before leaving the game idle.

## Completion

Each business contributes `0.5` for being open, `0.25 × (level−1)/4` for its
level and `0.25 × (capacity + speed + quality)/15` for its branches; the town's
completion is the average over its six businesses. `is_complete()` is
`completion() ≥ 0.999`, which needs all six businesses at level 5 with all three
branches maxed. The HUD shows a progress bar under the resource bar and
celebrates once when the town is finished, paying 25 gems and turning the meter
gold; the flag is saved, so the reward is paid once per town.

## Presentation

- **Lighting** — one shadow-casting warm sun, a cool sky fill, ACES tonemapping
  at 0.84 exposure with a small saturation lift, sky lighting at 0.46, and depth
  fog that fades the dunes.
- **Ground** — a 150×150 plane with a seamless sand noise texture, ring-shaped
  dunes at the horizon, and MultiMesh scatters of rocks, dry shrubs and trees
  that skip the road corridor and every plot.
- **Businesses** — a paved plot per business, the kit model scaled 2.4×, a
  roadside totem with an emissive board in the business colour, and level pips.
  Locked businesses show an empty lot with a pale board; buying in pops the
  building in with an eased scale tween.
- **Traffic** — eight vehicles in three silhouettes (car, van, truck) with
  spinning wheels, headlights and brake lights, each with its own speed, looping
  along the highway. Three more cars are parked at the plots and the workshop
  keeps a small stack of barrels.
- **Camera** — a 39° isometric pitch, a 1.2 s intro pull-in from 38 to 30 units,
  quarter turns, pinch zoom, drag panning, and a pulsing selection ring.
- **Interface** — a vignette behind the HUD, coloured card stripes, a five-step
  level meter in the detail panel, and Persian digits in Persian.

Everything stays inside the Compatibility renderer: no SSAO, SSIL, glow or
screen-space effects, so the POCO X5 Pro / 60 FPS target remains realistic.

## Reputation, gems and towns

- Reputation grows by `0.5 × served customers`.
- Town level = `1 + floor(reputation / 250)`.
- Gems: +5 at 100, 300, 700 and 1,500 reputation, once each.
- Five towns are defined in `scripts/core/town_data.gd` with their own traffic,
  income and cost multipliers and unlock reputation:

| Town | Traffic | Income | Cost | Reputation |
| --- | --- | --- | --- | --- |
| Desert | 1.00 | 1.00 | 1.00 | 0 |
| Forest | 0.85 | 1.20 | 1.10 | 600 |
| Mountain | 0.90 | 1.30 | 1.25 | 1,400 |
| Coast | 1.15 | 1.25 | 1.20 | 2,600 |
| Highway | 1.40 | 1.40 | 1.40 | 4,200 |

Only the desert town is playable in the slice; the others are data-ready for the
world map.

## Save format

`user://saves/profile_01.json`, with the previous write rotated to
`user://saves/backup_01.json`:

```json
{
  "version": 1,
  "town": "desert",
  "cash": 1234.5,
  "gems": 10,
  "reputation": 321.0,
  "customers": 812.0,
  "elapsed": 640.0,
  "gems_claimed": 2,
  "last_seen": 1763000000,
  "businesses": [
    {"id": "gas_station", "unlocked": true, "level": 3,
     "capacity": 1, "speed": 0, "quality": 2, "manager": 1,
     "customers": 400.0, "revenue": 1200.0}
  ]
}
```

Loading validates the version and the town id, drops unknown businesses, clamps
levels and branches into range, and re-opens the gas station if a save somehow
lost it. If the main file is unreadable, `backup_01.json` is used; if both fail a
new town starts.

## Scene and script map

| Path | Role |
| --- | --- |
| `scenes/main.tscn` → `scripts/main.gd` | menu ↔ town switching, owns the session |
| `scenes/ui/main_menu.tscn` → `scripts/ui/main_menu.gd` | title, new/continue, language |
| `scenes/town/town.tscn` → `scripts/town/town.gd` | simulation tick, input, autosave, HUD wiring |
| `scripts/town/town_view.gd` | ground, road, plots, buildings, selection ring, tap picking |
| `scripts/town/traffic.gd` | cosmetic cars looping on the highway |
| `scripts/town/isometric_camera.gd` | fixed pitch, quarter turns, pinch/wheel zoom, panning |
| `scripts/ui/town_hud.gd` | resource bar, business cards, detail panel, offline report |
| `scripts/core/game.gd` (autoload) | current town, save/continue, offline claim |
| `scripts/core/save_manager.gd` | file I/O, backup rotation, validation |
| `scripts/core/l10n.gd` | every string in Persian and English |

## Performance notes

- Verified against a **POCO X5 Pro / 60 FPS** target rather than a desktop.
- Compatibility renderer (`gl_compatibility`), no SSAO/SSIL, one shadow-casting
  directional light, simple box cars, six buildings, no per-frame allocations in
  the simulation loop.
- The economy is statistical: traffic is not simulated per customer, so more cars
  never cost more CPU.

## Roadmap

1. **Vertical slice (this build)** — desert town, six businesses, three branches,
   managers, offline income, saving, FA/EN, smoke screenshots.
2. World map and the remaining four towns with their own scenery and business
   mixes.
3. Managers as characters with contracts and traits; staff for the workshop.
4. Missions, daily objectives and a first-time flow.
5. Android export presets, signed APK/AAB and an on-device performance pass.

## Test coverage

`tests/run_tests.gd` runs four suites headlessly:

- `test_localization` — both languages complete, placeholders substitute, every
  business/town/branch/manager rank is named.
- `test_business_data` — catalogue completeness, model files exist, plots unique,
  town table valid.
- `test_economy` — profit, upgrades, branch caps, manager efficiency, reputation,
  gems and the offline cap.
- `test_save` — round trip, rejected saves, clamping, unknown ids, file I/O and
  the backup fallback.

`tools/smoke.gd` then boots the real scenes with a software renderer and captures
the menu (FA/EN), the town, the detail panel, a turned and a zoomed camera, the
offline report and the English HUD.
