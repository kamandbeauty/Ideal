# Art pass 04 — uploaded infantry replaces the procedural stand-in

## what changed

The attacking enemy infantry is now built from the **user-supplied** 3ds Max
model (`D0307048A1.max` + three `.dds` atlases) instead of the lofted procedural
soldier from pass 03. The pass-03 behaviour is untouched: the same 11-bone gait,
aim, fire, stagger and constrained physical ragdoll drive the new mesh.

| | pass 03 | pass 04 |
| --- | --- | --- |
| Source | procedural lofts/spheres | uploaded `.max`, 1,927 triangles |
| Shading | triplanar procedural PBR | three UV-mapped diffuse atlases |
| Exported triangles | 23,796 | 4,487 (1,927 body + 2,560 rifle) |
| Materials | 13 primitives | 3 infantry atlases + 3 rifle surfaces |
| Atlases in GLB | none | 3 embedded PNGs |

Full source chain, format notes and permission record:
[`uploaded-infantry-provenance.md`](uploaded-infantry-provenance.md).

## pipeline

    python3 ARTILLERY_FRONTLINE/tools/import_max_soldier.py   # stdlib only
    blender --background --python ARTILLERY_FRONTLINE/tools/create_models.py -- --only soldier

`.max` is proprietary and opens in neither Blender nor Assimp on Linux, so the
converter parses the OLE/CFB container and the 3ds Max chunk tree directly, and
decodes DXT1/DXT5 to PNG. It also authors what the upload lacks: the source is a
static A-pose with **no Skin modifier, no weights and no weapon**.

The converter builds the 11-bone rig, weights the body over its three nearest
bone segments (gear shells stay rigid), solves a two-bone IK onto a diagonal
low-ready carry, and **bakes** that pose into the vertices. This matters because
`enemy_soldier.gd` only adds arm *compliance* — it never re-solves a grip — so the
rest pose must already hold the rifle. The rifle itself is original project
geometry, declared as data so the Blender build and the local preview agree.

## exporter fixes

Three latent bugs surfaced once real UV-mapped, skinned geometry went through
`export_glb()` and the Khronos validator:

1. **Index accessors were `VEC3`, not `SCALAR`.** Every triangle count reported by
   the art gates was a third of the real one, and strict validators reject it.
   Budgets are re-stated against true counts (the soldier ceiling is now
   1,200–60,000; the machine ceiling moved to 400,000 for the same reason).
2. **`target: null` on the inverse-bind bufferView.** `target` is optional but
   must be an integer when present; it is now omitted.
3. **Skinned meshes were not scene roots.** glTF ignores their node transform, so
   they are promoted out of the pivot hierarchy.

UV V is also flipped on export: Blender/3ds Max are V-up, glTF `TEXCOORD_0` is
V-down. Existing models use triplanar or tiling surfaces, so this is visually
inert for them and correct for the atlases.

The three material names (`Uploaded infantry body/gear/head`) deliberately fall
through `MaterialLibrary.for_model_material`, so the imported atlases are never
replaced by triplanar procedural surfaces.

## verification

Local, before pushing:

- Real Blender 4.2 background build of all 15 models.
- `verify_art_pass.py` — pivots, budget, UV0, three embedded opaque atlases,
  target-less image bufferViews, skin with `JOINTS_0`/`WEIGHTS_0`.
- **Khronos `gltf-validator`: 0 errors, 0 warnings on all 15 GLBs.**
- A software rasteriser that decodes the *exported GLB* (embedded atlases, node
  hierarchy, skinning) and replays `_animate_skeleton` across a full stride plus
  aim and recoil: the hands stay within **8 mm** of their grip targets.
- Blender Cycles studio render, `qa/art-pass-02/soldier-studio.png`.

CI on `33497b1`:

- **Author original Blender assets** — success, including the new converter step
  and the Khronos gate.
- **ARTILLERY FRONTLINE** — success. **283 checks / 0 failures** (+21 new infantry
  assertions), coastal smoke 0 failures, zero `SCRIPT ERROR`/`Parse Error`/
  `SHADER ERROR` in import, test and smoke logs.
- ARM64 packages rebuilt and re-verified.

The new runtime assertions check that the infantry imports as a `Skeleton3D`
with all eleven bones, that all three meshes are skinned, that each atlas
survives as a UV-mapped (not triplanar) albedo, and that the rifle and muzzle sit
in the authored rest pose.

## packages

Source commit `33497b1`; packages published by CI in `fde0da2`.

| File | Bytes | SHA-256 |
| --- | --- | --- |
| `delivery/Artillery-Frontline-arm64.apk` | 52,506,405 | `aa4c7f6b16bbd78e9ff1312e298f29ce4d3ee5105b8ce5fb958b4b865d239c57` |
| `delivery/Artillery-Frontline-arm64.aab` | 51,943,665 | `06750b82c11fdd32ff085b897fc056a973dd246fbda184109e4c16f5643717f5` |

ARM64, minSdk 24 / targetSdk 36, landscape, offline (no INTERNET permission),
ZIP CRC and apksigner/jarsigner verified. Signing uses an ephemeral development
key, not a store release key.

## limits

- **No finger bones.** The uploaded hands are modelled open and there is nothing
  to curl, so the fingers do not wrap around the grip.
- The uploaded mesh is **third-party, owner-supplied**. The project owner has
  stated they hold permission to use it in this game, so it is retained; the
  provenance note records that grant. This is not an independent licence audit.
- Still **no Android device or emulator execution**. All runtime evidence is
  desktop Godot 4.7.2 under Xvfb/llvmpipe; mobile performance is not claimed.

## خلاصهٔ فارسی

پیاده‌نظام دشمن حالا از همان مدل سه‌بعدی‌ای ساخته می‌شود که خودتان فرستادید
(`D0307048A1.max` به‌همراه سه تکسچر `.dds`)، نه سرباز процедурی قبلی. رفتار مرحلهٔ ۳
دست‌نخورده باقی مانده: همان راه‌رفتن، نشانه‌گیری، شلیک و رگ‌دال فیزیکی روی مدل جدید
اجرا می‌شود.

فایل `.max` یک قالب انحصاری است و لینوکس نه Blender و نه Assimp بازش نمی‌کند؛
برای همین یک مبدل نوشتم که فقط با کتابخانهٔ استاندارد پایتون خود فایل را می‌خواند و
تکسچرهای DXT را به PNG تبدیل می‌کند. مدل اصلی ایستاده و بدون اسکلت و بدون اسلحه
بود، پس اسکلت ۱۱ استخوانی، وزن‌دهی و حالت گرفتن اسلحه را خودم ساختم و در مش پختم
تا سرباز از همان ابتدا تفنگ را در دست داشته باشد. تفنگ هم geometry اصلی پروژه است.

سه ایراد قدیمی خروجی‌گیر glTF هم پیدا و رفع شد (شاخص‌ها، `target: null` و ریشه
نبودن مش پوست‌دار). حالا هر ۱۵ مدل با اعتبارسنج رسمی Khronos بدون هیچ خطا و
هشداری قبول می‌شوند. در CI آزمون‌ها ۲۸۳/۰ و smoke ساحلی بدون خطا سبز شد و بسته‌های
ARM64 دوباره ساخته و راستی‌آزمایی شدند.

اجازهٔ استفاده از مدل ارسالی را خودتان اعلام کرده‌اید، بنابراین مدل نگه داشته
شد و این اجازه در یادداشت منبع ثبت شد؛ انگشت‌ها همچنان استخوان ندارند و دور
قبضه مشت نمی‌شوند. اجرای واقعی روی دستگاه اندروید انجام نشده است.
