# ARTILLERY FRONTLINE

An original, offline, single-player **Godot 4.7.2** artillery vertical slice for landscape Android. Take command of the M-70 Bastion in **Operation Dustline**, a desert training outpost with a radar installation, patrolling armor and a moving transport. This is a first playable milestone, not the full five-mission campaign.

## Play

Open `project.godot` in Godot 4.7.2 and run the main scene. Choose **Deploy to Dustline**. Drag the battlefield to traverse and elevate the gun, follow the dotted trajectory, and tap **FIRE**. Tap **RELOAD** after each shot; switching shell types also requires a reload. Neutralize all three targets before running out of ammunition.

| Action | Touch | Desktop |
| --- | --- | --- |
| Aim | Drag outside the buttons | Left mouse drag |
| Fire / reload | FIRE / RELOAD | Space / R |
| Select HE / AP | HE / AP | 1 / 2 |
| Zoom / shell camera | ZOOM / CAM | Z / C |
| Pause / resume | PAUSE / RESUME | Esc |

HE has a wide blast; AP deals more direct damage but has a smaller blast radius. Reloading and shell inventory are deliberately manual. The trajectory is an aid, not an aim-assist: patrol targets continue to move while a shell is in flight.

## Project and validation

- `scenes/main.tscn` is the composition root. Game systems live separately under `scripts/`; weapon and shell definitions are Godot Resources under `resources/`.
- The battlefield and models are original procedural geometry; effects and audio are generated locally. Font and engine licenses are listed in [ASSET_LICENSES.md](ASSET_LICENSES.md) and included under LICENSES in the game menu.
- The default Mobile renderer falls back to Compatibility if Vulkan is unavailable. Graphics settings, audio, sensitivity, and mission records are saved locally; the game requests no internet permission.
- Build, testing, architecture and known limitations are documented in [documentation/DEVELOPMENT.md](documentation/DEVELOPMENT.md).
- `.github/workflows/validate-and-build.yml` contains lint, headless test, and **debug** APK/AAB artifact jobs. Release signing is deliberately not configured in source.

This milestone is a vertical slice: the additional campaign missions, economy, upgrades, full destruction, final art/audio, and physical-device QA remain future work.
