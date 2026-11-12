# Phase 0 — Audit of the earlier project

What was in the repository before the conversion, and what became of it.
The earlier project was a coastal artillery defence game in the same folder
(`ARTILLERY_FRONTLINE/`), Godot 4.7.2, last commit `d83e311`.

## Reused, with changes

| Earlier system | What was kept | What changed |
| --- | --- | --- |
| Sound autoload (`audio_manager.gd`) | pooled one-shot players, separate buses, volume settings | rewritten around the new clip list; per-clip throttling so a horde cannot flood the mixer; looping beds started on request |
| Graphics autoload and frame monitor | quality tiers, render-scale governor that only reacts to sustained slow frames | tiers reduced to low/medium/high; new per-tier keys (corpse limit, fire count) |
| Save manager and profile | JSON save with temp-file write and one backup | new save file (`user://lastwall_v1.json`), new settings and career totals, type coercion against defaults |
| Pooled ray-swept bullets | the idea: no physics bodies, one ray per round per tick | rewritten as flat arrays with one MultiMesh for tracers (was one node per round); penetration added |
| Mounted weapon view model | per-barrel recoil, muzzle flashes, casings; the twin HMG model itself | cadence and ammunition moved into testable `WeaponState`; crosshair convergence; aim driven by `AimController`; since Phase 2 the eye rides on the gunner's own aiming frame and the gun's cradle turns with it |
| Effect pool | fixed pool of reusable emitters | new effect kinds (blood, gore, dust, sparks, breach smoke; in Phase 2 fireball, blast smoke and debris) |
| Material library | one shared material per surface type | UV-mapped textured materials bound by name to the generated level mesh |
| Persian/English text table and fonts | `Loc` pattern, Rajdhani and Vazirmatn | new text table for the new game |
| Test runner | dependency-free SceneTree runner with a JSON report | suites discovered automatically; every suite is new |
| CI workflow | verified engine download, import, suites, software-rendered run with screenshots, Android export, evidence committed back | retargeted to this branch; one workflow; APK and compatibility APK (the AAB build was dropped for now) |
| Sounds | `click`, `critical`, `impact`, `impact_flesh`, `impact_metal`, `reload`, `wind`, `music_theme` | generator folded into `tools/build_audio.py`. `explosion` and `rocket` were carried over at first and replaced by new syntheses in Phase 2 |

## Removed

| Area | Removed |
| --- | --- |
| Game code | `scripts/coastal`, `artillery`, `ballistics`, `combat`, `core`, `destruction`, `economy`, `enemy_ai`, `environments`, `missions`, `projectiles`, `progression`, `targeting`, `ui` (all rewritten or dropped) |
| Scenes and data | `scenes/core`, `scenes/battlefield`, `scenes/coastal`; `resources/ammunition`, `enemies`, `missions`, `upgrades`, `weapons` |
| Shaders | beach, ocean, terrain, crater, mountain, road, vegetation |
| Models | bazooka, mounted rocket, mounted cannon, mounted autocannon, soldier, landing craft, patrol boat, fighter, helicopter, hangar, vehicles, and all `.blend` sources. (The Phase 2 launcher is a new model, `tools/build_weapons.py`; the earlier shoulder launcher was looked at and not brought back.) |
| Other assets | radio voices, the earlier surface textures and sky, UI plate textures and menu key art, boat/ramp/splash/cannon sounds, converted soldier textures |
| Tools | model, texture and UI-texture generators, soldier import, studio renders, radio voice synthesis, the two smoke drivers |
| Documentation and packages | the earlier documentation and QA evidence, `delivery/` (earlier APK and AAB), the milestone documents in the repository root |

`tests/unit/test_project.gd` scans every script, scene and resource for the
earlier game's vocabulary and fails if any of it comes back.

## Kept as they were

- The folder name `ARTILLERY_FRONTLINE/`. The game does not depend on it; it
  can be renamed. Only the workflow file and these documents name it.
- The reference files in the repository root (screenshots, `.max`, `.dds`).
  The game does not use them.
