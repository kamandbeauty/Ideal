# Artillery Frontline — Coastal Defense Milestone

First-person mounted-weapon coastal defense scene. Original procedural models,
materials, audio, UI artwork and animation; no proprietary reference assets.

## Play
- Main menu: **DEPLOY / COASTAL DEFENSE**.
- Desktop: drag to aim, hold Space or left mouse to fire, R reload, Q cycle
  weapon, Z zoom, 1 repair, 2 airstrike, 3 helicopter support, 4 airdrop.
- Android: drag battlefield to aim; right-side FIRE, zoom, weapon, reload and
  bottom support buttons; top-left settings and AUTO toggle.

## Validation
```sh
godot --headless --path ARTILLERY_FRONTLINE --script res://tests/run_tests.gd
godot --path ARTILLERY_FRONTLINE --rendering-method gl_compatibility -- --coastal-smoke
```
The smoke driver captures desktop stills and exercises aiming, manual/automatic
fire, reload, rocket selection, explosions and support. It is software-rendered
CI evidence, not Android device certification.
