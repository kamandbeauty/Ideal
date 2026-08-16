# Ruby Run / روبی ران

A real, offline-first 2D endless runner for Android, built with **Godot 4.7.1** and GDScript. Ruby auto-runs through Ruby Forest; tap to jump and tap again for a double jump. The project is structured for Google Play, CafeBazaar, and Myket release without claiming that unconfigured external services are present.

## Play

1. Install Godot 4.7.1.
2. Open `project.godot` and run the main scene.
3. Tap/click/Space jumps; a second input in the air double-jumps.

No network connection, account, Android permission, ad SDK, or analytics SDK is needed by the base game.

## Implemented

- Endless speed progression, score/best score, random fair obstacle patterns, pooled rocks/logs/coins, collision, retry and home flow
- Portrait vector placeholder artwork with multi-layer parallax Ruby Forest and animated fox states
- Five data-driven skins with purchase/equip economy
- Defensive, atomic, versioned local saves and in-app confirmed reset
- Seven-day local daily reward with clock-rollback guard
- Music/sound/vibration settings (audio facade ready; production audio assets remain to be supplied)
- Disabled-by-default, failure-safe boundaries for ads, analytics, consent, and compliance preflight
- Debug APK and secret-signed release APK/AAB CI jobs
- Privacy Policy, Data Safety statement, Android guide, and release checklist

## Architecture

```text
scenes/                 Main Godot scene
scripts/managers/       Save, game, audio, skin, reward, ad, analytics, consent, compliance
scripts/player/         Ruby movement, double jump, visual animation, hit state
scripts/world/          Pooled entities and parallax forest
assets/images/          Replaceable SVG placeholder/icon
data/                    Skin catalog and release configuration
docs/                    Privacy, Data Safety, Android and release controls
tests/                   Headless GDScript tests
tools/                   Static release/project validator
.github/workflows/       Reproducible Android CI
```

Autoloads communicate through narrow manager interfaces. Scene code never calls an ad or analytics provider. Placeholder visuals can be replaced without changing gameplay data or service architecture.

## Validation

```bash
python3 tools/validate_project.py
godot --headless --editor --path . --import --quit
godot --headless --path . res://tests/test_runner.tscn
godot --headless --path . --export-debug "Android Debug" export/RubyRun-debug.apk
```

Every push and pull request runs those checks and a debug Android export. Manual/release workflows require all signing secrets and produce signed APK/AAB artifacts. See [Android release guide](docs/ANDROID_RELEASE.md).

## Android configuration

| Setting | Value |
|---|---|
| Application ID | `com.studiojavid.rubyrun` |
| Name | Ruby Run |
| Version | 1.0.0 / code 1 |
| Orientation | Portrait |
| Minimum SDK | 24 |
| Target SDK | 36 (must be rechecked at release time) |
| Base permissions | None |

`data/release_config.json` deliberately remains in development mode with an empty privacy URL. Publish the supplied policy at a real HTTPS location and complete `docs/RELEASE_CHECKLIST.md` before release. Never insert a fake URL.

## Advertising and analytics status

Neither SDK is included. Therefore rewarded controls are hidden, gameplay remains fully available, no interstitial/banner is shown, no analytics event leaves the device, and no network permission is requested. `AdManager` includes placement availability and frequency-cap boundaries; `AnalyticsManager` uses strict event/parameter allowlists. Adding a provider is a separate reviewed release change requiring privacy, consent, SDK inventory, manifest, and Data Safety updates.

## License and assets

Source licensing must be selected by the repository owner before public distribution. Current vector art is original project placeholder art; production store artwork and audio should be reviewed and supplied before publishing.
