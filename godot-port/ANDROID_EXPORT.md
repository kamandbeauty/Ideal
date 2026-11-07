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
| texture compression | ETC2/ASTC import enabled, required by the Android exporter | `project.godot` |
| architectures | `armeabi-v7a` + `arm64-v8a` | `export_presets.cfg` |
| renderer | GL Compatibility (GLES3 class), decision D2 of the audit | `project.godot` |
| engine | Godot 4.7.2 with its export templates | `project.godot`, CI |
| toolchain | OpenJDK 17, Android command-line tools, `platform-tools`, `build-tools;34.0.0`, `platforms;android-34` | `android-debug` CI job: all install steps green |
| export templates | official 4.4.1 `.tpz`, `android_debug.apk` present in `~/.local/share/godot/export_templates/4.4.1.stable/` | CI step "Make sure the Android export templates are installed" |
| debug keystore | `~/.android/debug.keystore`, alias `androiddebugkey` | CI step, and `tools/write_editor_settings.py` registers it |

## K1 — closed: the export works, and here is what was wrong

The Android export used to stop with `Cannot export project with preset "Android" due to configuration
errors:` and an **empty** list of reasons. Godot 4.4.1 never printed them on the command line; Godot
4.7.2 prints them, and there were exactly two:

```
"Min SDK" cannot be lower than 24, which is the version needed by the Godot library.
ETC2/ASTC texture compression is required for Android export. In Project Settings, search for 'ETC2'…
```

Fixes, both in the repository now:

| cause | fix |
| --- | --- |
| min SDK was 23, Godot's own library needs 24 | `min_sdk` is 24 wherever a Gradle build is used; the template path uses Godot's default |
| ETC2/ASTC import was off, and an Android export needs it for any GPU without full ASTC support | `rendering/textures/vram_compression/import_etc2_astc=true` in `project.godot` |

The `android-debug` job now exports `build/princes-palace-debug.apk` through the prebuilt template,
then proves it: the file is non-empty, `file(1)` sees an Android package, `unzip -l` finds
`AndroidManifest.xml` and `classes.dex`, and only then is it uploaded as the `princes-palace-debug-apk`
artifact (~57 MB, armv7 + arm64).

Two lessons worth keeping:
- an engine upgrade was the diagnostic tool. 4.4.1 swallowed the reasons; 4.7.2 printed them. When a
  tool hides its error, check whether a newer one shows it before re-engineering around it.
- the earlier hypotheses (templates, SDK, keystore, package id, preset schema, launcher icons) were all
  wrong, but each was cheap to rule out and the log now records them so nobody repeats the search.

## Release checklist (unchanged, still ahead)

- Install the CI artifact on a real device (it is built and verified, but nobody has run it yet).
- Device matrix run: match, cascade, booster, result, save/restore, lives refill, orientation, back
  gesture, low-memory behaviour.
- Frame time on a low-end device at 1080 × 1920 (the art's reference resolution), and a check that the
  85 sprites stay inside the memory budget from the audit's §3.
- Release keystore in a secret store, AAB, versioning, and a store listing in Persian + English.
