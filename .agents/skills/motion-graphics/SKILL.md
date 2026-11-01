---
name: motion-graphics
description: Create short, design-led motion graphics as deterministic HTML/CSS/JS scenes or Remotion compositions and export them to MP4, WebM, or GIF. Use for kinetic typography, animated titles, logo stings, lower thirds, stat count-ups, chart reveals, social overlays, intros, outros, motion posters, and any frame-based animation or video overlay request. Also use when the user says موشن گرافی, motion graphic, animated intro, title sequence, or animated overlay.
license: Apache-2.0
compatibility: Node.js 18+ for scaffolding and preview. Video export additionally requires Playwright Chromium and ffmpeg. Works with any Agent Skills compatible client.
metadata:
  author: Ideal
  version: "1.0.0"
  standard: "https://github.com/agentskills/agentskills"
---

# Motion Graphics

Produce a finished motion graphic, not a menu of options. Make the design calls,
state the reasoning in one line, then build and export the asset.

## When to use

Short (roughly 3-15 s), design-led pieces where motion carries the message,
such as kinetic typography, stat count-ups, chart reveals, logo reveals,
lower thirds, social overlays, title cards, intros, outros, and motion posters.

## When not to use

- Long-form narrated video or a talking-head edit (not a motion graphic).
- Adding hover/press micro-interactions to an existing app UI (use plain CSS).
- A static illustration or a single poster frame with no timeline.

## Workflow

### 0. Lock the brief

Collect only what is missing, otherwise decide and move on. Never stall on a
menu of styles. Defaults are `1920x1080`, `30 fps`, `6 s`, dark background,
one accent colour, no audio.

| Field | Default |
| --- | --- |
| Aspect / size | 16:9, 1920x1080 |
| Duration / fps | 6 s at 30 fps (180 frames) |
| Copy | Use the words the user supplied verbatim |
| Brand | Colours and fonts from the user, else the starter palette |
| Deliverable | `out/<slug>.mp4` plus the editable `index.html` |

### 1. Write a beat sheet before writing code

A beat sheet is a small table with `start`, `end`, `element`, and `motion`.
Example for a 6 s title card:

| Beat | Frames | What happens |
| --- | --- | --- |
| 1 | 0-45 | Eyebrow slides up, accent line draws in |
| 2 | 20-90 | Title lines stagger in with a mask reveal |
| 3 | 60-130 | Subtitle fades in, number counts up |
| 4 | 120-165 | Everything settles, accent orb drifts |
| 5 | 160-180 | Clean exit or hold on a readable end frame |

Overlap beats by 15-30 frames. The first and last frames must look intentional:
frame 0 should be a clean composition, and the final frame should be a readable
end card that can be used as a thumbnail.

### 2. Pick the cheapest stack that works

Read [references/stacks.md](references/stacks.md) for details. In short:

| Need | Stack |
| --- | --- |
| Most short graphics, typography, charts, overlays | Single-file HTML + Web Animations API (default) |
| React component reuse, programmatic video, many variants | Remotion |
| Mathematical / geometric explainers | Manim |
| Vector-only UI animation handed to an app | Lottie |

Default to the single-file HTML starter. It has no build step, no CDN, and is
deterministic, so every frame can be re-rendered identically.

### 3. Build the scene

```bash
npm run motion:new -- <slug>       # scaffolds motion/<slug>/index.html + brief.md
```

Then edit `motion/<slug>/index.html`. Rules that are easy to break:

- **Deterministic timeline.** Expose `window.__MOTION__` with `fps`, `frames`,
  `width`, `height`, and `seek(frame)`. Every animation must be driven by
  `seek()`, never by wall-clock time, `setTimeout`, or CSS `animation-play-state`.
  The starter does this with paused Web Animations API objects whose
  `currentTime` is set from the frame number.
- **No network at render time.** Inline fonts, SVG, and data; use system font
  stacks or bundle local font files. Never rely on a CDN or a remote image.
- **Animate only `transform` and `opacity`** (plus `clip-path` for reveals).
  Avoid `width`, `height`, `top`, `left`, `margin`, and `filter` in keyframes.
- **Safe area.** Keep all text inside a 10% inset so it survives cropping to
  9:16 or 1:1. Design at 1920x1080 and scale the whole stage with a transform.
- **Readable end frame.** Stop all motion with at least 15 frames left so the
  final composition is legible.
- Preview in a browser with no `?frame=` parameter. Add `?frame=90` to inspect
  a single frame. See [references/rendering.md](references/rendering.md).

Motion design rules, easing curves, stagger values, and type/color guidance live
in [references/motion-design.md](references/motion-design.md).

### 4. QA checklist

- [ ] Frame 0, middle frame, and final frame all look intentional.
- [ ] No clipping, no text outside the safe area, no half-loaded fonts.
- [ ] No `transition: all`, no `scale(0)` entrances, no `ease-in` on entrances.
- [ ] Same output for the same frame number on two runs (determinism check).
- [ ] Text contrast is high and copy is spelled exactly as supplied.
- [ ] Exports match the requested aspect ratio, fps, and duration.

### 5. Export

```bash
npm run motion:render -- <slug>              # MP4, H.264, yuv420p
npm run motion:render -- <slug> --keep-frames
```

The renderer opens the scene in Chromium, calls `seek(i)` for every frame,
screenshots each frame, and pipes the PNG sequence through ffmpeg. It deletes
intermediate frames unless `--keep-frames` is passed. ffmpeg output options,
transparent WebM overlays, GIFs, and aspect presets are documented in
[references/rendering.md](references/rendering.md).

If Chromium or ffmpeg is unavailable, still deliver the editable `index.html`
and report exactly what is missing instead of silently producing nothing.

### 6. Deliver

Return the video path, the editable source path, and a one-line summary of the
beat sheet. Do not dump the full source into the chat unless asked.

## Never ship

| Never | Instead |
| --- | --- |
| `transition: all` | Name the exact properties |
| `transform: scale(0)` entrance | `scale(0.95)` + `opacity: 0` |
| `ease-in` on an entrance | `cubic-bezier(0.22, 1, 0.36, 1)` |
| Everything entering at once | 30-80 ms stagger between elements |
| Animated `width` / `height` / `top` / `left` | `transform` / `opacity` / `clip-path` |
| Random values or `Date.now()` in the timeline | Deterministic per-frame math |
| A blank or mid-animation final frame | Hold a composed end card |
| Wall-clock CSS animations while exporting | Paused WAAPI animations driven by `seek()` |

## Bundled resources

- [assets/starter.html](assets/starter.html) - dependency-free 1920x1080 scene
  with a frame-driven timeline, used by `motion:new`.
- [scripts/new-motion.mjs](scripts/new-motion.mjs) - scaffold a new scene.
- [scripts/render.mjs](scripts/render.mjs) - render frames and encode video.
- [references/motion-design.md](references/motion-design.md) - timing, easing,
  type, colour, and composition rules.
- [references/stacks.md](references/stacks.md) - choosing between HTML, Remotion,
  Manim, and Lottie.
- [references/rendering.md](references/rendering.md) - deterministic capture,
  ffmpeg presets, and troubleshooting.

## Skill maintenance

This skill follows the Agent Skills specification at
`https://github.com/agentskills/agentskills`. Validate after editing:

```bash
npm run skills:validate
npm run skills:list
```
