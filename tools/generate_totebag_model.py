#!/usr/bin/env python3
"""
Custom Product Designer — procedural tote bag GLB generator.

Builds a canvas tote bag (front/back panels with a soft cross-section, two
gussets, a bottom, and two strap loops) with a texture-atlas UV layout that
matches the plugin's compositor:

  Atlas 2048x2048 (canvas pixel space, origin top-left):
    FRONT quadrant  x [0,1024)    y [0,1024)
    BACK  quadrant  x [1024,2048) y [0,1024)
    (bottom half is used by the gussets/bottom/straps trim UVs)

Print areas are exact UV rectangles inside the front/back quadrants, so the
JS compositor can paint designs straight into the atlas and they wrap onto
the real 3D surface (no UI overlay fakery).

Outputs (into the directory given as argv[1]):
  classic-tote.glb    the model (materials: TD_Fabric / TD_Trim)
  preview.png         flat render used as the model thumbnail
  manifest.json       print-area UV rects

Requires: numpy  (Pillow not needed; PNGs are written by the shared writer)
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from generate_tshirt_model import (  # noqa: E402  (shared, already validated)
    ATLAS,
    Mesh,
    make_png,
    render_meshes,
    write_glb,
)

# ---------------------------------------------------------------- geometry

BAG_W = 0.175        # half width  (m)  -> 35 cm wide
BAG_H = 0.20          # half height (m)  -> 40 cm tall body
BAG_D = 0.055         # half depth  (m)  -> 11 cm gusset
Y0 = 0.0              # bottom of the bag body
Y1 = 2 * BAG_H        # top opening

NU = 26               # horizontal segments across a panel
NV = 30               # vertical segments up a panel
ND = 6                # segments across a gusset

STRAP_W = 0.016       # strap half width
STRAP_T = 0.004       # strap half thickness
STRAP_X = 0.085       # strap anchor offset from center
STRAP_RISE = 0.135    # how high the strap arcs above the opening
NS = 26               # strap segments

# UV quadrant boxes (u0, v0, u1, v1) in 0..1 atlas space.
QUAD = {
    "front": (0.0, 0.0, 0.5, 0.5),
    "back": (0.5, 0.0, 1.0, 0.5),
    "trim": (0.0, 0.5, 1.0, 1.0),
}

# Print window as a fraction of the panel pattern (x from center, y from bottom).
# 30x35 cm inside a 38x40 cm panel, sitting slightly above center.
PRINT_W_CM = 28.0
PRINT_H_CM = 32.0
PANEL_W_CM = 35.0
PANEL_H_CM = 40.0
PRINT_BOTTOM_CM = 4.0   # gap from the bag bottom to the print window


def panel_profile(t):
    """Half-width multiplier up the panel (slightly tapered bottom)."""
    return 0.94 + 0.06 * min(1.0, t * 3.0)


def panel_bulge(t):
    """How far the panel bows outward (fraction of BAG_D) at height t."""
    return 0.55 + 0.45 * math.sin(math.pi * min(1.0, max(0.0, t)) ** 0.9)


def panel_point(side, u, v):
    """Point on the front (+z) or back (-z) panel. u,v in [0,1]."""
    sign = 1.0 if side == "front" else -1.0
    x = (u * 2.0 - 1.0) * BAG_W * panel_profile(v)
    y = Y0 + v * (Y1 - Y0)
    # Bow the panel out; flatten it near the rim and the floor.
    edge = 1.0 - abs(u * 2.0 - 1.0) ** 2.4
    z = sign * BAG_D * panel_bulge(v) * edge
    return (x, y, z)


def uv_in(quad, s, t):
    u0, v0, u1, v1 = QUAD[quad]
    return (u0 + s * (u1 - u0), v0 + t * (v1 - v0))


def build_panel(side):
    """Front/back panel grid. UV: s across the panel, t down from the rim."""
    m = Mesh(side, 0)
    quad = "front" if side == "front" else "back"
    grid = []
    for iv in range(NV + 1):
        v = iv / NV
        row = []
        for iu in range(NU + 1):
            u = iu / NU
            # Mirror the back panel horizontally so its texture reads correctly
            # from outside the bag.
            s = u if side == "front" else 1.0 - u
            p = panel_point(side, u, v)
            row.append(m.vertex(p, uv_in(quad, s, 1.0 - v)))
        grid.append(row)
    for iv in range(NV):
        for iu in range(NU):
            m.quad(grid[iv][iu], grid[iv][iu + 1],
                   grid[iv + 1][iu], grid[iv + 1][iu + 1])
    m.orient("radial_y")
    m.cull_and_normals()
    return m


def build_gusset(sign):
    """Side wall connecting the front and back panel edges (sign = +/-1 x)."""
    m = Mesh("gusset_%s" % ("r" if sign > 0 else "l"), 1)
    grid = []
    for iv in range(NV + 1):
        v = iv / NV
        u_edge = 1.0 if sign > 0 else 0.0
        pf = np.array(panel_point("front", u_edge, v))
        pb = np.array(panel_point("back", u_edge, v))
        row = []
        for j in range(ND + 1):
            t = j / ND
            p = pf * (1.0 - t) + pb * t
            # Push the wall outward a touch so the bag is not a flat slab.
            p[0] += sign * BAG_D * 0.30 * math.sin(math.pi * t) * panel_bulge(v)
            row.append(m.vertex(tuple(p), uv_in("trim", 0.05 + 0.20 * t,
                                                0.10 + 0.80 * (1.0 - v))))
        grid.append(row)
    for iv in range(NV):
        for j in range(ND):
            m.quad(grid[iv][j], grid[iv][j + 1],
                   grid[iv + 1][j], grid[iv + 1][j + 1])
    m.orient("radial_y")
    m.cull_and_normals()
    return m


def build_bottom():
    m = Mesh("bottom", 1)
    grid = []
    for iu in range(NU + 1):
        u = iu / NU
        pf = np.array(panel_point("front", u, 0.0))
        pb = np.array(panel_point("back", u, 0.0))
        row = []
        for j in range(ND + 1):
            t = j / ND
            p = pf * (1.0 - t) + pb * t
            row.append(m.vertex(tuple(p), uv_in("trim", 0.30 + 0.25 * u,
                                                0.10 + 0.25 * t)))
        grid.append(row)
    for iu in range(NU):
        for j in range(ND):
            m.quad(grid[iu][j], grid[iu][j + 1],
                   grid[iu + 1][j], grid[iu + 1][j + 1])
    # Bottom faces down.
    pos = np.array(m.pos)
    idx = np.array(m.idx, dtype=np.int64).reshape(-1, 3)
    v0, v1, v2 = pos[idx[:, 0]], pos[idx[:, 1]], pos[idx[:, 2]]
    n = np.cross(v1 - v0, v2 - v0)
    flip = n[:, 1] > 0
    idx[flip] = idx[flip][:, [0, 2, 1]]
    m.idx = idx.reshape(-1).tolist()
    m.cull_and_normals()
    return m


def build_rim():
    """Thin band closing the top opening between the two panels."""
    m = Mesh("rim", 1)
    grid = []
    for iu in range(NU + 1):
        u = iu / NU
        pf = np.array(panel_point("front", u, 1.0))
        pb = np.array(panel_point("back", u, 1.0))
        row = []
        for j in range(ND + 1):
            t = j / ND
            p = pf * (1.0 - t) + pb * t
            row.append(m.vertex(tuple(p), uv_in("trim", 0.60 + 0.20 * u,
                                                0.10 + 0.15 * t)))
        grid.append(row)
    for iu in range(NU):
        for j in range(ND):
            m.quad(grid[iu][j], grid[iu][j + 1],
                   grid[iu + 1][j], grid[iu + 1][j + 1])
    m.orient("up")
    m.cull_and_normals()
    return m


def build_strap(side):
    """One arcing handle over the opening, as a flat ribbon."""
    sign = 1.0 if side == "front" else -1.0
    m = Mesh("strap_%s" % side, 1)
    z_anchor = sign * BAG_D * panel_bulge(1.0) * 0.55

    def center(t):
        # Catenary-ish arc between the two anchors.
        x = (-STRAP_X) + t * (2 * STRAP_X)
        arc = math.sin(math.pi * t)
        y = Y1 - 0.005 + STRAP_RISE * arc
        z = z_anchor * (1.0 - 0.35 * arc)
        return np.array([x, y, z])

    rows = []
    for i in range(NS + 1):
        t = i / NS
        c = center(t)
        nxt = center(min(1.0, t + 1e-3)) - center(max(0.0, t - 1e-3))
        tangent = nxt / (np.linalg.norm(nxt) + 1e-12)
        # Ribbon width runs along z (across the bag), thickness along the normal.
        wdir = np.array([0.0, 0.0, 1.0])
        ndir = np.cross(wdir, tangent)
        ndir /= (np.linalg.norm(ndir) + 1e-12)
        ring = []
        corners = [
            (+STRAP_W, +STRAP_T), (+STRAP_W, -STRAP_T),
            (-STRAP_W, -STRAP_T), (-STRAP_W, +STRAP_T),
        ]
        for k, (a, b) in enumerate(corners):
            p = c + wdir * a + ndir * b
            ring.append(m.vertex(tuple(p),
                                 uv_in("trim", 0.82 + 0.04 * (k / 3.0),
                                       0.10 + 0.80 * t)))
        rows.append(ring)
    for i in range(NS):
        for k in range(4):
            k2 = (k + 1) % 4
            m.quad(rows[i][k], rows[i][k2], rows[i + 1][k], rows[i + 1][k2])
    m.orient("radial", point=(0.0, Y1, z_anchor), direction=(1.0, 0.0, 0.0))
    m.cull_and_normals()
    return m


# ---------------------------------------------------------------- UV rects

def print_uv_rect(side):
    """Exact atlas rectangle of the printable window on a panel."""
    half_w_frac = (PRINT_W_CM / PANEL_W_CM)          # fraction of panel width
    s0 = 0.5 - half_w_frac / 2.0
    s1 = 0.5 + half_w_frac / 2.0

    # v runs top->bottom in the atlas; the panel's t=0 is the rim.
    top_cm = PANEL_H_CM - PRINT_BOTTOM_CM - PRINT_H_CM
    t0 = top_cm / PANEL_H_CM
    t1 = (top_cm + PRINT_H_CM) / PANEL_H_CM

    u0, v0 = uv_in("front" if side == "front" else "back", s0, t0)
    u1, v1 = uv_in("front" if side == "front" else "back", s1, t1)
    return [round(min(u0, u1), 5), round(min(v0, v1), 5),
            round(max(u0, u1), 5), round(max(v0, v1), 5)]


# ---------------------------------------------------------------- main

PRINT_RECTS = {}


def debug_texture(u, v):
    x, y = u, v
    if y < 0.5:
        base = (236, 233, 226) if x < 0.5 else (230, 228, 220)
    else:
        base = (214, 205, 190)
    for a in PRINT_RECTS.values():
        u0, v0, u1, v1 = a["uv_rect"]
        if u0 <= x <= u1 and v0 <= y <= v1:
            return (255, 130, 120, 255)
    return base + (255,)


def main():
    global PRINT_RECTS
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    out_dir.mkdir(parents=True, exist_ok=True)

    meshes = [
        build_panel("front"),
        build_panel("back"),
        build_gusset(+1),
        build_gusset(-1),
        build_bottom(),
        build_rim(),
        build_strap("front"),
        build_strap("back"),
    ]

    PRINT_RECTS = {
        "front": {"uv_rect": print_uv_rect("front"),
                  "max_width_cm": PRINT_W_CM, "max_height_cm": PRINT_H_CM},
        "back": {"uv_rect": print_uv_rect("back"),
                 "max_width_cm": PRINT_W_CM, "max_height_cm": PRINT_H_CM},
    }

    tex = make_png(256, 256, debug_texture)
    glb_path = out_dir / "classic-tote.glb"
    write_glb(glb_path, meshes, tex)

    manifest = {
        "model": "classic-tote",
        "product_type": "totebag",
        "atlas": ATLAS,
        "print_areas": PRINT_RECTS,
        "camera": {"target_y": 0.20, "distance": 1.15},
        "triangles": sum(len(m.idx) // 3 for m in meshes),
        "bounds": {
            "x": [round(float(min(p[0] for m in meshes for p in m.pos)), 4),
                  round(float(max(p[0] for m in meshes for p in m.pos)), 4)],
            "y": [round(float(min(p[1] for m in meshes for p in m.pos)), 4),
                  round(float(max(p[1] for m in meshes for p in m.pos)), 4)],
            "z": [round(float(min(p[2] for m in meshes for p in m.pos)), 4),
                  round(float(max(p[2] for m in meshes for p in m.pos)), 4)],
        },
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2))

    l1 = np.array([0.4, 0.75, 0.55]); l1 /= np.linalg.norm(l1)
    l2 = np.array([-0.5, 0.4, 0.7]); l2 /= np.linalg.norm(l2)

    def qc(u, v):
        if v < 0.5:
            base = (205, 80, 80) if u < 0.5 else (80, 110, 210)
        else:
            base = (150, 140, 120)
        for a in PRINT_RECTS.values():
            u0, v0, u1, v1 = a["uv_rect"]
            if u0 <= u <= u1 and v0 <= v <= v1:
                return (250, 245, 80)
        return base

    render_meshes(meshes, eye=(0.0, 0.24, 0.95), target=(0.0, 0.20, 0.0),
                  up=(0, 1, 0), fov_deg=36, w=520, h=620,
                  light_dirs=(l1, l2), out_path=out_dir / "render-front.png",
                  uv_color=qc)
    render_meshes(meshes, eye=(0.0, 0.24, -0.95), target=(0.0, 0.20, 0.0),
                  up=(0, 1, 0), fov_deg=36, w=520, h=620,
                  light_dirs=(l1, l2), out_path=out_dir / "render-back.png",
                  uv_color=qc)
    render_meshes(meshes, eye=(0.0, 0.26, 0.92), target=(0.0, 0.20, 0.0),
                  up=(0, 1, 0), fov_deg=35, w=480, h=600,
                  light_dirs=(l1, l2), out_path=out_dir / "preview.png")

    print(f"GLB written: {glb_path} ({glb_path.stat().st_size/1024:.0f} KB)")
    print(f"triangles: {manifest['triangles']}")
    print(json.dumps(manifest["print_areas"], indent=2))
    print(json.dumps(manifest["bounds"], indent=2))


if __name__ == "__main__":
    main()
