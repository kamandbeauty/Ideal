# CI and builds (GitHub Actions + GameCI)

Two workflows, both dormant-until-needed:

| workflow | runs | what it proves |
| --- | --- | --- |
| `.github/workflows/ci.yml` | every push and PR | `replica/schema.sql` applies to a real Postgres 16, the 8 wallet-protecting constraints actually hold, the palette passes WCAG AA, and `Tokens.gen.cs` matches `tokens.json` |
| `.github/workflows/unity.yml` | pushes touching `client/**`, manual dispatch | EditMode + PlayMode tests, then an Android `.aab`; iOS Xcode project on manual dispatch |

The Unity jobs check for `client/ProjectSettings/ProjectVersion.txt` first and skip with a notice
until the project exists — the repo stays green while M0 is being built.

## One-time setup

### 1. Unity licence (needed by both workflows)

Unity's licence is per-machine; CI needs it as a secret.

**Personal / Plus:**
1. Run the helper action once in a scratch branch: `game-ci/unity-request-activation-file@v2`
   (it writes a `.alf` file as an artifact).
2. Upload that `.alf` to `license.unity3d.com` → download the `.ulf`.
3. `base64 -w0 Unity_v6000.x.ulf` (macOS: `base64 -i file -o -`) → paste into the secret
   **`UNITY_LICENSE`**.

**Pro / Enterprise:** skip the `.ulf`; set `UNITY_SERIAL`, `UNITY_EMAIL`, `UNITY_PASSWORD` instead.
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
- No art pipeline in CI. Addressables are built inside Unity; validating them needs the editor, so it
  happens in the same job as the test run once there is art to pack.
