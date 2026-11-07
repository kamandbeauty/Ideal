# Android export notes

An Android export preset is included at `export_presets.cfg`.

## Important placeholder

The preset currently uses `com.example.princespalace` only as a temporary debug package identifier. **Do not publish or distribute a release build with this identifier.** Before generating a store build, replace it with the final reverse-DNS package ID selected by the app owner. Changing the package ID later creates a separate Android app identity and separate app data.

## Local debug export

1. Install the Godot 4.4.1 export templates matching the editor version.
2. Configure the Java SDK and Android SDK paths in Godot Editor Settings.
3. Ensure Android platform/build tools and NDK are installed.
4. From the repository root, create the output directory and run:

```sh
mkdir -p godot-port/build
godot --headless --path godot-port --export-debug "Android" godot-port/build/princespalace-debug.apk
```

The current preset includes ARMv7 and ARM64. A debug export is for local device validation only.

## Release signing

A release APK/AAB must use an owner-controlled keystore. Do not commit the keystore or passwords to this repository. Keep signing credentials in a secure secret manager and configure the export environment variables documented by Godot.

## Still required before release

- Confirm the final Android package ID and display name.
- Confirm minimum Android version and target SDK.
- Configure a production keystore and release signing.
- Validate permissions and offline/online behavior.
- Export and install on real Android devices, then run gameplay, save/restore, performance and orientation tests.
