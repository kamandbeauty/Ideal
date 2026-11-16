# City zombie asset

The extra walker/runner appearance is based on **Male City Zombie Ready for Use in Game Engines**, by medicinestorm, CC0 1.0:
https://opengameart.org/content/male-city-zombie-ready-for-use-in-game-engines

The intermediate GLB and albedo atlas are from https://github.com/Ju4nK1807/Reticula/tree/bdc65546b165ae9963f59ab3adcb3468a0003dd5/public/models/characters (see its `credits.json`). Only the original city-zombie animations are used; the separately licensed additional animations from that repository are removed. The 2,404-triangle LOD is used, the atlas is reduced to 1024×512, and mesh positions, skeletal translations, inverse-bind translations and animation translations are converted from centimetres to metres. Clips are aliased to the game state-machine names. No game code from that project is used.

Reproduce with `python tools/prepare_city_zombie.py upstream-zombie.glb`, then `npx @gltf-transform/cli prune assets/models/zombies/zombie_city.glb output.glb --keep-attributes`; replace the unpruned file with the output. Run `python tools/prepare_city_zombie_atlas.py upstream-albedo.webp` (Pillow and numpy required) to resize, bake skin/cloth tint and flip the upstream atlas to match its OpenGL-style UVs; its original renderer applied the tint in a shader.
