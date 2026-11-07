#!/usr/bin/env python3
"""Blender Cycles studio render for the original twin .50-cal viewmodel.
Run after create_models.py and create_textures.py:
  blender --background --python render_weapon_studio.py
Outputs documentation/qa/art-pass-01/weapon-studio.png. CPU Cycles only; no GPU
or display server is required on the GitHub runner.
"""
import bpy
import math
import os
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "assets", "models", "source", "mounted_twin_hmg.blend")
TEX = os.path.join(ROOT, "assets", "textures", "pbr")
OUT = os.path.join(ROOT, "documentation", "qa", "art-pass-01")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=BLEND)

MAP = {
    "Weapon steel": "weapon_metal",
    "Weapon edge": "weapon_metal",
    "Weapon olive": "weapon_paint",
    "Weapon grip": "rubber",
    "Weapon brass": "weapon_brass",
    "Black bore": None,
}


def image_node(nodes, filename, non_color=False):
    node = nodes.new("ShaderNodeTexImage")
    node.image = bpy.data.images.load(os.path.join(TEX, filename), check_existing=True)
    if non_color:
        node.image.colorspace_settings.name = "Non-Color"
    return node


for material in bpy.data.materials:
    base_name = material.name.split(".")[0]
    if base_name not in MAP or MAP[base_name] is None or not material.use_nodes:
        continue
    kind = MAP[base_name]
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    if bsdf is None:
        continue
    albedo = image_node(nodes, kind + "_albedo.jpg")
    links.new(albedo.outputs["Color"], bsdf.inputs["Base Color"])
    if base_name == "Weapon edge":
        mix = nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[2].default_value = (1.45, 1.45, 1.42, 1.0)
        links.new(albedo.outputs["Color"], mix.inputs[1])
        links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
    normal_tex = image_node(nodes, kind + "_normal.png", True)
    normal = nodes.new("ShaderNodeNormalMap")
    normal.inputs["Strength"].default_value = 0.35
    links.new(normal_tex.outputs["Color"], normal.inputs["Color"])
    links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    orm = image_node(nodes, kind + "_orm.png", True)
    sep = nodes.new("ShaderNodeSeparateColor")
    links.new(orm.outputs["Color"], sep.inputs["Color"])
    links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])

# Studio floor and three-point lighting.
bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, -0.02))
floor = bpy.context.object
floor.name = "StudioFloor"
fm = bpy.data.materials.new("StudioFloor")
fm.use_nodes = True
fb = fm.node_tree.nodes.get("Principled BSDF")
fb.inputs["Base Color"].default_value = (0.055, 0.06, 0.058, 1)
fb.inputs["Roughness"].default_value = 0.85
floor.data.materials.append(fm)

world = bpy.data.worlds.new("StudioWorld")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.035, 0.04, 0.045, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.35
bpy.context.scene.world = world


def area(name, loc, energy, size, target, color=(1, 1, 1)):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return obj


area("Key", (3.2, -3.8, 4.6), 900, 4.0, (0, -0.5, 1.0), (1.0, 0.95, 0.86))
area("Fill", (-3.6, -2.0, 2.4), 380, 3.0, (0, -0.4, 1.0), (0.78, 0.86, 1.0))
area("Rim", (0.5, 3.6, 3.8), 650, 2.5, (0, 0, 1.1), (0.9, 0.95, 1.0))

cam_data = bpy.data.cameras.new("StudioCamera")
cam_data.lens = 45
cam = bpy.data.objects.new("StudioCamera", cam_data)
bpy.context.collection.objects.link(cam)
cam.location = (3.05, -4.05, 2.50)
direction = Vector((0, -0.62, 1.00)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = cam

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.render.resolution_x = 1600
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = os.path.join(OUT, "weapon-studio.png")
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "None"
bpy.ops.render.render(write_still=True)
print("STUDIO_RENDER", scene.render.filepath)
