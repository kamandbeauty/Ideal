# Uploaded infantry asset — provenance and pipeline

The attacking enemy infantry in the coastal milestone is built from a
**user-supplied** 3ds Max scene, not from art authored by this project.

## Source files

| File | What it is |
| --- | --- |
| `D0307048A1.max` | 3ds Max scene, OLE/CFB container, one Editable Mesh |
| `de387a0.dds` | 512×512 DXT5 — body/uniform atlas |
| `de0fc20.dds` | 256×256 DXT5 — gear atlas |
| `de30540.dds` | 256×256 DXT1 — head/face atlas |

These were uploaded into the repository root by the project owner. The scene
metadata references a third-party library (`cadnav`), so the mesh and its
textures are **not original work** and are **not** covered by the project's
"original assets only" claim. Everything else in `assets/models/` remains
procedurally authored by `tools/create_models.py`.

**Permission record.** The project owner has stated that they hold permission to
use this uploaded model in the game. The mesh is therefore retained as
owner-licensed material rather than flagged for replacement. This documents the
owner's grant; it is not an independent licence audit. Keep the underlying
permission evidence with the release records when distributing publicly.

## What the source does and does not contain

The `.max` holds a **static A-pose mesh**: 1,001 vertices, 1,927 triangles, one
UV channel, and a Multi/Sub-Object material with four slots (slot 3 reuses the
body atlas). There is **no Skin modifier, no skeleton and no vertex weights**,
and **no weapon**.

So the rig, the weights, the carrying pose and the rifle are all authored here:

* `tools/import_max_soldier.py` — reads the mesh, decodes the atlases, authors the
  11-bone skeleton, computes weights, solves the rifle grip and bakes the pose.
* `tools/create_models.py` (`soldier()`) — instantiates that data in Blender and
  builds the **original** rifle geometry declared in the converter.

## Conversion

`.max` is proprietary; neither Blender nor Assimp opens it on Linux. The
converter parses it with the Python standard library only — no Blender, no
third-party packages — so CI can regenerate everything from the uploaded files.

    python3 ARTILLERY_FRONTLINE/tools/import_max_soldier.py

Outputs:

* `assets/models/source/uploaded_soldier.json` — posed mesh, UVs, normals,
  materials, joints, weights, rifle specification.
* `assets/textures/uploaded/soldier_{body,gear,head}.png` — decoded atlases.

Both directories carry `.gdignore`: only the atlases **embedded in `soldier.glb`**
ship to the device, so Godot never imports duplicate loose textures.

### Format notes

* CFB: DIFAT → FAT → directory, with the mini-FAT for streams under 4,096 B.
* `Scene` chunk tree: `uint16 id` + `uint32 size`. The container flag is the
  **high bit of the size dword**, not of the id; size includes the 6-byte header.
* Face records are 20 B: three `uint32` indices, smoothing mask at +12, edge
  visibility flags at +16, **sub-material index at +18**.
* DDS: `dwFourCC` lives at byte 84. `dwPitchOrLinearSize` is unreliable, so block
  counts are derived from width/height. A DXT colour block is 8 B.

### Geometry corrections

* **Winding is inverted** in the source (every component has negative signed
  volume), so all triangles and map-face triples are reversed.
* **Smoothing groups** are reproduced by duplicating vertices at group
  boundaries, which makes a plain averaged vertex normal correct without
  depending on Blender-version-specific auto-smooth behaviour.
  1,001 source vertices become 2,324 after the split.
* **Scale/orientation**: Max Z-up, model facing +Y, 206 units tall → Blender Z-up
  metres, facing −Y, 1.82 m tall with the soles at z = 0. This is a proper
  rotation (determinant +1).
* **UV V-flip** happens once, in `export_glb()`: Blender/Max UVs are V-up while
  glTF `TEXCOORD_0` is V-down. Existing models use triplanar or tiling surfaces,
  so the flip is visually inert for them and correct for the atlases.

## Rig

Eleven joints, matching `SoldierRagdoll.BONES` and `SKIN_BONES` exactly:
`Hips, Torso, Head, LegL, KneeL, LegR, KneeR, ArmL, ElbowL, ArmR, ElbowR`.

* The continuous body shell blends over its three nearest bone segments with a
  `1/max(d, 0.015)^4` falloff, so shoulders, elbows and knees deform.
* The other 16 shells (head, hands, pouches, pads) stay rigid on the bone nearest
  their centroid, so hard gear does not smear.
* `scripts/coastal/enemy_soldier.gd` only adds *compliance* to the arms — it never
  re-solves a grip — so the rest pose must already hold the weapon. Both arms are
  posed with a two-bone IK (upper 0.282 m, forearm 0.249 m) onto a diagonal
  low-ready carry, and the result is baked into the vertices. The posed skeleton
  is published as the rest pose, which keeps the inverse-bind matrices
  consistent.

Measured against the live gait, the hands stay within **8 mm** of their grip
targets across a full stride plus aim and recoil.

## Known limitations

* **No finger bones.** The source hands are modelled open and there is nothing to
  curl, so the fingers do not wrap around the grip. Adding fingers would require
  re-modelling the hands.
* The rifle stock intentionally overlaps the chest at the shoulder, as a real
  slung carry does.
* The rifle is original project geometry, not part of the upload.

## Verification

* `tools/verify_art_pass.py` gates the exported GLB: pivots, 1,200–60,000
  triangles, UV0 on every primitive, three embedded opaque atlases, target-less
  image bufferViews, and a real skin with `JOINTS_0`/`WEIGHTS_0`.
* `tests/integration/test_coastal_pass3.gd` asserts at runtime that the infantry
  imports as a `Skeleton3D` with all eleven bones, that all three meshes are
  skinned, that each atlas survives the glTF import as a UV-mapped (not
  triplanar) albedo, and that the rifle and muzzle sit in the authored rest pose.
* `documentation/qa/art-pass-02/soldier-studio.png` is a Blender Cycles render of
  the exported model.
