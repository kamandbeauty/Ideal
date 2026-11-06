# Graphics overhaul

This pass replaces the flat prototype look with an original, offline PBR presentation while keeping the mobile-first tier system.

## What changed

- **Original seamless textures:** `tools/create_textures.py` authors sand, gravel, rock, painted metal, steel, fabric, wood, concrete, rubber, foliage, grass cards and a sky panorama. Albedo maps are JPEG; normal/ORM/alpha maps are PNG. No third-party art is downloaded.
- **Material response:** runtime surfaces use albedo + normal + ORM where available. Imported Blender models are upgraded by material name, preserving animation pivots.
- **Terrain and roads:** world-space sand texturing, macro variation, normal detail; conforming road meshes now use gravel, wheel ruts and ragged alpha-scissor edges.
- **Lighting/atmosphere:** ACES tonemapping, panorama sky, warmer directional sun, aerial-perspective fog, restrained glow. SSAO is enabled only on renderers that support it (Compatibility / Forward+); depth of field is enabled only outside Compatibility.
- **Scenery detail:** displaced rocks, clustered acacia canopies, wind-swayed dry-grass cards, higher-detail sandbags, textured structures and props. MultiMesh batching and visibility ranges remain in place.
- **Quality tiers:** `low`, `medium`, `high`, and manual `ultra`. AUTO is capped at `high` to protect frame rate; `ultra` is an explicit device-dependent choice.

## Honesty / validation boundaries

- “1000×” is treated as a qualitative request, not a measured benchmark.
- CI screenshots are software-rendered (Xvfb/llvmpipe) and are **not** Android GPU benchmarks.
- No device installation, touch/thermal validation, or store-release signing is claimed by this graphics pass.
- Existing offline, original-asset, and dev-signed CI package constraints remain unchanged.
