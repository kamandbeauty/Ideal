#!/usr/bin/env python3
"""
T-Shirt Designer — procedural low-poly t-shirt GLB generator.

Generates a garment-style t-shirt mesh (front/back panels, sleeves, shoulder
strips, collar band) with a texture-atlas UV layout purpose-built for the
T-Shirt Designer plugin:

  Atlas 2048x2048 (canvas pixel space, origin top-left):
    FRONT        quadrant  x [0,1024)    y [0,1024)
    BACK         quadrant  x [1024,2048) y [0,1024)
    LEFT_SLEEVE  quadrant  x [0,1024)    y [1024,2048)
    RIGHT_SLEEVE quadrant  x [1024,2048) y [1024,2048)

Print areas are exact UV rectangles, so the JS texture compositor can paint
designs straight into the atlas and they wrap onto the 3D shirt.

Triangle winding is auto-oriented outward (radial from the garment axis, the
sleeve axis, or up for the shoulder strips), so normals always face away
from the body regardless of how the loops were written.

Outputs (into the directory given as argv[1]):
  classic-tshirt.glb          the model (materials: TD_Fabric / TD_Trim)
  classic-tshirt-preview.png  flat render (front view)
  manifest.json               print-area UV rects

Requires: numpy, Pillow  (pip install numpy pillow)
"""
from __future__ import annotations

import json
import math
import struct
import sys
import zlib
from pathlib import Path

import numpy as np

# ---------------------------------------------------------------- constants

H_MAX = 0.70          # pattern height domain for UV (meters)
W_UV = 0.26           # pattern half-width domain for UV (>= max body half width)
ATLAS = 2048

# Side outline (x>0), garment pattern space. Monotone in y for the seam part.
SIDE_KEYS = [(0.000, 0.235), (0.150, 0.228), (0.300, 0.222), (0.430, 0.205),
             (0.500, 0.198)]
UNDERARM = (0.198, 0.500)
SHOULDER_PT = (0.244, 0.662)
NECK_PT = (0.088, 0.678)
FRONT_DIP = (0.000, 0.612)
BACK_DIP = (0.000, 0.658)

# Cross-section depth (half-depth of body) and shape exponent by height.
DEPTH_KEYS = [(0.000, 0.092), (0.300, 0.100), (0.500, 0.092), (0.662, 0.048),
              (0.700, 0.042)]
POWER_KEYS = [(0.000, 0.7), (0.450, 0.7), (0.600, 1.8), (0.700, 3.2)]

SLEEVE_LEN = 0.225          # visible tube length (m)
SLEEVE_ROOT_TUCK = 0.05     # hidden inside body
SLEEVE_RV = (0.083, 0.068)  # vertical ring radius (root -> cuff)
SLEEVE_RH = (0.058, 0.050)  # horizontal ring radius (root -> cuff)
SLEEVE_K = 18               # radial segments
SLEEVE_RINGS = 12           # rings along the axis
SLEEVE_AXIS = (1.0, -0.70, 0.06)   # outward, dropped ~35deg, slight forward
SLEEVE_C0 = (0.208, 0.581, 0.000)  # root ring center

NCOL, NROW = 56, 64         # panel grid resolution

# Print areas in pattern space (meters) — front/back: x range + y range.
PRINT_FRONT = {"x": (-0.15, 0.15), "y": (0.22, 0.57)}
PRINT_BACK = {"x": (-0.15, 0.15), "y": (0.24, 0.59)}
SLEEVE_PRINT_U = (0.378, 0.622)   # u range around the outer face
SLEEVE_PRINT_T = (0.25, 0.95)     # fraction along the tube

QUAD = {  # quadrant origin (u0, v0) in glTF UV space
    "front": (0.0, 0.0), "back": (0.5, 0.0),
    "left_sleeve": (0.0, 0.5), "right_sleeve": (0.5, 0.5),
}


# ---------------------------------------------------------------- helpers

def lerp(a, b, t):
    return a + (b - a) * t


def piecewise(keys, y):
    """Piecewise evaluation (smoothstep between keys) of a [(y, value)]."""
    if y <= keys[0][0]:
        return keys[0][1]
    if y >= keys[-1][0]:
        return keys[-1][1]
    for (y0, v0), (y1, v1) in zip(keys, keys[1:]):
        if y0 <= y <= y1:
            t = 0 if y1 == y0 else (y - y0) / (y1 - y0)
            tt = t * t * (3 - 2 * t)
            return lerp(v0, v1, tt)
    return keys[-1][1]


def bezier2(p0, p1, p2, t):
    return ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])


# Armhole: concave bezier from underarm to shoulder point.
ARMHOLE_CTRL = (0.203, 0.588)
ARMHOLE_SAMPLES = [bezier2(UNDERARM, ARMHOLE_CTRL, SHOULDER_PT, t)
                   for t in np.linspace(0, 1, 64)]
# neck line quadratics (right half)
FRONT_NL_SAMPLES = [bezier2(NECK_PT, (0.045, 0.640), FRONT_DIP, t)
                    for t in np.linspace(0, 1, 48)]
BACK_NL_SAMPLES = [bezier2(NECK_PT, (0.045, 0.668), BACK_DIP, t)
                   for t in np.linspace(0, 1, 48)]


def armhole_x(y):
    """x of the armhole curve at height y (monotone in y)."""
    if y <= UNDERARM[1]:
        return UNDERARM[0]
    if y >= SHOULDER_PT[1]:
        return SHOULDER_PT[0]
    prev = ARMHOLE_SAMPLES[0]
    for cur in ARMHOLE_SAMPLES[1:]:
        if prev[1] <= y <= cur[1]:
            t = 0 if cur[1] == prev[1] else (y - prev[1]) / (cur[1] - prev[1])
            return lerp(prev[0], cur[0], t)
        prev = cur
    return SHOULDER_PT[0]


def side_x(y):
    """Half width of the body outline at height y."""
    if y <= UNDERARM[1]:
        prev = SIDE_KEYS[0]
        for cur in SIDE_KEYS[1:]:
            if prev[0] <= y <= cur[0]:
                t = (y - prev[0]) / (cur[0] - prev[0])
                return lerp(prev[1], cur[1], t)
            prev = cur
        return SIDE_KEYS[-1][1]
    if y <= SHOULDER_PT[1]:
        return armhole_x(y)
    if y <= NECK_PT[1]:  # shoulder line
        t = (y - SHOULDER_PT[1]) / (NECK_PT[1] - SHOULDER_PT[1])
        return lerp(SHOULDER_PT[0], NECK_PT[0], t)
    return 0.0  # above neck point: outside


def neckline_y(x, side):
    """Top edge height at |x|<=NECK_PT[0] for 'front' or 'back'."""
    ax = abs(x)
    if ax >= NECK_PT[0]:
        t = (ax - NECK_PT[0]) / (SHOULDER_PT[0] - NECK_PT[0])
        return lerp(NECK_PT[1], SHOULDER_PT[1], t)
    samples = FRONT_NL_SAMPLES if side == "front" else BACK_NL_SAMPLES
    prev = samples[0]
    for cur in samples[1:]:
        if prev[0] >= ax >= cur[0]:
            t = (prev[0] - ax) / (prev[0] - cur[0])
            return lerp(prev[1], cur[1], t)
        prev = cur
    return samples[-1][1]


def top_edge_y(x, side):
    return neckline_y(x, side)


def wrap_z(x, y, sign):
    """Cross-section wrap depth for a body point."""
    hw = side_x(y)
    ax = min(abs(x), hw)
    hw = max(hw, 1e-6)
    d = piecewise(DEPTH_KEYS, y)
    p = piecewise(POWER_KEYS, y)
    return sign * d * (1.0 - (ax / hw) ** 2) ** p


# ---------------------------------------------------------------- mesh utils

class Mesh:
    def __init__(self, name, material):
        self.name = name
        self.material = material
        self.pos = []
        self.uv = []
        self.idx = []
        self._cache = {}

    def vertex(self, p, uv):
        key = (round(p[0], 6), round(p[1], 6), round(p[2], 6),
               round(uv[0], 6), round(uv[1], 6))
        if key in self._cache:
            return self._cache[key]
        i = len(self.pos)
        self.pos.append((p[0], p[1], p[2]))
        self.uv.append((uv[0], uv[1]))
        self._cache[key] = i
        return i

    def quad(self, a, b, c, d):
        """Grid quad a=(r,i) b=(r,i+1) c=(r+1,i) d=(r+1,i+1)."""
        self.idx += [a, b, c, c, b, d]

    def orient(self, mode, point=None, direction=None):
        """Flip triangles so face normals point outward.

        mode 'radial_y'  : away from the vertical garment axis (x=0,z=0)
        mode 'radial'    : away from the line (point, direction)
        mode 'up'        : toward +y
        """
        pos = np.array(self.pos)
        idx = np.array(self.idx, dtype=np.int64).reshape(-1, 3)
        v0, v1, v2 = pos[idx[:, 0]], pos[idx[:, 1]], pos[idx[:, 2]]
        n = np.cross(v1 - v0, v2 - v0)
        cen = (v0 + v1 + v2) / 3.0
        if mode == "radial_y":
            ref = cen.copy()
            ref[:, 1] = 0
        elif mode == "radial":
            d = np.array(direction, dtype=np.float64)
            d /= np.linalg.norm(d)
            rel = cen - np.array(point, dtype=np.float64)
            ref = rel - np.outer(rel @ d, d)  # component away from the axis
        else:  # up
            ref = np.zeros_like(cen)
            ref[:, 1] = 1.0
        rl = np.linalg.norm(ref, axis=1)
        ok = rl < 1e-12
        ref[ok] = np.array([0.0, 1.0, 0.0])
        rl[ok] = 1.0
        ref /= rl[:, None]
        dot = np.einsum("ij,ij->i", n, ref)
        flip = dot < -1e-12
        idx[flip] = idx[flip][:, [0, 2, 1]]
        self.idx = idx.reshape(-1).tolist()

    def cull_and_normals(self, eps=1e-10):
        """Drop degenerate triangles, compute smooth vertex normals."""
        pos = np.array(self.pos, dtype=np.float64)
        idx = np.array(self.idx, dtype=np.int64).reshape(-1, 3)
        if len(idx) == 0:
            self.nrm = np.zeros((len(pos), 3))
            return
        v0, v1, v2 = pos[idx[:, 0]], pos[idx[:, 1]], pos[idx[:, 2]]
        n = np.cross(v1 - v0, v2 - v0)
        area = 0.5 * np.linalg.norm(n, axis=1)
        keep = area > eps
        idx = idx[keep]
        n = n[keep]
        n /= (np.linalg.norm(n, axis=1, keepdims=True) + 1e-30)
        self.idx = idx.reshape(-1).tolist()
        acc = np.zeros_like(pos)
        for k in range(3):
            np.add.at(acc, idx[:, k], n)
        norm = np.linalg.norm(acc, axis=1, keepdims=True)
        acc /= (norm + 1e-30)
        dead = (norm[:, 0] < 1e-9)
        if dead.any():
            acc[dead] = np.array([0.0, 1.0, 0.0])
        self.nrm = acc


def build_panel(side):
    """Front or back body panel as a clamped grid (pattern-cut technique)."""
    sign = 1.0 if side == "front" else -1.0
    qu, qv = QUAD[side]
    m = Mesh(f"Body_{side}", 0)
    xs = np.linspace(-W_UV, W_UV, NCOL)
    ys = np.linspace(0.0, H_MAX, NROW)
    vid = np.zeros((NROW, NCOL), dtype=np.int64)
    for j, y in enumerate(ys):
        for i, x in enumerate(xs):
            hw = side_x(y)
            cx = min(max(x, -hw), hw)
            ty = top_edge_y(cx, side)
            cy = min(y, ty, H_MAX)
            cy = max(cy, 0.0)
            p = (cx, cy, wrap_z(cx, cy, sign))
            u = qu + ((x + W_UV) / (2 * W_UV)) * 0.5
            v = qv + (1.0 - y / H_MAX) * 0.5
            vid[j, i] = m.vertex(p, (u, v))
    for j in range(NROW - 1):
        for i in range(NCOL - 1):
            a, b = vid[j, i], vid[j, i + 1]
            c, d = vid[j + 1, i], vid[j + 1, i + 1]
            pa, pb = m.pos[a], m.pos[b]
            pc, pd = m.pos[c], m.pos[d]
            if (abs(pa[0] - pb[0]) < 1e-6 and abs(pa[1] - pb[1]) < 1e-6 and
                    abs(pc[0] - pd[0]) < 1e-6 and abs(pc[1] - pd[1]) < 1e-6):
                continue
            m.quad(a, b, c, d)
    m.orient("radial_y")
    m.cull_and_normals()
    return m


def _sleeve_rings():
    """Ring points + uvs of the RIGHT sleeve, root -> cuff."""
    axis = np.array(SLEEVE_AXIS, dtype=np.float64)
    axis /= np.linalg.norm(axis)
    c0 = np.array(SLEEVE_C0, dtype=np.float64)
    up = np.array([0.0, 1.0, 0.0])
    e1 = up - axis * np.dot(up, axis)
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(axis, e1)
    total = SLEEVE_LEN + SLEEVE_ROOT_TUCK
    rings = []
    for r in range(SLEEVE_RINGS + 1):
        t = r / SLEEVE_RINGS
        s = t * total - SLEEVE_ROOT_TUCK
        ease = 0.5 - 0.5 * math.cos(math.pi * t)
        rv = lerp(SLEEVE_RV[0], SLEEVE_RV[1], ease)
        rh = lerp(SLEEVE_RH[0], SLEEVE_RH[1], ease)
        center = c0 + axis * s - e1 * (0.012 * t * t)
        pts, uvs = [], []
        for k in range(SLEEVE_K):
            theta = 2 * math.pi * k / SLEEVE_K
            p = center + e1 * (rv * math.cos(theta)) + e2 * (rh * math.sin(theta))
            u_raw = ((theta + math.pi) % (2 * math.pi)) / (2 * math.pi)
            pts.append(p)
            uvs.append((u_raw, t))
        rings.append((pts, uvs))
    return rings, c0, axis


def build_sleeve(side):
    """Right sleeve built directly; left is a mirrored copy."""
    qu, qv = QUAD[f"{side}_sleeve"]
    m = Mesh(f"Sleeve_{side}", 0)
    rings, c0, axis = _sleeve_rings()
    mirror = (side == "left")
    if mirror:
        c0 = (-c0[0], c0[1], c0[2])
        axis = (-axis[0], axis[1], axis[2])
    ids = []
    for pts, uvs in rings:
        row = []
        for p, (u_raw, t) in zip(pts, uvs):
            if mirror:
                p = (-p[0], p[1], p[2])
                u_raw = 1.0 - u_raw
            u = qu + u_raw * 0.5
            v = qv + t * 0.5
            row.append(m.vertex(p, (u, v)))
        ids.append(row)
    for r in range(SLEEVE_RINGS):
        a, b = ids[r], ids[r + 1]
        for k in range(SLEEVE_K):
            k2 = (k + 1) % SLEEVE_K
            m.quad(a[k], a[k2], b[k], b[k2])
    m.orient("radial", point=c0, direction=axis)
    m.cull_and_normals()
    return m


def build_shoulder_strips():
    """Close the gap between front/back panels along each shoulder seam."""
    m = Mesh("Shoulder", 1)
    for mirror in (1.0, -1.0):
        n = 14
        rows = []
        for rr in range(3):  # front edge / ridge / back edge
            row = []
            for i in range(n):
                t = i / (n - 1)
                x = lerp(NECK_PT[0], SHOULDER_PT[0], t)
                yf = top_edge_y(x, "front")
                yb = top_edge_y(x, "back")
                zf = wrap_z(x, yf, 1.0)
                zb = wrap_z(x, yb, -1.0)
                y = lerp(yf, yb, rr / 2)
                z = lerp(zf, zb, rr / 2)
                if rr == 1:
                    y += 0.010  # ridge
                row.append(m.vertex((x * mirror, y, z), (0.0, 0.0)))
            rows.append(row)
        for i in range(n - 1):
            for rr in range(2):
                m.quad(rows[rr][i], rows[rr][i + 1],
                       rows[rr + 1][i], rows[rr + 1][i + 1])
    m.orient("up")
    m.cull_and_normals()
    return m


def build_collar():
    """Ribbed collar band following the neckline ring."""
    m = Mesh("Collar", 1)
    n = 44

    def nl_point(s, side, direction=1.0):
        """s 0..1 across an arc; direction +1: +neck -> -neck, -1: reverse."""
        ax = NECK_PT[0] * (1.0 - 2.0 * s) * direction
        y = neckline_y(abs(ax), side)
        sign = 1.0 if side == "front" else -1.0
        z = wrap_z(ax, y, sign)
        return np.array([ax, y, z])

    ring = [nl_point(i / (n - 1), "front") for i in range(n)]
    # back arc continues around: x from -neck back to +neck
    ring += [nl_point(i / (n - 1), "back", -1.0) for i in range(1, n - 1)]
    ring = np.array(ring)
    outward = ring.copy()
    outward[:, 1] = 0
    ol = np.linalg.norm(outward, axis=1, keepdims=True)
    outward = outward / (ol + 1e-9)
    up = np.array([0.0, 1.0, 0.0])
    lifts = [(0.000, 0.002), (0.004, 0.014), (0.006, 0.026)]
    rows = []
    for off, lift in lifts:
        row = []
        for i, p in enumerate(ring):
            q = p + outward[i] * off + up * lift
            row.append(m.vertex(tuple(q), (0.0, 0.0)))
        rows.append(row)
    cnt = len(ring)
    for rr in range(2):
        for i in range(cnt):
            i2 = (i + 1) % cnt
            m.quad(rows[rr][i], rows[rr][i2],
                   rows[rr + 1][i], rows[rr + 1][i2])
    m.orient("radial_y")
    m.cull_and_normals()
    return m


# ---------------------------------------------------------------- UV rects

def panel_uv_rect(side, x_range, y_range):
    qu, qv = QUAD[side]
    u0 = qu + ((x_range[0] + W_UV) / (2 * W_UV)) * 0.5
    u1 = qu + ((x_range[1] + W_UV) / (2 * W_UV)) * 0.5
    v0 = qv + (1.0 - y_range[1] / H_MAX) * 0.5   # top edge -> smaller v
    v1 = qv + (1.0 - y_range[0] / H_MAX) * 0.5   # bottom edge -> larger v
    return [round(u0, 5), round(v0, 5), round(u1, 5), round(v1, 5)]


def sleeve_uv_rect(side, u_range, t_range):
    qu, qv = QUAD[f"{side}_sleeve"]
    return [round(qu + u_range[0] * 0.5, 5), round(qv + t_range[0] * 0.5, 5),
            round(qu + u_range[1] * 0.5, 5), round(qv + t_range[1] * 0.5, 5)]


# ---------------------------------------------------------------- GLB writer

def make_png(w, h, rgb_fn):
    """Tiny pure-python PNG writer (RGBA, 8-bit)."""
    rows = []
    for y in range(h):
        row = bytearray([0])
        for x in range(w):
            r, g, b, a = rgb_fn(x / (w - 1), y / (h - 1))
            row += bytes((r, g, b, a))
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
            chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def write_glb(path, meshes, png_bytes):
    """Assemble meshes (with pos/nrm/uv/idx) into a GLB 2.0 file."""
    accessors = []
    buffer_views = []
    bin_chunks = []
    offset = 0

    def add_view(data, target=None):
        nonlocal offset
        pad = (4 - len(data) % 4) % 4
        buffer_views.append({"buffer": 0, "byteOffset": offset,
                             "byteLength": len(data)})
        if target:
            buffer_views[-1]["target"] = target
        bin_chunks.append(data + b"\x00" * pad)
        offset += len(data) + pad
        return len(buffer_views) - 1

    def add_accessor_f32(arr, atype, count, mins=None, maxs=None):
        data = arr.astype("<f4").tobytes()
        view = add_view(data, 34962)
        acc = {"bufferView": view, "componentType": 5126, "count": count,
               "type": atype}
        if mins is not None:
            acc["min"] = [round(float(v), 6) for v in mins]
            acc["max"] = [round(float(v), 6) for v in maxs]
        accessors.append(acc)
        return len(accessors) - 1

    def add_accessor_u32(arr):
        data = np.asarray(arr, dtype="<u4").tobytes()
        view = add_view(data, 34963)
        accessors.append({"bufferView": view, "componentType": 5125,
                          "count": len(arr), "type": "SCALAR"})
        return len(accessors) - 1

    prims = []
    for m in meshes:
        pos = np.array(m.pos, dtype=np.float64)
        nrm = np.array(m.nrm, dtype=np.float64)
        uv = np.array(m.uv, dtype=np.float64)
        idx = np.array(m.idx, dtype=np.int64)
        pacc = add_accessor_f32(pos, "VEC3", len(pos), pos.min(0), pos.max(0))
        nacc = add_accessor_f32(nrm, "VEC3", len(nrm))
        uacc = add_accessor_f32(uv, "VEC2", len(uv))
        iacc = add_accessor_u32(idx)
        prims.append({"attributes": {"POSITION": pacc, "NORMAL": nacc,
                                     "TEXCOORD_0": uacc},
                      "indices": iacc, "material": m.material})

    img_view = add_view(png_bytes)
    bin_data = b"".join(bin_chunks)

    nodes = [{"mesh": i, "name": "TShirt_" + m.name} for i, m in
             enumerate(meshes)]
    gltf_meshes = [{"name": m.name, "primitives": [prims[i]]}
                   for i, m in enumerate(meshes)]

    gltf = {
        "asset": {"version": "2.0",
                  "generator": "tshirt-designer procedural generator"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes))), "name": "Scene"}],
        "nodes": nodes,
        "meshes": gltf_meshes,
        "materials": [
            {"name": "TD_Fabric", "doubleSided": True,
             "pbrMetallicRoughness": {
                 "baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0,
                 "roughnessFactor": 0.92,
                 "baseColorTexture": {"index": 0}}},
            {"name": "TD_Trim", "doubleSided": True,
             "pbrMetallicRoughness": {
                 "baseColorFactor": [0.93, 0.93, 0.93, 1],
                 "metallicFactor": 0.0, "roughnessFactor": 0.85}},
        ],
        "textures": [{"sampler": 0, "source": 0}],
        "images": [{"bufferView": img_view, "mimeType": "image/png"}],
        "samplers": [{"magFilter": 9729, "minFilter": 9987,
                      "wrapS": 33071, "wrapT": 33071}],
        "accessors": accessors,
        "bufferViews": buffer_views,
        "buffers": [{"byteLength": len(bin_data)}],
    }

    json_data = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_data += b" " * ((4 - len(json_data) % 4) % 4)
    total = 12 + 8 + len(json_data) + 8 + len(bin_data)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))  # 'glTF', v2
        f.write(struct.pack("<II", len(json_data), 0x4E4F534A))   # JSON
        f.write(json_data)
        f.write(struct.pack("<II", len(bin_data), 0x004E4942))    # BIN
        f.write(bin_data)


# ---------------------------------------------------------------- renderer

def render_meshes(meshes, eye, target, up, fov_deg, w, h, light_dirs,
                  out_path, uv_color=None):
    """Minimal numpy software rasterizer (validation renders)."""
    eye, target, up = (np.array(v, dtype=np.float64) for v in (eye, target, up))
    fz = target - eye
    fz /= np.linalg.norm(fz)
    fx = np.cross(fz, up)
    fx /= np.linalg.norm(fx)
    fy = np.cross(fx, fz)
    focal = (w / 2) / math.tan(math.radians(fov_deg) / 2)

    color = np.zeros((h, w, 3), dtype=np.float64)
    zbuf = np.full((h, w), 1e9)

    for m in meshes:
        pos = np.array(m.pos)
        nrm = np.array(m.nrm)
        uv = np.array(m.uv)
        idx = np.array(m.idx, dtype=np.int64).reshape(-1, 3)
        if uv_color is not None:
            base = None  # per-vertex colors supplied
            vcolors = np.array([uv_color(u, v) for u, v in uv],
                               dtype=np.float64) / 255.0
        else:
            base = np.array([0.85, 0.85, 0.88]) if m.material else \
                np.array([0.95, 0.95, 0.97])
            vcolors = None
        cam = pos - eye
        zc = cam @ fz
        xc = cam @ fx
        yc = cam @ fy
        with np.errstate(divide="ignore", invalid="ignore"):
            sx = (xc / zc * focal + w / 2).astype(np.int64)
            sy = (-yc / zc * focal + h / 2).astype(np.int64)
        for tri in idx:
            i0, i1, i2 = tri
            if min(zc[i0], zc[i1], zc[i2]) <= 0.05:
                continue
            xs = np.array([sx[i0], sx[i1], sx[i2]])
            ys = np.array([sy[i0], sy[i1], sy[i2]])
            minx, maxx = max(int(xs.min()), 0), min(int(xs.max()), w - 1)
            miny, maxy = max(int(ys.min()), 0), min(int(ys.max()), h - 1)
            if minx > maxx or miny > maxy:
                continue
            denom = ((xs[1] - xs[0]) * (ys[2] - ys[0]) -
                     (xs[2] - xs[0]) * (ys[1] - ys[0]))
            if abs(denom) < 1e-9:
                continue
            gy, gx = np.mgrid[miny:maxy + 1, minx:maxx + 1]
            gy, gx = gy + 0.5, gx + 0.5
            w0 = ((xs[1] - gx) * (ys[2] - gy) -
                  (xs[2] - gx) * (ys[1] - gy)) / denom
            w1 = ((xs[2] - gx) * (ys[0] - gy) -
                  (xs[0] - gx) * (ys[2] - gy)) / denom
            w2 = 1.0 - w0 - w1
            inside = (w0 >= -1e-9) & (w1 >= -1e-9) & (w2 >= -1e-9)
            if not inside.any():
                continue
            sub = (slice(miny, maxy + 1), slice(minx, maxx + 1))
            zregion = zbuf[sub]
            z = w0 * zc[i0] + w1 * zc[i1] + w2 * zc[i2]
            draw = inside & (z < zregion)
            if not draw.any():
                continue
            n = (w0[..., None] * nrm[i0] + w1[..., None] * nrm[i1] +
                 w2[..., None] * nrm[i2])
            n /= (np.linalg.norm(n, axis=-1, keepdims=True) + 1e-30)
            l1 = np.maximum(0.0, n @ light_dirs[0])
            l2 = np.maximum(0.0, n @ light_dirs[1])
            lit = 0.30 + 0.45 * l1 + 0.25 * l2
            if vcolors is not None:
                c = (w0[..., None] * vcolors[i0] + w1[..., None] * vcolors[i1]
                     + w2[..., None] * vcolors[i2]) * lit[..., None]
            else:
                c = base[None, None, :] * lit[..., None]
            tmp = color[sub]
            mask3 = draw[..., None]
            color[sub] = tmp * (~mask3) + c * mask3
            zbuf[sub] = np.where(draw, z, zregion)

    img = np.clip(color, 0, 1)
    img = (img * 255).astype(np.uint8)
    try:
        from PIL import Image
        bg = np.zeros((h, w, 3), dtype=np.float64)
        t = np.linspace(0, 1, h)[:, None, None]
        bg = 245 - 14 * t  # subtle vertical gradient
        img = (bg * (zbuf[:, :, None] >= 1e9) +
               img * (zbuf[:, :, None] < 1e9)).astype(np.uint8)
        Image.fromarray(img).save(out_path)
    except ImportError:
        with open(str(out_path).rsplit(".", 1)[0] + ".ppm", "wb") as fh:
            fh.write(b"P6\n%d %d\n255\n" % (w, h))
            fh.write(img[::-1].tobytes())


# ---------------------------------------------------------------- main

PRINT_RECTS = {}


def white_texture(u, v):
    return (255, 255, 255, 255)


def debug_texture(u, v):
    """Atlas with quadrant tints + print-area rectangles (validation)."""
    x, y = u * ATLAS, v * ATLAS
    if y < ATLAS // 2:
        base = (235, 238, 245) if x < ATLAS // 2 else (228, 233, 244)
    else:
        base = (238, 235, 245) if x < ATLAS // 2 else (233, 238, 240)
    for a in PRINT_RECTS.values():
        u0, v0, u1, v1 = a["uv_rect"]
        px0, py0, px1, py1 = u0 * ATLAS, v0 * ATLAS, u1 * ATLAS, v1 * ATLAS
        if px0 <= x <= px1 and py0 <= y <= py1:
            return (255, 120, 120, 255)
    return base + (255,)


def main():
    global PRINT_RECTS
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    out_dir.mkdir(parents=True, exist_ok=True)

    front = build_panel("front")
    back = build_panel("back")
    sleeve_l = build_sleeve("left")
    sleeve_r = build_sleeve("right")
    shoulder = build_shoulder_strips()
    collar = build_collar()

    PRINT_RECTS = {
        "front": {"uv_rect": panel_uv_rect("front", PRINT_FRONT["x"],
                                           PRINT_FRONT["y"]),
                  "max_width_cm": 30, "max_height_cm": 35},
        "back": {"uv_rect": panel_uv_rect("back", PRINT_BACK["x"],
                                          PRINT_BACK["y"]),
                 "max_width_cm": 30, "max_height_cm": 35},
        "left_sleeve": {"uv_rect": sleeve_uv_rect("left", SLEEVE_PRINT_U,
                                                  SLEEVE_PRINT_T),
                        "max_width_cm": 10, "max_height_cm": 20},
        "right_sleeve": {"uv_rect": sleeve_uv_rect("right", SLEEVE_PRINT_U,
                                                   SLEEVE_PRINT_T),
                         "max_width_cm": 10, "max_height_cm": 20},
    }

    body = [front, back, sleeve_l, sleeve_r]
    trim = [shoulder, collar]
    meshes = body + trim

    tex = make_png(256, 256, debug_texture)
    glb_path = out_dir / "classic-tshirt.glb"
    write_glb(glb_path, meshes, tex)

    manifest = {
        "model": "classic-tshirt",
        "atlas": ATLAS,
        "print_areas": PRINT_RECTS,
        "camera": {"target_y": 0.36, "distance": 1.6},
        "triangles": sum(len(m.idx) // 3 for m in meshes),
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2))

    # validation renders (quadrant-coded colors, print areas highlighted)
    l1 = np.array([0.4, 0.75, 0.55]); l1 /= np.linalg.norm(l1)
    l2 = np.array([-0.5, 0.4, 0.7]); l2 /= np.linalg.norm(l2)

    def qc(u, v):
        if v < 0.5:
            base = (210, 70, 70) if u < 0.5 else (70, 100, 220)
        else:
            base = (80, 180, 90) if u < 0.5 else (190, 130, 50)
        for a in PRINT_RECTS.values():
            u0, v0, u1, v1 = a["uv_rect"]
            if u0 <= u <= u1 and v0 <= v <= v1:
                return (250, 250, 70)
        return base

    render_meshes(meshes, eye=(0.0, 0.42, 1.75), target=(0.0, 0.36, 0.0),
                  up=(0, 1, 0), fov_deg=34, w=520, h=640,
                  light_dirs=(l1, l2), out_path=out_dir / "render-front.png",
                  uv_color=qc)
    render_meshes(meshes, eye=(0.0, 0.42, -1.75), target=(0.0, 0.36, 0.0),
                  up=(0, 1, 0), fov_deg=34, w=520, h=640,
                  light_dirs=(l1, l2), out_path=out_dir / "render-back.png",
                  uv_color=qc)
    render_meshes(meshes, eye=(1.3, 0.55, 1.15), target=(0.0, 0.36, 0.0),
                  up=(0, 1, 0), fov_deg=34, w=640, h=640,
                  light_dirs=(l1, l2), out_path=out_dir / "render-34.png",
                  uv_color=qc)
    # clean white preview for the plugin's model thumbnail
    render_meshes(meshes, eye=(0.0, 0.44, 1.65), target=(0.0, 0.36, 0.0),
                  up=(0, 1, 0), fov_deg=33, w=480, h=600,
                  light_dirs=(l1, l2), out_path=out_dir / "preview.png")

    print(f"GLB written: {glb_path} ({glb_path.stat().st_size/1024:.0f} KB)")
    print(f"triangles: {manifest['triangles']}")
    print(json.dumps(PRINT_RECTS, indent=2))


if __name__ == "__main__":
    main()
