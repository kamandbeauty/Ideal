# LAST WALL: Zombie Siege — آخرین دیوار

A first-person wall-defence shooter for Android, built with Godot 4.7.2.
You are the gunner of a twin heavy machine gun on top of a fortified city
wall, with an RPG launcher and hand grenades at your side. The horde comes
through the ruined streets for the gate: walkers, runners, brutes, and in
the eighth and last wave the Behemoth. Hold it.

بازی تیراندازی اول‌شخص دفاع از دیوار شهر برای اندروید. شما تیربارچیِ مسلسل
سنگین دولول روی دیوار هستید، آرپی‌جی و نارنجک دستی هم دارید، و هشت موج زامبی
(عادی، دونده، سنگین‌وزن و در موج آخر غول‌پیکر) از خیابان‌های ویران به سمت
دروازه می‌آیند.

| What | Where |
| --- | --- |
| Godot project | [`ARTILLERY_FRONTLINE/`](ARTILLERY_FRONTLINE/) (folder name kept from the earlier project; it can be renamed freely) |
| Installable APK (ARM64) | [`delivery/LastWall-arm64.apk`](delivery/LastWall-arm64.apk), rebuilt by CI on every push |
| Build status and checksums | [`delivery/BUILD-STATUS.txt`](delivery/BUILD-STATUS.txt), [`delivery/SHA256SUMS.txt`](delivery/SHA256SUMS.txt) |
| Screenshots of the latest CI play-through | [`ARTILLERY_FRONTLINE/documentation/qa/`](ARTILLERY_FRONTLINE/documentation/qa/) |
| Phase reports | [`ARTILLERY_FRONTLINE/documentation/`](ARTILLERY_FRONTLINE/documentation/) |

The project is being built in phases. Phase 1 made the playable core: the
wall, the gun, one zombie type, the gate and wall health, and data-driven
waves. Phase 2 added the RPG launcher, hand grenades, weapon selection and
area damage. Phase 3 added the runner, the brute and the boss, and the full
eight-wave siege. Phase 4 redrew the HUD and the menus, added the visual
and audible feedback of a fight, and laid everything out for 20:9 and 4:3
screens as well. Phase 5 (this state) audited and cleaned the project,
fixed what the audit found, rebuilt the automatic quality control so that it
can be tuned from one file, and switched the delivered APK to a release
build. **The game has not yet been run on a phone or an emulator**: the APK
is built, signed and inspected, and the game is played by a script on a
desktop. The first device test is the next step; the Phase 5 report lists
what to look at. See the project README for details and the roadmap.

The image files and the `.max`/`.dds` files in this folder are reference
material supplied for the project; the game does not use them.
