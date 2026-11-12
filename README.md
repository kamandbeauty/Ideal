# Zombie Evolution — Level 01: "The Sky Bridge" (پل آسمانی)

## What this package is

A **Godot 4 GDScript starter kit** implementing the *core gameplay systems* described
in the Level 1 spec: player movement, squad recruitment, math gates, zombie AI,
and a Persian-language HUD/game-flow manager.

It is **not** a finished, buildable APK. It cannot be, from a text-based assistant
with no game engine, no 3D asset pipeline, and no Android build tools available.
What's missing and has to be done by you (or by Claude Code running locally,
where an actual Godot install, emulator, and Android SDK exist):

- 3D models & rigs (hero, soldiers, 3 zombie types, bridge environment, boss)
- Animations (idle/run/shoot/reload/hit/death/victory) — these scripts assume
  an AnimationPlayer with matching animation names, but contain no animation data
- Particle effects, muzzle flash, bullet trails, shell ejection meshes
- Audio assets (gunfire, growls, music, etc.)
- A bundled Persian font (e.g. Vazirmatn) set as the project's default theme font
- Scene (.tscn) files wiring these scripts to actual 3D nodes
- Building, running on an emulator/device, and APK export

## What's included

```
scripts/
  Player.gd        - swipe movement, auto-fire, health, reload
  Squad.gd         - soldier recruitment/formation/attack/death
  MathGate.gd      - ×2 / +N / % firepower gate logic, left/right selection
  Zombie.gd        - base enemy class; Normal/Runner/Brute via exported stats
  GameManager.gd   - level flow (sections 1-9), wave spawning, win/lose state
  HUD.gd           - Persian UI strings, RTL-ready labels, boss health bar
```

All code comments and node/variable names are in English per the spec; all
player-facing strings inside HUD.gd and GameManager.gd are in Persian.

## How to use this

1. Create a new Godot 4 project (or open your existing one).
2. Drop the `scripts/` folder in.
3. Build your bridge environment scene and character/zombie scenes (3D meshes
   + AnimationPlayer nodes with the animation names referenced in the scripts).
4. Attach `Player.gd` to your hero's CharacterBody3D, `Zombie.gd` to each zombie
   scene (set `zombie_type` in the Inspector), `MathGate.gd` to each gate Area3D
   pair, and `GameManager.gd` + `HUD.gd` to your level root / UI layer.
5. Wire the exported NodePaths/signals (marked `# TODO: assign in editor`) to
   your actual scene nodes.
6. For the Persian font: import Vazirmatn (or similar) as a Theme Resource and
   set it as the project's default font so Persian text renders with proper
   letter connections and RTL alignment — Godot 4's TextServer (ICU-based)
   handles Arabic-script shaping and RTL automatically once the font is set;
   just make sure `text_direction` on Label/RichTextLabel nodes showing Persian
   is set to **Auto** or **RTL**.

## Recommended next step

For actually running this in Godot, iterating on scenes/animations, and
producing an Android build, you'll want an environment with Godot + Android
SDK installed — that's a job for **Claude Code** running on your machine
rather than this chat, since it can execute the engine, build tools, and an
emulator directly.
