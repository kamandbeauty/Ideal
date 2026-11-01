# Rendering and export reference

## Deterministic frame capture

The renderer in [scripts/render.mjs](../scripts/render.mjs) does this:

1. Resolve `motion/<slug>/index.html` to a `file://` URL and open it in Chromium
   at exactly the scene's `width` x `height` with `deviceScaleFactor: 1`.
2. Wait for `window.__MOTION__.ready === true`.
3. Read `fps`, `frames`, `width`, `height` from `window.__MOTION__`.
4. For each `i` in `0..frames-1`, call `window.__MOTION__.seek(i)` and take a
   PNG screenshot into `motion/<slug>/frames/`.
5. Encode the PNG sequence with ffmpeg.
6. Delete the frames unless `--keep-frames` was passed.

Screenshots are taken with `animations: 'disabled'` at the Playwright level is
not needed because the scene itself controls all animation via `seek()`. Do not
use CSS `animation-play-state` tricks; they race with the screenshot.

## Setup

```bash
npm install
npm i -D playwright
npx playwright install chromium
# ffmpeg must be on PATH: macOS `brew install ffmpeg`,
# Debian/Ubuntu `sudo apt install ffmpeg`, Windows `winget install ffmpeg`
```

`playwright` is intentionally an optional, on-demand dependency so the skill
can be installed without downloading a browser. The render script prints a
targeted install hint if it is missing.

## Commands

```bash
npm run motion:render -- my-title                 # out/my-title.mp4
npm run motion:render -- my-title --keep-frames  # keep the PNG sequence
npm run motion:render -- my-title --out out/intro-final.mp4
```

## ffmpeg presets

MP4 (default, broadly compatible):

```bash
ffmpeg -y -framerate 30 -i frames/f_%05d.png \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart \
  out/video.mp4
```

Transparent WebM overlay for compositing on footage:

```bash
ffmpeg -y -framerate 30 -i frames/f_%05d.png \
  -c:v libvpx-vp9 -pix_fmt yuva420p -b:v 0 -crf 30 -auto-alt-ref 0 \
  out/overlay.webm
```

Start the HTML stage with a transparent background (`background: transparent`)
and screenshot with `omitBackground: true` for alpha overlays.

Short GIF for chat / docs:

```bash
ffmpeg -y -framerate 15 -i frames/f_%05d.png \
  -vf "fps=15,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
  -loop 0 out/preview.gif
```

ProRes or another mezzanine codec for handing off to an editor:

```bash
ffmpeg -y -framerate 30 -i frames/f_%05d.png \
  -c:v prores_ks -profile:v 3 out/master.mov
```

## Aspect and duration presets

| Deliverable | width x height | fps | frames for 6 s |
| --- | --- | --- | --- |
| YouTube / deck | 1920x1080 | 30 | 180 |
| Instagram feed | 1080x1080 | 30 | 180 |
| Story / Reel / Short | 1080x1920 | 30 | 180 |
| Broadcast | 1920x1080 | 25 | 150 |

Change `WIDTH`, `HEIGHT`, `FPS`, and `DURATION` in the scene, then verify that
all text still fits the 10% safe inset. Do not letterbox by stretching.

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `Cannot find module 'playwright'` | Run `npm i -D playwright && npx playwright install chromium` |
| `ffmpeg: command not found` | Install ffmpeg, then confirm `ffmpeg -version` |
| Frozen first frame in the video | `seek()` is not advancing `currentTime`; check paused WAAPI objects |
| Font differs from preview | Font not bundled or `ready` set before `document.fonts.ready` |
| Black frames at the end | `frames` exceeds the timeline; add a hold beat |
| Huge PNGs / slow render | Lower `deviceScaleFactor` to 1, keep the stage at 1920x1080 |
| Different output each run | Remove `Math.random()`, `Date.now()`, rAF loops, and CDN assets |
| Audio missing | This skill exports silent motion graphics; mux audio separately with `ffmpeg -i video.mp4 -i audio.wav -c:v copy -c:a aac out/final.mp4` |

## Verification

```bash
ffprobe -v error -show_entries stream=width,height,r_frame_rate,nb_frames -of default=nw=1 out/video.mp4
```

Confirm width, height, fps, and frame count match the brief before delivering.
