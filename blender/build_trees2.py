# Realistic conifers: curved 3D branches + sub-branches carrying hundreds of individually oriented twig sprites
# (Poly Haven atlases), foliage normals bent outward from the crown axis so the crown shades as a volume.
import sys, os, random; sys.path.insert(0, os.path.dirname(__file__))
from common import *
import mathutils
V = mathutils.Vector
TW = PH + "trees/"

FIR_SPR = [(80,104,162,198), (163,118,242,211), (168,12,238,93), (49,14,105,79)]
PINE_SPR = [(9,12,54,112), (167,88,238,132)]

def card_material(species):
    tex = ROOT + "/game/assets/textures/trees/" + ("fir_branch_card.png" if species == "fir" else "pine_tuft_card.png")
    m = bpy.data.materials.new(species + "_card"); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    d = nt.nodes.new("ShaderNodeTexImage"); d.image = img(tex)
    nt.links.new(d.outputs["Color"], b.inputs["Base Color"]); nt.links.new(d.outputs["Alpha"], b.inputs["Alpha"])
    b.inputs["Roughness"].default_value = 0.85
    m.surface_render_method = "DITHERED"
    return m


def branch_card(F, pts, width, roll, twist_up=V((0,0,1))):
    """Strip following a branch polyline; texture u runs along the branch (stem at u=0), v across."""
    n = len(pts)
    L = sum((pts[i+1]-pts[i]).length for i in range(n-1))
    acc = 0.0
    prev = None
    for i in range(n):
        d = (pts[min(i+1,n-1)] - pts[max(i-1,0)]).normalized()
        side = d.cross(twist_up)
        side = side.normalized() if side.length > 0.01 else d.cross(V((1,0,0))).normalized()
        side = mathutils.Quaternion(d, roll) @ side
        if i > 0: acc += (pts[i]-pts[i-1]).length
        u = acc / L
        w = width * (0.55 + 0.45 * math.sin(min(1.0, u*1.1) * math.pi * 0.5 + 0.3))
        cur = (pts[i] - side*w*0.5, pts[i] + side*w*0.5, u)
        if prev:
            F.quad([prev[0], prev[1], cur[1], cur[0]], [(prev[2], 0.0), (prev[2], 1.0), (u, 1.0), (u, 0.0)])
        prev = cur


def tuft(F, at, size, rng, up_bias=0.4):
    for k in range(3):
        a = rng.uniform(0, math.pi)
        d = V((math.cos(a), math.sin(a), 0))
        tilt = V((rng.uniform(-0.3,0.3), rng.uniform(-0.3,0.3), 1.0)).normalized()
        side = d; nrm = tilt
        fwd = nrm.cross(side).normalized()
        c = at
        h = size*0.5
        F.quad([c - side*h - fwd*h, c + side*h - fwd*h, c + side*h + fwd*h, c - side*h + fwd*h], [(0,0),(1,0),(1,1),(0,1)])
    for k in range(2):
        a = rng.uniform(0, math.pi)
        side = V((math.cos(a), math.sin(a), 0)); up = V((0,0,1))
        h = size*0.5
        F.quad([at - side*h - up*h*0.8, at + side*h - up*h*0.8, at + side*h + up*h, at - side*h + up*h], [(0,0),(1,0),(1,1),(0,1)])


def twig_material(species):
    m = bpy.data.materials.new(species + "_twig"); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    d = nt.nodes.new("ShaderNodeTexImage"); d.image = img(TW + f"{species}_tree_01_twig_diff_2k.jpg")
    a = nt.nodes.new("ShaderNodeTexImage"); a.image = img(TW + f"{species}_tree_01_twig_alpha_2k.png", True)
    n = nt.nodes.new("ShaderNodeTexImage"); n.image = img(TW + f"{species}_tree_01_twig_nor_gl_2k.jpg", True)
    nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(n.outputs[0], nm.inputs["Color"])
    nt.links.new(d.outputs[0], b.inputs["Base Color"]); nt.links.new(a.outputs[0], b.inputs["Alpha"]); nt.links.new(nm.outputs[0], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.8
    m.blend_method = "CLIP" if hasattr(m, "blend_method") else None
    return m

def bark_material(species):
    return pbr(species + "_bark", TW + f"{species}_tree_01_bark_diff_2k.jpg", TW + f"{species}_tree_01_bark_nor_gl_2k.jpg", rough=0.95)

class Mesh:
    def __init__(self, name):
        self.bm = bmesh.new(); self.uv = self.bm.loops.layers.uv.new("UVMap"); self.name = name
        self.normals = []   # per loop custom normal, in creation order
    def quad(self, pts, uvs, nrm=None):
        vs = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        for lp, uv in zip(f.loops, uvs): lp[self.uv].uv = uv
        f.smooth = True
        return f
    def finish(self):
        me = bpy.data.meshes.new(self.name); self.bm.to_mesh(me); self.bm.free()
        return me

def tube(M, path, radii, segs=5, uv_rep=1.0):
    rings = []
    for i, (p, r) in enumerate(zip(path, radii)):
        t = (path[min(i+1, len(path)-1)] - path[max(i-1, 0)]).normalized()
        side = t.cross(V((0,0,1)) if abs(t.z) < 0.95 else V((1,0,0))).normalized()
        up = side.cross(t).normalized()
        rings.append([p + (side*math.cos(a) + up*math.sin(a))*r for a in [k/segs*math.tau for k in range(segs)]])
    L = 0.0
    for i in range(len(rings)-1):
        seg_len = (path[i+1]-path[i]).length
        for k in range(segs):
            k2 = (k+1) % segs
            M.quad([rings[i][k], rings[i][k2], rings[i+1][k2], rings[i+1][k]],
                   [(k/segs, L*uv_rep), ((k+1)/segs, L*uv_rep), ((k+1)/segs, (L+seg_len)*uv_rep), (k/segs, (L+seg_len)*uv_rep)])
        L += seg_len

def twig(F, spr_list, at, direction, up_hint, size, rng, bend=0.25):
    x0,y0,x1,y1 = rng.choice(spr_list)
    aspect = (x1-x0)/(y1-y0)
    d = direction.normalized()
    roll = rng.uniform(-1.2, 1.2)
    side = d.cross(up_hint).normalized() if d.cross(up_hint).length > 0.01 else d.cross(V((1,0,0))).normalized()
    side = mathutils.Quaternion(d, roll) @ side
    nrm = side.cross(d).normalized()
    w = size * aspect * 0.5
    # two-segment card with a slight downward bend along its length
    mid = at + d*size*0.5 - nrm*size*bend*0.2
    tip = at + d*size - nrm*size*bend*0.6
    u0,u1 = x0/256, x1/256; v0,v1 = 1-y1/256, 1-y0/256; vm = (v0+v1)/2
    F.quad([at - side*w*0.6, at + side*w*0.6, mid + side*w, mid - side*w], [(u0,v0),(u1,v0),(u1,vm),(u0,vm)])
    F.quad([mid - side*w, mid + side*w, tip + side*w*0.8, tip - side*w*0.8], [(u0,vm),(u1,vm),(u1,v1),(u0,v1)])

def build(name, species, height, seed, style):
    reset(); rng = random.Random(seed)
    T = Mesh("Trunk"); B = Mesh("Branches"); F = Mesh("Foliage")
    spr = FIR_SPR if species == "fir" else PINE_SPR
    lean = V((rng.uniform(-0.2,0.2), rng.uniform(-0.2,0.2), 0))
    # trunk centerline with gentle wobble
    trunk_pts = []; trunk_r = []
    r0 = height * (0.022 if species == "fir" else 0.026)
    for i in range(15):
        t = i/14; z = t*height
        wob = V((math.sin(t*7+seed)*0.08, math.cos(t*5+seed)*0.08, 0)) * t
        trunk_pts.append(V((0,0,z)) + lean*t*t + wob)
        trunk_r.append(r0*(1-t*0.94)*(1.5 if i == 0 else (1.15 if i == 1 else 1.0)))
    tube(T, trunk_pts, trunk_r, segs=9, uv_rep=0.5)
    def axis_at(z):
        t = max(0.0, min(1.0, z/height)); i = min(13, int(t*14)); f = t*14 - i
        return trunk_pts[i].lerp(trunk_pts[i+1], f)
    if style == "fir":
        crown_base, levels = height*0.12, int(height*1.9)
    else:
        crown_base, levels = height*0.55, int(height*1.3)
    for li in range(levels):
        t = li/(levels-1); z = crown_base + t*(height*0.96 - crown_base)
        center = axis_at(z)
        if style == "fir":
            L = (height*0.27)*(1-t)**0.9 + 0.3
            n = rng.randint(5, 7) if t < 0.85 else 4
        else:
            env = math.sin(min(1.0, t*1.15)*math.pi)
            L = height*0.2*env + 0.4
            n = rng.randint(2, 4)
        a0 = rng.uniform(0, math.tau)
        for k in range(n):
            a = a0 + k/n*math.tau + rng.uniform(-0.4,0.4)
            out = V((math.cos(a), math.sin(a), 0))
            pitch = (rng.uniform(-0.15, 0.25) - 0.35*t) if style == "fir" else rng.uniform(0.05, 0.6)
            Lb = L*rng.uniform(0.8, 1.15)
            # branch curve: out, droop, tip turns up
            pts = []; rads = []
            steps = 5
            for s in range(steps+1):
                u = s/steps
                droop = (0.35*u*u - 0.18*u*u*u*1.5) * Lb if style == "fir" else -0.1*u*Lb
                p = center + out*Lb*u + V((0,0,math.sin(pitch)*Lb*u - droop))
                pts.append(p); rads.append(max(0.004, r0*0.35*(1-u)*(1-t*0.6)))
            tube(B, pts, [r*0.45 for r in rads], segs=4, uv_rep=2.0)
            if style == "fir":
                for roll in (-0.55, 0.0, 0.55):
                    shifted = [p + V((0,0,0.02*abs(roll))) for p in pts]
                    branch_card(F, shifted, Lb * rng.uniform(0.5, 0.62), roll + rng.uniform(-0.15, 0.15))
            else:
                for c in range(rng.randint(2, 4)):
                    u = rng.uniform(0.55, 1.0)
                    i = min(steps-1, int(u*steps)); f = u*steps - i
                    p = pts[i].lerp(pts[i+1], f) + V((0,0,0.08))
                    tuft(F, p, rng.uniform(0.9, 1.35) * (1.0 - t*0.25), rng)
    # crown tip
    top = axis_at(height*0.97)
    if style == "fir":
        for k in range(3):
            a = k/3*math.pi
            pts = [top - V((0,0,height*0.08)) + V((0,0,height*0.12*i/4)) for i in range(5)]
            branch_card(F, pts, height*0.07, a, V((math.cos(a), math.sin(a), 0)))
    else:
        tuft(F, top, 1.5, rng)
    # build objects
    tme = T.finish(); bme = B.finish(); fme = F.finish()
    objs = []
    for me, mname in ((tme, "Trunk"), (bme, "Branches"), (fme, "Foliage")):
        ob = link(bpy.data.objects.new(mname, me)); objs.append(ob)
    objs[0].data.materials.append(bark_material(species)); objs[1].data.materials.append(bark_material(species))
    objs[2].data.materials.append(card_material(species))
    # outward crown normals for foliage (blend 70% spherical + 30% face)
    fo = objs[2]; me = fo.data
    center_z = (crown_base + height) * 0.5
    normals = []
    me.calc_loop_triangles() if hasattr(me, "calc_loop_triangles") else None
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        ax = axis_at(co.z)
        out = V((co.x - ax.x, co.y - ax.y, (co.z - center_z) * 0.35 + 0.25)).normalized()
        normals.append(out)
    if hasattr(me, "use_auto_smooth"): me.use_auto_smooth = True
    me.normals_split_custom_set(normals)
    for ob in objs:
        bpy.context.view_layer.objects.active = ob
    tris = sum(len(o.data.polygons)*2 for o in objs)
    export_glb(MODELS + f"trees/{name}.glb", objs)
    print(name, "tris", tris)
    return objs

os.makedirs(MODELS + "trees", exist_ok=True)
build("fir_a", "fir", 14.0, 11, "fir")
build("fir_b", "fir", 10.0, 23, "fir")
build("fir_c", "fir", 17.5, 37, "fir")
build("pine_a", "pine", 16.0, 51, "pine")
last = build("pine_b", "pine", 12.5, 63, "pine")
preview(PREV + "pine_b.png", target=(0,0,6.5), dist=22, elev=0.15, az=0.7, hdri=PH+"hdri/qwantani_morning_puresky_2k.hdr")
reset(); objs = []
bpy.ops.import_scene.gltf(filepath=MODELS + "trees/fir_a.glb")
preview(PREV + "fir_a2.png", target=(0,0,6.5), dist=20, elev=0.12, az=0.7, hdri=PH+"hdri/qwantani_morning_puresky_2k.hdr")
reset()
bpy.ops.import_scene.gltf(filepath=MODELS + "trees/fir_a.glb")
preview(PREV + "fir_a2_close.png", target=(0,0,4.5), dist=6, elev=0.1, az=0.3, hdri=PH+"hdri/qwantani_morning_puresky_2k.hdr")
print("trees2 ok")
