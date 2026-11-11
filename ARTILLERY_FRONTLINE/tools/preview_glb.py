#!/usr/bin/env python3
"""Cycles contact sheet of a GLB for art review (headless Blender module).

    python3 tools/preview_glb.py model.glb out.png [--poses walk:0.2,attack:0.5] [--views front,side] \
        [--size 360x520] [--target 0,0.9,0] [--distance 3.4] [--texture file.png]

This is a review aid only; nothing in the game depends on it.
"""
import argparse
import math
import os
import sys
import tempfile

import bpy
from mathutils import Vector
from PIL import Image

VIEWS = {
    "front": (0.0, 8.0),
    "side": (90.0, 6.0),
    "back": (180.0, 8.0),
    "three": (35.0, 14.0),
    "top": (20.0, 55.0),
    "low": (25.0, -6.0),
}


def setup(samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 3
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs[0].default_value = (0.42, 0.45, 0.5, 1.0)
    background.inputs[1].default_value = 0.9
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(4.0)
    sun.rotation_euler = (math.radians(52.0), 0.0, math.radians(-38.0))
    scene.collection.objects.link(sun)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    return scene, camera


def ground(size=40.0):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    plane = bpy.context.object
    material = bpy.data.materials.new("Ground")
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.22, 0.22, 0.22, 1.0)
    plane.data.materials.append(material)


def aim(camera, target, yaw_deg, pitch_deg, distance, lens):
    """target and the orbit are in glTF space (Y up, +Z front); Blender is Z up with the model front on -Y."""
    tx, ty, tz = target
    center = Vector((tx, -tz, ty))
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    offset = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch))) * distance
    camera.location = center + offset
    direction = center - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = lens


def set_pose(scene, clip, seconds):
    for obj in scene.objects:
        if obj.type != "ARMATURE":
            continue
        action = bpy.data.actions.get(clip)
        if action is None:
            for candidate in bpy.data.actions:
                if candidate.name.split(".")[0] == clip or candidate.name.startswith(clip):
                    action = candidate
                    break
        if action is None:
            print("missing action", clip, [a.name for a in bpy.data.actions])
            continue
        if obj.animation_data is None:
            obj.animation_data_create()
        for track in list(obj.animation_data.nla_tracks):
            track.mute = True
        obj.animation_data.action = action
        try:
            if getattr(action, "slots", None) and len(action.slots):
                obj.animation_data.action_slot = action.slots[0]
        except Exception as error:  # older Blender without slotted actions
            print("slot", error)
    scene.frame_set(int(round(seconds * scene.render.fps)))


def override_texture(path):
    image = bpy.data.images.load(path)
    for material in bpy.data.materials:
        if not material.use_nodes:
            continue
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE":
                node.image = image


def main():
    argv = sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("glb")
    parser.add_argument("out")
    parser.add_argument("--poses", default="")
    parser.add_argument("--views", default="front,side")
    parser.add_argument("--size", default="360x520")
    parser.add_argument("--target", default="0,0.9,0")
    parser.add_argument("--distance", type=float, default=3.6)
    parser.add_argument("--lens", type=float, default=50.0)
    parser.add_argument("--samples", type=int, default=20)
    parser.add_argument("--texture", default="")
    parser.add_argument("--no-ground", action="store_true")
    args = parser.parse_args(argv)
    width, height = [int(v) for v in args.size.split("x")]
    scene, camera = setup(args.samples)
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.fps = 24
    if not args.no_ground:
        ground()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.glb))
    if args.texture:
        override_texture(os.path.abspath(args.texture))
    target = [float(v) for v in args.target.split(",")]
    poses = [p for p in args.poses.split(",") if p] or [""]
    views = [v for v in args.views.split(",") if v]
    sheet = Image.new("RGB", (width * len(poses), height * len(views)), (20, 20, 20))
    scratch = tempfile.mkdtemp()
    for column, pose in enumerate(poses):
        if pose:
            clip, _, seconds = pose.partition(":")
            set_pose(scene, clip, float(seconds or 0.0))
        for row, view in enumerate(views):
            yaw, pitch = VIEWS[view]
            aim(camera, target, yaw, pitch, args.distance, args.lens)
            scene.render.filepath = os.path.join(scratch, "tile.png")
            bpy.ops.render.render(write_still=True)
            sheet.paste(Image.open(scene.render.filepath).convert("RGB"), (column * width, row * height))
    sheet.save(args.out)
    print("wrote", args.out, sheet.size)


if __name__ == "__main__":
    main()
