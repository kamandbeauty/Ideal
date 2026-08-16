# Android and signing

- Package: `com.studiojavid.rubyrun`
- Version: `1.0.0` (`versionCode 1`)
- Orientation: portrait
- Minimum SDK: API 24
- Target/compile SDK: API 36
- Architectures: arm64-v8a for AAB; arm64-v8a + armeabi-v7a for test APK
- Base permissions: none (network permissions disabled)

The workflow builds without Android Studio using Godot 4.7.1, Temurin Java 17, Android command-line SDK, and official Godot export templates. As of this repository review date, API 36 is configured. Re-check the Google Play target-SDK deadline immediately before submission.

## Required GitHub Secrets

`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`. The release job fails clearly if any is absent. The keystore is decoded only into the ephemeral runner. If the key password differs from the store password, the ephemeral copy is normalized because Godot's exporter exposes one release password field. No signing material is committed or uploaded as an artifact.

Run the `Validate and build Android` workflow manually to create signed release artifacts. Do not create `v1.0.0` until all release-checklist blockers are cleared. Production ad identifiers, if ever needed, must also be injected from secrets/configuration and must never be committed.
