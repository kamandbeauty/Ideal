#!/usr/bin/env python3
"""Sculpt, texture, rig and animate the zombie models.

Every model is original and procedural: a signed-distance sculpt is meshed,
reduced to a mobile triangle budget, unwrapped, painted from the sculpt
(material layers, cloth folds, wounds, grime, blood, ambient occlusion),
skinned to an 18-bone skeleton and exported as binary glTF with its animation
clips. Every kind limps: its walk is authored lame in one leg, and a mirrored
copy of each walk is written beside it so that a crowd is not lame in step.

    python3 tools/build_zombies.py [--only walker] [--draft]

Requires numpy, pillow, scikit-image, fast-simplification and xatlas.
"""
import argparse
import io
import math
import os
import sys
import time

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from assetlib import noise, rig, sdf  # noqa: E402
from assetlib.gltf import GLB  # noqa: E402

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_DIR = os.path.join(PROJECT, "assets", "models", "zombies")
TEXTURE_DIR = os.path.join(PROJECT, "assets", "textures", "zombies")

SKIN, SHIRT, PANTS, SHOES, EYES = 0, 1, 2, 3, 4


class Prim:
    """One sculpt primitive with a bounding sphere for chunk culling."""

    def __init__(self, fn, center, radius, k=0.0, bone=None):
        self.fn = fn
        self.center = np.asarray(center, np.float32)
        self.radius = float(radius)
        self.k = k
        self.bone = bone


def _near(prim, lo, hi, margin):
    gap = np.linalg.norm(np.maximum(np.maximum(lo - prim.center, prim.center - hi), 0.0)) - prim.radius
    return gap <= margin


def blend(prims, p, margin=0.14):
    lo, hi = p.min(axis=0), p.max(axis=0)
    d = np.full(p.shape[0], margin, np.float32)
    for prim in prims:
        if _near(prim, lo, hi, margin):
            d = sdf.smin(d, prim.fn(p).astype(np.float32), prim.k)
    return d


def carve(d, prims, p, margin=0.05):
    lo, hi = p.min(axis=0), p.max(axis=0)
    for prim in prims:
        if _near(prim, lo, hi, margin):
            d = sdf.smax(d, -prim.fn(p).astype(np.float32), prim.k)
    return d


def cap(a, b, r1, r2=None, k=0.0, bone=None):
    a = np.asarray(a, np.float32)
    b = np.asarray(b, np.float32)
    r2 = r1 if r2 is None else r2
    return Prim(lambda p: sdf.capsule(p, a, b, r1, r2), (a + b) * 0.5, np.linalg.norm(b - a) * 0.5 + max(r1, r2), k, bone)


def ell(center, radii, k=0.0, bone=None, basis=None):
    return Prim(lambda p: sdf.ellipsoid(p, center, radii, basis), center, max(radii), k, bone)


def sph(center, radius, k=0.0, bone=None):
    return Prim(lambda p: sdf.sphere(p, center, radius), center, radius, k, bone)


def rbox(center, half, radius, k=0.0, bone=None, basis=None):
    return Prim(lambda p: sdf.box(p, center, half, radius, basis), center, float(np.linalg.norm(half)), k, bone)


# ---------------------------------------------------------------------------
# Specifications
# ---------------------------------------------------------------------------
WALKER = {
    "name": "walker",
    "scale": 1.0,
    "torso_w": 1.0, "torso_d": 1.0, "belly": 0.0, "limb": 1.0, "arm": 1.0, "neck": 1.0, "head": 1.07,
    "shoulder": 0.196, "hip": 0.092, "arm_spread": 38.0,
    "hand": 1.12,
    "outfit": {"sleeve": (0.62, 0.3), "hem": 0.975, "left_leg": 0.86, "right_leg": 0.42, "shoes": (True, False), "tear": 0.6},
    "wounds": [
        {"at": (0.112, 1.215, 0.062), "radii": (0.05, 0.08, 0.042), "ribs": True},
        {"at": (-0.118, 1.462, 0.012), "radii": (0.05, 0.034, 0.05)},
        {"arm": "L", "along": 0.45, "radii": (0.035, 0.03, 0.03)},
        {"at": (-0.062, 0.63, 0.05), "radii": (0.03, 0.06, 0.03)},
    ],
    "faces": {"body": 3600, "head": 1300},
    # At the gate a walker stands some 150 pixels tall through the sights; 768 leaves room to spare.
    "texture": 768,
    # The walk: a hobble. "distance" is the ground one cycle covers; the lame leg bears weight from the start of the
    # cycle to "bad_stance", the sound one from "good_on" to "good_off"; "walks" are the variations of it.
    "gait": {"period": 0.8, "lean": 21.0, "reach": 1.0, "walks": {
        "walk": {"distance": 1.4, "bad_stance": 0.34, "good_on": 0.44, "good_off": 0.94, "bad_lead": 0.1, "good_lead": 0.36, "arms": "reach"},
        "walk_b": {"distance": 1.4, "bad_stance": 0.36, "good_on": 0.46, "good_off": 0.96, "bad_lead": 0.14, "good_lead": 0.34, "arms": "hang",
                   "swing_out": 0.13, "bad_lift": 0.035, "lean": 27.0, "dip": 0.03},
    }},
    "palettes": [
        {"skin": (0.50, 0.55, 0.45), "shirt": (0.20, 0.30, 0.33), "pants": (0.17, 0.16, 0.15), "shoes": (0.07, 0.06, 0.05), "hair": (0.08, 0.07, 0.06), "plaid": 0.0, "blood": 1.0},
        {"skin": (0.56, 0.53, 0.52), "shirt": (0.40, 0.16, 0.13), "pants": (0.14, 0.19, 0.27), "shoes": (0.12, 0.09, 0.06), "hair": (0.22, 0.20, 0.18), "plaid": 1.0, "blood": 0.7},
        {"skin": (0.58, 0.60, 0.50), "shirt": (0.56, 0.54, 0.48), "pants": (0.31, 0.27, 0.19), "shoes": (0.05, 0.05, 0.05), "hair": (0.05, 0.04, 0.04), "plaid": 0.0, "blood": 1.5},
        {"skin": (0.47, 0.5, 0.47), "shirt": (0.19, 0.24, 0.15), "pants": (0.24, 0.22, 0.2), "shoes": (0.09, 0.07, 0.05), "hair": (0.33, 0.3, 0.26), "plaid": 0.0, "blood": 1.0},
    ],
}

# Fast: lean, bare to the waist, sprinting bent forward with both arms clawing ahead.
RUNNER = {
    "name": "runner",
    "scale": 0.97,
    "torso_w": 0.86, "torso_d": 0.84, "belly": -0.25, "limb": 0.84, "arm": 1.08, "neck": 0.9, "head": 1.0,
    "shoulder": 0.196, "hip": 0.088, "arm_spread": 32.0,
    "hand": 1.1,
    "outfit": {"sleeve": (0.0, 0.0), "hem": 1.7, "left_leg": 0.36, "right_leg": 0.3, "shoes": (False, False), "tear": 0.62},
    "wounds": [
        {"at": (0.105, 1.265, 0.058), "radii": (0.045, 0.085, 0.04), "ribs": True},
        {"at": (-0.045, 1.13, 0.085), "radii": (0.06, 0.045, 0.035)},
        {"arm": "R", "along": 0.5, "radii": (0.03, 0.03, 0.028)},
    ],
    "faces": {"body": 3300, "head": 1200},
    "texture": 768,
    "gait": {"period": 0.5, "stride": 0.85, "limp": 0.3, "lean": 31.0, "reach": 0.9, "lift": 0.17, "stance": 0.42, "arms": "flail"},
    "palettes": [
        {"skin": (0.58, 0.58, 0.54), "shirt": (0.2, 0.2, 0.2), "pants": (0.36, 0.08, 0.07), "shoes": (0.07, 0.06, 0.05), "hair": (0.06, 0.05, 0.05), "plaid": 0.0, "blood": 1.6,
         "bib": 0.7, "soil": 0.8},
        {"skin": (0.54, 0.60, 0.58), "shirt": (0.2, 0.2, 0.2), "pants": (0.10, 0.13, 0.22), "shoes": (0.07, 0.06, 0.05), "hair": (0.30, 0.12, 0.06), "plaid": 0.0, "blood": 1.2,
         "bib": 0.4, "soil": 0.8},
        {"skin": (0.5, 0.52, 0.44), "shirt": (0.2, 0.2, 0.2), "pants": (0.2, 0.21, 0.17), "shoes": (0.07, 0.06, 0.05), "hair": (0.1, 0.09, 0.08), "plaid": 0.0, "blood": 1.4,
         "bib": 0.85, "soil": 1.0},
    ],
}

# Heavy: a wall of a man in a work coverall, slow, arms hanging like clubs.
BRUTE = {
    "name": "brute",
    "scale": 1.35,
    "torso_w": 1.42, "torso_d": 1.4, "belly": 0.9, "limb": 1.42, "arm": 1.06, "neck": 1.45, "head": 1.02,
    "shoulder": 0.196, "hip": 0.122, "arm_spread": 27.0, "bulk": 1.0, "hand": 1.3, "foot": 1.3,
    "outfit": {"sleeve": (0.42, 0.42), "hem": 0.9, "left_leg": 0.97, "right_leg": 0.93, "shoes": (True, True), "tear": 0.7},
    "wounds": [
        {"at": (0.17, 1.34, 0.105), "radii": (0.065, 0.055, 0.045), "ribs": True},
        {"at": (-0.2, 1.47, 0.03), "radii": (0.06, 0.04, 0.06)},
    ],
    "faces": {"body": 4000, "head": 1200},
    "texture": 1024,
    "gait": {"period": 1.25, "stride": 0.6, "limp": 0.45, "lean": 11.0, "reach": 1.0, "arms": "hang"},
    "attack": "slam",
    "palettes": [
        {"skin": (0.52, 0.56, 0.44), "shirt": (0.66, 0.33, 0.08), "pants": (0.62, 0.3, 0.07), "shoes": (0.06, 0.05, 0.05), "hair": (0.07, 0.06, 0.05), "plaid": 0.0, "blood": 1.1},
        {"skin": (0.56, 0.52, 0.5), "shirt": (0.64, 0.58, 0.16), "pants": (0.6, 0.54, 0.15), "shoes": (0.06, 0.05, 0.05), "hair": (0.16, 0.14, 0.12), "plaid": 0.0, "blood": 0.8},
    ],
}

# Boss: twice a man's height, pale and swollen, small-headed, bloody to the elbows.
BOSS = {
    "name": "boss",
    "scale": 1.9,
    "torso_w": 1.55, "torso_d": 1.5, "belly": 0.55, "limb": 1.55, "arm": 1.16, "neck": 1.6, "head": 0.94,
    "shoulder": 0.196, "hip": 0.128, "arm_spread": 27.0, "bulk": 1.5, "hand": 1.55, "foot": 1.45,
    "outfit": {"sleeve": (0.0, 0.0), "hem": 1.7, "left_leg": 0.62, "right_leg": 0.44, "shoes": (False, False), "tear": 0.62},
    "wounds": [
        {"at": (0.2, 1.3, 0.11), "radii": (0.07, 0.1, 0.05), "ribs": True},
        {"at": (-0.13, 1.14, 0.14), "radii": (0.08, 0.05, 0.045)},
        {"at": (-0.22, 1.5, 0.0), "radii": (0.07, 0.045, 0.07)},
        {"arm": "L", "along": 0.3, "radii": (0.05, 0.045, 0.045)},
    ],
    "faces": {"body": 4800, "head": 1400},
    "texture": 1024,
    "gait": {"period": 1.3, "stride": 0.5, "limp": 0.2, "lean": 8.0, "reach": 1.0, "arms": "hang"},
    "attack": "slam",
    "palettes": [
        {"skin": (0.63, 0.63, 0.60), "shirt": (0.2, 0.2, 0.2), "pants": (0.11, 0.1, 0.1), "shoes": (0.07, 0.06, 0.05), "hair": (0.05, 0.04, 0.04), "plaid": 0.0, "blood": 2.3,
         "bib": 1.0, "soil": 1.0, "livid": 0.7},
    ],
}

SPECS = {"walker": WALKER, "runner": RUNNER, "brute": BRUTE, "boss": BOSS}


# ---------------------------------------------------------------------------
# Sculpt
# ---------------------------------------------------------------------------
class Sculpt:
    def __init__(self, spec):
        self.spec = spec
        s = spec
        self.skeleton = rig.Skeleton()
        sk = self.skeleton
        spread = math.radians(s["arm_spread"])
        arm_dir = np.array([math.sin(spread), -math.cos(spread), 0.0])
        upper, fore, hand = 0.285 * s["arm"], 0.26 * s["arm"], 0.17
        shoulder = np.array([s["shoulder"] * s["torso_w"], 1.43, -0.01])
        hip = np.array([s["hip"], 0.93, 0.0])
        sk.add("Root", (0, 0, 0))
        sk.add("Hips", (0, 0.98, 0), "Root")
        sk.add("Spine", (0, 1.10, 0), "Hips")
        sk.add("Chest", (0, 1.27, -0.005), "Spine")
        sk.add("Neck", (0, 1.485, 0.0), "Chest")
        sk.add("Head", (0, 1.575, 0.015), "Neck")
        self.lengths = {"upper_arm": upper, "fore_arm": fore, "hand": hand}
        for side, sign in (("L", 1.0), ("R", -1.0)):
            mirror = np.array([sign, 1.0, 1.0])
            sh = shoulder * mirror
            elbow = sh + arm_dir * mirror * upper
            wrist = elbow + arm_dir * mirror * fore
            sk.add("UpperArm_" + side, sh, "Chest")
            sk.add("LowerArm_" + side, elbow, "UpperArm_" + side)
            sk.add("Hand_" + side, wrist, "LowerArm_" + side)
            hp = hip * mirror
            knee = np.array([(s["hip"] + 0.008) * sign, 0.505, 0.012])
            ankle = np.array([(s["hip"] + 0.012) * sign, 0.085, -0.015])
            sk.add("UpperLeg_" + side, hp, "Hips")
            sk.add("LowerLeg_" + side, knee, "UpperLeg_" + side)
            sk.add("Foot_" + side, ankle, "LowerLeg_" + side)
        self.arm_dir = arm_dir
        self.lengths["thigh"] = float(np.linalg.norm(sk.position("LowerLeg_L") - sk.position("UpperLeg_L")))
        self.lengths["shin"] = float(np.linalg.norm(sk.position("Foot_L") - sk.position("LowerLeg_L")))
        self.head_center = np.array([0.0, 1.665, 0.025])
        self._build()

    def _build(self):
        s, sk = self.spec, self.skeleton
        tw, td, belly, limb, hs = s["torso_w"], s["torso_d"], s["belly"], s["limb"], s["head"]
        bulk, hand, foot_size = s.get("bulk", 0.0), s.get("hand", 1.0), s.get("foot", 1.0)
        skin = []
        skin.append(ell((0, 0.965, -0.005), (0.136 * tw, 0.105, 0.098 * td), 0.0, "Hips"))
        skin.append(ell((0, 1.10, 0.008 + belly * 0.03), (0.127 * tw, 0.125, 0.088 * td + belly * 0.05), 0.05, "Spine"))
        skin.append(ell((0, 1.305, -0.005), (0.166 * tw, 0.15, 0.108 * td), 0.05, "Chest"))
        sw = s["shoulder"] * tw - 0.02
        skin.append(cap((-sw, 1.435, -0.012), (sw, 1.435, -0.012), 0.058, None, 0.04, "Chest"))
        # Shoulder blades and a bowed upper back give the hunched silhouette.
        skin.append(ell((0, 1.36, -0.075 * td), (0.12 * tw, 0.10, 0.05), 0.04, "Chest"))
        skin.append(cap((0, 1.46, -0.005), (0, 1.60, 0.018), 0.043 * s["neck"], None, 0.03, "Neck"))
        outfit = s["outfit"]
        shirt_src = [skin[0], skin[1], skin[2], skin[3], skin[4]]
        pants_src = [skin[0]]
        # The masses that make a trunk read as a body and not as a tube: the slope from neck to shoulder,
        # the cap of each shoulder, the breast, the seat.
        for sign in (1.0, -1.0):
            trunk = [
                cap((0.035 * sign, 1.505, -0.022), (sw * 0.9 * sign, 1.452, -0.02), 0.034 * s["neck"], 0.03, 0.035, "Chest"),
                sph(((sw + 0.018) * sign, 1.432, -0.012), 0.05 * max(limb, 0.9), 0.035, "Chest"),
                ell((0.07 * tw * sign, 1.335, 0.062 * td), (0.07 * tw, 0.05, 0.035 * td), 0.045, "Chest"),
            ]
            seat = ell((0.062 * tw * sign, 0.935, -0.062 * td), (0.07 * tw, 0.075, 0.06 * td), 0.04, "Hips")
            skin.extend(trunk + [seat])
            shirt_src.extend(trunk)
            pants_src.append(seat)
        if bulk > 0.0:
            # A slab of muscle across the upper back and a mound on each shoulder: the heavy silhouette.
            slab = ell((0, 1.405, -0.045), (0.2 * tw, 0.085, 0.07 + 0.035 * bulk), 0.06, "Chest")
            skin.append(slab)
            shirt_src.append(slab)
            for sign in (1.0, -1.0):
                mound = sph((sw * sign, 1.44, -0.012), 0.062 + 0.02 * bulk, 0.04, "Chest")
                skin.append(mound)
                shirt_src.append(mound)
        shoes = []
        for side, sign in (("L", 1.0), ("R", -1.0)):
            sh, elbow, wrist = sk.position("UpperArm_" + side), sk.position("LowerArm_" + side), sk.position("Hand_" + side)
            d = self.arm_dir * np.array([sign, 1.0, 1.0])
            skin.append(cap(sh, elbow, 0.050 * limb, 0.040 * limb, 0.035, "UpperArm_" + side))
            skin.append(cap(elbow, wrist, 0.041 * limb, 0.029 * limb, 0.02, "LowerArm_" + side))
            # Palm, two finger groups curling forward and a thumb: a clawed mitten that survives decimation.
            front = np.array([0.0, 0.0, 1.0])
            basis = np.stack([d, front, np.cross(d, front)], axis=1)
            palm = wrist + d * 0.06 * hand
            skin.append(ell(palm, (0.062 * hand, 0.043 * hand, 0.02 * hand), 0.012, "Hand_" + side, basis))
            for offset in (-0.016 * hand, 0.016 * hand):
                a = wrist + d * 0.095 * hand + front * offset
                b = wrist + d * 0.17 * hand + front * (offset * 1.5 + 0.035 * hand)
                skin.append(cap(a, b, 0.0155 * hand, 0.011 * hand, 0.01, "Hand_" + side))
            skin.append(cap(wrist + d * 0.03 * hand + front * 0.03 * hand, wrist + d * 0.095 * hand + front * 0.065 * hand, 0.014 * hand,
                            0.01 * hand, 0.01, "Hand_" + side))
            skin.append(sph(elbow - d * 0.004 + np.array([0.0, 0.0, -0.012]), 0.04 * limb, 0.02, "LowerArm_" + side))
            sleeve = outfit["sleeve"][0 if side == "L" else 1]
            if sleeve > 0.0:
                shirt_src.append(cap(sh, sh + (elbow - sh) * sleeve, 0.050 * limb, 0.044 * limb, 0.035))
            hp, knee, ankle = sk.position("UpperLeg_" + side), sk.position("LowerLeg_" + side), sk.position("Foot_" + side)
            thigh = cap(hp, knee, 0.086 * limb, 0.056 * limb, 0.035, "UpperLeg_" + side)
            skin.append(thigh)
            skin.append(cap(knee, ankle, 0.054 * limb, 0.036 * limb, 0.03, "LowerLeg_" + side))
            calf = knee + (ankle - knee) * 0.3 + np.array([0.0, 0.0, -0.02])
            calf_muscle = ell(calf, (0.05 * limb, 0.11, 0.055 * limb), 0.03, "LowerLeg_" + side)
            skin.append(calf_muscle)
            skin.append(ell(ankle + np.array([0.005 * sign, -0.045, 0.07 * foot_size]), (0.043 * foot_size, 0.038, 0.112 * foot_size), 0.02,
                            "Foot_" + side))
            kneecap = sph(knee + np.array([0.0, 0.01, 0.03 * limb]), 0.045 * limb, 0.028, "LowerLeg_" + side)
            skin.append(kneecap)
            reach = outfit["left_leg"] if side == "L" else outfit["right_leg"]
            if reach > 0.5:
                pants_src.append(kneecap)
            if reach > 0.8:
                pants_src.append(calf_muscle)
            if reach <= 0.5:
                pants_src.append(cap(hp, hp + (knee - hp) * (reach * 2.0), 0.086 * limb, 0.062 * limb, 0.035))
            else:
                pants_src.append(thigh)
                pants_src.append(cap(knee, knee + (ankle - knee) * ((reach - 0.5) * 2.0), 0.056 * limb, 0.042 * limb, 0.03))
            if outfit["shoes"][0 if side == "L" else 1]:
                center = ankle + np.array([0.006 * sign, -0.042, 0.074 * foot_size])
                shoes.append(rbox(center, (0.052 * foot_size, 0.043, 0.135 * foot_size), 0.035, 0.0, "Foot_" + side))
                shoes.append(cap(ankle + np.array([0.0, -0.02, 0.0]), ankle + np.array([0.0, 0.035, 0.0]), 0.047 * max(1.0, limb * 0.9), None, 0.02,
                                 "Foot_" + side))
        hc = self.head_center
        head = [
            ell(hc + (0, 0.028, -0.012), (0.078 * hs, 0.092 * hs, 0.098 * hs), 0.03, "Head"),
            ell(hc + (0, -0.04, 0.022), (0.064 * hs, 0.082 * hs, 0.074 * hs), 0.03, "Head"),
            ell(hc + (0, -0.108 * hs, 0.044), (0.04 * hs, 0.03 * hs, 0.04 * hs), 0.025, "Head"),
            # A heavy brow over the sockets and a short, eaten-away nose.
            cap(hc + (-0.05 * hs, 0.017, 0.077 * hs), hc + (0.05 * hs, 0.017, 0.077 * hs), 0.0185 * hs, None, 0.012, "Head"),
            cap(hc + (0, 0.0, 0.092 * hs), hc + (0, -0.034 * hs, 0.103 * hs), 0.0105 * hs, 0.0125 * hs, 0.008, "Head"),
            # The hinge of a slack jaw, wider than the chin.
            cap(hc + (-0.047 * hs, -0.078 * hs, 0.012 * hs), hc + (0.047 * hs, -0.078 * hs, 0.012 * hs), 0.027 * hs, None, 0.02, "Head"),
        ]
        for sign in (1.0, -1.0):
            head.append(sph(hc + (0.056 * hs * sign, -0.028 * hs, 0.054 * hs), 0.025 * hs, 0.02, "Head"))
            head.append(ell(hc + (0.081 * hs * sign, -0.005, -0.005), (0.011, 0.03 * hs, 0.02 * hs), 0.008, "Head"))
        # Hair in matted clumps instead of a cap: an uneven outline against the sky.
        rng = np.random.default_rng(31 + len(s["name"]))
        for _ in range(9):
            angle = rng.uniform(0.0, math.tau)
            rise = rng.uniform(0.35, 1.0)
            spot = np.array([math.sin(angle) * 0.07 * hs * (1.1 - rise * 0.55), 0.03 + 0.085 * hs * rise, -0.02 + math.cos(angle) * 0.085 * hs * (1.1 - rise * 0.6)])
            if spot[2] > 0.045 * hs and rise < 0.75:
                continue
            head.append(sph(hc + spot, rng.uniform(0.016, 0.028) * hs, 0.014, "Head"))
        self.skin = skin + head
        self.sockets = [sph(hc + (0.033 * hs * sign, -0.008 * hs, 0.085 * hs), 0.0215 * hs, 0.008) for sign in (1.0, -1.0)]
        self.cheeks = [ell(hc + (0.064 * hs * sign, -0.066 * hs, 0.044 * hs), (0.018, 0.03, 0.03), 0.02) for sign in (1.0, -1.0)]
        self.mouth = ell(hc + (0, -0.086 * hs, 0.08 * hs), (0.034 * hs, 0.027 * hs, 0.038 * hs), 0.006)
        self.eyes = [sph(hc + (0.033 * hs * sign, -0.008 * hs, 0.0745 * hs), 0.0125 * hs) for sign in (1.0, -1.0)]
        self.shirt_src = shirt_src
        self.pants_src = pants_src
        self.shoes = shoes
        self.collar = sph((0, 1.50, 0.03), 0.078)
        # Wounds are bitten out of the sculpt: flesh under torn cloth, ribs in the deep ones.
        self.wounds, self.rib_wounds = [], []
        for wound in s.get("wounds", []):
            if "arm" in wound:
                side = wound["arm"]
                elbow, wrist = sk.position("LowerArm_" + side), sk.position("Hand_" + side)
                at = elbow + (wrist - elbow) * wound["along"] + np.array([0.0, 0.0, 0.03 * limb])
            else:
                at = np.asarray(wound["at"], np.float64)
            prim = ell(at, wound["radii"], 0.012)
            self.wounds.append(prim)
            if wound.get("ribs"):
                self.rib_wounds.append(prim)

    # -- layer fields -----------------------------------------------------
    def d_skin(self, p):
        d = blend(self.skin, p)
        d = carve(d, self.sockets + self.cheeks + [self.mouth] + self.wounds, p)
        return d

    def wound_distance(self, p, prims=None):
        """Distance to the nearest bite (negative inside it)."""
        prims = self.wounds if prims is None else prims
        d = np.full(p.shape[0], 1.0, np.float32)
        lo, hi = p.min(axis=0), p.max(axis=0)
        for prim in prims:
            if _near(prim, lo, hi, 0.08):
                d = np.minimum(d, prim.fn(p).astype(np.float32))
        return d

    def shirt_region(self, p):
        """Positive where the shirt has been torn away or never reached."""
        outfit = self.spec["outfit"]
        ragged = noise.fbm(p, 11.0, 3, seed=5)
        hem = (outfit["hem"] + (ragged - 0.5) * 0.07) - p[:, 1]
        tear = (noise.fbm(p + (3.1, 0.0, 1.7), 7.5, 3, seed=11) - outfit["tear"]) * 0.22
        # Keep the chest front mostly intact so the garment still reads as a shirt.
        tear -= np.clip((p[:, 1] - 1.22) * 0.25, 0.0, 0.05)
        collar = -self.collar.fn(p)
        # Cloth is torn open over a wound, a finger's width beyond its edge.
        torn = 0.016 - self.wound_distance(p)
        return np.maximum(np.maximum(np.maximum(hem, tear), collar), torn)

    def d_shirt(self, p):
        # Loose cloth: it stands a little further off the body toward the hem, where it hangs free.
        slack = 0.012 + 0.012 * np.clip((1.2 - p[:, 1]) / 0.25, 0.0, 1.0)
        return np.maximum(blend(self.shirt_src, p) - slack, self.shirt_region(p))

    def pants_region(self, p):
        ragged = noise.fbm(p, 13.0, 2, seed=23)
        return p[:, 1] - (1.035 + (ragged - 0.5) * 0.012)

    def d_pants(self, p):
        return np.maximum(np.maximum(blend(self.pants_src, p) - 0.0105, self.pants_region(p)), 0.014 - self.wound_distance(p))

    def d_shoes(self, p):
        if not self.shoes:
            return np.full(p.shape[0], 0.14, np.float32)
        return blend(self.shoes, p)

    def d_eyes(self, p):
        return blend(self.eyes, p, 0.05)

    def layers(self, p):
        return np.stack([self.d_skin(p), self.d_shirt(p), self.d_pants(p), self.d_shoes(p), self.d_eyes(p)], axis=1)

    def total(self, p):
        d = np.min(self.layers(p), axis=1)
        return np.maximum(d, -p[:, 1])

    def bone_distances(self, p):
        names = self.skeleton.names
        out = np.full((p.shape[0], len(names)), 1.0, np.float32)
        for prim in self.skin + self.shoes:
            i = names.index(prim.bone)
            out[:, i] = np.minimum(out[:, i], prim.fn(p))
        return out


# ---------------------------------------------------------------------------
# Meshing, weights, UVs
# ---------------------------------------------------------------------------
def build_mesh(sculpt, draft):
    spec = sculpt.spec
    cut = 1.535
    body_step, head_step = (0.011, 0.006) if draft else (0.0065, 0.0035)
    reach = sculpt.skeleton.position("Hand_L")[0] + 0.2
    body_fn = lambda p: np.maximum(sculpt.total(p), p[:, 1] - (cut + 0.02))
    head_fn = lambda p: np.maximum(sculpt.total(p), (cut - 0.02) - p[:, 1])
    bv, bf = sdf.mesh_from_field(body_fn, (-reach, -0.02, -0.26), (reach, cut + 0.04, 0.30), body_step)
    hv, hf = sdf.mesh_from_field(head_fn, (-0.13, cut - 0.04, -0.14), (0.13, 1.83, 0.19), head_step)
    raw = bf.shape[0] + hf.shape[0]
    bv, bf = sdf.simplify(bv, bf, spec["faces"]["body"])
    hv, hf = sdf.simplify(hv, hf, spec["faces"]["head"])
    vertices = np.concatenate([bv, hv], axis=0)
    faces = np.concatenate([bf, hf + bv.shape[0]], axis=0)
    is_head = np.concatenate([np.zeros(bv.shape[0], bool), np.ones(hv.shape[0], bool)])
    return vertices, faces, is_head, raw


def skin_weights(sculpt, vertices, is_head, sigma=0.022):
    distances = sculpt.bone_distances(vertices)
    weights = np.exp(-np.maximum(distances, 0.0) / sigma)
    names = sculpt.skeleton.names
    head, neck = names.index("Head"), names.index("Neck")
    # The head shell is rigid apart from a short blend into the neck at its base.
    blend_zone = np.clip((vertices[:, 1] - 1.515) / 0.07, 0.0, 1.0)
    rigid = np.zeros_like(weights)
    rigid[:, head] = blend_zone
    rigid[:, neck] = 1.0 - blend_zone
    weights[is_head] = rigid[is_head]
    weights[:, names.index("Root")] = 0.0
    order = np.argsort(-weights, axis=1)[:, :4]
    top = np.take_along_axis(weights, order, axis=1)
    top[top < 0.02] = 0.0
    top /= np.maximum(top.sum(axis=1, keepdims=True), 1e-9)
    order[top == 0.0] = 0
    return order.astype(np.uint8), top.astype(np.float32)


def unwrap(sculpt, vertices, faces, is_head, resolution):
    import xatlas
    density = vertices.copy()
    # More texels for the face and the hands, which carry the character.
    pivot = np.array([0.0, 1.6, 0.0], np.float32)
    density[is_head] = (density[is_head] - pivot) * 2.1 + pivot
    atlas = xatlas.Atlas()
    atlas.add_mesh(density, faces.astype(np.uint32))
    chart = xatlas.ChartOptions()
    chart.max_iterations = 2
    pack = xatlas.PackOptions()
    pack.padding = 3
    pack.resolution = resolution
    pack.bilinear = True
    pack.rotate_charts = True
    atlas.generate(chart, pack)
    mapping, indices, uvs = atlas[0]
    return mapping.astype(np.int64), indices.astype(np.int64), uvs.astype(np.float32)


def rasterize(uvs, faces, resolution):
    """Per texel: covering triangle and barycentric weights (-1 where empty)."""
    tri = np.full((resolution, resolution), -1, np.int64)
    bary = np.zeros((resolution, resolution, 3), np.float32)
    pix = uvs * resolution
    for index, face in enumerate(faces):
        a, b, c = pix[face[0]], pix[face[1]], pix[face[2]]
        lo = np.floor(np.minimum(np.minimum(a, b), c) - 1.0).astype(int)
        hi = np.ceil(np.maximum(np.maximum(a, b), c) + 1.0).astype(int)
        lo = np.clip(lo, 0, resolution - 1)
        hi = np.clip(hi, 0, resolution - 1)
        xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
        px, py = xs + 0.5, ys + 0.5
        det = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(det) < 1e-9:
            continue
        w0 = ((b[1] - c[1]) * (px - c[0]) + (c[0] - b[0]) * (py - c[1])) / det
        w1 = ((c[1] - a[1]) * (px - c[0]) + (a[0] - c[0]) * (py - c[1])) / det
        w2 = 1.0 - w0 - w1
        slack = 0.75 / max(1.0, math.sqrt(abs(det)))
        inside = (w0 >= -slack) & (w1 >= -slack) & (w2 >= -slack)
        # Texels strictly inside win over the conservative border of a neighbour.
        strict = (w0 >= 0.0) & (w1 >= 0.0) & (w2 >= 0.0)
        target = tri[ys, xs]
        write = inside & ((target < 0) | strict)
        tri[ys[write], xs[write]] = index
        weights = np.stack([w0, w1, w2], axis=-1)
        bary[ys[write], xs[write]] = weights[write]
    return tri, bary


def dilate(image, mask, passes=6):
    """Bleed painted texels into the gutters so mipmaps do not pull in black."""
    image = image.copy()
    mask = mask.copy()
    for _ in range(passes):
        total = np.zeros_like(image)
        count = np.zeros(mask.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            shifted = np.roll(image, (dy, dx), axis=(0, 1))
            shifted_mask = np.roll(mask, (dy, dx), axis=(0, 1))
            total += shifted * shifted_mask[..., None]
            count += shifted_mask
        fill = (~mask) & (count > 0)
        image[fill] = total[fill] / count[fill][:, None]
        mask = mask | fill
    return image


# ---------------------------------------------------------------------------
# Painting
# ---------------------------------------------------------------------------
def mix(a, b, t):
    t = np.clip(t, 0.0, 1.0)[:, None]
    return a * (1.0 - t) + np.asarray(b, np.float32) * t


def smooth(lo, hi, x):
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def survey(sculpt, points):
    """Everything a texel needs to know about the sculpt that no palette changes: where it lies, what it
    is made of, how open it is to the sky, and the noise fields the paint is driven by. This is the slow
    part of a bake, done once for all the skins of a kind. Points are taken in slabs by height so that
    each slab only meets the primitives near it."""
    order = np.argsort(points[:, 1], kind="stable")
    fields = {}
    for start in range(0, points.shape[0], 12000):
        chunk = order[start:start + 12000]
        part = _survey_slab(sculpt, points[chunk])
        for key, value in part.items():
            if key not in fields:
                fields[key] = np.zeros((points.shape[0],) + value.shape[1:], value.dtype)
            fields[key][chunk] = value
    return fields


def _survey_slab(sculpt, points):
    total = sculpt.total
    points = sdf.project(total, points, 2)
    normals = sdf.gradient(total, points)
    layers = sculpt.layers(points)
    biased = layers - np.array([0.0, 0.002, 0.002, 0.002, 0.001], np.float32)
    occ = sdf.occlusion(total, points, normals, 0.011, 5, 1.7)
    wide = sdf.occlusion(total, points, normals, 0.035, 3, 1.2)
    # Curvature of the surface: positive on a ridge, negative in a crease. It draws knuckles, the edge of a
    # jaw, the fold where an arm meets the trunk.
    probe = 0.006
    bulge = (total(points + normals * probe) + total(points - normals * probe)) / probe
    along = np.array([1.0, 0.33, 1.0], np.float32)
    return {
        "points": points,
        "normals": normals,
        "label": np.argmin(biased, axis=1).astype(np.int8),
        "shade": ((0.42 + 0.58 * occ) * (0.72 + 0.28 * wide)).astype(np.float32),
        "bulge": bulge.astype(np.float32),
        "n_low": noise.fbm(points, 6.0, 4, seed=3),
        "n_mid": noise.fbm(points, 19.0, 3, seed=7),
        "n_high": noise.fbm(points, 60.0, 2, seed=9),
        "n_fine": noise.value(points, 210.0, seed=41),
        "veins": noise.ridged(points, 16.0, 3, seed=13),
        "splat": noise.fbm(points + (5.0, 2.0, 9.0), 9.0, 4, seed=29),
        "drip": noise.fbm(points * np.array([1.0, 0.25, 1.0], np.float32), 30.0, 2, seed=31),
        # Folds run mostly along a limb or down the trunk: noise stretched in height, read as thin lines.
        "fold": noise.ridged(points * along, 21.0, 2, seed=47),
        "crease": noise.ridged(points * along + (1.7, 0.0, 3.9), 34.0, 2, seed=53),
        "socket": np.minimum(sculpt.sockets[0].fn(points), sculpt.sockets[1].fn(points)).astype(np.float32),
        "mouth": sculpt.mouth.fn(points).astype(np.float32),
        "shirt_edge": np.abs(sculpt.shirt_region(points)).astype(np.float32),
        "pants_edge": np.abs(sculpt.pants_region(points)).astype(np.float32),
        "wound": sculpt.wound_distance(points),
        "rib_wound": sculpt.wound_distance(points, sculpt.rib_wounds),
    }


def paint(sculpt, fields, palette):
    """Albedo (sRGB, 0..1) of one skin, from the survey of the sculpt."""
    spec = sculpt.spec
    points, label, shade = fields["points"], fields["label"], fields["shade"]
    n_low, n_mid, n_high, n_fine = fields["n_low"], fields["n_mid"], fields["n_high"], fields["n_fine"]
    veins, splat, drip, fold, crease, bulge = fields["veins"], fields["splat"], fields["drip"], fields["fold"], fields["crease"], fields["bulge"]
    hc = sculpt.head_center
    local = points - hc
    count = points.shape[0]
    blood_amount = palette["blood"]
    blood_dark = np.array([0.20, 0.025, 0.02], np.float32)
    blood_wet = np.array([0.36, 0.035, 0.03], np.float32)
    # Ridges catch the light and creases keep the dirt, on cloth and skin alike.
    relief = np.clip(1.0 + 2.2 * np.clip(bulge, -0.12, 0.08), 0.7, 1.16)

    color = np.zeros((count, 3), np.float32)
    skin = np.asarray(palette["skin"], np.float32)
    # Skin: mottled pallor, livid patches, dark veins, bruised extremities.
    base = np.tile(skin, (count, 1))
    # "livid" deepens the bruise-coloured patches (the pale kinds need them to keep their shape in full sun).
    livid = float(palette.get("livid", 0.0))
    bruise = np.array([0.72, 0.78, 0.86], np.float32) * (1.0 - livid) + np.array([0.5, 0.54, 0.68], np.float32) * livid
    base = mix(base, skin * bruise, smooth(0.45 - 0.07 * livid, 0.7, n_low))
    base = mix(base, skin * np.array([1.12, 1.02, 0.86], np.float32), smooth(0.55, 0.8, n_mid) * 0.6)
    base = mix(base, (0.23, 0.2, 0.3), (1.0 - smooth(0.02, 0.085, veins)) * 0.55)
    # Rot: dark, greenish blotches with a hard edge.
    base = mix(base, skin * np.array([0.42, 0.47, 0.36], np.float32), smooth(0.66, 0.7, noise_mix(n_low, n_mid)) * 0.75)
    base *= (0.9 + 0.2 * n_high)[:, None]
    # The cage of the ribs shows through the skin of the chest.
    chest_band = smooth(1.1, 1.16, points[:, 1]) * smooth(1.36, 1.3, points[:, 1]) * smooth(0.02, 0.07, np.abs(points[:, 0])) * smooth(-0.03, 0.03, points[:, 2])
    ribs = 0.5 + 0.5 * np.sin((points[:, 1] + 0.05 * np.abs(points[:, 0])) * math.tau / 0.042)
    base *= (1.0 - 0.2 * chest_band * smooth(0.45, 0.9, ribs))[:, None]
    hands = smooth(0.34, 0.48, np.abs(points[:, 0]))
    base = mix(base, blood_dark, hands * smooth(0.35, 0.6, splat) * 0.85 * blood_amount)
    wound = smooth(0.71, 0.76, splat) * blood_amount
    base = mix(base, blood_wet, wound)
    base = mix(base, (0.09, 0.01, 0.01), smooth(0.79, 0.84, splat) * blood_amount)
    # Bare-chested kinds: "bib" runs blood from the jaw down the chest and belly,
    # "soil" cakes the feet and shins with street dirt.
    bib = float(palette.get("bib", 0.0))
    if bib > 0.0:
        chest = smooth(-0.02, 0.05, points[:, 2]) * smooth(0.9, 1.02, points[:, 1]) * smooth(1.62, 1.5, points[:, 1])
        middle = smooth(0.27, 0.04, np.abs(points[:, 0]))
        # Soaked under the jaw, breaking up into runs and drips toward the belly.
        down = smooth(1.5, 0.98, points[:, 1])
        streak = splat * 0.45 + drip * 0.75 + middle * 0.16
        soaked = smooth(0.25 + 0.56 * down, 0.4 + 0.56 * down, streak)
        base = mix(base, blood_dark, np.clip(chest * (0.35 + 0.65 * middle) * soaked * 0.93 * bib, 0.0, 0.95))
        fresh = smooth(0.5 + 0.42 * down, 0.6 + 0.42 * down, streak)
        base = mix(base, blood_wet, np.clip(chest * middle * fresh * 0.55 * bib, 0.0, 0.6))
    soil = float(palette.get("soil", 0.0))
    if soil > 0.0:
        low = smooth(0.5, 0.03, points[:, 1])
        base = mix(base, (0.21, 0.18, 0.14), np.clip(low * (0.35 + 0.5 * n_mid + 0.25 * n_low) * soil, 0.0, 0.85))
    # Face: sunken sockets, a dark mouth with teeth, blood around the jaw.
    in_head = points[:, 1] > 1.53
    base = mix(base, (0.07, 0.04, 0.05), in_head * (1.0 - smooth(-0.002, 0.014, fields["socket"])) * 0.94)
    mouth = fields["mouth"]
    in_mouth = in_head * (1.0 - smooth(0.0, 0.006, mouth))
    base = mix(base, (0.10, 0.015, 0.02), in_mouth)
    hs = spec["head"]
    lip = np.abs(np.abs(local[:, 1] + 0.086 * hs) - 0.02 * hs)
    teeth = in_mouth * (1.0 - smooth(0.0, 0.0075, lip)) * (local[:, 2] > 0.062 * hs) * (np.sin(local[:, 0] * 520.0) > -0.55)
    base = mix(base, (0.78, 0.72, 0.56), teeth)
    jaw = in_head * smooth(-0.02, -0.07, local[:, 1]) * smooth(0.0, 0.05, local[:, 2])
    base = mix(base, blood_dark, jaw * smooth(0.3, 0.55, splat + drip * 0.3) * 0.9 * blood_amount)
    hair = in_head * smooth(0.035, 0.07, local[:, 1] - local[:, 2] * 0.45) * smooth(0.38, 0.5, n_mid + n_low * 0.4)
    base = mix(base, np.asarray(palette["hair"], np.float32) * (0.75 + 0.5 * n_fine)[:, None], hair * 0.93)
    # Bites: raw meat inside, a bruised and bloody rim, pale ribs in the deep ones.
    bitten = 1.0 - smooth(0.0, 0.009, fields["wound"])
    rim = (1.0 - smooth(0.004, 0.04, fields["wound"])) * (1.0 - bitten)
    base = mix(base, blood_dark, rim * (0.45 + 0.5 * n_mid))
    meat = np.array([0.36, 0.055, 0.045], np.float32) * (0.6 + 0.8 * n_mid)[:, None]
    base = mix(base, meat, bitten)
    in_ribs = 1.0 - smooth(0.0, 0.009, fields["rib_wound"])
    bars = smooth(0.25, 0.6, np.sin(points[:, 1] * math.tau / 0.034))
    base = mix(base, (0.74, 0.68, 0.54), in_ribs * bars * 0.9)
    base *= relief[:, None]
    color[label == SKIN] = base[label == SKIN]

    # Shirt: fabric tone, optional plaid, folds, stains, frayed dark edges and blood down the front.
    shirt = np.tile(np.asarray(palette["shirt"], np.float32), (count, 1))
    if palette["plaid"] > 0.0:
        around = np.arctan2(points[:, 0], points[:, 2] + 0.02)
        bands = (np.sin(points[:, 1] * 95.0) > 0.55) | (np.sin(around * 22.0) > 0.6)
        shirt = mix(shirt, np.asarray(palette["shirt"], np.float32) * 0.45, bands * palette["plaid"])
    shirt *= (0.82 + 0.36 * n_low)[:, None]
    shirt *= cloth_folds(fold, crease, n_fine, 0.3)[:, None]
    shirt = mix(shirt, (0.13, 0.11, 0.08), smooth(0.5, 0.75, n_mid) * 0.55)
    fray = 1.0 - smooth(0.0, 0.018, fields["shirt_edge"])
    shirt = mix(shirt, (0.06, 0.05, 0.04), fray * 0.7)
    front = smooth(0.0, 0.06, points[:, 2]) * smooth(1.02, 1.3, points[:, 1])
    shirt = mix(shirt, blood_dark, front * smooth(0.36, 0.56, splat * 0.7 + drip * 0.45) * 0.9 * blood_amount)
    shirt = mix(shirt, blood_dark, smooth(0.66, 0.72, splat) * blood_amount)
    # Soaked dark around a bite.
    shirt = mix(shirt, blood_dark, (1.0 - smooth(0.014, 0.075, fields["wound"])) * 0.85)
    shirt *= relief[:, None]
    color[label == SHIRT] = shirt[label == SHIRT]

    pants = np.tile(np.asarray(palette["pants"], np.float32), (count, 1))
    pants *= (0.8 + 0.4 * n_low)[:, None]
    pants *= cloth_folds(fold, crease, n_fine, 0.26)[:, None]
    pants = mix(pants, (0.2, 0.17, 0.12), smooth(0.25, 0.0, points[:, 1] - 0.3) * 0.5 + smooth(0.55, 0.8, n_mid) * 0.4)
    # Worn pale at the knees.
    pants = mix(pants, pants * 1.35 + 0.03, smooth(0.07, 0.0, np.abs(points[:, 1] - 0.5)) * smooth(0.0, 0.04, points[:, 2]) * 0.6)
    pants = mix(pants, blood_dark, smooth(0.68, 0.74, splat) * blood_amount)
    pants = mix(pants, blood_dark, (1.0 - smooth(0.012, 0.06, fields["wound"])) * 0.8)
    # A belt under the waistband, and frayed ends where a leg was torn short.
    pants = mix(pants, (0.05, 0.04, 0.035), 1.0 - smooth(0.006, 0.016, np.abs(points[:, 1] - 1.012)))
    pants = mix(pants, (0.06, 0.05, 0.04), (1.0 - smooth(0.0, 0.014, fields["pants_edge"])) * 0.5)
    pants *= relief[:, None]
    color[label == PANTS] = pants[label == PANTS]

    shoes = np.tile(np.asarray(palette["shoes"], np.float32), (count, 1))
    shoes = mix(shoes, (0.22, 0.19, 0.15), smooth(0.05, 0.0, points[:, 1]) * 0.7 + n_mid[:] * 0.2)
    shoes *= relief[:, None]
    color[label == SHOES] = shoes[label == SHOES]

    color *= shade[:, None]
    # Dead eyes: clouded and dull, one of them gone dark. They are lit like the rest of the face, so they
    # no longer shine out of it like lamps.
    eye = label == EYES
    cloudy = np.array([0.43, 0.42, 0.34], np.float32)
    gone = np.array([0.17, 0.05, 0.04], np.float32)
    left = (local[:, 0] > 0.0)[:, None]
    eyes = np.where(left, cloudy, gone) * (0.8 + 0.3 * n_high)[:, None]
    pupil = (np.abs(np.abs(local[:, 0]) - 0.033 * spec["head"]) < 0.0045) & (np.abs(local[:, 1] + 0.008 * spec["head"]) < 0.0045)
    eyes[pupil] *= 0.35
    color[eye] = (eyes * (0.55 + 0.45 * shade[:, None]))[eye]
    return np.clip(color, 0.0, 1.0)


def noise_mix(a, b):
    return a * 0.6 + b * 0.4


def cloth_folds(fold, crease, fine, depth):
    """Multiplier for cloth: dark lines where it creases, a lighter ridge beside them, and the weave."""
    dark = (1.0 - smooth(0.0, 0.07, fold)) * depth + (1.0 - smooth(0.0, 0.05, crease)) * depth * 0.6
    light = smooth(0.1, 0.22, fold) * smooth(0.4, 0.22, fold) * depth * 0.45
    return np.clip(1.0 - dark + light, 0.55, 1.2) * (0.93 + 0.14 * fine)


def bake_textures(sculpt, vertices, faces, uvs, resolution):
    tri, bary = rasterize(uvs, faces, resolution)
    mask = tri >= 0
    face_index = tri[mask]
    weights = bary[mask]
    corners = vertices[faces[face_index]]
    points = np.einsum("ij,ijk->ik", weights, corners).astype(np.float32)
    fields = survey(sculpt, points)
    images = []
    for palette in sculpt.spec["palettes"]:
        color = paint(sculpt, fields, palette)
        image = np.zeros((resolution, resolution, 3), np.float32)
        image[mask] = color
        image = dilate(image, mask)
        # glTF UVs have their origin at the top-left corner.
        images.append(Image.fromarray(np.round(image * 255.0).astype(np.uint8), "RGB"))
    return images


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------
IDENTITY = np.array([0.0, 0.0, 0.0, 1.0])


class Animator:
    """Poses are authored with hip motion, spine eulers and IK targets, then
    converted into local bone rotations."""

    def __init__(self, sculpt):
        self.sculpt = sculpt
        self.sk = sculpt.skeleton
        sk = self.sk
        self.rest_dir = {}
        for side in ("L", "R"):
            self.rest_dir["UpperArm_" + side] = sk.position("LowerArm_" + side) - sk.position("UpperArm_" + side)
            self.rest_dir["LowerArm_" + side] = sk.position("Hand_" + side) - sk.position("LowerArm_" + side)
            self.rest_dir["UpperLeg_" + side] = sk.position("LowerLeg_" + side) - sk.position("UpperLeg_" + side)
            self.rest_dir["LowerLeg_" + side] = sk.position("Foot_" + side) - sk.position("LowerLeg_" + side)
            self.rest_dir["Foot_" + side] = np.array([0.0, -0.25, 1.0])

    def solve(self, pose):
        """pose keys: hips (offset xyz), hips_rot/spine/chest/neck/head (euler deg),
        foot_L/foot_R (ankle target in character space), toe_L/toe_R (foot direction),
        hand_L/hand_R (wrist target relative to the chest joint, chest frame),
        knee/elbow poles, wrist_L/wrist_R (euler)."""
        sk, L = self.sk, self.sculpt.lengths
        rot = {}
        trans = {"Hips": np.asarray(pose.get("hips", (0, 0, 0)), np.float64)}
        rot["Hips"] = rig.quat_euler(*pose.get("hips_rot", (0, 0, 0)))
        rot["Spine"] = rig.quat_euler(*pose.get("spine", (0, 0, 0)))
        rot["Chest"] = rig.quat_euler(*pose.get("chest", (0, 0, 0)))
        rot["Neck"] = rig.quat_euler(*pose.get("neck", (0, 0, 0)))
        rot["Head"] = rig.quat_euler(*pose.get("head", (0, 0, 0)))
        hips_q = rot["Hips"]
        hips_p = sk.position("Hips") + trans["Hips"]
        chest_q = rig.quat_mul(rig.quat_mul(hips_q, rot["Spine"]), rot["Chest"])
        for side, sign in (("L", 1.0), ("R", -1.0)):
            # Legs: targets are in character space; solve there, express in the hips frame.
            hip_world = hips_p + rig.quat_rotate(hips_q, sk.offset("UpperLeg_" + side))
            ankle = np.asarray(pose.get("foot_" + side, sk.position("Foot_" + side)), np.float64)
            pole = np.asarray(pose.get("knee_" + side, (0.12 * sign, 0.0, 1.0)), np.float64)
            knee = rig.two_bone(hip_world, ankle, L["thigh"], L["shin"], pole)
            reach = ankle - hip_world
            limit = L["thigh"] + L["shin"] - 1e-4
            if np.linalg.norm(reach) > limit:
                ankle = hip_world + reach / np.linalg.norm(reach) * limit
            inv = rig.quat_inv(hips_q)
            thigh_dir = rig.quat_rotate(inv, knee - hip_world)
            shin_dir = rig.quat_rotate(inv, ankle - knee)
            a_thigh = rig.quat_between(self.rest_dir["UpperLeg_" + side], thigh_dir)
            a_shin = rig.quat_between(self.rest_dir["LowerLeg_" + side], shin_dir)
            toe = rig.quat_rotate(inv, np.asarray(pose.get("toe_" + side, (0.0, -0.25, 1.0)), np.float64))
            a_foot = rig.quat_between(self.rest_dir["Foot_" + side], toe)
            rot["UpperLeg_" + side] = a_thigh
            rot["LowerLeg_" + side] = rig.quat_mul(rig.quat_inv(a_thigh), a_shin)
            rot["Foot_" + side] = rig.quat_mul(rig.quat_inv(a_shin), a_foot)
            # Arms: wrist targets relative to the shoulder line, in the chest frame.
            shoulder = sk.position("UpperArm_" + side) - sk.position("Chest")
            wrist = np.asarray(pose.get("hand_" + side, shoulder + self.rest_dir["UpperArm_" + side] + self.rest_dir["LowerArm_" + side]), np.float64)
            pole = np.asarray(pose.get("elbow_" + side, (0.5 * sign, -1.0, -0.6)), np.float64)
            elbow = rig.two_bone(shoulder, wrist, L["upper_arm"], L["fore_arm"], pole)
            reach = wrist - shoulder
            limit = L["upper_arm"] + L["fore_arm"] - 1e-4
            if np.linalg.norm(reach) > limit:
                wrist = shoulder + reach / np.linalg.norm(reach) * limit
            a_upper = rig.quat_between(self.rest_dir["UpperArm_" + side], elbow - shoulder)
            a_lower = rig.quat_between(self.rest_dir["LowerArm_" + side], wrist - elbow)
            rot["UpperArm_" + side] = a_upper
            rot["LowerArm_" + side] = rig.quat_mul(rig.quat_inv(a_upper), a_lower)
            rot["Hand_" + side] = rig.quat_euler(*pose.get("wrist_" + side, (0, 0, 0)))
        _ = chest_q
        return rot, trans

    def bake(self, pose_fn, duration, fps=24, loop=False):
        count = max(2, int(round(duration * fps)) + 1)
        times = np.linspace(0.0, duration, count)
        rotations = {name: [] for name in self.sk.names}
        hips = []
        for t in times:
            rot, trans = self.solve(pose_fn(float(t), duration))
            for name in self.sk.names:
                rotations[name].append(rot.get(name, IDENTITY))
            hips.append(self.sk.offset("Hips") + trans["Hips"])
        if loop:
            for name in rotations:
                rotations[name][-1] = rotations[name][0]
            hips[-1] = hips[0]
        # Keep neighbouring keys in the same quaternion hemisphere.
        for name, keys in rotations.items():
            for i in range(1, len(keys)):
                if float(np.dot(keys[i], keys[i - 1])) < 0.0:
                    keys[i] = -keys[i]
        return times, rotations, np.asarray(hips)


def clips(sculpt):
    """Return {name: (pose_fn, duration, loop)} for a spec."""
    sk = sculpt.sk if hasattr(sculpt, "sk") else sculpt.skeleton
    gait = sculpt.spec["gait"]
    foot = {"L": sk.position("Foot_L"), "R": sk.position("Foot_R")}
    shoulder = {side: sk.position("UpperArm_" + side) - sk.position("Chest") for side in ("L", "R")}
    lean = gait["lean"]
    tau = math.tau

    def stance_feet(spread=0.0, forward=(0.0, 0.0)):
        return {
            "foot_L": foot["L"] + np.array([spread, 0.0, forward[0]]),
            "foot_R": foot["R"] + np.array([-spread, 0.0, forward[1]]),
        }

    def step(phase, stride, lift, stance=0.6):
        """Ankle offset (y, z) through one cycle: planted and sliding back, then swinging forward."""
        phase %= 1.0
        if phase < stance:
            s = phase / stance
            return 0.0, stride * (0.5 - s)
        s = (phase - stance) / (1.0 - stance)
        return lift * math.sin(math.pi * s) ** 1.2, stride * (-0.5 + rig.ease(s))

    def walk(t, duration):
        """The stepping gaits (the sprint and the heavy tread). The right leg is the lame one: its step is
        shorter and lower, and the body drops and leans over it each time it has to carry the weight."""
        ph = t / duration
        stride, limp = gait["stride"], gait["limp"]
        lift, stance, arms = gait.get("lift", 0.085), gait.get("stance", 0.6), gait.get("arms", "hang")
        ly, lz = step(ph, stride, lift, stance)
        ry, rz = step(ph + 0.5, stride * (1.0 - limp * 0.35), lift * (1.0 - limp), stance)
        # 1 in the middle of the lame leg's stance, 0 half a cycle away.
        on_bad = (0.5 + 0.5 * math.cos(tau * (ph - 0.5 - stance * 0.5))) ** 1.5
        bob = -0.045 + 0.018 * math.cos(2 * tau * ph) - 0.05 * limp * on_bad
        reach = gait["reach"]
        if arms == "flail":
            # A sprint: low, bent far forward, one arm clawing ahead and beating with the stride, the other dead at its side.
            beat = math.sin(tau * ph)
            return {
                "hips": (0.02 * beat - 0.03 * limp * on_bad, -0.075 + 0.03 * math.cos(2 * tau * ph) - 0.06 * limp * on_bad, 0.0),
                "hips_rot": (lean * 0.5, 7.0 * beat, -3.0 * beat + 6.0 * limp * on_bad),
                "spine": (lean * 0.4, -5.0 * beat, 5.0 * limp * on_bad),
                "chest": (lean * 0.4 + 8.0 * limp * on_bad, -8.0 * beat, 12.0 * limp * on_bad),
                "neck": (-lean * 0.45, 0.0, 4.0 + 12.0 * limp),
                "head": (-lean * 0.5 + 5.0 * math.sin(2 * tau * ph), 5.0 * beat, 6.0 + 16.0 * limp),
                "foot_L": foot["L"] + np.array([0.0, ly, lz]),
                "foot_R": foot["R"] + np.array([-0.04 * limp, ry, rz]),
                "toe_L": (0.0, -0.25 - ly * 5.0, 1.0),
                "toe_R": (-0.5 * limp, -0.25 - ry * 5.0, 1.0),
                "knee_L": (0.1, 0.0, 1.0),
                "knee_R": (-0.1 - 0.4 * limp, 0.0, 1.0),
                "hand_L": shoulder["L"] + np.array([-0.02, -0.10 + 0.13 * beat, 0.42 * reach - 0.07 * beat]),
                "hand_R": shoulder["R"] + np.array([-0.04, -0.44, 0.02 + 0.2 * math.sin(tau * (ph - 0.18))]),
                "wrist_L": (30.0, 0.0, 8.0),
                "wrist_R": (5.0, 0.0, -12.0),
            }
        # A heavy tread: the trunk rolls over each planted foot and the arms swing like weights.
        roll = math.sin(tau * ph)
        return {
            "hips": (0.05 * roll - 0.03 * limp * on_bad, bob, 0.0),
            "hips_rot": (lean * 0.45 + 5.0 * limp * on_bad, 6.0 * roll, -5.0 * roll + 5.0 * limp * on_bad),
            "spine": (lean * 0.4, -4.0 * roll, 3.0 * roll + 4.0 * limp * on_bad),
            "chest": (lean * 0.45 + 6.0 * limp * on_bad, -6.0 * roll, 2.0 * roll + 9.0 * limp * on_bad),
            "neck": (-4.0, 3.0 * math.sin(tau * ph + 0.6), 4.0 + 8.0 * limp),
            "head": (-6.0 + 3.0 * math.sin(2 * tau * ph), 5.0 * math.sin(tau * ph + 1.0), 5.0 + 12.0 * limp),
            "foot_L": foot["L"] + np.array([0.035, ly, lz]),
            "foot_R": foot["R"] + np.array([-0.035 - 0.03 * limp, ry, rz]),
            "toe_L": (0.2, -0.25 - ly * 5.0, 1.0),
            "toe_R": (-0.2 - 0.5 * limp, -0.25 - ry * 4.0, 1.0),
            "knee_R": (-0.12 - 0.4 * limp, 0.0, 1.0),
            "hand_L": shoulder["L"] + np.array([0.07, -0.5, 0.07 - 0.13 * roll]),
            "hand_R": shoulder["R"] + np.array([-0.07, -0.5, 0.07 + 0.13 * roll]),
            "elbow_L": (1.0, -0.6, -0.5),
            "elbow_R": (-1.0, -0.6, -0.5),
            "wrist_L": (12.0, 0.0, 14.0),
            "wrist_R": (12.0, 0.0, -14.0),
        }

    def hobble(style):
        """A lame walk at a hurry. The right leg is the bad one: it takes the weight for a moment, the body
        drops and lurches over it, and it is dragged after (or swung round stiff). The sound leg does the
        work with one long step. While a foot bears weight it does not slide: it moves back under the body
        at exactly the speed the clip covers ground."""
        distance = style["distance"]
        bad_off, good_on, good_off = style["bad_stance"], style["good_on"], style["good_off"]
        bad_lead, good_lead = style["bad_lead"], style["good_lead"]
        bad_step = distance * bad_off
        good_step = distance * (good_off - good_on)
        arms, swing_out, bad_lift = style.get("arms", "reach"), style.get("swing_out", 0.0), style.get("bad_lift", 0.012)
        own_lean, dip, lift = style.get("lean", lean), style.get("dip", 0.045), style.get("lift", 0.1)
        mid_bad, mid_good = bad_off * 0.5, (good_on + good_off) * 0.5
        reach = gait["reach"]

        def pose(t, duration):
            ph = (t / duration) % 1.0
            if ph < bad_off:
                k = ph / bad_off
                rz, ry, rx, drag = bad_lead - bad_step * k, 0.0, 0.0, 0.0
            else:
                k = (ph - bad_off) / (1.0 - bad_off)
                drag = math.sin(math.pi * k)
                rz, ry, rx = bad_lead - bad_step + bad_step * rig.ease(k), bad_lift * drag, -swing_out * drag
            if good_on <= ph < good_off:
                k = (ph - good_on) / (good_off - good_on)
                land, push = max(0.0, 1.0 - k / 0.15), max(0.0, (k - 0.78) / 0.22)
                lz, ly = good_lead - good_step * k, 0.05 * push * push
                toe_l = (0.05, -0.25 + 0.3 * land - 0.9 * push * push, 1.0)
            else:
                k = ((ph - good_off) % 1.0) / (1.0 - (good_off - good_on))
                lz = good_lead - good_step + good_step * rig.ease(k)
                ly = 0.05 * (1.0 - k) ** 2 + lift * math.sin(math.pi * k) ** 1.2
                toe_l = (0.05, -0.25 - 0.9 * (1.0 - k) ** 2 + 0.3 * k * k, 1.0)
            # 1 while the lame leg carries the weight; +1 at the middle of the sound leg's stance.
            on_bad = (0.5 + 0.5 * math.cos(tau * (ph - mid_bad))) ** 1.5
            rise = math.cos(tau * (ph - mid_good))
            turn = math.sin(tau * (ph - mid_good))
            result = {
                # Over the lame foot and low while it bears weight, thrown forward off it, high over the sound one.
                "hips": (-0.035 * math.cos(tau * (ph - mid_bad)) - 0.012, -0.062 + dip * rise - 0.02 * on_bad, 0.035 * math.sin(tau * (ph - mid_bad))),
                "hips_rot": (own_lean * 0.45 + 5.0 * on_bad, 6.0 * turn, 3.0 * on_bad - 1.5),
                "spine": (own_lean * 0.4 + 4.0 * on_bad, -4.0 * turn, 3.0 * on_bad),
                "chest": (own_lean * 0.45 + 5.0 * on_bad, -5.0 * turn, 6.0 * on_bad - 2.0),
                "neck": (-6.0, 4.0 * math.sin(tau * ph + 0.6), 9.0),
                # The head lolls and follows the drop a moment late.
                "head": (-10.0 + 7.0 * math.sin(tau * (ph - mid_bad - 0.12)), 6.0 * math.sin(tau * ph + 1.0), 14.0),
                "foot_L": foot["L"] + np.array([0.0, ly, lz]),
                "foot_R": foot["R"] + np.array([-0.03 + rx, ry, rz]),
                "toe_L": toe_l,
                # Turned out, and scraping on its toes while it is dragged.
                "toe_R": (-0.5, -0.25 - 0.55 * drag, 1.0),
                "knee_R": (-0.45, 0.0, 1.0),
            }
            if arms == "reach":
                # The arm on the sound side gropes ahead; the other hangs dead and swings behind the step.
                result["hand_L"] = shoulder["L"] + np.array([-0.03, -0.12 + 0.04 * math.sin(tau * ph), 0.45 * reach + 0.03 * math.sin(tau * ph + 1.3)])
                result["hand_R"] = shoulder["R"] + np.array([-0.05, -0.47, 0.06 + 0.1 * math.sin(tau * (ph - 0.25))])
                result["wrist_L"] = (25.0, 0.0, 10.0)
                result["wrist_R"] = (10.0, 0.0, -8.0)
            else:
                result["hand_L"] = shoulder["L"] + np.array([0.05, -0.47, 0.04 + 0.08 * math.sin(tau * (ph - 0.1))])
                result["hand_R"] = shoulder["R"] + np.array([-0.06, -0.48, 0.03 + 0.11 * math.sin(tau * (ph - 0.3))])
                result["wrist_L"] = (12.0, 0.0, 10.0)
                result["wrist_R"] = (12.0, 0.0, -10.0)
            return result
        return pose

    def mirrored(pose_fn):
        """The same movement lame in the other leg: left and right change places."""
        def flip(key, value):
            value = tuple(float(v) for v in value)
            if key in ("hips_rot", "spine", "chest", "neck", "head") or key.startswith("wrist_"):
                return (value[0], -value[1], -value[2])
            return (-value[0], value[1], value[2])

        def pose(t, duration):
            out = {}
            for key, value in pose_fn(t, duration).items():
                other = key[:-1] + ("R" if key.endswith("_L") else "L") if key.endswith(("_L", "_R")) else key
                out[other] = flip(key, value)
            return out
        return pose

    def idle(t, duration):
        ph = t / duration
        pose = stance_feet(0.02)
        pose.update({
            "hips": (0.012 * math.sin(tau * ph), -0.035 + 0.006 * math.sin(2 * tau * ph), 0.0),
            "hips_rot": (5.0, 3.0 * math.sin(tau * ph), -2.0),
            "spine": (6.0, 0.0, 2.0 * math.sin(tau * ph)),
            "chest": (8.0, 3.0 * math.sin(tau * ph + 0.5), 3.0),
            "neck": (-4.0, 6.0 * math.sin(tau * ph), 10.0),
            "head": (-6.0, 10.0 * math.sin(tau * ph + 0.8), 12.0 + 3.0 * math.sin(2 * tau * ph)),
            "hand_L": shoulder["L"] + np.array([0.02, -0.46, 0.12 + 0.02 * math.sin(tau * ph)]),
            "hand_R": shoulder["R"] + np.array([-0.05, -0.48, 0.07 + 0.02 * math.sin(tau * ph + 2.0)]),
        })
        return pose

    def attack(t, duration):
        ph = t / duration

        def swing(p):
            """0 wound up, 1 struck: slow raise, fast strike, short hold."""
            p %= 1.0
            if p < 0.45:
                return 1.0 - rig.ease(p / 0.45)
            if p < 0.6:
                return rig.ease((p - 0.45) / 0.15)
            return 1.0

        right, left = swing(ph), swing(ph + 0.5)
        lunge = max(right, left) - 0.5
        pose = stance_feet(0.035, (0.10, -0.12))
        up = np.array([0.0, 0.34, 0.16])
        hit = np.array([0.0, 0.02, 0.50])
        pose.update({
            "hips": (0.0, -0.06, 0.03 + 0.05 * lunge),
            "hips_rot": (8.0 + 6.0 * lunge, 7.0 * (left - right), 0.0),
            "spine": (8.0 + 8.0 * lunge, 5.0 * (left - right), 0.0),
            "chest": (9.0 + 12.0 * lunge, 9.0 * (left - right), 0.0),
            "neck": (-8.0 - 10.0 * lunge, 0.0, 6.0),
            "head": (-12.0 + 18.0 * lunge, 6.0 * (right - left), 8.0),
            "hand_L": shoulder["L"] + np.array([-0.05, 0.0, 0.0]) + up * (1.0 - left) + hit * left,
            "hand_R": shoulder["R"] + np.array([0.05, 0.0, 0.0]) + up * (1.0 - right) + hit * right,
            "elbow_L": (1.0, -0.3, -0.4),
            "elbow_R": (-1.0, -0.3, -0.4),
            "wrist_L": (-30.0 + 50.0 * left, 0.0, 0.0),
            "wrist_R": (-30.0 + 50.0 * right, 0.0, 0.0),
        })
        return pose

    def slam(t, duration):
        """Both fists raised overhead and brought down together; the blow lands at 0.56 of the clip."""
        ph = (t / duration) % 1.0
        if ph < 0.5:
            up = rig.ease(ph / 0.5)
        elif ph < 0.62:
            up = 1.0 - rig.ease((ph - 0.5) / 0.12)
        else:
            up = 0.0
        # Shudder of the impact, dying away while the fists rest on the target.
        ring = math.sin(min(1.0, max(0.0, (ph - 0.62) / 0.2)) * math.pi) if ph >= 0.62 else 0.0
        pose = stance_feet(0.05, (0.12, -0.14))
        overhead = np.array([0.0, 0.37, 0.10])
        struck = np.array([0.0, -0.04, 0.5])
        pose.update({
            "hips": (0.0, -0.07 + 0.02 * up, 0.07 - 0.07 * up),
            "hips_rot": (15.0 - 21.0 * up + 3.0 * ring, 0.0, 0.0),
            "spine": (13.0 - 21.0 * up, 0.0, 0.0),
            "chest": (17.0 - 29.0 * up + 4.0 * ring, 0.0, 0.0),
            "neck": (-10.0 + 6.0 * up, 0.0, 0.0),
            "head": (-6.0 - 16.0 * up + 8.0 * ring, 0.0, 0.0),
            "hand_L": shoulder["L"] + np.array([-0.06, 0.0, 0.0]) + overhead * up + struck * (1.0 - up),
            "hand_R": shoulder["R"] + np.array([0.06, 0.0, 0.0]) + overhead * up + struck * (1.0 - up),
            "elbow_L": (1.0, -0.3, -0.5),
            "elbow_R": (-1.0, -0.3, -0.5),
            "wrist_L": (20.0 - 50.0 * up, 0.0, 0.0),
            "wrist_R": (20.0 - 50.0 * up, 0.0, 0.0),
        })
        return pose

    def hit(t, duration):
        ph = t / duration
        jolt = math.sin(math.pi * min(1.0, ph * 1.6)) * (1.0 - ph * 0.5)
        pose = stance_feet(0.0, (0.06 - 0.1 * jolt, -0.08 - 0.06 * jolt))
        pose.update({
            "hips": (0.02 * jolt, -0.05 - 0.02 * jolt, -0.07 * jolt),
            "hips_rot": (6.0 - 14.0 * jolt, 10.0 * jolt, 4.0 * jolt),
            "spine": (5.0 - 14.0 * jolt, 8.0 * jolt, 0.0),
            "chest": (6.0 - 18.0 * jolt, 14.0 * jolt, 5.0 * jolt),
            "neck": (-4.0 - 12.0 * jolt, 0.0, 8.0),
            "head": (-8.0 - 22.0 * jolt, -10.0 * jolt, 12.0),
            "hand_L": shoulder["L"] + np.array([0.10 * jolt, -0.2 - 0.1 * jolt, 0.36 - 0.3 * jolt]),
            "hand_R": shoulder["R"] + np.array([-0.16 * jolt, -0.45 + 0.2 * jolt, 0.08 - 0.12 * jolt]),
        })
        return pose

    def death_back(t, duration):
        fall = rig.ease(min(1.0, t / 0.85))
        settle = rig.ease(min(1.0, max(0.0, (t - 0.85) / 0.25)))
        buckle = math.sin(math.pi * min(1.0, t / 0.6))
        hips_y = -0.83 * fall ** 1.6 + 0.02 * math.sin(math.pi * settle)
        hips_z = -0.42 * fall
        pitch = -86.0 * fall ** 1.35
        heel = 0.085 + 0.02
        pose = {
            "hips": (0.03 * fall, hips_y, hips_z),
            "hips_rot": (pitch, 8.0 * fall, 4.0 * fall),
            "spine": (-10.0 * buckle + 4.0 * fall, 0.0, 3.0 * fall),
            "chest": (-16.0 * buckle + 2.0 * fall, 6.0 * fall, 0.0),
            "neck": (-20.0 * buckle - 6.0 * fall, 0.0, 10.0),
            "head": (-24.0 * buckle - 10.0 * fall, 20.0 * fall, 12.0),
            # Feet stay near where they stood, then slide out as the body lands.
            "foot_L": foot["L"] + np.array([0.05 * fall, (heel - 0.085) * fall, 0.18 * fall]),
            "foot_R": foot["R"] + np.array([-0.07 * fall, (heel - 0.085) * fall + 0.1 * buckle * (1.0 - fall), 0.05 * fall]),
            "toe_L": (0.3 * fall, 1.0 * fall - 0.25 * (1.0 - fall), 1.0 - 0.6 * fall),
            "toe_R": (-0.4 * fall, 1.0 * fall - 0.25 * (1.0 - fall), 1.0 - 0.6 * fall),
            "knee_L": (0.3, 0.6, 1.0),
            "knee_R": (-0.5, 0.6, 1.0),
            "hand_L": shoulder["L"] + np.array([0.02 + 0.30 * fall, -0.25 + 0.42 * buckle - 0.02 * fall, 0.30 - 0.36 * fall]),
            "hand_R": shoulder["R"] + np.array([-0.05 - 0.34 * fall, -0.45 + 0.5 * buckle + 0.22 * fall, 0.08 - 0.12 * fall]),
            "elbow_L": (1.0, -0.2, -0.8),
            "elbow_R": (-1.0, -0.2, -0.8),
        }
        return pose

    def death_front(t, duration):
        kneel = rig.ease(min(1.0, t / 0.45))
        fall = rig.ease(min(1.0, max(0.0, (t - 0.3) / 0.6)))
        hips_y = -0.50 * kneel - 0.33 * fall
        hips_z = 0.10 * kneel + 0.38 * fall
        pitch = 14.0 * kneel + 70.0 * fall
        back = np.array([0.0, 0.0, -0.30 * kneel - 0.42 * fall])
        pose = {
            "hips": (-0.02 * fall, hips_y, hips_z),
            "hips_rot": (pitch, -6.0 * fall, -3.0 * fall),
            "spine": (8.0 * kneel - 2.0 * fall, 0.0, 0.0),
            "chest": (12.0 * kneel - 6.0 * fall, -8.0 * fall, 0.0),
            "neck": (10.0 * kneel - 20.0 * fall, 0.0, 6.0),
            "head": (14.0 * kneel - 30.0 * fall, 35.0 * fall, 8.0),
            "foot_L": foot["L"] + back + np.array([0.04 * fall, 0.03 * kneel, 0.0]),
            "foot_R": foot["R"] + back * 0.8 + np.array([-0.06 * fall, 0.03 * kneel, 0.0]),
            "toe_L": (0.0, -0.25 - 0.9 * kneel, 1.0 - 1.6 * kneel),
            "toe_R": (0.0, -0.25 - 0.9 * kneel, 1.0 - 1.6 * kneel),
            "knee_L": (0.25, -0.2, 1.0),
            "knee_R": (-0.25, -0.2, 1.0),
            "hand_L": shoulder["L"] + np.array([0.06 + 0.12 * fall, -0.30 + 0.34 * fall, 0.30 + 0.05 * fall]),
            "hand_R": shoulder["R"] + np.array([-0.08 - 0.16 * fall, -0.42 + 0.30 * fall, 0.10 + 0.16 * fall]),
            "elbow_L": (1.0, -0.4, -0.2),
            "elbow_R": (-1.0, -0.4, -0.2),
        }
        return pose

    walks = {}
    if "walks" in gait:
        for clip, style in gait["walks"].items():
            walks[clip] = (hobble(style), gait["period"], True)
    else:
        walks["walk"] = (walk, gait["period"], True)
    for clip in list(walks):
        walks[clip + "_m"] = (mirrored(walks[clip][0]), walks[clip][1], True)
    return {
        **walks,
        "idle": (idle, 2.4, True),
        "attack": (slam if sculpt.spec.get("attack", "claw") == "slam" else attack, 1.1, True),
        "hit": (hit, 0.42, False),
        "death_back": (death_back, 1.25, False),
        "death_front": (death_front, 1.05, False),
    }


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------
def png_bytes(image):
    buffer = io.BytesIO()
    image.save(buffer, "PNG", optimize=True)
    return buffer.getvalue()


def build(name, draft=False):
    started = time.time()
    spec = SPECS[name]
    sculpt = Sculpt(spec)
    vertices, faces, is_head, raw = build_mesh(sculpt, draft)
    mapping, faces_uv, uvs = unwrap(sculpt, vertices, faces, is_head, spec["texture"])
    positions = vertices[mapping]
    head_flags = is_head[mapping]
    normals = sdf.gradient(sculpt.total, positions, 0.004)
    joints, weights = skin_weights(sculpt, positions, head_flags)
    resolution = spec["texture"] // 2 if draft else spec["texture"]
    textures = bake_textures(sculpt, positions, faces_uv, uvs, resolution)
    os.makedirs(MODEL_DIR, exist_ok=True)
    os.makedirs(TEXTURE_DIR, exist_ok=True)
    for index, image in enumerate(textures):
        image.save(os.path.join(TEXTURE_DIR, "zombie_%s_%s.png" % (name, "abcdefgh"[index])), optimize=True)

    scale = spec["scale"]
    glb = GLB()
    # The game takes its skins from the PNG files; the copy inside the model is a small one, for viewers.
    texture = glb.image(png_bytes(textures[0].resize((384, 384), Image.LANCZOS)), "zombie_%s_a" % name)
    material = glb.material("zombie_%s" % name, (1, 1, 1, 1), 0.0, 0.86, texture)
    sk = sculpt.skeleton
    root = glb.node("Zombie_" + name)
    joint_nodes = []
    for i, bone in enumerate(sk.names):
        parent = root if sk.parents[i] < 0 else joint_nodes[sk.parents[i]]
        joint_nodes.append(glb.node(bone, translation=sk.offset(bone) * scale, parent=parent))
    inverse = sk.inverse_bind()
    inverse[:, :3, 3] *= scale
    skin = glb.skin("ZombieSkin", joint_nodes, inverse, joint_nodes[0])
    mesh = glb.mesh("Zombie_%s_mesh" % name, [{
        "positions": positions * scale, "normals": normals, "uvs": uvs, "indices": faces_uv,
        "joints": joints, "weights": weights, "material": material,
    }])
    glb.node("Body", mesh=mesh, skin=skin, parent=root)
    animator = Animator(sculpt)
    report = []
    for clip, (pose_fn, duration, loop) in clips(sculpt).items():
        times, rotations, hips = animator.bake(pose_fn, duration, 24, loop)
        tracks = [(joint_nodes[sk.index("Hips")], "translation", times, hips * scale)]
        for bone, keys in rotations.items():
            if bone == "Root":
                continue
            tracks.append((joint_nodes[sk.index(bone)], "rotation", times, np.asarray(keys)))
        glb.animation(clip, tracks)
        report.append("%s %.2fs" % (clip, duration))
    path = os.path.join(MODEL_DIR, "zombie_%s.glb" % name)
    size = glb.write(path)
    height = float(positions[:, 1].max() * scale)
    print("%s: %d sculpt triangles -> %d triangles, %d vertices, %d bones, height %.2f m, texture %dpx x%d, %d KB, %.1fs" % (
        name, raw, faces_uv.shape[0], positions.shape[0], len(sk.names), height, resolution, len(textures), size // 1024, time.time() - started))
    print("  clips:", ", ".join(report))
    gait = spec["gait"]
    if "walks" in gait:
        speeds = ", ".join("%s %.2f" % (clip, style["distance"] / gait["period"] * scale) for clip, style in gait["walks"].items())
    else:
        speeds = "walk %.2f" % (gait["stride"] / (gait.get("stance", 0.6) * gait["period"]) * scale)
    shoulder = float(np.abs(positions[positions[:, 1] > 1.3][:, 0]).max() * scale) * 2.0
    print("  ground speed without sliding (m/s): %s; shoulder width %.2f m, head centre %.2f m" % (speeds, shoulder, sculpt.head_center[1] * scale))
    return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    parser.add_argument("--draft", action="store_true", help="coarse sculpt and half-size textures for quick iteration")
    args = parser.parse_args()
    names = [n for n in args.only.split(",") if n] or list(SPECS)
    for name in names:
        build(name, args.draft)


if __name__ == "__main__":
    main()
