# Attribution

## Starter Kit City Builder — Kenney

The 3D models, the colour texture and the sound effects in this repository come
from **Starter Kit City Builder** by [Kenney](https://kenney.nl):

- Code of the starter kit: MIT licence (see
  [`assets/kenney/LICENSE.md`](assets/kenney/LICENSE.md)).
- Included 3D models, 2D sprites and sound effects: CC0 1.0 Universal
  (public domain).

Files taken from the kit and kept in this project:

| Folder | Contents |
| --- | --- |
| `assets/models/*.glb` | roads, buildings, grass, trees, pavement, fountain |
| `assets/models/Textures/colormap.png` | shared colour texture for the models |
| `assets/audio/placement-*.ogg`, `removal-*.ogg`, `rotate.ogg`, `toggle.ogg` | build/UI sounds kept from the kit |

The game code in `scripts/`, the map layout and the user interface were written
for this project and are not part of the starter kit.

## Music, sound effects and icon — generated for this project

Nothing in the soundtrack is licensed from anywhere: it is synthesised from
scratch by [`tools/build_audio.py`](tools/build_audio.py) (numpy + libsndfile),
so the files in `assets/audio/music/`, `assets/audio/sfx/` and
`assets/audio/ambience.ogg` are original works released with this repository.
Re-run the script to regenerate or retune them.

The launcher icon is generated artwork: the 1024 px master is
`assets/icons/source-icon.png`, and [`tools/build_icons.py`](tools/build_icons.py)
derives every shipped size (project icon, legacy launcher icon, Android adaptive
foreground and background) from it.

## Cartoon environment and navigation art

The procedural gabled buildings, palette, lawns and toy-town scenery in
`scripts/town/cartoon_buildings.gd` and related scripts, the five SVG navigation
illustrations in `assets/ui/`, and the baked maps from
`tools/build_surface_textures.py` are original assets made for this project.
The user-provided screenshot guided the palette and general low-poly treatment;
no models, textures, icons, logos, screenshot pixels or UI artwork were extracted
from the reference game or included in the shipped assets.

## Vazirmatn font

`assets/fonts/Vazirmatn-*.ttf` is **Vazirmatn** by Saber Rastikerdar, licensed
under the SIL Open Font License 1.1 (see [`assets/fonts/OFL.txt`](assets/fonts/OFL.txt)).
It is bundled so Persian text is shaped and rendered correctly, including
right-to-left layout.

## Engine

Built with [Godot Engine](https://godotengine.org) 4.7 (MIT licence).
