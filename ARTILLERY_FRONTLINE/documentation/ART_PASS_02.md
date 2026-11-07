# Art pass 02 — infantry, remaining weapons, coastal graphics

Scope: make the humans read as soldiers instead of box limbs, rebuild the four
remaining player weapons with the same PBR pipeline as the twin HMG, and remove
the confirmed graphical defects of the coastal milestone (white grid mountains,
striped sand/water, hard foam, black low-tier cloth, screen-filling black smoke,
cropped ammo panel, low-contrast threat label).

All geometry, textures and renders are original. Authoring runs in Blender 5.0.1
on GitHub Actions (`Author original Blender assets`); nothing is copied from the
visual references.

## Models (Blender → glTF, verified by `tools/verify_art_pass.py`)

| Model | Triangles | Notes |
| --- | ---: | --- |
| soldier | 5,952 | 1.82 m, lofted anatomy, 13 pivots: Hips/Torso/Head/LegL,R/KneeL,R/ArmL,R/ElbowL,R/Rifle/Muzzle |
| mounted_cannon | 3,737 | recuperators, muzzle brake ports, optic, brass ejection |
| mounted_rocket | 4,210 | four tubes, optic, hose, pedestal |
| mounted_autocannon | 4,667 | spinning shroud, drum, spade grips |
| bazooka | 1,531 | venturi, wood grips, sight ladder |

Every primitive carries UV0; world bounds are Y-up; triangle gates are
4k–60k (soldier) and 1.5k–80k (weapons). Soldier arms are posed with a two-bone
IK solve so both hands meet the rifle grip and handguard. New PBR sets:
`skin_*`, `leather_*`; sand ripples reduced to avoid contour striping.

## Runtime animation

`enemy_soldier.gd` drives knees, elbows, torso lean/twist, head stabilization and
rifle bob from the stride phase; `play_fire()` adds a muzzle-flash billboard,
omni light and recoil kick. Death now folds knees/hips/torso/head instead of
rotating a stiff root.

## Environment / lighting / effects

- `mountain.gdshader`: unshaded, noise-strata ridge with distance haze (replaces
  the sun-blasted white grid wall); ridge moved to z −760…−1050 and lowered.
- `beach.gdshader`: two rotated detail samples, macro/patch variation, distance
  fade, wet-sand band and noise-broken shoreline foam; normal depth 0.16.
- `ocean.gdshader`: three-component swell with analytic normals, noise ripples,
  broken crest foam and foam at the true waterline (z ≈ −13); specular reduced.
- Sun 1.12, sky ambient 0.36, exposure 0.96, fog 0.00045 (low 0.0007).
- `material_library.gd`: authored metallic/roughness fallbacks when ORM textures
  are detached on the low tier (previously cloth went fully metallic → black).
- `explosion_effect.gd`: per-system tint + lifetime alpha fade instead of
  `color_ramp` (black/checkered particles under Compatibility), mip-free
  filtering, capped smoke quads, ground dust skipped on low tier.
- Shader compile errors and GDScript errors now fail CI (`coastal-smoke.log`
  is preserved as evidence).

## HUD

Ammo panel height fixed (no crop), threat label gets a shadow pill contrast,
global label shadow for readability over sand and sky.

## Validation (CI, not a device)

- Assets workflow run **42371518511** ✅ — Blender authoring, Cycles studio
  renders (`qa/art-pass-02/soldier-studio.png`), export gates, `art-pass-02.json`.
- Main workflow run **42375143021** ✅ — unit/integration **242 checks / 0 failures**,
  coastal smoke **33 checks / 0 failures** (llvmpipe Compatibility, low tier:
  ~14.4 fps, 334 draw calls, 135,804 primitives, scale 0.62). Software rendering
  only; no Android device or emulator execution was performed.
- Packages: `delivery/Artillery-Frontline-arm64.apk` (48,573,377 B) and `.aab`
  (48,127,769 B), ARM64, minSdk 24 / target 36, landscape, no INTERNET permission,
  ephemeral development signature. The compatibility-package APK is verified in
  CI and published as the `android-compatibility-apk` workflow artifact instead
  of being tracked in Git (snapshot size budget).

## Known limits

- Soldiers are mobile-budget realistic-proportioned figures (≈6k tris), not
  scanned humans; faces read at studio distance, silhouettes read in game.
- llvmpipe fps is a software-renderer floor, not a phone measurement.
- Landing zones were moved closer (z 26–30) so infantry is legible at ~20–30 m.
