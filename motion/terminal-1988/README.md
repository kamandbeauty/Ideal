# Terminal (1988) — final cut

The finished vertical short is `exports/terminal-1988-1080p.mp4`.

- 1080 × 1920, 30 fps, H.264 video / AAC stereo audio
- 51.6 seconds, synchronized to `audio/vo.wav`
- Persian captions follow `subtitles-source.txt`
- `stills/contact-sheet.jpg` is a QC overview sampled from the encoded MP4

## Source and rendering

`index.html` contains the deterministic shot timeline, camera moves, crossfades, animated character rig, and captions. The rig follows the approved character design in `assets/characters/mehran.svg`; photographic plates and Vazirmatn fonts are kept under `assets/`.

From the repository root, install the project dependencies with `npm ci`, then run:

```sh
node motion/terminal-1988/render.mjs --sample  # quick browser/render smoke test
node motion/terminal-1988/render.mjs           # render and mux the final MP4
```

`storyboard.md` and `subtitles-source.txt` document the narrative and reference copy. Runtime frames and Chromium libraries are generated under `/tmp`, not kept in the repository.
