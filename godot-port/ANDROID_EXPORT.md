# Android export — state of play

The port is a portrait Android game: `project.godot` fixes the 415 × 738 design space, the
`gl_compatibility` renderer and `window/handheld/orientation=1`. This file records exactly how far the
Android build has got, so nobody has to guess from a red workflow.

## What is configured and verified

| item | value | verified by |
| --- | --- | --- |
| package id | `com.shazdeh.palace` | `export_presets.cfg` |
| version | code 1, name 1.0.0 | `export_presets.cfg` |
| launcher icons | `assets/branding/icon_192.png`, `icon_432.png` (Godot rejects the 512 px source in these slots) | sizes checked in the repo |
| architectures | `armeabi-v7a` + `arm64-v8a` | `export_presets.cfg` |
| renderer | GL Compatibility (GLES3 class), decision D2 of the audit | `project.godot` |
| toolchain | OpenJDK 17, Android command-line tools, `platform-tools`, `build-tools;34.0.0`, `platforms;android-34` | `android-debug` CI job: all install steps green |
| export templates | official 4.4.1 `.tpz`, `android_debug.apk` present in `~/.local/share/godot/export_templates/4.4.1.stable/` | CI step "Make sure the Android export templates are installed" |
| debug keystore | `~/.android/debug.keystore`, alias `androiddebugkey` | CI step, and `tools/write_editor_settings.py` registers it |

## Known problem K1 — the CLI refuses the export with an empty reason

`godot --headless --path godot-port --export-debug "Android" build/princes-palace-debug.apk` stops
with:

```
ERROR: Cannot export project with preset "Android" due to configuration errors:
ERROR: Project export for preset "Android" failed.
```

and the list of configuration errors after the colon is **empty**. Everything that usually produces a
named error there has been tested: the templates exist, the SDK/JDK paths are registered in
`editor_settings-4.tres`, the keystore exists and is registered, the icons are the exact sizes Godot
wants, the preset was rewritten in the Godot 4.4 schema (`version/code`, no Godot 3 keys), a stripped
"minimal" preset fails identically, and the copy of the same preset with `use_gradle_build=true` never
gets as far as reporting an error because the Gradle build takes longer than the probing budget.

Two things this is **not**:
- not a broken project — on the same runner a **Linux export succeeds** end to end (the pack is built
  and written), so the export pipeline and the presets file itself are fine;
- not a missing template — `android_debug.apk` is listed in the templates directory during the same
  run.

Next things to try, in order of cost:
1. On a workstation with a display, open *Project → Export → Android* once, read the error list Godot
   shows in the dialog (it is populated there even when the CLI prints nothing), and fix that.
2. Run the Gradle path with a 45-minute budget: `--install-android-build-template`, then
   `gradle_build/use_gradle_build=true`, then export. Gradle is the only path that honours a custom
   package id and explicit `min_sdk`/`target_sdk`, so it has to work before a release build anyway.
3. If both stall, pin an older export template (4.3) as a control to see whether the failure is
   version-specific.

Until K1 is closed, the `android-debug` job stays **failing on purpose**: no APK is claimed, and no
artifact is uploaded, because none was produced. The `headless` job — import, every script compiles,
both suites, and a real boot to the title screen — is the gate that says the game itself works.

## Release checklist (unchanged, still ahead)

- Close K1 and produce a debug APK that installs on a device.
- Device matrix run: match, cascade, booster, result, save/restore, lives refill, orientation, back
  gesture, low-memory behaviour.
- Frame time on a low-end device at 1080 × 1920 (the art's reference resolution), and a check that the
  85 sprites stay inside the memory budget from the audit's §3.
- Release keystore in a secret store, AAB, versioning, and a store listing in Persian + English.
