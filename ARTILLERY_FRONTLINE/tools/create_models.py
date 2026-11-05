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
        b=o.modifiers.new('Machined edges','BEVEL'); b.width=bevel; b.segments=2
        bpy.ops.object.modifier_apply(modifier=b.name)
        b=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=b.name)
    if rot:o.rotation_euler=rot
    return o
def cyl(name,loc,radius,depth,mat='Gun steel',parent=None,axis='Z',vertices=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    o=adopt(bpy.context.object,name,mat,parent)
    if axis=='X':o.rotation_euler[1]=math.pi/2
    if axis=='Y':o.rotation_euler[0]=math.pi/2
    b=o.modifiers.new('Rim bevel','BEVEL');b.width=min(.035,radius*.12);b.segments=2
    bpy.ops.object.modifier_apply(modifier=b.name)
    for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
    return o
def rod(name,a,b,r,mat='Gun steel',parent=None):
    a,b=Vector(a),Vector(b); d=b-a
    o=cyl(name,(a+b)/2,r,d.length,mat,parent,vertices=12)
    o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC,name+'.blend'))
    export_glb(root,os.path.join(OUT,name+'.glb'))
    print('CREATED',name, len(bpy.data.objects),'objects')

def wheel(parent,x,y,z,r=.91,width=.48):
    cyl('Tire',(x,y,z),r,width,'Rubber',parent,'X',24)
    cyl('Rim',(x+math.copysign(width*.52,x),y,z),r*.57,.06,'Armor edge',parent,'X',20)
    cyl('Hub',(x+math.copysign(width*.64,x),y,z),r*.22,.14,'Gun steel',parent,'X',16)
    for i in range(8):
        a=i*math.tau/8
        cyl('Hub bolt',(x+math.copysign(width*.68,x),y+math.sin(a)*r*.38,z+math.cos(a)*r*.38),.045,.06,'Recoil steel',parent,'X',6)
    for i in range(18):
        a=i*math.tau/18
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
    for s in [-1,1]:
        trail=box('Split trail',(s*1.25,2.65,.68),(.4,4.4,.42),'Field olive',r,.07)
        trail.rotation_euler[2]=s*-.24
        sp=box('Ground spade',(s*1.83,4.62,.3),(.95,.3,.65),'Gun steel',r,.05)
        rod('Trail brace',(s*.7,1,.9),(s*1.55,3.6,.65),.075,'Recoil steel',r)
        box('Shield',(s*1.04,-.55,2.38),(1.18,.18,1.55),'Armor edge',r,.07,(math.radians(-9),0,s*.08))
        box('Shield lower',(s*1.2,.0,1.7),(1.05,.2,.5),'Field olive',r,.04)
        box('Tool locker',(s*1.4,1.3,1.5),(.55,1.0,.45),'Field olive',r,.06)
        for j in range(4):
            cyl('Shield fastener',(s*(.62+j*.25),-.68,2.94),.035,.045,'Recoil steel',r,'Y',6)
    turret=empty('Turret',(0,.1,1.75),r)
    box('Cradle',(0,-.1,.36),(1.25,1.75,.52),'Field olive',turret,.1)
    for s in [-1,1]:
        cyl('Trunnion',(s*.76,0,.65),.31,.22,'Gun steel',turret,'X')
        rod('Hydraulic sleeve',(s*.56,.55,.1),(s*.56,-.9,.65),.13,'Field olive',turret)
        rod('Hydraulic piston',(s*.56,-.7,.53),(s*.56,-1.5,.78),.068,'Recoil steel',turret)
    pivot=empty('BarrelPivot',(0,0,.68),turret)
    recoil=empty('RecoilAssembly',(0,0,0),pivot)
    cyl('Barrel sleeve',(0,-.8,0),.29,2.0,'Field olive',recoil,'Y',24)
    cyl('Forged tube',(0,-3.4,0),.18,4.2,'Gun steel',recoil,'Y',24)
    for y in [-1.7,-2.0,-4.6]:cyl('Barrel collar',(0,y,0),.225,.13,'Armor edge',recoil,'Y',24)
    box('Muzzle brake',(0,-5.72,0),(.56,.7,.46),'Gun steel',recoil,.08)
    for s in [-1,1]:
        box('Gas port',(s*.284,-5.7,0),(.015,.32,.25),'Black bore',recoil,.01)
    cyl('Muzzle rim',(0,-6.09,0),.215,.07,'Recoil steel',recoil,'Y',24)
    cyl('Bore darkness',(0,-6.132,0),.147,.012,'Black bore',recoil,'Y',24)
    empty('Muzzle',(0,-6.17,0),recoil)
    box('Breech',(0,.55,0),(.7,.9,.58),'Gun steel',pivot,.07)
    block=box('BreechBlock',(.44,.7,0),(.14,.6,.48),'Recoil steel',pivot,.035)
    rod('Operating lever',(.5,.8,.2),(.85,1.0,.35),.045,'Gun steel',pivot)
    cyl('Elevation wheel',(-1.0,.55,.3),.32,.07,'Gun steel',turret,'X',16)
    for i in range(6):
        a=i*math.tau/6
        rod('Wheel spoke',(-1.05,.55,.3),(-1.05,.55+math.sin(a)*.3,.3+math.cos(a)*.3),.025,'Armor edge',turret)
    box('Gunner seat',(-1.25,1.05,.65),(.62,.55,.13),'Canvas',turret,.05)
    box(' Sight housing',(.72,-.2,1.0),(.3,.4,.4),'Field olive',turret,.04)
    cyl('Optic glass',(.72,-.415,1.04),.095,.025,'Glass',turret,'Y',16)
    finish(r,'kestrel')

def warden():
    r=reset('Warden')
    for s in [-1,1]:
        box('Track belt',(s*2.0,0,.78),(.8,6.9,1.35),'Rubber',r,.3)
        for y in [-2.5,-1.25,0,1.25,2.5]:wheel(r,s*2.16,y,.75,.58,.45)
        for i in range(22):
            box('Track shoe',(s*2.0,-3.25+i*.31,1.47),(.87,.2,.1),'Gun steel',r,.015)
        box('Side skirt',(s*2.3,0,1.65),(.22,6.6,.65),'Field olive',r,.05)
        for i in range(6):box('ERA skirt',(s*2.44,-2.55+i*1.02,1.72),(.18,.88,.5),'Armor edge',r,.04)
    box('Lower hull',(0,0,1.25),(3.7,6.4,1.0),'Field olive',r,.2)
    mesh('Sloped glacis',[(-1.95,-3.3,1.5),(1.95,-3.3,1.5),(1.75,-2.25,2.35),(-1.75,-2.25,2.35),(-1.8,3.0,1.5),(1.8,3.0,1.5),(1.7,2.6,2.25),(-1.7,2.6,2.25)],[(0,1,2,3),(4,7,6,5),(3,2,6,7),(0,4,5,1),(0,3,7,4),(1,5,6,2)],'Armor edge',r)
    turret=empty('Turret',(0,-.25,2.35),r)
    cyl('Turret race',(0,0,0),1.3,.25,'Gun steel',turret)
    box('Cast turret',(0,-.1,.48),(2.75,2.8,.92),'Field olive',turret,.35)
    for s in [-1,1]:
        for i in range(3):box('Cheek armor',(s*1.13,-.9+i*.58,.62),(.48,.5,.65),'Armor edge',turret,.08,(0,s*.18,0))
    cyl('Tank gun',(0,-3.2,.55),.12,4.2,'Gun steel',turret,'Y')
    cyl('Fume extractor',(0,-2.6,.55),.2,.75,'Field olive',turret,'Y')
    cyl('Muzzle',(0,-5.32,.55),.15,.18,'Gun steel',turret,'Y')
    cyl('Bore',(0,-5.42,.55),.09,.02,'Black bore',turret,'Y')
    for x in [-.65,.65]:
        cyl('Hatch',(x,.5,1.02),.4,.12,'Armor edge',turret)
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
    box('Armored cab',(0,-2.45,2.0),(2.65,2.3,1.9),'Sand armor',r,.18)
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
        box('Cargo strap',(0,y,2.55),(2.67,.07,1.55),'Field olive',r,.04)
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
    segments=20
    for y in [-15,15]:
        for i in range(segments+1):
            a=i*math.pi/segments
            verts.append((10.7*math.cos(a),y,5.3+5.2*math.sin(a)))
    for i in range(segments):faces.append((i,i+1,i+segments+2,i+segments+1))
    roof=mesh('Curved roof',verts,faces,'Field olive',r)
    solid=roof.modifiers.new('Roof thickness','SOLIDIFY');solid.thickness=.15
    bpy.context.view_layer.objects.active=roof;bpy.ops.object.modifier_apply(modifier=solid.name)
    for y in [-14.7,-10,-5,0,5,10,14.7]:
        for i in range(segments):
            a=i*math.pi/segments;b=(i+1)*math.pi/segments
            rod('Roof rib',(10.55*math.cos(a),y,5.25+5.05*math.sin(a)),(10.55*math.cos(b),y,5.25+5.05*math.sin(b)),.075,'Gun steel',r)
    for s in [-1,1]:
        box('Door pillar',(s*9.7,-14.8,3),(.7,.7,6),'Gun steel',r,.04)
        box('Part-open door',(s*8.1,-14.6,2.7),(3.0,.15,5.2),'Field olive',r,.025)
    for y in [-8,0,8]:box('Roof ventilator',(0,y,10.55),(1.6,2.0,.6),'Gun steel',r,.08)
    finish(r,'hangar')

if __name__=='__main__':
    kestrel();warden();nomad();sentry();hangar()
