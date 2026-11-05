# Android build and signing

## Toolchain

- Godot 4.7.2 stable standard editor and matching export templates.
- JDK 17.
- Android SDK platform 36, build-tools 36.1.0, platform-tools.
- Godot Android Gradle source template for AAB; APK presets can export without Gradle.
- ARM64-v8a only in this milestone. Minimum SDK 26 for Mobile/Vulkan package; 24 for Compatibility package. Target SDK 36.

The sandbox originally had no Godot, Blender, Java, Android SDK, templates or device. Engine/SDK downloads were network-restricted. GitHub Actions provides the free build toolchain; the editor archive is checksum-pinned. Blender models are authored by the separate asset workflow.

## Automated build

Run **ARTILLERY FRONTLINE** workflow on the session branch. It performs import, unit/integration tests, a software-rendered gameplay smoke test, then APK/AAB export. It verifies APK signatures, AAB jarsignature, ARM64 native libraries, project payload, ZIP CRC and absence of INTERNET permission.

Presets:

1. `Android APK` — Mobile renderer, ARM64.
2. `Android AAB` — Gradle bundle, ARM64.
3. `Android Compatibility` — OpenGL ES fallback renderer, ARM64; separate package suffix `.compatibility`.

## Signing

For development validation only, CI creates a random temporary RSA keystore in runner temp storage and exports debug-signed packages. These are installable test builds, **not** upload-to-Play release identities. Reinstalling a build from a different ephemeral key may require uninstalling the previous test build.

For a persistent release identity, configure GitHub Secrets:

- `ARTILLERY_KEYSTORE_BASE64`
- `ARTILLERY_KEYSTORE_PASSWORD`
- `ARTILLERY_KEY_ALIAS`

The workflow decodes the keystore only into runner temp storage and passes credentials through Godot's documented environment variables. It then uses `--export-release`. Never commit keystores, passwords, `key.properties`, or local SDK paths. Preserve the real release keystore outside this repository; losing it prevents updates under the same signing identity.

## Local export

Install matching templates, configure Java/Android SDK paths in Godot Editor Settings, install the Android build template for AAB, set signing through editor/environment, then:

```sh
godot --headless --path ARTILLERY_FRONTLINE --export-release "Android APK" ../delivery/Artillery-Frontline-arm64.apk
godot --headless --path ARTILLERY_FRONTLINE --export-release "Android AAB" ../delivery/Artillery-Frontline-arm64.aab
```

A successful export is not an installation test. Device QA must cover touch comfort, safe areas, suspend/resume, thermal throttling, Vulkan and OpenGL startup, audio focus, save persistence after force-stop, and sustained frame time. No Android device/emulator was available in the initial sandbox.
