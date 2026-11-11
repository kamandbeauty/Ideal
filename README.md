# LAST WALL: Zombie Siege — آخرین دیوار

A first-person wall-defence shooter for Android, built with Godot 4.7.2.
You are the gunner of a twin heavy machine gun on top of a fortified city
wall, with an RPG launcher and hand grenades at your side. The horde comes
through the ruined streets for the gate. Hold it.

بازی تیراندازی اول‌شخص دفاع از دیوار شهر برای اندروید. شما تیربارچیِ مسلسل
سنگین دولول روی دیوار هستید، آرپی‌جی و نارنجک دستی هم دارید، و موج‌های زامبی
از خیابان‌های ویران به سمت دروازه می‌آیند.

| What | Where |
| --- | --- |
| Godot project | [`ARTILLERY_FRONTLINE/`](ARTILLERY_FRONTLINE/) (folder name kept from the earlier project; it can be renamed freely) |
| Installable APK (ARM64) | [`delivery/LastWall-arm64.apk`](delivery/LastWall-arm64.apk), rebuilt by CI on every push |
| Build status and checksums | [`delivery/BUILD-STATUS.txt`](delivery/BUILD-STATUS.txt), [`delivery/SHA256SUMS.txt`](delivery/SHA256SUMS.txt) |
| Screenshots of the latest CI play-through | [`ARTILLERY_FRONTLINE/documentation/qa/`](ARTILLERY_FRONTLINE/documentation/qa/) |
| Phase reports | [`ARTILLERY_FRONTLINE/documentation/`](ARTILLERY_FRONTLINE/documentation/) |

The project is being built in phases. Phase 1 made the playable core: the
wall, the gun, one zombie type, the gate and wall health, and data-driven
waves. Phase 2 (this state) adds the RPG launcher, hand grenades, weapon
selection and area damage. See the project README for details and the
roadmap.

The image files and the `.max`/`.dds` files in this folder are reference
material supplied for the project; the game does not use them.
