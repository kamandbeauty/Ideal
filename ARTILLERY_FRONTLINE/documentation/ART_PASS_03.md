# Art pass 03 — organic infantry, physical death, real ballistics, detailed war machines

Scope (user request, Persian): «وقت بزار و کارکتر ها و همه ی حرکاتشون ، جزئیات سلاح و ضربه شلیک، تمام ماشین های جنگی را با ریزترین جزئیاتشون طراحی کن»

This pass replaces the segmented/robot infantry with a skinned humanoid, makes
death a constrained physical ragdoll that stays on the beach, routes **all**
damage through swept projectile collisions (both directions), adds explicit hit
/ kill confirmation, and rebuilds every war machine with articulated pivots and
fine surface detail. All geometry is original Blender authoring; no reference
assets are copied.

## infantry model and motion

- `soldier.glb`: one skin, 11 joints (Hips/Torso/Head/LegL,R/KneeL,R/ArmL,R/ElbowL,R),
  13 skinned primitives, 7,932 triangles. Inverse bind matrices + JOINTS_0/WEIGHTS_0
  are verified by `tools/verify_art_pass.py` (`documentation/art-pass-03.json`).
- Gear (helmet, vest, pouches, belt, boots, radio, rifle) is weighted to the nearest
  bone segment so it follows the body instead of floating as separate boxes.
- `enemy_soldier.gd` drives a procedural Skeleton3D gait: stride/knee lift, hips
  bob/roll/yaw, torso counter-lean, head stabilization, arm compliance, idle sway,
  aim lean, fire recoil + muzzle flash/light, stagger and cover crouch.
- Rifle/Muzzle remain attached to the torso bone; recoil is guarded when the
  importer exposes them as BoneAttachment3D.

## physical death (no sink tween)

- `soldier_ragdoll.gd` builds a `PhysicalBoneSimulator3D` under the imported
  skeleton with 11 constrained bodies: hinge knees/elbows (+5/−110°), cone
  hips/spine/head/shoulders, per-bone mass, friction 0.85, replace damping.
- Lethal hits apply a directed impulse (damage-scaled, clamped 24–95 + upward kick)
  at the actual impact point. Corpses collide with terrain only (layer 16), settle
  after sleeping/timeout, keep their final pose and remain visible.
- Missing-asset fallback is still a real RigidBody3D corpse, never a tween sink.

## real projectile damage and shot feedback

- Player emplacement has a real StaticBody3D hitbox (layer 8). Enemy rifle/heavy
  fire launches pooled bullets with mask 13 (terrain/cover/player); damage occurs
  only in `_on_bullet_impact` when the swept ray actually hits that hitbox.
- Player bullets use mask 7 and call `receive_damage(amount, hit_point, direction)`
  on soldiers/vehicles/aircraft/craft. The old probabilistic `pending_enemy_hits`
  scheduler is deleted.
- Spread is applied once in camera axes about the raw bore direction; high-pitch
  fire no longer corkscrews/doubles the cone.
- HUD crosshair shows a white X on confirmed hit (0.18 s) and red X on kill
  (0.45 s) with distinct UI sounds; impact sparks/blast remain at the real hit point.

## war machines (Blender pivots + runtime articulation)

| Model | Triangles | Articulation / detail |
| --- | ---: | --- |
| warden tank | 62,436 | WheelL/R0–4 + sprocket/idler, track runs, ERA blocks, hinges, tow cables; Turret/BarrelPivot/RecoilAssembly/Muzzle, cupola, hatches, AA mount, smoke launchers, rangefinder |
| nomad APC | 20,119 | WheelL/R0–3, leaf springs/shocks, hull detail; Turret/BarrelPivot/RecoilAssembly/Muzzle, ammo box |
| helicopter | 4,987 | Rotor + 4-blade TailRotor, mast/links/tips, nose/windows/rivets, exhausts, stub wings/pods, boom ribs, skids, pitot |
| fighter | 5,170 | AileronL/R, ElevatorL/R, Rudder, AfterburnerL/R, missiles, nozzles, tanks |
| landing craft | 5,319 | Ramp, Radar, PropellerL/R, rudders, ribs/fenders, ramp treads/hinges/winches, bow gun |
| patrol boat | 3,356 | Radar, PropellerL/R, BarrelPivot/RecoilAssembly/Muzzle, bow wedge, strakes, fenders, cabin/roof, depth charges |

Runtime: `enemy_vehicle.gd` rolls wheels by speed/radius, suspends the hull, yaws
the turret and pitches the barrel toward the objective, springs the recoil
assembly, flashes the muzzle and leaves a persistent wreck. `enemy_aircraft.gd`
spins rotor/tail rotor, banks control surfaces, flickers afterburners and crashes
into a persistent wreck resting on terrain. `landing_craft.gd` and
`coastal_background_action.gd` spin propellers/radar and animate ramp/bob; deaths
leave visible wrecks instead of hiding the model.

## validation (GitHub Actions, Godot 4.7.2-stable official)

- Assets workflow run **42383239773 ✅** (`e6782a4`): Blender authoring + glTF
  gates; bot published models/source/evidence (`e38cfc0`).
- Main workflow run **42384819381 ✅** (`720528e`): import gate clean; unit +
  integration **257 checks / 0 failures** (`artillery-test-results.json`,
  `documentation/qa/tests.log`); main smoke 18/0; coastal smoke **33/0**
  (`documentation/qa/coastal-smoke-report.json`).
- New regression `tests/integration/test_coastal_pass3.gd`: player hitbox layer,
  swept bullet damages a soldier + hit confirmation, lethal hit creates physical
  corpse resting above terrain and still visible, enemy projectile damages player
  only on real impact, camera-axis spread cone at 55° pitch, tank wheel/recoil and
  helicopter tail-rotor pivots.
- Software-rendered coastal snapshot (Xvfb/llvmpipe, low tier, **not Android
  hardware**): 9.4 fps, 302 draws, 179,930 primitives, scale 0.62. The detailed
  pass intentionally raises primitive count; mobile hardware performance is not
  claimed from this renderer.
- Android packages rebuilt from `720528e` and verified by CI (`delivery/`):
  - `Artillery-Frontline-arm64.apk` — 52,001,910 B, SHA-256
    `70f8a7f9ab87af466d81708bb03ae500cf1a7e9e4be0d44ca90656ba4308fbbe`
  - `Artillery-Frontline-arm64.aab` — 51,567,240 B, SHA-256
    `fb68784f9071791fdff383670e2d7fec6f26d0441a74100b41a12302eb1afdd3`
  - ARM64, minSdk 24 / targetSdk 36, landscape, offline (no INTERNET), ZIP CRC,
    apksigner/jarsigner verified. Signing is an ephemeral development key, not a
    store release. No device/emulator execution was possible in this environment.

## evidence

- `documentation/qa/art-pass-03/before-after.jpg` — pass-02 vs pass-03 soldier
  studio and beach infantry.
- `documentation/art-pass-03.json` — skin/joint/pivot/triangle gates.
- `documentation/qa/coastal-infantry.png`, `coastal-fire.png`,
  `coastal-explosion.png`, `coastal-weapon-reload.png`, `coastal-results.png`.
- Pass-02 evidence is preserved (`ART_PASS_02.md`, `art-pass-02.json`,
  `qa/art-pass-02/before-after.jpg`).

## خلاصهٔ فارسی

پیادهٔ نظامی دیگر ربات قطعه‌قطعه نیست: یک اسکلت پوست‌دار ۱۱ استخوانی با راه‌رفتن،
بیکاری، نشانه‌گیری، شلیک، تلوتلو و سنگرگیری رویه‌ای دارد. مرگ، رگ‌دال فیزیکی
مقیدشده است که روی ساحل می‌ماند و در شن فرو نمی‌رود. آسیب دوطرفه فقط از برخورد
واقعی گلولهٔ swept می‌آید و hit/kill روی مگسک تأیید می‌شود. تانک، نفربر، بالگرد،
جنگنده، ناوچهٔ پیاده‌سازی و گشت‌اور همگی با پیوت‌های متحرک (چرخ/برجک/لوله/رکور،
روتور/دم‌روتور/سطوح کنترل/پس‌سوز، رمپ/رادار/پروانه) و جزئیات سطحی بازسازی شدند.
آزمون‌ها ۲۵۷/۰ و smoke ساحلی ۳۳/۰ در CI سبز شدند؛ بسته‌های ARM64 بالا دوباره
ساخته و امضا/معماری/آفلاین بودنشان verify شد. اجرای واقعی روی دستگاه اندروید
انجام نشده و کارایی موبایل از رندر نرم‌افزاری دسکتاپ ادعا نمی‌شود.
