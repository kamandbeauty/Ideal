#!/usr/bin/env python3
"""
Numeric validation of the generated t-shirt GLB.

1. Parses the GLB, checks glTF structure, accessor/bufferView integrity.
2. Normal orientation: every part must face outward.
3. UV-rect -> 3D mapping: every print-area rectangle must land on the
   expected region of the garment (front chest, back, upper-outer sleeve).
4. Renders silhouette views with quadrant-coded colors and analyses pixels
   (coverage, symmetry, print-rect placement, aspect ratios).

Exit code 0 = all checks passed.
"""
from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import generate_tshirt_model as gen  # noqa: E402


# ---------------------------------------------------------------- GLB parse

def parse_glb(path):
    data = Path(path).read_bytes()
    magic, version, total = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67, "bad GLB magic"
    assert version == 2, "bad GLB version"
    assert total == len(data), f"length mismatch {total} != {len(data)}"
    off = 12
    jlen, jtype = struct.unpack_from("<II", data, off)
    assert jtype == 0x4E4F534A, "first chunk must be JSON"
    gltf = json.loads(data[off + 8: off + 8 + jlen])
    off += 8 + jlen
    blen, btype = struct.unpack_from("<II", data, off)
    assert btype == 0x004E4942, "second chunk must be BIN"
    bin_data = data[off + 8: off + 8 + blen]
    assert len(bin_data) == blen, "truncated BIN chunk"
    return gltf, bin_data


def read_accessor(gltf, bin_data, idx):
    acc = gltf["accessors"][idx]
    bv = gltf["bufferViews"][acc["bufferView"]]
    start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    comp = acc["componentType"]
    n = acc["count"]
    sizes = {5126: 4, 5125: 4, 5123: 2, 5122: 2, 5121: 1, 5120: 1}
    ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[acc["type"]]
    dt = {5126: "<f4", 5125: "<u4", 5123: "<u2", 5122: "<i2",
          5121: "u1", 5120: "i1"}[comp]
    arr = np.frombuffer(bin_data, dtype=dt, count=n * ncomp, offset=start)
    return arr.reshape(n, ncomp)


def load_meshes(glb_path):
    gltf, bin_data = parse_glb(glb_path)
    meshes = []
    for node in gltf["nodes"]:
        if "mesh" not in node:
            continue
        for prim in gltf["meshes"][node["mesh"]]["primitives"]:
            pos = read_accessor(gltf, bin_data, prim["attributes"]["POSITION"])
            nrm = read_accessor(gltf, bin_data, prim["attributes"]["NORMAL"])
            uv = read_accessor(gltf, bin_data, prim["attributes"]["TEXCOORD_0"])
            idx = read_accessor(gltf, bin_data, prim["indices"])
            meshes.append({
                "name": gltf["meshes"][node["mesh"]]["name"],
                "material": prim["material"], "pos": pos, "nrm": nrm,
                "uv": uv, "idx": idx.reshape(-1, 3),
            })
    return gltf, meshes


# ------------------------------------------------------- UV -> 3D mapping

def uv_to_3d(mesh, u, v):
    """Locate 3D point for a UV coordinate (barycentric in UV space)."""
    uv, pos, idx = mesh["uv"], mesh["pos"], mesh["idx"]
    for tri in idx:
        t_uv = uv[tri]
        if not (t_uv[:, 0].min() - 1e-6 <= u <= t_uv[:, 0].max() + 1e-6 and
                t_uv[:, 1].min() - 1e-6 <= v <= t_uv[:, 1].max() + 1e-6):
            continue
        d = ((t_uv[1, 0] - t_uv[0, 0]) * (t_uv[2, 1] - t_uv[0, 1]) -
             (t_uv[2, 0] - t_uv[0, 0]) * (t_uv[1, 1] - t_uv[0, 1]))
        if abs(d) < 1e-12:
            continue
        w1 = ((t_uv[1, 0] - u) * (t_uv[2, 1] - v) -
              (t_uv[2, 0] - u) * (t_uv[1, 1] - v)) / d
        w2 = ((t_uv[2, 0] - u) * (t_uv[0, 1] - v) -
              (t_uv[0, 0] - u) * (t_uv[2, 1] - v)) / d
        w0 = 1 - w1 - w2
        if w0 >= -1e-6 and w1 >= -1e-6 and w2 >= -1e-6:
            return w0 * pos[tri[0]] + w1 * pos[tri[1]] + w2 * pos[tri[2]]
    return None


def check_print_areas(meshes, manifest):
    ok = True
    for key, area in manifest["print_areas"].items():
        u0, v0, u1, v1 = area["uv_rect"]
        pts = []
        for fu in np.linspace(0.05, 0.95, 7):
            for fv in np.linspace(0.05, 0.95, 7):
                p = None
                for m in meshes:
                    if m["material"] != 0:
                        continue
                    p = uv_to_3d(m, u0 + (u1 - u0) * fu, v0 + (v1 - v0) * fv)
                    if p is not None:
                        break
                if p is None:
                    print(f"  FAIL {key}: UV point not found on mesh")
                    ok = False
                    continue
                pts.append(p)
        if not pts:
            continue
        pts = np.array(pts)
        cx, cy, cz = pts.mean(0)
        mins, maxs = pts.min(0), pts.max(0)
        if key == "front":
            good = (cz > 0.02 and abs(cx) < 0.02 and
                    0.20 <= cy <= 0.60 and mins[0] > -0.17 and maxs[0] < 0.17)
        elif key == "back":
            good = (cz < -0.02 and abs(cx) < 0.02 and 0.22 <= cy <= 0.62)
        elif key == "left_sleeve":
            good = (cx < -0.16 and 0.35 <= cy <= 0.62)
        else:
            good = (cx > 0.16 and 0.35 <= cy <= 0.62)
        status = "ok" if good else "FAIL"
        if not good:
            ok = False
        print(f"  {key:14s} {status}  center=({cx:+.3f},{cy:+.3f},{cz:+.3f}) "
              f"span=({maxs[0]-mins[0]:.2f}w {maxs[1]-mins[1]:.2f}h) "
              f"z:[{mins[2]:+.3f},{maxs[2]:+.3f}]")
    return ok


def check_normals(meshes):
    """Every mesh part must face outward."""
    ok = True
    for m in meshes:
        pos, nrm = m["pos"], m["nrm"]
        if m["name"] == "Body_front":
            front = pos[:, 2] > 0.03
            back = pos[:, 2] < -0.03
            if front.sum():
                good = np.mean(nrm[front][:, 2]) > 0.4
                print(f"  front panel  nz_mean={np.mean(nrm[front][:,2]):+.2f}"
                      f"  {'ok' if good else 'FAIL'}")
                ok &= good
            if back.sum():
                good = np.mean(nrm[back][:, 2]) < -0.4
                print(f"  back panel   nz_mean={np.mean(nrm[back][:,2]):+.2f}"
                      f"  {'ok' if good else 'FAIL'}")
                ok &= good
        elif m["name"].startswith("Sleeve"):
            # sleeve: radial away from the sleeve axis
            side = 1.0 if pos[:, 0].mean() > 0 else -1.0
            axis = np.array(gen.SLEEVE_AXIS, dtype=np.float64)
            axis[0] *= side
            axis /= np.linalg.norm(axis)
            c0 = np.array(gen.SLEEVE_C0, dtype=np.float64)
            c0[0] *= side
            rel = pos - c0
            radial = rel - np.outer(rel @ axis, axis)
            radial /= (np.linalg.norm(radial, axis=1, keepdims=True) + 1e-9)
            d = np.einsum("ij,ij->i", nrm, radial)
            good = np.mean(d) > 0.3
            print(f"  sleeve {'R' if side>0 else 'L'}    radial_dot={np.mean(d):+.2f}"
                  f"  {'ok' if good else 'FAIL'}")
            ok &= good
        else:
            radial = pos.copy(); radial[:, 1] = 0
            radial /= (np.linalg.norm(radial, axis=1, keepdims=True) + 1e-9)
            d = np.einsum("ij,ij->i", nrm, radial)
            if m["name"] == "Collar":
                good = np.mean(d) > 0.4
                print(f"  collar        radial_dot={np.mean(d):+.2f}"
                      f"  {'ok' if good else 'FAIL'}")
            else:
                good = np.mean(nrm[:, 1]) > 0.15
                print(f"  shoulder      ny_mean={np.mean(nrm[:,1]):+.2f}"
                      f"  {'ok' if good else 'FAIL'}")
            ok &= good
    return ok


# ------------------------------------------------------- pixel analysis

def analyze_view(name, img, zbuf, expect):
    h, w, _ = img.shape
    visible = zbuf < 1e9
    total = visible.sum()
    print(f"  [{name}] visible {total}px ({100*total/(h*w):.1f}%)")
    checks = []
    r = img[..., 0]; g = img[..., 1]; b = img[..., 2]
    red = visible & (r > 0.45) & (g < 0.35) & (b < 0.35)
    blue = visible & (b > 0.35) & (r < 0.35) & (g < 0.45)
    green = visible & (g > 0.4) & (r < 0.45) & (b < 0.4)
    yellow = visible & (r > 0.44) & (g > 0.44) & (b < 0.4)
    for cname, mask, exp in (("front-red", red, expect.get("front")),
                             ("back-blue", blue, expect.get("back")),
                             ("sleeve-green", green, expect.get("sleeve")),
                             ("print-yellow", yellow, expect.get("print"))):
        cnt = int(mask.sum())
        pct = 100 * cnt / max(total, 1)
        line = f"    {cname:13s} {pct:5.1f}%"
        if exp is not None:
            lo, hi = exp
            good = lo <= pct <= hi
            line += f"  (expect {lo}-{hi}%)  {'ok' if good else 'FAIL'}"
            checks.append(good)
        print(line)
        if cname == "print-yellow" and cnt > 50:
            ys, xs = np.where(mask)
            bw, bh = xs.max()-xs.min(), ys.max()-ys.min()
            print(f"      print bbox: {bw}x{bh}px  aspect(h/w)={bh/max(bw,1):.2f}"
                  f"  center=({xs.mean()/w:.2f},{ys.mean()/h:.2f})")
            # central patch only (body print; sleeves are at the edges)
            cmask = mask.copy()
            cmask[:, :int(w*0.30)] = False
            cmask[:, int(w*0.70):] = False
            if cmask.sum() > 50:
                cys, cxs = np.where(cmask)
                cbw = cxs.max()-cxs.min(); cbh = cys.max()-cys.min()
                good_a = 0.85 <= cbh/max(cbw, 1) <= 1.55
                print(f"      body print: {cbw}x{cbh}px aspect(h/w)="
                      f"{cbh/max(cbw,1):.2f} {'ok' if good_a else 'FAIL'}")
                checks.append(good_a)
    ys, xs = np.where(visible)
    if len(ys):
        sw, sh = xs.max()-xs.min(), ys.max()-ys.min()
        good = 0.70 <= sw/sh <= 1.45
        print(f"    silhouette: {sw}x{sh}px  aspect(w/h)={sw/sh:.2f} "
              f"{'ok' if good else 'FAIL'}")
        checks.append(good)
    return all(checks) if checks else True


def render_quadrants(meshes, eye, target, w, h, fov_deg, print_rects):
    light = np.array([0.4, 0.75, 0.55]); light /= np.linalg.norm(light)
    light2 = np.array([-0.4, 0.45, -0.85]); light2 /= np.linalg.norm(light2)

    def qc(u, v):
        if v < 0.5:
            base = (210, 70, 70) if u < 0.5 else (70, 100, 220)
        else:
            base = (80, 180, 90) if u < 0.5 else (190, 130, 50)
        for a in print_rects.values():
            u0, v0, u1, v1 = a["uv_rect"]
            if u0 <= u <= u1 and v0 <= v <= v1:
                return (250, 250, 70)
        return base

    class FakeMesh:
        pass

    fakes = []
    for m in meshes:
        fm = FakeMesh()
        fm.pos = m["pos"]; fm.nrm = m["nrm"]; fm.uv = m["uv"]
        fm.idx = m["idx"].reshape(-1); fm.material = m["material"]
        fakes.append(fm)

    return _render(fakes, eye, target, w, h, fov_deg, qc, light, light2)


def _render(meshes, eye, target, w, h, fov_deg, uv_color, light, light2):
    import math as _m
    eye = np.array(eye, dtype=np.float64)
    target = np.array(target, dtype=np.float64)
    fz = target - eye; fz /= np.linalg.norm(fz)
    fx = np.cross(fz, [0, 1, 0]); fx /= np.linalg.norm(fx)
    fy = np.cross(fx, fz)
    focal = (w / 2) / _m.tan(_m.radians(fov_deg) / 2)
    img = np.zeros((h, w, 3))
    zbuf = np.full((h, w), 1e9)
    for m in meshes:
        pos, nrm, uv, idx = m.pos, m.nrm, m.uv, m.idx.reshape(-1, 3)
        vcolors = np.array([uv_color(u, v) for u, v in uv],
                           dtype=np.float64) / 255.0
        cam = pos - eye
        zc = cam @ fz; xc = cam @ fx; yc = cam @ fy
        sx = (xc / zc * focal + w / 2).astype(int)
        sy = (-yc / zc * focal + h / 2).astype(int)
        for tri in idx:
            i0, i1, i2 = tri
            if min(zc[i0], zc[i1], zc[i2]) <= 0.05:
                continue
            xs = np.array([sx[i0], sx[i1], sx[i2]])
            ys = np.array([sy[i0], sy[i1], sy[i2]])
            minx, maxx = max(xs.min(), 0), min(xs.max(), w - 1)
            miny, maxy = max(ys.min(), 0), min(ys.max(), h - 1)
            if minx > maxx or miny > maxy:
                continue
            d = ((xs[1]-xs[0])*(ys[2]-ys[0]) - (xs[2]-xs[0])*(ys[1]-ys[0]))
            if abs(d) < 1e-9:
                continue
            gy, gx = np.mgrid[miny:maxy+1, minx:maxx+1]
            gy, gx = gy + 0.5, gx + 0.5
            w0 = ((xs[1]-gx)*(ys[2]-gy) - (xs[2]-gx)*(ys[1]-gy)) / d
            w1 = ((xs[2]-gx)*(ys[0]-gy) - (xs[0]-gx)*(ys[2]-gy)) / d
            w2 = 1 - w0 - w1
            inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
            if not inside.any():
                continue
            sub = (slice(miny, maxy+1), slice(minx, maxx+1))
            z = w0*zc[i0] + w1*zc[i1] + w2*zc[i2]
            draw = inside & (z < zbuf[sub])
            if not draw.any():
                continue
            n = (w0[..., None]*nrm[i0] + w1[..., None]*nrm[i1] +
                 w2[..., None]*nrm[i2])
            n /= (np.linalg.norm(n, axis=-1, keepdims=True) + 1e-30)
            lit = 0.42 + 0.38*np.maximum(0, n @ light) + \
                0.24*np.maximum(0, n @ light2)
            c = (w0[..., None]*vcolors[i0] + w1[..., None]*vcolors[i1] +
                 w2[..., None]*vcolors[i2]) * lit[..., None]
            img[sub] = img[sub]*(~draw[..., None]) + c*draw[..., None]
            zbuf[sub] = np.where(draw, z, zbuf[sub])
    return img, zbuf


# ---------------------------------------------------------------- main

def main():
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
        "/home/user/scratch/render")
    glb = src / "classic-tshirt.glb"
    manifest = json.loads((src / "manifest.json").read_text())

    print("== GLB structure ==")
    gltf, meshes = load_meshes(glb)
    names = sorted({m["name"] for m in meshes})
    mats = [mm["name"] for mm in gltf["materials"]]
    print(f"  meshes: {names}, materials: {mats}")
    assert mats[0] == "TD_Fabric" and mats[1] == "TD_Trim"
    part_names = sorted({m["name"] for m in meshes})
    assert part_names == ["Body_back", "Body_front", "Collar",
                          "Shoulder", "Sleeve_left", "Sleeve_right"], part_names
    tris = sum(len(m["idx"]) for m in meshes)
    allpos = np.vstack([m["pos"] for m in meshes])
    allnrm = np.vstack([m["nrm"] for m in meshes])
    alluv = np.vstack([m["uv"] for m in meshes])
    print(f"  triangles: {tris}, verts: {len(allpos)}")
    print(f"  bounds: x[{allpos[:,0].min():+.3f},{allpos[:,0].max():+.3f}] "
          f"y[{allpos[:,1].min():+.3f},{allpos[:,1].max():+.3f}] "
          f"z[{allpos[:,2].min():+.3f},{allpos[:,2].max():+.3f}]")
    assert np.isfinite(allpos).all() and np.isfinite(allnrm).all()
    assert np.abs(np.linalg.norm(allnrm, axis=1) - 1).max() < 1e-3
    assert 0 <= alluv.min() and alluv.max() <= 1.0
    assert abs(allpos[:, 0].max() + allpos[:, 0].min()) < 0.01, "not symmetric"
    w = allpos[:, 0].max() - allpos[:, 0].min()
    hh = allpos[:, 1].max() - allpos[:, 1].min()
    d = allpos[:, 2].max() - allpos[:, 2].min()
    print(f"  size: {w:.2f}w x {hh:.2f}h x {d:.2f}d (span incl. sleeves)")
    assert 0.80 < w < 1.05, "sleeve span"
    assert 0.66 < hh < 0.80, "height"
    assert 0.14 < d < 0.30, "depth"

    print("== normal orientation ==")
    ok_nrm = check_normals(meshes)

    print("== print area UV -> 3D mapping ==")
    ok_area = check_print_areas(meshes, manifest)

    print("== rendered views (pixel analysis) ==")
    pr = manifest["print_areas"]
    img_f, z_f = render_quadrants(meshes, (0, 0.42, 1.75), (0, 0.36, 0),
                                  420, 520, 34, pr)
    img_b, z_b = render_quadrants(meshes, (0, 0.42, -1.75), (0, 0.36, 0),
                                  420, 520, 34, pr)
    img_s, z_s = render_quadrants(meshes, (1.55, 0.5, 1.35), (0, 0.34, 0),
                                  520, 520, 36, pr)
    ok_f = analyze_view("front", img_f, z_f,
                        {"front": (32, 90), "back": (0, 4), "sleeve": (4, 35),
                         "print": (8, 40)})
    ok_b = analyze_view("back", img_b, z_b,
                        {"front": (0, 7), "back": (32, 90), "sleeve": (4, 35),
                         "print": (8, 40)})
    ok_s = analyze_view("3/4-side", img_s, z_s,
                        {"front": (20, 65), "back": (0, 45), "sleeve": (2, 45),
                         "print": (1, 38)})
    ok_geom = ok_f and ok_b and ok_s

    print()
    if ok_nrm and ok_area and ok_geom:
        print("ALL CHECKS PASSED")
        return 0
    print("VALIDATION FAILED",
          f"(normals={ok_nrm} areas={ok_area} views={ok_geom})")
    return 1


if __name__ == "__main__":
    sys.exit(main())
