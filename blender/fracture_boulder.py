# Pre-fractures boulder_01 into a 2-level hierarchy (1 -> 3 -> 9 pieces). Cut faces get material "RockInner".
import sys, os, json, random; sys.path.insert(0, os.path.dirname(__file__))
from common import *
import mathutils
V = mathutils.Vector
random.seed(7)
reset()
bpy.ops.import_scene.gltf(filepath=PH + "models/boulder_01/boulder_01.gltf")
src = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
mw = src.matrix_world.copy(); src.parent = None; src.matrix_world = mw
bpy.context.view_layer.objects.active = src; src.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
d = src.modifiers.new("dec","DECIMATE"); d.ratio = 0.07; bpy.ops.object.modifier_apply(modifier="dec")
bpy.ops.object.shade_smooth()
inner = bpy.data.materials.new("RockInner"); src.data.materials.append(inner)
INNER = len(src.data.materials)-1
bb = [V(c) for c in src.bound_box]; mn = V((min(v.x for v in bb),min(v.y for v in bb),min(v.z for v in bb))); mx = V((max(v.x for v in bb),max(v.y for v in bb),max(v.z for v in bb)))
piv = V(((mn.x+mx.x)/2,(mn.y+mx.y)/2,mn.z)); src.data.transform(mathutils.Matrix.Translation(-piv))
os.makedirs(MODELS + "rocks/boulder", exist_ok=True)

def cut(me, co, no, keep_positive):
    bm = bmesh.new(); bm.from_mesh(me)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, clear_inner=keep_positive, clear_outer=not keep_positive)
    cut_edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    if cut_edges:
        f = bmesh.ops.holes_fill(bm, edges=cut_edges, sides=0)
        for face in f["faces"]:
            face.material_index = INNER; face.smooth = False
        bmesh.ops.triangulate(bm, faces=f["faces"])
    out = bpy.data.meshes.new("piece"); bm.to_mesh(out); bm.free()
    for m in me.materials: out.materials.append(m)
    return out

def center(me):
    vs = [v.co for v in me.vertices]
    return sum(vs, V()) / max(1, len(vs))

def split3(me):
    c = center(me)
    n1 = V((random.uniform(-1,1), random.uniform(-0.4,0.4), random.uniform(-1,1))).normalized()
    a = cut(me, c + n1*0.05, n1, True); b = cut(me, c + n1*0.05, n1, False)
    cb = center(b)
    n2 = n1.cross(V((0,0,1))).normalized() if abs(n1.z) < 0.9 else V((1,0,0))
    n2 = (n2 + V((random.uniform(-.3,.3),random.uniform(-.3,.3),random.uniform(-.3,.3)))).normalized()
    return [a, cut(b, cb, n2, True), cut(b, cb, n2, False)]

meta = {"pieces": {}}
def export_piece(me, name, parent_origin):
    c = center(me)
    me.transform(mathutils.Matrix.Translation(-c))
    ob = link(bpy.data.objects.new(name, me))
    export_glb(MODELS + f"rocks/boulder/{name}.glb", [ob], export_materials="PLACEHOLDER")
    bpy.data.objects.remove(ob)
    vol = sum(len(p.vertices) for p in me.polygons)
    meta["pieces"][name] = {"offset": [round(c.x - parent_origin.x,4), round(c.z - parent_origin.z,4), round(-(c.y - parent_origin.y),4)]}  # to Godot Y-up
    return c

whole = src.data.copy()
export_glb(MODELS + "rocks/boulder/boulder_l0.glb", [src], export_materials="PLACEHOLDER")
root = V((0,0,0))
for i, p in enumerate(split3(whole)):
    kids = split3(p)
    c1 = export_piece(p, f"boulder_l1_{i}", root)
    for j, k in enumerate(kids):
        export_piece(k, f"boulder_l2_{i}_{j}", c1 + V())  # offsets relative to l1 center (before recentre)
json.dump(meta, open(MODELS + "rocks/boulder/fracture.json","w"), indent=1)
print("fracture ok", len(meta["pieces"]))
