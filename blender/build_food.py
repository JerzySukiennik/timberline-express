# Food item models: berry cluster, mushroom, raw and cooked meat.
import sys, os, random; sys.path.insert(0, os.path.dirname(__file__))
from vkit import *

def out(path):
    export_glb(MODELS + path, list(bpy.context.scene.objects))

def sphere(name, r, loc, m, parent=None, seg=12):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg//2+2, radius=r)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new(name, me)); ob.location = loc
    me.materials.append(m if not isinstance(m, str) else mat(m))
    for p in me.polygons: p.use_smooth = True
    if parent: ob.parent = parent
    return ob

reset(); clear_mats(); random.seed(4)
berry = pbr("berry", color=(0.35, 0.03, 0.08, 1), rough=0.25)
leaf = pbr("leaf", color=(0.18, 0.32, 0.1, 1), rough=0.7)
root = empty("Berries", (0,0,0))
for i in range(14):
    a = random.random()*6.28; rr = random.random()*0.035
    sphere(f"b{i}", random.uniform(0.009, 0.013), (math.cos(a)*rr, math.sin(a)*rr, random.uniform(0,0.03)), berry, root, 10)
box("leaf1", (0.05, 0.03, 0.002), (0.02, 0.01, 0.035), leaf, root, rot=(0.3, 0, 0.5), bevel=0)
box("leaf2", (0.045, 0.028, 0.002), (-0.02, -0.01, 0.036), leaf, root, rot=(-0.3, 0, -0.6), bevel=0)
out("items/berries.glb")

reset(); clear_mats()
cap = pbr("cap", color=(0.42, 0.24, 0.12, 1), rough=0.6)
stem = pbr("stem", color=(0.85, 0.8, 0.7, 1), rough=0.8)
root = empty("Mushroom", (0,0,0))
cyl("stem", 0.012, 0.07, (0,0,0.035), "Z", stem, root, verts=12, r2=0.009)
c = cyl("cap", 0.045, 0.03, (0,0,0.075), "Z", cap, root, verts=20, r2=0.012)
out("items/mushroom.glb")

for name, col, rough in (("raw_meat", (0.55, 0.08, 0.08, 1), 0.35), ("cooked_meat", (0.32, 0.16, 0.07, 1), 0.6)):
    reset(); clear_mats(); random.seed(8)
    m = pbr(name, color=col, rough=rough)
    fat = pbr("fat", color=(0.85, 0.78, 0.68, 1) if name == "raw_meat" else (0.55, 0.38, 0.2, 1), rough=0.5)
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=3, radius=0.07)
    for v in bm.verts:
        v.co.x *= 1.4; v.co.z *= 0.45; v.co *= random.uniform(0.92, 1.06)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new(name, me)); me.materials.append(m)
    for p in me.polygons: p.use_smooth = True
    bone = cyl("bone", 0.012, 0.06, (0.11, 0, 0.0), "X", fat, ob, verts=10)
    out(f"items/{name}.glb")
print("food ok")

reset(); clear_mats(); random.seed(12)
leather = pbr("sack", color=(0.33, 0.22, 0.13, 1), rough=0.8)
bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=3, radius=0.25)
for v in bm.verts:
    v.co.z *= 0.75 if v.co.z > 0 else 0.45
    v.co *= random.uniform(0.95, 1.05)
me = bpy.data.meshes.new("Sack"); bm.to_mesh(me); bm.free()
ob = link(bpy.data.objects.new("Sack", me)); me.materials.append(leather)
for p in me.polygons: p.use_smooth = True
ob.location.z = 0.12
cyl("neck", 0.07, 0.12, (0, 0, 0.32), "Z", leather, ob, verts=14, r2=0.05)
cyl("tie", 0.075, 0.02, (0, 0, 0.3), "Z", "rope", ob, verts=14)
export_glb(MODELS + "props/sack.glb", list(bpy.context.scene.objects))
print("sack ok")
