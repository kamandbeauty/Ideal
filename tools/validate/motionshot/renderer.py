"""Reference frame renderer (docs/MOTION_SPEC.md §7).

Purpose:
  1. Produce *real* MP4 output from a project description so the motion engine,
     transitions and timeline can be inspected frame by frame.
  2. Act as the golden reference the Kotlin OpenGL renderer is compared against
     (mean absolute error tolerance, spec §11).

It intentionally uses CPU sampling instead of a GPU: the math is identical, and
it makes the reference independent of any driver.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence, Tuple

import numpy as np
from PIL import Image, ImageFilter, ImageOps

from .camera import CameraState, ImageFit, Viewport, sample_keyframes
from .profile import MotionProfile
from .timeline import (DrawLayer, Segment, TransitionSpec, clamped_transition,
                       resolve_layers, transition_draw_layers)


# --------------------------------------------------------------------------
@dataclass
class RenderPhoto:
    photo_id: str
    path: str
    src_w: int
    src_h: int
    duration: float
    profile: MotionProfile
    transition: TransitionSpec = field(default_factory=TransitionSpec)

    @property
    def aspect(self) -> float:
        return self.src_w / self.src_h


@dataclass
class RenderProject:
    photos: List[RenderPhoto]
    out_w: int
    out_h: int
    fps: int
    aspect: float = 16 / 9

    @property
    def viewport(self) -> Viewport:
        return Viewport(self.aspect)

    @property
    def total_duration(self) -> float:
        return float(sum(p.duration for p in self.photos))

    @property
    def total_frames(self) -> int:
        return int(round(self.total_duration * self.fps))


# --------------------------------------------------------------------------
def exif_orient(im: Image.Image) -> Image.Image:
    return ImageOps.exif_transpose(im) or im


class SourceCache:
    """Decodes each photo once, with a bounded working resolution."""

    def __init__(self, max_working_px: int = 4000):
        self._cache: Dict[str, Image.Image] = {}
        self.max_working_px = max_working_px

    def get(self, photo: RenderPhoto) -> Image.Image:
        im = self._cache.get(photo.photo_id)
        if im is not None:
            return im
        im = exif_orient(Image.open(photo.path)).convert("RGB")
        # Working resolution: never below the output size, never absurdly large.
        w, h = im.size
        longest = max(w, h)
        if longest > self.max_working_px:
            s = self.max_working_px / longest
            im = im.resize((max(1, int(w * s)), max(1, int(h * s))), Image.LANCZOS)
        self._cache[photo.photo_id] = im
        return im

    def clear(self) -> None:
        self._cache.clear()


# --------------------------------------------------------------------------
def layer_affine(im_w: int, im_h: int, cam: CameraState, fit: ImageFit,
                 vp: Viewport, out_w: int, out_h: int,
                 zoom_mul: float = 1.0,
                 offset_x: float = 0.0, offset_y: float = 0.0
                 ) -> Tuple[float, float, float, float, float, float]:
    """PIL AFFINE coefficients mapping output pixels -> source pixels.

    Implements spec §7.1:
        nx = (u - outW/2) * vh/outH - offset_x*vw
        q  = c + R(-r) * (nx, ny) / (scale*zoom_mul)
        sx = (q.x + iw)/(2*iw) * W
    """
    scale = cam.scale * zoom_mul
    r = cam.rotation
    cos_r, sin_r = math.cos(r), math.sin(r)

    # output pixel -> normalized viewport offset
    k = vp.vh / out_h
    ox = out_w / 2.0
    oy = out_h / 2.0
    # offset_x is expressed in viewport widths
    shift_x = offset_x * vp.vw
    shift_y = offset_y * vp.vh

    # q = c + R(-r)*(n - shift)/scale ; R(-r) = [[cos, sin], [-sin, cos]]
    inv = 1.0 / scale
    # dq/dnx = (cos, -sin)/scale  -> nx = (u-ox)*k - shift_x
    a_x = cos_r * k * inv
    b_x = sin_r * k * inv
    c_x = cam.x + inv * (cos_r * (-ox * k - shift_x) + sin_r * (-oy * k - shift_y))
    d_y = -sin_r * k * inv
    e_y = cos_r * k * inv
    f_y = cam.y + inv * (-sin_r * (-ox * k - shift_x) + cos_r * (-oy * k - shift_y))

    a = a_x * (im_w / (2.0 * fit.iw))
    b = b_x * (im_w / (2.0 * fit.iw))
    c = (c_x + fit.iw) * (im_w / (2.0 * fit.iw))
    d = d_y * (im_h / (2.0 * fit.ih))
    e = e_y * (im_h / (2.0 * fit.ih))
    f = (f_y + fit.ih) * (im_h / (2.0 * fit.ih))
    return (a, b, c, d, e, f)


def render_layer(project: RenderProject, photo: RenderPhoto, local_time: float,
                 src: Image.Image, dl: DrawLayer,
                 freeze_at_end: bool = False) -> Image.Image:
    vp = project.viewport
    fit = ImageFit.make(photo.src_w, photo.src_h, vp)
    t = photo.duration if freeze_at_end else local_time
    t = max(0.0, min(photo.duration, t))
    cam = photo.profile.sample(t, fit, vp)
    coeffs = layer_affine(src.width, src.height, cam, fit, vp,
                          project.out_w, project.out_h,
                          zoom_mul=dl.zoom_mul,
                          offset_x=dl.offset_x, offset_y=dl.offset_y)
    layer = src.transform((project.out_w, project.out_h), Image.AFFINE, coeffs,
                          resample=Image.BILINEAR)
    if dl.blur_px > 0.5:
        radius = dl.blur_px * (project.out_h / 1080.0)
        if radius >= 0.5:
            layer = layer.filter(ImageFilter.GaussianBlur(radius))
    return layer


def render_frame(project: RenderProject, t: float, cache: SourceCache) -> np.ndarray:
    """Render the composited frame at time t as an RGB uint8 array."""
    durations = [p.duration for p in project.photos]
    transitions = [p.transition for p in project.photos]
    layers = resolve_layers(t, durations, transitions)
    draws = transition_draw_layers(layers)
    canvas = np.zeros((project.out_h, project.out_w, 3), dtype=np.float32)

    for layer, dl in zip(layers, draws):
        if dl.alpha <= 0.001 and draws[-1] is not dl:
            continue
        photo = project.photos[layer.photo_index]
        src = cache.get(photo)
        img = render_layer(project, photo, layer.local_time, src, dl,
                           freeze_at_end=dl.blend_hold)
        arr = np.asarray(img, dtype=np.float32)
        a = float(min(1.0, max(0.0, dl.alpha)))
        if a >= 1.0:
            canvas = arr
        else:
            canvas = arr * a + canvas * (1.0 - a)

    return np.clip(canvas + 0.5, 0, 255).astype(np.uint8)


def iter_frames(project: RenderProject, cache: Optional[SourceCache] = None,
                progress=None):
    cache = cache or SourceCache()
    n = project.total_frames
    for i in range(n):
        # exact rational timestamps: no float drift (spec §8.4)
        t = i / project.fps
        yield i, t, render_frame(project, t, cache)
        if progress and (i % 10 == 0 or i == n - 1):
            progress((i + 1) / n)
