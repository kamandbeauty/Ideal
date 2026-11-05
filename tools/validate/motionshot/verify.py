#!/usr/bin/env python3
"""Generate golden vectors + verify invariants. Run: python3 -m motionshot.verify"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np

from .camera import (CameraState, ImageFit, Keyframe, Viewport, clamp_camera,
                     half_extent, max_pan, min_scale_at_rotation,
                     sample_keyframes)
from .mathx import Xorshift128Plus, ease, fnv1a64, photo_seed, to_signed64
from .profile import (MOTION_TYPES, PhotoMotionInput, build_profiles,
                      generate_profile, regenerate_one)
from .timeline import (TRANSITION_TYPES, Layer, TransitionSpec,
                       resolve_layers, transition_draw_layers)

HERE = os.path.dirname(os.path.abspath(__file__))
GOLDEN_DIR = os.path.join(HERE, "golden")

FAILS: list[str] = []
CHECKS = [0, 0]


def check(name: str, cond: bool, detail: str = ""):
    CHECKS[0] += 1
    if cond:
        CHECKS[1] += 1
    else:
        FAILS.append(f"{name} {detail}")
        print(f"  FAIL  {name} {detail}")


def close(a, b, tol=1e-9) -> bool:
    return abs(a - b) <= tol


# ---------------------------------------------------------------------------
def gen_easing():
    out = {}
    for kind in ["linear", "easeIn", "easeOut", "easeInOut", "smooth", "smoother"]:
        out[kind] = [[t, ease(kind, t)] for t in np.linspace(0, 1, 21)]
    out["custom"] = [[t, ease("custom", float(t), (0.25, 0.1, 0.25, 1.0))]
                     for t in np.linspace(0, 1, 21)]
    out["custom_ez"] = [[t, ease("custom", float(t), (0.42, 0, 0.58, 1))]
                        for t in np.linspace(0, 1, 21)]
    # monotonic + endpoints
    for k, rows in out.items():
        check(f"easing[{k}].endpoints",
              close(rows[0][1], 0.0, 1e-12) and close(rows[-1][1], 1.0, 1e-12),
              str((rows[0][1], rows[-1][1])))
        check(f"easing[{k}].monotonic",
              all(rows[i][1] <= rows[i + 1][1] + 1e-12 for i in range(len(rows) - 1)))
    return out


def gen_prng():
    out = {}
    rng = Xorshift128Plus(photo_seed(42, "photo-a", 0))
    out["seed_42_photo_a"] = [to_signed64(rng.next_u64()) for _ in range(16)]
    rng2 = Xorshift128Plus(fnv1a64("MotionShot"))
    out["fnv_positions"] = [[s, to_signed64(fnv1a64(s))] for s in
                            ["", "a", "photo-a", "project-1", "زیبا"]]
    out["doubles"] = [rng2.next_double() for _ in range(8)]
    out["photo_seeds"] = [[to_signed64(photo_seed(1, f"p{i}", i))] for i in range(6)]
    return out


def gen_keyframe_sampling():
    """A hand-built 4-keyframe profile that exercises every interpolation rule."""
    kfs = [
        Keyframe(0.0, -0.2, 0.05, 1.10, 0.0, "smoother"),
        Keyframe(1.5, 0.15, -0.10, 1.45, math.radians(2.0), "easeInOut"),
        Keyframe(3.0, 0.05, 0.12, 1.20, math.radians(-1.0), "linear"),
        Keyframe(5.0, -0.10, 0.0, 1.35, math.radians(3.5), "easeOut"),
    ]
    rows = []
    for t in np.linspace(0, 5.0, 51):
        st = sample_keyframes(kfs, float(t))
        rows.append([float(t), st.x, st.y, st.scale, st.rotation])
    return {"keyframes": [k.to_json() for k in kfs], "samples": rows}


def gen_camera():
    vp = Viewport(16 / 9)
    fit = ImageFit.make(4000, 3000, vp)
    rows = []
    for rot_deg in (0.0, 3.0, 10.0):
        r = math.radians(rot_deg)
        bw, bh = half_extent(vp, 1.5, r)
        s_min = min_scale_at_rotation(fit, vp, r)
        mx, my = max_pan(fit, vp, 1.5, r)
        st = clamp_camera(CameraState(0.9, -0.9, 1.5, r), fit, vp)
        rows.append({"rotation": r, "bw": bw, "bh": bh, "minScale": s_min,
                     "maxPanX": mx, "maxPanY": my,
                     "clamped": [st.x, st.y, st.scale, st.rotation]})
        # invariant: clamped camera never reveals outside the image
        check(f"camera.fit[{rot_deg}deg]",
              bw <= fit.iw + 1e-12 and bh <= fit.ih + 1e-12)
    for aspect in (9 / 16, 1.0, 4 / 5, 16 / 9, 2.39):
        v = Viewport(aspect)
        f = ImageFit.make(3000, 4000, v)
        s0 = min_scale_at_rotation(f, v, 0.0)
        check(f"camera.cover[{aspect:.3f}]", close(s0, 1.0, 1e-9), str(s0))
        bw, bh = half_extent(v, 1.0, 0.0)
        check(f"camera.exact[{aspect:.3f}]",
              close(bw, f.iw * 0 + bw) and bw <= f.iw + 1e-9 and bh <= f.ih + 1e-9)
    return {"viewport16x9": {"vw": vp.vw, "vh": vp.vh},
            "fit4000x3000": {"iw": fit.iw, "ih": fit.ih}, "rows": rows}


def gen_profiles():
    """Profile output for all 15 types + the auto builder, all deterministic."""
    vp = Viewport(16 / 9)
    out = {"types": {}}
    for mt in MOTION_TYPES:
        rng = Xorshift128Plus(photo_seed(99, "photo-x", 3))
        fit = ImageFit.make(4032, 3024, vp)
        prof = generate_profile(mt, 0.7, 5.0, fit, vp, rng, 12345)
        out["types"][mt] = prof.to_json()
        # legality: every sampled camera is inside the image and >= min scale
        for i in range(101):
            st = prof.sample(5.0 * i / 100, fit, vp)
            bw, bh = half_extent(vp, st.scale, st.rotation)
            check(f"profile[{mt}].legal@{i}",
                  bw <= fit.iw + 1e-9 and bh <= fit.ih + 1e-9,
                  f"bw={bw:.4f} iw={fit.iw:.4f} s={st.scale:.4f}")
        # first/last time exact
        check(f"profile[{mt}].timing",
              close(prof.keyframes[0].time, 0.0) and close(prof.keyframes[-1].time, 5.0))
        check(f"profile[{mt}].kfcount", len(prof.keyframes) >= 2,
              str(len(prof.keyframes)))

    photos = [PhotoMotionInput(f"p{i}", 4032, 3024, 5.0) for i in range(8)]
    built = build_profiles(photos, vp, 2024, 0.65)
    out["auto"] = {k: v.to_json() for k, v in built.items()}
    types = [v.motion_type for v in built.values()]
    out["auto_types"] = types
    consecutive = sum(1 for a, b in zip(types, types[1:]) if a == b)
    check("auto.noConsecutiveRepeat", consecutive == 0, str(types))

    # determinism: same seed -> identical profiles
    again = build_profiles(photos, vp, 2024, 0.65)
    check("auto.deterministic",
          [p.to_json() for p in again.values()] == [p.to_json() for p in built.values()])

    # locks are honoured by regenerate
    locked = dict(built)
    first = photos[0].photo_id
    locked[first].is_locked = True
    before = locked[first].to_json()
    after = build_profiles(photos, vp, 9999, 0.9, existing=locked, regenerate=True)
    check("auto.lockPreserved", after[first].to_json() == before)
    changed = sum(1 for p in photos[1:] if after[p.photo_id].to_json() !=
                  locked[p.photo_id].to_json())
    check("auto.lockOnlyOnePreserved", changed > 0, str(changed))
    out["locked_after_regen"] = {k: v.to_json() for k, v in after.items()}
    return out


def gen_transitions():
    out = {}
    for tr in TRANSITION_TYPES:
        rows = []
        for p in np.linspace(0, 1, 21):
            layers = [Layer(0, 1.0, "out", float(p), tr),
                      Layer(1, 0.5, "in", float(p), tr)]
            dl = transition_draw_layers(layers)
            rows.append([float(p), dl[0].alpha, dl[1].alpha,
                         dl[0].offset_x, dl[1].offset_x,
                         dl[0].zoom_mul, dl[1].zoom_mul,
                         dl[0].blur_px, dl[1].blur_px])
            o, i = dl
            if tr in ("crossDissolve", "fade", "zoomTransition", "smoothZoom",
                      "blurTransition", "none"):
                check(f"transition[{tr}].alpha@{p:.2f}",
                      close(o.alpha + i.alpha, 1.0, 1e-9),
                      f"{o.alpha + i.alpha}")
            elif tr in ("slideLeft", "slideRight"):
                span = max(o.offset_x, i.offset_x) - min(o.offset_x, i.offset_x)
                check(f"transition[{tr}].tiles@{p:.2f}", close(span, 1.0, 1e-9),
                      str(span))
            else:
                check(f"transition[{tr}].bounded@{p:.2f}", o.alpha + i.alpha <= 1 + 1e-9)
        out[tr] = rows

    # timeline windows
    durs = [4.0, 5.0, 3.0, 6.0]
    trans = [TransitionSpec("crossDissolve", 1.0), TransitionSpec("slideLeft", 0.5),
             TransitionSpec("fadeToBlack", 2.0), TransitionSpec("none", 0.5)]
    rows = []
    for t in np.arange(0, sum(durs) + 0.001, 0.25):
        ls = resolve_layers(float(t), durs, trans)
        rows.append([float(t), [[l.photo_index, l.role, round(l.local_time, 6),
                                 round(l.progress, 6)] for l in ls]])
        check(f"timeline.layers@{t:.2f}", 1 <= len(ls) <= 2, str(len(ls)))
    out["timeline"] = {"durations": durs,
                       "transitions": [t.to_json() for t in trans],
                       "rows": rows}
    return out


def gen_motion_paths():
    """Motion Path Engine golden vectors + invariants (spec §12)."""
    from .motion_path import (LUT_SIZE, MotionPathSpec, bake_path,
                              build_arc_lut, evaluate_path, param_at_arc,
                              path_tangent, raw_point, sanitize_path,
                              smooth_stroke)
    from .profile import (MotionProfile, generate_path_profile,
                          pick_path_preset)

    vp = Viewport(16 / 9)
    fit = ImageFit.make(4032, 3024, vp)

    specs = {
        "linearDerived": MotionPathSpec(preset="linear", radius_x=0.30,
                                        radius_y=0.20),
        "linearPoints": MotionPathSpec(preset="linear",
                                       points=[(-0.25, -0.10), (0.30, 0.18)]),
        "circleCw": MotionPathSpec(preset="circularCw", radius_x=0.30,
                                   radius_y=0.30, start_angle=-math.pi / 2),
        "circleCcw2": MotionPathSpec(preset="circularCcw", radius_x=0.25,
                                     radius_y=0.25, turns=2.0,
                                     start_angle=0.5),
        "ellipse": MotionPathSpec(preset="elliptical", radius_x=0.35,
                                  radius_y=0.18, start_angle=0.8,
                                  direction=-1),
        "spiralTight": MotionPathSpec(preset="spiral", radius_x=0.30,
                                      radius_y=0.30, curvature=0.9,
                                      turns=1.5, start_angle=-math.pi / 2),
        "spiralLoose": MotionPathSpec(preset="spiral", radius_x=0.35,
                                      radius_y=0.35, curvature=0.1,
                                      turns=1.0),
        "sCurveDefault": MotionPathSpec(preset="sCurve", radius_x=0.30,
                                        radius_y=0.20, curvature=0.7),
        "sCurve5pts": MotionPathSpec(preset="sCurve",
                                     points=[(-0.30, -0.15), (-0.12, 0.18),
                                             (0.02, -0.10), (0.18, 0.16),
                                             (0.32, -0.18)]),
        "fig8": MotionPathSpec(preset="figureEight", radius_x=0.35,
                               radius_y=0.20, turns=2.0),
        "arcPart": MotionPathSpec(preset="arc", radius_x=0.30, radius_y=0.30,
                                  sweep=1.2, start_angle=2.0),
        "bezierDefault": MotionPathSpec(preset="cubicBezier", radius_x=0.40,
                                        radius_y=0.25, curvature=0.8),
        "bezierPts": MotionPathSpec(preset="cubicBezier",
                                    points=[(-0.35, -0.20), (-0.10, 0.30),
                                            (0.15, -0.35), (0.35, 0.25)]),
        "custom4": MotionPathSpec(preset="custom",
                                  points=[(-0.30, -0.10), (-0.10, 0.20),
                                          (0.20, 0.10), (0.35, -0.20)]),
        "degPoint": MotionPathSpec(preset="circularCw", radius_x=0.0,
                                   radius_y=0.0),
        "holdEarly": MotionPathSpec(preset="circularCw", radius_x=0.20,
                                    radius_y=0.20, speed=1.8, speed_ease=0.4,
                                    start_angle=-math.pi / 2),
    }

    out: dict = {"lutSize": LUT_SIZE, "specs": {}}
    sanitized = {}
    for name, spec in specs.items():
        spec = sanitize_path(spec, fit, vp)
        sanitized[name] = spec
        cum, total = build_arc_lut(spec)
        rows = []
        for i in range(17):
            t = 5.0 * i / 16
            st = evaluate_path(spec, fit, vp, t, 5.0)
            rows.append([round(t, 6), round(st.x, 9), round(st.y, 9),
                         round(st.scale, 9), round(st.rotation, 9)])
        out["specs"][name] = {
            "spec": spec.to_json(),
            "total": round(total, 9),
            "samples": rows,
            "tangentStart": [round(v, 9) for v in path_tangent(spec, 0.0)],
            "tangentEnd": [round(v, 9) for v in path_tangent(spec, 1.0)],
        }
        # cover safety: the evaluated state is already clamped AND the
        # footprint stays inside the image at every time (spec §12.6)
        for i in range(0, 101):
            t = 5.0 * i / 100
            st = evaluate_path(spec, fit, vp, t, 5.0)
            c = clamp_camera(st, fit, vp)
            bw, bh = half_extent(vp, st.scale, st.rotation)
            check(f"path[{name}].coverSafe@{i}",
                  abs(st.x - c.x) < 1e-15 and abs(st.y - c.y) < 1e-15
                  and bw <= fit.iw + 1e-9 and bh <= fit.ih + 1e-9,
                  f"bw={bw:.4f} iw={fit.iw:.4f}")

    # arc-length uniformity: equal arc steps must have (nearly) equal chords
    out["uniformity"] = {}
    for name in ("circleCw", "ellipse", "fig8", "spiralTight", "custom4"):
        spec = sanitized[name]
        cum, total = build_arc_lut(spec)
        if total < 1e-6:
            continue
        pts = [raw_point(spec, param_at_arc(spec, cum, total * j / 400))
               for j in range(401)]
        ds = [math.hypot(pts[j + 1][0] - pts[j][0], pts[j + 1][1] - pts[j][1])
              for j in range(400)]
        ratio = max(ds) / min(ds)
        out["uniformity"][name] = {"ratio": round(ratio, 6),
                                   "total": round(total, 9)}
        check(f"path.uniform[{name}]", ratio < 1.03, f"ratio={ratio:.5f}")

    # closed-path seam continuity. Position must be identical at u=0 and
    # u=1; the tangent from one-sided chords carries a documented estimator
    # bias of ~2*pi*e*turns (chord vs tangent), so the invariant bound is
    # that, plus a small margin. The *exact* measured jump is stored in the
    # golden and replayed bit-for-bit by the Dart/Kotlin conformance tests.
    e = 1e-3
    out["seams"] = {}
    for name in ("circleCw", "circleCcw2", "fig8"):
        spec = sanitized[name]
        a = raw_point(spec, 0.0)
        b = raw_point(spec, 1.0)
        ta = path_tangent(spec, 0.0)
        tb = path_tangent(spec, 1.0)
        ang = abs(math.atan2(ta[1], ta[0]) - math.atan2(tb[1], tb[0]))
        ang = min(ang, 2 * math.pi - ang)
        bound = 2 * math.pi * e * spec.turns + 0.005
        out["seams"][name] = {"posJump": round(math.hypot(a[0] - b[0],
                                                          a[1] - b[1]), 12),
                              "angleJump": round(ang, 9)}
        check(f"path.seam[{name}]",
              math.hypot(a[0] - b[0], a[1] - b[1]) < 1e-9 and ang < bound,
              f"pos={math.hypot(a[0]-b[0], a[1]-b[1]):.2e} ang={ang:.2e}")

    # bake fidelity: baked keyframes approximate the path within chord error
    out["bake"] = {}
    for name in ("circleCw", "sCurve5pts", "bezierPts", "custom4", "linearPoints"):
        spec = sanitized[name]
        kfs = bake_path(spec, fit, vp, 5.0)
        max_pos = 0.0
        max_s = 0.0
        for i in range(26):
            t = 5.0 * i / 25
            st = evaluate_path(spec, fit, vp, t, 5.0)
            bk = sample_keyframes(kfs, t)
            max_pos = max(max_pos, abs(st.x - bk.x), abs(st.y - bk.y))
            max_s = max(max_s, abs(st.scale - bk.scale))
        out["bake"][name] = {"maxPosErr": round(max_pos, 9),
                             "maxScaleErr": round(max_s, 9)}
        check(f"path.bake[{name}]", max_pos < 5e-3 and max_s < 2e-3,
              f"pos={max_pos:.2e} scale={max_s:.2e}")

    # C1 continuity at the waypoints of the spline presets (no jumps, no
    # kinks): the exact analytic derivative of the left segment at its end
    # must equal the right segment's derivative at its start.
    from .motion_path import _cr_segment_derivative
    out["c1"] = {}
    for name, npts in (("sCurve5pts", 5), ("custom4", 4)):
        spec = sanitized[name]
        pts = spec.points
        n = len(pts)
        worst = 0.0
        for i in range(1, n - 1):
            segL = [pts[i - 2] if i - 2 >= 0 else pts[0], pts[i - 1],
                    pts[i], pts[i + 1] if i + 1 < n else pts[-1]]
            segR = [pts[i - 1], pts[i], pts[i + 1],
                    pts[i + 2] if i + 2 < n else pts[-1]]
            left = _cr_segment_derivative(segL[0], segL[1], segL[2],
                                          segL[3], True)
            right = _cr_segment_derivative(segR[0], segR[1], segR[2],
                                           segR[3], False)
            worst = max(worst, abs(left[0] - right[0]),
                        abs(left[1] - right[1]))
        out["c1"][name] = round(worst, 12)
        check(f"path.c1[{name}]", worst < 1e-9, f"defect={worst:.2e}")

    # freehand smoothing pipeline (deterministic, 24 points, ends preserved)
    # The golden stores the 9-dp input array, and the conformance tests feed
    # THAT array to smooth_stroke — so the published output must be computed
    # from the rounded input (not the unrounded source values), keeping the
    # round-trip error within the tests' 1e-9 tolerance.
    raw_full = [(-0.30 + 0.012 * j + 0.006 * math.sin(0.7 * j),
                 0.05 * math.sin(0.35 * j)) for j in range(0, 61, 2)]
    raw = [(round(x, 9), round(y, 9)) for (x, y) in raw_full]
    sm = smooth_stroke(raw)
    sm2 = smooth_stroke(raw)
    out["stroke"] = {"input": [[x, y] for (x, y) in raw],
                     "output": [[round(x, 9), round(y, 9)] for (x, y) in sm]}
    check("path.stroke.count", len(sm) == 24, str(len(sm)))
    check("path.stroke.deterministic", sm == sm2)
    check("path.stroke.ends",
          math.hypot(sm[0][0] - raw[0][0], sm[0][1] - raw[0][1]) < 0.01
          and math.hypot(sm[-1][0] - raw[-1][0],
                         sm[-1][1] - raw[-1][1]) < 0.01)

    # random curved motion: no adjacent preset repeats + legal + deterministic
    def run_random():
        rng = Xorshift128Plus(photo_seed(2026, "path-gen", 0))
        prev = None
        seq = []
        profs = {}
        for _ in range(40):
            preset = pick_path_preset(rng, prev)
            prof = generate_path_profile(rng, 0.7, 5.0, fit, vp, 12345,
                                         exclude_preset=prev, preset=preset)
            seq.append(preset)
            profs.setdefault(preset, prof.to_json())
            prev = preset
        return seq, profs

    seq, profs = run_random()
    seq2, _ = run_random()
    out["random"] = {"presets": seq,
                     "profiles": {k: v for k, v in list(profs.items())[:5]}}
    check("path.random.deterministic", seq == seq2)
    check("path.random.noRepeat",
          all(a != b for a, b in zip(seq, seq[1:])), str(seq))
    check("path.random.poolCovered", len(set(seq)) >= 5, str(sorted(set(seq))))
    for name, prof_json in profs.items():
        prof = MotionProfile.from_json(prof_json)
        assert prof.path is not None, f"random {name} lost its path"
        for i in range(21):
            st = prof.sample(5.0 * i / 20, fit, vp)
            bw, bh = half_extent(vp, st.scale, st.rotation)
            check(f"path.random.legal[{name}@{i}]",
                  bw <= fit.iw + 1e-9 and bh <= fit.ih + 1e-9)

    # JSON round-trip of the spec model
    for name, spec in sanitized.items():
        rt = MotionPathSpec.from_json(spec.to_json())
        check(f"path.json[{name}]", rt.to_json() == spec.to_json())
    check("path.json.rejectsUnknown",
          _rejects_unknown_preset())
    return out


def _rejects_unknown_preset() -> bool:
    from .motion_path import MotionPathSpec
    try:
        MotionPathSpec.from_json({"preset": "warpDrive"})
        return False
    except ValueError:
        return True


def gen_audio_rules():
    """Analytic checks of §9 without touching ffmpeg."""
    from .audio import AudioSettings, build_audio
    import wave
    import tempfile
    # build a 2s 440Hz wav at 48k, stereo
    sr = 48000
    t = np.arange(int(2.0 * sr)) / sr
    tone = np.stack([0.5 * np.sin(2 * np.pi * 440 * t)] * 2, axis=1).astype(np.float32)
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    tmp.close()
    pcm16 = (tone * 32767).astype(np.int16)
    with wave.open(tmp.name, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(pcm16.tobytes())

    a = build_audio(AudioSettings(path=tmp.name, volume=1.0, fade_in=0.1,
                                  fade_out=0.1, loop=True), 7.3, sr)
    check("audio.loopLength", a.shape[0] == int(round(7.3 * sr)), str(a.shape))
    a2 = build_audio(AudioSettings(path=tmp.name, volume=1.0, fade_in=0.1,
                                   fade_out=0.1, loop=False), 7.3, sr)
    tail = a2[int(2.5 * sr):]
    check("audio.noLoopSilence", float(np.abs(tail).max()) < 1e-6)
    def rms(x):
        return float(np.sqrt(np.mean(np.square(x)))) if len(x) else 0.0

    a3 = build_audio(AudioSettings(path=tmp.name, volume=1.0, fade_in=0.2,
                                   fade_out=0.2, loop=True), 4.0, sr)
    body = rms(a3[int(1.0 * sr):int(1.2 * sr)])
    check("audio.fadeInStarts", rms(a3[:int(0.02 * sr)]) < 0.10 * body,
          f"{rms(a3[:int(0.02 * sr)])/body:.4f}")
    check("audio.fadeOutEnds", rms(a3[-int(0.02 * sr):]) < 0.10 * body,
          f"{rms(a3[-int(0.02 * sr):])/body:.4f}")
    check("audio.bodyNotFaded", body > 0.3, str(body))
    # loop seam must not click: no sample-to-sample jump larger than the
    # maximum slope of the source tone itself
    d = np.abs(np.diff(a3[:, 0]))
    max_slope = 2 * math.pi * 440 / sr * 0.5 * 1.6
    check("audio.noSeamClick", float(d.max()) < max_slope,
          f"maxJump={float(d.max()):.4f} limit={max_slope:.4f}")
    a4 = build_audio(AudioSettings(path=tmp.name, volume=0.5, fade_in=0.0,
                                   fade_out=0.0, loop=True), 4.0, sr)
    check("audio.volume", abs(rms(a4[int(1.0 * sr):int(1.2 * sr)])
                              / rms(a3[int(1.0 * sr):int(1.2 * sr)]) - 0.5) < 0.02)
    check("audio.noneIsNone", build_audio(None, 4.0) is None)
    os.unlink(tmp.name)
    return {"rules": ["loop-to-target", "no-loop-silence", "fade-in-out",
                      "volume", "no-audio"]}


def gen_encoding():
    from .encode import derive_bitrate, round_even
    rows = []
    for (w, h) in [(1280, 720), (1920, 1080), (2560, 1440), (3840, 2160),
                   (1080, 1920), (1080, 1080)]:
        for fps in (24, 30, 60):
            for q in ("standard", "high", "maximum"):
                for codec in ("h264", "hevc"):
                    rows.append([w, h, fps, q, codec,
                                 derive_bitrate(w, h, fps, q, codec)])
    out = {"bitrates": rows,
           "roundEven": [[v, round_even(v)] for v in (1079, 1080, 1081, 721, 3)]}
    # monotonic: more pixels -> more bits, higher quality -> more bits
    b = {(w, h, f, q, c): derive_bitrate(w, h, f, q, c)
         for (w, h) in [(1280, 720), (1920, 1080)] for f in (30,) 
         for q in ("standard", "high") for c in ("h264",)}
    check("encode.qualityMonotonic",
          b[(1920, 1080, 30, "high", "h264")] > b[(1920, 1080, 30, "standard", "h264")])
    check("encode.resMonotonic",
          b[(1920, 1080, 30, "high", "h264")] > b[(1280, 720, 30, "high", "h264")])
    return out


def main() -> int:
    os.makedirs(GOLDEN_DIR, exist_ok=True)
    print("Generating golden vectors + invariant checks\n")
    sections = {
        "easing": gen_easing(),
        "prng": gen_prng(),
        "keyframes": gen_keyframe_sampling(),
        "camera": gen_camera(),
        "profiles": gen_profiles(),
        "motion_paths": gen_motion_paths(),
        "transitions": gen_transitions(),
        "audio": gen_audio_rules(),
        "encoding": gen_encoding(),
    }
    for name, data in sections.items():
        path = os.path.join(GOLDEN_DIR, f"{name}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=1, sort_keys=True)
        print(f"  wrote golden/{name}.json")
    print(f"\nchecks: {CHECKS[1]}/{CHECKS[0]} passed")
    if FAILS:
        print(f"\n{len(FAILS)} FAILURES:")
        for f_ in FAILS[:40]:
            print("  -", f_)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
