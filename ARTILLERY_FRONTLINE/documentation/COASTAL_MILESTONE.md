# Coastal Defense — first playable Android milestone

Original fixed-position combined-arms wave defense inspired by the supplied
references' presentation, not copied assets or UI artwork.

## Play
- Main menu: **DEPLOY / COASTAL DEFENSE**.
- The player never leaves the emplacement. Drag to traverse/elevate; defend
  against sea, flank and rear approaches across three escalating rounds.
- Desktop: left mouse/Space fire, right-drag aim, R reload, Q cycle weapon,
  Z zoom, F auto-fire, 1 repair, 2 airstrike, 3 helicopter, 4 airdrop.
- Android: drag battlefield to aim; right-side FIRE/ZOOM/WEAPON controls;
  bottom support, reload and rocket controls; top-left settings and AUTO.

## First scene contents
Twin heavy machine guns, 105 mm cannon, rocket pod, bazooka and autocannon;
animated infantry, tanks, transports, attack helicopter, fighter pass,
destructible landing craft, ocean, mountains, beach defenses and explosive
barrels. Airstrike is available from round one; helicopter and airdrop unlock
in later rounds. Supports use charges and independent cooldowns.

## Validation
```sh
godot --headless --path ARTILLERY_FRONTLINE --script res://tests/run_tests.gd
godot --path ARTILLERY_FRONTLINE --rendering-method gl_compatibility -- --coastal-smoke
```
CI checks include weapon viewmodel framing (no camera-covering barrel), fixed
camera position, multi-direction spawns, armor/aircraft damage, support cooldown
independence, full three-round completion and restart. Software-rendered CI is
not a physical Android device benchmark.
