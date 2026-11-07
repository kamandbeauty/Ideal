#!/usr/bin/env python3
"""Blender Cycles studio render for the original infantry model."""
import bpy, os
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND=os.path.join(ROOT,'assets','models','source','soldier.blend')
TEX=os.path.join(ROOT,'assets','textures','pbr')
OUT=os.path.join(ROOT,'documentation','qa','art-pass-02')
os.makedirs(OUT,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=BLEND)
MAP={'Uniform':'fabric','Uniform dark':'fabric','Webbing':'fabric','Canvas':'fabric','Skin':'skin','Leather':'leather','Rifle wood':'wood','Helmet steel':'weapon_paint','Weapon steel':'weapon_metal','Weapon edge':'weapon_metal','Rubber':'rubber','Recoil steel':'weapon_metal','Black bore':None}
def img(nodes,filename,non_color=False):
    n=nodes.new('ShaderNodeTexImage'); n.image=bpy.data.images.load(os.path.join(TEX,filename),check_existing=True)
    if non_color:n.image.colorspace_settings.name='Non-Color'
    return n
for m in bpy.data.materials:
    base=m.name.split('.')[0]
    if base not in MAP or MAP[base] is None or not m.use_nodes:continue
    kind=MAP[base]; nodes=m.node_tree.nodes; links=m.node_tree.links; bs=nodes.get('Principled BSDF')
    if bs is None:continue
    a=img(nodes,kind+'_albedo.jpg'); links.new(a.outputs['Color'],bs.inputs['Base Color'])
    if base in ['Uniform','Uniform dark']:
        mix=nodes.new('ShaderNodeMixRGB'); mix.blend_type='MULTIPLY'; mix.inputs[0].default_value=1.0
        mix.inputs[2].default_value=(0.20,0.24,0.15,1) if base=='Uniform' else (0.13,0.16,0.10,1)
        links.new(a.outputs['Color'],mix.inputs[1]); links.new(mix.outputs['Color'],bs.inputs['Base Color'])
    if base=='Webbing':
        mix=nodes.new('ShaderNodeMixRGB'); mix.blend_type='MULTIPLY'; mix.inputs[0].default_value=1.0; mix.inputs[2].default_value=(0.30,0.34,0.24,1)
        links.new(a.outputs['Color'],mix.inputs[1]); links.new(mix.outputs['Color'],bs.inputs['Base Color'])
    nt=img(nodes,kind+'_normal.png',True); nm=nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value=0.4
    links.new(nt.outputs['Color'],nm.inputs['Color']); links.new(nm.outputs['Normal'],bs.inputs['Normal'])
    orm=img(nodes,kind+'_orm.png',True); sep=nodes.new('ShaderNodeSeparateColor'); links.new(orm.outputs['Color'],sep.inputs['Color'])
    links.new(sep.outputs['Green'],bs.inputs['Roughness']); links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
bpy.ops.mesh.primitive_plane_add(size=20,location=(0,0,-0.02)); floor=bpy.context.object
fm=bpy.data.materials.new('Floor'); fm.use_nodes=True; fb=fm.node_tree.nodes.get('Principled BSDF')
fb.inputs['Base Color'].default_value=(0.05,0.055,0.05,1); fb.inputs['Roughness'].default_value=0.9; floor.data.materials.append(fm)
world=bpy.data.worlds.new('World'); world.use_nodes=True; world.node_tree.nodes['Background'].inputs[0].default_value=(0.03,0.035,0.04,1); world.node_tree.nodes['Background'].inputs[1].default_value=0.35; bpy.context.scene.world=world
def area(name,loc,energy,size,target,color=(1,1,1)):
    d=bpy.data.lights.new(name,'AREA'); d.energy=energy; d.size=size; d.color=color
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); o.location=loc
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
area('Key',(2.4,-2.8,3.2),420,3.0,(0,0,1.0),(1.0,0.98,0.94))
area('Fill',(-2.6,-1.6,1.8),260,2.5,(0,0,1.0),(0.78,0.86,1.0))
area('Rim',(0.4,2.8,2.8),520,2.0,(0,0,1.1),(0.9,0.95,1.0))
cd=bpy.data.cameras.new('Camera'); cd.lens=45; cam=bpy.data.objects.new('Camera',cd); bpy.context.collection.objects.link(cam)
cam.location=(2.05,-3.25,1.50); cam.rotation_euler=(Vector((0,0,0.95))-cam.location).to_track_quat('-Z','Y').to_euler(); bpy.context.scene.camera=cam
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=96; sc.cycles.use_denoising=True
sc.render.resolution_x=1100; sc.render.resolution_y=1400; sc.render.resolution_percentage=100; sc.render.image_settings.file_format='PNG'
sc.render.filepath=os.path.join(OUT,'soldier-studio.png'); sc.view_settings.view_transform='AgX'; sc.view_settings.look='None'
bpy.ops.render.render(write_still=True); print('STUDIO_RENDER',sc.render.filepath)
