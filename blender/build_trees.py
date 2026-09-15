# Card-based fir trees: tapered bark trunk + drooping branch cards baked by bake_branch_cards.py.
import sys, os; sys.path.insert(0, os.path.dirname(__file__))
from common import *
import random, mathutils
TEX = ROOT + "/game/assets/textures/trees/"
TW = PH + "trees/"

def trunk(h, r0, segs=10, rings=12, seed=0):
    random.seed(seed)
    bm = bmesh.new(); uvl = bm.loops.layers.uv.new("UVMap")
    rings_v = []
    lean = mathutils.Vector((random.uniform(-0.15,0.15), random.uniform(-0.15,0.15), 0))
    for i in range(rings+1):
        t = i/rings; z = t*h
        r = r0*(1-t*0.92) * (1.35 if i == 0 else 1.0)
        off = lean * t*t
        ring = [bm.verts.new((math.cos(a)*r+off.x, math.sin(a)*r+off.y, z)) for a in [j/segs*2*math.pi for j in range(segs)]]
        rings_v.append(ring)
    for i in range(rings):
        for j in range(segs):
            a,b = rings_v[i][j], rings_v[i][(j+1)%segs]; c,d = rings_v[i+1][(j+1)%segs], rings_v[i+1][j]
            f = bm.faces.new((a,b,c,d))
            for lp,(u,v) in zip(f.loops, ((j/segs, i/rings*h/2), ((j+1)/segs, i/rings*h/2), ((j+1)/segs,(i+1)/rings*h/2), (j/segs,(i+1)/rings*h/2))):
                lp[uvl].uv = (u*2, v)
    me = bpy.data.meshes.new("Trunk"); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    return me, lean

def add_card(bm, uvl, origin, direction, up, length, width, droop, segs=4, u0=0.0, u1=1.0, v0=0.0, v1=1.0):
    side = direction.cross(up).normalized()
    nrm = side.cross(direction).normalized()
    prev = None
    for s in range(segs+1):
        t = s/segs
        p = origin + direction*length*t - nrm*droop*t*t*length
        l = bm.verts.new(p - side*width/2); r = bm.verts.new(p + side*width/2)
        u = u0 + (u1-u0)*t
        if prev:
            f = bm.faces.new((prev[0], prev[1], r, l))
            for lp,(uu,vv) in zip(f.loops, ((prev[2],v0),(prev[2],v1),(u,v1),(u,v0))): lp[uvl].uv = (uu,vv)
        prev = (l, r, u)

def build_fir(name, h, seed):
    reset(); random.seed(seed)
    tme, lean = trunk(h*0.97, 0.024*h, seed=seed)
    tob = link(bpy.data.objects.new("Trunk", tme))
    tob.data.materials.append(pbr("bark", TW+"fir_tree_01_bark_diff_2k.jpg", TW+"fir_tree_01_bark_nor_gl_2k.jpg", None, rough=0.9))
    bm = bmesh.new(); uvl = bm.loops.layers.uv.new("UVMap")
    bm_tip = bmesh.new(); uvt = bm_tip.loops.layers.uv.new("UVMap")
    base = h*0.18; levels = int(h*1.35)
    Z = mathutils.Vector((0,0,1))
    for i in range(levels):
        t = i/(levels-1); z = base + t*(h*0.9-base)
        center = lean*(z/h)**2 + mathutils.Vector((0,0,z))
        L = (h*0.26)*(1-t)**0.95 + 0.35
        n = random.randint(5,7) if t < 0.8 else random.randint(3,5)
        a0 = random.uniform(0, 6.28)
        for k in range(n):
            a = a0 + k/n*2*math.pi + random.uniform(-0.25,0.25)
            pitch = math.radians(random.uniform(-4, 12) - 8*t)
            d = mathutils.Vector((math.cos(a)*math.cos(pitch), math.sin(a)*math.cos(pitch), -math.sin(pitch))).normalized()
            Ll = L*random.uniform(0.8,1.1)
            droop = random.uniform(0.12,0.28)*(1-t*0.5)
            # flat card (face up) + slanted second card for side volume
            add_card(bm, uvl, center, d, Z, Ll, Ll*0.5, droop)
            tilt = (Z*0.6 + d.cross(Z).normalized()).normalized()
            add_card(bm, uvl, center, d, tilt, Ll*0.9, Ll*0.45, droop*0.8)
    # crown tip: 3 crossed upright cards
    top = lean + mathutils.Vector((0,0,h*0.86))
    for k in range(3):
        a = k/3*math.pi
        side = mathutils.Vector((math.cos(a), math.sin(a), 0))
        add_card(bm_tip, uvt, top, Z, side.cross(Z), h*0.16, h*0.08, 0.0, segs=2)
    fme = bpy.data.meshes.new("Foliage"); bm.to_mesh(fme); bm.free()
    fob = link(bpy.data.objects.new("Foliage", fme))
    fob.data.materials.append(pbr("fir_branch", TEX+"fir_branch_card.png", alpha="diff", rough=0.85, clip=True))
    # tip card uv: stem is along +v in the tip texture, cards grow along u -> rotate uv
    for f in bm_tip.faces:
        for lp in f.loops:
            u, v = lp[uvt].uv; lp[uvt].uv = (v, u)
    tme2 = bpy.data.meshes.new("FoliageTip"); bm_tip.to_mesh(tme2); bm_tip.free()
    tip = link(bpy.data.objects.new("FoliageTip", tme2))
    tip.data.materials.append(pbr("fir_tip", TEX+"fir_tip_card.png", alpha="diff", rough=0.85, clip=True))
    for ob in (fob, tip):
        for p in ob.data.polygons: p.use_smooth = True
    tris = sum(len(o.data.polygons)*2 for o in (fob, tip)) + len(tme.polygons)*2
    export_glb(MODELS + f"trees/{name}.glb", [tob, fob, tip])
    print(name, "tris~", tris)
    return tob, fob, tip

os.makedirs(MODELS + "trees", exist_ok=True)
build_fir("fir_a", 14.0, 11)
build_fir("fir_b", 10.0, 23)
build_fir("fir_c", 17.0, 37)
# preview the last one
preview(PREV + "fir_c.png", target=(0,0,7.5), dist=24, elev=0.12, az=0.7, hdri=PH+"hdri/kloofendal_misty_morning_puresky_2k.hdr")
print("done")
