# HyperFrames stickman probe — findings

A 6-second vertical (1080×1920) stickman shot built to test whether
[HyperFrames](https://github.com/heygen-com/hyperframes) is a real alternative to
this repo's own `seek(frame)` + Playwright + ffmpeg pipeline.

Composition: `index.html`. Persian captions (Vazirmatn, `dir="rtl"`), one SVG rig,
two-bone IK for arms and legs, and the deterministic "boiling line" jitter the
project recommends (12 drawings a second, seeded by `Math.floor(t * 12)`).

## Verdict

**Yes, it works, and it maps almost one-to-one onto what this repo already does.**
Same contract: every frame a pure function of timeline time, no `Math.random`,
no timers, no `requestAnimationFrame` in the authored code. HyperFrames only adds
the pieces this repo hand-rolls (lint, layout/motion/contrast gates, snapshots,
alpha output, a block registry).

## Numbers measured in the sandbox

| | |
|---|---|
| `check` | 0 errors, 0 warnings (lint + layout + motion + contrast + audio) |
| MP4 render | 6.0 s film in **19.5 s** (180 frames, software GL, screenshot capture) |
| MP4 size | 452 KB |
| ProRes 4444 MOV | 38 MB, `yuva444p12le` — **real alpha, 97.4 % transparent** |
| WebM | `yuv420p` — **no alpha** (the page background is opaque; this is not a bug) |
| NaN check | 0 bad path values across 300 frames, after the fix below |

## Three things that cost time

1. **`--format webm` does not keep alpha here.** The reported `yuv420p` is a
   consequence of an opaque `body` background. Use `--format mov --prores-profile 4444`
   (or `png-sequence`) for transparency; `4444` is the only ProRes profile that keeps it.
2. **Sandbox wiring.** Three env pieces are needed and none is obvious from the docs:
   - `HYPERFRAMES_BROWSER_PATH=/tmp/chromium` — `browser ensure` cannot download.
   - A **full** ffmpeg on `PATH`. The one bundled with Remotion has no `setparams`
     filter and the render dies at "Streaming encoder exited before frame 67".
     `npm i @ffmpeg-installer/linux-x64 @ffprobe-installer/linux-x64` fixes it.
   - Fonts must be local: contract rule 9 fails any family without an `@font-face`
     pointing at `assets/fonts/`. Vazirmatn is copied from `motion/kamand-paper/fonts/`.
3. **A GSAP trap worth remembering.** In `vars`, a nested plain object is treated as
   *another target*, not as a property path:

   ```js
   tl.to(target, { handR: { x: 300, y: -180 } });        // ✗ animates a detached object
   tl.to(target, { "handR.x": 300, "handR.y": -180 });   // ✓
   ```

   With the first form `target.handR` became the new object on the first tick and the
   IK target went `NaN`, silently, at the moment the tween started. `check` passed;
   only the browser console showed `<path> attribute d: Expected number, "…LNaN NaN"`.
   **This is exactly the class of failure `check` does not catch — read the render's
   `[Browser:ERROR]` lines.**

## What this means for the repo

The migration cost is low because there is nothing to port conceptually: an
`index.html` with a paused timeline, `data-start` / `data-duration` on clips, and
`window.__timelines["<composition-id>"] = tl` is the same shape as
`motion/kamand-paper/index.html`. The gain is the gates (lint, layout, motion,
contrast, snapshots, contact sheets) and alpha output without a desktop app.
The cost is a new dependency tree and giving up the current zero-dependency
`render.mjs` scripts.

Not yet tested here: RTL caption animation at word level (the `splitArabicLetters`
pattern from `remotion-dev/skills` was not needed for a 3-line caption swap),
audio, and the 450-block registry.
