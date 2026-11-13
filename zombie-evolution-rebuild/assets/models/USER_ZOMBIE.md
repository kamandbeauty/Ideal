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
other clips are not yet integrated. The ordinary zombie, runner and stage
boss now share this same rigged model and texture. The runner plays the Run
clip, while the other two play Walk. The boss is scaled up and widened, rather
than being a separate authored monster. Their original static GLBs remain in
the repository but are no longer displayed in these roles. Each role plays
Idle, Attack, Hit and Death. Death uses the existing fast clip and scripted
knockback. Damage remains immediate rather than synchronized to a strike frame.
A test-only close-up was inspected and shows the textured source model. A
normal gameplay still shows the scaled boss in front of the entrance, but it
is too small to validate foot contact, facing or the quality of its movement.
