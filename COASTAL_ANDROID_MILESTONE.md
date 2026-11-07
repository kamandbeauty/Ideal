# Coastal Android milestone — World War style direction

Date: 2026-11-07
Branch: `arena/40ad7d87-ideal`
Repository: `kamandbeauty/Ideal`
Source commit validated by CI: `4cf1959167d163b5cc33ef2f9120f3fe32d29112`
Package publication commit: `f996e8b6000e75ec7e3ec395a8014c4c1f498f29`
Successful CI run: `42358925625` (`validate` and `android` jobs passed)

## What changed after the two reference images

The uploaded screenshots were used as visual/layout direction only. No proprietary
assets, icons or UI artwork were copied.

- Fixed first-person defensive position; the camera never translates.
- Corrected the previous camera-covering weapon bug: twin barrels stay forward,
  the viewmodel sits in the lower foreground, and a framing regression check was added.
- Three escalating combined-arms rounds with sea, flank and rear approaches.
- Destructible infantry, tanks, transports, attack helicopter, fighter pass and
  landing craft; enemy counter tracks living targets.
- Twin heavy machine guns, 105 mm cannon, rocket pod, bazooka and autocannon.
- Round-one airstrike, repair, later helicopter support and airdrop; charges and
  independent cooldowns.
- Original mobile HUD: gear/settings, auto-fire, round pips, threat bearing,
  mission/enemies/timer, circular zoom/fire/weapon controls, support row,
  health bar, ammo/reload/rocket panel and Android safe-area handling.
- Coastal beach, animated ocean, smooth distant ridge, defenses, explosive
  barrels, rocket projectiles, explosions and smoke.

## Verified results

- Headless/integration suite: **233 checks, 0 failures**.
- Software-rendered coastal smoke: **28 checks, 0 failures**.
- Smoke covered: lower-foreground weapon framing, forward muzzles, fixed camera,
  touch drag, HUD fire button, auto-fire, reload, rocket damage to armor, bazooka
  selection, round-one airstrike, repair cooldown independence and results panel.
- Package inspection: ARM64, min SDK 24, target SDK 36, landscape, no INTERNET
  permission, ZIP CRC pass, APK/AAB signatures verified in CI.
- Local SHA-256 recheck of `delivery/SHA256SUMS.txt`: all OK.

## Downloadable development packages

- `delivery/Artillery-Frontline-arm64.apk` — primary ARM64 Android install.
- `delivery/Artillery-Frontline-compatibility.apk` — OpenGL compatibility fallback.
- `delivery/Artillery-Frontline-arm64.aab` — Gradle bundle.

Signing is an **ephemeral development key**, not a store-release signing identity.

## Important limits

- No physical Android device was available. An attempted software x86_64 emulator
  boot in CI timed out without KVM and was removed from the required workflow.
  Therefore this is **not** device-certified gameplay, touch comfort, thermal or
  sustained-FPS validation.
- CI smoke performance is desktop software rendering (llvmpipe), about 15.9 FPS
  in the final low-tier snapshot; it is not an Android GPU benchmark.
- Assets are original procedural/PBR work. The scene is playable and follows the
  requested layout/atmosphere, but it does not yet match the reference game's
  full production art polish. Next visual refinement should wait for approval of
  this first playable milestone.

## Install and play

Install the ARM64 APK on a landscape Android phone. Main menu: **DEPLOY / COASTAL
DEFENSE**. Drag the battlefield to aim; use the right-side FIRE/ZOOM/WEAPON
controls and bottom support/reload/rocket controls. Survive all three waves.
