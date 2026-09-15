# First-person arms v2: rigid rounded segments (sleeve, forearm, glove palm, capsule phalanges) each weighted 100% to
# one bone, so nothing smears when the IK bends joints. Same bone names/layout as v1. Vertex colours: R=glove, G=sleeve.
import sys, os; sys.path.insert(0, os.path.dirname(__file__))
from common import *
import mathutils
V = mathutils.Vector

J = {"shoulder": V((0,0,0)), "elbow": V((0,0.30,0)), "wrist": V((0,0.555,0))}
FING = {  # knuckle, segment lengths, radius
 "index":  (V((-0.030,0.648,0.002)), (0.044,0.026,0.021), 0.0094),
 "middle": (V((-0.010,0.653,0.004)), (0.048,0.029,0.023), 0.0098),
 "ring":   (V(( 0.010,0.649,0.002)), (0.045,0.027,0.022), 0.0092),
 "pinky":  (V(( 0.028,0.638,-0.002)), (0.035,0.021,0.019), 0.0082),
}
THUMB = [V((-0.024,0.572,-0.010)), V((-0.046,0.600,-0.020)), V((-0.058,0.630,-0.024)), V((-0.064,0.653,-0.026))]

class Builder:
    def __init__(self, sx):
        self.sx = sx; self.bm = bmesh.new()
        self.col = self.bm.verts.layers.float_color.new("Col")
        self.dl = self.bm.verts.layers.deform.verify()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.groups = []
    def M(self, v): return V((v.x*self.sx, v.y, v.z))
    def gid(self, name):
        if name not in self.groups: self.groups.append(name)
        return self.groups.index(name)
    def add(self, tmp_bm, bone, glove, sleeve, matrix):
        """Copy a temporary bmesh in, transformed, weighted to bone, with region colours and cylindrical UVs."""
        g = self.gid(bone); vmap = {}
        for v in tmp_bm.verts:
            co = matrix @ v.co
            nv = self.bm.verts.new(self.M(co)); vmap[v] = nv
            nv[self.col] = (glove, sleeve, 0.0, 1.0); nv[self.dl][g] = 1.0
        for f in tmp_bm.faces:
            try:
                nf = self.bm.faces.new([vmap[v] for v in (reversed(f.verts) if self.sx < 0 else f.verts)])
            except ValueError:
                continue
            nf.smooth = True
            us = []
            for lp in nf.loops:
                c = lp.vert.co
                us.append([math.atan2(c.z, c.x*self.sx)/(2*math.pi)+0.5, c.y*3.0])
            if max(u for u,_ in us) - min(u for u,_ in us) > 0.5:
                for u in us:
                    if u[0] < 0.5: u[0] += 1.0
            for lp,(u,vv) in zip(nf.loops, us): lp[self.uv].uv = (u, vv)

def rounded_box(size, subdiv=2, taper=None):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=3, use_grid_fill=True)
    # round the cube toward a sphere
    for v in bm.verts:
        p = v.co.copy()
        sph = p.normalized() * 0.5
        q = p.lerp(sph, 0.55)
        v.co = V((q.x*size[0], q.y*size[1], q.z*size[2]))
        if taper:
            t = (v.co.y/size[1]) + 0.5
            v.co.x *= taper[0] + (taper[1]-taper[0])*t
            v.co.z *= taper[0] + (taper[1]-taper[0])*t
    return bm

def capsule(r0, r1, length, segs=16, rings=6):
    """Along +Y from 0 to length, hemispherical caps."""
    bm = bmesh.new()
    rows = []
    prof = []
    for i in range(rings+1):  # bottom cap
        a = -math.pi/2 + (math.pi/2)*i/rings
        prof.append((math.cos(a)*r0, math.sin(a)*r0))
    for i in range(1, 4):
        t = i/4; prof.append((r0+(r1-r0)*t, length*t))
    for i in range(rings+1):  # top cap
        a = (math.pi/2)*i/rings
        prof.append((math.cos(a)*r1, length + math.sin(a)*r1))
    for (rad, y) in prof:
        row = [bm.verts.new((math.cos(2*math.pi*j/segs)*rad, y, math.sin(2*math.pi*j/segs)*rad)) for j in range(segs)]
        rows.append(row)
    for i in range(len(rows)-1):
        for j in range(segs):
            j2 = (j+1) % segs
            try: bm.faces.new((rows[i][j], rows[i+1][j], rows[i+1][j2], rows[i][j2]))
            except ValueError: pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    return bm

def tube(r0, r1, length, squash=1.0, segs=24, rings=10, bulge=0.0):
    bm = bmesh.new(); rows = []
    for i in range(rings+1):
        t = i/rings; y = length*t
        rad = r0 + (r1-r0)*t + bulge*math.sin(math.pi*min(1.0, t*1.6))
        rows.append([bm.verts.new((math.cos(2*math.pi*j/segs)*rad, y, math.sin(2*math.pi*j/segs)*rad*squash)) for j in range(segs)])
    for i in range(rings):
        for j in range(segs):
            j2 = (j+1) % segs
            bm.faces.new((rows[i][j], rows[i+1][j], rows[i+1][j2], rows[i][j2]))
    return bm

def torus_bm(R, r, squash, segs=28, rsegs=10):
    """Ring around +Y."""
    bm = bmesh.new(); rows = []
    for i in range(segs):
        a = 2*math.pi*i/segs
        rows.append([bm.verts.new((math.cos(a)*(R + math.cos(2*math.pi*j/rsegs)*r), math.sin(2*math.pi*j/rsegs)*r, math.sin(a)*(R + math.cos(2*math.pi*j/rsegs)*r)*squash)) for j in range(rsegs)])
    for i in range(segs):
        for j in range(rsegs):
            i2 = (i+1) % segs; j2 = (j+1) % rsegs
            bm.faces.new((rows[i][j], rows[i2][j], rows[i2][j2], rows[i][j2]))
    return bm

def align(origin, direction):
    d = V(direction).normalized()
    q = V((0,1,0)).rotation_difference(d)
    return mathutils.Matrix.Translation(V(origin)) @ q.to_matrix().to_4x4()

def build_side(side):
    sx = 1 if side == "R" else -1
    B = Builder(sx)
    # sleeve (upper arm) + rolled cuff, elbow joint ball
    B.add(tube(0.052, 0.045, 0.29, squash=0.92, bulge=0.004), "upper", 0, 1, align(J["shoulder"], (0,1,0)))
    for (yy, R, rr) in ((0.262, 0.05, 0.015), (0.285, 0.049, 0.013)):
        B.add(torus_bm(R, rr, 0.9), "upper", 0, 1, mathutils.Matrix.Translation(V((0, yy, 0))))
    ball = bmesh.new(); bmesh.ops.create_uvsphere(ball, u_segments=16, v_segments=10, radius=0.038)
    B.add(ball, "fore", 0, 0, mathutils.Matrix.Translation(J["elbow"]))
    # forearm: oval, tapering, slight muscle bulge near the elbow
    B.add(tube(0.039, 0.026, 0.25, squash=0.78, bulge=0.006), "fore", 0, 0, align(J["elbow"], (0,1,0)))
    # glove cuff over the wrist
    B.add(torus_bm(0.027, 0.011, 0.78, segs=24, rsegs=10), "hand", 1, 0, mathutils.Matrix.Translation(J["wrist"] + V((0,0.004,0))) @ mathutils.Matrix.Diagonal((1,2.2,1,1)))
    # palm: rounded pillow, wider at the knuckles, thin
    palm = rounded_box((0.082, 0.1, 0.034), taper=(0.9, 1.05))
    B.add(palm, "hand", 1, 0, mathutils.Matrix.Translation(V((-0.001, 0.603, -0.001))))
    thenar = rounded_box((0.032, 0.055, 0.03)); B.add(thenar, "hand", 1, 0, mathutils.Matrix.Translation(V((-0.022, 0.588, -0.006))))
    for name,(k,segs,r) in FING.items():
        p = k.copy()
        for i,s in enumerate(segs):
            r0 = r*(1.0-0.08*i); r1 = r*(0.92-0.08*i)
            glove = 1.0 if i == 0 else 0.0
            B.add(capsule(r0*(1.12 if i == 0 else 1.0), r1*(1.1 if i == 0 else 1.0), s - r1*0.6), f"{name}{i+1}", glove, 0, align(p, (0,1,0)))
            p = p + V((0,s,0))
    for i in range(3):
        a, b = THUMB[i], THUMB[i+1]
        r = [0.0125, 0.0108, 0.0098][i]
        B.add(capsule(r, r*0.92, (b-a).length - r*0.5), f"thumb{i+1}", 1.0 if i == 0 else 0.0, 0, align(a, b-a))
    me = bpy.data.meshes.new("Arm"+side); B.bm.to_mesh(me); B.bm.free()
    ob = link(bpy.data.objects.new("Arm"+side, me))
    ca = me.color_attributes.get("Col")
    if ca:
        me.color_attributes.active_color = ca
        me.color_attributes.render_color_index = me.color_attributes.find("Col")
    for gname in B.groups: ob.vertex_groups.new(name=gname)
    ob.data.materials.append(bpy.data.materials.get("Arm") or bpy.data.materials.new("Arm"))
    # armature (identical layout to v1)
    ad = bpy.data.armatures.new("Rig"+side); rig = link(bpy.data.objects.new("Rig"+side, ad))
    bpy.ops.object.select_all(action="DESELECT"); rig.select_set(True); bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    M = B.M
    def bone(name, head, tail, parent=None):
        b = ad.edit_bones.new(name); b.head = M(head); b.tail = M(tail); b.roll = 0.0
        if parent: b.parent = ad.edit_bones[parent]
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
    mod = ob.modifiers.new("Armature", "ARMATURE"); mod.object = rig
    ob.parent = rig
    return rig, ob

reset()
rR, oR = build_side("R")
rL, oL = build_side("L")
export_glb(MODELS + "arms.glb", [rR, oR, rL, oL], export_vertex_color="ACTIVE")
# preview: right hand in a grip around a vertical stick, plus close-up
bpy.context.view_layer.objects.active = rR; bpy.ops.object.mode_set(mode="POSE")
for n in ("index","middle","ring","pinky"):
    for i,a in zip((1,2,3),(-75,-90,-60)):
        pb = rR.pose.bones[f"{n}{i}"]; pb.rotation_mode = "XYZ"; pb.rotation_euler = (math.radians(a),0,0)
for i in (1,2,3):
    pb = rR.pose.bones[f"thumb{i}"]; pb.rotation_mode = "XYZ"; pb.rotation_euler = (math.radians(-25),0,math.radians(20))
bpy.ops.object.mode_set(mode="OBJECT")
rL.location.x = -0.3
mat = bpy.data.materials["Arm"]; mat.use_nodes = True
nt = mat.node_tree; bsdf = nt.nodes["Principled BSDF"]
attr = nt.nodes.new("ShaderNodeVertexColor"); attr.layer_name = "Col"
sep = nt.nodes.new("ShaderNodeSeparateColor"); nt.links.new(attr.outputs[0], sep.inputs[0])
mix1 = nt.nodes.new("ShaderNodeMix"); mix1.data_type = "RGBA"; mix1.inputs[6].default_value = (0.72,0.5,0.39,1); mix1.inputs[7].default_value = (0.24,0.14,0.08,1)
nt.links.new(sep.outputs[0], mix1.inputs[0])
mix2 = nt.nodes.new("ShaderNodeMix"); mix2.data_type = "RGBA"; mix2.inputs[7].default_value = (0.42,0.07,0.06,1)
nt.links.new(mix1.outputs[2], mix2.inputs[6]); nt.links.new(sep.outputs[1], mix2.inputs[0]); nt.links.new(mix2.outputs[2], bsdf.inputs["Base Color"])
preview(PREV + "arms2.png", target=(0.0,0.6,0.0), dist=0.32, elev=0.35, az=0.9)
preview(PREV + "arms2_top.png", target=(-0.15,0.45,0.0), dist=0.9, elev=1.2, az=-1.4)
print("arms done")
