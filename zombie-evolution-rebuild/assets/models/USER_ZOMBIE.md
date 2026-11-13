# User-supplied animated zombie

Source: user-provided Google Drive folder, archives `Zombie+animation.rar`
(SHA-256 `94d92b666ee58eaffa81f30fbefcfaf5f7f4364eaa7562ef4ff0f52de1eb2a9d`)
and `Texture+set+1.rar` (SHA-256
`fe9a156f18db1005efa009a693aacee933989566ca58d1dd43f5a1d2c010d258`). The
user confirmed they have permission to use and redistribute these files in the
repository; the original creator and license terms were not supplied and have
not been independently verified. Do not label this CC0.

FBX files include the same seven-part weighted mesh and a separate motion per
file. Conversion used assimpjs `glb2`, Pillow to resize `2_Albedo.tga` from
4096 to 1024 pixels, and `ci/assemble_user_zombie.py` to merge clips by unique
node name and embed the texture. Raw source files remain in the user's Drive,
not in this repository. Six source clips: idle1, walk, run, atack1 (original
spelling), gethit, death1. Original source model and rig are retained, not
replaced with synthetic procedural motions. Source's second texture set and
other clips are not yet integrated. The GLB replaces only the ordinary zombie role; the runner and brute remain
their existing models. Movement selects authored idle and walk, attacks and
hits play their respective clips, and death plays the supplied death clip.
Gameplay damage is still applied immediately, not synchronized to the animation
strike frame. Conversion and animation timing still need in-game visual review.
