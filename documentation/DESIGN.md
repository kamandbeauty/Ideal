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

## Missions

`MissionData` holds a single ordered chain, and `TownState.mission_progress()`
measures the current one from state that already exists (upgrade counters,
customers, unlocked businesses, completion):

| # | Mission | Goal | Reward |
| --- | --- | --- | --- |
| 1 | First upgrade | 1 upgrade | 250 coins |
| 2 | The roadside kitchen | open the restaurant | 400 coins |
| 3 | Level three | any business at level 3 | 600 coins |
| 4 | First manager | hire one manager | 800 coins |
| 5 | Specialise | buy any branch | 500 coins |
| 6 | Regulars | 500 customers served | 1,000 coins |
| 7 | Full house | all six businesses open | 2,000 coins |
| 8 | Complete stop | 100 % completion | 25 gems |

The HUD shows one mission pill with progress and a claim button; the step and
the counters are saved, and claiming is refused twice.

## Events

`TownEvents` defines short multipliers that keep the simulation deterministic:

| Event | Duration | Traffic | Income |
| --- | --- | --- | --- |
| Rush hour | 90 s | ×1.8 | ×1.0 |
| Holiday | 120 s | ×1.5 | ×1.2 |
| Rain | 90 s | ×0.6 | ×0.9 |
| Breakdown | 60 s | ×1.0 | ×0.75 |
| Local festival | 90 s | ×1.2 | ×1.3 |
| Power cut | 45 s | ×0.8 | ×0.8 |

One event runs at a time; `traffic()` and `net_per_minute()` apply the factors,
so capacity, customers, reputation and offline income all follow. The HUD shows
a timed chip and toasts the start and the end.

## Customer flow

Each unlocked business owns a `ServiceQueue` and up to ten visible customers in
total:

| Rule | Value |
| --- | --- |
| Service slots | `1 + floor((level - 1) * 0.75)`, capped at 4 |
| Line limit | slots + 2 (the next traveller drives past) |
| Service time | 2.5–9 s, so a slot turns over while you watch |
| Vehicle mix | car, SUV, pickup, truck, bus, camper × 10 paints |
| Ticket shown | `net_per_minute / served_per_minute` |

The flow is cosmetic: it never changes cash, and the "+amount" is the same money
the business already books.

## Staff and managers

`TownStaff` puts a real character on every plot:

| Who | Where | What they do |
| --- | --- | --- |
| Staff | at the door, facing the road | a two-handed work loop, small body bob |
| Manager | `manager_rank ≥ 1` | hi-vis vest, cap and clipboard; patrols the forecourt |

Managers also run the business. `AutoUpgrade` runs every five seconds:

1. Collect every upgrade a **managed** business could still buy (level,
   branch, manager rank).
2. Sort by price.
3. Buy the cheapest one that leaves `max(150, 90 s of income)` in the till.
4. Toast what happened and sparkle the building.

So a manager never spends the money the player is saving for the next business,
but an idle town keeps improving itself instead of standing still.

| Script | Role |
| --- | --- |
| `scripts/town/town_staff.gd` | staff and manager characters on every plot |
| `scripts/core/auto_upgrade.gd` | the manager's shopping rule and cash reserve |

## Art direction: retro 1950s

The chosen look (style B of the four studies in `documentation/design/styles/`):
cherry red and cream, chrome, turquoise and mustard, a neon tube on every roof
and a googie sign on every plot.

| Piece | Where it lives |
| --- | --- |
| Palette and material helpers | `scripts/town/retro_style.gd` |
| Repainted kit models | `assets/models/Textures/colormap-retro.png`, generated by `tools/recolor_colormap.py` |
| Awnings, roof neon, chrome skirting | `TownView._build_retro_features` |
| Googie pylon signs | `TownView._build_totem` |
| Double yellow centre line | `TownView._build_road` |
| Retro paint set for vehicles | `VehicleMesh.PAINTS` |

The atlas is recoloured, not replaced: every kit building keeps its UV layout and
detail, but its swatches are re-hued into the retro palette (pale tints become
cream and sand, saturated ramps become cherry, mustard, teal, dusty blue and
salmon). Re-run `python3 tools/recolor_colormap.py` to retune the town.

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
- **Visible growth** — `BusinessDecor` builds four prop stages per business from
  primitives (level 2 … 5). Stages pop in when the level reaches them, and the
  building itself grows 2.5 % per level. Examples: fuel pumps and a lit canopy
  (gas station), tables, awning, rooftop sign and a terrace (restaurant), crates,
  entrance canopy, lit shop window and an upper floor (store), tyre stack, lift,
  compressor and a service bay (workshop), parking bays, balcony rail, pool and a
  sign tower (motel), barrels, wash arch, brushes and a second arch (car wash).
- **Living town** — ten pedestrians walk the sidewalks with swinging legs and a
  slight bob, and every few seconds an unlocked business pops a floating `+N`.
- **Day and night** — `DayCycle` runs a 12-minute day, rotating the sun from
  sunrise to sunset and blending sky, fog, ambient and fill light. Emissive
  materials collected from totems, canopies, lamps, pools and signs switch on
  after sunset; a compiled list means night costs nothing extra per frame.
- **Camera** — a 39° isometric pitch, a 1.2 s intro pull-in from 38 to 30 units,
  quarter turns, pinch zoom, drag panning, and a pulsing selection ring. An
  upgrade leans the camera toward that plot for a moment, and completion pulls
  back to 40 units for the banner.
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
| `scripts/town/traffic.gd` | ten highway vehicles looping on the road |
| `scripts/town/customer_flow.gd` | customers: drive in, queue, get served, pay, leave |
| `scripts/town/vehicle_mesh.gd` | six vehicle silhouettes and ten paint variants |
| `scripts/town/person_mesh.gd` | the shared character rig and its walk/idle/carry poses |
| `scripts/town/town_staff.gd` | workers at every door and managers on patrol |
| `scripts/core/service_queue.gd` | capacity rule for the queue (slots, line, overflow) |
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
- The economy is statistical: the customer flow is presentation only, capped at
  ten vehicles on screen, so it never feeds back into income.
- Vehicles and people are boxes on pivots: one `StandardMaterial3D` per colour,
  no textures, no per-frame allocations in the queue step.

## Roadmap

1. **Vertical slice (this build)** — desert town, six businesses, three branches,
   managers, offline income, saving, FA/EN, smoke screenshots.
2. World map and the remaining four towns with their own scenery and business
   mixes.
3. Managers as characters with contracts and traits; staff for the workshop.
4. Missions, daily objectives and a first-time flow.
5. ~~Android export preset and a downloadable debug APK~~ (done: preset
   "Android APK", `.github/workflows/apk.yml`, rolling `roadstop-apk` release).
   Remaining: release signing/AAB and an on-device performance pass.

## Test coverage

`tests/run_tests.gd` runs eight suites headlessly:

- `test_localization` — both languages complete, placeholders substitute, every
  business/town/branch/manager rank is named.
- `test_business_data` — catalogue completeness, model files exist, plots unique,
  town table valid.
- `test_economy` — profit, upgrades, branch caps, manager efficiency, reputation,
  gems and the offline cap.
- `test_save` — round trip, rejected saves, clamping, unknown ids, file I/O and
  the backup fallback.
- `test_decor` — every decor stage exists and only uses real props.
- `test_missions_events` — the mission chain, rewards, event multipliers and the
  event catalogue.
- `test_customer_flow` — service slots, line overflow, promotion order and the
  vehicle catalogue.
- `test_auto_upgrade` — the manager's cheapest-first rule, the cash reserve and
  maxed businesses going quiet.
- `test_decor` — all four visual stages build for every business, lit props
  register their materials, and the day cycle's sun and phases are correct.
- `test_missions_events` — the chain runs from the first upgrade to a finished
  town, rewards pay once, every mission and event is translated, and event
  multipliers and timers behave.

`tools/smoke.gd` then boots the real scenes with a software renderer and captures
the menu (FA/EN), the town, the detail panel, a turned and a zoomed camera, the
offline report and the English HUD.
