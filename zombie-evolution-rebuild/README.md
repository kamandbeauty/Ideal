# Zombie Evolution — clean-room project

A standalone Godot 4 portrait project, independent from the other projects in this repository. Open this directory's `project.godot` with Godot 4. From the Persian launcher choose «شروع بازی». The hero runs automatically; drag left/right on a touchscreen or with the mouse, or use the arrow keys. The assault rifle targets enemies automatically. To choose a gate, move left or right before reaching it; the hero fires at the corresponding gate. The gate effect is applied after crossing. Defeat all enemies and reach the end of the bridge to win.

## Prototype status

This is a **headless-tested gameplay prototype**, not a finished game. Code includes a procedural bridge, clouds, character collision and movement, rifle raycasts, zombie waves, squad, a gate pair, health and results. A headless no-input run and focused integration tests passed, but graphical rendering, touch on Android, and balance have not been verified. Character art is temporary. Audio, polished animations and visual effects, full level design, boss phases, full progression, Android export, device performance, and correct Persian rendering on Android remain to be implemented or verified.

## Running checks

With Godot 4 installed, import the project first with `godot --headless --editor --path . --quit`. Then run `godot --headless --path . --script res://tests/level_test.gd` for the integration test. Additional launcher, autoplay and Persian UI checks are in `tests/`. Run `godot --headless --path . --script res://tests/preferences_test.gd` with an isolated user data directory, because it writes settings. See `TESTING.md` for actual test status.

DejaVu Sans is bundled under `assets/fonts/LICENSE.txt`. A preliminary ARM64 Android export preset is included, but Android export templates, Android SDK/JDK and local debug signing are not configured; no APK has been produced. See `TESTING.md` for the current workspace limitations and export command.
