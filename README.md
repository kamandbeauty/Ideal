# Ruby Run 3D / روبی ران

A portrait Android **third-person runner + auto shooter + number-gate game** built with Unity 6.3 LTS, C#, URP, Input System, and Cinemachine. Package: `com.studiojavid.rubyrun`.

## Current vertical slice

Stage 1 is implemented end-to-end in source: Ruby auto-runs with smooth touch drag; ten real pooled soldiers follow an adaptive formation; Ruby and soldiers acquire targets and fire pooled 3D projectiles; three gate decisions modify the army; three enemy archetypes move/attack/take damage/die; victory, game over, retry, next, coins, upgrades, skins, daily reward, settings, local saves and offline play are functional.

All current character/environment art is **original procedural low-poly placeholder art**, not copied or downloaded. It uses custom generated meshes rather than Unity primitive GameObjects and exposes replaceable visual roots. It is coherent enough for engineering/testing, but it is not represented as final commercial character art; final rigged models and authored animation still require art-direction approval.

## Unity

- Editor: `6000.3.21f1` (Unity 6.3 LTS)
- Rendering: URP 17
- Input: Input System EnhancedTouch
- Camera: Cinemachine 3 package with damped mobile follow fallback
- Android: portrait, ARM64, IL2CPP, min API 24, target API 36

Open `Assets/Scenes/Bootstrap.unity` and press Play. The game requires no network service or account.

## Structure

```text
Assets/
  Art Audio Materials Prefabs Scenes UI VFX
  Scripts/
    Army Combat Core Data Editor Enemies Gates Player Services Stage UI
  Tests/Editor
Packages/
ProjectSettings/
docs/
```

See [architecture](docs/ARCHITECTURE.md), [Data Safety](docs/DATA_SAFETY.md), [Privacy Policy](docs/PRIVACY_POLICY.md), and [release checklist](docs/RELEASE_CHECKLIST.md).

## CI migration note

`docs/unity-android-build.yml` is the reviewed Unity workflow template. Copy it to `.github/workflows/android-build.yml` through GitHub after the Unity source push; the Arena GitHub App cannot modify workflow files. Delete/replace the old Godot workflow rather than keeping both.

Unity CI additionally requires `UNITY_LICENSE`, `UNITY_EMAIL`, and `UNITY_PASSWORD`. Signed release builds require `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`. No keystore or credential belongs in Git.

## Status

This repository is a source-complete vertical-slice implementation, **not yet a completed commercial release**. Unity compilation, device profiling, final art/animation, signed APK/AAB generation, final manifest inspection, and store testing remain release blockers.
