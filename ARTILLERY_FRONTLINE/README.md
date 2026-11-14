# LAST WALL: Zombie Siege

First-person wall-defence shooter. Godot 4.7.2, mobile renderer, landscape,
offline. Persian and English.

## The game

You man a machine gun on a bastion of the city wall (the twin heavy gun or
the six-barrel gun: you choose on the title screen), with an RPG launcher and
a belt of hand grenades beside you. In front of you is the gate court: the
city gate in the right wall arm, a patched breach in the left one, and beyond
the court the ruined avenue the horde comes down.

- Zombies walk the streets, cross the court and take a place at the gate or
  at the wall. There they swing, and every blow costs gate or wall health.
- When the gate falls, they stop attacking it and run through. Each one
  that gets inside tears a chunk out of the wall's health.
- When the wall's health reaches zero the wall is breached and the stage
  is lost. Hold every wave of all three stages and the wall holds.

### Stages

The siege is eight waves, fought in three stages. A stage is one sitting of
two or three minutes.

| Stage | Waves | Zombies | What it brings |
| --- | --- | --- | --- |
| 1 | 3 | 74 | walkers, then the first runners: the opener |
| 2 | 3 | 136 | the brutes, then a swarm |
| 3 | 2 | 115 | the heavy wave, then the Behemoth |

Winning a stage opens the next. The title screen shows all three: the open
ones can be picked and played again, the rest wait under a padlock. The
result screen of a stage that was won offers NEXT STAGE. Every stage begins
on a whole wall and gate, with the rockets and grenades of a new match;
zombies keep the hardening of the waves that came before, so the first wave
of stage 2 is as tough as the fourth wave of the siege. The best run is kept
as a stage and a wave. A save from before there were stages keeps its
progress: every stage that lay wholly behind its best wave is open.

### The horde

| Kind | What it is | How to deal with it |
| --- | --- | --- |
| Walker | the rank and file: slow, three rounds to the body (four in the late waves) | sweep them; a rocket or grenade clears a knot of them |
| Runner | from the second wave of stage 1: lean, more than twice as fast, strikes often | two rounds to the body or one to the head; they reach the wall first |
| Brute | from stage 2: 2.4 m of muscle, nineteen body rounds or more, hardly slowed by hits or blasts; each blow is worth nearly five of a walker's | head shots, or a rocket for most of its health; it takes two places at the wall |
| Behemoth | the boss of the last wave of stage 3: 3.4 m tall, nearly ten thousand health, thick-skulled, cannot be slowed, staggered or thrown | everything you have; if it walks through a fallen gate it takes six tenths of the wall with it |

Zombies claim a place at the gate or wall and the rows behind step up when
one in front drops. The big ones take several places side by side and push
aside whatever is smaller than themselves: the Behemoth moves brutes, brutes
move the rest. Health and speed rise a little with every wave, each wave
that brings something new says so under its banner, and the Behemoth has its
own health bar.

Each walker, runner or brute is one of the original figures or the free
bloat character, picked at random when it spawns. The bloat is the fatter
monster: it takes a bit more killing than the rest of its type. Walkers wear
one of five painted outfits. The horde is sized to read against the wall from
the bastion without towering over the gate.

None of them walks sound. Every kind drags a leg: one foot takes the weight
and the other is hauled after it, with the trunk pitching over the good side.
Each model brings that walk lame in the left leg and lame in the right (the
walker also a second, more broken gait), and every zombie takes one of them
for its life, at its own pace and its own point in the stride, so a crowd
does not move in step. The body rounds in the table are the twin gun's; the
six-barrel gun needs nearly twice as many, and fires them in less time.

### Weapons

| Weapon | Use | Supply |
| --- | --- | --- |
| Twin heavy machine gun | the gun a new player has: 12 heavy rounds a second, accurate, each one goes through a body into the one behind; the better gun for the head | endless belt, 160 rounds between reloads (2.6 s) |
| Six-barrel rotary gun | the other gun for the mount: 25 light rounds a second that stop in the first body and scatter wider; its barrels need 0.3 s to run up before the first round | endless belt, 500 rounds between reloads (3.6 s) |
| RPG launcher | one rocket into a crowd: kills what it strikes and everything within a few metres | one in the tube and three spare at the start; more arrive after each wave |
| Hand grenade | lobbed to the spot under the crosshair, up to 46 m; bounces, then bursts | three at the start, five at most; one more after each wave |

One of the two guns stands on the mount; the title screen shows both with a
line on each, the street behind the menu shows the chosen one at once, and
the choice is kept. Held on a body they are nearly even (400 damage a second
for the twin gun, 425 for the six-barrel gun; over belt after belt 336 and
356); the twin gun does 1000 a second to a head, the other 850.

Explosions hurt zombies only: the gate and the wall are spared (a knob in
the blast resources changes that). Rockets and grenades are kept out of the
accuracy figure on the result screen.

### Controls

| Action | Touch | Keyboard / mouse |
| --- | --- | --- |
| Aim | drag anywhere (also with the thumb that holds FIRE) | arrow keys or WASD, or drag with the mouse |
| Fire | hold the FIRE button | Space, or hold the mouse on FIRE |
| Draw the sight in or out | the lens button above FIRE | Z, or the right mouse button |
| Reload | RELOAD button | R |
| Switch weapon | touch a weapon card | 1, 2, or Q for the next one |
| Throw a grenade | grenade button | G |
| Pause | pause button, Android back | Esc or P |

Each finger gets its own role when it lands, so one thumb can hold FIRE
while the other aims. Switching takes a moment (the weapon in hand is put
away, the other is brought up), and a weapon keeps reloading while it is put
away. The left-handed layout mirrors both hands, and the controls step in
from a camera notch.

The sight brings the street 2.5 times closer, for either gun and for the
launcher. Drawn in, the same travel of the finger turns the gun 2.5 times
less, so the picture moves under the thumb as it always does; the shake of a
shot is scaled down with it. A tap draws it in and a tap lets it out; it lets
go by itself when a match ends, and every match starts with the naked eye.

Aim limits are yaw −70°…+70° and pitch −15°…+45°. Pitch follows the Godot
convention: negative is below the horizon, so the gun depresses 15° and
elevates 45°. Every attack position in the level is inside those limits.

### Screens and settings

The title screen stands in two blocks with the gun between them: the title,
SETTINGS and the language at the reading edge, and at the other a card with
the coming battle: which stage, which gun, and the button that starts it.

The HUD keeps each thing at the edge it belongs to: wall and gate top left,
the wave (and the Behemoth's bar) top centre, kills and PAUSE top right, the
firing hand in one bottom corner and the weapon cards in the other. A blow
on the wall or the gate that lands outside the view raises an arrow on that
side of the screen. Pause tells where the match stands and asks twice before
RESTART or MAIN MENU throws it away; the result screen gives ten figures.
Everything is laid out for 16:9, 20:9 and 4:3 screens, steps in from a
camera cut-out, and reads right-to-left in Persian.

| Setting | Choices |
| --- | --- |
| Aim sensitivity, invert vertical aim, left-handed layout | slider and switches |
| Screen shake | on / off; changes the picture only, never where rounds go |
| Language | Persian / English |
| Master, effects and music volume | sliders; the wind follows the effects volume |
| Graphics quality | auto / low / medium / high |
| Show frame rate | on / off |

"Auto" starts a phone on the medium tier and then watches the frame time.
It lowers the 3D render resolution a step at a time while frames stay slow,
and raises it again when they are fast; a step up that is regretted at once
sets a ceiling, so the resolution does not swing back and forth. If the
resolution has gone all the way down and frames are no shorter, it is given
back and left alone. Still slow, one tier is given up; if that buys nothing
either, the tier is taken back and tiers are left alone. A tier the player
picks is never touched. Every number involved (what counts as slow, the
steps, the floors, the patience) is in `resources/graphics/governor.tres`;
none of them has been tuned on a phone yet. The low tier drops shadows,
normal maps, the lights of flashes, rockets and blasts, and the particle
dressing; the high tier adds 2× MSAA and glow.

## Project layout

```
scenes/        main.tscn, levels/, player/, weapons/, zombies/
scripts/
  core/        event bus, game flow, the campaign of stages, layers, match statistics
  player/      AimSettings, AimController, Defender
  weapons/     WeaponData, WeaponState, Weapon, TwinHmg, RotaryGun, RocketLauncher,
               BulletPool, RocketPool, GrenadePool, GrenadeData,
               ExplosionData, Ballistics
  zombies/     ZombieData, Zombie, Horde, AttackLines
  waves/       SpawnGroup, WaveData, WaveSet, WaveDirector
  environment/ LevelLayout, CityLevel, Defense, DefenseData
  effects/     EffectPool, Explosions, MarkPool, CasingPool
  ui/          Hud, HudWidgets, Menus, MenuWidgets, UITheme, Loc
  graphics/    quality tiers, the automatic-quality governor and its settings, materials
  audio/ performance/ save/
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
| `resources/aim/default_aim.tres` | aim limits, drag sensitivity, smoothing, recoil, field of view, how much closer the sight brings the street and how fast it glides in |
| `resources/weapons/twin_hmg.tres`, `rotary_gun.tres` | per gun: damage, headshot multiplier, rate of fire, spread, magazine, reload, penetration, tracers, recoil, and for a motor-driven gun the time it takes to run up |
| `resources/weapons/rpg_launcher.tres` | rocket speed and range, direct-hit damage, reload, rockets carried and the most that can be carried, time to bring it up |
| `resources/weapons/frag_grenade.tres` | grenades carried, cooldown, throwing range, flight time, fuze, bounce |
| `resources/explosions/rocket_blast.tres`, `grenade_blast.tres` | damage, inner and outer radius, share of damage at the edge, stagger, knockback, camera shake, damage to the wall and gate |
| `resources/zombies/walker.tres`, `runner.tres`, `brute.tres`, `boss.tres` | per kind: health, speed, attack damage and interval, breach damage, places taken at the wall, head and blast damage shares, how much hits and blasts slow, stagger and throw it, hit volumes, voice, pool size |
| `resources/defense/city_wall.tres` | wall and gate health, warning thresholds |
| `resources/waves/stage_1_waves.tres`, `stage_2_waves.tres`, `stage_3_waves.tres` | every wave of each stage: groups of any kind, counts, timing, routes, targets, the hint shown under its banner, growth per wave, rockets and grenades handed out when it is cleared, and how many waves of the siege lie before the stage |
| `resources/levels/city_siege_layout.tres` | routes, attack places, effect anchors (written by `tools/build_city.py`) |
| `resources/graphics/governor.tres` | automatic quality: target frame rate, what counts as a slow frame, resolution steps and floor, how long to wait, the lowest tier allowed, or off altogether |

`tools/make_waves.gd` rewrites the shipped waves if you want them back: it
holds the eight waves of the siege and cuts them into stages (`CUTS`, three,
three and two). `scripts/core/campaign.gd` lists the stage files in order;
the guns that can stand on the mount are listed in `Profile.GUNS` and
`Defender.GUN_SCENES`.

## Running, testing, building

```
godot --path .                                  # play on desktop (mouse = touch)
godot --headless --path . --editor --import     # import assets, build the class cache
godot --headless --path . --script res://tests/run_tests.gd
godot --path . --rendering-method gl_compatibility -- --smoke   # self-driving run with screenshots
python3 tools/audit_project.py                  # nothing broken, nothing left over (no engine needed)
```

The workflow in `.github/workflows/last-wall.yml` does the same with the
official editor, then exports the Android APK, inspects it and commits it to
`delivery/`. See `documentation/BUILD_ANDROID.md`.

## Assets

Every model, texture and sound is generated by the scripts in `tools/`
(`build_zombies.py` for all four kinds, `build_city.py`, `build_weapons.py`,
`build_textures.py`, `build_audio.py`, `build_icon.py`), except the twin
gun, which was modelled for the earlier project. Nothing is downloaded. See
`ASSET_LICENSES.md`. `tools/preview_glb.py` draws a generated model from any
side, in any pose of any clip, without the engine.

## Roadmap

| Phase | Content | State |
| --- | --- | --- |
| 0 | Audit of the earlier project, reuse plan | done |
| 1 | Wall and city, fixed first-person gunner, twin HMG, walker zombie, wall and gate health, zombie attacks, data-driven waves, HUD and basic menus | done |
| 2 | RPG launcher and hand grenades, weapon selection, grenade button, area damage | done |
| 3 | Fast, Heavy and Boss zombies, full wave progression | done |
| 4 | HUD and menu polish, audio and visual polish | done |
| 5 | Optimisation, clean-up, final verification | done |
| 6 | The sight that draws in, new zombie models that limp, the six-barrel gun, the siege in three stages | done; not yet run on a phone |
