# Choosing a rendering stack

Pick the cheapest tool that can deliver the requested asset. Do not install a
framework for a six-second title card.

## 1. Single-file HTML + Web Animations API (default)

Best for kinetic typography, stat count-ups, chart reveals, lower thirds, logo
stings, social overlays, motion posters, and anything under ~15 seconds.

Why: no build, no dependencies, offline-safe, and trivially deterministic. The
browser is both the preview and the renderer, and `seek(frame)` gives exact
frame reproduction for ffmpeg.

Use [assets/starter.html](../assets/starter.html) as the base. Its contract:

```js
window.__MOTION__ = {
  fps: 30,
  frames: 180,
  width: 1920,
  height: 1080,
  duration: 6,
  seek(frame) { /* set animation.currentTime = frame / fps * 1000 */ },
  ready: true,
};
```

`ready` must become `true` only after fonts and local assets have loaded.
All animations are created with `element.animate(...)`, immediately `.pause()`d,
and advanced by assigning `currentTime`. In preview mode (no `?frame=`
parameter) the same animations are `.play()`ed so the author can watch the
piece in real time.

## 2. Remotion

Use when the deliverable is a React component, needs programmatic variants from
data, requires audio synchronisation, or must be rendered by a CI pipeline that
already uses Remotion.

- Composition: `<Composition id="..." durationInFrames={180} fps={30} width={1920} height={1080} />`.
- Drive everything from `useCurrentFrame()` and `interpolate()` / `spring()`.
- Render with `npx remotion render src/index.ts <Id> out/video.mp4`.
- Still deterministic, but adds a Node/React toolchain. Only choose it when that
  toolchain already exists or is explicitly requested.

## 3. Manim (Python)

Use for mathematical or geometric explainers where shapes must be constructed
from equations, graph axes, or transformations of formulae.

- Requires Python and Cairo/OpenGL system libraries; export via
  `manim -qh scene.py SceneName`.
- Not suitable for brand typography or UI-like overlays.

## 4. Lottie / SVG

Use only when the consumer is an app or a web page that needs a vector animation
at runtime, not a video file. Lottie is a delivery format, not an authoring
environment. Export a Lottie JSON and hand it to the app team.

## What not to use

- **CSS keyframe animations alone** for export. They are wall-clock driven and
  cannot be reliably seeked frame by frame. WAAPI gives the same declarative
  keyframes with a controllable `currentTime`.
- **Canvas drawing driven by `requestAnimationFrame`** unless it is explicitly
  redrawn inside `seek(frame)`. A live rAF loop is not deterministic.
- **Remote CDNs, web fonts, or stock images** fetched during rendering. Bundle
  or inline everything so a render works offline and is reproducible.
- **`setTimeout` / `setInterval`** inside the timeline. Always compute state
  from the frame number.

## Decision shortcut

| Request | Stack |
| --- | --- |
| "An animated title / intro / lower third / stat" | Single-file HTML |
| "A set of 50 personalised videos from CSV" | Remotion |
| "Explain the Fourier transform visually" | Manim |
| "Give the app team a looping vector icon animation" | Lottie |
| "A transparent overlay on top of footage" | Single-file HTML, export WebM with alpha |
