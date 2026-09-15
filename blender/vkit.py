# Hard-surface modelling kit for vehicles/props: textured materials, box/cylinder primitives with box-projected UVs.
import sys, os; sys.path.insert(0, os.path.dirname(__file__))
from common import *
import mathutils
V = mathutils.Vector
VT = ROOT + "/Niepotrzebne/vtex/"
_M = {}

def mat(name):
    if name in _M: return _M[name]
    spec = {
      "planks": dict(diff="planks_diffuse.jpg", nor="planks_nor_gl.jpg", arm="planks_arm.jpg"),
      "wood":   dict(diff="planks_diffuse.jpg", nor="planks_nor_gl.jpg", arm="planks_arm.jpg"),
      "iron":   dict(diff="iron_diffuse.jpg", nor="iron_nor_gl.jpg", arm="iron_arm.jpg"),
      "green":  dict(diff="green_diffuse.jpg", nor="green_nor_gl.jpg", arm="green_arm.jpg"),
      "yellow": dict(diff="yellow_diffuse.jpg", nor="green_nor_gl.jpg", arm="green_arm.jpg"),
      "black":  dict(diff="black_diffuse.jpg", nor="green_nor_gl.jpg", arm="green_arm.jpg"),
      "red":    dict(diff="red_diffuse.jpg", nor="green_nor_gl.jpg", arm="green_arm.jpg"),
      "cream":  dict(diff="cream_diffuse.jpg", nor="green_nor_gl.jpg", arm="green_arm.jpg"),
      "plate":  dict(diff="plate_diffuse.jpg", nor="plate_nor_gl.jpg", arm="plate_arm.jpg"),
    }.get(name)
    if spec:
        m = pbr(name, VT+spec["diff"], VT+spec["nor"], VT+spec["arm"])
    else:
        solid = {"brass": ((0.78,0.56,0.22,1),0.3,1.0), "steel": ((0.3,0.3,0.31,1),0.45,1.0),
                 "glass": ((0.05,0.07,0.08,1),0.05,0.0), "rubber": ((0.03,0.03,0.03,1),0.8,0.0),
                 "gauge_face": ((0.92,0.9,0.82,1),0.5,0.0), "needle": ((0.6,0.05,0.03,1),0.5,0.0),
                 "FireGlow": ((1.0,0.35,0.05,1),1.0,0.0), "Headlight": ((1.0,0.95,0.8,1),0.2,0.0),
                 "WaterLevel": ((0.25,0.45,0.55,1),0.1,0.0), "rope": ((0.55,0.45,0.3,1),0.9,0.0)}[name]
        m = pbr(name, color=solid[0], rough=solid[1], metal=solid[2])
    _M[name] = m; return m

def boxuv(me, scale=0.5):
    bm = bmesh.new(); bm.from_mesh(me); uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal; ax = max(range(3), key=lambda i: abs(n[i]))
        for lp in f.loops:
            c = lp.vert.co
            u, v = [(c.y, c.z), (c.x, c.z), (c.x, c.y)][ax]
            lp[uvl].uv = (u*scale, v*scale)
    bm.to_mesh(me); bm.free()

def _finish(ob, m, parent, bevel, smooth):
    if bevel:
        b = ob.modifiers.new("bev", "BEVEL"); b.width = bevel; b.segments = 2; b.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = ob; bpy.ops.object.modifier_apply(modifier="bev")
    mname = m if isinstance(m, str) else m.name
    boxuv(ob.data, {"planks": 0.28, "wood": 0.35}.get(mname, 0.6))
    ob.data.materials.append(mat(m) if isinstance(m, str) else m)
    for p in ob.data.polygons: p.use_smooth = smooth
    if smooth:
        ob.data.set_sharp_from_angle(angle=math.radians(40)) if hasattr(ob.data, "set_sharp_from_angle") else None
    if parent: ob.parent = parent; ob.matrix_parent_inverse = parent.matrix_world.inverted()
    return ob

def box(name, size, loc, m="iron", parent=None, rot=(0,0,0), bevel=0.012, pivot=None):
    """size (x,y,z); loc = center in world; pivot = world point to become the object origin."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0); bmesh.ops.scale(bm, vec=V(size), verts=bm.verts)
    bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new(name, me))
    R = mathutils.Euler(rot).to_matrix().to_4x4()
    piv = V(pivot) if pivot is not None else V(loc)
    me.transform(mathutils.Matrix.Translation(V(loc)-piv) @ R) if pivot is not None else me.transform(R)
    ob.location = piv
    bpy.context.view_layer.update()
    return _finish(ob, m, parent, bevel, False)

def cyl(name, r, depth, loc, axis="Z", m="iron", parent=None, verts=20, r2=None, pivot=None, bevel=0.0, smooth=True, cap=True):
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=verts, radius1=r, radius2=(r if r2 is None else r2), depth=depth)
    rot = {"Z": mathutils.Matrix(), "X": mathutils.Matrix.Rotation(math.pi/2, 4, "Y"), "Y": mathutils.Matrix.Rotation(-math.pi/2, 4, "X")}[axis]
    bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new(name, me))
    piv = V(pivot) if pivot is not None else V(loc)
    me.transform(mathutils.Matrix.Translation(V(loc)-piv)); ob.location = piv
    bpy.context.view_layer.update()
    return _finish(ob, m, parent, bevel, smooth)

def empty(name, loc, parent=None):
    ob = link(bpy.data.objects.new(name, None)); ob.location = V(loc)
    if parent: ob.parent = parent; ob.matrix_parent_inverse = parent.matrix_world.inverted()
    return ob

def spoked_wheel(name, loc, r, width=0.12, spokes=10, parent=None, m="black", tread="steel", counterweight=False):
    """Railway wheel on axis X, origin at axle center. Flange on the inner side (toward x=0)."""
    root = cyl(name, r*0.93, width*0.35, loc, "X", m, parent, verts=28)   # web ring / rim inner
    ob = cyl(name+"_tread", r, width, loc, "X", tread, root, verts=36, cap=False)
    inner = -1 if loc[0] > 0 else 1
    cyl(name+"_flange", r*1.08, 0.025, (loc[0]+inner*width*0.45, loc[1], loc[2]), "X", tread, root, verts=36)
    cyl(name+"_hub", r*0.22, width*1.3, loc, "X", m, root, verts=16)
    for s in range(spokes):
        a = s/spokes*2*math.pi
        mid = V((loc[0], loc[1]+math.cos(a)*r*0.55, loc[2]+math.sin(a)*r*0.55))
        box(f"{name}_spoke{s}", (0.03, r*0.75, 0.05), mid, m, root, rot=(a,0,0), bevel=0.006)
    if counterweight:
        box(name+"_cw", (0.05, r*0.7, r*0.35), (loc[0], loc[1], loc[2]-r*0.55), m, root, bevel=0.02)
    return root

def join_children(root):
    """Merge static mesh children (no animation) into root to cut draw calls. Keeps named animated parts."""
    kids = [c for c in root.children if c.type == "MESH" and not c.get("anim")]
    if not kids: return root
    bpy.ops.object.select_all(action="DESELECT")
    for k in kids: k.select_set(True)
    root.select_set(True); bpy.context.view_layer.objects.active = root
    bpy.ops.object.join()
    return root

def anim(ob):
    ob["anim"] = 1; return ob

def clear_mats():
    _M.clear()
