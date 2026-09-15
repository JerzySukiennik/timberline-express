# Imports Poly Haven glTF models, decimates to game budgets, re-centers origins, exports one GLB per object.
import sys, os; sys.path.insert(0, os.path.dirname(__file__))
from common import *
import mathutils

# asset -> (target tris per object, out subdir, origin mode)
JOBS = {
  "rock_moss_set_01": (2500, "rocks", "bottom"),
  "rock_moss_set_02": (2500, "rocks", "bottom"),
  "boulder_01": (3500, "rocks", "bottom"),
  "fern_02": (2500, "plants", "bottom"),
  "shrub_02": (5000, "plants", "bottom"),
  "dry_branches_medium_01": (2500, "plants", "bottom"),
  "tree_stump_01": (3000, "plants", "bottom"),
  "picke_dirty_01": (4000, "tools", "keep"),
  "wooden_axe_03": (3000, "tools", "keep"),
  "wooden_crate_01": (4000, "props", "bottom"),
  "wooden_bucket_01": (3000, "props", "bottom"),
}
report = []
for asset,(budget, sub, origin) in JOBS.items():
    reset()
    bpy.ops.import_scene.gltf(filepath=PH + f"models/{asset}/{asset}.gltf")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    os.makedirs(MODELS + sub, exist_ok=True)
    for o in meshes:
        bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); bpy.context.view_layer.objects.active = o
        # bake parent transforms into mesh
        mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        tris = sum(len(p.vertices)-2 for p in o.data.polygons)
        if tris > budget:
            d = o.modifiers.new("dec", "DECIMATE"); d.ratio = budget/tris; d.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier="dec")
        bb = [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
        mn = mathutils.Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
        mx = mathutils.Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
        if origin == "bottom":
            piv = mathutils.Vector(((mn.x+mx.x)/2, (mn.y+mx.y)/2, mn.z))
        else:
            piv = mathutils.Vector(((mn.x+mx.x)/2, (mn.y+mx.y)/2, (mn.z+mx.z)/2))
        o.data.transform(mathutils.Matrix.Translation(-piv)); o.location = (0,0,0)
        name = o.name.replace(".", "_")
        if len(meshes) == 1: name = asset
        export_glb(MODELS + f"{sub}/{name}.glb", [o])
        t2 = sum(len(p.vertices)-2 for p in o.data.polygons)
        report.append(f"{sub}/{name}.glb tris {tris}->{t2} size {tuple(round(x,2) for x in (mx-mn))}")
print("\n".join(report))
