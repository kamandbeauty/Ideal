# Phase 1 — Foundation (spec, reference model, golden vectors)

Status: **PASS** — this is the only phase fully verifiable in this environment.

## What was built

`docs/MOTION_SPEC.md` is the single source of truth: coordinate system, easing,
keyframe interpolation, cover fit and clamping, transitions, timeline windows,
render pipeline, encoding parameters, audio rules, determinism, precision.
Dart and Kotlin are both ports of it; the Python reference in
`tools/validate/motionshot/` is the executable expression of the same document.

## Verification

`python3 -m motionshot.verify` → **1850/1850 checks pass**, writing 8 golden
vectors consumed by both the Dart cross-check and the JVM conformance test:

| Fixture | Contents |
| --- | --- |
| `easing.json` | 6 curves + 2 custom cubic-beziers × 21 samples |
| `prng.json` | FNV-1a vectors, photo seeds, 16 raw draws, 8 doubles |
| `keyframes.json` | 4-keyframe profile, 51 samples |
| `camera.json` | viewport/fit, 3 rotations × half-extent/min-scale/max-pan/clamp |
| `profiles.json` | all 15 motion types + auto-build + lock behaviour |
| `transitions.json` | 9 transitions × 21 progress steps + a 4-photo timeline |
| `encoding.json` | 108 bitrate combos + even-rounding |
| `audio.json` | loop crossfade, trim, fades, volume rules |

An end-to-end reference render was produced with the same math
(1920×1080, 15.000 s, 450 frames @ 30 fps, H.264+AAC, 2.13 MB) — as a
*reference*, not as an app feature.

## Invariants proven by the reference run

* cover-fit exposes no background at any time: `bw ≤ iw`, `bh ≤ ih` for every
  motion type, every sample;
* `alpha_out + alpha_in == 1` for the 6 alpha-complementary transitions,
  slide offsets differ by exactly 1.0 viewport width;
* `fadeToBlack` is the only transition that may show black;
* no two consecutive auto-assigned motion types repeat;
* locked profiles survive `regenerate=True` byte for byte;
* even output dimensions, PTS `round(i·1e6/fps)` with no drift.

## Completion

Phase 1: **100%**, fully verified. This is the phase whose tests are the
evidence for everything that could not be executed later.
