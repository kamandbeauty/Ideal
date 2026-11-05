# MotionShot — Canonical Motion & Timeline Specification (v1.0)

This document is the **single source of truth** for every piece of math in MotionShot.
Three independent implementations must agree with it, bit-for-bit within the stated
tolerance:

| Implementation | Location | Purpose |
|---|---|---|
| Dart (preview / UI) | `lib/features/motion/` | Real-time preview, gesture editing, timeline |
| Kotlin (render) | `android/.../motion/` | OpenGL render + MediaCodec export |
| Python (validator) | `tools/validate/` | Golden-vector generation + reference MP4 render |

Any change to this document requires updating all three implementations **and** the
golden vectors in `tools/validate/golden/*.json`.

---

## 1. Coordinate systems

### 1.1 Image space (source pixels)

Origin at the **top-left** of the decoded, EXIF-corrected source image.
`x` grows right, `y` grows down. Size = `(W, H)` in pixels.

### 1.2 Normalized camera space

All motion state is stored in **normalized camera space**, independent of output
resolution and independent of preview scale. This is what guarantees that a 480p
preview and a 4K export show the *same* framing.

- The **viewport** is the output frame, assumed to be a rectangle of aspect ratio
  `A = outW / outH`.
- The viewport is normalized so that its **shorter side is 1.0**:
  - if `A >= 1` (landscape / square): `vw = A`, `vh = 1`
  - if `A < 1`  (portrait):           `vw = 1`, `vh = 1 / A`
- The viewport center is the camera position `(cx, cy)`.
- `scale` = zoom factor. `scale = 1.0` means the viewport exactly covers the
  "cover-fitted" image (see 1.4). `scale = 2.0` means half as much of the image is
  visible on each axis.
- `rotation` = clockwise rotation of the **image within the viewport**, in radians.
  Because the image rotates about the camera center, the visible footprint of a
  rotated image is its axis-aligned bounding box.

### 1.3 Camera → image transform

Given camera `(cx, cy, scale, rotation)`:

1. Viewport half-extents in normalized image units: `hw = vw / (2*scale)`,
   `hh = vh / (2*scale)`.
2. If `rotation != 0`, the axis-aligned bounding box of the rotated viewport corners
   is larger. With `c = |cos r|`, `s = |sin r|`:
   `bw = hw*c + hh*s`, `bh = hw*s + hh*c`.
   Otherwise `bw = hw`, `bh = hh`.
3. Rendered result (the GL draw) rotates the image by `+r` and scales by
   `2*scale/max(vw,vh)` about the camera center — see §7 for exact matrices.

### 1.4 Cover fit of the source image

The source image must always cover the viewport at `scale = 1` (no letterboxing,
no black bars — the "no unintended black frames" rule).

Let the source image dimensions be `(W, H)` (after EXIF rotation) and let the image
be centered at the camera center in normalized space. Define the image half-extents
in normalized units:

```
cover = max( vw / W , vh / H )
iw    = W * cover / 2          // half width of the image in normalized units
ih    = H * cover / 2
```

So the image occupies `[-iw, iw] x [-ih, ih]` when centered on the origin.
An image with the same aspect ratio as the viewport has exactly `iw = vw/2`,
`ih = vh/2` at `scale = 1`.

---

## 2. Easing curves

All easing functions map `t in [0,1] -> [0,1]`, with `f(0)=0` and `f(1)=1`.

| Easing | Formula |
|---|---|
| `linear` | `t` |
| `easeIn` | `t^2` |
| `easeOut` | `1-(1-t)^2` |
| `easeInOut` | `t<0.5 ? 2t^2 : 1-2(1-t)^2` |
| `smooth` | `t*t*(3-2t)` (smoothstep) |
| `smoother` | `t*t*t*(t*(6t-15)+10)` (smootherstep, the default) |
| `custom` | Cubic Bézier `(x1,y1,x2,y2)` evaluated by Newton-Raphson with bisection fallback, exactly as CSS `cubic-bezier`. Defaults `(0.42,0,0.58,1)` = ease-in-out. |

Bézier evaluation: solve `x(u) = t` for `u`, then return `y(u)`.
`x(u) = 3(1-u)^2*u*x1 + 3(1-u)*u^2*x2 + u^3`.

Guard: if `x1,x2` are outside `[0,1]` they are clamped (keeps `x(u)` monotonic).

---

## 3. Keyframes

A `MotionProfile` owns an ordered list of keyframes with **at least 2** entries.

```
Keyframe {
  time:       double   // seconds, relative to the start of this photo's segment
  x, y:       double   // camera center, normalized space (§1.2), relative to the
                       // image center. x in [-iw, iw], y in [-ih, ih]
  scale:      double   // >= 1.001
  rotation:   double   // radians, clockwise
  easing:     Easing   // easing of the segment that STARTS at this keyframe
}
```

### 3.1 Sampling rules

Given a local time `t` in seconds:

1. If `t <= kf[0].time` → return `kf[0]` state.
2. If `t >= kf[n-1].time` → return `kf[n-1]` state.
3. Otherwise find the segment `i` such that `kf[i].time <= t < kf[i+1].time`.
4. `u = (t - kf[i].time) / (kf[i+1].time - kf[i].time)` (guarded `dt > 1e-6`).
5. `e = ease(kf[i].easing, u)` — the easing of the **start** keyframe of the segment.
6. Interpolate `x`, `y`, `scale`, `rotation` **linearly in the eased parameter**.
   - `scale` interpolates in **log space** (`exp(lerp(log s0, log s1, e))`) so that
     constant zoom speed is perceived as perceptually uniform. If either scale
     is `<= 0` fall back to linear.
   - `rotation` takes the **shortest path**: add/subtract `2*pi` to the end value
     until `|r1 - r0| <= pi`.

Keyframe lists must be sorted by time; the parser sorts them and rejects
duplicates closer than `1e-3 s`.

### 3.2 Safety clamp (applied after sampling, before rendering)

The camera must never reveal an area outside the image. For the sampled state:

```
hw = vw / (2*scale)
hh = vh / (2*scale)
bw = hw*|cos r| + hh*|sin r|
bh = hw*|sin r| + hh*|cos r|
cx = clamp(cx, -iw + bw, iw - bw)      // if bw*2 > 2*iw, center: cx = 0
cy = clamp(cy, -ih + bh, ih - bh)      // same
```

If the rotated+zoomed viewport is wider than the image (`2*bw > 2*iw`), the axis is
centered instead of clamped, and the authoring layer must have prevented this by
enforcing the minimum scale (§4).

---

## 4. Minimum scale (no-crop-guarantee)

Rotation increases the required footprint. For a given image and viewport, the
minimum safe scale that guarantees full coverage at any rotation is:

```
sMinAtRot(r) = max( (vw*|cos r| + vh*|sin r|) / (2*iw),
                    (vw*|sin r| + vh*|cos r|) / (2*ih) )
```

Since `iw, ih` already include the cover fit, `sMinAtRot(0) >= 1`.
Authoring (random generator + gesture editor) refuses to produce a keyframe with
`scale < sMinAtRot(rotation) * 1.001`. The editor surfaces this as a live "safe
area" indicator and a haptic warning; the value is never silently mutated at render
time (except by the safety clamp in §3.2, which is idempotent for valid input).

---

## 5. Pan limits

The **maximum usable camera travel** at a given scale/rotation, used by the random
generator to keep motion perceptible but legal:

```
maxPanX(scale, r) = max(0, iw - bw)
maxPanY(scale, r) = max(0, ih - bh)
```

Random pan targets are drawn in `[-0.85, 0.85] * maxPan` and then clamped by §3.2,
so the motion always has visual headroom and never touches the image edge.

---

## 6. Timeline / project composition

### 6.1 Segment duration (display duration of a photo)

`PhotoItem.duration` is the **full display window** of the photo on the timeline,
including any transition overlap (the standard editor model — e.g. CapCut/Premiere).
The motion of the photo runs across the full window, so the camera is still moving
during a transition, which is what makes moves feel continuous.

Defaults: `duration = 5.0 s`, allowed `[1.0, 30.0]` s.

### 6.2 Transitions

A transition with duration `D` between photo `i` and `i+1`:

- The *cut point* (midpoint of the transition) is at the boundary between the two
  segments: `t_i + duration_i`.
- The transition **window** is `[boundary - D/2, boundary + D/2]`.
- During the window, photo `i` and photo `i+1` are both rendered:
  `p = (t - (boundary - D/2)) / D`, `p in [0,1]`.
- `D` is clamped to `min(D, duration_i, duration_{i+1})` so a segment can never be
  fully consumed twice, and `D >= 0`. `D = 0` means a hard cut (`none`).
- **First and last transitions are ignored** (no fade-in from black at the start and
  no fade-out at the end); the first photo is fully visible at `t=0` and the last is
  fully visible at the end.
- If `transition.type == fadeToBlack`, a black card may appear between them: the
  outgoing photo fades to black over the first half, the incoming photo fades in from
  black over the second half. This is intentional and specified — it is never
  generated accidentally.

### 6.3 Timeline index

```
starts[0] = 0
starts[i+1] = starts[i] + duration_i          // sums, NOT reduced by overlaps
totalDuration = sum(duration_i)
```

This is the model used by the preview timeline and the exporter, so seeking in the
preview and the exported MP4 timeline always agree.

### 6.4 Layer resolution at time t

```
for each boundary k (between photo k and k+1), with D_k = clamped transition duration:
  if D_k > 0 and |t - boundary_k| < D_k/2:
      emit layer(outgoing = k, incoming = k+1, p = ...)
```

Otherwise find `i` with `starts[i] <= t < starts[i] + duration_i` → single layer `i`.
If `t >= totalDuration`, use the last photo at its final keyframe, `p=1`.

**Coverage invariant** (machine-checked for every type at `p = 0, 0.05 … 1.0`).
"Coverage" means *fraction of the viewport that is painted by at least one layer*:

| Group | Types | Invariant |
|---|---|---|
| Alpha-complementary | `crossDissolve`, `fade`, `zoomTransition`, `smoothZoom`, `blurTransition`, `none` | `alpha_out + alpha_in == 1.0` exactly, and both layers' geometry covers the full viewport |
| Spatially complementary | `slideLeft`, `slideRight` | `alpha_out == alpha_in == 1.0`, and `offset_in - offset_out == 1.0` viewport width, so the two rects together tile `[0,1]` with no gap and no black |
| Intentional black | `fadeToBlack` | not 1.0 by design (see §6.2); the only type allowed to show black, and only in the middle of its window |

This is the machine-checked guarantee of "no unintended black frames between photos".
A transition type that violates its row's invariant is a test failure.

### 6.5 Local photo time

For a layer of photo `i`: `local = clamp(t - starts[i], 0, duration_i)`.
During the incoming half of a transition, `local` is small but positive, so the
incoming photo starts its motion immediately; during the outgoing half, `local`
approaches the end, so the outgoing photo finishes its motion. No reset, no jump.

---

## 7. Rendering

### 7.1 Layer draw

For a layer with camera state `(cx, cy, scale, rotation)` and alpha `a`:

The layer is drawn into a full-viewport quad. Texture coordinates are transformed so
that image point `q` (in normalized units, origin at image center) maps to the
viewport. In GL convention (NDC, y up, viewport `[-1..1]` on both axes regardless of
aspect):

```
// viewport half extents in normalized units
hw = vw / 2, hh = vh / 2

// position of the camera in texture space: uv of image center is (0.5, 0.5)
// normalized image coords -> uv:  u = 0.5 + x / (2*iw),  v = 0.5 - y / (2*ih)

M = T(0,0) * S(1/hw, 1/hh) * S(scale) * R(-rotation) ... expressed directly:
```

The renderer builds the quad vertices in image-normalized space and applies:

```
ndc = R(-r) * (q - c) * (1/hw, 1/hh) * ... 
```

Concretely, for each of the 4 quad corners covering the visible image area:

```
d  = (q - c)                 // offset from camera center, normalized units
d' = rotate(d, +r)           // image rotates clockwise
ndc.x = d'.x / hw * scale
ndc.y = -d'.y / hh * scale   // flip: normalized image y grows down, NDC y grows up
uv    = (0.5 + q.x/(2*iw), 0.5 - q.y/(2*ih))
```

Because `scale` divides the visible window (`hw`/`hh` were derived from `vw/(2*scale)`
in §1.3), the draw uses `scale/hw` where `hw = vw/2`. The vertex shader therefore gets
`u_scale = 2*scale/vw` and `u_scaleY = 2*scale/vh`, plus a rotation matrix and a
center offset. The exact shader is in `OpenGLRenderer.kt`; the validator reproduces
this math in `tools/validate/renderer.py` so a golden frame comparison can be made.

Filtering: **linear** for minification with mipmaps when the image is downscaled by
more than 2x, **linear** for magnification. No upscale beyond the source resolution is
ever requested from the decoder (§8).

### 7.2 Transition blending

Each layer renders into the same framebuffer with premultiplied alpha `a`.
Shader must multiply RGB and A by the layer alpha. Blend func `ONE, ONE_MINUS_SRC_ALPHA`
with premultiplied colors. Per-type alpha/offset:

| Type | Outgoing layer | Incoming layer |
|---|---|---|
| `crossDissolve` | `a = 1-p` | `a = p` |
| `fade` | `a = 1` (holds, then alpha `1-p` over whole window — same math as crossDissolve but the outgoing layer's motion is frozen at the boundary state) | `a = p` |
| `fadeToBlack` | `a = 1-2p` for `p<=0.5`, `0` after; black quad behind | `a = 2p-1` for `p>=0.5`, `0` before; black quad behind |
| `slideLeft` | translate `-p*vw`, `a=1` | translate `(1-p)*vw`, `a=1` (tiles with the outgoing rect) |
| `slideRight` | translate `+p*vw`, `a=1` | translate `(p-1)*vw`, `a=1` (tiles with the outgoing rect) |
| `zoomTransition` | `scale *= 1+0.25p`, `a = 1-p` | `scale *= 0.8+0.2p`, `a = p` |
| `smoothZoom` | `scale *= 1+0.12p`, `a = 1-p` (gentler) | `scale *= 0.94+0.06p`, `a = p` |
| `blurTransition` | two-pass separable gaussian, radius `b = 12*p` px @1080p, `a = 1-p` | radius `b = 12*(1-p)`, `a = p` |
| `none` | hard cut: `p` snaps to 0/1 |

**Blur fallback:** on devices without the required FBO extension, `blurTransition`
degrades to `crossDissolve` — a documented, deterministic fallback, not a bug.

Slide directions are **physical** (LTR layout): `slideLeft` moves the outgoing image
towards the left edge of the screen. In RTL app language the *UI* mirrors, but the
video's physical direction is fixed — a video looks identical on every phone.

---

## 8. Encoding

### 8.1 Resolution & aspect

Requested `(outW, outH)` comes from the aspect preset + resolution preset
(`720p` = 720px on the **short** side, `1080p` = 1080, `1440p` = 1440, `2160p` = 2160).
`original` aspect = aspect of the **first** photo, clamped to `[9:16, 16:9]`.

Dimensions are rounded to an **even** value (multiple of 2) — the hard requirement for
4:2:0 chroma. No further rounding is applied by default, so `1080p/16:9` is exactly
`1920x1080`, not `1920x1072`. If the chosen encoder reports stricter stride alignment
(`MediaCodecInfo.VideoCapabilities` / `getWidthAlignment()`), the exporter rounds the
*encoder input* to that alignment and crops the extra rows/columns on decode, so the
delivered frame size never changes because of a device quirk.

### 8.2 Bitrate

```
pixelsPerSecond = outW * outH * fps
base            = 0.10 bits/pixel/second      (standard, H.264)
high            = 0.16
maximum         = 0.24
hevcFactor      = 0.70                        (HEVC achieves the same quality at 70%)
bitrate         = clamp(base * pixelsPerSecond * hevcFactor, 1_500_000, 100_000_000)
```

`custom` mode takes the user value and clamps it to the encoder-reported range
`[videoBitrateRange]`. The chosen bitrate is always logged with the export so the
"quality was not artificially reduced" rule is auditable.

### 8.3 Source resolution policy

- The decoder is asked for `inSampleSize = 1` whenever the decoded bitmap fits the
  per-device budget, otherwise the smallest power-of-2 subsample that fits
  (§ already downscaling to `>= outW*1.25` is pointless).
- If `sourceWidth < outW`, the image is rendered at its native resolution and
  upscaled only by the camera zoom that the user chose — the app never resamples the
  original file on disk and never claims the output has more detail than the input.
  A one-time, dismissible warning is shown when `sourcePixels < outputPixels * 0.6`.
- Original files are **never modified**; only a thumbnail copy + the video are written.

### 8.4 Frame timestamps

`presentationTimeUs = round(frameIndex * 1_000_000 / fps)`. **Never** accumulate a
float of `1/fps` (drift). Audio PTS comes from the decoder/mixer in microseconds and
is offset by the audio start trim. Muxer writes video track first for maximum player
compatibility (some players mis-detect fps when audio is first).

---

## 9. Audio

- Sources: MP3, AAC/M4A, WAV, OGG. Volume `0..1` (UI 0..200% with a limiter at 1.0),
  fade in/out durations, trim `(start, end)`, loop on/off.
- Target length = `totalDuration` of the video.
- If the trimmed clip is **shorter** and `loop == true`: loop seamlessly until the
  target length; the final repetition is truncated. If `loop == false`, the remainder
  is silence (with the fade-out applied at the end of the audio, not the end of the
  video).
- If **longer**: truncate to the target length, but first subtract the fade-out.
- Fades are applied **in the sample domain** (per-sample gain ramp) by the Kotlin
  mixer, and identical ramps are reproduced by the validator.
- Audio track is `AAC LC`, 44.1 kHz or 48 kHz (source rate preferred, resampled only
  if the encoder rejects it), stereo, 128 kbps (192 for `maximum` quality).
- Sync: the muxer starts audio PTS at `0` for the first written sample and video PTS
  at `0` for the first frame; both tracks end at `totalDuration` within one frame.

---

## 10. Random motion (deterministic)

`Randomize` is **reproducible** from `(projectSeed, photoIndex, photoId)`:

```
seed_i = fnv1a64(projectSeed XOR fnv1a64(photoId) XOR (photoIndex+1)*0x9E3779B97F4A7C15)
```

`fnv1a64` is the 64-bit FNV-1a hash over UTF-8 bytes. The Dart and Kotlin
implementations of the PRNG (`xorshift128+` seeded by SplitMix64 from `seed_i`) are
identical and covered by golden vectors.

Generation rules:

1. Choose a `motionType` by weighted draw from the enabled set. The previous
   photo's type is **removed from the pool** for this draw (not merely down-weighted),
   which makes "no identical motion on consecutive photos" a hard, seed-independent
   guarantee. The exclusion is skipped only when the pool has a single entry.
2. Direction (for directional types) is drawn independently, so the same type can
   still look different on consecutive photos.
3. `intensity` in `[0.35, 1.0]` from the profile's intensity range.
4. Start scale `s0 = 1 + 0.02*i`, end scale `s1` per type, both `>= sMinAtRot(r)+1e-3`.
5. Pan vector length `= intensity * 0.8 * min(maxPanX, maxPanY)`, direction from the
   type (or random for `drift`/`combined`) with the sign chosen by the PRNG.
6. Rotation: `0` for all pure pan/zoom types; `±(0.4..2.2)°` for `subtleRotation` and
   `drift`; `±(0.8..1.6)°` for `combined`.
7. Emit 2 keyframes (`t=0`, `t=duration`) with `easing = smoother`, unless the type is
   `combined`/`drift`, which emit 3 (adding a mid keyframe at `t=duration*0.5` with the
   pan perpendicularly offset by `±0.2*travel` to create a curved path).
8. Locked photos (`isLocked == true`) are **skipped** by every randomize operation.
9. `Regenerate all` keeps each photo's `motionType` if the user pinned it
   (`isMotionTypePinned`), otherwise re-rolls everything.

---

## 11. Precision & tolerance

- All math in `double` (Dart) / `double` (Kotlin). No `float` for camera state.
- Golden vectors store 9 decimal places; comparison tolerance `1e-6` absolute for
  camera state, `1e-9` for easing outputs.
- Frame checksum comparison tolerance: mean absolute error `<= 2/255` per channel
  between the Python reference and a Kotlin render of the same project. (Exact match
  is not achievable across GPU texture filtering; the tolerance is chosen to catch
  motion/framing bugs while ignoring dithering.)

---

## 12. Curved paths (motionPath)

A photo's motion may be a **path**: the camera centre follows a parametric
curve while zoom and rotation interpolate independently. Paths are a first-class
`motionPath` field on the motion profile, persisted with the project and sent in
the export request. The three runtimes (Python reference, Dart, Kotlin) must
produce identical results for identical inputs; the goldens in
`tools/validate/motionshot/golden/motion_paths.json` (mirrored to
`test/golden/` and `android/app/src/test/resources/`) are the contract.

### 12.1 Model (`MotionPathSpec`)

| field | type | meaning |
|---|---|---|
| `preset` | enum id | one of the ten presets below; ids are persisted, never rename |
| `centerX`, `centerY` | double | path centre, normalized camera space (§1.2) |
| `radiusX`, `radiusY` | double | horizontal / vertical radius, normalized |
| `turns` | double | full revolutions (circular, spiral); integer for figureEight |
| `startAngle` | double | radians; the direction of travel is set by `direction` |
| `sweep` | double | radians, `arc` preset only |
| `curvature` | double | 0..1; bends sCurve / cubicBezier, sets spiral inner radius |
| `speed` | double | path-speed multiplier, clamped 0.25..3 |
| `speedEase` | double | 0..1; blends the progress through the smoother curve |
| `startZoom`, `endZoom` | double | zoom envelope; zoom interpolates in **log** space over progress |
| `startRotation`, `endRotation` | double | radians; rotation takes the **shortest arc** over progress |
| `direction` | ±1 | clockwise (1) / counter-clockwise (−1) |
| `points` | [x, y]* | user points for `custom`; 2 for `linear`; 3 for `sCurve`; 4 for `cubicBezier` |
| `isCustom`, `isUserEdited` | bool | editor bookkeeping |

The ten presets: `linear`, `circularCw`, `circularCcw`, `elliptical`, `spiral`,
`sCurve`, `figureEight`, `arc`, `cubicBezier`, `custom`.

### 12.2 Arc-length re-parameterization (uniform speed)

Speed along the curve must be constant in arc length, so the evaluator builds a
cumulative-arc-length lookup table (LUT) once per spec and caches it:

- `N = 4096` cells; each cell's chord length is estimated with `REFINE_STEPS = 16`
  sub-chords, `LUT[0] = 0`, `LUT[i]` = sum of chord lengths up to `u = i / N`.
- `total = LUT[N]`.
- `paramAtArc(target)`: `target <= 0 → 0`, `target >= total → 1`; binary search for
  the first cell with `LUT[hi] >= target`, then re-estimate that cell with 16
  sub-chords and linearly interpolate inside the sub-chord that contains
  `target`. Result: `u = (j0 + (local − C[j0]) / ΔC) / 16 + u0`.
- Uniformity invariant: with 400 arc-length samples the max/min chord-length
  ratio must stay `< 1.03`.

### 12.3 Preset geometry — `rawPoint(spec, u)`

`u` is clamped to [0, 1]; `d = direction`. All positions are **before**
arc-length re-parameterization and **before** the §3.2 safety clamp.

- `linear`: lerp between two endpoints (`points[0..1]`, else the radius box
  diagonal centred on the path centre).
- `circularCw` / `circularCcw` / `elliptical`:
  `θ = startAngle + d·2π·turns·u`, point = `(cx + rx·cosθ, cy + ry·sinθ)`.
  (`circularCcw` uses the same formula with `direction = −1`.)
- `arc`: `θ = startAngle + d·sweep·u`, same ellipse point.
- `spiral`: `ρ = lerp(0.15 + 0.75·(1 − curvature), 1, u)`;
  point = `(cx + rx·ρ·cosθ, cy + ry·ρ·sinθ)` with the circular `θ`.
- `figureEight`: integer `k = floor(turns + 0.5)` (min 1; half-up, so all
  three runtimes tie-break identically); `a = 2π·k·u`;
  `x = cx + rx·sin a`, `y = cy + ry·sin a·cos a`. Integer `k` guarantees a C1
  seam at `u = 1`.
- `sCurve`: centripetal Catmull-Rom (§12.4) through 3 waypoints
  (`points[0..2]` if given, else `((cx−rx, cy+bend), (cx, cy), (cx+rx, cy−bend))`
  with `bend = (2·curvature − 1)·ry`).
- `cubicBezier`: cubic Hermite form through 4 points (`points[0..3]` if given,
  else symmetric control points with the same `bend`).
- `custom`: centripetal Catmull-Rom through `points` (boundary points clamped,
  so the curve runs exactly from the first point to the last); 0 points →
  centre, 1 point → that point.

Tangents for editor arrows and seam tests: central finite difference (ε = 1e-3),
one-sided at `u ≤ ε` and `u ≥ 1 − ε` (so closed paths report their true seam
tangents).

### 12.4 Centripetal Catmull-Rom (α = 0.5)

The curve is evaluated with the Sverchok (Barry–Goldman) form of the centripetal
rational Catmull-Rom: knot intervals `Δt = ‖pᵢ − pᵢ₋₁‖` (α = 0.5 → square-root
chord lengths, used verbatim), then two barycentric interpolation passes over
`(a1, a2, b1, b2)` with the segment-local parameter. Degenerate guards: any
interval `< 1e-12` collapses to its endpoint. This form is **C1 continuous at the
knots** — verified exactly (not by finite differences) with the analytic segment
derivative; the worst knot-derivative mismatch in the goldens is `< 1e-9`.
(The plain barycentric form is only C0 and must not be used.)

### 12.5 Freehand stroke smoothing

Touch strokes (normalized, up/down-sampled by the editor) are reduced to a
smooth `custom` path deterministically:

1. drop consecutive points closer than `0.004` normalized units;
2. resample to 24 points uniformly in arc length;
3. Chaikin corner-cutting ×2;
4. resample to 24 points again.

Endpoints are preserved (within 0.01); the same input always gives the same
24-point output on all three runtimes.

### 12.6 Sanitizing (cover-safe invariant)

`sanitizePath(spec, fit, vp)` clamps every authoring field so the whole path
stays inside the §5 pan limits and above the §4 minimum scale, even at the
worst (zoom, rotation) the envelope reaches:

- `sMin = minScaleAtRotation(rMax) · 1.002` with `rMax = max(|r0|, |r1|)`;
  both zooms are lifted up to `sMin` (never lowered);
- pan limits from `maxPan(max(s0, s1), rMax)` clamp `center`, `radiusX ∈
  [0, mx]`, `radiusY ∈ [0, my]` and every `points` entry;
- `turns ∈ [0.05, 4]`, `sweep ∈ [0.1, 2π]`, `curvature ∈ [0, 1]`,
  `speed ∈ [0.25, 3]`, `speedEase ∈ [0, 1]`; angles, direction, `preset`,
  `isCustom` / `isUserEdited` pass through.

Sanitize is idempotent and is applied on every write to the profile.

### 12.7 Deterministic generation

Random curved motion reuses the §10 machinery (`Xorshift128Plus`,
`photoSeed`, no `Math.random()`). `pickPathPreset` draws from the weighted pool

`circularCw 1.2, circularCcw 1.2, elliptical 1.0, sCurve 1.1, spiral 0.8,
figureEight 0.7, arc 1.0`

with the **previous photo's preset removed from the pool** (hard no-repeat
guarantee, same rule as §10). `generatePathProfile(rng, intensity, duration,
fit, vp, seed, …)` performs exactly these draws, in this order (the order is
part of the contract; a preset may be pre-selected, which skips only draw 0):

1. `direction = sign()`
2. `startAngle = range(0, 2π)`
3. `curvature = range(0.15, 0.85)`
4. `speed = range(0.8, 1.4)`
5. `speedEase = range(0, 0.5)`
6. if circular/spiral: `turns = 2.0` when `bool(0.25)`
7. if figureEight: `turns = irange(1, 2)`
8. if arc: `sweep = range(0.6π, 1.8π)`
9. `pattern = irange(0, 4)` → zoom envelope:
   - 0: `s0 = base, s1 = base·(1.18 + 0.24i)` (curve + push in)
   - 1: `s0 = base·(1.18 + 0.24i), s1 = base` (curve + pull back)
   - 2: `s0 = base·(1.05 + 0.08i), s1 = s0·range(1.0, 1.06)` (draw 10)
   - 3: `s0 = 1.03 + 0.04i, s1 = s0·(1.12 + 0.18i)` (slow push)
   - 4: `s1 = 1.03 + 0.04i, s0 = s1·(1.12 + 0.18i)` (pull back)
   with `base = 1.04 + 0.10·i`
10. (see pattern 2 above)
11. `bool(0.5)` → 12. `r1 = radians(range(0.4, 1.5)·sign())`, else `r1 = 0`; always `r0 = 0`
13. `radiusX = r = margin·(0.35 + 0.45i)` (floor 0.03) where
    `margin = min(maxPanX, maxPanY)` at `(max(s0,s1), |r1−r0|)` (floor 0.02);
    `radiusY = r·range(0.7, 1.0)` for elliptical / sCurve / figureEight, else `r`
14. `bool(0.3)` → 15. `center = (range(−0.1, 0.1), range(−0.1, 0.1))`, else `(0, 0)`

Then: `sanitizePath` → `bakePath` (128 samples) → the profile's `motionType` is
derived from the zoom envelope (`s1 ≥ s0 → zoomIn`, `s0 > s1 → zoomOut`,
equal → `drift`) — the path itself carries the curve, the motionType only
describes the zoom.

Dart editor flow: each regenerate rolls `bool(kCurvedPathChance = 0.40)` for
curved vs straight motion (manual/locked photos are protected: a photo the user
touched by hand keeps its motion — the `protectManual` rule is Dart-only, the
native side never re-rolls).

### 12.8 Preview, render and export integration

- **Progress**: `q = clamp(t / duration, 0, 1)`; `p = min(q·speed, 1)`;
  `p += speedEase·(smoother(p) − p)`. With `speed > 1` the camera holds the end
  pose after `duration / speed`.
- **Evaluation at time t**: `u = paramAtArc(p·total)`;
  `position = rawPoint(spec, u)`;
  `scale = logLerp(startZoom, endZoom, p)` (§2 log-space scale);
  `rotation = startRotation + shortestAngle(startRotation, endRotation)·p`;
  then the §3.2 safety clamp. Preview (Dart) and native render/export (Kotlin)
  both call this same evaluator — there is no second, approximate implementation.
- **Bake**: 128 uniform samples over `[0, duration]` (endpoints forced to
  `t = 0` and `t = duration`), each sampled through the evaluator, emitted as
  `linear`-eased keyframes so the baked profile is a faithful stand-in for
  consumers that only understand keyframes.
- **Export**: the request carries the full `motionPath` spec JSON; the native
  side parses it leniently (missing/malformed fields fall back to the baked
  keyframes, never a crash).

### 12.9 Goldens & tolerances

`verify.py` regenerates the goldens; the Dart (`test/motion_path_test.dart`) and
Kotlin (`MotionPathConformanceTest.kt`) suites replay them. Coverage: all ten
preset geometries (17 samples each + total length + seam tangents), bake
fidelity (128-sample bake sampled at 26 points must match the live evaluator),
seam continuity (`rawPoint(0) ≈ rawPoint(1)`, tangent angle jump `< 1e-9`),
arc-length uniformity (ratio `< 1.03`), exact C1 knot derivatives, the 24-point
freehand pipeline, and a 40-draw randomized generation replay. Comparison
tolerances: `1e-8` for engine state, `1e-9` for baked keyframes, stroke output
and seam quantities, exact (integer) for seeds and preset sequences.
