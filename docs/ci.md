# CI and builds (GitHub Actions + GameCI)

Two workflows. `ci.yml` runs on every push and needs nothing; `unity.yml` runs when the Unity half of
the repo changes, and now that `client/ProjectSettings/ProjectVersion.txt` exists it builds for real:

| workflow | runs | what it proves |
| --- | --- | --- |
| `.github/workflows/ci.yml` | every push and PR | `replica/schema.sql` applies to a real Postgres 16, the 8 wallet-protecting constraints actually hold, the palette passes WCAG AA, `Tokens.gen.cs` matches `tokens.json`, level + district JSON validates, every C# file parses, every static member it names exists, and no Unity/TMP/UI type is named without the `using` that brings it into scope, the Persian shaper agrees with a second implementation and the shipped font can draw its output, and the art manifest matches its generated catalog |
| `.github/workflows/unity.yml` | pushes touching `client/**`, manual dispatch | EditMode + PlayMode tests (the compile gate), then an Android `.apk` — dispatch can ask for the store `.aab` instead; iOS Xcode project on dispatch |

The Unity jobs still check for `client/ProjectSettings/ProjectVersion.txt` first and skip with a
notice if it ever goes missing. It exists now, so they do not skip: the project pins `6000.0.32f1`
(`b2e806cf271c`) and `unity.yml` installs exactly that. Running the game locally, and what the first
compile is expected to cost, is [`docs/m5-run.md`](m5-run.md).

`ci.yml` runs eight jobs: `schema`, `design`, `content` (levels + chapter meta), `csharp`
(`tools/csharp/lint.py`, pinned grammar in `tools/csharp/requirements.txt`), `unity-project` (the
project's editor version, the pipeline's pin and every package version must agree —
`tools/ci/check_unity_pin.py`), `text` (Persian letter
tables, shaping vs `arabic-reshaper`, golden vectors, font coverage — `tools/text/requirements.txt`),
`art` (the sprite contract, its generated catalog, every committed PNG, the generator that draws them,
and the 48 px silhouette gate) and `server`. The
`csharp` job is not a substitute for Unity's compiler — it is what catches a broken brace or a renamed
member on a machine that cannot build the game. The `text` job is what stops a shaper regression from
reaching a phone: Persian is the product.

## One-time setup

### 1. Unity licence (needed by both workflows)

Unity's licence is per-machine; CI needs it as a **repository secret**. Two things that are *not* a
licence for CI, and look like one:

- **a licence activated in the Hub on your laptop** — it lives in a file on that machine, and the runner
  is a different machine;
- **Hub connected to GitHub** — that is Unity Version Control / cloud sign-in; Actions never reads it.

What CI needs is the `.ulf` file itself, as base64.

**Personal / Plus — the short path (a licence already activated in your Hub):**

The Hub already wrote the file. Find it, encode it, paste it:

| OS | path |
| --- | --- |
| Windows | `C:\ProgramData\Unity\Unity_lic.ulf` |
| macOS | `/Library/Application Support/Unity/Unity_lic.ulf` |
| Linux | `~/.local/share/unity3d/Unity/Unity_lic.ulf` |

```bash
# Linux / macOS
base64 -w0 Unity_lic.ulf        # macOS: base64 -i Unity_lic.ulf -o license.b64
```

```powershell
# Windows PowerShell: straight to the clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\ProgramData\Unity\Unity_lic.ulf")) | Set-Clipboard
```

Then **Settings → Secrets and variables → Actions → New repository secret**, name `UNITY_LICENSE`,
value = that base64 string (one line, no wrapping, no quotes).

**Personal / Plus — the long path (if the runner rejects the `.ulf` above):**
1. Run the helper action once in a scratch branch: `game-ci/unity-request-activation-file@v2`
   (it writes a `.alf` file as an artifact — that file describes the *runner*, not your laptop).
2. Upload that `.alf` to `license.unity3d.com` → download the `.ulf`.
3. Encode it the same way and paste it into `UNITY_LICENSE`.

Either way: Unity allows three activated machines per licence. A CI activation is one of them, so do
not run two Unity workflows in parallel, and do not be surprised if a fourth activation needs an old one
freed.

**Pro / Enterprise:** skip the `.ulf`; set `UNITY_SERIAL`, `UNITY_EMAIL`, `UNITY_PASSWORD` instead.
(`UNITY_EMAIL` + `UNITY_PASSWORD` alone can activate a Personal licence too, but it is rate-limited and
takes a slot on every run; the `.ulf` is the better default.)
Unity allows three activated machines per serial — CI claiming one slot is normal, but do not run two
Unity workflows in parallel on the same licence.

### 2. Android upload key (create once, never lose it)

```bash
keytool -genkeypair -v -keystore user.keystore -alias shazdeh \
  -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 user.keystore    # macOS: base64 -i user.keystore -o -
```

Secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASS`, `ANDROID_KEYALIAS_NAME`,
`ANDROID_KEYALIAS_PASS`. Keep an offline copy of `user.keystore` and its passwords — losing the
upload key means a new app listing, and Play will not accept an update signed with a different key.

### 3. Unity version

`env.UNITY_VERSION` in `unity.yml` is pinned (`6000.0.32f1`). The detect job fails the build if the
project was last opened with a different version, which is exactly what you want: a version skew
between laptop and CI shows up as weird import errors otherwise.

### 4. iOS

`build-ios` runs on `macos-14` and only on manual dispatch (macOS minutes bill at 10×). It produces
an unsigned Xcode project. Signing and TestFlight upload come later with
`APPLE_APP_ID`, `APPLE_TEAM_ID`, `APPLE_API_KEY_ID`, `APPLE_API_KEY_ISSUER_ID` and an
`App Store Connect API key` (`.p8`), plus fastlane or `xcrun altool`. Nothing in the client may
depend on that until M2.

## Rules of thumb

- **Every store upload needs a strictly higher `versionCode`.** `0.${{ github.run_number }}` works as
  long as run numbers never reset (they do not, unless the workflow file is recreated). Before the
  first Play upload, switch to a version file the app itself reads, or Unity's built-in Android
  version code, and bump it in the PR.
- **Cache `client/Library`.** It is the difference between a 20-minute and a 6-minute build. The cache
  key includes `packages-lock.json` and the Unity version, so a package bump invalidates it.
- **Android on every PR, iOS on demand.** iOS is for TestFlight checkpoints, not for iteration.
- **`allowDirtyBuild: false`** in both builds: a build from a dirty tree is not reproducible and will
  bite during a store rejection.
- **Artifacts retire themselves** (30 days Android, 14 days iOS/CI). If a build is a release
  candidate, download it and archive it somewhere permanent — do not rely on Actions retention.
- **Server job is a no-op** until `server/package.json` exists. When the API lands, add
  `npm test` and `typecheck`, and keep the Postgres service from the `schema` job as its test database.
- **Secrets are never printed.** GameCI masks the licence; do not add `set -x` around anything that
  touches a keystore or a token.

## The custom build method

Both builds call `Shazdeh.EditorTools.CiBuild`, not GameCI's default builder. Reason: the default
needs a scene in Build Settings, and no `.unity` file is committed before the project is opened in the
editor once. `CiBuild` creates the boot scene from code (`ShazdehMenu.EnsureGreyBoxScene`) and then
builds, so a fresh clone is buildable. Details and the local equivalent: `docs/build.md`.

## What is deliberately not here yet

- No store publishing step (Google Play / App Store) — that arrives with `/replica-deploy`, together
  with the preflight gate: tests green, parity scored, `sweep.py` clean, listing linted.
- No nightly build. If a nightly is wanted later, add a `schedule:` trigger to `unity.yml` with
  `target: android` and a 30-day artifact retention.
- No Addressables build in CI. Sprites are drawn and validated here, but packing them into an atlas is
  an editor step, so it happens in the same job as the test run.
