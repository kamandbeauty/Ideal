# Android device test — LAST WALL 0.6.1

Repeatable procedure for a real ARM64 phone. **CI does not run this.**
Nothing in this file is evidence that a device was used.

## Device record (fill in on the phone)

| Field | Value |
| --- | --- |
| Date | |
| Tester | |
| Device model | |
| Android version | |
| GPU / renderer (Settings → show FPS: Compatibility or Mobile) | |
| Display refresh (Hz) | |
| Quality setting | auto / low / medium / high |
| Starting FPS (title, idle street) | |
| RAM used after one match (system settings) | |
| Thermal (cool / warm / hot after 15 min) | |
| APK file / SHA-256 | `delivery/LastWall-arm64.apk` |
| Package | `com.studiojavid.zombiesiege` |
| Version | 0.6.1 (versionCode 7) |

Install: uninstall any previous build first if the signature is the
throw-away CI key. Copy the APK, allow that source, open it.

If the Mobile renderer blacks or tears, install
`LastWall-compatibility.apk` (`com.studiojavid.zombiesiege.compatibility`)
from the workflow artifacts and record that.

## Procedure

Do these in order. Tick only what was actually done on the device.
Record FPS with **Show FPS** on (Settings). Note hitches, audio cuts,
and anything that looks stretched or black.

1. **Menu and settings.** Title in Persian and English. Volume sliders.
   Quality low / medium / high / auto. Each quality change must keep a
   picture on screen (no black frame, no stretched 3D). Back button
   leaves settings, then the title, then the app.
2. **Touch aiming.** Drag on the street. Sensitivity and invert Y.
   The gun follows the finger; the crosshair stays on what you meant.
3. **Continuous fire.** Hold FIRE for a full belt. Recoil, tracers,
   brass, sound. Let go: the gun stops on that frame, not after a pause.
4. **Weapon switching.** Shoulder the RPG, fire one rocket, return to
   the machine gun. Empty the launcher: it puts itself away.
5. **Reload.** Tap RELOAD mid-belt. Belt fills. Dry-fire click when empty
   and reloading.
6. **Zoom.** Sight button. Street 2.5× closer, aim slower under the
   finger. Toggle off. Survives pause.
7. **Grenade.** Throw three. Arc, bounce, blast, pouch count.
8. **RPG.** Direct hit and a miss into the street. Blast radius. No
   damage to the wall.
9. **Large crowd.** Last waves of a stage, or quality high with auto
   off. Record FPS, worst hitch, and whether the governor (auto) drops
   the 3D scale. The picture must not tear when scale moves.
10. **Audio.** Theme and wind on the title. Shots, reloads, groans,
    blasts, victory / defeat. Mute music: wind stays. Mute effects:
    shots go quiet. After MAIN MENU, no stuck burst or groan.
11. **Memory.** One full stage, then a second. No climb that ends in a
    kill. Note RAM after each.
12. **Thermal / frame-time.** Fifteen minutes of play. Phone warm is
    expected; a sustained drop below 30 fps on auto is a fail for that
    device — record the scale and tier the governor settled on.
13. **Pause, restart, save.** Pause during a wave. Resume. AGAIN after
    defeat. Kill the app from recents, reopen: language, gun, quality
    and opened stages are still there.
14. **Update path.** If a *production* keystore signed this APK, install
    it over the previous production build without uninstalling. Save
    must survive. A development-signed APK will not install over
    another development build — uninstall first, and say so.

## Pass / fail

A step passes only with a device, a recorded model, and notes.
Software-rendered CI play is not this procedure.
