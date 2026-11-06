# QA report — ARTILLERY FRONTLINE vertical slice / MVP candidate

Date: 2026-11-06
Branch: `arena/40ad7d87-ideal`
Verified build source commit: `e4407def4dda0dbfa802f97ba22976557b71f982`
Final package publication commit: `f6f3568` (see Git history for the full hash)
Engine: Godot **4.7.2 stable** (`4.7.2.stable.official.ed1daf0bf`)
Asset authoring: Blender **5.0.1** in GitHub Actions

## Result summary

- **197 headless assertions, 0 failures** in the final CI validation job.
- **17 software-rendered smoke checks, 0 failures**; first mission completed through real UI fire/reload paths.
- All five missions exercised by the headless scene/physics campaign integration suite.
- ARM64 **APK**, **AAB** and **Compatibility APK** exported successfully in CI run **42204972594**.
- APK v2/v3 signatures verified; AAB JAR signature explicitly applied and verified; unsigned-AAB regression check rejects the earlier bad bundle.
- Local post-download SHA-256 checks and Python package inspection passed.
- **No Android device or emulator was available. This is not device certification or a mobile performance claim.**

## Executed checks

| Check | Where executed | Result |
|---|---|---|
| Environment inspection and free-tool bootstrap | Sandbox + CI | Debian sandbox initially lacked Godot/Blender/Java/SDK; CI supplied free toolchains |
| Checksum-pinned Godot editor install | CI | SHA-256 matched; version reported 4.7.2 stable |
| Project import / GDScript compilation | CI headless | Pass |
| Unit + integration runner | CI headless | **197 checks, 0 failures** (`artillery-test-results.json`) |
| Full campaign scene integration | CI headless | `sr02`–`sr05` completed with real terrain, ballistics, AI, reload and ammunition supply; `sr01` covered by the detailed mission suite |
| Software-rendered gameplay smoke | CI Xvfb/llvmpipe Compatibility | **17 checks, 0 failures** (`documentation/qa/smoke-report.json`) |
| Touch drag, UI fire button, fire-control solution, upgrade persistence | CI smoke | Pass |
| Original Blender model export | Asset CI | Five GLB + BLEND sets present; named pivots verified |
| Android APK/AAB/Compatibility export | CI run 42204972594 | Pass |
| APK signature/certificate inspection | CI `apksigner` | v2 and v3 verified for both APKs |
| AAB signature inspection | CI `jarsigner` + ZIP inspection | `jar verified`; META-INF signature block present; expected self-signed development-certificate warnings |
| ARM64-only payload, project data, ZIP CRC | CI + local Python | Pass |
| Package IDs, min/target SDK, landscape, no INTERNET | CI `aapt2` + local Python | Pass: `com.frontline.artillery`, `.compatibility`; min 24 / target 36 for APKs; landscape orientation; no INTERNET |
| SHA-256 delivery checksums | Local after CI publication | `sha256sum -c delivery/SHA256SUMS.txt`: all OK |
| Credential/keystore scan | Local tracked-file scan | No private keys, keystores or literal signing passwords found |

Representative commands executed by CI:

```sh
godot --headless --path ARTILLERY_FRONTLINE --editor --import
godot --headless --path ARTILLERY_FRONTLINE --script res://tests/run_tests.gd
xvfb-run -a -s '-screen 0 1440x810x24' godot --path ARTILLERY_FRONTLINE \
  --rendering-method gl_compatibility --resolution 1440x810 -- --smoke-test
godot --headless --path ARTILLERY_FRONTLINE --export-debug 'Android APK' res://../delivery/Artillery-Frontline-arm64.apk
godot --headless --path ARTILLERY_FRONTLINE --export-debug 'Android AAB' res://../delivery/Artillery-Frontline-arm64.aab
godot --headless --path ARTILLERY_FRONTLINE --export-debug 'Android Compatibility' res://../delivery/Artillery-Frontline-compatibility.apk
```

Local post-publication inspection:

```sh
sha256sum -c delivery/SHA256SUMS.txt
python3 ARTILLERY_FRONTLINE/tools/verify_packages.py delivery
```

## Gameplay smoke observation

Mission `sr01 / FIRST LIGHT`: **2 shots, 2 hits, 100% accuracy, 3 stars, 535 credits, 2 upgrade points**, completed in about **11.3 s** of mission time in the accelerated smoke path. The smoke driver forced manual **MEDIUM** quality so AUTO desktop preference would not mask the intended profile.

Final desktop CI snapshot:

- Renderer: **Compatibility / OpenGL under Xvfb + llvmpipe software rasterization**
- Tier: medium, 3D scale 0.82
- FPS: **12.6**, smoothed frame interval **79.48 ms**
- Draw calls: **372**
- Objects: **1189**
- Primitives: **126158**

Earlier runs on the same software renderer varied roughly from 12 to 20 FPS. These numbers measure a CPU-rasterized CI desktop, **not** an Android GPU. No sustained 30/60 FPS mobile claim is made.

## Visual evidence

- `documentation/qa/battlefield.png`
- `documentation/qa/impact_t01.png`
- `documentation/qa/impact_t03.png`
- `documentation/qa/mission-results.png`
- `documentation/qa/upgrades.png`

Inspected fixes include terrain facing/collision, model forward-axis correction, height-conforming roads without the earlier z-fighting bands, HUD top-bar layout, non-zero predicted impact range, moving-target lead, and capture of the final explosion before the results screen hides the battlefield.

## Android package facts

See `delivery/package-validation.json`, `delivery/SHA256SUMS.txt`, `delivery/*-signature.txt`, and the decoded manifest/badging text files.

- Primary APK: `com.frontline.artillery`, ARM64, min SDK 24, target SDK 36, landscape, no INTERNET.
- Compatibility APK: `com.frontline.artillery.compatibility`, ARM64, OpenGL command-line fallback, same inspected SDK/orientation/offline facts.
- AAB: Gradle-built ARM64 bundle; preset minimum SDK override 26; explicitly JAR-signed and verified.
- Signing identity in this run: **ephemeral development key**, `CN=Artillery Frontline Development, O=Frontline, C=DE`. It is not a persistent Play release identity. The temporary certificate expires in about 30 days; reinstalling builds from different ephemeral keys may require uninstalling the previous test build.

## Issues found and corrected during validation

- Godot 4.7 API mismatches in particles, MultiMesh, ImmediateMesh, environment and signals.
- Moving-target fire-control misses: added waypoint-aware lead and iterative flight-time solve.
- Terrain/road winding and collision misses: corrected facing, enabled backface terrain collision, conformed road grids to the height field.
- Android export configuration: enabled ETC2/ASTC import; removed invalid non-Gradle SDK assumptions; installed Gradle template `.build_version` and `.gdignore`.
- Release-signing environment variable typo corrected.
- Gradle AAB initially exported unsigned: CI now signs/verifies the bundle and the verifier rejects unsigned output.
- Orientation verification no longer depends on brittle `aapt2 xmltree` integer formatting; it requires the decoded attribute plus landscape feature inference.
- Headless dummy-audio playback leaks were addressed by skipping dummy-driver playback in logic tests and stopping/releasing pooled streams at shutdown.

## Not executed / remaining limitations

- No `adb install`, physical-device touch test, emulator run, Android GPU profiling, thermal/throttling test, suspend/resume test, audio-focus test or force-stop save test.
- No store-release signing unless repository Secrets are configured and a new CI run is executed.
- No baked LightmapGI, raymarched volumetrics, unlimited rigid-body fracture, streaming open world, multiplayer, cloud save, ads or IAP.
- One battlefield and one configurable weapon in this slice; enemy AI is patrol/alert/staged destruction rather than a full combined-arms combat simulation.
- Earlier CI emitted non-fatal `aapt2` themed-icon resource warnings; launcher appearance on Android 13+ themed icons remains device-untested.
- Software-rendered screenshots/performance are not representative of final mobile visual quality or frame rate.
