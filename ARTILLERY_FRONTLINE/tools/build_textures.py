#!/usr/bin/env python3
"""Author the tiling world textures (albedo + tangent normal) procedurally.

Every image is original and deterministic; nothing is downloaded.

    python3 tools/build_textures.py

Requires numpy, scipy and pillow.
"""
import os

import sys

import numpy as np
from PIL import Image
from scipy.spatial import cKDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from assetlib import noise  # noqa: E402

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(PROJECT, "assets", "textures", "world")


def pnoise(size, freq, seed):
    """Periodic value noise in [0, 1]."""
    rng = np.random.default_rng(seed)
    lattice = rng.random((freq, freq))
    xs = np.arange(size) * freq / size
    i0 = np.floor(xs).astype(int)
    f = xs - i0
    f = f * f * (3.0 - 2.0 * f)
    i1 = (i0 + 1) % freq
    top = lattice[np.ix_(i0, i0)] * (1 - f)[None, :] + lattice[np.ix_(i0, i1)] * f[None, :]
    bottom = lattice[np.ix_(i1, i0)] * (1 - f)[None, :] + lattice[np.ix_(i1, i1)] * f[None, :]
    return top * (1 - f)[:, None] + bottom * f[:, None]


def pfbm(size, freq, octaves, seed, gain=0.5):
    total = np.zeros((size, size))
    amplitude, norm = 1.0, 0.0
    for octave in range(octaves):
        total += pnoise(size, min(freq, size // 2), seed + octave * 101) * amplitude
        norm += amplitude
        amplitude *= gain
        freq *= 2
    return total / norm


def smooth(lo, hi, x):
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def cracks(size, freq, seed, width=0.012, cover=0.5):
    """1 on a crack, 0 elsewhere: jagged cell boundaries, kept only in patches so
    the network reads as separate fractures instead of a tiling. A higher
    `cover` threshold leaves fewer patches."""
    _distance, _ids, edge = voronoi(size, max(4, freq * freq), seed, warp=0.035)
    line = 1.0 - smooth(0.0, width * 0.55, edge)
    gate = smooth(cover, cover + 0.12, pfbm(size, max(2, freq), 3, seed + 7))
    return line * gate


def voronoi(size, count, seed, warp=0.0):
    """Periodic cell noise: (distance to nearest site, cell id, edge distance)."""
    rng = np.random.default_rng(seed)
    sites = rng.random((count, 2))
    tiled = np.concatenate([sites + (dx, dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    ids = np.tile(np.arange(count), 9)
    ys, xs = np.mgrid[0:size, 0:size]
    px = (xs + 0.5) / size
    py = (ys + 0.5) / size
    if warp > 0.0:
        px = px + (pfbm(size, 8, 3, seed + 31) - 0.5) * warp * 2.0
        py = py + (pfbm(size, 8, 3, seed + 47) - 0.5) * warp * 2.0
    points = np.stack([px.ravel(), py.ravel()], axis=1)
    distance, index = cKDTree(tiled).query(points, k=2)
    return (distance[:, 0].reshape(size, size), ids[index[:, 0]].reshape(size, size),
            (distance[:, 1] - distance[:, 0]).reshape(size, size))


def lerp(a, b, t):
    return a * (1.0 - t[..., None]) + np.asarray(b, np.float64) * t[..., None]


def normal_map(height, strength):
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    normal = np.stack([-dx, dy, np.ones_like(height)], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    return normal * 0.5 + 0.5


def save(name, albedo, height=None, strength=4.0):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(np.round(np.clip(albedo, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + ".jpg"), quality=90)
    if height is not None:
        normal = normal_map(height, strength)
        Image.fromarray(np.round(normal * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_n.png"), optimize=True)
    print("texture", name, albedo.shape[:2])


def concrete(size=512):
    """Board-formed fortress concrete: 3 m per tile."""
    mottled = pfbm(size, 4, 5, 11)
    fine = pfbm(size, 64, 3, 12)
    color = lerp(np.full((size, size, 3), (0.50, 0.495, 0.47)), (0.61, 0.60, 0.565), smooth(0.3, 0.75, mottled))
    color *= (0.9 + 0.2 * fine)[..., None]
    height = mottled * 0.3 + fine * 0.25
    ys, xs = np.mgrid[0:size, 0:size]
    # Formwork joints: four lifts per tile and a panel seam every half tile.
    for period, axis, depth in ((size // 4, ys, 0.5), (size // 2, xs, 0.35)):
        distance = np.minimum(axis % period, period - axis % period)
        joint = 1.0 - smooth(0.0, 2.2, distance)
        color *= (1.0 - 0.34 * joint * depth * 2.0)[..., None]
        height -= joint * depth * 0.6
    # Tie holes on a regular grid.
    cx = (xs % (size // 4)) - size // 8
    cy = (ys % (size // 4)) - size // 8
    hole = 1.0 - smooth(2.0, 4.0, np.sqrt(cx * cx + cy * cy))
    color *= (1.0 - 0.5 * hole)[..., None]
    height -= hole * 0.5
    # Rain streaks running down from each lift line, and old leak stains.
    streak = pnoise(size, 48, 13)[0:1, :].repeat(size, axis=0)
    fade = 1.0 - ((ys % (size // 2)) / (size // 2))
    color *= (1.0 - 0.22 * smooth(0.55, 0.9, streak) * fade)[..., None]
    stain = smooth(0.58, 0.8, pfbm(size, 3, 4, 14))
    color = lerp(color, (0.33, 0.31, 0.27), stain * 0.45)
    crack = np.maximum(cracks(size, 3, 15, 0.01, 0.6), cracks(size, 5, 16, 0.007, 0.66))
    color *= (1.0 - 0.42 * crack)[..., None]
    height -= crack * 0.5
    pores = smooth(0.78, 0.86, pfbm(size, 128, 1, 17))
    color *= (1.0 - 0.25 * pores)[..., None]
    height -= pores * 0.2
    save("concrete", color, height, 5.0)


def asphalt(size=512):
    """Worn road surface: 5 m per tile."""
    base = pfbm(size, 6, 4, 21)
    grit = pfbm(size, 128, 2, 22)
    color = np.full((size, size, 3), (0.115, 0.115, 0.12)) * (0.8 + 0.5 * base)[..., None]
    stones = smooth(0.62, 0.85, grit)
    color = lerp(color, (0.3, 0.29, 0.28), stones * 0.5)
    height = grit * 0.5 + base * 0.2
    patch = smooth(0.6, 0.66, pfbm(size, 3, 3, 23))
    color = lerp(color, (0.075, 0.075, 0.08), patch * 0.7)
    height += patch * 0.08
    dust = smooth(0.5, 0.85, pfbm(size, 5, 4, 24))
    color = lerp(color, (0.29, 0.26, 0.22), dust * 0.38)
    crack = np.maximum(np.maximum(cracks(size, 3, 25, 0.014), cracks(size, 6, 26, 0.009)), cracks(size, 9, 27, 0.006))
    color *= (1.0 - 0.8 * crack)[..., None]
    height -= crack
    save("asphalt", color, height, 5.0)


def paving(size=512):
    """Concrete plaza slabs with joints: 4 m per tile (four slabs across)."""
    mottled = pfbm(size, 5, 5, 31)
    fine = pfbm(size, 96, 2, 32)
    color = lerp(np.full((size, size, 3), (0.36, 0.35, 0.33)), (0.47, 0.455, 0.42), smooth(0.25, 0.8, mottled))
    color *= (0.88 + 0.24 * fine)[..., None]
    height = fine * 0.3 + mottled * 0.2
    ys, xs = np.mgrid[0:size, 0:size]
    period = size // 4
    slab = (xs // period) * 4 + (ys // period)
    tone = np.random.default_rng(33).random(16)[slab]
    color *= (0.9 + 0.2 * tone)[..., None]
    joint = np.maximum(1.0 - smooth(0.0, 2.5, np.minimum(xs % period, period - xs % period)),
                       1.0 - smooth(0.0, 2.5, np.minimum(ys % period, period - ys % period)))
    color *= (1.0 - 0.62 * joint)[..., None]
    height -= joint * 0.8
    stain = smooth(0.55, 0.8, pfbm(size, 4, 4, 34))
    color = lerp(color, (0.2, 0.185, 0.16), stain * 0.5)
    crack = np.maximum(cracks(size, 4, 35, 0.011, 0.6), cracks(size, 7, 36, 0.007, 0.66))
    color *= (1.0 - 0.5 * crack)[..., None]
    height -= crack * 0.6
    save("paving", color, height, 5.0)


def plaster(size=512):
    """Neutral facade render, tinted per building by vertex colour: 4 m per tile."""
    mottled = pfbm(size, 4, 5, 41)
    fine = pfbm(size, 96, 2, 42)
    color = np.full((size, size, 3), (0.74, 0.73, 0.71)) * (0.82 + 0.3 * mottled)[..., None]
    color *= (0.94 + 0.12 * fine)[..., None]
    height = fine * 0.2 + mottled * 0.15
    ys, xs = np.mgrid[0:size, 0:size]
    streak = pnoise(size, 40, 43)[0:1, :].repeat(size, axis=0) * pfbm(size, 3, 2, 44)
    color *= (1.0 - 0.35 * smooth(0.3, 0.7, streak))[..., None]
    # Spalled patches where the render fell off and darker masonry shows.
    spall = smooth(0.69, 0.72, pfbm(size, 6, 5, 45, 0.62))
    color = lerp(color, (0.45, 0.36, 0.31), spall * 0.75)
    height -= spall * 0.6
    soot = smooth(0.55, 0.85, pfbm(size, 3, 3, 46))
    color = lerp(color, (0.2, 0.19, 0.18), soot * 0.4)
    crack = np.maximum(cracks(size, 4, 47, 0.01, 0.58), cracks(size, 8, 48, 0.007, 0.64))
    color *= (1.0 - 0.5 * crack)[..., None]
    height -= crack * 0.5
    save("plaster", color, height, 4.0)


def brick(size=512):
    """Exposed masonry: 2 m per tile, 24 courses."""
    courses, per_row = 24, 8
    ys, xs = np.mgrid[0:size, 0:size]
    row = (ys * courses) // size
    fy = (ys * courses / size) % 1.0
    shift = (row % 2) * 0.5
    fxa = xs * per_row / size + shift
    col = np.floor(fxa).astype(int) % per_row
    fx = fxa % 1.0
    rng = np.random.default_rng(51)
    tone = rng.random((courses, per_row))[row, col]
    hue = rng.random((courses, per_row))[row, col]
    color = lerp(np.full((size, size, 3), (0.42, 0.2, 0.15)), (0.56, 0.31, 0.2), tone)
    color = lerp(color, (0.3, 0.2, 0.17), smooth(0.7, 1.0, hue) * 0.8)
    mortar = np.maximum(1.0 - smooth(0.0, 0.09, np.minimum(fy, 1.0 - fy)), 1.0 - smooth(0.0, 0.035, np.minimum(fx, 1.0 - fx)))
    fine = pfbm(size, 96, 2, 52)
    color *= (0.85 + 0.3 * fine)[..., None]
    color = lerp(color, (0.47, 0.45, 0.41), mortar)
    height = (1.0 - mortar) * 0.7 + fine * 0.2
    soot = smooth(0.45, 0.8, pfbm(size, 3, 4, 53))
    color = lerp(color, (0.13, 0.12, 0.11), soot * 0.6)
    save("brick", color, height, 4.0)


def metal(size=512):
    """Painted steel plate, neutral for tinting, with rust and scratches: 2 m per tile."""
    mottled = pfbm(size, 5, 4, 61)
    fine = pfbm(size, 128, 2, 62)
    color = np.full((size, size, 3), (0.66, 0.66, 0.66)) * (0.86 + 0.22 * mottled)[..., None]
    color *= (0.95 + 0.1 * fine)[..., None]
    height = fine * 0.12
    rust_field = pfbm(size, 6, 5, 63, 0.6)
    rust = smooth(0.56, 0.7, rust_field)
    color = lerp(color, (0.36, 0.17, 0.08), rust * 0.92)
    color = lerp(color, (0.2, 0.09, 0.05), smooth(0.7, 0.82, rust_field) * 0.8)
    height -= rust * 0.25
    ys, xs = np.mgrid[0:size, 0:size]
    # Rust runs under each seam.
    seam = np.minimum(ys % (size // 2), size // 2 - ys % (size // 2))
    line = 1.0 - smooth(0.0, 2.0, seam)
    color *= (1.0 - 0.45 * line)[..., None]
    height -= line * 0.5
    run = smooth(0.45, 0.8, pnoise(size, 36, 64)[0:1, :].repeat(size, axis=0)) * (1.0 - (ys % (size // 2)) / (size // 2)) ** 2
    color = lerp(color, (0.33, 0.16, 0.08), run * 0.55)
    # Rivets along the seams.
    cx = (xs % (size // 8)) - size // 16
    cy = (ys % (size // 2)) - 10
    rivet = 1.0 - smooth(2.5, 4.5, np.sqrt(cx * cx + cy * cy))
    color *= (1.0 + 0.18 * rivet)[..., None]
    height += rivet * 0.7
    scratch = smooth(0.8, 0.9, pnoise(size, 160, 65)[:, 0:1].repeat(size, axis=1) * pfbm(size, 8, 2, 66) * 1.6)
    color = lerp(color, (0.8, 0.8, 0.78), scratch * 0.3)
    save("metal", color, height, 3.0)


def rubble(size=512):
    """Broken masonry and concrete: 2.5 m per tile."""
    _d1, id1, edge1 = voronoi(size, 70, 71, warp=0.02)
    _d2, id2, edge2 = voronoi(size, 420, 72)
    rng = np.random.default_rng(73)
    tone1 = rng.random(70)[id1]
    kind = rng.random(70)[id1]
    tone2 = rng.random(420)[id2]
    color = lerp(np.full((size, size, 3), (0.33, 0.32, 0.30)), (0.55, 0.53, 0.49), tone1)
    color = lerp(color, (0.42, 0.25, 0.19), (kind > 0.8).astype(float) * 0.7)
    color = lerp(color, (0.2, 0.19, 0.18), (kind < 0.12).astype(float) * 0.6)
    small = smooth(0.0, 0.012, edge2)
    color *= (0.72 + 0.28 * small * (0.7 + 0.3 * tone2))[..., None]
    gap = 1.0 - smooth(0.0, 0.016, edge1)
    color *= (1.0 - 0.6 * gap)[..., None]
    dust = smooth(0.3, 0.75, pfbm(size, 6, 4, 74))
    color = lerp(color, (0.43, 0.4, 0.35), dust * 0.62)
    fine = pfbm(size, 128, 2, 75)
    color *= (0.85 + 0.3 * fine)[..., None]
    height = smooth(0.0, 0.05, edge1) * 0.7 + tone1 * 0.4 + small * 0.2
    save("rubble", color, height, 5.0)


def burlap(size=256):
    """Sandbag hessian: 0.6 m per tile."""
    ys, xs = np.mgrid[0:size, 0:size]
    threads = 40
    warp = np.sin(xs * np.pi * 2 * threads / size) * 0.5 + 0.5
    weft = np.sin(ys * np.pi * 2 * threads / size) * 0.5 + 0.5
    over = ((xs * threads // size + ys * threads // size) % 2).astype(float)
    weave = warp * over + weft * (1.0 - over)
    mottled = pfbm(size, 4, 4, 81)
    color = lerp(np.full((size, size, 3), (0.36, 0.30, 0.19)), (0.56, 0.48, 0.32), weave * 0.7 + mottled * 0.3)
    dirt = smooth(0.5, 0.85, pfbm(size, 5, 4, 82))
    color = lerp(color, (0.22, 0.19, 0.14), dirt * 0.55)
    fine = pfbm(size, 96, 2, 83)
    color *= (0.88 + 0.24 * fine)[..., None]
    save("burlap", color, weave * 0.7 + mottled * 0.3, 3.0)


def sky(width=2048, height=1024):
    """Equirectangular dusk sky over a burning city. The image centre faces -Z,
    the direction the defender looks; the low sun sits behind the left shoulder."""
    us = (np.arange(width) + 0.5) / width
    vs = (np.arange(height) + 0.5) / height
    phi = (us - 0.5) * 2.0 * np.pi
    theta = vs * np.pi
    sin_t, cos_t = np.sin(theta)[:, None], np.cos(theta)[:, None]
    direction = np.stack([sin_t * np.sin(phi)[None, :], np.broadcast_to(cos_t, (height, width)), -sin_t * np.cos(phi)[None, :]], axis=-1)
    flat = direction.reshape(-1, 3)
    up = np.clip(flat[:, 1], 0.0, 1.0)
    sun = np.array([0.0, 0.62, 0.78])
    sun /= np.linalg.norm(sun)
    toward_sun = np.clip(flat @ sun, -1.0, 1.0)
    zenith = np.array([0.15, 0.19, 0.28])
    middle = np.array([0.36, 0.38, 0.45])
    warm = np.array([0.78, 0.58, 0.42])
    cool = np.array([0.5, 0.48, 0.52])
    side = (np.clip(flat[:, 2] / np.maximum(np.linalg.norm(flat[:, [0, 2]], axis=1), 1e-6), -1.0, 1.0) * 0.5 + 0.5)[:, None]
    horizon = cool[None, :] * (1 - side) + warm[None, :] * side
    t = up ** 0.55
    color = horizon * (1 - t)[:, None] + middle[None, :] * t[:, None]
    t2 = np.clip((up - 0.35) / 0.65, 0.0, 1.0)
    color = color * (1 - t2)[:, None] + zenith[None, :] * t2[:, None]
    # Warm glow around the sun, cooler and dimmer on the far side.
    glow = np.clip(toward_sun, 0.0, 1.0) ** 3
    color += np.array([0.5, 0.28, 0.1])[None, :] * glow[:, None] * (1.0 - up)[:, None]
    color *= (0.86 + 0.14 * (toward_sun * 0.5 + 0.5))[:, None]
    disc = np.clip((toward_sun - 0.9985) / 0.001, 0.0, 1.0)
    color += np.array([1.0, 0.8, 0.55])[None, :] * disc[:, None]
    # Cloud deck: project onto a plane so the clouds stretch toward the horizon.
    plane = flat[:, [0, 2]] / np.maximum(flat[:, 1:2] + 0.12, 0.02)
    points = np.concatenate([plane * 0.55, np.full((len(flat), 1), 3.7)], axis=1)
    warp = noise.fbm(points * 0.6 + 11.0, 1.0, 3, 5)
    points[:, 0] += warp * 1.4
    cover = noise.fbm(points, 1.0, 5, 21)
    cloud = smooth(0.46, 0.72, cover) * smooth(0.0, 0.12, flat[:, 1])
    detail = noise.fbm(points * 3.1 + 4.0, 1.0, 3, 33)
    lit = np.clip(0.45 + 0.75 * (detail - 0.5) + 0.35 * (toward_sun * 0.5 + 0.5), 0.0, 1.0)
    cloud_dark = np.array([0.17, 0.18, 0.23])
    cloud_lit = np.array([0.9, 0.66, 0.5])
    cloud_color = cloud_dark[None, :] * (1 - lit)[:, None] + cloud_lit[None, :] * lit[:, None]
    color = color * (1 - cloud * 0.88)[:, None] + cloud_color * (cloud * 0.88)[:, None]
    # Smoke rising from the city in front of the wall.
    azimuth = np.arctan2(flat[:, 0], -flat[:, 2])
    smoke = np.zeros(len(flat))
    for centre, spread, reach, seed in ((-0.5, 0.12, 0.5, 1), (0.16, 0.09, 0.62, 2), (0.62, 0.15, 0.45, 3), (-1.25, 0.2, 0.4, 4),
                                        (1.5, 0.18, 0.42, 5), (-0.12, 0.05, 0.3, 6)):
        lean = up * 0.55
        wobble = (noise.fbm(np.stack([azimuth * 3.0, up * 6.0, np.full(len(flat), seed * 7.3)], axis=1), 1.0, 3, 40 + seed) - 0.5) * 0.3
        offset = azimuth - centre - lean - wobble
        column = np.exp(-(offset / (spread * (1.0 + up * 3.0))) ** 2) * np.clip(1.0 - up / reach, 0.0, 1.0)
        smoke = np.maximum(smoke, column)
    billow = noise.fbm(np.stack([azimuth * 9.0, up * 14.0, np.full(len(flat), 2.0)], axis=1), 1.0, 4, 77)
    smoke = np.clip(smoke * (0.55 + 0.9 * billow), 0.0, 1.0) * smooth(0.0, 0.03, flat[:, 1])
    smoke_color = np.array([0.13, 0.12, 0.12])
    color = color * (1 - smoke * 0.82)[:, None] + smoke_color[None, :] * (smoke * 0.82)[:, None]
    # Haze band and the ground half, matched to the scene fog.
    fog = np.array([0.47, 0.45, 0.47])
    band = np.exp(-np.clip(flat[:, 1], 0.0, 1.0) * 22.0)
    color = color * (1 - band * 0.8)[:, None] + fog[None, :] * (band * 0.8)[:, None]
    below = flat[:, 1] < 0.0
    depth = np.clip(-flat[:, 1] * 3.0, 0.0, 1.0)
    ground = fog[None, :] * (1 - depth)[:, None] + np.array([0.2, 0.18, 0.17])[None, :] * depth[:, None]
    color = np.where(below[:, None], ground, color)
    image = np.clip(color, 0.0, 1.0).reshape(height, width, 3)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(np.round(image * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "sky_dusk.jpg"), quality=92)
    print("texture sky_dusk", image.shape[:2])


def main():
    sky()
    concrete()
    asphalt()
    paving()
    plaster()
    brick()
    metal()
    rubble()
    burlap()


if __name__ == "__main__":
    main()
