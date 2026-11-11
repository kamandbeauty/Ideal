# LAST WALL: Zombie Siege

First-person wall-defence shooter. Godot 4.7.2, mobile renderer, landscape,
offline. Persian and English.

## The game

You man a twin heavy machine gun on a bastion of the city wall, with an RPG
launcher and a belt of hand grenades beside you. In front of you is the gate
court: the city gate in the right wall arm, a patched breach in the left one,
and beyond the court the ruined avenue the horde comes down.

- Zombies walk the streets, cross the court and take a place at the gate or
  at the wall. There they swing, and every blow costs gate or wall health.
- When the gate falls, they stop attacking it and run through. Each one
  that gets inside tears a chunk out of the wall's health.
- When the wall's health reaches zero the wall is breached and the match
  is lost. Survive all eight waves and the wall holds.

### The horde

| Kind | What it is | How to deal with it |
| --- | --- | --- |
| Walker | the rank and file: slow, three rounds to the body (four in the late waves) | sweep them; a rocket or grenade clears a knot of them |
| Runner | from wave 2: lean, more than twice as fast, strikes often | two rounds to the body or one to the head; they reach the wall first |
| Brute | from wave 4: 2.4 m of muscle, nineteen body rounds or more, hardly slowed by hits or blasts; each blow is worth nearly five of a walker's | head shots, or a rocket for most of its health; it takes two places at the wall |
| Behemoth | the boss of wave 8: 3.4 m tall, nearly ten thousand health, thick-skulled, cannot be slowed, staggered or thrown | everything you have; if it walks through a fallen gate it takes six tenths of the wall with it |

Zombies claim a place at the gate or wall and the rows behind step up when
one in front drops. The big ones take several places side by side and push
aside whatever is smaller than themselves: the Behemoth moves brutes, brutes
move the rest. Health and speed rise a little with every wave, each wave
that brings something new says so under its banner, and the Behemoth has its
own health bar.

### Weapons

| Weapon | Use | Supply |
| --- | --- | --- |
| Twin heavy machine gun | the everyday weapon: fast, accurate, pierces one zombie | endless belt, 160 rounds between reloads |
| RPG launcher | one rocket into a crowd: kills what it strikes and everything within a few metres | one in the tube and three spare at the start; more arrive after each wave |
| Hand grenade | lobbed to the spot under the crosshair, up to 46 m; bounces, then bursts | three at the start, five at most; one more after each wave |

Explosions hurt zombies only: the gate and the wall are spared (a knob in
the blast resources changes that). Rockets and grenades are kept out of the
accuracy figure on the result screen.

### Controls

| Action | Touch | Keyboard / mouse |
| --- | --- | --- |
| Aim | drag anywhere (also with the thumb that holds FIRE) | arrow keys or WASD, or drag with the mouse |
| Fire | hold the FIRE button | Space, or hold the mouse on FIRE |
| Reload | RELOAD button | R |
| Switch weapon | touch a weapon card | 1, 2, or Q for the next one |
| Throw a grenade | grenade button | G |
| Pause | pause button, Android back | Esc or P |

Each finger gets its own role when it lands, so one thumb can hold FIRE
while the other aims. Switching takes a moment (the weapon in hand is put
away, the other is brought up), and a weapon keeps reloading while it is put
away. The left-handed layout mirrors both hands, and the controls step in
from a camera notch.

Aim limits are yaw −70°…+70° and pitch −15°…+45°. Pitch follows the Godot
convention: negative is below the horizon, so the gun depresses 15° and
elevates 45°. Every attack position in the level is inside those limits.

## Project layout

```
scenes/        main.tscn, levels/, player/, weapons/, zombies/
scripts/
  core/        event bus, game flow, layers, match statistics
  player/      AimSettings, AimController, Defender
  weapons/     WeaponData, WeaponState, Weapon, TwinHmg, RocketLauncher,
               BulletPool, RocketPool, GrenadePool, GrenadeData,
               ExplosionData, Ballistics
  zombies/     ZombieData, Zombie, Horde, AttackLines
  waves/       SpawnGroup, WaveData, WaveSet, WaveDirector
  environment/ LevelLayout, CityLevel, Defense, DefenseData
  effects/     EffectPool, Explosions
  ui/          Hud, HudWidgets, Menus, UITheme, Loc
  audio/ graphics/ performance/ save/
resources/     the numbers: aim/, weapons/, explosions/, zombies/, waves/, defense/, levels/
assets/        models, textures, audio, fonts
tests/         headless unit and integration suites
tools/         asset generators, CI helpers, the self-driving play-through
documentation/ phase reports and the evidence CI records
```

## Tuning without touching code

Everything that shapes play is an exported property of a resource:

| File | What it controls |
| --- | --- |
| `resources/aim/default_aim.tres` | aim limits, drag sensitivity, smoothing, recoil, field of view |
| `resources/weapons/twin_hmg.tres` | damage, headshot multiplier, rate of fire, spread, magazine, reload, penetration, tracers |
| `resources/weapons/rpg_launcher.tres` | rocket speed and range, direct-hit damage, reload, rockets carried and the most that can be carried, time to bring it up |
| `resources/weapons/frag_grenade.tres` | grenades carried, cooldown, throwing range, flight time, fuze, bounce |
| `resources/explosions/rocket_blast.tres`, `grenade_blast.tres` | damage, inner and outer radius, share of damage at the edge, stagger, knockback, camera shake, damage to the wall and gate |
| `resources/zombies/walker.tres`, `runner.tres`, `brute.tres`, `boss.tres` | per kind: health, speed, attack damage and interval, breach damage, places taken at the wall, head and blast damage shares, how much hits and blasts slow, stagger and throw it, hit volumes, voice, pool size |
| `resources/defense/city_wall.tres` | wall and gate health, warning thresholds |
| `resources/waves/city_siege_waves.tres` | every wave: groups of any kind, counts, timing, routes, targets, the hint shown under its banner, growth per wave, rockets and grenades handed out when it is cleared |
| `resources/levels/city_siege_layout.tres` | routes, attack places, effect anchors (written by `tools/build_city.py`) |

`tools/make_waves.gd` rewrites the shipped waves if you want them back.

## Running, testing, building

```
godot --path .                                  # play on desktop (mouse = touch)
godot --headless --path . --editor --import     # import assets, build the class cache
godot --headless --path . --script res://tests/run_tests.gd
godot --path . --rendering-method gl_compatibility -- --smoke   # self-driving run with screenshots
```

The workflow in `.github/workflows/last-wall.yml` does the same with the
official editor, then exports the Android APK, inspects it and commits it to
`delivery/`. See `documentation/BUILD_ANDROID.md`.

## Assets

Every model, texture and sound is generated by the scripts in `tools/`
(`build_zombies.py` for all four kinds, `build_city.py`, `build_weapons.py`,
`build_textures.py`, `build_audio.py`, `build_icon.py`), except the mounted
gun, which was modelled for the earlier project. Nothing is downloaded. See
`ASSET_LICENSES.md`.

## Roadmap

| Phase | Content | State |
| --- | --- | --- |
| 0 | Audit of the earlier project, reuse plan | done |
| 1 | Wall and city, fixed first-person gunner, twin HMG, walker zombie, wall and gate health, zombie attacks, data-driven waves, HUD and basic menus | done |
| 2 | RPG launcher and hand grenades, weapon selection, grenade button, area damage | done |
| 3 | Fast, Heavy and Boss zombies, full wave progression | done |
| 4 | HUD and menu polish, audio and visual polish | next |
| 5 | Optimisation, clean-up, final verification | planned |
