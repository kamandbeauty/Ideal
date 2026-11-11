#!/usr/bin/env python3
"""Author the explosive weapons: the RPG launcher, its rocket and the hand grenade.

Writes
    assets/models/weapons/rpg_launcher.glb     shoulder launcher with a loaded round (node Warhead)
    assets/models/weapons/rocket.glb           the round in flight
    assets/models/weapons/frag_grenade.glb     the thrown grenade

All three look down -Z (the engine's forward), so no scene needs a half-turn.
Metres, Y up. The launcher's origin lies on the tube axis at the shoulder.

    python3 tools/build_weapons.py

Requires numpy.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from assetlib.meshkit import Builder, rot_x  # noqa: E402

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(PROJECT, "assets", "models", "weapons")

FORWARD = (0.0, 0.0, -1.0)

# Launcher stations along the tube, metres (z grows toward the gunner's back).
VENTURI_Z = 0.50
MUZZLE_Z = -0.47
TUBE_R = 0.034
WARHEAD_R = 0.054
WARHEAD_TIP_Z = -1.02


def materials(b):
    # The same names and values as the mounted gun, so both weapons read as one kit.
    b.material("Weapon steel", (0.075, 0.082, 0.085, 1.0), metallic=0.88, roughness=0.48)
    b.material("Weapon edge", (0.18, 0.19, 0.19, 1.0), metallic=0.9, roughness=0.38)
    b.material("Weapon olive", (0.105, 0.125, 0.082, 1.0), metallic=0.22, roughness=0.7)
    b.material("Weapon grip", (0.025, 0.027, 0.026, 1.0), metallic=0.02, roughness=0.92)
    b.material("Weapon wood", (0.2, 0.105, 0.045, 1.0), metallic=0.0, roughness=0.62)
    b.material("Black bore", (0.008, 0.012, 0.011, 1.0), metallic=0.1, roughness=0.88)
    b.material("Warhead", (0.15, 0.2, 0.09, 1.0), metallic=0.3, roughness=0.55)
    b.material("Warhead band", (0.5, 0.36, 0.08, 1.0), metallic=0.55, roughness=0.45)


def lathe(b, node, material, profile, segments=18, color=(1, 1, 1), cap_start=False, cap_end=False):
    """Stack of frusta along -Z through (z, radius) stations given from back to front."""
    for index in range(len(profile) - 1):
        z0, r0 = profile[index]
        z1, r1 = profile[index + 1]
        if abs(z0 - z1) < 1e-6:
            continue
        b.cylinder(node, material, (0.0, 0.0, z0), r0, z0 - z1, segments=segments, color=color, top_radius=r1, caps=False, axis=FORWARD)
    if cap_start:
        disc(b, node, material, profile[0][0], profile[0][1], segments, color, facing_back=True)
    if cap_end:
        disc(b, node, material, profile[-1][0], profile[-1][1], segments, color, facing_back=False)


def disc(b, node, material, z, radius, segments, color, facing_back):
    # A zero-height frustum would have no normal; a thin one closes the end cleanly.
    thickness = 0.0015
    start = z + (thickness if facing_back else 0.0)
    b.cylinder(node, material, (0.0, 0.0, start), radius if not facing_back else 0.0005, thickness, segments=segments, color=color,
               top_radius=0.0005 if not facing_back else radius, caps=False, axis=FORWARD)


def warhead(b, node, muzzle_z, neck=0.1):
    """The PG-7 style round: thin neck, swelling cone, long ogive and a fuze tip."""
    z = muzzle_z + 0.03
    lathe(b, node, "Weapon steel", [(z, 0.02), (z - neck - 0.03, 0.02)], 14)
    z -= neck + 0.03
    lathe(b, node, "Warhead", [(z, 0.02), (z - 0.1, WARHEAD_R)], 20, color=(0.86, 0.86, 0.86))
    z -= 0.1
    lathe(b, node, "Warhead band", [(z, WARHEAD_R + 0.001), (z - 0.022, WARHEAD_R + 0.001)], 20)
    z -= 0.022
    lathe(b, node, "Warhead", [(z, WARHEAD_R), (z - 0.035, WARHEAD_R * 0.97), (z - 0.13, WARHEAD_R * 0.76), (z - 0.22, WARHEAD_R * 0.46),
                               (z - 0.265, WARHEAD_R * 0.3)], 20)
    z -= 0.265
    lathe(b, node, "Weapon edge", [(z, WARHEAD_R * 0.3), (z - 0.03, 0.013), (z - 0.05, 0.007)], 12, cap_end=True)
    return z - 0.05


def build_launcher():
    b = Builder(seed=7)
    materials(b)
    tube = "Tube"
    # Flared venturi, then the tube proper.
    lathe(b, tube, "Weapon steel", [(VENTURI_Z, 0.062), (VENTURI_Z - 0.03, 0.058), (VENTURI_Z - 0.14, TUBE_R + 0.002)], 20)
    lathe(b, tube, "Black bore", [(VENTURI_Z - 0.004, 0.056), (VENTURI_Z - 0.12, 0.012)], 16, cap_end=True)
    lathe(b, tube, "Weapon olive", [(VENTURI_Z - 0.14, TUBE_R), (MUZZLE_Z + 0.03, TUBE_R)], 20, color=(0.92, 0.92, 0.92))
    lathe(b, tube, "Weapon steel", [(MUZZLE_Z + 0.03, TUBE_R + 0.004), (MUZZLE_Z, TUBE_R + 0.004)], 20)
    lathe(b, tube, "Black bore", [(MUZZLE_Z + 0.002, TUBE_R + 0.003), (MUZZLE_Z + 0.001, 0.02)], 16)
    # Wooden heat shield where the cheek and the shoulder rest, with steel clamps.
    lathe(b, tube, "Weapon wood", [(0.3, TUBE_R + 0.004), (0.285, TUBE_R + 0.014), (0.02, TUBE_R + 0.014), (0.005, TUBE_R + 0.004)], 20)
    for z in (0.262, 0.15, 0.04):
        lathe(b, tube, "Weapon steel", [(z + 0.008, TUBE_R + 0.0165), (z - 0.008, TUBE_R + 0.0165)], 20)
    # Trigger group and the two grips.
    b.box(tube, "Weapon steel", (0.0, -TUBE_R - 0.022, -0.17), (0.03, 0.044, 0.15))
    b.box(tube, "Weapon steel", (0.0, -TUBE_R - 0.012, -0.3), (0.022, 0.024, 0.07))
    grip = rot_x(-14.0)
    b.box(tube, "Weapon wood", (0.0, -TUBE_R - 0.095, -0.145), (0.032, 0.115, 0.046), basis=grip)
    b.box(tube, "Weapon wood", (0.0, -TUBE_R - 0.062, 0.05), (0.032, 0.105, 0.044), basis=grip)
    b.box(tube, "Weapon steel", (0.0, -TUBE_R - 0.072, -0.215), (0.008, 0.008, 0.07))
    b.box(tube, "Weapon steel", (0.0, -TUBE_R - 0.052, -0.252), (0.008, 0.045, 0.008))
    b.box(tube, "Weapon edge", (0.0, -TUBE_R - 0.05, -0.205), (0.006, 0.03, 0.008), basis=rot_x(18.0))
    # Iron sights along the top.
    b.box(tube, "Weapon steel", (0.0, TUBE_R + 0.008, -0.38), (0.02, 0.016, 0.03))
    b.box(tube, "Weapon steel", (0.0, TUBE_R + 0.034, -0.38), (0.005, 0.04, 0.008))
    b.box(tube, "Weapon steel", (0.0, TUBE_R + 0.008, -0.1), (0.022, 0.016, 0.03))
    b.box(tube, "Weapon steel", (0.0, TUBE_R + 0.036, -0.1), (0.026, 0.042, 0.005))
    # Optical sight on its bracket, left of the tube where the right eye finds it.
    b.box(tube, "Weapon steel", (-TUBE_R - 0.012, 0.012, -0.07), (0.02, 0.05, 0.09))
    b.cylinder(tube, "Weapon steel", (-TUBE_R - 0.028, 0.056, 0.02), 0.019, 0.17, segments=14, axis=FORWARD)
    b.cylinder(tube, "Weapon grip", (-TUBE_R - 0.028, 0.056, 0.05), 0.024, 0.034, segments=14, axis=FORWARD)
    b.cylinder(tube, "Weapon edge", (-TUBE_R - 0.028, 0.056, -0.15), 0.022, 0.012, segments=14, axis=FORWARD)
    b.box(tube, "Weapon steel", (-TUBE_R - 0.028, 0.086, -0.05), (0.016, 0.022, 0.03))
    # Sling swivels.
    for z in (0.33, -0.33):
        b.box(tube, "Weapon steel", (0.0, -TUBE_R - 0.01, z), (0.012, 0.02, 0.02))
    # The loaded round has its own node so the game can hide it after a shot.
    b.pivot("Warhead", (0.0, 0.0, MUZZLE_Z))
    tip = warhead(b, "Warhead", MUZZLE_Z)
    b.marker("Muzzle", (0.0, 0.0, MUZZLE_Z))
    b.marker("Venturi", (0.0, 0.0, VENTURI_Z))
    b.marker("Tip", (0.0, 0.0, tip))
    size, report = b.export(os.path.join(OUT, "rpg_launcher.glb"), "RpgLauncher")
    return "rpg_launcher.glb", size, b.triangle_count(), report


def build_rocket():
    """The round in flight: origin at its middle, nose toward -Z."""
    b = Builder(seed=8)
    materials(b)
    body = "Body"
    tip = warhead(b, body, 0.0, neck=0.08)
    # Tail boom, motor nozzle ring and four fins.
    lathe(b, body, "Weapon steel", [(0.53, 0.013), (0.03, 0.016)], 10, cap_start=True)
    lathe(b, body, "Weapon edge", [(0.19, 0.024), (0.14, 0.024)], 12)
    for index in range(4):
        angle = math.radians(45.0 + 90.0 * index)
        direction = np.array([math.cos(angle), math.sin(angle), 0.0])
        side = np.array([-math.sin(angle), math.cos(angle), 0.0])
        frame = np.stack([side, direction, np.array([0.0, 0.0, 1.0])], axis=1)
        b.box(body, "Weapon olive", (direction[0] * 0.062, direction[1] * 0.062, 0.46), (0.003, 0.1, 0.13), basis=frame)
    b.marker("Exhaust", (0.0, 0.0, 0.55))
    b.marker("Nose", (0.0, 0.0, tip))
    size, report = b.export(os.path.join(OUT, "rocket.glb"), "Rocket")
    return "rocket.glb", size, b.triangle_count(), report


def build_grenade():
    """Egg-shaped fragmentation grenade standing on Y, origin at its middle."""
    b = Builder(seed=9)
    materials(b)
    body = "Body"
    up = (0.0, 1.0, 0.0)
    stations = [(-0.046, 0.012), (-0.036, 0.024), (-0.016, 0.031), (0.006, 0.031), (0.026, 0.024), (0.038, 0.014)]
    for index in range(len(stations) - 1):
        y0, r0 = stations[index]
        y1, r1 = stations[index + 1]
        shade = 0.82 if index % 2 else 1.0
        b.cylinder(body, "Weapon olive", (0.0, y0, 0.0), r0, y1 - y0, segments=12, color=(shade, shade, shade), top_radius=r1,
                   caps=index == 0, axis=up)
    b.cylinder(body, "Weapon steel", (0.0, 0.038, 0.0), 0.012, 0.022, segments=10, axis=up)
    b.box(body, "Weapon edge", (0.0, 0.062, 0.006), (0.012, 0.006, 0.03))
    b.box(body, "Weapon edge", (0.0, 0.02, 0.032), (0.012, 0.075, 0.004), basis=rot_x(-9.0))
    b.cylinder(body, "Weapon edge", (-0.02, 0.05, 0.0), 0.011, 0.003, segments=10, axis=(1.0, 0.0, 0.0))
    size, report = b.export(os.path.join(OUT, "frag_grenade.glb"), "FragGrenade")
    return "frag_grenade.glb", size, b.triangle_count(), report


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, size, triangles, report in (build_launcher(), build_rocket(), build_grenade()):
        print("%-20s %7d bytes  %5d triangles  %s" % (name, size, triangles, ", ".join("%s:%d" % (n, t) for n, t, _p in report)))


if __name__ == "__main__":
    main()
