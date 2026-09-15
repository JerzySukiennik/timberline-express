# First-person arms: skin-modifier mesh + armature (upper/fore/hand + 3-bone fingers). Right arm built, left mirrored.
import sys, os; sys.path.insert(0, os.path.dirname(__file__))
from common import *
import mathutils
V = mathutils.Vector

# joint positions (Blender, Z up). Arm points +Y, right arm, palm down (-Z), thumb to -X.
J = {
 "shoulder": V((0,0,0)), "elbow": V((0,0.30,0)), "wrist": V((0,0.555,0)), "palm": V((0,0.61,-0.002)),
}
FING = {  # knuckle, segment lengths
 "index":  (V((-0.034,0.655,0.004)), (0.045,0.027,0.022), 0.0100),
 "middle": (V((-0.011,0.661,0.006)), (0.049,0.030,0.024), 0.0104),
 "ring":   (V(( 0.012,0.656,0.004)), (0.046,0.028,0.023), 0.0097),
 "pinky":  (V(( 0.032,0.643,0.000)), (0.036,0.022,0.019), 0.0088),
}
THUMB = [V((-0.018,0.575,-0.010)), V((-0.043,0.603,-0.022)), V((-0.058,0.636,-0.027)), V((-0.066,0.660,-0.029))]

def build_side(side):
    sx = 1 if side == "R" else -1
    M = lambda v: V((v.x*sx, v.y, v.z))
    # --- skin-modifier skeleton mesh ---
    bm = bmesh.new(); rad = []
    def vert(p, r):
        v = bm.verts.new(M(p)); rad.append(r); return v
    sh = vert(J["shoulder"], 0.052)
    up1 = vert(V((0,0.15,0)), 0.050)
    el = vert(J["elbow"], 0.041)
    f1 = vert(V((0,0.36,0.002)), 0.040)
    f2 = vert(V((0,0.46,0.001)), 0.033)
    wr = vert(J["wrist"], 0.025)
    pm = vert(J["palm"], 0.036)
    for a,b in ((sh,up1),(up1,el),(el,f1),(f1,f2),(f2,wr),(wr,pm)): bm.edges.new((a,b))
    tips = {}
    for name,(k,segs,r) in FING.items():
        kn = vert(k, r*1.05); bm.edges.new((pm, kn)); p = k.copy(); prev = kn
        for i,s in enumerate(segs):
            p = p + V((0,s,0)); nv = vert(p, r*(0.95-0.12*i)); bm.edges.new((prev, nv)); prev = nv
    prev = None
    for i,p in enumerate(THUMB):
        nv = vert(p, [0.013,0.012,0.0105,0.0095][i])
        bm.edges.new((wr if i == 0 else prev, nv)) if i else bm.edges.new((pm, nv))
        prev = nv
    me = bpy.data.meshes.new("Arm"+side); bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new("Arm"+side, me))
    sk = ob.modifiers.new("skin", "SKIN")
    for i, sv in enumerate(me.skin_vertices[0].data): sv.radius = (rad[i], rad[i]*(0.62 if i >= 6 else 1.0))
    me.skin_vertices[0].data[0].use_root = True
    ob.modifiers.new("sub", "SUBSURF").levels = 2
    bpy.context.view_layer.objects.active = ob; ob.select_set(True)
    for m in list(ob.modifiers): bpy.ops.object.modifier_apply(modifier=m.name)
    # flatten palm a bit in Z around the hand
    for v in ob.data.vertices:
        if v.co.y > 0.57 and v.co.y < 0.66 and abs(v.co.x) < 0.045:
            v.co.z = v.co.z*0.72
    # --- region mask in vertex colors: R=glove, G=sleeve (rest = skin) ---
    mat = bpy.data.materials.new("Arm"); ob.data.materials.append(mat)
    ca = ob.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    def sstep(e0, e1, x):
        t = max(0.0, min(1.0, (x-e0)/(e1-e0))); return t*t*(3-2*t)
    for v in ob.data.vertices:
        c = v.co; y = c.y; lx = c.x*sx
        sleeve = 1.0 - sstep(0.275, 0.29, y)
        glove = sstep(0.525, 0.54, y)
        if y > 0.62:
            if lx < -0.04 and y < 0.70 and c.z < -0.004:   # thumb
                glove *= 1.0 - sstep(0.615, 0.63, y)
            else:
                nearest = min(FING.values(), key=lambda f: abs(f[0].x - lx))
                cut = nearest[0].y + nearest[1][0]*0.55
                glove *= 1.0 - sstep(cut-0.004, cut+0.004, y)
        ca.data[v.index].color = (glove, sleeve, 0.0, 1.0)
    for poly in ob.data.polygons: poly.use_smooth = True
    # cylindrical UVs around the arm axis (+Y): u = angle, v = length -> continuous plaid/leather
    uvl = ob.data.uv_layers.new(name="UVMap")
    for poly in ob.data.polygons:
        us = []
        for li in poly.loop_indices:
            co = ob.data.vertices[ob.data.loops[li].vertex_index].co
            us.append((math.atan2(co.z, co.x*sx)/(2*math.pi) + 0.5, co.y*3.0))
        if max(u for u,_ in us) - min(u for u,_ in us) > 0.5:
            us = [(u+1.0 if u < 0.5 else u, v) for u,v in us]
        for li,(u,v) in zip(poly.loop_indices, us): ob.data.uv_layers["UVMap"].data[li].uv = (u, v)
    # rolled sleeve cuff
    bpy.ops.mesh.primitive_torus_add(major_radius=0.047, minor_radius=0.013, major_segments=28, minor_segments=10, location=M(V((0,0.285,0))), rotation=(math.pi/2,0,0))
    cuff = bpy.context.active_object; cuff.name = "Cuff"+side; cuff.scale = (1,1,1.25)
    for v in cuff.data.vertices: v.co.x += 0.004*math.sin(v.co.y*40)  # fold wobble
    bpy.ops.object.shade_smooth(); cuff.data.materials.append(mat)
    cc = cuff.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for d in cc.data: d.color = (0.0, 1.0, 0.0, 1.0)
    cu = cuff.data.uv_layers.new(name="UVMap")
    for poly in cuff.data.polygons:
        for li in poly.loop_indices:
            co = cuff.data.vertices[cuff.data.loops[li].vertex_index].co
            cu.data[li].uv = (math.atan2(co.z, co.x)/(2*math.pi)+0.5, co.y*3.0)
    bpy.ops.object.select_all(action="DESELECT"); cuff.select_set(True); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.join()
    # --- armature ---
    ad = bpy.data.armatures.new("Rig"+side); rig = link(bpy.data.objects.new("Rig"+side, ad))
    bpy.ops.object.select_all(action="DESELECT"); rig.select_set(True); bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    def bone(name, head, tail, parent=None, roll=0.0):
        b = ad.edit_bones.new(name); b.head = M(head); b.tail = M(tail); b.roll = roll
        if parent: b.parent = ad.edit_bones[parent]; b.use_connect = (b.parent.tail - b.head).length < 1e-4
        return b
    bone("upper", J["shoulder"], J["elbow"])
    bone("fore", J["elbow"], J["wrist"], "upper")
    bone("hand", J["wrist"], V((0,0.645,0)), "fore")
    for name,(k,segs,r) in FING.items():
        p = k.copy(); par = "hand"
        for i,s in enumerate(segs):
            q = p + V((0,s,0)); bone(f"{name}{i+1}", p, q, par); par = f"{name}{i+1}"; p = q
    par = "hand"
    for i in range(3):
        bone(f"thumb{i+1}", THUMB[i], THUMB[i+1], par); par = f"thumb{i+1}"
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    return rig, ob

reset()
rR, oR = build_side("R")
rL, oL = build_side("L")
rL.location.x = -0.45; oL  # preview offset only
export_glb(MODELS + "arms_rig_preview_tmp.glb", [rR, oR])  # sanity
rL.location.x = 0.0
os.remove(MODELS + "arms_rig_preview_tmp.glb")
export_glb(MODELS + "arms.glb", [rR, oR, rL, oL], export_vertex_color="ACTIVE")
# preview: grip pose on right hand
rL.location.x = -0.35
bpy.context.view_layer.objects.active = rR; bpy.ops.object.mode_set(mode="POSE")
for n in ("index","middle","ring","pinky"):
    for i in (1,2,3):
        rR.pose.bones[f"{n}{i}"].rotation_mode = "XYZ"; rR.pose.bones[f"{n}{i}"].rotation_euler = (math.radians(-70 if i==1 else -80),0,0)
bpy.ops.object.mode_set(mode="OBJECT")
preview(PREV + "arms.png", target=(-0.15,0.5,0), dist=0.9, elev=0.9, az=-1.2)
preview(PREV + "arms_side.png", target=(0.0,0.6,0), dist=0.35, elev=0.2, az=0.3)
print("arms done")
