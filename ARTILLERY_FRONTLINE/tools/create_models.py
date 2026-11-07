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
def mesh(name,verts,faces,mat,parent=None):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o)
    adopt(o,name,mat,parent);return o
def reset(name):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for m in list(bpy.data.materials):
        if m.users==0:bpy.data.materials.remove(m)
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
def finish(root,name):
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
    export_glb(root,os.path.join(OUT,name+'.glb'))
    print('CREATED',name, len(bpy.data.objects),'objects')

def wheel(parent,x,y,z,r=.91,width=.48):
    cyl('Tire',(x,y,z),r,width,'Rubber',parent,'X',32)
    cyl('Rim',(x+math.copysign(width*.52,x),y,z),r*.57,.06,'Armor edge',parent,'X',24)
    bolts(parent,(x+math.copysign(width*.56,x),y,z),r*.40,8,'X',.03,.05)
    cyl('Hub',(x+math.copysign(width*.64,x),y,z),r*.22,.14,'Gun steel',parent,'X',20)
    for i in range(8):
        a=i*math.tau/8
        cyl('Hub bolt',(x+math.copysign(width*.68,x),y+math.sin(a)*r*.38,z+math.cos(a)*r*.38),.045,.06,'Recoil steel',parent,'X',6)
    for i in range(24):
        a=i*math.tau/24
        o=box('Tread',(x,y+math.sin(a)*r,z+math.cos(a)*r),(.52,.14,.08),'Rubber',parent,.015)
        o.rotation_euler[0]=-a

def export_glb(root,path):
    """Direct standards-compliant GLB writer, independent of Blender's bundled
    glTF addon (Ubuntu's Blender package has an incompatible addon runtime).
    Evaluated geometry and named animation pivots are preserved exactly.
    """
    convert=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
    inverse=convert.inverted()
    objects=[root]+list(root.children_recursive)
    indices={o.name:i for i,o in enumerate(objects)}
    doc={'asset':{'version':'2.0','generator':'ARTILLERY FRONTLINE original Blender pipeline'},
         'scene':0,'scenes':[{'nodes':[0]}],'nodes':[],'meshes':[],'materials':[],
         'accessors':[],'bufferViews':[],'buffers':[]}
    material_indices={}; binary=bytearray()
    def accessor(values,fmt,components,target,minimum=None,maximum=None):
        nonlocal binary
        while len(binary)%4:binary.append(0)
        payload=struct.pack('<'+fmt*(len(values)*components),*[c for v in values for c in v]) if components>1 else struct.pack('<'+fmt*len(values),*values)
        view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':len(payload),'target':target})
        binary.extend(payload)
        typ={1:'SCALAR',2:'VEC2',3:'VEC3',4:'VEC4'}[components]
        component_type={'f':5126,'I':5125,'H':5123}[fmt]
        a={'bufferView':view,'componentType':component_type,'count':len(values),'type':typ}
        if minimum is not None:a['min']=minimum;a['max']=maximum
        index=len(doc['accessors']);doc['accessors'].append(a);return index
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
        positions=[tuple(convert.to_3x3() @ v.co) for v in mesh.vertices]
        normals=[tuple((convert.to_3x3() @ v.normal).normalized()) for v in mesh.vertices]
        triangles=[tuple(t.vertices) for t in mesh.loop_triangles]
        if not triangles:
            evaluated.to_mesh_clear();continue
        pa=accessor(positions,'f',3,34962,[min(p[k] for p in positions) for k in range(3)],[max(p[k] for p in positions) for k in range(3)])
        na=accessor(normals,'f',3,34962)
        ia=accessor(triangles,'I',3,34963)
        source=o.data.materials[0] if o.data.materials else None
        if source.name not in material_indices:
            bs=source.node_tree.nodes.get('Principled BSDF')
            color=list(bs.inputs['Base Color'].default_value)
            pbr={'baseColorFactor':color,'metallicFactor':float(bs.inputs['Metallic'].default_value),'roughnessFactor':float(bs.inputs['Roughness'].default_value)}
            material_indices[source.name]=len(doc['materials']);doc['materials'].append({'name':source.name,'pbrMetallicRoughness':pbr,'doubleSided':False})
        doc['meshes'].append({'name':o.data.name,'primitives':[{'attributes':{'POSITION':pa,'NORMAL':na},'indices':ia,'material':material_indices[source.name]}]})
        node['mesh']=len(doc['meshes'])-1
        evaluated.to_mesh_clear()
    doc['buffers']=[{'byteLength':len(binary)}]
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
        box('Track belt',(s*2.0,0,.78),(.8,6.9,1.35),'Rubber',r,.3)
        for y in [-2.5,-1.25,0,1.25,2.5]:wheel(r,s*2.16,y,.75,.58,.45)
        for i in range(26):
            box('Track shoe',(s*2.0,-3.25+i*.25,1.47),(.87,.18,.1),'Gun steel',r,.012)
            box('Track shoe lower',(s*2.0,-3.25+i*.25,.12),(.87,.18,.08),'Gun steel',r,.01)
        box('Side skirt',(s*2.3,0,1.65),(.22,6.6,.65),'Field olive',r,.05)
        for i in range(6):box('ERA skirt',(s*2.44,-2.55+i*1.02,1.72),(.18,.88,.5),'Armor edge',r,.04)
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
    cyl('Tank gun',(0,-3.2,.55),.12,4.2,'Gun steel',turret,'Y')
    cyl('Fume extractor',(0,-2.6,.55),.2,.75,'Field olive',turret,'Y')
    cyl('Muzzle',(0,-5.32,.55),.15,.18,'Gun steel',turret,'Y')
    cyl('Bore',(0,-5.42,.55),.09,.02,'Black bore',turret,'Y')
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
        for y in [-2.65,.8,2.55]:wheel(r,x,y,.82,.73,.46)
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
    r=reset('MountedTwinHMG')
    pivot=weapon_base(r,False)
    for sx in [-1,1]:
        box('Low side rail',(sx*.56,-.15,-.08),(.12,.75,.16),'Armor edge',pivot,.03)
    box('Shared cradle',(0,-.1,.02),(1.05,.7,.22),'Armor edge',pivot,.06)
    recoil=empty('RecoilAssembly',(0,0,0),pivot)
    for s in [-1,1]:
        x=s*.3
        box('Receiver',(x,-.18,0),(.34,.72,.26),'Gun steel',recoil,.05)
        box('Top cover',(x,-.18,.16),(.3,.66,.06),'Armor edge',recoil,.025)
        box('Feed tray',(x,-.05,.19),(.22,.3,.04),'Recoil steel',recoil,.015)
        cyl('Barrel',(x,-1.35,0),.042,1.6,'Gun steel',recoil,'Y',20)
        cyl('Cooling jacket',(x,-.93,0),.062,.62,'Armor edge',recoil,'Y',20)
        for i in range(5):cyl('Jacket ring',(x,-.71-i*.11,0),.065,.025,'Gun steel',recoil,'Y',16)
        box('Muzzle brake',(x,-2.19,0),(.11,.18,.11),'Gun steel',recoil,.02)
        empty('MuzzleL' if s<0 else 'MuzzleR',(x,-2.31,0),recoil)
        box('Ammo box',(s*.62,-.05,-.12),(.24,.4,.28),'Field olive',recoil,.035)
        rod('Belt chute',(s*.48,-.12,.08),(s*.3,-.18,.08),.035,'Rubber',recoil)
        box('Sight post',(x,-1.17,.2),(.04,.04,.16),'Gun steel',pivot,.01)
    box('Breech',(0,.28,-.02),(.62,.26,.22),'Recoil steel',recoil,.03)
    for s in [-1,1]:
        rod('Spade grip',(s*.34,.42,-.08),(s*.38,.62,-.16),.025,'Rubber',pivot)
        cyl('Grip cap',(s*.38,.64,-.16),.035,.06,'Rubber',pivot,'Z',10)
    hose(pivot,[(.5,.1,-.1),(.56,-.1,-.04),(.5,-.3,.02)],.02)
    finish(r,'mounted_twin_hmg')

def mounted_cannon():
    r=reset('MountedCannon')
    pivot=weapon_base(r)
    recoil=empty('RecoilAssembly',(0,0,0),pivot)
    cyl('Recoil sleeve',(0,-.45,0),.14,1.0,'Field olive',recoil,'Y',24)
    cyl('Barrel',(0,-1.55,0),.085,1.7,'Gun steel',recoil,'Y',24)
    for y in [-.9,-1.2]:cyl('Barrel collar',(0,y,0),.11,.08,'Armor edge',recoil,'Y',24)
    box('Muzzle brake',(0,-2.45,0),(.26,.3,.26),'Gun steel',recoil,.035)
    for s in [-1,1]:box('Brake port',(s*.135,-2.45,0),(.02,.18,.18),'Black bore',recoil,.005)
    empty('Muzzle',(0,-2.64,0),recoil)
    box('Breech',(0,.34,0),(.4,.42,.32),'Recoil steel',recoil,.045)
    rod('Operating lever',(.22,.42,.1),(.48,.58,.18),.03,'Gun steel',pivot)
    cyl('Elevation wheel',(-.48,.28,.05),.2,.05,'Gun steel',pivot,'X',20)
    box('Sight housing',(.3,-.2,.24),(.2,.26,.2),'Field olive',pivot,.03)
    cyl('Optic glass',(.3,-.34,.26),.06,.02,'Glass',pivot,'Y',16)
    finish(r,'mounted_cannon')

def mounted_rocket():
    r=reset('MountedRocket')
    pivot=weapon_base(r,False)
    recoil=empty('RecoilAssembly',(0,0,0),pivot)
    box('Pod frame',(0,-.35,0),(.66,1.1,.5),'Field olive',recoil,.06)
    for x in [-.18,.18]:
        for z in [-.12,.12]:
            cyl('Launch tube',(x,-.55,z),.115,1.3,'Gun steel',recoil,'Y',20)
            cyl('Tube cap',(x,-1.22,z),.09,.03,'Black bore',recoil,'Y',16)
            cyl('Rocket nose',(x,-1.05,z),.075,.18,'Armor edge',recoil,'Y',14)
    empty('Muzzle',(0,-1.28,0),recoil)
    box('Breech',(0,.28,0),(.5,.22,.4),'Gun steel',recoil,.04)
    box('Optics',(0,.05,.36),(.34,.3,.22),'Field olive',pivot,.035)
    box('Optic glass',(0,-.11,.38),(.24,.025,.14),'Glass',pivot,.01)
    for s in [-1,1]:rod('Handle',(s*.3,.3,-.12),(s*.34,.52,-.2),.025,'Rubber',pivot)
    finish(r,'mounted_rocket')

def mounted_autocannon():
    r=reset('MountedAutocannon')
    pivot=weapon_base(r)
    recoil=empty('RecoilAssembly',(0,0,0),pivot)
    box('Receiver',(0,-.2,0),(.36,.8,.3),'Gun steel',recoil,.05)
    cyl('Barrel',(0,-1.2,0),.055,1.6,'Gun steel',recoil,'Y',22)
    cyl('Flash hider',(0,-2.05,0),.08,.22,'Armor edge',recoil,'Y',18)
    empty('Muzzle',(0,-2.19,0),recoil)
    spin=empty('BarrelSpin',(0,-.6,0),recoil)
    cyl('Barrel shroud',(0,-.2,0),.085,.5,'Armor edge',spin,'Y',20)
    cyl('Ammo drum',(.3,.05,-.12),.22,.18,'Field olive',recoil,'X',22)
    box('Feed chute',(.18,-.12,-.04),(.2,.3,.12),'Gun steel',recoil,.025)
    box('Breech',(0,.3,0),(.3,.28,.24),'Recoil steel',recoil,.035)
    box('Sight',(0,-.35,.24),(.16,.2,.16),'Field olive',pivot,.025)
    cyl('Optic glass',(0,-.46,.26),.05,.02,'Glass',pivot,'Y',14)
    finish(r,'mounted_autocannon')

def soldier():
    r=reset('Soldier')
    material('Uniform',(.24,.28,.18),0.,.9)
    material('Webbing',(.13,.15,.1),0.,.95)
    material('Skin',(.45,.33,.25),0.,.7)
    hips=empty('Hips',(0,0,.95),r)
    box('Pelvis',(0,0,0),(.34,.22,.2),'Uniform',hips,.05)
    torso=empty('Torso',(0,0,.18),hips)
    box('Chest',(0,0,.26),(.42,.26,.5),'Uniform',torso,.08)
    box('Vest',(0,-.13,.28),(.36,.08,.36),'Webbing',torso,.04)
    for x in [-.12,.12]:box('Pouch',(x,-.18,.16),(.1,.06,.14),'Webbing',torso,.02)
    box('Pack',(0,.17,.28),(.32,.12,.34),'Canvas',torso,.05)
    neck=cyl('Neck',(0,0,.56),.06,.1,'Skin',torso,'Z',12)
    head=empty('Head',(0,0,.66),torso)
    sphere('Face',(0,0,0),(.11,.12,.13),'Skin',head,16,10)
    sphere('Helmet',(0,.01,.05),(.135,.14,.11),'Field olive',head,18,10)
    box('Visor',(0,-.11,.02),(.18,.03,.05),'Glass',head,.01)
    for s in [-1,1]:
        leg=empty('LegL' if s<0 else 'LegR',(s*.11,0,-.02),hips)
        box('Thigh',(0,0,-.22),(.15,.17,.44),'Uniform',leg,.045)
        box('Shin',(0,-.01,-.62),(.13,.15,.4),'Uniform',leg,.04)
        box('Boot',(0,-.05,-.86),(.15,.24,.12),'Rubber',leg,.035)
        arm=empty('ArmL' if s<0 else 'ArmR',(s*.27,0,.48),torso)
        box('Upper arm',(0,0,-.16),(.12,.14,.32),'Uniform',arm,.04)
        box('Forearm',(0,-.03,-.42),(.1,.12,.28),'Uniform',arm,.035)
        sphere('Hand',(0,-.04,-.58),(.055,.06,.07),'Skin',arm,12,8)
    rifle=empty('Rifle',(.16,-.18,.32),torso)
    box('Rifle body',(0,0,0),(.06,.42,.1),'Gun steel',rifle,.015)
    cyl('Rifle barrel',(0,-.3,.02),.02,.3,'Gun steel',rifle,'Y',10)
    box('Magazine',(0,.02,-.1),(.05,.1,.14),'Black bore',rifle,.01)
    finish(r,'soldier')

def landing_craft():
    r=reset('LandingCraft')
    box('Hull',(0,0,.8),(4.2,11.5,1.6),'Sand armor',r,.35)
    box('Deck',(0,.2,1.65),(3.8,10.5,.16),'Field olive',r,.06)
    for s in [-1,1]:box('Gunwale',(s*2.0,0,1.9),(.18,11.0,.5),'Sand armor',r,.08)
    ramp=empty('Ramp',(0,-5.7,1.2),r)
    box('Ramp plate',(0,-1.4,0),(3.6,2.8,.16),'Armor edge',r,.05)
    for s in [-1,1]:rod('Ramp cable',(s*1.7,-5.5,2.2),(s*1.7,-7.8,1.3),.03,'Gun steel',r)
    box('Superstructure',(0,3.8,2.6),(2.6,2.4,1.8),'Sand armor',r,.16)
    box('Bridge glass',(0,2.55,2.9),(2.2,.05,.6),'Glass',r,.02)
    cyl('Mast',(0,4.2,4.0),.06,1.8,'Gun steel',r,'Z',10)
    box('Radar',(0,4.2,4.9),(.7,.12,.16),'Gun steel',r,.02)
    for y in [-3,-1,1,3]:box('Cleat',(1.9,y,2.15),(.12,.3,.12),'Gun steel',r,.02)
    finish(r,'landing_craft')

def helicopter():
    r=reset('Helicopter')
    sphere('Fuselage',(0,0,1.1),(1.1,2.6,1.1),'Field olive',r,22,14)
    box('Cabin glass',(0,-1.9,1.3),(.9,.7,.6),'Glass',r,.12)
    box('Tail boom',(0,3.4,1.3),(.34,4.2,.34),'Field olive',r,.1)
    box('Tail fin',(0,5.3,1.9),(.12,.7,1.2),'Armor edge',r,.05)
    rotor=empty('Rotor',(0,0,2.25),r)
    cyl('Rotor hub',(0,0,0),.14,.18,'Gun steel',rotor,'Z',12)
    for i in range(4):
        a=i*math.tau/4
        blade=box('Blade',(math.cos(a)*2.4,math.sin(a)*2.4,.06),(4.8,.22,.04),'Black bore',rotor,.01)
        blade.rotation_euler[2]=a
    tail=empty('TailRotor',(0.22,5.3,1.9),r)
    box('Tail blade',(0,0,0),(.04,.9,.08),'Black bore',tail,.005)
    for s in [-1,1]:
        rod('Skid',(s*.8,-1.4,.15),(s*.8,1.6,.15),.05,'Gun steel',r)
        rod('Skid strut F',(s*.7,-.9,.2),(s*.8,-.9,.7),.04,'Gun steel',r)
        rod('Skid strut R',(s*.7,.9,.2),(s*.8,.9,.7),.04,'Gun steel',r)
    finish(r,'helicopter')

def patrol_boat():
    r=reset('PatrolBoat')
    box('Hull',(0,0,.5),(2.2,7.0,1.0),'Sand armor',r,.28)
    box('Deck',(0,0,1.05),(2.0,6.4,.12),'Field olive',r,.05)
    box('Cabin',(0,.8,1.7),(1.5,1.8,1.1),'Sand armor',r,.12)
    box('Cabin glass',(0,-.12,1.85),(1.2,.05,.45),'Glass',r,.02)
    cyl('Mast',(0,1.4,2.8),.04,1.2,'Gun steel',r,'Z',8)
    cyl('Bow gun',(0,-2.2,1.35),.08,.7,'Gun steel',r,'Y',12)
    box('Gun shield',(0,-1.9,1.45),(.5,.08,.4),'Armor edge',r,.03)
    finish(r,'patrol_boat')
def bazooka():
    r=reset('Bazooka')
    pivot=weapon_base(r,False)
    recoil=empty('RecoilAssembly',(0,0,0),pivot)
    cyl('Launch tube',(0,-.55,0),.095,1.7,'Field olive',recoil,'Y',24)
    cyl('Front collar',(0,-1.38,0),.11,.08,'Armor edge',recoil,'Y',24)
    cyl('Rear venturi',(0,.34,0),.13,.22,'Gun steel',recoil,'Y',24)
    cyl('Rocket nose',(0,-1.42,0),.07,.16,'Warning',recoil,'Y',16)
    empty('Muzzle',(0,-1.52,0),recoil)
    box('Shoulder rest',(0,.1,-.18),(.22,.5,.12),'Rubber',pivot,.04)
    box('Sight ladder',(0,-.4,.18),(.05,.3,.16),'Gun steel',pivot,.01)
    cyl('Sight ring',(0,-.52,.26),.055,.02,'Gun steel',pivot,'Y',14)
    box('Trigger grip',(0,.18,-.22),(.08,.16,.24),'Rubber',pivot,.03)
    rod('Trigger guard',(0,.1,-.18),(0,.26,-.3),.015,'Gun steel',pivot)
    box('Breech',(0,.42,0),(.24,.18,.24),'Recoil steel',recoil,.03)
    finish(r,'bazooka')

def fighter():
    r=reset('Fighter')
    sphere('Fuselage',(0,0,1.0),(.62,4.6,.72),'Sand armor',r,24,14)
    sphere('Canopy',(0,-1.7,1.55),(.42,1.1,.42),'Glass',r,20,12)
    mesh('Main wing',[(-.55,-.4,1.0),(-4.4,1.3,.82),(-3.7,2.2,.82),(-.5,1.2,1.0),(.55,-.4,1.0),(4.4,1.3,.82),(3.7,2.2,.82),(.5,1.2,1.0)],[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'Sand armor',r)
    mesh('Tail wing',[(-.4,3.4,1.1),(-1.9,4.3,1.0),(-1.5,4.8,1.0),(-.3,4.2,1.1),(.4,3.4,1.1),(1.9,4.3,1.0),(1.5,4.8,1.0),(.3,4.2,1.1)],[(0,1,2,3),(4,7,6,5)],'Sand armor',r)
    box('Vertical tail',(0,3.9,1.9),(.12,1.3,1.5),'Sand armor',r,.05)
    for s in [-1,1]:
        cyl('Engine nozzle',(s*.32,4.35,.95),.24,.3,'Gun steel',r,'Y',18)
        cyl('Intake',(s*.5,-.6,.7),.22,.5,'Black bore',r,'Y',16)
        box('Pylon',(s*2.2,.9,.65),(.12,.8,.3),'Gun steel',r,.02)
        cyl('Drop tank',(s*2.2,.9,.35),.16,1.0,'Field olive',r,'Y',14)
    finish(r,'fighter')

if __name__=='__main__':
    kestrel();warden();nomad();sentry();hangar()
    mounted_twin_hmg();mounted_cannon();mounted_rocket();mounted_autocannon()
    soldier();landing_craft();helicopter();patrol_boat();bazooka();fighter()
