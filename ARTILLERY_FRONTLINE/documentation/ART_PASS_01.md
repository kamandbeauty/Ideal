# Art pass 01 — twin .50-cal mount and camera framing

Scope: weapon viewmodel only. Environment, soldiers and HUD redesign are intentionally deferred to later passes.

## Blender production
- Authoring: `tools/create_models.py` executed by GitHub Actions with Blender 5.0.1 (`--background`, CPU).
- Source scene: `assets/models/source/mounted_twin_hmg.blend`.
- Export: `assets/models/mounted_twin_hmg.glb`, 16,834 triangles, 23 UV-mapped primitives, six original materials.
- Studio proof: `documentation/qa/art-pass-01/weapon-studio.png` rendered with Cycles CPU, 96 samples, denoised, three-point lighting.
- Structural gate: `tools/verify_art_pass.py` checks UV0, animation pivots, triangle budget and metre-scale world bounds.

## Mechanical detail
Chamfered receivers, riveted side plates, ejection ports, charging handles, hinged feed covers, feed trays, visible brass belt cartridges, ammo cans with ribs/latches, protected front sights, rear apertures, spade grips, butterfly triggers, slotted muzzle brakes, traverse ring, handwheel, elevation screw and pedestal collars.

## Runtime
- Independent left/right recoil pivots and hinged reload covers.
- Brass ejection from receiver ports; textured additive muzzle flash.
- UV-based weapon PBR (parkerized steel, matte olive paint, brass, rubber) instead of world-space noise.
- Camera offset retuned so muzzles sit in the lower aiming band and stay separated.

## Validation status
Blender asset workflow and structural gate: passed. In-game software smoke and Android package rebuild: pending final CI on the committed GLB. No physical Android device QA is claimed.
