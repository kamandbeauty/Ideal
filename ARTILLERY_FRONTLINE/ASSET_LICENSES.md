# Asset and dependency licenses

No assets, branding, models, maps, audio, or proprietary content from World of Artillery are used.

| Asset | Source | Author / supplier | License / permission | Attribution / notice | Commercial use |
|---|---|---|---|---|---|
| Kestrel M-42, Warden MBT, Nomad 6×6, Sentry post, hangar, coastal machines | Original `tools/create_models.py`, authored in Blender | ARTILLERY FRONTLINE contributors | CC0-1.0 project dedication | No external attribution required | Yes |
| Terrain, roads, base kit, rocks, vegetation, sandbags, icon and procedural UI drawings | Original procedural Godot geometry / SVG / Python | ARTILLERY FRONTLINE contributors | CC0-1.0 project dedication | None required | Yes |
| UI plates, scrims, divider, checkbox/slider/chevron glyphs | Original `tools/create_ui_textures.py` | ARTILLERY FRONTLINE contributors | CC0-1.0 project dedication | None required | Yes |
| Persian menu key art and command emblem (`hero_beach.jpg`, `hero_ridge.jpg`, `hero_gun.jpg`, `emblem.png`) | Produced during this project's Persian UI art pass | Project art pass | Project asset; not third-party stock photography | Retained in `assets/textures/ui/` | Project use |
| Uploaded enemy infantry mesh and atlases (`D0307048A1.max`, `de387a0.dds`, `de0fc20.dds`, `de30540.dds` as uploaded) | Repository-root upload by project owner; metadata references a third-party library | Project owner / upstream supplier | Owner-stated permission to use in this game; not an independent licence audit | See `documentation/uploaded-infantry-provenance.md`; keep underlying permission evidence with release records | Per owner grant |
| Cannon, explosion, reload, click, impact, wind WAV files | Original deterministic synthesis in `tools/create_audio.py` | ARTILLERY FRONTLINE contributors | CC0-1.0 project dedication | None required | Yes |
| Terrain and crater shaders | Original shaders in `shaders/` | ARTILLERY FRONTLINE contributors | CC0-1.0 project dedication | None required | Yes |
| Vazirmatn Regular / Medium / SemiBold / Bold fonts | https://github.com/rastikerdar/vazirmatn | Vazirmatn project authors | SIL Open Font License 1.1 | Retain `assets/fonts/Vazirmatn-OFL.txt`; do not sell the font alone | Yes |
| Rajdhani Medium / SemiBold fonts, legacy UI font files | https://github.com/google/fonts/tree/main/ofl/rajdhani | Indian Type Foundry / Rajdhani project authors | SIL Open Font License 1.1 | Retain `assets/fonts/OFL.txt`; do not sell the font alone | Yes |
| Godot 4.7.2 engine/runtime | https://github.com/godotengine/godot/releases/tag/4.7.2-stable | Juan Linietsky, Ariel Manzur and Godot contributors | MIT | Retain engine copyright/license; see `documentation/licenses/Godot-MIT.txt` | Yes |
| Blender authoring tool | https://www.blender.org/ | Blender Foundation and contributors | GPL (tool only; original output is not forced to GPL) | Tool notice retained in Blender distribution | Yes |

The original project assets are dedicated to the public domain under CC0 where legally possible. See `documentation/licenses/CC0-1.0.txt`. Third-party fonts and the engine retain their own licenses. The uploaded infantry model is retained under the project owner's stated permission; this is not a relicensing of the upstream asset and not an independent licence audit. There are no asset-store dependencies, paid plugins, advertisements, or runtime network services.

Engine archive SHA-256 verified by CI:
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.
