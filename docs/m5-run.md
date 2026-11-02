# Running it (M5): first open, first compile, first APK

This is the document that turns "the repo contains a game" into "a game is running in front of me".
It exists because everything before M5 was written, drawn and gated *without a single run*: no C# in
this repository has ever been compiled by the compiler that will ship it.

## Where it stands, as of the first real pipeline run

The first push after `ProjectVersion.txt` landed (run
[`41415848971`](https://github.com/kamandbeauty/Ideal/actions/runs/41415848971)) is the first one that
did not take the "no Unity project" escape hatch:

| job | result | why |
| --- | --- | --- |
| `detect unity project` | **success** | the project is found and its version matches the pipeline pin |
| `edit + play mode tests` | **failure** | `game-ci/unity-test-runner` has no `UNITY_LICENSE` — the one thing only the account owner can add |
| `android` / `ios` | skipped | they wait on `test` |

`ci.yml` stayed green on the same push, including its new `unity project pin` job. So the failure is
not the code: it is the licence secret. Add it (below), push, and the next run either passes the tests
or finally shows a real compile error.

Two paths, in order of how fast they get you a screen:

| | what you get | what it costs | how long |
| --- | --- | --- | --- |
| **A — local editor** | the game in the Unity Game view, one click into each screen | a Unity 6 install (~8 GB) | minutes after the install |
| **B — GitHub Actions** | an installable `.apk` on your phone | a Unity licence secret, plus 20–90 min of CI per build | an afternoon of setup, once |

Path A is how a bug gets fixed; path B is how a build reaches a device. Do A first.

## What the repo has, and what Unity generates

The repository commits **only the parts a human decides**:

| committed | generated on first open (ignored by git) |
| --- | --- |
| `client/Assets/**` — scripts, asmdefs, art PNGs, fonts, level JSON | `client/Library/`, `client/Temp/`, `client/Logs/`, `client/Obj/` |
| `client/Packages/manifest.json` — 14 packages pinned exact | `client/Packages/packages-lock.json` (all of them are pinned, so this is reproducible anyway) |
| `client/ProjectSettings/ProjectVersion.txt` — `6000.0.32f1 (b2e806cf271c)` | the other ~20 `ProjectSettings/*.asset` files |
| — | every `*.meta` file |

There is no scene in the repo and no prefab, on purpose: `Editor/ShazdehMenu.cs` builds the scenes from
code (`Assets/Scenes/App.unity` plus two inspection scenes), so CI can build from a fresh clone and
nothing can rot as a broken `.unity` YAML file.

`ProjectVersion.txt` is the switch. `unity.yml` looks for it, and `tools/ci/check_unity_pin.py` fails
the `ci.yml` `unity-project` job if it disagrees with the `UNITY_VERSION` the pipeline installs.

## Path A — the game in the Unity editor

1. Install **Unity 6000.0.32f1** through Unity Hub (any 6000.0.32f1 module set; add the *Android Build
   Support* module only if you also want to build locally).
2. Open the folder **`client/`** as a project. First import takes a few minutes and is where the first
   compile error will appear, if there is one.
3. In the menu bar, run **`کاخ شازده → Create scenes`**. This creates:
   - `Assets/Scenes/App.unity` — the game (one `AppRoot` object; add it to Build Settings as scene 0),
   - `Assets/Scenes/_DesignSystem.unity` — every token, button and frame on one page,
   - `Assets/Scenes/_PersianCheck.unity` — shaping, numerals, mirroring, the font's own coverage.
4. Open `App.unity` and press **Play**. Expect the home screen: the palace plate, the level card,
   «شروع», the top bar with coins/potions/lives. Then «شروع» into the board: the chapter floor under a
   nine-sliced frame, nine by nine stones, the moves pill, the booster bar.

   If a screen comes up with its text and buttons but an **empty** rectangle where the board should be,
   that is the camera, not the art: the board is drawn by a real `Camera` one unit in front of its near
   plane, and anything placed on the camera's own plane is culled before it is drawn.
5. Read the Console. The boot log is designed to be the first thing a human reads:

   ```
   [boot] save at …/shazdeh-save.json — level 1, 0 potions, 5 lives
   ```

   Any line starting `[boot]` before that is a content or save problem, and it names the file.

6. Optional, and worth doing once: **`کاخ شازده → Validate levels`** and **`کاخ شازده → Build UI font
   assets (optional)`**. The font assets are optional by design — `ShazdehFonts` builds them from the
   shipped TTF at runtime — but baking them removes a small hitch from the first frame on a cheap phone.

Out of the editor, the same two entry points exist as menu items for the build you want:

- **`کاخ شازده → Build → Android (APK, for a phone)`** → `build/Android/Shazdeh.apk`, signed with the
  debug key, installs with `adb install`.
- **`کاخ شازده → Build → Android (AAB)`** → the store bundle.

### After the first successful open, commit what Unity generated

```bash
git add client/ProjectSettings client/Packages/packages-lock.json
git add -A client/Assets        # the .meta files Unity just wrote
```

`ProjectSettings.asset` carries the portrait lock, the bundle id and the player settings that
`CiBuild.ApplyPlayerSettings` also writes at build time; committing it means the editor and the build
agree without anyone remembering a checkbox. `.meta` files must be committed: they hold the GUIDs the
scene references.

## Path B — an installable APK from GitHub Actions

The workflow is `.github/workflows/unity.yml`; setup detail (licence file, keystore) is in
[`docs/ci.md`](ci.md). In short:

1. **Unity licence** → secret `UNITY_LICENSE` (personal: the `.alf` → `.ulf` dance, then
   `base64 -w0`), or `UNITY_SERIAL` + `UNITY_EMAIL` + `UNITY_PASSWORD` on a paid plan.
2. Push, or run the workflow by hand with **`android_output: apk`**.
3. `test` runs first — EditMode + PlayMode — and it *is* the compile gate: nothing is built until the
   150 tests have been compiled and run.
4. `build-android` produces `shazdeh-android-<run>.apk` as an artifact. Download it on the phone,
   allow "install unknown apps", install.

An **`.aab` cannot be installed on a phone** — it is a store submission format. That is why a push
builds the `.apk` by default and dispatch can ask for `aab` when the store is the target.

The keystore secrets are only needed for a release build: with none set, GameCI falls back to Unity's
debug keystore, which installs on a test phone. Do not ship a debug-signed build to a store.

## What to expect from the first compile

Honest list, because the alternative is a surprise:

- **It has never been compiled.** 150 tests, ~8 000 lines of C#, all written against APIs I could read
  but not run. The first compile — Path A step 2, or Path B step 3 — is where the truth arrives.
- The likeliest error sites, in order: (1) `Game/Ui/BoardScreen.cs`, the newest and largest file, and
  specifically the booster bar and the armed-tap path added in M4; (2) `Editor/TmpFontSetup.cs`, if
  TMP's `CreateFontAsset` overload changed between 3.0 and 3.2; (3) `Editor/CiBuild.cs`, if a
  `PlayerSettings` setter moved in Unity 6.
- A compile error is a **success** at this stage: it is the first information the project has ever
  received from the actual toolchain. Paste it and it gets fixed; every gate in `ci.yml` stays green
  while that happens, because none of them claim to compile.
- Nothing here claims the *game* works. The swap feel, the timing of a cascade and the shape of the
  layout are judged by playing, not by a test.

## What M5 is done means

- `ci.yml` `unity-project` is green (it is: the pin, the revision and 14 package versions agree).
- The project opens in 6000.0.32f1 and compiles with zero errors.
- The 150 tests pass in the editor's Test Runner.
- `App.unity` runs: home → play → board → win/lose → home, and the booster chips fire.
- One `.apk` installs on a phone and starts without a Unity splash of errors.
