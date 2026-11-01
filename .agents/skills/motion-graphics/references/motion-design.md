# Motion design reference

Load this file when making aesthetic or timing decisions inside a motion graphic.

## Timing

| Element | Duration | Notes |
| --- | --- | --- |
| Eyebrow / small label | 250-400 ms | Enters first, establishes hierarchy |
| Hero title line | 500-700 ms | Mask or slide + fade, never a hard cut |
| Stagger between lines | 60-100 ms | 30-80 ms for dense UI-like sequences |
| Subtitle / body | 400-600 ms | Starts ~10 frames after the title |
| Number count-up | 800-1200 ms | Ease-out so the last digits settle |
| Accent shape / line draw | 400-800 ms | `clip-path` or `scaleX` from 0 to 1 |
| Exit | 300-500 ms | Faster than the entrance |
| Final hold | >= 500 ms | Readable end frame / thumbnail |

At 30 fps, 1 frame = 33.3 ms. At 60 fps, 1 frame = 16.7 ms. Derive every
keyframe from frames, not from seconds typed into CSS, so the same scene can be
re-timed by changing `FPS`.

## Easing

Use named curves as constants so the whole piece feels related:

```js
const EASE = {
  out:   'cubic-bezier(0.22, 1, 0.36, 1)',      // entrances, default
  inOut: 'cubic-bezier(0.65, 0, 0.35, 1)',      // moves across the frame
  in:    'cubic-bezier(0.55, 0, 1, 0.45)',      // exits only
  soft:  'cubic-bezier(0.33, 1, 0.68, 1)',      // gentle drifts
  snap:  'cubic-bezier(0.16, 1, 0.3, 1)',       // punchy stings
};
```

- Entrances always ease out. Ease-in on an entrance feels like the element is
  being pulled away from the viewer.
- Exits may ease in, and should be shorter than entrances.
- Avoid built-in `ease` and `linear` except for continuous loops, progress bars,
  and camera drifts.
- Springs are fine for accent objects, but keep them deterministic: compute the
  spring position from the frame number rather than integrating live physics.

## Motion properties

Animate `transform` (translate, scale, rotate) and `opacity`. `clip-path` is
acceptable for reveals. Everything else triggers layout or paint:

- Do not animate `width`, `height`, `margin`, `padding`, `top`, `left`, `right`,
  `bottom`, `font-size`, `box-shadow`, or `filter` in keyframes.
- Use `scaleX` on a 1px-tall line instead of animating `width`.
- Use `translate3d` / `transform` strings instead of individual `x` / `y`
  properties when the scene is heavy.
- Set `will-change: transform, opacity` on the few elements that move, not on
  everything.
- Prefer `scale(0.95)` + `opacity: 0` over `scale(0)`; avoid the "pop from
  nothing" look.

## Composition and type

- Design on a 1920x1080 stage and keep all content inside a 10% inset
  (192 px horizontal, 108 px vertical). This survives 1:1 and 9:16 crops.
- One focal point per beat. If two things move at once, one leads and the other
  follows by 10-20 frames.
- Limit the palette to one background, one foreground, and one or two accents.
- Type: a large hero (120-180 px at 1080p), a small caps eyebrow (24-32 px with
  letter-spacing), and a quiet subtitle (36-48 px). Two font families maximum.
- Use a system font stack (`system-ui, "Segoe UI", Arial, sans-serif`) unless a
  bundled font file is supplied. Never load Google Fonts at render time.
- Numbers: use tabular figures (`font-variant-numeric: tabular-nums`) so a
  count-up does not jitter horizontally.
- High contrast is non-negotiable for overlays that sit on unknown footage.
  Add a subtle scrim or a solid shape behind text.

## Hierarchy of beats

A short graphic needs exactly one "hero" moment. Typical order:

1. Establish (background, grid, accent line).
2. Lead in the eyebrow.
3. Hero reveal, staggered.
4. Support detail (subtitle, stat, chart).
5. Hold the composed frame.
6. Optional exit or a clean cut to the end card.

Overlap beats so the sequence never has dead frames, but do not start more than
two independent entrances in the same frame.

## Accessibility and reduced motion

- Provide a still end frame that reads as a static poster.
- When embedding in a web page, honour `@media (prefers-reduced-motion: reduce)`
  by jumping to the final frame instead of playing the timeline.
- Keep flashes below 3 Hz and avoid large-area luminance jumps.

## Common failure modes

| Symptom | Fix |
| --- | --- |
| Jerky number count-up | Use `tabular-nums` and a fixed-width container |
| Text blurred while scaling | Animate a wrapper's opacity, keep text unscaled |
| Different frames on re-render | Remove `Math.random()`, `Date.now()`, CSS animations |
| Fonts change mid-sequence | Wait for `document.fonts.ready` before `ready = true` |
| Last frame half-faded | Add a hold beat and check `seek(frames - 1)` |
| Cropped on vertical export | Keep content inside the 10% safe inset |
