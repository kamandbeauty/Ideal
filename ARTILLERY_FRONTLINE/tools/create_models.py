#!/usr/bin/env python3
"""Original ARTILLERY FRONTLINE hard-surface asset construction.
Run with Blender 3.4+ --background --python this_file.py. No external assets.
All dimensions are meters. Blender Z-up exports to Godot Y-up glTF.
"""
import bpy, math, os, sys, struct, json
from mathutils import Matrix
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','models')
SRC=os.path.join(OUT,'source')
os.makedirs(SRC,exist_ok=True)
M={}
SKIN_BONES=['Hips','Torso','Head','LegL','KneeL','LegR','KneeR','ArmL','ElbowL','ArmR','ElbowR']
def material(name,color,metal=0.,rough=.65):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1)
    m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=metal
    bs.inputs['Roughness'].default_value=rough
    M[name]=m; return m
material('Field olive',(.19,.235,.15),.48,.62)
material('Armor edge',(.29,.32,.22),.55,.56)
material('Gun steel',(.105,.135,.12),.8,.38)
material('Recoil steel',(.38,.42,.39),.85,.28)
material('Rubber',(.032,.038,.033),.05,.92)
material('Canvas',(.32,.32,.21),0.,.95)
material('Brass',(.52,.37,.14),.72,.4)
material('Black bore',(.008,.012,.011),.1,.88)
material('Glass',(.045,.11,.12),.65,.2)
material('Lamp',((.8,.66,.36)),.25,.25)
material('Sand armor',(.43,.38,.25),.35,.72)
material('Warning',(.7,.32,.075),.25,.6)
CURRENT=None
def adopt(obj,name,mat,parent=None):
    obj.name=name
    if mat: obj.data.materials.append(M[mat])
    if parent:
        obj.parent=parent
    return obj
def empty(name,loc=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o)
    o.location=loc; o.empty_display_size=.3
    if parent:o.parent=parent
    return o
def box(name,loc,scale,mat='Field olive',parent=None,bevel=.05,rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=adopt(bpy.context.object,name,mat,parent)
    o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        b=o.modifiers.new('Machined edges','BEVEL'); b.width=bevel; b.segments=3
        bpy.ops.object.modifier_apply(modifier=b.name)
        b=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=b.name)
    if rot:o.rotation_euler=rot
    return o
def cyl(name,loc,radius,depth,mat='Gun steel',parent=None,axis='Z',vertices=28):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    o=adopt(bpy.context.object,name,mat,parent)
    if axis=='X':o.rotation_euler[1]=math.pi/2
    if axis=='Y':o.rotation_euler[0]=math.pi/2
    b=o.modifiers.new('Rim bevel','BEVEL');b.width=min(.03,radius*.10);b.segments=2
    bpy.ops.object.modifier_apply(modifier=b.name)
    for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
    return o
def rod(name,a,b,r,mat='Gun steel',parent=None):
    a,b=Vector(a),Vector(b); d=b-a
    o=cyl(name,(a+b)/2,r,d.length,mat,parent,vertices=12)
    o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o
def bolts(parent,center,radius,count,axis='Z',r=.035,depth=.05,mat='Recoil steel'):
    cx,cy,cz=center
    for i in range(count):
        a=i*math.tau/count
        if axis=='Z': loc=(cx+math.cos(a)*radius,cy+math.sin(a)*radius,cz)
        elif axis=='X': loc=(cx,cy+math.cos(a)*radius,cz+math.sin(a)*radius)
        else: loc=(cx+math.cos(a)*radius,cy,cz+math.sin(a)*radius)
        cyl('Bolt',loc,r,depth,mat,parent,axis,6)
def hose(parent,points,r=.035,mat='Rubber'):
    for a,b in zip(points[:-1],points[1:]):
        rod('Hydraulic hose',a,b,r,mat,parent)
def loft(name,rings,mat,parent=None,segments=20):
    """Smooth elliptical cross-section loft with cylindrical UVs."""
    verts=[];faces=[];uvs=[]
    for ri,(z,rx,ry,ox,oy) in enumerate(rings):
        for i in range(segments):
            a=i*math.tau/segments
            verts.append((ox+math.cos(a)*rx,oy+math.sin(a)*ry,z))
    for ri in range(len(rings)-1):
        for i in range(segments):
            j=(i+1)%segments
            faces.append((ri*segments+i,ri*segments+j,(ri+1)*segments+j,(ri+1)*segments+i))
    faces.append(tuple(range(segments-1,-1,-1)))
    faces.append(tuple((len(rings)-1)*segments+i for i in range(segments)))
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o)
    adopt(o,name,mat,parent)
    uv=data.uv_layers.new(name='UVMap')
    for poly in data.polygons:
        for li in poly.loop_indices:
            vi=data.loops[li].vertex_index
            ri=vi//segments; i=vi%segments
            uv.data[li].uv=(i/segments,ri/max(1,len(rings)-1))
        poly.use_smooth=True
    return o

def torus(name,loc,major,minor,mat='Gun steel',parent=None,axis='Z',segments=32):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=segments,minor_segments=10,location=loc)
    o=adopt(bpy.context.object,name,mat,parent)
    if axis=='X':o.rotation_euler[1]=math.pi/2
    if axis=='Y':o.rotation_euler[0]=math.pi/2
    for p in o.data.polygons:p.use_smooth=True
    return o

def mesh(name,verts,faces,mat,parent=None):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o)
    adopt(o,name,mat,parent);return o
def reset(name):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes,bpy.data.curves,bpy.data.materials,bpy.data.images):
        for item in list(block):
            if item.users==0:block.remove(item)
    M.clear()
    material('Field olive',(.19,.235,.15),.48,.62)
    material('Armor edge',(.29,.32,.22),.55,.56)
    material('Gun steel',(.105,.135,.12),.8,.38)
    material('Recoil steel',(.38,.42,.39),.85,.28)
    material('Rubber',(.032,.038,.033),.05,.92)
    material('Canvas',(.32,.32,.21),0.,.95)
    material('Brass',(.52,.37,.14),.72,.4)
    material('Black bore',(.008,.012,.011),.1,.88)
    material('Glass',(.045,.11,.12),.65,.2)
    material('Lamp',(.8,.66,.36),.25,.25)
    material('Sand armor',(.43,.38,.25),.35,.72)
    material('Warning',(.7,.32,.075),.25,.6)
    return empty(name)
def merge_children(parent):
    # Join only direct static mesh siblings, preserving all animation pivots.
    groups={}
    for o in list(parent.children):
        if o.type=='MESH':
            key=o.data.materials[0].name if o.data.materials else ''
            groups.setdefault(key,[]).append(o)
    for key,objects in groups.items():
        if len(objects)<2:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join();objects[0].name=parent.name+'_'+key.replace(' ','_')
def finish(root,name,skin=False):
    empty_names=[o.name for o in bpy.data.objects if o.type=='EMPTY']
    for object_name in empty_names:
        o=bpy.data.objects.get(object_name)
        if o is not None and o.type=='EMPTY':merge_children(o)
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for o in bpy.data.objects:o.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC,name+'.blend'))
    export_glb(root,os.path.join(OUT,name+'.glb'),skin=skin)
    print('CREATED',name, len(bpy.data.objects),'objects')

def wheel(parent,x,y,z,r=.91,width=.48,pivot_name=None):
    side=1 if x>=0 else -1
    if pivot_name:
        hub=empty(pivot_name,(x,y,z),parent)
        cx,cy,cz=0,0,0
    else:
        hub=parent
        cx,cy,cz=x,y,z
    cyl('Tire',(cx,cy,cz),r,width,'Rubber',hub,'X',32)
    cyl('Rim',(cx+side*width*.52,cy,cz),r*.57,.06,'Armor edge',hub,'X',24)
    bolts(hub,(cx+side*width*.56,cy,cz),r*.40,8,'X',.03,.05)
    cyl('Hub',(cx+side*width*.64,cy,cz),r*.22,.14,'Gun steel',hub,'X',20)
    cyl('Brake drum',(cx-side*width*.30,cy,cz),r*.34,.10,'Gun steel',hub,'X',18)
    for i in range(8):
        a=i*math.tau/8
        cyl('Hub bolt',(cx+side*width*.68,cy+math.sin(a)*r*.38,cz+math.cos(a)*r*.38),.045,.06,'Recoil steel',hub,'X',6)
    for i in range(24):
        a=i*math.tau/24
        o=box('Tread',(cx,cy+math.sin(a)*r,cz+math.cos(a)*r),(.52,.14,.08),'Rubber',hub,.015)
        o.rotation_euler[0]=-a
    return hub

def export_glb(root,path,skin=False):
    """Direct standards-compliant GLB writer, independent of Blender's bundled
    glTF addon (Ubuntu's Blender package has an incompatible addon runtime).
    Evaluated geometry and named animation pivots are preserved exactly.
    When skin=True, meshes carrying vertex groups named after pivot empties are
    exported as glTF skins (JOINTS_0/WEIGHTS_0 + inverse bind matrices), so Godot
    imports a real Skeleton3D instead of a pile of rigid robot parts.
    """
    convert=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
    inverse=convert.inverted()
    objects=[root]+list(root.children_recursive)
    indices={o.name:i for i,o in enumerate(objects)}
    doc={'asset':{'version':'2.0','generator':'ARTILLERY FRONTLINE asset pipeline'},
         'scene':0,'scenes':[{'nodes':[0]}],'nodes':[],'meshes':[],'materials':[],
         'accessors':[],'bufferViews':[],'buffers':[],'images':[],'textures':[],'samplers':[]}
    material_indices={}; image_indices={}; binary=bytearray()
    def embed_image(image):
        """Pack a diffuse atlas into the GLB binary chunk. Image bufferViews must
        not carry a `target`, so this bypasses accessor()."""
        nonlocal binary
        key=image.filepath
        if key in image_indices:return image_indices[key]
        with open(bpy.path.abspath(image.filepath),'rb') as handle:payload=handle.read()
        while len(binary)%4:binary.append(0)
        view=len(doc['bufferViews'])
        doc['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':len(payload)})
        binary.extend(payload)
        source=len(doc['images'])
        doc['images'].append({'name':image.name,'mimeType':'image/png','bufferView':view})
        if not doc['samplers']:
            # Linear + mipmaps, repeat wrap: matches Godot's default import.
            doc['samplers'].append({'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497})
        doc['textures'].append({'sampler':0,'source':source})
        image_indices[key]=len(doc['textures'])-1
        return image_indices[key]
    def accessor(values,fmt,components,target,minimum=None,maximum=None):
        nonlocal binary
        while len(binary)%4:binary.append(0)
        payload=struct.pack('<'+fmt*(len(values)*components),*[c for v in values for c in v]) if components>1 else struct.pack('<'+fmt*len(values),*values)
        view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':len(payload),'target':target})
        binary.extend(payload)
        typ={1:'SCALAR',2:'VEC2',3:'VEC3',4:'VEC4',16:'MAT4'}[components]
        component_type={'f':5126,'I':5125,'H':5123,'B':5121}[fmt]
        a={'bufferView':view,'componentType':component_type,'count':len(values),'type':typ}
        if minimum is not None:a['min']=minimum;a['max']=maximum
        index=len(doc['accessors']);doc['accessors'].append(a);return index
    joint_objects=[o for o in objects if o.type=='EMPTY' and o.name in SKIN_BONES] if skin else []
    joint_index={o.name:i for i,o in enumerate(joint_objects)}
    skin_index=None
    if joint_objects:
        flat=[]
        for j in joint_objects:
            world=convert @ j.matrix_world @ inverse
            m=world.inverted()
            # glTF matrices are column-major: one VEC16 per joint.
            flat.append(tuple(m[r][c] for c in range(4) for r in range(4)))
        doc['skins']=[{'name':'SoldierSkin','joints':[indices[j.name] for j in joint_objects],'inverseBindMatrices':accessor(flat,'f',16,None)}]
        skin_index=0
    depsgraph=bpy.context.evaluated_depsgraph_get()
    for o in objects:
        matrix=convert @ o.matrix_local @ inverse
        loc,rot,scale=matrix.decompose()
        node={'name':o.name,'translation':list(loc),'rotation':[rot.x,rot.y,rot.z,rot.w],'scale':list(scale)}
        children=[indices[c.name] for c in o.children]
        if children:node['children']=children
        doc['nodes'].append(node)
        if o.type!='MESH':continue
        evaluated=o.evaluated_get(depsgraph);mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
        uv_layer=mesh.uv_layers.active
        positions=[];normals=[];uvs=[];triangles=[];remap={}
        rotation=convert.to_3x3()
        weighted=skin_index is not None and any(g.name in joint_index for g in o.vertex_groups)
        joints=[];weights=[]
        for tri in mesh.loop_triangles:
            face=[]
            for loop_index in tri.loops:
                vi=mesh.loops[loop_index].vertex_index
                uv=tuple(uv_layer.data[loop_index].uv) if uv_layer else (0.0,0.0)
                key=(vi,round(uv[0],6),round(uv[1],6))
                if key not in remap:
                    vertex=mesh.vertices[vi]
                    remap[key]=len(positions)
                    positions.append(tuple(rotation @ vertex.co))
                    normals.append(tuple((rotation @ vertex.normal).normalized()))
                    # Blender/3ds Max UVs are V-up; glTF TEXCOORD_0 is V-down.
                    uvs.append((uv[0],1.0-uv[1]))
                    if weighted:
                        groups=sorted(((g.group,g.weight) for g in vertex.groups if o.vertex_groups[g.group].name in joint_index),key=lambda x:-x[1])[:4]
                        total=sum(w for _,w in groups) or 1.0
                        jj=[joint_index[o.vertex_groups[g].name] for g,_ in groups]+[0]*(4-len(groups))
                        ww=[w/total for _,w in groups]+[0.0]*(4-len(groups))
                        joints.append(tuple(jj));weights.append(tuple(ww))
                face.append(remap[key])
            triangles.append(tuple(face))
        if not triangles:
            evaluated.to_mesh_clear();continue
        pa=accessor(positions,'f',3,34962,[min(p[k] for p in positions) for k in range(3)],[max(p[k] for p in positions) for k in range(3)])
        na=accessor(normals,'f',3,34962)
        ua=accessor(uvs,'f',2,34962)
        # glTF indices are SCALAR, not VEC3: one component per corner. Packing
        # them as VEC3 made every accessor report a third of the real triangle
        # count and is rejected by strict validators.
        ia=accessor([c for tri in triangles for c in tri],'I',1,34963)
        source=o.data.materials[0] if o.data.materials else None
        if source.name not in material_indices:
            bs=source.node_tree.nodes.get('Principled BSDF')
            color=list(bs.inputs['Base Color'].default_value)
            pbr={'baseColorFactor':color,'metallicFactor':float(bs.inputs['Metallic'].default_value),'roughnessFactor':float(bs.inputs['Roughness'].default_value)}
            entry={'name':source.name,'pbrMetallicRoughness':pbr,'doubleSided':False,'alphaMode':'OPAQUE'}
            link=bs.inputs['Base Color'].links
            if link and link[0].from_node.type=='TEX_IMAGE' and link[0].from_node.image:
                pbr['baseColorTexture']={'index':embed_image(link[0].from_node.image),'texCoord':0}
                pbr['baseColorFactor']=[1.0,1.0,1.0,1.0]
            material_indices[source.name]=len(doc['materials']);doc['materials'].append(entry)
        attributes={'POSITION':pa,'NORMAL':na,'TEXCOORD_0':ua}
        if weighted:
            attributes['JOINTS_0']=accessor(joints,'H',4,34962)
            attributes['WEIGHTS_0']=accessor(weights,'f',4,34962)
            node['skin']=skin_index
        doc['meshes'].append({'name':o.data.name,'primitives':[{'attributes':attributes,'indices':ia,'material':material_indices[source.name]}]})
        node['mesh']=len(doc['meshes'])-1
        evaluated.to_mesh_clear()
    doc['buffers']=[{'byteLength':len(binary)}]
    # glTF forbids empty arrays; only the infantry carries embedded atlases.
    for key in ('images','textures','samplers'):
        if not doc[key]:del doc[key]
    encoded=json.dumps(doc,separators=(',',':')).encode('utf8')
    while len(encoded)%4:encoded+=b' '
    while len(binary)%4:binary.append(0)
    total=12+8+len(encoded)+8+len(binary)
    with open(path,'wb') as f:
        f.write(struct.pack('<III',0x46546c67,2,total))
        f.write(struct.pack('<II',len(encoded),0x4e4f534a));f.write(encoded)
        f.write(struct.pack('<II',len(binary),0x004e4942));f.write(binary)

def kestrel():
    r=reset('Kestrel')
    cyl('Axle',(0,.4,.95),.17,4.6,'Gun steel',r,'X')
    for x in [-2.05,2.05]:wheel(r,x,.4,.96)
    box('Lower carriage',(0,.35,1.18),(2.5,2.6,.48),'Field olive',r,.13)
    cyl('Traverse ring',(0,.15,1.55),1.14,.28,'Gun steel',r)
    bolts(r,(0,.15,1.71),1.02,16,'Z',.04,.05)
    for sx in [-1,1]:
        for i in range(5): box('Carriage rivet',(sx*1.18,-.05+i*.5,1.44),(.06,.06,.05),'Recoil steel',r,.01)
    for s in [-1,1]:
        trail=box('Split trail',(s*1.25,2.65,.68),(.4,4.4,.42),'Field olive',r,.07)
        trail.rotation_euler[2]=s*-.24
        sp=box('Ground spade',(s*1.83,4.62,.3),(.95,.3,.65),'Gun steel',r,.05)
        rod('Trail brace',(s*.7,1,.9),(s*1.55,3.6,.65),.075,'Recoil steel',r)
        box('Shield',(s*1.04,-.55,2.38),(1.18,.18,1.55),'Armor edge',r,.07,(math.radians(-9),0,s*.08))
        box('Shield lower',(s*1.2,.0,1.7),(1.05,.2,.5),'Field olive',r,.04)
        box('Shield weld',(s*1.04,-.66,2.38),(1.12,.035,.06),'Gun steel',r,.01,(math.radians(-9),0,s*.08))
        box('Vision block',(s*.72,-.66,2.86),(.22,.05,.16),'Glass',r,.02)
        box('Tool locker',(s*1.4,1.3,1.5),(.55,1.0,.45),'Field olive',r,.06)
        for j in range(4):
            cyl('Shield fastener',(s*(.62+j*.25),-.68,2.94),.035,.045,'Recoil steel',r,'Y',6)
    turret=empty('Turret',(0,.1,1.75),r)
    box('Cradle',(0,-.1,.36),(1.25,1.75,.52),'Field olive',turret,.1)
    for s in [-1,1]:
        cyl('Trunnion',(s*.76,0,.65),.31,.22,'Gun steel',turret,'X')
        rod('Hydraulic sleeve',(s*.56,.55,.1),(s*.56,-.9,.65),.13,'Field olive',turret)
        rod('Hydraulic piston',(s*.56,-.7,.53),(s*.56,-1.5,.78),.068,'Recoil steel',turret)
        hose(turret,[(s*.62,.62,.18),(s*.78,.2,.34),(s*.7,-.35,.56),(s*.58,-.82,.7)],.028)
        bolts(turret,(s*.76,0,.78),.22,8,'X',.028,.04)
    pivot=empty('BarrelPivot',(0,0,.68),turret)
    recoil=empty('RecoilAssembly',(0,0,0),pivot)
    cyl('Barrel sleeve',(0,-.8,0),.29,2.0,'Field olive',recoil,'Y',32)
    for i in range(6): cyl('Sleeve rib',(0,-.1-i*.28,0),.305,.045,'Armor edge',recoil,'Y',32)
    cyl('Forged tube',(0,-3.4,0),.18,4.2,'Gun steel',recoil,'Y',32)
    for y in [-1.7,-2.0,-4.6]:cyl('Barrel collar',(0,y,0),.225,.13,'Armor edge',recoil,'Y',32)
    bolts(recoil,(0,-4.6,0),.19,8,'Y',.022,.035)
    box('Muzzle brake',(0,-5.72,0),(.56,.7,.46),'Gun steel',recoil,.06)
    for s in [-1,1]:
        for i in range(2): box('Brake baffle',(s*.286,-5.5-i*.28,0),(.02,.12,.3),'Black bore',recoil,.005)
    for s in [-1,1]:
        box('Gas port',(s*.284,-5.7,0),(.015,.32,.25),'Black bore',recoil,.01)
    cyl('Muzzle rim',(0,-6.09,0),.215,.07,'Recoil steel',recoil,'Y',24)
    cyl('Bore darkness',(0,-6.132,0),.147,.012,'Black bore',recoil,'Y',24)
    empty('Muzzle',(0,-6.17,0),recoil)
    box('Breech',(0,.55,0),(.7,.9,.58),'Gun steel',pivot,.07)
    block=box('BreechBlock',(.44,.7,0),(.14,.6,.48),'Recoil steel',pivot,.035)
    rod('Operating lever',(.5,.8,.2),(.85,1.0,.35),.045,'Gun steel',pivot)
    cyl('Elevation wheel',(-1.0,.55,.3),.32,.07,'Gun steel',turret,'X',24)
    cyl('Wheel hub',(-1.08,.55,.3),.08,.1,'Recoil steel',turret,'X',12)
    for i in range(8):
        a=i*math.tau/8
        rod('Wheel spoke',(-1.05,.55,.3),(-1.05,.55+math.sin(a)*.3,.3+math.cos(a)*.3),.025,'Armor edge',turret)
    box('Gunner seat',(-1.25,1.05,.65),(.62,.55,.13),'Canvas',turret,.05)
    box(' Sight housing',(.72,-.2,1.0),(.3,.4,.4),'Field olive',turret,.04)
    cyl('Optic glass',(.72,-.415,1.04),.095,.025,'Glass',turret,'Y',20)
    box('Ammo rack',(-1.35,1.9,1.0),(.7,1.2,.35),'Field olive',r,.05)
    for i in range(4):
        cyl('Stowed round',(-1.35,1.45+i*.3,1.28),.09,.5,'Brass',r,'Z',16)
        cyl('Round tip',(-1.35,1.45+i*.3,1.56),.07,.12,'Gun steel',r,'Z',12)
    finish(r,'kestrel')

def warden():
    r=reset('Warden')
    for s in [-1,1]:
        side='L' if s<0 else 'R'
        box('Track belt',(s*2.0,0,.78),(.8,6.9,1.35),'Rubber',r,.3)
        for wi,y in enumerate([-2.5,-1.25,0,1.25,2.5]):wheel(r,s*2.16,y,.75,.58,.45,'Wheel%s%d'%(side,wi))
        wheel(r,s*2.16,-3.05,1.05,.42,.40,'Wheel%sSprocket'%side)
        wheel(r,s*2.16,3.05,1.05,.42,.40,'Wheel%sIdler'%side)
        for i in range(26):
            box('Track shoe',(s*2.0,-3.25+i*.25,1.47),(.87,.18,.1),'Gun steel',r,.012)
            box('Track shoe lower',(s*2.0,-3.25+i*.25,.12),(.87,.18,.08),'Gun steel',r,.01)
            box('Track grouser',(s*2.0,-3.25+i*.25,.05),(.87,.05,.04),'Recoil steel',r,.005)
            cyl('Track pin',(s*2.42,-3.25+i*.25,1.47),.025,.04,'Recoil steel',r,'X',6)
        box('Side skirt',(s*2.3,0,1.65),(.22,6.6,.65),'Field olive',r,.05)
        for i in range(6):
            box('ERA skirt',(s*2.44,-2.55+i*1.02,1.72),(.18,.88,.5),'Armor edge',r,.04)
            bolts(r,(s*2.54,-2.55+i*1.02,1.72),.18,4,'X',.018,.03)
        for i in range(5):box('Skirt hinge',(s*2.42,-2.2+i*1.1,2.0),(.10,.16,.08),'Gun steel',r,.015)
        rod('Tow cable',(s*2.35,-2.8,2.05),(s*2.35,2.6,2.05),.025,'Gun steel',r)
        for y in [-2.8,2.6]:torus('Cable clamp',(s*2.35,y,2.05),.04,.012,'Recoil steel',r,'Y',10)
    box('Lower hull',(0,0,1.25),(3.7,6.4,1.0),'Field olive',r,.18)
    for s in [-1,1]:
        for i in range(8): cyl('Hull rivet',(s*1.82,-2.8+i*.8,1.82),.035,.04,'Recoil steel',r,'X',6)
    mesh('Sloped glacis',[(-1.95,-3.3,1.5),(1.95,-3.3,1.5),(1.75,-2.25,2.35),(-1.75,-2.25,2.35),(-1.8,3.0,1.5),(1.8,3.0,1.5),(1.7,2.6,2.25),(-1.7,2.6,2.25)],[(0,1,2,3),(4,7,6,5),(3,2,6,7),(0,4,5,1),(0,3,7,4),(1,5,6,2)],'Armor edge',r)
    turret=empty('Turret',(0,-.25,2.35),r)
    cyl('Turret race',(0,0,0),1.3,.25,'Gun steel',turret)
    box('Cast turret',(0,-.1,.48),(2.75,2.8,.92),'Field olive',turret,.3)
    bolts(turret,(0,0,.16),1.18,14,'Z',.035,.04)
    box('Turret weld',(0,-1.42,.95),(2.5,.04,.05),'Gun steel',turret,.01)
    for s in [-1,1]:
        for i in range(3):box('Cheek armor',(s*1.13,-.9+i*.58,.62),(.48,.5,.65),'Armor edge',turret,.08,(0,s*.18,0))
    pivot=empty('BarrelPivot',(0,-1.25,.55),turret)
    recoil=empty('RecoilAssembly',(0,0,0),pivot)
    cyl('Tank gun',(0,-1.95,0),.12,4.2,'Gun steel',recoil,'Y')
    cyl('Fume extractor',(0,-1.35,0),.2,.75,'Field olive',recoil,'Y')
    cyl('Thermal sleeve',(0,-2.6,0),.145,1.4,'Armor edge',recoil,'Y',20)
    for y in [-.7,-1.9,-3.2]:torus('Barrel collar',(0,y,0),.15,.02,'Gun steel',recoil,'Y',18)
    cyl('Muzzle brake',(0,-4.07,0),.15,.18,'Gun steel',recoil,'Y')
    cyl('Bore',(0,-4.17,0),.09,.02,'Black bore',recoil,'Y')
    empty('Muzzle',(0,-4.22,0),recoil)
    box('Breech',(0,.35,0),(.42,.6,.42),'Gun steel',pivot,.06)
    rod('Recoil cylinder L',(-.22,.1,-.05),(-.22,-.9,-.05),.05,'Recoil steel',pivot)
    rod('Recoil cylinder R',(.22,.1,-.05),(.22,-.9,-.05),.05,'Recoil steel',pivot)
    cyl('Commander cupola',(.65,.5,1.06),.42,.16,'Armor edge',turret,'Z',20)
    for i in range(6):box('Vision block',(.65+math.cos(i*math.tau/6)*.34,.5+math.sin(i*math.tau/6)*.34,1.16),(.12,.08,.08),'Glass',turret,.01)
    box('Loader hatch',(-.65,.5,1.02),(.62,.62,.10),'Armor edge',turret,.05)
    rod('Hatch handle',(-.85,.5,1.1),(-.45,.5,1.1),.02,'Gun steel',turret)
    box('AA mount',(.65,.5,1.28),(.12,.12,.22),'Gun steel',turret,.02)
    cyl('AA gun',(.65,.28,1.42),.025,.55,'Gun steel',turret,'Y',10)
    box('Gun shield',(.65,.42,1.42),(.22,.03,.16),'Armor edge',turret,.01)
    for s in [-1,1]:
        box('Smoke launcher bank',(s*1.25,-.7,.75),(.16,.34,.18),'Gun steel',turret,.02)
        for i in range(3):cyl('Smoke tube',(s*1.34,-.82+i*.12,.82),.03,.14,'Black bore',turret,'X',8)
    box('Laser rangefinder',(0,-1.35,.95),(.5,.18,.14),'Armor edge',turret,.02)
    cyl('Rangefinder lens L',(-.18,-1.45,.95),.045,.02,'Glass',turret,'Y',12)
    cyl('Rangefinder lens R',(.18,-1.45,.95),.045,.02,'Glass',turret,'Y',12)
    for x in [-.65,.65]:
        cyl('Hatch',(x,.5,1.02),.4,.12,'Armor edge',turret)
        bolts(turret,(x,.5,1.1),.32,8,'Z',.025,.035)
        box('Periscope',(x,.16,1.1),(.28,.15,.16),'Glass',turret,.02)
    rod('Antenna',(1.05,.9,.8),(1.05,.9,3.2),.02,'Gun steel',turret)
    box('Stowage',(0,1.55,.55),(2.3,.45,.65),'Canvas',turret,.08)
    for x in [-1.45,1.45]:
        box('Headlamp',(x,-3.13,1.85),(.3,.12,.22),'Lamp',r,.035)
    for i in range(7):box('Engine grille',(0,1.7+i*.14,2.32),(2.4,.065,.045),'Gun steel',r,.005)
    finish(r,'warden')

def nomad():
    r=reset('Nomad')
    box('Chassis',(0,0,.95),(2.5,7.6,.35),'Gun steel',r,.08)
    for x in [-1.55,1.55]:
        side='L' if x<0 else 'R'
        for wi,y in enumerate([-2.65,.8,2.55]):wheel(r,x,y,.82,.73,.46,'Wheel%s%d'%(side,wi))
        for y in [-2.65,.8,2.55]:
            box('Leaf spring',(x*.82,y,1.15),(.12,.9,.08),'Gun steel',r,.015)
            cyl('Shock absorber',(x*.72,y,1.45),.05,.5,'Recoil steel',r,'Z',10)
    box('Armored cab',(0,-2.45,2.0),(2.65,2.3,1.9),'Sand armor',r,.16)
    for s in [-1,1]:
        for i in range(4): cyl('Cab rivet',(s*1.3,-3.2+i*.5,2.7),.03,.04,'Recoil steel',r,'X',6)
    box('Bonnet',(0,-3.55,1.55),(2.5,1.0,.8),'Field olive',r,.1)
    box('Windscreen',(0,-3.625,2.45),(2.18,.035,.65),'Glass',r,.025)
    box('Windscreen divider',(0,-3.66,2.45),(.07,.05,.7),'Gun steel',r,.01)
    for x in [-1.34,1.34]:
        box('Door glass',(x,-2.45,2.48),(.025,1.25,.62),'Glass',r,.02)
        box('Door handle',(x*1.025,-1.94,1.96),(.05,.25,.05),'Gun steel',r,.01)
        rod('Mirror arm',(x,-3.2,2.5),(x*1.25,-3.3,2.5),.035,'Gun steel',r)
        box('Mirror',(x*1.25,-3.3,2.5),(.1,.2,.32),'Gun steel',r,.03)
        box('Headlight',(x*.73,-4.07,1.55),(.4,.04,.25),'Lamp',r,.04)
    turret=empty('Turret',(0,-2.2,3.05),r)
    cyl('Turret ring',(0,0,0),.42,.12,'Gun steel',turret,'Z',20)
    pivot=empty('BarrelPivot',(0,0,.12),turret)
    recoil=empty('RecoilAssembly',(0,0,0),pivot)
    box('Gun shield',(0,-.18,.12),(.5,.06,.34),'Armor edge',pivot,.03)
    cyl('Autocannon',(0,-.55,.12),.035,.9,'Gun steel',recoil,'Y',12)
    cyl('Flash hider',(0,-1.02,.12),.05,.12,'Gun steel',recoil,'Y',12)
    empty('Muzzle',(0,-1.10,.12),recoil)
    box('Ammo box',(.28,.05,.05),(.18,.24,.18),'Field olive',pivot,.02)
    box('Cargo bed',(0,1.45,1.5),(2.7,4.7,.5),'Field olive',r,.06)
    box('Canvas load',(0,1.45,2.45),(2.6,4.5,1.6),'Canvas',r,.3)
    for y in [-.5,.8,2.1,3.45]:
        box('Cargo strap',(0,y,2.55),(2.67,.07,1.55),'Field olive',r,.035)
        box('Strap buckle',(1.36,y,2.55),(.06,.18,.2),'Recoil steel',r,.02)
    for i in range(5):box('Radiator grille',(0,-4.075,1.3+i*.1),(.95,.03,.035),'Gun steel',r,.005)
    box('Front bumper',(0,-4.2,1.02),(2.95,.22,.25),'Gun steel',r,.05)
    rod('Antenna',(1.15,-1.4,2.8),(1.15,-1.4,4.5),.018,'Gun steel',r)
    finish(r,'nomad')

def sentry():
    r=reset('Sentry')
    box('Concrete footing',(0,0,.2),(5.5,5.0,.4),'Sand armor',r,.1)
    for x in [-1.6,1.6]:
        for y in [-1.35,1.35]:rod('Tower leg',(x,y,.4),(x*.75,y*.75,3.1),.12,'Gun steel',r)
    box('Platform',(0,0,2.85),(4,3.5,.25),'Field olive',r,.06)
    for s in [-1,1]:box('Armor shield',(s*1.75,0,3.4),(.18,3.5,.9),'Sand armor',r,.04)
    box('Front shield',(0,-1.65,3.4),(3.5,.18,.9),'Sand armor',r,.04)
    turret=empty('Turret',(0,0,3.1),r)
    cyl('Weapon pedestal',(0,0,.4),.3,.8,'Gun steel',turret)
    box('Launcher housing',(0,-.3,.95),(1.2,1.8,.7),'Field olive',turret,.12)
    for x in [-.36,.36]:
        cyl('Launch tube',(x,-1.1,1.05),.23,2.4,'Gun steel',turret,'Y')
        cyl('Tube cap',(x,-2.32,1.05),.18,.03,'Black bore',turret,'Y')
    box('Optics',(0,.25,1.55),(.65,.55,.45),'Field olive',turret,.06)
    box('Optic glass',(0,-.035,1.55),(.45,.025,.24),'Glass',turret,.02)
    rod('Radio mast',(1.6,1.3,2.9),(1.6,1.3,6.8),.04,'Gun steel',r)
    for z in [5.6,6.15]:rod('Aerial cross',(1.1,1.3,z),(2.1,1.3,z),.025,'Gun steel',r)
    finish(r,'sentry')

def hangar():
    r=reset('Hangar')
    box('Slab',(0,0,.1),(22,30,.2),'Sand armor',r,.04)
    # Modular open-front maintenance hangar, with a curved corrugated roof.
    for s in [-1,1]:box('Side wall',(s*10.5,0,2.8),(.35,29,5.4),'Sand armor',r,.04)
    box('Rear wall',(0,14.4,2.8),(21,.35,5.4),'Sand armor',r,.04)
    verts=[];faces=[]
    segments=32
    for y in [-15,15]:
        for i in range(segments+1):
            a=i*math.pi/segments
            verts.append((10.7*math.cos(a),y,5.3+5.2*math.sin(a)))
    for i in range(segments):faces.append((i,i+1,i+segments+2,i+segments+1))
    roof=mesh('Curved roof',verts,faces,'Field olive',r)
    solid=roof.modifiers.new('Roof thickness','SOLIDIFY');solid.thickness=.15
    bpy.context.view_layer.objects.active=roof;bpy.ops.object.modifier_apply(modifier=solid.name)
    for y in [-14.7,-12,-9,-6,-3,0,3,6,9,12,14.7]:
        for i in range(segments):
            a=i*math.pi/segments;b=(i+1)*math.pi/segments
            rod('Roof rib',(10.55*math.cos(a),y,5.25+5.05*math.sin(a)),(10.55*math.cos(b),y,5.25+5.05*math.sin(b)),.075,'Gun steel',r)
    for s in [-1,1]:
        box('Door pillar',(s*9.7,-14.8,3),(.7,.7,6),'Gun steel',r,.04)
        box('Part-open door',(s*8.1,-14.6,2.7),(3.0,.15,5.2),'Field olive',r,.025)
    for y in [-8,0,8]:box('Roof ventilator',(0,y,10.55),(1.6,2.0,.6),'Gun steel',r,.08)
    finish(r,'hangar')


def sphere(name,loc,scale,mat,parent=None,segments=20,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=loc)
    o=adopt(bpy.context.object,name,mat,parent)
    o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return o

def weapon_base(r,shield=True):
    cyl('Pedestal',(0,.35,.55),.34,.7,'Gun steel',r)
    cyl('Traverse ring',(0,.1,.95),.62,.18,'Armor edge',r)
    bolts(r,(0,.1,1.06),.52,10,'Z',.035,.04)
    box('Cradle',(0,.15,1.15),(.7,.9,.34),'Field olive',r,.08)
    if shield:
        for s in [-1,1]:
            box('Gun shield',(s*.52,-.28,1.42),(.5,.08,.72),'Armor edge',r,.04,(math.radians(-8),0,s*.06))
    return empty('BarrelPivot',(0,0,1.28),r)

def mounted_twin_hmg():
    """Original twin .50-cal pedestal mount. Generic real-world mechanical
    language; no proprietary game mesh, texture or UI is used. Dimensions are
    metres. Animation pivots: RecoilL/R, CoverL/R, MuzzleL/R, EjectionL/R."""
    r=reset('MountedTwinHMG')
    material('Weapon steel',(.075,.082,.085),.88,.48)
    material('Weapon edge',(.18,.19,.19),.9,.38)
    material('Weapon olive',(.105,.125,.082),.22,.7)
    material('Weapon grip',(.025,.027,.026),.02,.92)
    material('Weapon brass',(.46,.33,.12),.85,.34)
    # Pedestal and traverse ring.
    cyl('Base plate',(0,.18,.06),.44,.12,'Weapon olive',r,'Z',40)
    bolts(r,(0,.18,.13),.35,10,'Z',.028,.035,'Weapon edge')
    cyl('Pedestal column',(0,.18,.48),.17,.76,'Weapon olive',r,'Z',32)
    for z in [.2,.62,.78]:cyl('Pedestal collar',(0,.18,z),.205,.055,'Weapon edge',r,'Z',32)
    cyl('Traverse ring',(0,.12,.88),.39,.11,'Weapon steel',r,'Z',44)
    bolts(r,(0,.12,.95),.32,12,'Z',.024,.03,'Weapon edge')
    torus('Traverse handwheel',(.48,.18,.82),.16,.018,'Weapon edge',r,'X',28)
    for i in range(4):
        a=i*math.tau/4
        rod('Handwheel spoke',(.48,.18,.82),(.48,.18+math.cos(a)*.15,.82+math.sin(a)*.15),.012,'Weapon steel',r)
    cyl('Handwheel hub',(.48,.18,.82),.04,.08,'Weapon steel',r,'X',16)
    # Cradle, trunnions and elevation gear.
    box('Cradle bed',(0,.06,1.02),(.76,.58,.15),'Weapon olive',r,.035)
    for s in [-1,1]:
        box('Cradle cheek',(s*.37,.02,1.12),(.075,.62,.30),'Weapon olive',r,.025)
        cyl('Trunnion',(s*.40,0,1.15),.095,.10,'Weapon edge',r,'X',24)
        bolts(r,(s*.455,0,1.15),.065,6,'X',.014,.02,'Weapon steel')
        rod('Cradle brace',(s*.34,.30,.98),(s*.30,-.24,1.08),.025,'Weapon steel',r)
    rod('Elevation screw',(0,.34,.92),(0,.34,1.16),.028,'Weapon edge',r)
    torus('Elevation wheel',(0,.40,1.02),.11,.014,'Weapon edge',r,'Y',24)
    pivot=empty('BarrelPivot',(0,0,1.15),r)
    for s in [-1,1]:
        side='L' if s<0 else 'R'
        x=s*.245
        recoil=empty('Recoil'+side,(x,0,0),pivot)
        empty('Receiver'+side,(0,-.05,.02),recoil)
        # Receiver: chamfered body, side plates, rivets, ejection port.
        box('Receiver body',(0,-.05,0),(.19,.68,.20),'Weapon steel',recoil,.018)
        box('Receiver top rail',(0,-.05,.105),(.20,.62,.025),'Weapon edge',recoil,.008)
        for ps in [-1,1]:
            box('Receiver side plate',(ps*.098,-.06,-.005),(.014,.56,.145),'Weapon steel',recoil,.006)
            for y in [-.28,-.14,0,.14,.26]:
                cyl('Side rivet',(ps*.108,y,.035),.011,.012,'Weapon edge',recoil,'X',8)
                cyl('Side rivet lower',(ps*.108,y,-.055),.011,.012,'Weapon edge',recoil,'X',8)
        box('Ejection port',(s*.104,-.10,-.025),(.012,.16,.07),'Black bore',recoil,.004)
        empty('Ejection'+side,(s*.13,-.10,-.03),recoil)
        rod('Charging handle',(s*.11,.12,.02),(s*.20,.12,.02),.012,'Weapon edge',recoil)
        cyl('Charging knob',(s*.215,.12,.02),.022,.05,'Weapon grip',recoil,'X',12)
        # Hinged top cover and feed tray.
        cover=empty('Cover'+side,(0,.22,.11),recoil)
        box('Top cover',(0,-.245,.018),(.195,.50,.035),'Weapon steel',cover,.012)
        box('Cover rib',(0,-.245,.040),(.055,.44,.014),'Weapon edge',cover,.005)
        for y in [-.42,-.24,-.06]:
            cyl('Cover hinge',(0,y,.005),.018,.21,'Weapon edge',cover,'X',12)
        box('Feed tray',(0,-.08,.095),(.16,.24,.018),'Weapon edge',recoil,.005)
        # Barrel, chamber, cooling rings and slotted muzzle brake.
        cyl('Barrel chamber',(0,-.44,0),.048,.24,'Weapon steel',recoil,'Y',28)
        cyl('Barrel',(0,-1.08,0),.032,1.08,'Weapon steel',recoil,'Y',28)
        for i in range(7):cyl('Barrel ring',(0,-.60-i*.055,0),.040,.012,'Weapon edge',recoil,'Y',24)
        cyl('Muzzle brake',(0,-1.68,0),.052,.16,'Weapon steel',recoil,'Y',28)
        for ps in [-1,1]:
            box('Brake port',(ps*.043,-1.68,0),(.012,.09,.045),'Black bore',recoil,.003)
        cyl('Bore',(0,-1.765,0),.024,.012,'Black bore',recoil,'Y',20)
        empty('Muzzle'+side,(0,-1.79,0),recoil)
        # Sights: protected front post and rear aperture.
        box('Front sight base',(0,-1.50,.055),(.05,.06,.035),'Weapon steel',recoil,.006)
        box('Front sight post',(0,-1.50,.105),(.012,.018,.075),'Weapon edge',recoil,.003)
        for ps in [-1,1]:box('Sight ear',(ps*.028,-1.50,.10),(.010,.025,.075),'Weapon steel',recoil,.003)
        box('Rear sight base',(0,.16,.13),(.06,.05,.035),'Weapon steel',recoil,.006)
        torus('Rear aperture',(0,.16,.19),.028,.006,'Weapon edge',recoil,'Y',20)
        # Back plate, spade grips and butterfly trigger.
        box('Back plate',(0,.31,0),(.20,.05,.21),'Weapon steel',recoil,.012)
        for ps in [-1,1]:
            rod('Spade grip',(ps*.07,.34,-.02),(ps*.105,.50,-.10),.020,'Weapon grip',recoil)
            cyl('Grip cap',(ps*.108,.515,-.108),.026,.045,'Weapon grip',recoil,'Z',12)
        box('Butterfly trigger',(0,.43,-.04),(.045,.025,.09),'Weapon edge',recoil,.006)
        # Ammo can on the outboard side, with lid, ribs and latches.
        ammo=empty('AmmoCan'+side,(s*.43,-.04,-.16),pivot)
        box('Ammo can body',(0,0,0),(.24,.42,.28),'Weapon olive',ammo,.022)
        box('Ammo can lid',(0,0,.15),(.25,.43,.035),'Weapon olive',ammo,.012)
        for y in [-.14,0,.14]:box('Can rib',(0,y,.02),(.25,.025,.24),'Weapon olive',ammo,.006)
        for ps in [-1,1]:box('Can latch',(ps*.125,-.10,.08),(.02,.06,.08),'Weapon edge',ammo,.004)
        rod('Can handle',(-.08,0,.19),(.08,0,.19),.012,'Weapon edge',ammo)
        # Visible disintegrating belt: brass cartridges walking into the feed tray.
        for i in range(8):
            bx=s*(.31-i*.027)
            cyl('Belt cartridge',(bx,-.07,.105),.014,.105,'Weapon brass',pivot,'Y',12)
            cyl('Belt tip',(bx,-.13,.105),.010,.025,'Weapon edge',pivot,'Y',10)
            box('Belt link',(bx,-.045,.105),(.020,.035,.032),'Weapon steel',pivot,.003)
        rod('Feed chute',(s*.34,-.04,.02),(s*.16,-.06,.08),.032,'Weapon olive',pivot)
    finish(r,'mounted_twin_hmg')

def weapon_pedestal(r,shield=False):
    cyl('Base plate',(0,.18,.06),.40,.12,'Weapon olive',r,'Z',36)
    bolts(r,(0,.18,.13),.31,8,'Z',.026,.03,'Weapon edge')
    cyl('Pedestal column',(0,.18,.46),.15,.72,'Weapon olive',r,'Z',28)
    for z in [.22,.66]:cyl('Pedestal collar',(0,.18,z),.185,.05,'Weapon edge',r,'Z',28)
    cyl('Traverse ring',(0,.12,.86),.35,.10,'Weapon steel',r,'Z',40)
    bolts(r,(0,.12,.92),.28,10,'Z',.022,.028,'Weapon edge')
    box('Cradle bed',(0,.06,1.00),(.62,.52,.13),'Weapon olive',r,.03)
    for s in [-1,1]:
        box('Cradle cheek',(s*.30,.02,1.08),(.06,.54,.24),'Weapon olive',r,.02)
        cyl('Trunnion',(s*.33,0,1.10),.08,.09,'Weapon edge',r,'X',20)
    torus('Elevation wheel',(0,.38,1.00),.10,.013,'Weapon edge',r,'Y',22)
    rod('Elevation screw',(0,.32,.90),(0,.32,1.12),.024,'Weapon edge',r)
    if shield:
        for s in [-1,1]:box('Low shield',(s*.42,-.18,1.18),(.30,.04,.34),'Weapon olive',r,.02,(math.radians(-6),0,s*.05))
    return empty('BarrelPivot',(0,0,1.10),r)

def mounted_cannon():
    r=reset('MountedCannon')
    material('Weapon steel',(.075,.082,.085),.88,.48)
    material('Weapon edge',(.18,.19,.19),.9,.38)
    material('Weapon olive',(.105,.125,.082),.22,.7)
    material('Weapon grip',(.025,.027,.026),.02,.92)
    material('Weapon brass',(.46,.33,.12),.85,.34)
    pivot=weapon_pedestal(r,True)
    recoil=empty('RecoilAssembly',(0,0,0),pivot)
    box('Breech block',(0,.22,0),(.30,.34,.26),'Weapon steel',recoil,.03)
    box('Breech face',(0,.40,0),(.26,.04,.22),'Weapon edge',recoil,.01)
    empty('Breech',(0,.30,.14),recoil)
    cyl('Barrel jacket',(0,-.30,0),.095,.50,'Weapon olive',recoil,'Y',28)
    cyl('Barrel',(0,-1.20,0),.055,1.40,'Weapon steel',recoil,'Y',28)
    for y in [-.62,-.80]:cyl('Barrel collar',(0,y,0),.070,.05,'Weapon edge',recoil,'Y',24)
    cyl('Muzzle brake',(0,-1.98,0),.085,.22,'Weapon steel',recoil,'Y',28)
    for s in [-1,1]:
        box('Brake port',(s*.082,-1.98,0),(.012,.14,.07),'Black bore',recoil,.003)
        cyl('Recuperator',(s*.12,-.20,.10),.045,.46,'Weapon edge',recoil,'Y',18)
        rod('Recuperator rod',(s*.12,-.44,.10),(s*.12,-.62,.10),.02,'Weapon steel',recoil)
    cyl('Bore',(0,-2.10,0),.032,.012,'Black bore',recoil,'Y',20)
    empty('Muzzle',(0,-2.12,0),recoil)
    empty('EjectionL',(.20,.25,-.05),recoil)
    rod('Operating lever',(.18,.30,.08),(.34,.42,.14),.018,'Weapon edge',pivot)
    box('Sight housing',(.22,-.10,.20),(.12,.18,.12),'Weapon olive',pivot,.02)
    cyl('Optic glass',(.22,-.20,.22),.035,.015,'Glass',pivot,'Y',16)
    box('Ammo tray',(-.24,.10,-.08),(.18,.28,.04),'Weapon edge',pivot,.008)
    for i in range(3):cyl('Shell',( -.24,.02+i*.08,-.04),.025,.07,'Weapon brass',pivot,'Y',12)
    finish(r,'mounted_cannon')

def mounted_rocket():
    r=reset('MountedRocket')
    material('Weapon steel',(.075,.082,.085),.88,.48)
    material('Weapon edge',(.18,.19,.19),.9,.38)
    material('Weapon olive',(.105,.125,.082),.22,.7)
    material('Weapon grip',(.025,.027,.026),.02,.92)
    material('Warning',(.7,.32,.075),.25,.6)
    pivot=weapon_pedestal(r,False)
    recoil=empty('RecoilAssembly',(0,0,0),pivot)
    box('Pod frame',(0,-.28,0),(.56,.90,.44),'Weapon olive',recoil,.04)
    for x in [-.15,.15]:
        for z in [-.11,.11]:
            cyl('Launch tube',(x,-.40,z),.10,1.10,'Weapon steel',recoil,'Y',24)
            torus('Tube rim',(x,-.95,z),.10,.012,'Weapon edge',recoil,'Y',20)
            cyl('Rocket nose',(x,-.80,z),.065,.16,'Warning',recoil,'Y',16)
            cyl('Tube cap',(x,.16,z),.09,.03,'Weapon edge',recoil,'Y',18)
    empty('Muzzle',(0,-.98,0),recoil)
    box('Breech plate',(0,.20,0),(.50,.06,.40),'Weapon steel',recoil,.015)
    empty('Breech',(0,.22,.20),recoil)
    for s in [-1,1]:
        rod('Pod brace',(s*.28,.10,-.18),(s*.28,-.60,-.18),.02,'Weapon edge',recoil)
        rod('Handle',(s*.26,.24,-.10),(s*.30,.44,-.18),.02,'Weapon grip',pivot)
    box('Optic housing',(0,.02,.30),(.24,.22,.16),'Weapon olive',pivot,.025)
    cyl('Optic glass',(0,-.10,.32),.05,.015,'Glass',pivot,'Y',16)
    box('Junction box',(.24,.10,.18),(.10,.14,.08),'Weapon steel',pivot,.012)
    hose(pivot,[(.24,.10,.14),(.28,-.10,.10),(.24,-.30,.05)],.012)
    finish(r,'mounted_rocket')

def mounted_autocannon():
    r=reset('MountedAutocannon')
    material('Weapon steel',(.075,.082,.085),.88,.48)
    material('Weapon edge',(.18,.19,.19),.9,.38)
    material('Weapon olive',(.105,.125,.082),.22,.7)
    material('Weapon grip',(.025,.027,.026),.02,.92)
    material('Weapon brass',(.46,.33,.12),.85,.34)
    pivot=weapon_pedestal(r,True)
    recoil=empty('RecoilAssembly',(0,0,0),pivot)
    box('Receiver',(0,-.10,0),(.26,.62,.24),'Weapon steel',recoil,.025)
    box('Top cover',(0,-.10,.13),(.27,.56,.035),'Weapon edge',recoil,.01)
    for s in [-1,1]:
        for y in [-.30,-.15,0,.15]:cyl('Receiver rivet',(s*.135,y,.04),.010,.012,'Weapon edge',recoil,'X',8)
    cyl('Barrel',(0,-1.00,0),.038,1.30,'Weapon steel',recoil,'Y',24)
    spin=empty('BarrelSpin',(0,-.55,0),recoil)
    cyl('Barrel shroud',(0,-.10,0),.065,.40,'Weapon edge',spin,'Y',24)
    for i in range(5):torus('Shroud ring',(0,-.26+i*.08,0),.066,.008,'Weapon steel',spin,'Y',18)
    cyl('Flash hider',(0,-1.72,0),.060,.18,'Weapon steel',recoil,'Y',24)
    for s in [-1,1]:box('Hider port',(s*.058,-1.72,0),(.010,.10,.05),'Black bore',recoil,.003)
    cyl('Bore',(0,-1.82,0),.022,.012,'Black bore',recoil,'Y',18)
    empty('Muzzle',(0,-1.84,0),recoil)
    cyl('Ammo drum',(.24,.02,-.10),.18,.14,'Weapon olive',recoil,'X',24)
    torus('Drum rim',(.31,.02,-.10),.18,.012,'Weapon edge',recoil,'X',24)
    box('Feed chute',(.14,-.08,-.02),(.16,.24,.10),'Weapon steel',recoil,.015)
    box('Breech',(0,.24,0),(.22,.20,.20),'Weapon edge',recoil,.02)
    empty('EjectionL',(.18,.10,-.08),recoil)
    box('Sight',(0,-.28,.20),(.12,.16,.12),'Weapon olive',pivot,.02)
    cyl('Optic glass',(0,-.37,.22),.035,.015,'Glass',pivot,'Y',16)
    for s in [-1,1]:rod('Spade grip',(s*.10,.30,-.04),(s*.14,.46,-.12),.018,'Weapon grip',pivot)
    finish(r,'mounted_autocannon')

def _load_uploaded_infantry():
    """Read the converter's output. Fails loudly rather than silently shipping
    the old procedural stand-in, so CI cannot drift from the uploaded source."""
    path=os.path.join(SRC,'uploaded_soldier.json')
    if not os.path.exists(path):
        raise RuntimeError('uploaded_soldier.json is missing; run '
                           'tools/import_max_soldier.py before create_models.py')
    with open(path,encoding='utf8') as handle:doc=json.load(handle)
    if doc.get('schema')!='artillery.uploaded-infantry/2':
        raise RuntimeError('unexpected infantry schema %r'%doc.get('schema'))
    return doc

def _atlas_material(name,texture,rough):
    """Diffuse-atlas material. The atlases are UV-mapped, not triplanar, so the
    runtime MaterialLibrary deliberately leaves these three names untouched."""
    m=material(name,(1,1,1),0.,rough)
    path=os.path.join(ROOT,'assets','textures','uploaded',texture)
    if not os.path.exists(path):
        raise RuntimeError('missing decoded atlas %s'%path)
    image=bpy.data.images.load(path,check_existing=True)
    image.colorspace_settings.name='sRGB'
    nodes=m.node_tree.nodes
    tex=nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Linear'
    m.node_tree.links.new(tex.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
    return m

def _infantry_mesh(name,doc,root,group_names):
    """One mesh per atlas. Splitting by material keeps export_glb's one-primitive
    -per-mesh contract and avoids a multi-material Godot surface."""
    names=[m['name'] for m in doc['materials']]
    keep=[i for i,m in enumerate(doc['face_material']) if names[m]==name]
    if not keep:return None
    faces=[doc['faces'][i] for i in keep]
    map_faces=[doc['map_faces'][i] for i in keep]
    remap={};verts=[];weights=[]
    for face in faces:
        for vi in face:
            if vi not in remap:
                remap[vi]=len(verts)
                verts.append(doc['vertices'][vi])
                weights.append(doc['weights'][vi])
    data=bpy.data.meshes.new(name)
    data.from_pydata(verts,[],[tuple(remap[v] for v in f) for f in faces])
    data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o)
    o.parent=root
    o.data.materials.append(M[name])
    uv=data.uv_layers.new(name='UVMap')
    for pi,poly in enumerate(data.polygons):
        for li,corner in zip(poly.loop_indices,range(3)):
            uv.data[li].uv=doc['uvs'][map_faces[pi][corner]]
        # Hard edges are already duplicated at the smoothing-group seams, so a
        # plain averaged normal reproduces the 3ds Max shading.
        poly.use_smooth=True
    groups={g:o.vertex_groups.new(name=g) for g in group_names}
    for vi,influences in enumerate(weights):
        for joint,weight in influences:
            if weight>1e-5:groups[group_names[joint]].add([vi],weight,'REPLACE')
    return o

def soldier():
    """User-supplied 3ds Max infantryman, re-rigged for the coastal gait.

    Geometry, UVs, atlases, the 11-bone skeleton, the skin weights and the baked
    low-ready rifle grip all come from tools/import_max_soldier.py. This builder
    only instantiates them and adds the project's original rifle, so the asset
    stays reproducible in CI from the uploaded source files.
    """
    r=reset('Soldier')
    doc=_load_uploaded_infantry()
    bones=[j['name'] for j in doc['joints']]
    if bones!=SKIN_BONES:
        raise RuntimeError('rig order %s does not match SKIN_BONES'%bones)
    material('Rifle wood',(.24,.15,.08),.05,.68)
    material('Weapon steel',(.075,.082,.085),.88,.48)
    material('Weapon edge',(.18,.19,.19),.9,.38)
    # One mesh per distinct atlas. Material index 3 reuses the body atlas, so
    # collapse duplicates onto the first index that declared the name.
    canonical={}
    for index,entry in enumerate(doc['materials']):
        canonical.setdefault(entry['name'],index)
    for name,index in canonical.items():
        entry=doc['materials'][index]
        _atlas_material(name,entry['texture'],.62 if 'head' in name else .86)
    pivots={}
    for record in doc['joints']:
        parent=pivots[record['parent']] if record['parent'] else r
        pivot=empty(record['name'],record['translation'],parent)
        pivot.rotation_mode='QUATERNION'
        x,y,z,w=record['rotation']
        pivot.rotation_quaternion=(w,x,y,z)
        pivots[record['name']]=pivot
    for name in canonical:
        _infantry_mesh(name,doc,r,bones)
    # Original rifle. The grip is already baked into the mesh, so the weapon is
    # rigidly parented to Torso and never re-solved at runtime.
    spec=doc['rifle']
    rifle=empty('Rifle',spec['translation'],pivots[spec['parent']])
    rifle.rotation_euler=spec['rotation_euler']
    for part in spec['parts']:
        loc=part['location'];dim=part['dimensions']
        if part['kind']=='box':
            box(part['name'],loc,dim,part['material'],rifle,part['extra'])
        else:
            cyl(part['name'],loc,dim[0],dim[1],part['material'],rifle,part['extra'],14)
    empty('Muzzle',spec['muzzle_translation'],rifle)
    finish(r,'soldier',skin=True)

def landing_craft():
    r=reset('LandingCraft')
    box('Hull',(0,0,.8),(4.2,11.5,1.6),'Sand armor',r,.35)
    box('Deck',(0,.2,1.65),(3.8,10.5,.16),'Field olive',r,.06)
    for s in [-1,1]:
        box('Gunwale',(s*2.0,0,1.9),(.18,11.0,.5),'Sand armor',r,.08)
        for i in range(10):box('Hull rib',(s*2.1,-4.5+i*1.0,.9),(.06,.10,1.2),'Armor edge',r,.015)
        for y in [-3,-1,1,3]:
            box('Cleat',(s*1.9,y,2.15),(.12,.3,.12),'Gun steel',r,.02)
            torus('Tire fender',(s*2.15,y,.9),.22,.07,'Rubber',r,'X',14)
    ramp=empty('Ramp',(0,-5.7,1.2),r)
    box('Ramp plate',(0,-1.4,0),(3.6,2.8,.16),'Armor edge',r,.05)
    for i in range(8):box('Ramp tread',(0,-.3-i*.32,.10),(3.4,.06,.04),'Gun steel',r,.005)
    for s in [-1,1]:
        box('Ramp hinge',(s*1.6,-.1,0),(.22,.18,.22),'Gun steel',r,.03)
        rod('Ramp cable',(s*1.7,-5.5,2.2),(s*1.7,-7.8,1.3),.03,'Gun steel',r)
        cyl('Ramp winch',(s*1.7,-5.3,2.2),.10,.16,'Gun steel',r,'X',12)
    box('Superstructure',(0,3.8,2.6),(2.6,2.4,1.8),'Sand armor',r,.16)
    box('Bridge glass',(0,2.55,2.9),(2.2,.05,.6),'Glass',r,.02)
    for x in [-.7,0,.7]:box('Window divider',(x,2.53,2.9),(.05,.06,.62),'Gun steel',r,.005)
    box('Bridge roof',(0,3.8,3.55),(2.7,2.5,.12),'Armor edge',r,.04)
    cyl('Mast',(0,4.2,4.0),.06,1.8,'Gun steel',r,'Z',10)
    radar=empty('Radar',(0,4.2,4.9),r)
    box('Radar bar',(0,0,0),(.7,.12,.16),'Gun steel',radar,.02)
    rod('Radar brace',(0,0,-.1),(0,0,-.4),.03,'Gun steel',radar)
    for s in [-1,1]:
        cyl('Exhaust',(s*.9,4.6,3.2),.07,.5,'Gun steel',r,'Z',10)
        prop=empty('Propeller%s'%('L' if s<0 else 'R'),(s*1.2,5.4,.35),r)
        cyl('Prop hub',(0,0,0),.08,.14,'Recoil steel',prop,'Y',10)
        for i in range(3):
            a=i*math.tau/3
            blade=box('Prop blade',(math.cos(a)*.22,0,math.sin(a)*.22),(.34,.03,.10),'Recoil steel',prop,.01)
            blade.rotation_euler[1]=a
        rod('Shaft',(s*1.2,4.8,.35),(s*1.2,5.4,.35),.04,'Gun steel',r)
        box('Rudder',(s*1.2,5.7,.35),(.06,.4,.5),'Armor edge',r,.02)
    box('Bow gun shield',(0,-4.6,2.1),(.6,.08,.4),'Armor edge',r,.03)
    cyl('Bow gun',(0,-4.9,2.2),.03,.6,'Gun steel',r,'Y',10)
    finish(r,'landing_craft')

def helicopter():
    r=reset('Helicopter')
    sphere('Fuselage',(0,0,1.1),(1.1,2.6,1.1),'Field olive',r,24,16)
    sphere('Nose',(0,-2.2,1.0),(.75,.8,.7),'Field olive',r,20,12)
    box('Cabin glass',(0,-1.9,1.45),(.95,.75,.55),'Glass',r,.12)
    box('Glass divider',(0,-2.28,1.45),(.04,.06,.56),'Gun steel',r,.005)
    for s in [-1,1]:
        box('Side window',(s*1.02,-.6,1.45),(.05,.9,.45),'Glass',r,.03)
        box('Door frame',(s*1.05,-.1,1.1),(.06,1.2,.9),'Armor edge',r,.03)
        box('Door handle',(s*1.1,-.5,1.1),(.04,.16,.04),'Gun steel',r,.01)
        for i in range(6):cyl('Fuselage rivet',(s*1.08,-1.4+i*.5,1.8),.015,.02,'Recoil steel',r,'X',6)
    box('Engine housing',(0,.6,2.0),(1.0,1.6,.5),'Armor edge',r,.12)
    for s in [-1,1]:
        cyl('Exhaust',(s*.55,1.3,2.0),.12,.4,'Gun steel',r,'Y',12)
        cyl('Exhaust bore',(s*.55,1.52,2.0),.09,.02,'Black bore',r,'Y',12)
        box('Stub wing',(s*1.3,-.1,1.0),(.9,.5,.12),'Field olive',r,.04)
        cyl('Rocket pod',(s*1.5,-.35,.85),.14,.7,'Gun steel',r,'Y',12)
        for i in range(4):cyl('Pod tube',(s*1.5+math.cos(i*math.tau/4)*.07,-.72,.85+math.sin(i*math.tau/4)*.07),.03,.02,'Black bore',r,'Y',8)
        cyl('Gun pod',(s*1.1,-.5,.75),.08,.6,'Gun steel',r,'Y',10)
    box('Tail boom',(0,3.4,1.3),(.34,4.2,.34),'Field olive',r,.1)
    for i in range(5):box('Boom rib',(0,1.8+i*.7,1.3),(.38,.06,.38),'Armor edge',r,.01)
    box('Tail fin',(0,5.3,1.9),(.12,.7,1.2),'Armor edge',r,.05)
    box('Horizontal stabilizer',(0,4.9,1.4),(1.6,.4,.06),'Field olive',r,.02)
    rotor=empty('Rotor',(0,0,2.35),r)
    cyl('Rotor mast',(0,0,-.12),.08,.25,'Gun steel',rotor,'Z',10)
    cyl('Rotor hub',(0,0,0),.16,.18,'Gun steel',rotor,'Z',12)
    for i in range(4):
        a=i*math.tau/4
        rod('Pitch link',(math.cos(a)*.12,math.sin(a)*.12,.05),(math.cos(a)*.35,math.sin(a)*.35,.06),.015,'Recoil steel',rotor)
        blade=box('Blade',(math.cos(a)*2.4,math.sin(a)*2.4,.06),(4.8,.22,.04),'Black bore',rotor,.01)
        blade.rotation_euler[2]=a
        box('Blade tip',(math.cos(a)*4.65,math.sin(a)*4.65,.06),(.3,.24,.05),'Warning',rotor,.01).rotation_euler[2]=a
    tail=empty('TailRotor',(0.22,5.3,1.9),r)
    cyl('Tail hub',(0,0,0),.05,.08,'Gun steel',tail,'X',8)
    for i in range(4):
        a=i*math.tau/4
        blade=box('Tail blade',(0,math.cos(a)*.28,math.sin(a)*.28),(.04,.5,.07),'Black bore',tail,.005)
        blade.rotation_euler[0]=a
    for s in [-1,1]:
        rod('Skid',(s*.8,-1.4,.15),(s*.8,1.6,.15),.05,'Gun steel',r)
        rod('Skid strut F',(s*.7,-.9,.2),(s*.8,-.9,.7),.04,'Gun steel',r)
        rod('Skid strut R',(s*.7,.9,.2),(s*.8,.9,.7),.04,'Gun steel',r)
        rod('Skid brace',(s*.8,-.9,.2),(s*.8,.9,.2),.03,'Gun steel',r)
    rod('Antenna',(0,2.0,1.6),(0,2.2,2.6),.012,'Gun steel',r)
    cyl('Pitot tube',(0,-2.9,.9),.015,.3,'Recoil steel',r,'Y',8)
    finish(r,'helicopter')

def patrol_boat():
    r=reset('PatrolBoat')
    box('Hull',(0,0,.5),(2.2,7.0,1.0),'Sand armor',r,.28)
    mesh('Bow wedge',[(-1.1,-3.5,.0),(1.1,-3.5,.0),(0,-4.4,.5),(-1.1,-3.5,1.0),(1.1,-3.5,1.0)],[(0,1,2),(0,2,3),(1,4,2),(3,2,4),(0,3,4,1)],'Sand armor',r)
    box('Deck',(0,0,1.05),(2.0,6.4,.12),'Field olive',r,.05)
    for s in [-1,1]:
        box('Gunwale',(s*1.0,0,1.25),(.10,6.6,.25),'Armor edge',r,.03)
        for i in range(6):box('Hull strake',(s*1.12,-2.5+i, .55),(.05,.8,.08),'Gun steel',r,.01)
        for y in [-2,-0.5,1.5,2.8]:torus('Fender',(s*1.15,y,.75),.14,.05,'Rubber',r,'X',12)
    box('Cabin',(0,.8,1.7),(1.5,1.8,1.1),'Sand armor',r,.12)
    box('Cabin glass',(0,-.12,1.85),(1.2,.05,.45),'Glass',r,.02)
    for x in [-.4,0,.4]:box('Window divider',(x,-.14,1.85),(.04,.06,.47),'Gun steel',r,.005)
    box('Cabin roof',(0,.8,2.3),(1.6,1.9,.10),'Armor edge',r,.03)
    cyl('Mast',(0,1.4,2.8),.04,1.2,'Gun steel',r,'Z',8)
    radar=empty('Radar',(0,1.4,3.4),r)
    box('Radar bar',(0,0,0),(.5,.08,.10),'Gun steel',radar,.015)
    rod('Whip antenna',(.6,1.6,2.3),(.65,1.7,3.6),.01,'Gun steel',r)
    pivot=empty('BarrelPivot',(0,-2.0,1.3),r)
    box('Gun shield',(0,-.1,.1),(.5,.08,.4),'Armor edge',pivot,.03)
    recoil=empty('RecoilAssembly',(0,0,0),pivot)
    cyl('Bow gun',(0,-.35,.1),.04,.7,'Gun steel',recoil,'Y',12)
    empty('Muzzle',(0,-.72,.1),recoil)
    box('Ammo box',(.25,.1,.0),(.16,.2,.14),'Field olive',pivot,.02)
    for s in [-1,1]:
        prop=empty('Propeller%s'%('L' if s<0 else 'R'),(s*.6,3.4,.2),r)
        cyl('Prop hub',(0,0,0),.06,.1,'Recoil steel',prop,'Y',8)
        for i in range(3):
            a=i*math.tau/3
            box('Prop blade',(math.cos(a)*.16,0,math.sin(a)*.16),(.24,.02,.08),'Recoil steel',prop,.008).rotation_euler[1]=a
        box('Rudder',(s*.6,3.7,.2),(.05,.3,.4),'Armor edge',r,.015)
    box('Depth charge rack',(0,2.8,1.25),(1.0,.6,.2),'Gun steel',r,.03)
    for x in [-.3,0,.3]:cyl('Depth charge',(x,2.8,1.45),.10,.3,'Field olive',r,'Y',10)
    finish(r,'patrol_boat')
def bazooka():
    r=reset('Bazooka')
    material('Weapon steel',(.075,.082,.085),.88,.48)
    material('Weapon edge',(.18,.19,.19),.9,.38)
    material('Weapon olive',(.105,.125,.082),.22,.7)
    material('Weapon grip',(.025,.027,.026),.02,.92)
    material('Rifle wood',(.24,.15,.08),.05,.68)
    material('Webbing',(.10,.12,.08),0.,.95)
    material('Warning',(.7,.32,.075),.25,.6)
    pivot=empty('BarrelPivot',(0,0,1.05),r)
    recoil=empty('RecoilAssembly',(0,0,0),pivot)
    cyl('Launch tube',(0,-.35,0),.075,1.50,'Weapon olive',recoil,'Y',28)
    for y in [-.95,-.30,.25]:torus('Tube band',(0,y,0),.077,.010,'Weapon edge',recoil,'Y',22)
    cyl('Front collar',(0,-1.10,0),.085,.07,'Weapon edge',recoil,'Y',24)
    cyl('Rear venturi',(0,.42,0),.10,.18,'Weapon steel',recoil,'Y',24)
    cyl('Venturi bore',(0,.52,0),.075,.012,'Black bore',recoil,'Y',20)
    cyl('Rocket nose',(0,-1.14,0),.052,.14,'Warning',recoil,'Y',16)
    empty('Muzzle',(0,-1.24,0),recoil)
    box('Shoulder rest',(0,.18,-.12),(.16,.34,.08),'Rifle wood',pivot,.025)
    box('Shoulder pad',(0,.30,-.15),(.18,.10,.10),'Weapon grip',pivot,.02)
    box('Front grip',(0,-.45,-.12),(.06,.10,.16),'Rifle wood',pivot,.02)
    box('Rear grip',(0,.10,-.14),(.06,.10,.18),'Rifle wood',pivot,.02)
    box('Trigger guard',(0,.02,-.10),(.04,.10,.015),'Weapon steel',pivot,.004)
    box('Sight ladder',(0,-.55,.12),(.04,.22,.10),'Weapon steel',pivot,.008)
    torus('Sight ring',(0,-.62,.18),.035,.006,'Weapon edge',pivot,'Y',16)
    box('Front sight',(0,-.95,.10),(.012,.02,.06),'Weapon steel',pivot,.003)
    rod('Sling',(0,.20,-.08),(0,-.50,-.08),.008,'Webbing',pivot)
    box('Breech',(0,.34,0),(.16,.10,.16),'Weapon steel',recoil,.015)
    empty('Breech',(0,.36,.08),recoil)
    finish(r,'bazooka')

def fighter():
    r=reset('Fighter')
    sphere('Fuselage',(0,0,1.0),(.62,4.6,.72),'Sand armor',r,28,16)
    sphere('Nose cone',(0,-4.3,1.0),(.30,.7,.32),'Armor edge',r,18,10)
    rod('Pitot',(0,-4.9,1.0),(0,-5.3,1.0),.015,'Recoil steel',r)
    sphere('Canopy',(0,-1.7,1.55),(.42,1.1,.42),'Glass',r,20,12)
    box('Canopy frame',(0,-1.7,1.75),(.05,1.8,.05),'Gun steel',r,.01)
    box('Ejection seat',(0,-1.5,1.35),(.3,.4,.3),'Black bore',r,.03)
    mesh('Main wing',[(-.55,-.4,1.0),(-4.4,1.3,.82),(-3.7,2.2,.82),(-.5,1.2,1.0),(.55,-.4,1.0),(4.4,1.3,.82),(3.7,2.2,.82),(.5,1.2,1.0)],[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'Sand armor',r)
    for s in [-1,1]:
        side='L' if s<0 else 'R'
        aileron=empty('Aileron'+side,(s*3.2,1.85,.84),r)
        box('Aileron surface',(0,0,0),(1.3,.35,.05),'Armor edge',aileron,.015)
        box('Wing fence',(s*2.4,.9,1.0),(.05,.9,.18),'Sand armor',r,.01)
        cyl('Wingtip missile',(s*4.35,1.5,.82),.06,.8,'Gun steel',r,'Y',10)
        cyl('Missile nose',(s*4.35,1.08,.82),.04,.12,'Warning',r,'Y',10)
        for i in range(4):
            a=i*math.tau/4
            box('Missile fin',(s*4.35+math.cos(a)*.06,1.85,.82+math.sin(a)*.06),(.02,.16,.08),'Gun steel',r,.005)
    mesh('Tail wing',[(-.4,3.4,1.1),(-1.9,4.3,1.0),(-1.5,4.8,1.0),(-.3,4.2,1.1),(.4,3.4,1.1),(1.9,4.3,1.0),(1.5,4.8,1.0),(.3,4.2,1.1)],[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'Sand armor',r)
    for s in [-1,1]:
        side='L' if s<0 else 'R'
        elevator=empty('Elevator'+side,(s*1.1,4.5,1.05),r)
        box('Elevator surface',(0,0,0),(1.0,.3,.05),'Armor edge',elevator,.012)
    box('Vertical tail',(0,3.9,1.9),(.12,1.3,1.5),'Sand armor',r,.05)
    rudder=empty('Rudder',(0,4.45,2.0),r)
    box('Rudder surface',(0,0,0),(.10,.35,1.2),'Armor edge',rudder,.02)
    for s in [-1,1]:
        cyl('Engine nozzle',(s*.32,4.35,.95),.24,.3,'Gun steel',r,'Y',18)
        for i in range(12):
            a=i*math.tau/12
            box('Nozzle petal',(s*.32+math.cos(a)*.22,4.48,.95+math.sin(a)*.22),(.06,.10,.05),'Recoil steel',r,.01)
        burner=empty('Afterburner%s'%('L' if s<0 else 'R'),(s*.32,4.55,.95),r)
        cyl('Burner glow',(0,0,0),(.16),.04,'Lamp',burner,'Y',12)
        cyl('Intake',(s*.5,-.6,.7),.22,.5,'Black bore',r,'Y',16)
        box('Intake lip',(s*.5,-.85,.7),(.5,.06,.5),'Armor edge',r,.02)
        box('Pylon',(s*2.2,.9,.65),(.12,.8,.3),'Gun steel',r,.02)
        cyl('Drop tank',(s*2.2,.9,.35),.16,1.0,'Field olive',r,'Y',14)
        for y in [.55,1.25]:torus('Tank strap',(s*2.2,y,.35),.17,.015,'Gun steel',r,'Y',12)
        box('Gear door',(s*.45,.2,.45),(.08,.9,.06),'Armor edge',r,.01)
    for i in range(6):box('Spine panel',(0,-.5+i*.7,1.72),(.5,.05,.04),'Armor edge',r,.005)
    rod('Antenna',(0,2.2,1.6),(0,2.4,2.3),.012,'Gun steel',r)
    finish(r,'fighter')

BUILDERS={'kestrel':kestrel,'warden':warden,'nomad':nomad,'sentry':sentry,'hangar':hangar,'mounted_twin_hmg':mounted_twin_hmg,'mounted_cannon':mounted_cannon,'mounted_rocket':mounted_rocket,'mounted_autocannon':mounted_autocannon,'soldier':soldier,'landing_craft':landing_craft,'helicopter':helicopter,'patrol_boat':patrol_boat,'bazooka':bazooka,'fighter':fighter}

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    only=args[args.index('--only')+1].split(',') if '--only' in args else list(BUILDERS)
    for name in only:
        if name not in BUILDERS:raise SystemExit('Unknown model: '+name)
        BUILDERS[name]()
