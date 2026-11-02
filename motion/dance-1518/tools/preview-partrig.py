#!/usr/bin/env python3
"""Preview the cutout rig without a browser.

Composes the painted pieces with PIL into a few test poses so pivot and attach
numbers can be tuned in seconds instead of render minutes. The maths is exactly
what engine/partrig.js does with nested SVG groups:

    frame(piece)  = frame(parent) @ T(attach) @ R(rest + angle) @ S(k) @ T(-pivot)
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "assets", "parts")

# joint caps / centrelines measured by tools/build-part-rig.py
PIVOT = {
    "head": (71.5, 190.9),
    "bodice": (89.0, 240.0),
    "apron": (85.5, 6.3),
    "skirt": (128.5, 6.2),
    "arm": (26.0, 6.6),
    "fore": (25.5, 6.6),
    "leg": (69.5, 6.5),
}
TILT = {"arm": 1.1, "fore": 1.6, "leg": -8.4}
K = {"head": 0.92, "bodice": 0.95, "apron": 0.8, "skirt": 0.92,
     "arm": 0.85, "fore": 0.85, "leg": 1.0}

# in BODICE-LOCAL px (children of the bodice inherit its scale, so their offsets
# must be expressed in the same space the painted piece uses)
NECK = (88.5, 26.0)
SHOULDERS = {"L": (40.0, 20.0), "R": (136.0, 20.0)}
APRON_AT = (89.0, 168.0)
ELBOW = 106.0                 # arm-local px: shoulder cap → elbow cap
# in RIG px (hip = 0,0)
SKIRT_AT = (0.0, 8.0)
LEG_AT = {"L": (-46.0, 150.0), "R": (52.0, 150.0)}


def load(n):
    return Image.open(os.path.join(P, n + ".png")).convert("RGBA")


IMGS = {n: load(n) for n in ("head", "bodice", "apron", "skirt", "arm", "fore", "leg")}


def T(x, y):
    m = np.eye(3); m[0, 2] = x; m[1, 2] = y; return m


def R(deg):
    a = np.deg2rad(deg); m = np.eye(3)
    m[0, 0] = np.cos(a); m[0, 1] = -np.sin(a)
    m[1, 0] = np.sin(a); m[1, 1] = np.cos(a)
    return m


def Sc(k):
    m = np.eye(3); m[0, 0] = m[1, 1] = k; return m


def MIRROR():
    m = np.eye(3); m[0, 0] = -1; return m


def joint(name, angle, k, mirrored=False):
    """frame for a piece: rotate about its cap, scale, and shift the pivot to 0."""
    m = R(angle) @ Sc(k) @ T(-PIVOT[name][0], -PIVOT[name][1])
    return m @ MIRROR() if mirrored else m


def draw(canvas, name, frame):
    img = IMGS[name]
    a, b, c = frame[0]; d, e, f = frame[1]
    det = a * e - b * d
    if abs(det) < 1e-9:
        return
    inv = np.array([[e, -b, b * f - e * c], [-d, a, d * c - a * f]]) / det
    out = img.transform(canvas.size, Image.AFFINE,
                        (inv[0, 0], inv[0, 1], inv[0, 2], inv[1, 0], inv[1, 1], inv[1, 2]),
                        resample=Image.BICUBIC)
    canvas.alpha_composite(out)


def pose(canvas, ox, oy, s, pv):
    root = T(ox, oy) @ Sc(s)

    for side in ("L", "R"):
        m = side == "R"
        ang = pv.get("leg" + side, 0) + (TILT["leg"] if m else -TILT["leg"])
        draw(canvas, "leg", root @ T(*LEG_AT[side]) @ joint("leg", ang, K["leg"], m))

    draw(canvas, "skirt", root @ T(*SKIRT_AT) @ joint("skirt", pv.get("skirt", 0), K["skirt"]))

    torso = root @ T(0, 0)                      # hip frame
    draw(canvas, "bodice", torso @ joint("bodice", pv.get("torso", 0), K["bodice"]))
    draw(canvas, "apron", torso @ joint("bodice", pv.get("torso", 0), K["bodice"])
         @ T(*APRON_AT) @ joint("apron", pv.get("apron", 0), 1.0))

    for side in ("L", "R"):
        m = side == "R"
        armAng = pv.get("arm" + side, 0) + (TILT["arm"] if m else -TILT["arm"])
        armFrame = (torso @ joint("bodice", pv.get("torso", 0), K["bodice"])
                    @ T(*SHOULDERS[side]) @ joint("arm", armAng, K["arm"], m))
        draw(canvas, "arm", armFrame)
        foreAng = pv.get("fore" + side, 0) + (TILT["fore"] if m else -TILT["fore"])
        draw(canvas, "fore", armFrame @ T(0, ELBOW) @ joint("fore", foreAng, K["fore"] / K["arm"], m))

    draw(canvas, "head", torso @ joint("bodice", pv.get("torso", 0), K["bodice"])
         @ T(*NECK) @ joint("head", pv.get("head", 0), K["head"]))


def main():
    canvas = Image.new("RGBA", (1600, 1040), (34, 31, 27, 255))
    poses = [
        {},
        {"torso": -3, "head": 5, "armL": -50, "foreL": -24, "armR": 30, "foreR": 16, "skirt": -3, "legL": -6},
        {"torso": 4, "head": -7, "armL": 20, "foreL": 30, "armR": -62, "foreR": -20, "skirt": 4, "legR": 9},
    ]
    for i, pv in enumerate(poses):
        pose(canvas, 250 + i * 520, 640, 0.78, pv)
    os.makedirs(os.path.join(ROOT, "stills"), exist_ok=True)
    canvas.convert("RGB").save(os.path.join(ROOT, "stills", "partrig-poses.png"))
    print("wrote stills/partrig-poses.png")


if __name__ == "__main__":
    main()
