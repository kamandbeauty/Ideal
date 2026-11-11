#!/usr/bin/env python3
"""Author the siege level: fortress wall, gate court and ruined city.

Writes
    assets/models/environment/city_siege.glb          geometry, chunked for culling
    resources/levels/city_siege_layout.tres            routes, attack lines, effect anchors

Both come from the same numbers, so gameplay markers can never drift away
from the geometry. Player frame: the defender looks down -Z, +X is right.

    python3 tools/build_city.py

Requires numpy.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from assetlib import noise  # noqa: E402
from assetlib.meshkit import Builder, rot_x, rot_y, rot_z  # noqa: E402

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_GLB = os.path.join(PROJECT, "assets", "models", "environment", "city_siege.glb")
OUT_LAYOUT = os.path.join(PROJECT, "resources", "levels", "city_siege_layout.tres")

UP = np.array([0.0, 1.0, 0.0])

# --- Fortress dimensions (metres) ---------------------------------------
DECK = 4.0                      # gun deck and rear wall walk
PIVOT = (0.0, -1.35)            # gun pedestal (x, z); the gunner's eye is at the origin
BASTION_R = 2.3
ARM_X = 17.0                    # inner face of both wall arms
ARM_T = 3.5
ARM_TOP = 5.0
ARM_Z0, ARM_Z1 = -48.0, -1.5
BACK_Z = 1.5                    # front face of the rear wall
GATE_Z0, GATE_Z1 = -22.5, -15.5
GATE_H = 4.2
GATEHOUSE_Z0, GATEHOUSE_Z1 = -25.5, -12.5
GATEHOUSE_X = 16.2              # inner face of the gatehouse
PATCH_Z0, PATCH_Z1 = -30.0, -23.0
PATCH_H = 3.8

# --- Streets --------------------------------------------------------------
RING_Z0, RING_Z1 = -58.0, -48.0
AVENUE_HALF = 9.0
FACADE_X = 13.0
CROSS_Z0, CROSS_Z1 = -90.0, -78.0
END_Z = -130.0
LANDMARK_Z = -142.0

CONCRETE = (0.86, 0.86, 0.84)
CONCRETE_DARK = (0.62, 0.62, 0.6)
STEEL = (0.34, 0.37, 0.34)
BURNT = (0.13, 0.115, 0.105)


def materials(b):
    b.material("concrete", (0.56, 0.55, 0.52, 1), 0.0, 0.92, tile=3.0)
    b.material("paving", (0.42, 0.41, 0.38, 1), 0.0, 0.95, tile=4.0)
    b.material("asphalt", (0.14, 0.14, 0.15, 1), 0.0, 0.9, tile=5.0)
    b.material("plaster", (0.7, 0.68, 0.64, 1), 0.0, 0.95, tile=4.0, double_sided=True)
    b.material("brick", (0.46, 0.25, 0.18, 1), 0.0, 0.95, tile=2.0, double_sided=True)
    b.material("metal", (0.6, 0.6, 0.6, 1), 0.55, 0.62, tile=2.0)
    b.material("rubble", (0.4, 0.38, 0.35, 1), 0.0, 1.0, tile=2.5)
    b.material("burlap", (0.45, 0.38, 0.25, 1), 0.0, 1.0, tile=0.6)
    b.material("interior", (0.035, 0.035, 0.04, 1), 0.0, 1.0)
    b.material("marking", (1, 1, 1, 1), 0.0, 0.85)
    b.material("lamp", (1.0, 0.8, 0.5, 1), 0.0, 0.5, emissive=(1.0, 0.72, 0.38))
    b.material("ember", (1.0, 0.42, 0.12, 1), 0.0, 0.6, emissive=(1.0, 0.36, 0.08))
    b.material("skyline", (0.2, 0.21, 0.23, 1), 0.0, 1.0)


# ---------------------------------------------------------------------------
# Facades and buildings
# ---------------------------------------------------------------------------
class Facade:
    """A wall plane addressed in (u along the wall, v up, d into the building)."""

    def __init__(self, b, node, origin, normal, material):
        self.b = b
        self.node = node
        self.o = np.asarray(origin, np.float64)
        self.n = np.asarray(normal, np.float64)
        self.u = np.cross(UP, self.n)
        self.frame = np.stack([self.u, UP, self.n], axis=1)
        self.material = material

    def p(self, u, v, d=0.0):
        return self.o + self.u * u + UP * v - self.n * d

    def quad(self, u0, v0, u1, v1, color, d=0.0, material=None, colors=None):
        self.b.quad(self.node, material or self.material,
                    [self.p(u0, v0, d), self.p(u1, v0, d), self.p(u1, v1, d), self.p(u0, v1, d)],
                    color, 0.0, self.frame, self.o, colors=colors)

    def poly(self, points, color):
        """Convex polygon given as (u, v) pairs, counter-clockwise seen from the front."""
        unique = []
        for point in points:
            if not unique or abs(point[0] - unique[-1][0]) + abs(point[1] - unique[-1][1]) > 1e-5:
                unique.append(point)
        if len(unique) > 1 and abs(unique[0][0] - unique[-1][0]) + abs(unique[0][1] - unique[-1][1]) < 1e-5:
            unique.pop()
        for i in range(1, len(unique) - 1):
            corners = [self.p(*unique[0]), self.p(*unique[i]), self.p(*unique[i + 1])]
            self.b.tri(self.node, self.material, corners, color, self.frame, self.o)

    def opening(self, u0, v0, u1, v1, a0, b0, a1, b1, color, depth=0.3, back="interior", back_color=(1, 1, 1), soot=0.0):
        """A wall cell (u0..u1, v0..v1) with a recessed opening (a0..a1, b0..b1)."""
        dark = tuple(c * (1.0 - soot) for c in color)
        self.quad(u0, v0, a0, v1, color)
        self.quad(a1, v0, u1, v1, color)
        if b0 > v0 + 1e-3:
            self.quad(a0, v0, a1, b0, color)
        if v1 > b1 + 1e-3:
            self.quad(a0, b1, a1, v1, color, colors=[dark, dark, color, color])
        reveal = tuple(c * 0.55 for c in color)
        b = self.b
        b.quad(self.node, self.material, [self.p(a0, b0), self.p(a0, b0, depth), self.p(a0, b1, depth), self.p(a0, b1)], reveal, 0.0, self.frame, self.o)
        b.quad(self.node, self.material, [self.p(a1, b0, depth), self.p(a1, b0), self.p(a1, b1), self.p(a1, b1, depth)], reveal, 0.0, self.frame, self.o)
        b.quad(self.node, self.material, [self.p(a0, b0), self.p(a1, b0), self.p(a1, b0, depth), self.p(a0, b0, depth)], reveal, 0.0, self.frame, self.o)
        b.quad(self.node, self.material, [self.p(a0, b1, depth), self.p(a1, b1, depth), self.p(a1, b1), self.p(a0, b1)], reveal, 0.0, self.frame, self.o)
        if back:
            self.quad(a0, b0, a1, b1, back_color, depth, back)


def profile(rng, count, height, floor_h, damage, start, end):
    """Broken top edge of a wall, one height per bay boundary."""
    if damage <= 0.01:
        return np.full(count + 1, height)
    knots = max(2, count // 3 + 2)
    coarse = rng.random(knots)
    t = np.linspace(0, knots - 1, count + 1)
    low = np.interp(t, np.arange(knots), coarse)
    edge = height * (1.0 - damage * (0.25 + 0.95 * low))
    edge += rng.uniform(-0.55, 0.55, count + 1) * floor_h
    edge[0], edge[-1] = start, end
    edge = np.clip(edge, floor_h * 0.7, height)
    edge[edge > height - 0.45 * floor_h] = height
    return edge


def facade(b, node, origin, normal, length, floors, floor_h, ground_h, edge, rng, tint, material, detail=True, lit=0.0, fire=0.0):
    wall = Facade(b, node, origin, normal, material)
    count = len(edge) - 1
    width = length / count
    levels = [0.0, ground_h] + [ground_h + floor_h * (i + 1) for i in range(floors - 1)]
    for i in range(count):
        u0, u1 = i * width, (i + 1) * width
        left, right = edge[i], edge[i + 1]
        shade = 0.9 + 0.2 * rng.random()
        color = tuple(c * shade for c in tint)
        for f in range(len(levels) - 1):
            v0, v1 = levels[f], levels[f + 1]
            if min(left, right) >= v1 - 1e-6:
                if not detail:
                    wall.quad(u0, v0, u1, v1, color)
                    continue
                roll = rng.random()
                soot = 0.75 if rng.random() < 0.3 else 0.0
                if f == 0:
                    a0, a1 = u0 + width * 0.14, u1 - width * 0.14
                    if roll < 0.2:
                        wall.quad(u0, v0, u1, v1, color)
                    elif roll < 0.4:
                        wall.opening(u0, v0, u1, v1, a0, v0 + 0.02, a1, v0 + 3.0, color, 0.12, "metal", (0.3, 0.31, 0.3), soot)
                    else:
                        wall.opening(u0, v0, u1, v1, a0, v0 + 0.02, a1, v0 + 3.0, color, 0.35, "interior", (1, 1, 1), soot)
                    continue
                a0, a1 = u0 + width * 0.27, u1 - width * 0.27
                b0, b1 = v0 + 0.95, v0 + 0.95 + floor_h * 0.52
                if roll < 0.1:
                    wall.quad(u0, v0, u1, v1, color)
                elif roll < 0.1 + lit:
                    wall.opening(u0, v0, u1, v1, a0, b0, a1, b1, color, 0.25, "lamp", (1, 1, 1))
                elif roll < 0.1 + lit + fire:
                    wall.opening(u0, v0, u1, v1, a0, b0, a1, b1, color, 0.25, "ember", (1, 1, 1), 0.85)
                else:
                    wall.opening(u0, v0, u1, v1, a0, b0, a1, b1, color, 0.3, "interior", (1, 1, 1), soot)
            elif max(left, right) > v0 + 1e-6:
                vl = min(max(left, v0), v1)
                vr = min(max(right, v0), v1)
                # A broken edge reads better with a notch than a straight cut.
                um = u0 + width * (0.35 + 0.3 * rng.random())
                vn = min(v1, max(v0, (vl + vr) * 0.5 - 0.5 * rng.random()))
                broken = tuple(c * 0.86 for c in color)
                wall.poly([(u0, v0), (um, v0), (um, vn), (u0, vl)], broken)
                wall.poly([(um, v0), (u1, v0), (u1, vr), (um, vn)], broken)


def building(b, node, x0, x1, z0, z1, floors, seed, tint, damage=0.5, material="plaster", detail="x+x-z+", lit=0.0, fire=0.0,
             floor_h=3.3, ground_h=4.2, roof=None, collide=True):
    """Hollow shell with broken top. Faces listed in `detail` get window openings."""
    rng = np.random.default_rng(seed)
    height = ground_h + floor_h * (floors - 1)
    corners = {}
    for key in ("x0z0", "x1z0", "x1z1", "x0z1"):
        corners[key] = height if damage <= 0.01 else float(np.clip(height * (1.0 - damage * rng.random() * 1.1), floor_h, height))
    sides = [
        ("z+", (x0, 0, z1), (0, 0, 1), x1 - x0, corners["x0z1"], corners["x1z1"]),
        ("x+", (x1, 0, z1), (1, 0, 0), z1 - z0, corners["x1z1"], corners["x1z0"]),
        ("z-", (x1, 0, z0), (0, 0, -1), x1 - x0, corners["x1z0"], corners["x0z0"]),
        ("x-", (x0, 0, z0), (-1, 0, 0), z1 - z0, corners["x0z0"], corners["x0z1"]),
    ]
    lowest = height
    for code, origin, normal, length, start, end in sides:
        count = max(2, int(round(length / 3.3)))
        edge = profile(rng, count, height, floor_h, damage, start, end)
        lowest = min(lowest, float(edge.min()))
        facade(b, node, origin, normal, length, floors, floor_h, ground_h, edge, rng, tint, material, code in detail, lit, fire)
    slab_color = (0.5, 0.49, 0.47)
    if roof is None:
        roof = damage < 0.12
    if roof:
        b.quad(node, "concrete", [(x0, height - 0.05, z1), (x1, height - 0.05, z1), (x1, height - 0.05, z0), (x0, height - 0.05, z0)], (0.4, 0.4, 0.4))
    else:
        # Floors and party walls that show through the broken shell.
        level = ground_h
        index = 0
        while level < height - 0.1:
            if lowest - floor_h * 1.6 < level < lowest + floor_h * 0.4:
                cut = 0.25 + 0.6 * rng.random()
                if index % 2 == 0:
                    xa, xb = x0 + 0.2, x0 + (x1 - x0) * cut
                else:
                    xa, xb = x0 + (x1 - x0) * (1.0 - cut), x1 - 0.2
                b.quad(node, "concrete", [(xa, level, z1 - 0.2), (xb, level, z1 - 0.2), (xb, level, z0 + 0.2), (xa, level, z0 + 0.2)], slab_color)
                b.quad(node, "concrete", [(xa, level - 0.25, z0 + 0.2), (xb, level - 0.25, z0 + 0.2), (xb, level - 0.25, z1 - 0.2), (xa, level - 0.25, z1 - 0.2)],
                       (0.2, 0.2, 0.2))
            level += floor_h
            index += 1
        for k in range(2):
            px = x0 + (x1 - x0) * (0.33 + 0.34 * k)
            top = float(np.clip(lowest + rng.uniform(-1.0, 4.0), floor_h, height))
            b.quad(node, material, [(px, 0, z1 - 0.3), (px, 0, z0 + 0.3), (px, top, z0 + 0.3), (px, top - rng.uniform(0, 3.0), z1 - 0.3)],
                   tuple(c * 0.5 for c in tint))
    if collide:
        collide_height = max(lowest, height * 0.6)
        b.collide_box(((x0 + x1) / 2, collide_height / 2, (z0 + z1) / 2), (x1 - x0, collide_height, z1 - z0))
    return height


def heap(b, node, cx, cz, rx, rz, height, seed, color=(0.9, 0.88, 0.84), resolution=7, material="rubble", base=0.0):
    """Rubble mound: displaced dome with smooth normals."""
    rng = np.random.default_rng(seed)
    n = resolution
    us = np.linspace(-1.0, 1.0, n + 1)
    grid_x, grid_z = np.meshgrid(us, us)
    radius = np.sqrt(grid_x ** 2 + grid_z ** 2)
    points = np.stack([cx + grid_x * rx, np.zeros_like(grid_x), cz + grid_z * rz], axis=-1).reshape(-1, 3)
    bump = noise.fbm(points * 0.9 + rng.uniform(0, 40, 3), 1.0, 3, seed)
    dome = np.clip(1.0 - radius.reshape(-1) ** 2, 0.0, 1.0) ** 0.7
    points[:, 1] = base + height * dome * (0.45 + 1.1 * bump) - 0.05 * (1.0 - dome)
    heights = points[:, 1].reshape(n + 1, n + 1)
    dz, dx = np.gradient(heights, rz * 2.0 / n, rx * 2.0 / n)
    normals = np.stack([-dx, np.ones_like(dx), -dz], axis=-1).reshape(-1, 3)
    normals /= np.linalg.norm(normals, axis=1, keepdims=True)
    tile = b.materials[material]["tile"]
    uvs = np.stack([points[:, 0] / tile, points[:, 2] / tile], axis=1)
    tone = 0.62 + 0.55 * bump
    colors = np.asarray(color)[None, :] * tone[:, None]
    triangles = []
    for j in range(n):
        for i in range(n):
            a = j * (n + 1) + i
            c = a + n + 1
            triangles.append((a, c, a + 1))
            triangles.append((a + 1, c, c + 1))
    b.part(node, material).add(points, normals, uvs, colors, triangles)
    return rng


def debris(b, node, cx, cz, rx, rz, height, seed, slabs=2, rocks=3):
    rng = heap(b, node, cx, cz, rx, rz, height, seed)
    for _ in range(rocks):
        px, pz = cx + rng.uniform(-0.7, 0.7) * rx, cz + rng.uniform(-0.7, 0.7) * rz
        size = rng.uniform(0.5, 1.3)
        b.rock(node, "rubble", (px, height * 0.35 + size * 0.2, pz), (size * 1.3, size, size * 1.1), int(rng.integers(1 << 30)), (0.8, 0.78, 0.74))
    for _ in range(slabs):
        px, pz = cx + rng.uniform(-0.55, 0.55) * rx, cz + rng.uniform(-0.55, 0.55) * rz
        basis = rot_y(rng.uniform(0, 360)) @ rot_x(rng.uniform(14, 38)) @ rot_z(rng.uniform(-14, 14))
        b.box(node, "concrete", (px, height * 0.5 + 0.2, pz), (rng.uniform(1.6, 3.2), 0.24, rng.uniform(1.2, 2.4)), basis=basis,
              color=(0.7, 0.7, 0.68))


# ---------------------------------------------------------------------------
# Fortress
# ---------------------------------------------------------------------------
def parapet(b, node, start, end, inward, base, low=0.9, merlon=0.7, thickness=0.5, pitch=2.6, color=CONCRETE):
    """Crenellated parapet from start to end (x, z); `inward` is the unit normal
    toward the wall walk, the parapet's outer face sits on the start-end line."""
    start, end = np.asarray(start, np.float64), np.asarray(end, np.float64)
    direction = end - start
    length = float(np.linalg.norm(direction))
    direction /= length
    yaw = math.degrees(math.atan2(direction[0], direction[1]))
    inward = np.asarray(inward, np.float64)
    mid = (start + end) / 2 + inward * thickness / 2
    b.box(node, "concrete", (mid[0], base + low / 2, mid[1]), (thickness, low, length), yaw, color, cell=3.0, skip="y-")
    count = max(1, int(length // pitch))
    step = length / count
    for i in range(count):
        centre = start + direction * (i + 0.5) * step + inward * thickness / 2
        b.box(node, "concrete", (centre[0], base + low + merlon / 2, centre[1]), (thickness, merlon, step * 0.58), yaw, color, skip="y-")


def sandbags(b, node, start, end, base, rows=2, seed=0, color=(0.92, 0.88, 0.78)):
    rng = np.random.default_rng(seed)
    start, end = np.asarray(start, np.float64), np.asarray(end, np.float64)
    direction = end - start
    length = float(np.linalg.norm(direction))
    direction /= length
    yaw = math.degrees(math.atan2(direction[0], direction[1])) + 90.0
    bag = 0.62
    for row in range(rows):
        count = max(1, int(length / bag) - (row % 2))
        offset = (length - count * bag) / 2
        for i in range(count):
            centre = start + direction * (offset + (i + 0.5) * bag)
            shade = 0.82 + 0.3 * rng.random()
            b.blob(node, "burlap", (centre[0], base + 0.11 + row * 0.19, centre[1]), (0.33, 0.125, 0.19), 6, 4,
                   tuple(c * shade for c in color), yaw + rng.uniform(-7, 7))


def fortress(b):
    node = "Fortress"
    px, pz = PIVOT
    # Gun bastion: a half-round barbette projecting from the rear wall.
    angles = np.radians(np.arange(-90, 91, 22.5))
    ring = [(px + BASTION_R * math.sin(a), pz - BASTION_R * math.cos(a)) for a in angles]
    outline = [(-BASTION_R, BACK_Z)] + ring + [(BASTION_R, BACK_Z)]
    centre = (px, DECK, pz + 0.6)
    for i in range(len(outline) - 1):
        (ax, az), (cx, cz) = outline[i], outline[i + 1]
        b.tri(node, "concrete", [centre, (cx, DECK, cz), (ax, DECK, az)], (0.78, 0.78, 0.76))
        spread = 1.22
        base_a = (px + (ax - px) * spread, 0.0, (pz + (az - pz) * spread) if az < BACK_Z else az)
        base_c = (px + (cx - px) * spread, 0.0, (pz + (cz - pz) * spread) if cz < BACK_Z else cz)
        b.quad(node, "concrete", [base_c, base_a, (ax, DECK, az), (cx, DECK, cz)], CONCRETE, cell=2.0)
    # Low kerb the guns fire over; it stays under the bore line at full depression.
    kerb_h, kerb_w = 0.34, 0.34
    inner = [(px + (BASTION_R - kerb_w) * math.sin(a), pz - (BASTION_R - kerb_w) * math.cos(a)) for a in angles]
    top = DECK + kerb_h
    tone = (0.9, 0.9, 0.88)
    for i in range(len(ring) - 1):
        (ax, az), (cx, cz) = ring[i], ring[i + 1]
        (ix, iz), (jx, jz) = inner[i], inner[i + 1]
        b.quad(node, "concrete", [(ix, top, iz), (jx, top, jz), (cx, top, cz), (ax, top, az)], tone)
        b.quad(node, "concrete", [(jx, DECK, jz), (ix, DECK, iz), (ix, top, iz), (jx, top, jz)], (0.8, 0.8, 0.78))
        b.quad(node, "concrete", [(cx, DECK, cz), (ax, DECK, az), (ax, top, az), (cx, top, cz)], tone)
    for (ax, az), (ix, iz), flip in ((ring[0], inner[0], False), (ring[-1], inner[-1], True)):
        corners = [(ax, DECK, az), (ix, DECK, iz), (ix, top, iz), (ax, top, az)]
        b.quad(node, "concrete", corners[::-1] if flip else corners, tone)
    # Traverse ring and deck plates under the mount.
    b.cylinder(node, "metal", (px, DECK, pz), 0.95, 0.035, 20, (0.3, 0.32, 0.31))
    b.cylinder(node, "metal", (px, DECK + 0.035, pz), 0.62, 0.03, 16, (0.2, 0.21, 0.21))
    # Sandbags and ready ammunition on the flanks, outside the firing arc.
    sandbags(b, node, (-BASTION_R + 0.25, -1.2), (-BASTION_R + 0.25, BACK_Z - 0.2), DECK, 3, 3)
    sandbags(b, node, (BASTION_R - 0.25, -1.2), (BASTION_R - 0.25, BACK_Z - 0.2), DECK, 3, 4)
    for side in (-1, 1):
        b.box(node, "metal", (side * 1.45, DECK + 0.17, 0.75), (0.46, 0.34, 0.3), 12 * side, (0.33, 0.38, 0.27))
        b.box(node, "metal", (side * 1.52, DECK + 0.51, 0.78), (0.46, 0.34, 0.3), -8 * side, (0.3, 0.35, 0.25))
        b.box(node, "metal", (side * 1.0, DECK + 0.17, 1.05), (0.46, 0.34, 0.3), 80 * side, (0.33, 0.38, 0.27))

    # Rear wall with its wall walk.
    depth = 4.5
    for side in (-1, 1):
        x0, x1 = sorted((side * BASTION_R, side * (ARM_X - 2.0)))
        b.box(node, "concrete", ((x0 + x1) / 2, DECK / 2, BACK_Z + depth / 2), (x1 - x0, DECK, depth), 0, CONCRETE, cell=2.6, skip="y-",
              collide=True)
        parapet(b, node, (x0 + (0.5 if side > 0 else 0.0), BACK_Z), (x1 - (0.0 if side > 0 else 0.5), BACK_Z), (0, 1), DECK, 0.75, 0.6)
        sandbags(b, node, (side * 5.0, BACK_Z + 1.2), (side * 8.2, BACK_Z + 1.2), DECK, 2, 7 + side)
        b.box(node, "metal", (side * 10.5, DECK + 0.3, BACK_Z + 2.4), (1.1, 0.6, 0.7), 20 * side, (0.3, 0.34, 0.26))
    b.box(node, "concrete", (0, DECK / 2, BACK_Z + depth / 2 + 0.01), (BASTION_R * 2, DECK, depth), 0, CONCRETE, skip="y-z-")
    b.box(node, "concrete", (0, DECK + 1.5, BACK_Z + depth + 0.3), (ARM_X * 2, 3.0, 0.6), 0, CONCRETE_DARK, cell=3.0)

    # Corner towers tie the rear wall into the arms and close the view backwards.
    for side in (-1, 1):
        cx = side * (ARM_X + 2.2)
        b.box(node, "concrete", (cx, 4.75, 3.2), (8.4, 9.5, 9.4), 0, CONCRETE, cell=2.8, skip="y-", collide=True)
        b.box(node, "concrete", (cx, 9.8, 3.2), (8.5, 0.6, 9.5), 0, (0.7, 0.7, 0.68), skip="y-")
        b.box(node, "concrete", (cx, 10.6, 3.2), (6.6, 1.1, 7.6), 0, CONCRETE_DARK, skip="y-")
        b.box(node, "interior", (cx - side * 4.21, 6.4, 0.6), (0.06, 0.5, 1.6), 0)
        b.box(node, "interior", (cx - side * 2.0, 6.4, -1.51), (1.6, 0.5, 0.06), 0)

    # Wall arms.
    for side in (-1, 1):
        arm(b, side)
    gatehouse(b)
    patch(b)

    # Flank towers at the mouth of the court and the outer curtain wall.
    for side in (-1, 1):
        cx = side * (ARM_X + 2.0)
        b.box(node, "concrete", (cx, 4.5, -47.5), (7.4, 9.0, 7.4), 0, CONCRETE, cell=2.6, skip="y-", collide=True)
        b.box(node, "concrete", (cx, 9.25, -47.5), (7.6, 0.5, 7.6), 0, (0.7, 0.7, 0.68), skip="y-")
        for dx, dz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            b.box(node, "metal", (cx + dx * 3.0, 10.4, -47.5 + dz * 3.0), (0.22, 1.9, 0.22), 0, STEEL)
        b.box(node, "metal", (cx, 11.45, -47.5), (7.2, 0.2, 7.2), 0, (0.3, 0.3, 0.29))
        b.box(node, "lamp", (cx - side * 2.6, 10.1, -44.2), (0.7, 0.7, 0.25), 0)
        b.box(node, "metal", (cx - side * 2.6, 10.1, -44.36), (0.86, 0.86, 0.3), 0, (0.2, 0.2, 0.2))
        x0, x1 = sorted((side * (ARM_X + 5.7), side * 78.0))
        b.box(node, "concrete", ((x0 + x1) / 2, ARM_TOP / 2, -46.5), (x1 - x0, ARM_TOP, 3.0), 0, CONCRETE, cell=3.2, skip="y-", collide=True)
        parapet(b, node, (x0, -48.0), (x1, -48.0), (0, 1), ARM_TOP, 0.9, 0.7)


def arm(b, side):
    """One wall arm; side -1 is the left (patched breach), +1 the right (gate)."""
    node = "Fortress"
    inner = side * ARM_X
    outer = side * (ARM_X + ARM_T)
    centre_x = (inner + outer) / 2
    if side > 0:
        gaps = [(GATEHOUSE_Z0, GATEHOUSE_Z1)]
    else:
        gaps = [(PATCH_Z0, PATCH_Z1)]
    spans = []
    cursor = ARM_Z0
    for z0, z1 in gaps:
        spans.append((cursor, z0))
        cursor = z1
    spans.append((cursor, ARM_Z1))
    for z0, z1 in spans:
        b.box(node, "concrete", (centre_x, ARM_TOP / 2, (z0 + z1) / 2), (ARM_T, ARM_TOP, z1 - z0), 0, CONCRETE, cell=2.5, skip="y-", collide=True)
        # Plinth and a string course break up the face.
        b.box(node, "concrete", (inner - side * 0.1, 0.5, (z0 + z1) / 2), (0.2, 1.0, z1 - z0), 0, (0.74, 0.74, 0.72), cell=3.0, skip="y-")
        b.box(node, "concrete", (inner - side * 0.06, 4.35, (z0 + z1) / 2), (0.12, 0.3, z1 - z0), 0, (0.72, 0.72, 0.7))
    if side < 0:
        # Lintel over the patched breach and the dark void behind it.
        b.box(node, "concrete", (centre_x, (PATCH_H + ARM_TOP) / 2, (PATCH_Z0 + PATCH_Z1) / 2), (ARM_T, ARM_TOP - PATCH_H, PATCH_Z1 - PATCH_Z0), 0,
              CONCRETE_DARK, cell=2.5)
        b.box(node, "interior", (outer + 0.2, PATCH_H / 2, (PATCH_Z0 + PATCH_Z1) / 2), (0.2, PATCH_H, PATCH_Z1 - PATCH_Z0), 0)
        b.collide_box((centre_x, (PATCH_H + ARM_TOP) / 2, (PATCH_Z0 + PATCH_Z1) / 2), (ARM_T, ARM_TOP - PATCH_H, PATCH_Z1 - PATCH_Z0))
    # Pilasters.
    z = ARM_Z1 - 4.0
    while z > ARM_Z0 + 3.0:
        blocked = any(z0 - 1.2 < z < z1 + 1.2 for z0, z1 in gaps)
        if not blocked:
            b.box(node, "concrete", (inner - side * 0.15, ARM_TOP / 2 + 0.2, z), (0.3, ARM_TOP + 0.4, 0.9), 0, (0.8, 0.8, 0.78), cell=2.6, skip="y-")
        z -= 7.0
    # Parapets on both edges of the wall walk.
    if side > 0:
        parapet(b, node, (inner, ARM_Z1), (inner, GATEHOUSE_Z1), (1, 0), ARM_TOP, 1.0, 0.7)
        parapet(b, node, (inner, GATEHOUSE_Z0), (inner, ARM_Z0), (1, 0), ARM_TOP, 1.0, 0.7)
    else:
        parapet(b, node, (inner, ARM_Z0), (inner, ARM_Z1), (-1, 0), ARM_TOP, 1.0, 0.7)
    b.box(node, "concrete", (outer - side * 0.25, ARM_TOP + 0.5, (ARM_Z0 + ARM_Z1) / 2), (0.5, 1.0, ARM_Z1 - ARM_Z0), 0, CONCRETE_DARK, skip="y-")
    # Wall lamps.
    for z in (-8.0, -36.0, -44.0):
        b.box(node, "metal", (inner - side * 0.25, 4.0, z), (0.5, 0.08, 0.08), 0, STEEL)
        b.box(node, "lamp", (inner - side * 0.52, 3.9, z), (0.16, 0.2, 0.34), 0)


def gatehouse(b):
    node = "Fortress"
    x0, x1 = GATEHOUSE_X, ARM_X + ARM_T + 0.8
    top = 7.4
    cx = (x0 + x1) / 2
    for z0, z1 in ((GATEHOUSE_Z0, GATE_Z0), (GATE_Z1, GATEHOUSE_Z1)):
        b.box(node, "concrete", (cx, top / 2, (z0 + z1) / 2), (x1 - x0, top, z1 - z0), 0, CONCRETE, cell=2.4, skip="y-", collide=True)
    b.box(node, "concrete", (cx, (GATE_H + top) / 2, (GATE_Z0 + GATE_Z1) / 2), (x1 - x0, top - GATE_H, GATE_Z1 - GATE_Z0), 0, CONCRETE, cell=2.4,
          collide=True)
    b.box(node, "concrete", (cx, top + 0.2, (GATEHOUSE_Z0 + GATEHOUSE_Z1) / 2), (x1 - x0 + 0.5, 0.4, GATEHOUSE_Z1 - GATEHOUSE_Z0 + 0.5), 0,
          (0.7, 0.7, 0.68), skip="y-")
    parapet(b, node, (x0, GATEHOUSE_Z1), (x0, GATEHOUSE_Z0), (1, 0), top + 0.4, 0.5, 0.6, pitch=2.2)
    sandbags(b, node, (x0 + 1.1, GATEHOUSE_Z0 + 1.0), (x0 + 1.1, GATEHOUSE_Z0 + 4.4), top + 0.4, 2, 21)
    # Passage behind the leaves: dark throat and floor.
    b.quad(node, "interior", [(x1 + 0.3, 0, GATE_Z0), (x1 + 0.3, 0, GATE_Z1), (x1 + 0.3, GATE_H, GATE_Z1), (x1 + 0.3, GATE_H, GATE_Z0)])
    b.quad(node, "paving", [(x0, 0.02, GATE_Z1), (x1 + 0.3, 0.02, GATE_Z1), (x1 + 0.3, 0.02, GATE_Z0), (x0, 0.02, GATE_Z0)], (0.4, 0.4, 0.4))
    # Hazard chevrons on the jambs and lintel.
    stripe = 0.5
    for jamb_z, direction in ((GATE_Z0 - 0.02, -1), (GATE_Z1 + 0.02, 1)):
        y = 0.0
        index = 0
        while y < GATE_H + 0.5:
            color = (0.85, 0.66, 0.08) if index % 2 == 0 else (0.07, 0.07, 0.07)
            za, zb = sorted((jamb_z, jamb_z + direction * 0.55))
            b.quad(node, "marking", [(x0 - 0.012, y, za), (x0 - 0.012, y, zb), (x0 - 0.012, y + stripe, zb), (x0 - 0.012, y + stripe, za)], color)
            y += stripe
            index += 1
    z = GATE_Z0
    index = 0
    while z < GATE_Z1 - 1e-6:
        color = (0.85, 0.66, 0.08) if index % 2 == 0 else (0.07, 0.07, 0.07)
        b.quad(node, "marking", [(x0 - 0.012, GATE_H + 0.02, z), (x0 - 0.012, GATE_H + 0.02, z + stripe), (x0 - 0.012, GATE_H + 0.55, z + stripe),
                                 (x0 - 0.012, GATE_H + 0.55, z)], color)
        z += stripe
        index += 1
    # Lamps over the gate.
    for z in (GATE_Z0 - 0.9, GATE_Z1 + 0.9):
        b.box(node, "metal", (x0 - 0.3, 5.6, z), (0.6, 0.1, 0.1), 0, STEEL)
        b.box(node, "lamp", (x0 - 0.62, 5.45, z), (0.22, 0.3, 0.5), 0)
        b.box(node, "metal", (x0 - 0.62, 5.64, z), (0.3, 0.08, 0.6), 0, (0.18, 0.18, 0.18))

    # Gate leaves, each with its origin on the hinge so the game can swing them.
    leaf = (GATE_Z1 - GATE_Z0) / 2
    face_x = x0 + 0.45
    for name, hinge_z, direction in (("GateLeafA", GATE_Z0, 1.0), ("GateLeafB", GATE_Z1, -1.0)):
        b.pivot(name, (face_x, 0.0, hinge_z))
        centre_z = hinge_z + direction * leaf / 2
        b.box(name, "metal", (face_x, GATE_H / 2, centre_z), (0.16, GATE_H - 0.06, leaf - 0.05), 0, (0.36, 0.4, 0.37), cell=1.4)
        for y in (0.2, GATE_H * 0.36, GATE_H * 0.68, GATE_H - 0.2):
            b.box(name, "metal", (face_x - 0.12, y, centre_z), (0.1, 0.26, leaf - 0.05), 0, (0.26, 0.29, 0.27))
        for dz in (-leaf / 2 + 0.17, 0.0, leaf / 2 - 0.17):
            b.box(name, "metal", (face_x - 0.12, GATE_H / 2, centre_z + dz), (0.1, GATE_H - 0.06, 0.24), 0, (0.26, 0.29, 0.27))
        # Diagonal braces.
        for half in (-1, 1):
            basis = rot_x(direction * half * 38.0)
            b.box(name, "metal", (face_x - 0.1, GATE_H * 0.52, centre_z + half * leaf * 0.25), (0.07, GATE_H * 0.4, 0.14), basis=basis,
                  color=(0.3, 0.33, 0.3))
        # Hazard band along the foot.
        z = hinge_z if direction > 0 else hinge_z - leaf
        for index in range(7):
            color = (0.8, 0.62, 0.08) if index % 2 == 0 else (0.07, 0.07, 0.07)
            b.quad(name, "marking", [(face_x - 0.085, 0.36, z + index * leaf / 7), (face_x - 0.085, 0.36, z + (index + 1) * leaf / 7),
                                     (face_x - 0.085, 0.78, z + (index + 1) * leaf / 7), (face_x - 0.085, 0.78, z + index * leaf / 7)], color)


def patch(b):
    """Emergency repair over the breach in the left arm. A separate node: the
    game blows it out when the wall falls."""
    name = "WallPatch"
    rng = np.random.default_rng(77)
    face = -ARM_X
    mid = (PATCH_Z0 + PATCH_Z1) / 2
    b.pivot(name, (face, 0.0, mid))
    # Overlapping plates.
    z = PATCH_Z0 - 0.3
    while z < PATCH_Z1:
        y = 0.0
        width = rng.uniform(1.5, 2.3)
        while y < PATCH_H + 0.2:
            height = rng.uniform(1.1, 1.7)
            tone = rng.uniform(0.75, 1.05)
            tint = (0.5 * tone, 0.4 * tone, 0.3 * tone) if rng.random() < 0.55 else (0.38 * tone, 0.42 * tone, 0.4 * tone)
            b.box(name, "metal", (face + 0.1 + rng.uniform(0.0, 0.07), y + height / 2, min(z + width / 2, PATCH_Z1 + 0.2)),
                  (0.07, height + 0.1, width + 0.12), 0, tint)
            y += height
        z += width
    # Bracing.
    for y in (0.7, 2.0, 3.3):
        b.box(name, "metal", (face + 0.25, y, mid), (0.16, 0.2, PATCH_Z1 - PATCH_Z0 + 1.4), 0, (0.24, 0.2, 0.17))
    for z in (PATCH_Z0 + 0.6, mid - 1.1, mid + 1.2, PATCH_Z1 - 0.6):
        b.box(name, "metal", (face + 0.36, PATCH_H / 2 + 0.1, z), (0.18, PATCH_H + 0.4, 0.18), 0, (0.2, 0.18, 0.16))
    # Ragged concrete around the opening.
    for z, lean in ((PATCH_Z0 - 0.15, 1), (PATCH_Z1 + 0.15, -1)):
        for k in range(4):
            b.rock("Fortress", "concrete", (face + 0.1, 0.5 + k * 1.0, z + lean * rng.uniform(0.0, 0.3)), (0.7, 1.1, rng.uniform(0.6, 1.1)),
                   int(rng.integers(1 << 30)), (0.66, 0.66, 0.64), flatten=1.0)


# ---------------------------------------------------------------------------
# Ground
# ---------------------------------------------------------------------------
def ground(b):
    node = "Ground"
    b.quad(node, "paving", [(-ARM_X, 0, BACK_Z), (ARM_X, 0, BACK_Z), (ARM_X, 0, ARM_Z0), (-ARM_X, 0, ARM_Z0)], (0.95, 0.94, 0.9), cell=1.8)
    b.quad(node, "asphalt", [(-78, 0, RING_Z1), (78, 0, RING_Z1), (78, 0, RING_Z0), (-78, 0, RING_Z0)], (1, 1, 1), cell=3.4)
    b.quad(node, "asphalt", [(-AVENUE_HALF, 0, RING_Z0), (AVENUE_HALF, 0, RING_Z0), (AVENUE_HALF, 0, LANDMARK_Z), (-AVENUE_HALF, 0, LANDMARK_Z)],
           (1, 1, 1), cell=3.0)
    for side in (-1, 1):
        x0, x1 = sorted((side * AVENUE_HALF, side * 78.0))
        b.quad(node, "asphalt", [(x0, 0, CROSS_Z1), (x1, 0, CROSS_Z1), (x1, 0, CROSS_Z0), (x0, 0, CROSS_Z0)], (0.95, 0.95, 0.95), cell=5.0)
        b.quad(node, "asphalt", [(x0, 0, END_Z), (x1, 0, END_Z), (x1, 0, LANDMARK_Z), (x0, 0, LANDMARK_Z)], (0.9, 0.9, 0.9), cell=6.0)
        # Pavements with kerbs.
        for z0, z1 in ((CROSS_Z1, RING_Z0), (END_Z, CROSS_Z0)):
            xa, xb = sorted((side * AVENUE_HALF, side * FACADE_X))
            b.box(node, "paving", ((xa + xb) / 2, 0.08, (z0 + z1) / 2), (xb - xa, 0.16, z1 - z0), 0, (0.9, 0.88, 0.84), cell=3.5, skip="y-")
            # Block interiors: bare ground under and between the buildings.
            xc, xd = sorted((side * FACADE_X, side * 78.0))
            b.quad(node, "rubble", [(xc, 0.02, z1), (xd, 0.02, z1), (xd, 0.02, z0), (xc, 0.02, z0)], (0.6, 0.58, 0.55), cell=8.0)
    # Faded lane markings.
    z = RING_Z0 - 3.0
    while z > END_Z:
        if not (CROSS_Z0 - 1 < z < CROSS_Z1 + 3):
            b.quad(node, "marking", [(-0.09, 0.012, z), (0.09, 0.012, z), (0.09, 0.012, z - 3.0), (-0.09, 0.012, z - 3.0)], (0.5, 0.5, 0.46))
        z -= 8.0
    for x in np.arange(-7.5, 7.6, 1.5):
        b.quad(node, "marking", [(x - 0.3, 0.012, RING_Z0 - 0.6), (x + 0.3, 0.012, RING_Z0 - 0.6), (x + 0.3, 0.012, RING_Z0 - 3.4),
                                 (x - 0.3, 0.012, RING_Z0 - 3.4)], (0.46, 0.46, 0.43))
    # Everything beyond the modelled streets.
    b.quad(node, "rubble", [(-260, -0.04, 30), (260, -0.04, 30), (260, -0.04, -300), (-260, -0.04, -300)], (0.4, 0.39, 0.37), cell=70.0)
    b.collide_quad([(-260, 0, 30), (260, 0, 30), (260, 0, -300), (-260, 0, -300)])


# ---------------------------------------------------------------------------
# Props
# ---------------------------------------------------------------------------
CAR_PROFILES = {
    "sedan": ([(-2.15, 0.32), (-2.2, 0.82), (-1.55, 0.9), (-0.95, 1.36), (0.65, 1.36), (1.3, 0.88), (2.2, 0.78), (2.22, 0.32)], 1.72),
    "van": ([(-2.4, 0.34), (-2.42, 1.75), (1.2, 1.78), (1.75, 1.1), (2.4, 1.0), (2.42, 0.34)], 1.9),
    "hatch": ([(-1.85, 0.32), (-1.9, 0.86), (-1.6, 1.36), (0.5, 1.38), (1.15, 0.88), (1.9, 0.78), (1.92, 0.32)], 1.66),
}


def car(b, node, x, z, yaw, seed, kind="sedan", tint=None, burnt=True, collide=True):
    rng = np.random.default_rng(seed)
    outline, width = CAR_PROFILES[kind]
    if tint is None:
        tint = BURNT if burnt else (0.4, 0.42, 0.44)
    glass = (0.05, 0.05, 0.055)
    colors = []
    for i in range(len(outline)):
        a, c = outline[i], outline[(i + 1) % len(outline)]
        sloped = abs(c[1] - a[1]) > 0.3 and abs(c[0] - a[0]) > 0.25 and min(a[1], c[1]) > 0.7
        tone = 0.85 + 0.3 * rng.random()
        colors.append(glass if sloped else tuple(v * tone for v in tint))
    lift = 0.0 if not burnt else -0.12
    b.prism(node, "metal", outline, width, (x, lift, z), yaw, tint, colors=colors)
    frame = rot_y(yaw)
    origin = np.array([x, lift, z])
    # Side glass.
    roof = max(p[1] for p in outline)
    z_back = min(p[0] for p in outline if p[1] > roof - 0.1)
    z_front = max(p[0] for p in outline if p[1] > roof - 0.1)
    for side in (-1, 1):
        sx = side * (width / 2 + 0.006)
        corners = [origin + frame @ np.array([sx, 0.95, z_back - 0.25]), origin + frame @ np.array([sx, 0.95, z_front + 0.3]),
                   origin + frame @ np.array([sx, roof - 0.08, z_front - 0.05]), origin + frame @ np.array([sx, roof - 0.08, z_back + 0.1])]
        if side > 0:
            corners = corners[::-1]
        b.quad(node, "interior", corners)
    length = max(p[0] for p in outline)
    for side in (-1, 1):
        for end in (-1, 1):
            if burnt and rng.random() < 0.25:
                continue
            centre = origin + frame @ np.array([side * (width / 2 - 0.12), 0.31 - lift * 0.5, end * (length - 0.75)])
            axis = frame @ np.array([side * 1.0, 0.0, 0.0])
            b.cylinder(node, "metal", centre - axis * 0.1, 0.31, 0.2, 9, (0.08, 0.08, 0.08) if not burnt else (0.2, 0.17, 0.15), axis=axis)
    if collide:
        b.collide_box((x, 0.7, z), (width, 1.4, length * 2), yaw)


def bus(b, node, x, z, yaw, roll=0.0):
    """Burnt-out bus, optionally lying on its side."""
    length, width, height = 11.0, 2.5, 2.9
    basis = rot_y(yaw) @ rot_z(roll)
    rolled = abs(roll) > 1.0
    centre = np.array([x, width / 2 if rolled else height / 2 + 0.25, z])
    b.box(node, "metal", centre, (width, height, length), basis=basis, color=(0.34, 0.2, 0.13), cell=2.4)
    for side in (-1, 1):
        for i in range(7):
            local = np.array([side * (width / 2 + 0.012), 0.45, -length / 2 + 1.2 + i * 1.42])
            corners = []
            for sy, sz in ((-1, -1), (-1, 1), (1, 1), (1, -1)):
                corners.append(centre + basis @ (local + np.array([0.0, sy * 0.42, sz * 0.56])))
            if side > 0:
                corners = corners[::-1]
            b.quad(node, "interior", corners)
    # Wheels so the overturned hull is not a plain slab.
    for dz in (-3.6, 3.6):
        for sx in (-1, 1):
            hub = centre + basis @ np.array([sx * (width / 2 - 0.3), -height / 2 + 0.1, dz])
            axis = basis @ np.array([sx * 1.0, 0.0, 0.0])
            b.cylinder(node, "metal", hub - axis * 0.12, 0.5, 0.3, 10, (0.1, 0.1, 0.1), axis=axis)
    if rolled:
        b.collide_box((x, width / 2, z), (height, width, length), yaw)
    else:
        b.collide_box((x, height / 2, z), (width, height, length), yaw)


def apc(b, node, x, z, yaw):
    """Knocked-out armoured carrier: the wreck in the middle of the court."""
    hull = [(-3.3, 0.55), (-3.45, 1.35), (-2.9, 2.05), (1.6, 2.05), (2.9, 1.5), (3.45, 1.2), (3.2, 0.55)]
    tint = (0.2, 0.22, 0.17)
    b.prism(node, "metal", hull, 2.7, (x, 0.0, z), yaw, tint)
    frame = rot_y(yaw)
    origin = np.array([x, 0.0, z])
    b.box(node, "metal", origin + frame @ np.array([0.0, 2.3, -0.3]), (1.5, 0.5, 1.7), yaw, (0.17, 0.18, 0.15))
    muzzle = frame @ np.array([0.0, 0.12, 1.0])
    b.cylinder(node, "metal", origin + frame @ np.array([0.0, 2.34, 0.4]), 0.06, 2.1, 8, (0.1, 0.1, 0.1), axis=muzzle)
    for side in (-1, 1):
        for dz in (-2.3, -0.8, 0.8, 2.3):
            hub = origin + frame @ np.array([side * 1.2, 0.55, dz])
            axis = frame @ np.array([side * 1.0, 0.0, 0.0])
            b.cylinder(node, "metal", hub, 0.55, 0.36, 10, (0.09, 0.09, 0.09), axis=axis)
    b.box(node, "metal", origin + frame @ np.array([0.7, 2.1, -2.0]), (0.8, 0.08, 0.9), basis=frame @ rot_x(-35), color=(0.16, 0.17, 0.14))
    b.collide_box((x, 1.1, z), (2.7, 2.2, 6.8), yaw)


def barrier(b, node, x, z, yaw, tint=(0.8, 0.8, 0.78), length=2.6):
    outline = [(-0.3, 0.0), (-0.28, 0.22), (-0.1, 0.42), (-0.08, 0.86), (0.08, 0.86), (0.1, 0.42), (0.28, 0.22), (0.3, 0.0)]
    b.prism(node, "concrete", outline, length, (x, 0.0, z), yaw + 90.0, tint, tile=1.5)
    b.collide_box((x, 0.43, z), (0.6, 0.86, length), yaw)


def hedgehog(b, node, x, z, seed, size=1.5):
    rng = np.random.default_rng(seed)
    spin = rot_y(rng.uniform(0, 360))
    tint = (0.3, 0.19, 0.13)
    for basis in (rot_z(54.7) @ rot_y(45), rot_z(-54.7) @ rot_y(-45), rot_x(54.7) @ rot_y(45)):
        b.box(node, "metal", (x, size * 0.3, z), (0.13, size, 0.13), basis=spin @ basis, color=tint)


def tooth(b, node, x, z, yaw, tint=(0.74, 0.74, 0.72)):
    b.box(node, "concrete", (x, 0.5, z), (1.15, 1.0, 1.15), yaw, tint, skip="y-", taper=(0.32, 0.32), tile=1.8)


def lamp_post(b, node, x, z, side, lean=0.0, lit=False):
    basis = rot_z(lean)
    origin = np.array([x, 0.0, z])
    b.box(node, "metal", origin + basis @ np.array([0.0, 3.6, 0.0]), (0.16, 7.2, 0.16), basis=basis, color=(0.2, 0.21, 0.2))
    b.box(node, "metal", origin + basis @ np.array([-side * 0.8, 7.15, 0.0]), (1.7, 0.1, 0.12), basis=basis, color=(0.2, 0.21, 0.2))
    b.box(node, "lamp" if lit else "interior", origin + basis @ np.array([-side * 1.5, 7.05, 0.0]), (0.5, 0.1, 0.24), basis=basis)


def crate(b, node, x, y, z, yaw, size=(1.0, 0.6, 0.6), tint=(0.3, 0.34, 0.25)):
    b.box(node, "metal", (x, y + size[1] / 2, z), size, yaw, tint)


def props(b, layout):
    court = "CourtProps"
    # Wrecks down the centre line of the court; zombie lanes pass on both sides.
    apc(b, court, 0.3, -33.5, 24.0)
    car(b, court, -0.6, -24.5, 72.0, 5, "sedan")
    layout["fires"].append(((-0.6, 0.9, -24.5), 1.3))
    debris(b, court, 0.8, -28.6, 2.0, 1.5, 0.55, 31, slabs=1, rocks=2)
    # Hedgehogs and dragon's teeth ring the dead ground below the bastion.
    for i, degrees in enumerate(np.arange(-42.0, 42.1, 10.5)):
        a = math.radians(degrees)
        hedgehog(b, court, 17.2 * math.sin(a), PIVOT[1] - 17.2 * math.cos(a), 40 + i)
    for i, degrees in enumerate(np.arange(-34.0, 34.1, 8.5)):
        a = math.radians(degrees)
        tooth(b, court, 14.6 * math.sin(a), PIVOT[1] - 14.6 * math.cos(a), degrees * 0.7 + (i * 37) % 20)
    # Chicane at the mouth; the walking lanes on either side stay clear.
    barrier(b, court, -1.4, -43.6, 90.0)
    barrier(b, court, 1.3, -43.9, 84.0)
    barrier(b, court, 0.0, -41.2, 96.0, (0.72, 0.72, 0.7))
    for side in (-1, 1):
        barrier(b, court, side * 15.5, -45.4, 90.0 - side * 4.0)
    # Dead ground dressing: crater, spill from old fighting.
    heap(b, court, -6.5, -8.5, 3.4, 3.0, 0.5, 51, (0.5, 0.48, 0.45), 8)
    layout["scorch"].append(((-6.5, 0.0, -8.5), 4.2))
    debris(b, court, 9.5, -5.5, 2.4, 2.0, 0.7, 52, slabs=2, rocks=3)
    debris(b, court, -13.5, -3.2, 2.6, 2.2, 0.9, 53, slabs=1, rocks=3)
    debris(b, court, 14.6, -6.0, 1.8, 2.2, 0.8, 54, slabs=1, rocks=2)
    sandbags(b, court, (-4.0, -11.6), (-0.4, -12.6), 0.0, 3, 55)
    sandbags(b, court, (3.2, -11.2), (6.4, -9.6), 0.0, 2, 56)
    crate(b, court, 5.4, 0.0, -7.0, 30.0, (1.2, 0.7, 0.8))
    crate(b, court, -2.6, 0.0, -9.4, -18.0, (1.0, 0.6, 0.7), (0.34, 0.26, 0.17))
    layout["scorch"].append(((0.3, 0.0, -33.5), 5.0))
    layout["scorch"].append(((-0.6, 0.0, -24.5), 3.6))

    street = "StreetProps"
    # Ring road and avenue wrecks, kept clear of the walking lanes.
    car(b, street, 6.9, -62.5, 8.0, 11, "sedan")
    car(b, street, -7.1, -68.0, 172.0, 12, "hatch")
    car(b, street, -6.6, -74.5, -14.0, 13, "van", (0.3, 0.27, 0.24))
    car(b, street, 7.3, -96.0, 190.0, 14, "hatch")
    car(b, street, -7.0, -101.5, 10.0, 15, "sedan")
    car(b, street, -6.8, -118.0, 160.0, 16, "van")
    car(b, street, 6.4, -123.0, 30.0, 17, "sedan")
    car(b, street, 25.0, -49.3, 93.0, 18, "sedan")
    car(b, street, -41.0, -49.4, 86.0, 19, "van", (0.26, 0.22, 0.19))
    car(b, street, 21.0, -88.9, 96.0, 20, "hatch")
    car(b, street, -24.0, -79.2, 86.0, 21, "sedan")
    bus(b, street, 6.3, -109.0, 24.0, 90.0)
    layout["fires"].append(((6.9, 0.9, -62.5), 1.1))
    layout["fires"].append(((-6.8, 1.2, -118.0), 1.4))
    layout["scorch"].append(((6.9, 0.0, -62.5), 3.4))
    layout["scorch"].append(((-6.8, 0.0, -118.0), 4.0))
    layout["scorch"].append(((0.0, 0.0, -84.0), 6.0))
    for i, z in enumerate(np.arange(-62.0, END_Z, -22.0)):
        lamp_post(b, street, -9.6, z, -1, lean=(-9.0 if i == 1 else 0.0))
        lamp_post(b, street, 9.6, z - 11.0, 1, lean=(14.0 if i == 2 else 0.0))
    # Barricade abandoned on the avenue.
    barrier(b, street, -6.2, -86.5, 70.0)
    barrier(b, street, 6.6, -81.0, 110.0)
    hedgehog(b, street, 7.6, -70.0, 60)
    hedgehog(b, street, -7.8, -92.0, 61)
    for side in (-1, 1):
        barrier(b, street, side * 20.0, -57.2, 90.0 + side * 8.0)
        hedgehog(b, street, side * 31.0, -49.2, 63 + side)


# ---------------------------------------------------------------------------
# City
# ---------------------------------------------------------------------------
def city(b, layout):
    palette = [(0.78, 0.74, 0.66), (0.7, 0.66, 0.6), (0.64, 0.68, 0.7), (0.76, 0.66, 0.56), (0.62, 0.62, 0.6), (0.72, 0.6, 0.52)]
    # First blocks, between the ring road and the cross street.
    building(b, "BlockL1", -31.0, -FACADE_X, CROSS_Z1, RING_Z0, 5, 101, palette[0], 0.55, detail="x+z+", fire=0.05)
    building(b, "BlockL1", -53.0, -36.0, CROSS_Z1, RING_Z0, 4, 102, palette[1], 0.75, "brick", detail="x+z+")
    building(b, "BlockL1", -76.0, -55.0, CROSS_Z1 + 2.0, RING_Z0, 6, 103, palette[2], 0.35, detail="z+")
    building(b, "BlockR1", FACADE_X, 33.0, CROSS_Z1, RING_Z0, 6, 111, palette[3], 0.5, detail="x-z+")
    building(b, "BlockR1", 37.5, 55.0, CROSS_Z1, RING_Z0, 3, 112, palette[4], 0.8, "brick", detail="x-z+")
    building(b, "BlockR1", 57.0, 76.0, CROSS_Z1 + 3.0, RING_Z0, 5, 113, palette[5], 0.4, detail="z+")
    # Second blocks.
    building(b, "BlockL2", -32.0, -FACADE_X, -110.0, CROSS_Z0, 6, 121, palette[4], 0.5, detail="x+z+", fire=0.04)
    building(b, "BlockL2", -30.0, -FACADE_X, END_Z, -112.5, 4, 122, palette[3], 0.7, "brick", detail="x+z+")
    building(b, "BlockL2", -60.0, -35.0, -116.0, CROSS_Z0, 8, 123, palette[1], 0.45, detail="x+z+")
    building(b, "BlockR2", FACADE_X, 31.0, -108.0, CROSS_Z0, 4, 131, palette[2], 0.65, detail="x-z+")
    building(b, "BlockR2", FACADE_X, 33.0, END_Z, -110.5, 8, 132, palette[0], 0.5, detail="x-z+", fire=0.03)
    building(b, "BlockR2", 36.0, 62.0, -118.0, CROSS_Z0, 6, 133, palette[5], 0.55, detail="x-z+")
    # Landmark closing the avenue.
    building(b, "Landmark", -30.0, -5.0, LANDMARK_Z - 22.0, LANDMARK_Z, 9, 141, palette[1], 0.5, detail="z+x+")
    building(b, "Landmark", -5.0, 13.0, LANDMARK_Z - 26.0, LANDMARK_Z - 3.0, 12, 142, palette[4], 0.6, detail="z+x-x+")
    building(b, "Landmark", 15.0, 38.0, LANDMARK_Z - 20.0, LANDMARK_Z, 7, 143, palette[3], 0.6, detail="z+x-")
    building(b, "Landmark", -66.0, -34.0, LANDMARK_Z - 20.0, LANDMARK_Z, 6, 144, palette[2], 0.5, detail="z+")
    building(b, "Landmark", 42.0, 74.0, LANDMARK_Z - 20.0, LANDMARK_Z, 8, 145, palette[0], 0.5, detail="z+")

    # Rubble spilling out of the ruins.
    spills = [(-14.5, -61.0, 3.2, 3.6, 1.5), (-12.6, -72.0, 2.6, 3.4, 1.1), (14.2, -66.5, 3.0, 4.0, 1.4), (13.2, -59.5, 2.4, 2.4, 0.9),
              (-39.5, -59.4, 3.0, 2.2, 1.6), (41.0, -59.6, 3.0, 2.4, 1.5), (-13.2, -97.0, 2.8, 4.0, 1.3), (-14.0, -121.0, 3.4, 4.4, 1.7),
              (13.4, -100.5, 2.6, 3.6, 1.2), (14.0, -127.0, 3.2, 3.0, 1.4), (-22.0, -91.0, 4.5, 2.6, 1.3), (24.0, -91.5, 4.0, 2.6, 1.2),
              (-2.0, -142.4, 6.0, 2.6, 1.8), (31.0, -141.6, 4.0, 2.0, 1.5), (-33.0, -141.6, 4.0, 2.0, 1.4), (-44.0, -59.0, 4.0, 2.4, 1.2),
              (46.0, -59.2, 4.4, 2.4, 1.3)]
    for i, (x, z, rx, rz, h) in enumerate(spills):
        node = "StreetRubbleNear" if z > CROSS_Z0 else "StreetRubbleFar"
        debris(b, node, x, z, rx, rz, h, 200 + i, slabs=2 if h > 1.2 else 1, rocks=3)
    # Smoke columns over the ruins.
    for position, scale in (((-24.0, 14.0, -70.0), 1.0), ((26.0, 20.0, -100.0), 1.3), ((-40.0, 22.0, -112.0), 1.5), ((2.0, 30.0, -156.0), 2.0),
                            ((58.0, 16.0, -70.0), 1.2), ((-64.0, 18.0, -150.0), 1.6)):
        layout["smokes"].append((position, scale))
    layout["fires"].append(((-22.0, 9.6, -59.2), 1.8))
    layout["fires"].append(((22.5, 12.8, -110.6), 2.0))

    # Inside the walls: blacked-out but standing, a few windows still lit.
    tones = [(0.5, 0.5, 0.52), (0.56, 0.53, 0.5), (0.48, 0.5, 0.5)]
    for side in (-1, 1):
        specs = [(27.0, 45.0, -43.0, -24.0, 5), (27.5, 47.0, -21.0, -4.0, 7), (27.0, 44.0, -1.0, 16.0, 6), (50.0, 74.0, -40.0, -10.0, 9)]
        for i, (xa, xb, z0, z1, floors) in enumerate(specs):
            x0, x1 = sorted((side * xa, side * xb))
            face = "" if i == 3 else ("x-" if side > 0 else "x+")
            building(b, "InnerCity", x0, x1, z0, z1, floors, 300 + i + (10 if side > 0 else 0), tones[i % 3], 0.0,
                     detail=face, lit=0.07, collide=False)

    # Far skyline: flat silhouettes that the fog swallows.
    rng = np.random.default_rng(900)
    for i in range(46):
        x = rng.uniform(-240, 240)
        z = rng.uniform(-290, -175)
        if abs(x) < 80 and z > -200:
            z -= 30
        w, d, h = rng.uniform(14, 34), rng.uniform(14, 30), rng.uniform(22, 78)
        tone = rng.uniform(0.75, 1.1)
        b.box("Skyline", "skyline", (x, h / 2, z), (w, h, d), rng.uniform(-10, 10), (tone, tone, tone), skip="y-")
        if rng.random() < 0.7:
            b.box("Skyline", "skyline", (x + rng.uniform(-0.3, 0.3) * w, h + rng.uniform(2, 8) / 2, z), (w * rng.uniform(0.25, 0.6), rng.uniform(4, 14), d * 0.6),
                  rng.uniform(-10, 10), (tone * 0.9,) * 3, skip="y-")
    for side in (-1, 1):
        for i in range(9):
            x = side * rng.uniform(95, 230)
            z = rng.uniform(-170, 20)
            w, d, h = rng.uniform(16, 30), rng.uniform(16, 30), rng.uniform(18, 52)
            tone = rng.uniform(0.8, 1.1)
            b.box("Skyline", "skyline", (x, h / 2, z), (w, h, d), rng.uniform(-10, 10), (tone, tone, tone), skip="y-")


# ---------------------------------------------------------------------------
# Baked shading
# ---------------------------------------------------------------------------
def bake(b, layout):
    scorches = [(np.array(position), radius) for position, radius in layout["scorch"]]

    def grime(points, normals):
        mottle = 0.78 + 0.4 * noise.fbm(points * 0.085, 1.0, 3, 5)
        vertical = np.abs(normals[:, 1]) < 0.5
        foot = np.clip(points[:, 1] / 1.5, 0.0, 1.0)
        factor = np.where(vertical, mottle * (0.6 + 0.4 * foot), mottle)
        for position, radius in scorches:
            distance = np.linalg.norm(points[:, [0, 2]] - position[[0, 2]], axis=1)
            burn = np.clip((radius - distance) / (radius * 0.65), 0.0, 1.0)
            near_ground = points[:, 1] < 0.4
            factor = np.where(near_ground, factor * (1.0 - 0.72 * burn), factor)
        return factor

    b.shade(grime, materials={"concrete", "paving", "asphalt", "plaster", "brick", "rubble"})

    def court_contact(points, normals):
        # Darken the court floor where it meets the walls.
        inside = (np.abs(points[:, 0]) <= ARM_X + 0.01) & (points[:, 2] >= ARM_Z0 - 0.01) & (points[:, 1] < 0.05)
        edge = np.minimum(ARM_X - np.abs(points[:, 0]), BACK_Z - points[:, 2])
        return np.where(inside, 0.62 + 0.38 * np.clip(edge / 2.2, 0.0, 1.0), 1.0)

    b.shade(court_contact, materials={"paving"}, nodes={"Ground"})


# ---------------------------------------------------------------------------
# Gameplay layout
# ---------------------------------------------------------------------------
def gameplay(layout):
    layout["mount"] = (PIVOT[0], DECK, PIVOT[1])
    layout["eye"] = (0.0, DECK + 1.6, 0.0)
    mouth_z = ARM_Z0 + 1.5
    layout["mouths"] = {"left": ((-6.5, 0.0, mouth_z), 3.0), "right": ((6.5, 0.0, mouth_z), 3.0)}
    shared = [((-1.8, 0.0, -117.0), 3.0), ((-1.8, 0.0, -103.0), 3.0), ((0.0, 0.0, -92.0), 4.5), ((0.0, 0.0, -70.0), 4.5), ((0.0, 0.0, -54.0), 5.5)]
    # Every route starts out of sight of the gun: behind a block corner, in an alley or behind the wall arms.
    layout["routes"] = {
        "avenue_left": [((-24.0, 0.0, -136.0), 3.0), ((-4.0, 0.0, -132.0), 3.5)] + shared,
        "avenue_right": [((24.0, 0.0, -136.0), 3.0), ((2.0, 0.0, -132.0), 3.5)] + shared,
        "cross_left": [((-30.0, 0.0, -84.0), 3.5), ((-14.0, 0.0, -84.0), 3.5), ((-3.0, 0.0, -72.0), 3.5), ((-2.0, 0.0, -54.0), 4.5)],
        "cross_right": [((30.0, 0.0, -84.0), 3.5), ((14.0, 0.0, -84.0), 3.5), ((3.0, 0.0, -72.0), 3.5), ((2.0, 0.0, -54.0), 4.5)],
        "ring_left": [((-32.0, 0.0, -54.2), 2.6), ((-16.0, 0.0, -54.2), 2.6), ((-8.0, 0.0, -52.5), 2.5)],
        "ring_right": [((32.0, 0.0, -54.2), 2.6), ((16.0, 0.0, -54.2), 2.6), ((8.0, 0.0, -52.5), 2.5)],
        "alley_left": [((-33.5, 0.0, -66.0), 1.2), ((-33.5, 0.0, -57.4), 1.4), ((-16.0, 0.0, -54.2), 2.6), ((-8.0, 0.0, -52.5), 2.5)],
        "alley_right": [((35.2, 0.0, -66.0), 1.2), ((35.2, 0.0, -57.4), 1.4), ((16.0, 0.0, -54.2), 2.6), ((8.0, 0.0, -52.5), 2.5)],
    }
    stand = 0.85
    gate_x = GATEHOUSE_X + 0.45 - 0.2 - stand
    layout["lines"] = {
        "gate": {"a": (gate_x, 0.0, GATE_Z0 + 0.5), "b": (gate_x, 0.0, GATE_Z1 - 0.5), "normal": (-1.0, 0.0, 0.0), "rows": 2, "spacing": 1.0,
                 "target": "gate", "side": "right", "priority": 0},
        "patch": {"a": (-ARM_X + stand + 0.3, 0.0, PATCH_Z0 + 0.5), "b": (-ARM_X + stand + 0.3, 0.0, PATCH_Z1 - 0.5), "normal": (1.0, 0.0, 0.0),
                  "rows": 2, "spacing": 1.0, "target": "wall", "side": "left", "priority": 0},
        "wall_right": {"a": (ARM_X - stand - 0.2, 0.0, -40.0), "b": (ARM_X - stand - 0.2, 0.0, GATEHOUSE_Z0 - 1.6), "normal": (-1.0, 0.0, 0.0),
                       "rows": 1, "spacing": 1.1, "target": "wall", "side": "right", "priority": 1},
        "wall_left_far": {"a": (-ARM_X + stand + 0.2, 0.0, -42.0), "b": (-ARM_X + stand + 0.2, 0.0, PATCH_Z0 - 1.6), "normal": (1.0, 0.0, 0.0),
                          "rows": 1, "spacing": 1.1, "target": "wall", "side": "left", "priority": 1},
        "wall_left_near": {"a": (-ARM_X + stand + 0.2, 0.0, PATCH_Z1 + 1.6), "b": (-ARM_X + stand + 0.2, 0.0, -11.0), "normal": (1.0, 0.0, 0.0),
                           "rows": 1, "spacing": 1.1, "target": "wall", "side": "left", "priority": 1},
    }
    gate_mid = (GATE_Z0 + GATE_Z1) / 2
    patch_mid = (PATCH_Z0 + PATCH_Z1) / 2
    layout["breach"] = {
        "gate": [((GATEHOUSE_X - 1.6, 0.0, gate_mid), 2.4), ((ARM_X + ARM_T + 5.0, 0.0, gate_mid), 2.2)],
        "wall": [((-ARM_X + 1.8, 0.0, patch_mid), 2.4), ((-ARM_X - ARM_T - 4.0, 0.0, patch_mid), 2.2)],
    }
    layout["gate"] = {"center": (GATEHOUSE_X + 0.45, GATE_H / 2, gate_mid), "size": (0.5, GATE_H, GATE_Z1 - GATE_Z0)}
    layout["patch"] = {"center": (-ARM_X + 0.2, PATCH_H / 2, patch_mid), "size": (0.6, PATCH_H, PATCH_Z1 - PATCH_Z0)}
    layout["lamps"] = [((GATEHOUSE_X - 0.9, 5.3, gate_mid), 13.0, 2.2), ((-ARM_X + 1.2, 4.6, patch_mid), 10.0, 1.4)]


def vec(value):
    return "Vector3(%s)" % ", ".join(fmt(v) for v in value)


def fmt(value):
    text = "%.3f" % value
    text = text.rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def write_layout(layout, path):
    def points(entries):
        return "PackedVector3Array(%s)" % ", ".join(fmt(v) for position, _w in entries for v in position)

    def widths(entries):
        return "PackedFloat32Array(%s)" % ", ".join(fmt(w) for _p, w in entries)

    lines = ['[gd_resource type="Resource" script_class="LevelLayout" load_steps=2 format=3]', "",
             '[ext_resource type="Script" path="res://scripts/environment/level_layout.gd" id="1"]', "", "[resource]", 'script = ExtResource("1")']
    lines.append("mount_position = %s" % vec(layout["mount"]))
    lines.append("eye_position = %s" % vec(layout["eye"]))
    lines.append("court_half_width = %s" % fmt(ARM_X))
    routes = []
    for name, entries in layout["routes"].items():
        routes.append('"%s": {"points": %s, "widths": %s}' % (name, points(entries), widths(entries)))
    lines.append("routes = {%s}" % ", ".join(routes))
    mouths = []
    for name, (position, width) in layout["mouths"].items():
        mouths.append('"%s": {"position": %s, "width": %s}' % (name, vec(position), fmt(width)))
    lines.append("mouths = {%s}" % ", ".join(mouths))
    attack = []
    for name, line in layout["lines"].items():
        attack.append('"%s": {"a": %s, "b": %s, "normal": %s, "rows": %d, "spacing": %s, "target": "%s", "side": "%s", "priority": %d}' % (
            name, vec(line["a"]), vec(line["b"]), vec(line["normal"]), line["rows"], fmt(line["spacing"]), line["target"], line["side"],
            line["priority"]))
    lines.append("attack_lines = {%s}" % ", ".join(attack))
    breach = []
    for name, entries in layout["breach"].items():
        breach.append('"%s": {"points": %s, "widths": %s}' % (name, points(entries), widths(entries)))
    lines.append("breach_routes = {%s}" % ", ".join(breach))
    lines.append("gate_center = %s" % vec(layout["gate"]["center"]))
    lines.append("gate_size = %s" % vec(layout["gate"]["size"]))
    lines.append("patch_center = %s" % vec(layout["patch"]["center"]))
    lines.append("patch_size = %s" % vec(layout["patch"]["size"]))
    lines.append("fires = [%s]" % ", ".join('{"position": %s, "scale": %s}' % (vec(p), fmt(s)) for p, s in layout["fires"]))
    lines.append("smokes = [%s]" % ", ".join('{"position": %s, "scale": %s}' % (vec(p), fmt(s)) for p, s in layout["smokes"]))
    lines.append("lamps = [%s]" % ", ".join('{"position": %s, "range": %s, "energy": %s}' % (vec(p), fmt(r), fmt(e)) for p, r, e in layout["lamps"]))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def main():
    b = Builder(7)
    materials(b)
    layout = {"fires": [], "smokes": [], "scorch": [], "lamps": []}
    ground(b)
    fortress(b)
    props(b, layout)
    city(b, layout)
    gameplay(layout)
    bake(b, layout)
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    size, report = b.export(OUT_GLB, "CitySiege")
    write_layout(layout, OUT_LAYOUT)
    total = 0
    for name, triangles, surfaces in report:
        total += triangles
        print("  %-18s %6d triangles, %d surfaces" % (name, triangles, surfaces))
    print("city_siege.glb: %d triangles in %d chunks, %d collision triangles, %.0f KB" % (
        total, len(report), sum(len(i) for i in b.collision.indices), size / 1024.0))
    print("layout:", os.path.relpath(OUT_LAYOUT, PROJECT))


if __name__ == "__main__":
    main()
