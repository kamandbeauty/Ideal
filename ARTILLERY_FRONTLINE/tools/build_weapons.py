#!/usr/bin/env python3
"""Author the weapons built for this game: the six-barrel rotary gun on its mount,
the RPG launcher, its rocket and the hand grenade.

Writes
    assets/models/weapons/rotary_gun.glb       mounted six-barrel gun (nodes Mount, BarrelPivot, Rotor, AmmoCan)
    assets/models/weapons/rpg_launcher.glb     shoulder launcher with a loaded round (node Warhead)
    assets/models/weapons/rocket.glb           the round in flight
    assets/models/weapons/frag_grenade.glb     the thrown grenade

All of them look down -Z (the engine's forward), so no scene needs a half-turn.
Metres, Y up. The launcher's origin lies on the tube axis at the shoulder; the
rotary gun stands on the foot of its mount with its trunnions 1.15 m up, like
the twin gun it can replace.

    python3 tools/build_weapons.py

Requires numpy.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from assetlib.meshkit import Builder, rot_x, rot_z  # noqa: E402

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


def lathe(b, node, material, profile, segments=18, color=(1, 1, 1), cap_start=False, cap_end=False, at=(0.0, 0.0)):
    """Stack of frusta along -Z through (z, radius) stations given from back to front, about the axis x, y = `at`."""
    for index in range(len(profile) - 1):
        z0, r0 = profile[index]
        z1, r1 = profile[index + 1]
        if abs(z0 - z1) < 1e-6:
            continue
        b.cylinder(node, material, (at[0], at[1], z0), r0, z0 - z1, segments=segments, color=color, top_radius=r1, caps=False, axis=FORWARD)
    if cap_start:
        disc(b, node, material, profile[0][0], profile[0][1], segments, color, facing_back=True, at=at)
    if cap_end:
        disc(b, node, material, profile[-1][0], profile[-1][1], segments, color, facing_back=False, at=at)


def disc(b, node, material, z, radius, segments, color, facing_back, at=(0.0, 0.0)):
    # A zero-height frustum would have no normal; a thin one closes the end cleanly.
    thickness = 0.0015
    start = z + (thickness if facing_back else 0.0)
    b.cylinder(node, material, (at[0], at[1], start), radius if not facing_back else 0.0005, thickness, segments=segments, color=color,
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


# The rotary gun, metres. z grows toward the gunner. It is drawn heavier than a rifle-calibre gun of the
# kind: the gunner looks down on it from behind, and thin barrels would be lost against the street.
PIVOT_Y = 1.15          # trunnions above the foot of the mount, as on the twin gun
BORE_Y = -0.02          # the bore lies just under the trunnion axis: the eye, 0.43 m above it, sees along the barrels
CLUSTER_R = 0.06        # the six bores lie on a circle of this radius
BARREL_R = 0.019
HOUSING_R = 0.12
HOUSING_BACK = 0.28
HOUSING_FRONT = -0.22
GUN_MUZZLE_Z = -1.36


def ring(b, node, material, center, inner, outer, depth, segments=16, color=(1, 1, 1)):
    """A flat ring standing across the bore axis, `depth` thick, seen from either side."""
    cx, cy, cz = center
    back, front = cz + depth * 0.5, cz - depth * 0.5
    for index in range(segments):
        a0, a1 = math.tau * index / segments, math.tau * (index + 1) / segments
        d0, d1 = np.array([math.cos(a0), math.sin(a0), 0.0]), np.array([math.cos(a1), math.sin(a1), 0.0])
        middle = np.array([cx, cy, 0.0])
        i0, i1, o0, o1 = middle + d0 * inner, middle + d1 * inner, middle + d0 * outer, middle + d1 * outer
        z_back, z_front = np.array([0.0, 0.0, back]), np.array([0.0, 0.0, front])
        b.quad(node, material, [i0 + z_back, o0 + z_back, o1 + z_back, i1 + z_back], color)
        b.quad(node, material, [i1 + z_front, o1 + z_front, o0 + z_front, i0 + z_front], color)
        b.quad(node, material, [o0 + z_back, o0 + z_front, o1 + z_front, o1 + z_back], color)
        b.quad(node, material, [i0 + z_front, i0 + z_back, i1 + z_back, i1 + z_front], color)


def build_rotary_gun():
    """A six-barrel rotary gun on a pedestal: the barrels turn about the bore axis (node Rotor), the gun
    tips on its trunnions (node BarrelPivot), the belt box hangs on the left (node AmmoCan)."""
    b = Builder(seed=11)
    materials(b)
    b.material("Weapon brass", (0.46, 0.33, 0.12, 1.0), metallic=0.85, roughness=0.34)
    mount, gun, rotor, can = "Mount", "BarrelPivot", "Rotor", "AmmoCan"
    up, across = (0.0, 1.0, 0.0), (1.0, 0.0, 0.0)
    axis_y = PIVOT_Y + BORE_Y
    bore = (0.0, axis_y)
    arm_x = 0.215

    # The mount: a flanged pedestal, a bearing, and the fork that carries the trunnions.
    b.cylinder(mount, "Weapon olive", (0.0, 0.0, 0.0), 0.22, 0.035, segments=20, axis=up)
    b.cylinder(mount, "Weapon olive", (0.0, 0.035, 0.0), 0.22, 0.04, segments=20, top_radius=0.11, axis=up)
    b.cylinder(mount, "Weapon olive", (0.0, 0.075, 0.0), 0.09, 0.62, segments=16, color=(0.9, 0.9, 0.9), axis=up, caps=False)
    for index in range(6):
        angle = math.tau * index / 6.0
        b.cylinder(mount, "Weapon steel", (math.cos(angle) * 0.18, 0.035, math.sin(angle) * 0.18), 0.015, 0.018, segments=6, axis=up)
    b.cylinder(mount, "Weapon steel", (0.0, 0.695, 0.0), 0.125, 0.07, segments=20, axis=up)
    b.cylinder(mount, "Weapon edge", (0.0, 0.765, 0.0), 0.105, 0.02, segments=20, axis=up)
    b.box(mount, "Weapon olive", (0.0, 0.82, 0.0), (arm_x * 2.0 + 0.04, 0.07, 0.14))
    for sign in (-1.0, 1.0):
        b.box(mount, "Weapon olive", (arm_x * sign, 1.02, 0.0), (0.04, 0.37, 0.13))
        b.box(mount, "Weapon olive", ((arm_x - 0.045) * sign, 0.875, 0.0), (0.07, 0.05, 0.11), basis=rot_z(-40.0 * sign))
        b.cylinder(mount, "Weapon steel", ((arm_x + 0.02) * sign, PIVOT_Y, 0.0), 0.055, 0.024, segments=14, axis=(sign, 0.0, 0.0))
        b.cylinder(mount, "Weapon edge", ((arm_x + 0.044) * sign, PIVOT_Y, 0.0), 0.024, 0.012, segments=8, axis=(sign, 0.0, 0.0))

    # The gun proper tips about the trunnion axis, which passes through its housing.
    b.pivot(gun, (0.0, PIVOT_Y, 0.0))
    b.cylinder(gun, "Weapon steel", (-arm_x + 0.02, PIVOT_Y, 0.0), 0.034, (arm_x - 0.02) * 2.0, segments=12, axis=across)
    for sign in (-1.0, 1.0):
        b.cylinder(gun, "Weapon edge", ((HOUSING_R - 0.005) * sign, PIVOT_Y, 0.0), 0.06, 0.03, segments=14, axis=(sign, 0.0, 0.0))
    # Housing: a drum with a band at either end and cooling ribs between.
    lathe(b, gun, "Weapon steel", [(HOUSING_BACK, HOUSING_R), (HOUSING_FRONT, HOUSING_R)], 22, at=bore)
    lathe(b, gun, "Weapon edge", [(HOUSING_BACK + 0.016, HOUSING_R + 0.008), (HOUSING_BACK - 0.026, HOUSING_R + 0.008)], 22, cap_start=True, at=bore)
    lathe(b, gun, "Weapon edge", [(HOUSING_FRONT + 0.034, HOUSING_R + 0.008), (HOUSING_FRONT, HOUSING_R + 0.008)], 22, at=bore)
    for z in (0.19, 0.115, -0.07, -0.145):
        lathe(b, gun, "Weapon edge", [(z + 0.008, HOUSING_R + 0.004), (z - 0.008, HOUSING_R + 0.004)], 22, at=bore)
    lathe(b, gun, "Weapon steel", [(HOUSING_FRONT, HOUSING_R + 0.008), (HOUSING_FRONT - 0.04, 0.095)], 22, cap_end=True, at=bore)
    # Feeder and delinker high on the left, where the belt comes in.
    b.box(gun, "Weapon steel", (-0.118, axis_y + 0.085, -0.02), (0.1, 0.13, 0.22), basis=rot_z(22.0))
    b.box(gun, "Weapon edge", (-0.147, axis_y + 0.152, -0.02), (0.085, 0.012, 0.18), basis=rot_z(22.0))
    # Drive motor high on the right, its gearbox, and the cable that feeds it.
    b.cylinder(gun, "Weapon edge", (0.125, axis_y + 0.09, 0.19), 0.055, 0.25, segments=14, axis=FORWARD)
    b.cylinder(gun, "Weapon steel", (0.125, axis_y + 0.09, 0.22), 0.036, 0.032, segments=12, axis=FORWARD)
    b.cylinder(gun, "Weapon steel", (0.125, axis_y + 0.09, -0.06), 0.062, 0.05, segments=14, axis=FORWARD)
    b.cylinder(gun, "Weapon grip", (0.125, axis_y + 0.09, 0.31), 0.013, 0.1, segments=8, axis=FORWARD)
    b.cylinder(gun, "Weapon grip", (0.125, axis_y + 0.095, 0.31), 0.013, 0.2, segments=8, axis=(0.55, -1.0, 0.1))
    # Spade grips and the thumb trigger between them.
    b.box(gun, "Weapon steel", (0.0, axis_y, 0.35), (0.04, 0.04, 0.17))
    b.box(gun, "Weapon steel", (0.0, axis_y, 0.425), (0.26, 0.028, 0.028))
    for sign in (-1.0, 1.0):
        b.cylinder(gun, "Weapon grip", (0.13 * sign, axis_y - 0.09, 0.425), 0.023, 0.18, segments=10, axis=up)
        b.cylinder(gun, "Weapon steel", (0.13 * sign, axis_y - 0.1, 0.425), 0.028, 0.012, segments=10, axis=up)
        b.cylinder(gun, "Weapon steel", (0.13 * sign, axis_y + 0.088, 0.425), 0.028, 0.012, segments=10, axis=up)
    b.box(gun, "Weapon brass", (0.0, axis_y + 0.002, 0.446), (0.085, 0.05, 0.014))
    # Sight rail along the top, a low ring at the back of it and a post at the front.
    b.box(gun, "Weapon steel", (0.0, axis_y + HOUSING_R + 0.008, 0.03), (0.04, 0.016, 0.44))
    for z in (0.2, 0.12, 0.04, -0.04, -0.12):
        b.box(gun, "Weapon edge", (0.0, axis_y + HOUSING_R + 0.018, z), (0.046, 0.004, 0.03))
    b.box(gun, "Weapon steel", (0.0, axis_y + HOUSING_R + 0.024, 0.2), (0.05, 0.016, 0.05))
    ring(b, gun, "Weapon steel", (0.0, axis_y + HOUSING_R + 0.058, 0.2), 0.02, 0.028, 0.012, 14)
    b.box(gun, "Weapon steel", (0.0, axis_y + HOUSING_R + 0.036, HOUSING_FRONT + 0.03), (0.01, 0.045, 0.014))
    # The chute that carries the belt from the box up into the feeder: links of brass and steel on an arc.
    start, bend, end = np.array([-0.34, PIVOT_Y + 0.12]), np.array([-0.35, axis_y + 0.23]), np.array([-0.175, axis_y + 0.105])
    links = 10
    for index in range(links):
        t0, t1 = index / links, (index + 1) / links
        p0 = (1 - t0) ** 2 * start + 2 * (1 - t0) * t0 * bend + t0 ** 2 * end
        p1 = (1 - t1) ** 2 * start + 2 * (1 - t1) * t1 * bend + t1 ** 2 * end
        middle, run = (p0 + p1) * 0.5, p1 - p0
        tilt = math.degrees(math.atan2(run[1], run[0]))
        b.box(gun, "Weapon brass" if index % 2 else "Weapon steel", (middle[0], middle[1], -0.02), (float(np.linalg.norm(run)) * 1.08, 0.034, 0.12 if index % 2 else 0.134),
              basis=rot_z(tilt))
    # Carriers out to the belt box on the left and the battery on the right.
    b.box(gun, "Weapon steel", (-0.262, PIVOT_Y - 0.05, 0.08), (0.03, 0.03, 0.26))
    b.box(gun, "Weapon steel", (0.262, PIVOT_Y - 0.05, 0.08), (0.03, 0.03, 0.2))
    b.box(gun, "Weapon olive", (0.34, PIVOT_Y - 0.06, 0.08), (0.14, 0.2, 0.26))
    b.box(gun, "Weapon edge", (0.34, PIVOT_Y + 0.044, 0.08), (0.15, 0.01, 0.27))
    for z in (0.02, 0.14):
        b.cylinder(gun, "Weapon brass", (0.34, PIVOT_Y + 0.049, z), 0.014, 0.02, segments=8, axis=up)

    # The rotor: hub, six barrels, the two clamps that hold them and the shaft down the middle.
    b.pivot(rotor, (0.0, axis_y, 0.0))
    b.attach(rotor, gun)
    lathe(b, rotor, "Weapon steel", [(HOUSING_FRONT - 0.04, 0.088), (HOUSING_FRONT - 0.17, 0.088)], 18, cap_end=True, at=bore)
    b.cylinder(rotor, "Weapon steel", (0.0, axis_y, HOUSING_FRONT - 0.17), 0.02, 0.94, segments=8, axis=FORWARD, caps=False)
    for index in range(6):
        angle = math.radians(90.0 + 60.0 * index)
        x, y = math.cos(angle) * CLUSTER_R, axis_y + math.sin(angle) * CLUSTER_R
        b.cylinder(rotor, "Weapon edge", (x, y, HOUSING_FRONT - 0.15), BARREL_R, HOUSING_FRONT - 0.15 - GUN_MUZZLE_Z, segments=10, axis=FORWARD,
                   caps=False, color=(0.78, 0.78, 0.78) if index % 2 else (1.0, 1.0, 1.0))
        b.cylinder(rotor, "Weapon steel", (x, y, GUN_MUZZLE_Z + 0.045), BARREL_R + 0.005, 0.045, segments=10, axis=FORWARD, caps=False)
        b.cylinder(rotor, "Black bore", (x, y, GUN_MUZZLE_Z + 0.004), BARREL_R + 0.005, 0.004, segments=10, axis=FORWARD)
    for z in (-0.72, -1.2):
        lathe(b, rotor, "Weapon steel", [(z + 0.028, 0.092), (z - 0.028, 0.092)], 18, cap_start=True, cap_end=True, at=bore)
        lathe(b, rotor, "Weapon edge", [(z + 0.008, 0.0955), (z - 0.008, 0.0955)], 18, at=bore)

    # The belt box: it comes off for a reload, so it has its own node.
    box_at = np.array([-0.36, PIVOT_Y - 0.05, 0.08])
    b.pivot(can, box_at)
    b.attach(can, gun)
    b.box(can, "Weapon olive", box_at, (0.2, 0.32, 0.46))
    b.box(can, "Weapon edge", box_at + (0.0, 0.166, 0.0), (0.21, 0.012, 0.47))
    b.box(can, "Weapon olive", box_at + (0.0, 0.0, 0.232), (0.16, 0.24, 0.006), color=(0.78, 0.78, 0.78))
    for z in (-0.17, 0.17):
        b.box(can, "Weapon steel", box_at + (-0.102, 0.11, z), (0.008, 0.07, 0.034))
    b.box(can, "Weapon steel", box_at + (0.0, 0.185, 0.12), (0.11, 0.008, 0.018))
    for z in (0.075, 0.165):
        b.box(can, "Weapon steel", box_at + (0.0, 0.178, z), (0.014, 0.014, 0.014))

    b.marker("Muzzle", (0.0, axis_y + CLUSTER_R, GUN_MUZZLE_Z), parent=gun)
    b.marker("Ejection", (0.2, axis_y - 0.08, -0.1), parent=gun)
    size, report = b.export(os.path.join(OUT, "rotary_gun.glb"), "RotaryGun")
    return "rotary_gun.glb", size, b.triangle_count(), report


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
    for name, size, triangles, report in (build_rotary_gun(), build_launcher(), build_rocket(), build_grenade()):
        print("%-20s %7d bytes  %5d triangles  %s" % (name, size, triangles, ", ".join("%s:%d" % (n, t) for n, t, _p in report)))


if __name__ == "__main__":
    main()
