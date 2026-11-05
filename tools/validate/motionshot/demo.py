#!/usr/bin/env python3
"""Render a real MP4 from a MotionShot project spec.

    python3 -m motionshot_demo --out /tmp/demo.mp4 --photos a.jpg b.jpg ...

This drives exactly the same algorithms the Kotlin renderer must implement, so it
doubles as a visual proof of the motion spec and a golden reference for frames.
"""
from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import sys
import time
from typing import List

import numpy as np
from PIL import Image, ImageOps

from .audio import AudioSettings
from .camera import ImageFit, Viewport
from .encode import export_video, probe, round_even
from .profile import (MOTION_TYPES, PhotoMotionInput, build_profiles,
                      generate_profile)
from .renderer import (RenderPhoto, RenderProject, SourceCache, render_frame)
from .timeline import TransitionSpec
from .mathx import Xorshift128Plus, photo_seed

ASPECTS = {"16:9": 16 / 9, "9:16": 9 / 16, "1:1": 1.0, "4:5": 4 / 5}
RES = {"720p": 720, "1080p": 1080, "1440p": 1440, "2160p": 2160}


def output_dimensions(aspect: float, short_side: int):
    if aspect >= 1:
        h = short_side
        w = int(round(short_side * aspect))
    else:
        w = short_side
        h = int(round(short_side / aspect))
    return round_even(w), round_even(h)


def build(photo_paths: List[str], out_path: str, *, fps: int = 30,
          aspect: str = "16:9", res: str = "1080p", seconds: float = 4.0,
          seed: int = 7, intensity: float = 0.7, quality: str = "high",
          codec: str = "h264", transition: str = "crossDissolve",
          transition_seconds: float = 0.6, audio: str = None,
          loop_audio: bool = True, fixed_motion: str = None,
          work_dir: str = "/tmp", quiet: bool = False):
    wide = ASPECTS[aspect]
    ow, oh = output_dimensions(wide, RES[res])
    vp = Viewport(wide)

    photos: List[RenderPhoto] = []
    inputs: List[PhotoMotionInput] = []
    for i, p in enumerate(photo_paths):
        im = ImageOps.exif_transpose(Image.open(p))
        w, h = im.size
        inputs.append(PhotoMotionInput(photo_id=f"photo-{i}", src_w=w,
                                       src_h=h, duration=seconds))
    profiles = build_profiles(inputs, vp, seed, intensity)
    if fixed_motion:
        profiles = {}
        for i, inp in enumerate(inputs):
            rng = Xorshift128Plus(photo_seed(seed, inp.photo_id, i))
            profiles[inp.photo_id] = generate_profile(
                fixed_motion, intensity, seconds,
                ImageFit.make(inp.src_w, inp.src_h, vp), vp, rng, seed)
    for i, (p, inp) in enumerate(zip(photo_paths, inputs)):
        photos.append(RenderPhoto(
            photo_id=inp.photo_id, path=p, src_w=inp.src_w, src_h=inp.src_h,
            duration=seconds, profile=profiles[inp.photo_id],
            transition=TransitionSpec(transition, transition_seconds)))

    project = RenderProject(photos=photos, out_w=ow, out_h=oh, fps=fps,
                            aspect=wide)
    aud = None
    if audio:
        aud = AudioSettings(path=audio, volume=0.9, fade_in=0.8, fade_out=1.5,
                            loop=loop_audio)
    t0 = time.time()
    last = [0.0]

    def prog(f, stage):
        if quiet:
            return
        if f - last[0] >= 0.05 or f >= 1.0:
            last[0] = f
            sys.stdout.write(f"\r  {stage} {f*100:5.1f}%")
            sys.stdout.flush()

    result = export_video(project, out_path, codec=codec, quality=quality,
                          audio=aud, work_dir=work_dir, progress=prog)
    if not quiet:
        print()
    elapsed = time.time() - t0
    return result, project, elapsed


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/tmp/motionshot_demo.mp4")
    ap.add_argument("--photos", nargs="+", required=True)
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--aspect", default="16:9", choices=list(ASPECTS))
    ap.add_argument("--res", default="1080p", choices=list(RES))
    ap.add_argument("--seconds", type=float, default=4.0)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--intensity", type=float, default=0.7)
    ap.add_argument("--quality", default="high")
    ap.add_argument("--codec", default="h264", choices=["h264", "hevc"])
    ap.add_argument("--transition", default="crossDissolve")
    ap.add_argument("--transition-seconds", type=float, default=0.6)
    ap.add_argument("--audio", default=None)
    ap.add_argument("--fixed-motion", default=None, choices=MOTION_TYPES)
    ap.add_argument("--json", default=None, help="write the project JSON here")
    args = ap.parse_args(argv)

    res, project, elapsed = build(
        args.photos, args.out, fps=args.fps, aspect=args.aspect, res=args.res,
        seconds=args.seconds, seed=args.seed, intensity=args.intensity,
        quality=args.quality, codec=args.codec, transition=args.transition,
        transition_seconds=args.transition_seconds, audio=args.audio,
        fixed_motion=args.fixed_motion)
    print(f"  {res}")
    print(f"  rendered in {elapsed:.2f}s "
          f"({res.frames/max(elapsed,1e-6):.1f} fps of timeline)")
    info = probe(res.path)
    print(f"  probe: {info.get('codec')} {info.get('width')}x{info.get('height')} "
          f"@ {info.get('fps')} fps, {info.get('duration')}s, "
          f"audio={info.get('audio_codec', 'none')}, "
          f"{info['size']/1e6:.2f} MB")
    if args.json:
        with open(args.json, "w") as f:
            json.dump({"photos": [p.photo_id for p in project.photos],
                       "motions": [p.profile.motion_type for p in project.photos],
                       "seed": args.seed}, f, indent=2)
        print(f"  json -> {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
