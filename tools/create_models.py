import bpy, math
from pathlib import Path
from mathutils import Vector

DEST = Path(__file__).resolve().parents[1] / 'assets/models/objects'
DEST.mkdir(parents=True, exist_ok=True)

def mat(name, color, metal=0.0, rough=.3, emission=0):
    m = bpy.data.materials.new(name); m.diffuse_color = (*color, 1); m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal; p.inputs['Roughness'].default_value = rough
    if emission:
        p.inputs['Emission Color'].default_value = (*color, 1); p.inputs['Emission Strength'].default_value = emission
    return m

def finish(o, name, material, bevel=0, smooth=True):
    o.name = name; o.data.materials.append(material)
    if bevel:
        mod = o.modifiers.new('Rounded edges', 'BEVEL'); mod.width = bevel; mod.segments = 4
        bpy.context.view_layer.objects.active = o; bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        for p in o.data.polygons: p.use_smooth = True
        mod = o.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
        bpy.context.view_layer.objects.active = o; bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def box(name, loc, size, material, bevel=.005):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=bpy.context.object; o.dimensions=size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o,name,material,bevel)

def mesh(name, verts, faces, material, bevel=0):
    m=bpy.data.meshes.new(name); m.from_pydata(verts,[],faces); m.update()
    o=bpy.data.objects.new(name,m); bpy.context.collection.objects.link(o)
    return finish(o,name,material,bevel)

def lathe(name, profile, material):
    n=64; v=[(r*math.cos(i*2*math.pi/n),r*math.sin(i*2*math.pi/n),z) for r,z in profile for i in range(n)]
    f=[]
    for j in range(len(profile)-1):
        for i in range(n):
            k=j*n+i; q=j*n+(i+1)%n; f.append((k,q,q+n,k+n))
    return mesh(name,v,f,material)

def export(name):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(DEST/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_cameras=False,export_lights=False)
    tris=sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
    print(f'MODEL {name}: {tris} polygons')
    bpy.ops.object.delete(use_global=False)

bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
blue=mat('Glazed blue ceramic',(.025,.32,.68),rough=.22)
inside=mat('Ivory ceramic interior',(.86,.9,.91),rough=.28)
silver=mat('Brushed stainless steel',(.62,.68,.76),metal=.7,rough=.28)
dark=mat('Graphite frame',(.045,.055,.07),metal=.65,rough=.24)
glass=mat('Blue display glass',(.018,.10,.22),rough=.16,emission=.25)
white=mat('Screen white',(.78,.89,1),rough=.45,emission=.45)
cyan=mat('Screen teal',(.02,.62,.7),rough=.45,emission=.2)
orange=mat('Screen amber',(.95,.38,.08),rough=.5,emission=.2)

# A genuinely hollow mug with a rounded rim and a full ceramic handle.
lathe('CupBody',[(0,-.165),(.12,-.165),(.131,-.158),(.137,-.14),(.16,.14),(.16,.158),(.156,.166),(.148,.169),(.140,.163),(.139,.15)],blue)
lathe('CupInterior',[(.139,.15),(.119,-.125),(.111,-.137),(0,-.137)],inside)
v=[]; f=[]; n=64; k=12
for i in range(n):
    t=i*2*math.pi/n
    for j in range(k):
        a=j*2*math.pi/k; thick=.022
        v.append((.182+(.089+thick*math.cos(a))*math.cos(t),thick*math.sin(a),.006+(.112+thick*math.cos(a))*math.sin(t)))
for i in range(n):
    for j in range(k): f.append((i*k+j,((i+1)%n)*k+j,((i+1)%n)*k+(j+1)%k,i*k+(j+1)%k))
mesh('CupHandle',v,f,blue)
export('cup')

# Portrait phone, front towards Blender -Y / Godot +Z.
box('PhoneFrame',(0,0,0),(.22,.026,.38),silver,.016)
box('PhoneBezel',(0,-.012,0),(.208,.008,.368),dark,.015)
box('PhoneDisplay',(0,-.017,0),(.19,.004,.333),glass,.011)
box('DetailSpeaker',(0,-.020,.143),(.045,.003,.007),dark,.003)
box('DetailHomeBar',(0,-.020,-.147),(.065,.003,.004),white,.0018)
box('DetailTimeBar',(-.028,-.020,.097),(.092,.002,.012),white,.002)
box('DetailTimeBarSmall',(-.047,-.020,.076),(.054,.002,.005),white,.002)
for i in range(3):
    for j in range(2): box(f'DetailApp_{i}_{j}',(-.058+i*.058,-.020,.014-j*.060),(.037,.003,.037),[cyan,white,orange][(i+j)%3],.008)
box('DetailPowerKey',(.112,0,.06),(.005,.012,.043),dark,.002)
box('DetailVolumeKey',(-.112,0,.072),(.005,.012,.064),dark,.002)
box('DetailCameraBack',(-.067,.016,.123),(.058,.009,.071),dark,.012)
for z in [.108,.14]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=(-.067,.023,z),scale=(.014,.005,.014))
    finish(bpy.context.object,'DetailCameraLens',glass)
export('phone')

# A narrow contoured fork handle, widened shoulder, and four separated tapered tines.
outline=[(-.020,-.23),(-.027,-.215),(-.023,-.18),(-.014,-.04),(-.019,.024),(-.055,.072),(-.056,.102),(.056,.102),(.055,.072),(.019,.024),(.014,-.04),(.023,-.18),(.027,-.215),(.020,-.23)]
v=[(x,y,z) for y in [-.007,.007] for x,z in outline]; n=len(outline)
f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
mesh('ForkHandleAndShoulder',v,f,silver,.004)
for i in range(4):
    x=-.045+i*.03; ztop=.218 if i in [1,2] else .211
    o=[(x-.010,.086),(x-.008,ztop-.018),(x-.004,ztop),(x+.004,ztop),(x+.008,ztop-.018),(x+.010,.086)]
    v=[(xx,y,zz) for y in [-.006,.006] for xx,zz in o]; n=len(o)
    f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
    mesh(f'ForkTine{i}',v,f,silver,.0025)
export('fork')
