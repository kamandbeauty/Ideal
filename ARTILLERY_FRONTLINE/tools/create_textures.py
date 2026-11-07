#!/usr/bin/env python3
"""Deterministic original PBR texture authoring for ARTILLERY FRONTLINE.

Free dependencies: Python 3, NumPy, Pillow. No downloaded art or paid services.
Albedo maps are high-quality JPEG; normal/ORM/alpha maps are lossless PNG.
"""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "textures" / "pbr"
OUT.mkdir(parents=True, exist_ok=True)


def normalized(a):
    a = np.asarray(a, dtype=np.float64)
    lo, hi = float(a.min()), float(a.max())
    return (a - lo) / max(hi - lo, 1e-9)


def periodic_noise(size, seed, power=1.8, blur=0.0):
    rng = np.random.default_rng(seed)
    spectrum = np.fft.fft2(rng.standard_normal((size, size)))
    fy = np.fft.fftfreq(size)[:, None]
    fx = np.fft.fftfreq(size)[None, :]
    freq = np.sqrt(fx * fx + fy * fy)
    amp = np.zeros_like(freq)
    mask = freq > 0
    amp[mask] = freq[mask] ** (-power)
    amp[0, 0] = 0
    field = np.real(np.fft.ifft2(spectrum * amp))
    if blur:
        img = Image.fromarray(np.uint8(normalized(field) * 255))
        field = np.asarray(img.filter(ImageFilter.GaussianBlur(blur)), dtype=np.float64) / 255.0
    return normalized(field)


def fbm(size, seed, octaves=5, power=1.7):
    total = np.zeros((size, size))
    weight = 1.0
    norm = 0.0
    for octave in range(octaves):
        total += weight * periodic_noise(size, seed + octave * 97, power + octave * 0.15)
        norm += weight
        weight *= 0.52
    return normalized(total / norm)


def save_rgb(name, array, quality=91):
    array = np.clip(array, 0, 255).astype(np.uint8)
    Image.fromarray(array, "RGB").save(OUT / name, quality=quality, optimize=True, subsampling=0)


def save_gray(name, array):
    Image.fromarray(np.clip(array, 0, 255).astype(np.uint8), "L").save(OUT / name, optimize=True)


def save_normal(name, height, strength):
    if height.shape[0] > 512:
        height = np.asarray(Image.fromarray(np.uint8(normalized(height) * 255)).resize((512, 512), Image.BILINEAR), dtype=np.float64) / 255.0
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    n = np.dstack((-dx, -dy, np.ones_like(height)))
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    Image.fromarray(np.clip((n * 0.5 + 0.5) * 255, 0, 255).astype(np.uint8), "RGB").save(OUT / name, optimize=True)


def save_orm(name, ao, roughness, metallic=0.0):
    if np.isscalar(metallic):
        metallic = np.full_like(ao, metallic)
    rgb = np.dstack((np.clip(ao, 0, 1) * 255, np.clip(roughness, 0, 1) * 255, np.clip(metallic, 0, 1) * 255))
    Image.fromarray(rgb.astype(np.uint8), "RGB").save(OUT / name, optimize=True)


def speckles(size, seed, count, radius, value):
    rng = np.random.default_rng(seed)
    layer = np.zeros((size, size))
    yy, xx = np.mgrid[0:size, 0:size]
    for _ in range(count):
        cx, cy = rng.integers(0, size, 2)
        r = max(1, int(rng.normal(radius, radius * 0.35)))
        dx = (xx - cx + size // 2) % size - size // 2
        dy = (yy - cy + size // 2) % size - size // 2
        mask = dx * dx + dy * dy < r * r
        layer[mask] = value * rng.uniform(0.6, 1.25)
    return layer


def sand():
    size = 1024
    warp = fbm(size, 120, 5)
    yy, xx = np.mgrid[0:size, 0:size]
    ripple_phase = (xx * 13.0 + yy * 3.0 + warp * 5.0) * math.tau / size
    ripples = (np.sin(ripple_phase) * 0.5 + 0.5) ** 2.2
    macro = fbm(size, 410, 6, 1.5)
    grain = periodic_noise(size, 777, 0.55, 0.35)
    pebbles = speckles(size, 91, 420, 2.2, 1.0)
    height = macro * 0.38 + ripples * 0.055 + grain * 0.10 + pebbles * 0.16
    base = np.array([171.0, 146.0, 108.0])
    variation = (macro - 0.5) * 46.0 + (grain - 0.5) * 18.0 - ripples * 3.0
    albedo = base[None, None, :] + variation[:, :, None]
    albedo += pebbles[:, :, None] * np.array([18.0, 14.0, 9.0])
    ao = 0.82 + 0.18 * normalized(height) - pebbles * 0.05
    rough = 0.88 + 0.10 * grain
    save_rgb("sand_albedo.jpg", albedo)
    save_normal("sand_normal.png", height, 5.5)
    save_orm("sand_orm.png", ao, rough)


def gravel():
    size = 1024
    macro = fbm(size, 222, 6)
    stones = speckles(size, 223, 1500, 3.4, 1.0)
    cracks = np.clip((fbm(size, 224, 4, 2.4) - 0.56) * 7.0, 0, 1)
    height = macro * 0.35 + stones * 0.5 - cracks * 0.22
    base = np.array([111.0, 101.0, 84.0])
    albedo = base[None, None, :] + ((macro - 0.5) * 38.0 + stones * 34.0 - cracks * 30.0)[:, :, None]
    save_rgb("gravel_albedo.jpg", albedo)
    save_normal("gravel_normal.png", height, 7.0)
    save_orm("gravel_orm.png", 0.72 + 0.28 * normalized(height), 0.86 + 0.12 * macro)


def rock():
    size = 1024
    strata = fbm(size, 330, 6, 2.1)
    yy, xx = np.mgrid[0:size, 0:size]
    bands = (np.sin((yy * 0.045 + strata * 4.0) * math.tau / size * 6.0) * 0.5 + 0.5)
    cracks = np.clip((fbm(size, 331, 4, 2.5) - 0.59) * 8.0, 0, 1)
    grain = periodic_noise(size, 332, 0.8, 0.4)
    height = strata * 0.5 + bands * 0.16 + grain * 0.12 - cracks * 0.3
    base = np.array([128.0, 116.0, 96.0])
    albedo = base[None, None, :] + ((strata - 0.5) * 46.0 + (bands - 0.5) * 18.0 - cracks * 42.0)[:, :, None]
    save_rgb("rock_albedo.jpg", albedo)
    save_normal("rock_normal.png", height, 8.0)
    save_orm("rock_orm.png", 0.68 + 0.32 * normalized(height), 0.82 + 0.16 * strata)


def painted(name, seed, base_color):
    size = 512
    dents = fbm(size, seed, 5, 1.9)
    scratches = np.clip((periodic_noise(size, seed + 1, 1.1, 0.25) - 0.68) * 9.0, 0, 1)
    chips = speckles(size, seed + 2, 110, 1.5, 1.0)
    dust = fbm(size, seed + 3, 4, 1.4)
    wear = np.clip(scratches + chips * 0.8, 0, 1)
    height = dents * 0.35 - wear * 0.25
    albedo = np.array(base_color)[None, None, :] + ((dents - 0.5) * 20.0 + (dust - 0.5) * 12.0)[:, :, None]
    albedo = albedo * (1.0 - wear[:, :, None] * 0.45) + wear[:, :, None] * np.array([92.0, 88.0, 78.0])
    save_rgb(name + "_albedo.jpg", albedo)
    save_normal(name + "_normal.png", height, 3.0)
    save_orm(name + "_orm.png", 0.78 + 0.22 * dents, 0.52 + 0.30 * dust + wear * 0.18, 0.28 + wear * 0.50)


def steel():
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    machining = (np.sin(yy * math.tau / 9.0) * 0.5 + 0.5) * 0.12
    wear = fbm(size, 511, 5)
    scratches = np.clip((periodic_noise(size, 512, 1.0, 0.2) - 0.7) * 8.0, 0, 1)
    height = machining + wear * 0.2 - scratches * 0.2
    albedo = np.array([72.0, 78.0, 76.0])[None, None, :] + ((wear - 0.5) * 26.0 + machining * 30.0 + scratches * 35.0)[:, :, None]
    save_rgb("steel_albedo.jpg", albedo)
    save_normal("steel_normal.png", height, 2.4)
    save_orm("steel_orm.png", 0.82 + 0.18 * wear, 0.30 + 0.34 * wear - scratches * 0.12, 0.86)


def fabric():
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    weave = ((np.sin(xx * math.tau / 6.0) * np.sin(yy * math.tau / 6.0)) * 0.5 + 0.5)
    wrinkles = fbm(size, 610, 5, 1.6)
    stains = fbm(size, 611, 4, 1.3)
    height = weave * 0.18 + wrinkles * 0.5
    albedo = np.array([142.0, 128.0, 92.0])[None, None, :] + ((wrinkles - 0.5) * 34.0 + (stains - 0.5) * 24.0 + weave * 8.0)[:, :, None]
    save_rgb("fabric_albedo.jpg", albedo)
    save_normal("fabric_normal.png", height, 2.8)
    save_orm("fabric_orm.png", 0.70 + 0.30 * wrinkles, 0.90 + 0.08 * stains)


def wood():
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    grain = fbm(size, 710, 5, 2.2)
    rings = (np.sin((xx * 0.12 + grain * 5.0) * math.tau / size * 10.0) * 0.5 + 0.5)
    planks = (np.abs((yy % 128) - 64) < 3).astype(float)
    height = grain * 0.3 + rings * 0.18 - planks * 0.5
    albedo = np.array([126.0, 96.0, 58.0])[None, None, :] + ((grain - 0.5) * 38.0 + (rings - 0.5) * 22.0 - planks * 45.0)[:, :, None]
    save_rgb("wood_albedo.jpg", albedo)
    save_normal("wood_normal.png", height, 3.4)
    save_orm("wood_orm.png", 0.72 + 0.28 * grain, 0.78 + 0.18 * rings)


def concrete():
    size = 512
    pores = speckles(size, 811, 900, 1.4, 1.0)
    macro = fbm(size, 812, 6)
    cracks = np.clip((fbm(size, 813, 4, 2.6) - 0.61) * 8.0, 0, 1)
    height = macro * 0.35 - pores * 0.25 - cracks * 0.4
    albedo = np.array([146.0, 138.0, 118.0])[None, None, :] + ((macro - 0.5) * 34.0 - pores * 24.0 - cracks * 40.0)[:, :, None]
    save_rgb("concrete_albedo.jpg", albedo)
    save_normal("concrete_normal.png", height, 4.0)
    save_orm("concrete_orm.png", 0.70 + 0.30 * macro, 0.86 + 0.12 * pores)


def rubber():
    size = 512
    cracks = np.clip((fbm(size, 910, 4, 2.4) - 0.58) * 7.0, 0, 1)
    grain = periodic_noise(size, 911, 0.8, 0.4)
    height = grain * 0.2 - cracks * 0.3
    albedo = np.array([34.0, 36.0, 33.0])[None, None, :] + ((grain - 0.5) * 12.0 - cracks * 10.0)[:, :, None]
    save_rgb("rubber_albedo.jpg", albedo)
    save_normal("rubber_normal.png", height, 2.0)
    save_orm("rubber_orm.png", 0.80 + 0.20 * grain, 0.90 + 0.08 * cracks)


def foliage():
    size = 512
    noise = fbm(size, 1010, 6, 1.8)
    clusters = np.clip((noise - 0.42) * 2.4, 0, 1)
    albedo = np.array([74.0, 82.0, 48.0])[None, None, :] + ((noise - 0.5) * 44.0)[:, :, None]
    save_rgb("foliage_albedo.jpg", albedo)
    save_normal("foliage_normal.png", noise, 3.0)
    save_orm("foliage_orm.png", 0.62 + 0.38 * clusters, 0.84 + 0.12 * noise)
    card = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw = ImageDraw.Draw(card)
    rng = np.random.default_rng(1011)
    for _ in range(34):
        x0 = float(rng.uniform(150, 360))
        height = float(rng.uniform(160, 470))
        lean = float(rng.uniform(-110, 110))
        width = float(rng.uniform(3, 9))
        color = (int(rng.uniform(92, 142)), int(rng.uniform(94, 128)), int(rng.uniform(48, 72)), 255)
        points = [(x0 - width, 512), (x0 + width, 512), (x0 + lean + width * 0.25, 512 - height * 0.65), (x0 + lean, 512 - height)]
        draw.polygon(points, fill=color)
    card.save(OUT / "grass_card.png", optimize=True)


def sky():
    width, height = 2048, 1024
    yy, xx = np.mgrid[0:height, 0:width]
    v = yy / (height - 1)
    zenith = np.array([44.0, 84.0, 132.0])
    horizon = np.array([168.0, 180.0, 188.0])
    ground = np.array([104.0, 96.0, 80.0])
    sky_mask = np.clip(1.0 - v / 0.54, 0, 1) ** 0.42
    color = horizon[None, None, :] * (1 - sky_mask[:, :, None]) + zenith[None, None, :] * sky_mask[:, :, None]
    below = v > 0.52
    color[below] = ground[None, None, :]
    clouds_small = fbm(1024, 1110, 6, 1.65)
    clouds = np.asarray(Image.fromarray(np.uint8(clouds_small * 255)).resize((width, height), Image.BILINEAR), dtype=np.float64) / 255.0
    cloud_band = np.exp(-((v - 0.36) / 0.18) ** 2)
    cloud_mask = np.clip((clouds - 0.52) * 3.0, 0, 1) * cloud_band
    color = color * (1 - cloud_mask[:, :, None] * 0.72) + np.array([232.0, 226.0, 210.0])[None, None, :] * cloud_mask[:, :, None] * 0.72
    sun_u, sun_v = 0.735, 0.43
    du = np.minimum(np.abs(xx / width - sun_u), 1 - np.abs(xx / width - sun_u))
    glow = np.exp(-((du / 0.075) ** 2 + ((v - sun_v) / 0.085) ** 2))
    disk = np.exp(-((du / 0.010) ** 2 + ((v - sun_v) / 0.012) ** 2))
    color += glow[:, :, None] * np.array([70.0, 48.0, 22.0]) + disk[:, :, None] * np.array([180.0, 160.0, 120.0])
    save_rgb("sky_panorama.jpg", color, quality=93)


def weapon_metal():
    """Parkerized gun steel: fine directional wear, not glossy plastic."""
    size = 1024
    yy, xx = np.mgrid[0:size, 0:size]
    grain = periodic_noise(size, 1201, 0.7, 0.3)
    brush = np.sin(yy * math.tau / 3.0 + grain * 2.0) * 0.5 + 0.5
    wear = fbm(size, 1202, 5, 1.8)
    rng = np.random.default_rng(1203)
    scratches = np.zeros((size, size))
    for _ in range(90):
        y = int(rng.integers(0, size)); x = int(rng.integers(0, size)); length = int(rng.integers(12, 90))
        scratches[y, x:x+length] = rng.uniform(0.25, 0.8)
    scratches = np.asarray(Image.fromarray(np.uint8(scratches*255)).filter(ImageFilter.GaussianBlur(0.6)), dtype=float)/255.0
    height = grain * 0.18 + brush * 0.05 - scratches * 0.35
    base = np.array([54.0, 58.0, 60.0])
    albedo = base[None, None, :] + ((wear - 0.5) * 14.0 + (grain - 0.5) * 8.0 + scratches * 26.0)[:, :, None]
    save_rgb("weapon_metal_albedo.jpg", albedo)
    save_normal("weapon_metal_normal.png", height, 1.6)
    save_orm("weapon_metal_orm.png", 0.86 + 0.14 * wear, 0.42 + 0.22 * wear - scratches * 0.10, 0.90)


def weapon_paint():
    size = 1024
    dents = fbm(size, 1210, 5, 1.9)
    dust = fbm(size, 1211, 4, 1.4)
    chips = speckles(size, 1212, 36, 1.1, 1.0)
    scratches = np.clip((periodic_noise(size, 1213, 1.1, 0.25) - 0.74) * 8.0, 0, 1)
    wear = np.clip(chips + scratches * 0.6, 0, 1)
    height = dents * 0.25 - wear * 0.3
    albedo = np.array([52.0, 58.0, 42.0])[None, None, :] + ((dents - 0.5) * 12.0 + (dust - 0.5) * 8.0)[:, :, None]
    albedo = albedo * (1.0 - wear[:, :, None] * 0.55) + wear[:, :, None] * np.array([58.0, 60.0, 56.0])
    save_rgb("weapon_paint_albedo.jpg", albedo)
    save_normal("weapon_paint_normal.png", height, 2.0)
    save_orm("weapon_paint_orm.png", 0.80 + 0.20 * dents, 0.70 + 0.18 * dust, 0.12 + wear * 0.40)


def weapon_brass():
    size = 512
    wear = fbm(size, 1220, 4, 1.8)
    grain = periodic_noise(size, 1221, 0.8, 0.3)
    albedo = np.array([148.0, 112.0, 48.0])[None, None, :] + ((wear - 0.5) * 24.0 + (grain - 0.5) * 10.0)[:, :, None]
    save_rgb("weapon_brass_albedo.jpg", albedo)
    save_normal("weapon_brass_normal.png", grain * 0.15 + wear * 0.1, 1.2)
    save_orm("weapon_brass_orm.png", 0.85 + 0.15 * wear, 0.30 + 0.20 * wear, 0.88)


def muzzle_flash():
    size = 256
    yy, xx = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2
    dx = (xx - cx) / cx; dy = (yy - cy) / cy
    radius = np.sqrt(dx*dx + dy*dy)
    angle = np.arctan2(dy, dx)
    spikes = (np.cos(angle * 6.0) * 0.5 + 0.5) ** 3
    core = np.exp(-(radius / 0.22) ** 2)
    rays = np.exp(-(radius / (0.30 + spikes * 0.55)) ** 3) * (0.35 + spikes * 0.65)
    alpha = np.clip(core + rays * 0.8, 0, 1)
    color = np.zeros((size, size, 4))
    color[:, :, 0] = 255
    color[:, :, 1] = 180 + core * 70
    color[:, :, 2] = 70 + core * 150
    color[:, :, 3] = alpha * 255
    Image.fromarray(color.astype(np.uint8), "RGBA").save(OUT / "muzzle_flash.png", optimize=True)


def skin():
    size = 512
    pores = periodic_noise(size, 1301, 0.6, 0.4)
    tone = fbm(size, 1302, 4, 1.7)
    blush = fbm(size, 1303, 3, 1.3)
    albedo = np.array([150.0, 108.0, 82.0])[None, None, :] + ((tone - 0.5) * 18.0)[:, :, None]
    albedo[:, :, 0] += blush * 10.0
    save_rgb("skin_albedo.jpg", albedo)
    save_normal("skin_normal.png", pores * 0.12 + tone * 0.05, 1.0)
    save_orm("skin_orm.png", 0.9 + 0.1 * tone, 0.62 + 0.18 * pores, 0.0)


def leather():
    size = 512
    grain = periodic_noise(size, 1310, 0.7, 0.35)
    creases = np.clip((fbm(size, 1311, 4, 2.2) - 0.55) * 6.0, 0, 1)
    height = grain * 0.2 - creases * 0.3
    albedo = np.array([46.0, 40.0, 34.0])[None, None, :] + ((grain - 0.5) * 12.0 - creases * 10.0)[:, :, None]
    save_rgb("leather_albedo.jpg", albedo)
    save_normal("leather_normal.png", height, 2.0)
    save_orm("leather_orm.png", 0.8 + 0.2 * grain, 0.72 + 0.16 * creases, 0.02)


if __name__ == "__main__":
    sand(); gravel(); rock()
    painted("paint_olive", 420, [78.0, 88.0, 62.0])
    painted("paint_sand", 450, [150.0, 132.0, 94.0])
    steel(); skin(); leather(); weapon_metal(); weapon_paint(); weapon_brass(); muzzle_flash(); fabric(); wood(); concrete(); rubber(); foliage(); sky()
    files = sorted(p for p in OUT.iterdir() if p.is_file())
    print("CREATED_TEXTURES", len(files), "files", sum(p.stat().st_size for p in files), "bytes")
