# Small props and inventory items: knife, switch stand, buffer stop, jerrycan, barrel, log, coal, stone, fiber, sleeper.
import sys, os; sys.path.insert(0, os.path.dirname(__file__))
from vkit import *
os.makedirs(MODELS + "props", exist_ok=True); os.makedirs(MODELS + "tools", exist_ok=True); os.makedirs(MODELS + "items", exist_ok=True)
import random

def out(path, prev=None, **pv):
    export_glb(MODELS + path, list(bpy.context.scene.objects))
    if prev: preview(PREV + prev, **pv)

def knife():
    reset(); clear_mats()
    root = empty("Knife", (0,0,0))
    # blade along +Y from guard at y=0; handle y<0. Edge down (-Z).
    me = bpy.data.meshes.new("Blade"); bm = bmesh.new()
    prof = [(0.0,0.012),(0.0,-0.016),(0.09,-0.018),(0.13,-0.012),(0.155,0.002),(0.12,0.012)]
    top = [bm.verts.new((0.0022, y, z)) for y,z in prof]; bot = [bm.verts.new((-0.0022, y, z)) for y,z in prof]
    bm.faces.new(top); bm.faces.new(list(reversed(bot)))
    for i in range(len(prof)):
        j = (i+1) % len(prof); bm.faces.new((top[i], top[j], bot[j], bot[i]))
    # sharpen edge: pull bottom edge verts together
    for v in top + bot:
        if v.co.z < -0.01: v.co.x *= 0.15
    bm.normal_update(); bm.to_mesh(me); bm.free()
    blade = link(bpy.data.objects.new("Blade", me)); blade.parent = root; boxuv(me); me.materials.append(mat("steel"))
    box("guard", (0.012, 0.012, 0.042), (0, -0.004, -0.002), "brass", root, bevel=0.003)
    h = cyl("handle", 0.014, 0.11, (0, -0.066, -0.002), "Y", "wood", root, verts=14, r2=0.016)
    h.scale = (0.8, 1, 1)
    cyl("pommel", 0.016, 0.012, (0, -0.126, -0.002), "Y", "brass", root, verts=14)
    for nm, p in (("M_Grip",(0,-0.06,-0.002)),("M_Tip",(0,0.155,0.0))): empty(nm, p, root)
    out("tools/knife.glb", "knife.png", target=(0,0,0), dist=0.45, elev=0.3, az=0.2)

def switch_stand():
    reset(); clear_mats()
    root = empty("SwitchStand", (0,0,0))
    base = box("Base", (0.5, 0.4, 0.12), (0, 0, 0.06), "black", root)
    box("housing", (0.22, 0.22, 0.45), (0, 0, 0.35), "black", base)
    cyl("mast", 0.035, 0.9, (0, 0, 1.0), "Z", "black", base, verts=12)
    join_children(base)
    tgt = anim(box("Target", (0.02, 0.4, 0.4), (0, 0, 1.3), "red", root, pivot=(0, 0, 1.3)))
    box("targetband", (0.025, 0.12, 0.42), (0, 0, 1.3), "cream", tgt, bevel=0); join_children(tgt)
    lev = anim(box("Lever", (0.05, 0.7, 0.05), (0, 0.38, 0.6), "black", root, pivot=(0, 0.05, 0.6)))
    box("levergrip", (0.07, 0.14, 0.07), (0, 0.72, 0.6), "red", lev); join_children(lev)
    empty("M_Grip", (0, 0.72, 0.6), root)
    out("props/switch_stand.glb", "switch.png", target=(0,0,0.7), dist=2.5, elev=0.3, az=0.6)

def buffer_stop():
    reset(); clear_mats()
    root = empty("BufferStop", (0,0,0))
    b = box("Body", (2.2, 0.3, 0.45), (0, 0, 0.95), "red", root)
    for x in (-0.75, 0.75):
        cyl(f"buf{x}", 0.17, 0.06, (x, 0.2, 0.95), "Y", "steel", b, verts=18)
        cyl(f"stock{x}", 0.07, 0.2, (x, 0.1, 0.95), "Y", "black", b, verts=12)
    for x in (-0.72, 0.72):
        box(f"strut{x}", (0.14, 1.6, 0.14), (x, -0.7, 0.55), "black", b, rot=(math.radians(-30),0,0))
        box(f"post{x}", (0.14, 0.14, 0.95), (x, 0, 0.47), "black", b)
    box("sleeperA", (2.6, 0.26, 0.15), (0, 0, 0.0), "wood", b)
    box("sleeperB", (2.6, 0.26, 0.15), (0, -1.3, 0.0), "wood", b)
    join_children(b)
    out("props/buffer_stop.glb", "buffer.png", target=(0,-0.4,0.6), dist=4, elev=0.3, az=0.9)

def jerrycan():
    reset(); clear_mats()
    root = empty("Jerrycan", (0,0,0))
    b = box("Body", (0.17, 0.35, 0.46), (0, 0, 0.23), "red", root, bevel=0.03)
    box("handle", (0.04, 0.2, 0.05), (0, -0.04, 0.5), "red", b, bevel=0.01)
    cyl("spout", 0.025, 0.06, (0, 0.13, 0.49), "Z", "steel", b, verts=12)
    join_children(b)
    empty("M_Grip", (0, -0.04, 0.5), root)
    out("items/jerrycan.glb", "jerrycan.png", target=(0,0,0.25), dist=1.3, elev=0.3, az=0.6)

def barrel():
    reset(); clear_mats()
    root = empty("WaterBarrel", (0,0,0))
    b = cyl("Body", 0.32, 0.95, (0, 0, 0.475), "Z", "wood", root, verts=28, r2=0.32)
    cyl("mid", 0.35, 0.5, (0, 0, 0.475), "Z", "wood", b, verts=28, cap=False)
    for z in (0.12, 0.36, 0.6, 0.84):
        cyl(f"hoop{z}", 0.345, 0.04, (0, 0, z), "Z", "iron", b, verts=28)
    cyl("water", 0.3, 0.01, (0, 0, 0.9), "Z", "WaterLevel", b, verts=28)
    join_children(b)
    out("props/water_barrel.glb", "barrel.png", target=(0,0,0.5), dist=2.2, elev=0.4, az=0.6)

def items():
    # log
    reset(); clear_mats()
    bark = pbr("bark", PH+"trees/fir_tree_01_bark_diff_2k.jpg", PH+"trees/fir_tree_01_bark_nor_gl_2k.jpg")
    root = empty("Log", (0,0,0))
    lg = cyl("Body", 0.09, 0.55, (0,0,0), "Y", bark, root, verts=14)
    for y in (-0.276, 0.276):
        cyl(f"cut{y}", 0.085, 0.004, (0,y,0), "Y", "planks", lg, verts=14)
    join_children(lg)
    out("items/log.glb", "log.png", target=(0,0,0), dist=1.2, elev=0.4, az=0.6)
    # coal lump & stone: noise-displaced icospheres
    for name, m, r, seed in (("coal", "black", 0.07, 3), ("stone", None, 0.08, 5)):
        reset(); clear_mats()
        random.seed(seed)
        bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
        for v in bm.verts:
            v.co *= random.uniform(0.8, 1.15); v.co.z *= 0.75
        me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        ob = link(bpy.data.objects.new(name.capitalize(), me)); boxuv(me, 3.0)
        if m: me.materials.append(pbr("coal", VT+"black_diffuse.jpg", VT+"iron_nor_gl.jpg", rough=0.45, metal=0.2))
        else: me.materials.append(pbr("stone", ROOT+"/game/assets/textures/rock/boulder_01_diff_1k.jpg", ROOT+"/game/assets/textures/rock/boulder_01_nor_gl_1k.jpg"))
        out(f"items/{name}.glb")
    # fiber bundle
    reset(); clear_mats()
    root = empty("Fiber", (0,0,0))
    random.seed(9)
    grass = pbr("fiber", color=(0.42,0.45,0.2,1), rough=0.9)
    b = box("Body", (0.004, 0.3, 0.004), (0,0,0), grass, root, bevel=0)
    for i in range(24):
        box(f"f{i}", (0.004, random.uniform(0.25,0.33), 0.004), (random.uniform(-0.025,0.025), random.uniform(-0.02,0.02), random.uniform(-0.02,0.02)), grass, b, rot=(random.uniform(-0.1,0.1),0,random.uniform(-0.15,0.15)), bevel=0)
    box("tie", (0.06, 0.02, 0.06), (0,0,0), "rope", b, bevel=0.005)
    join_children(b)
    out("items/fiber.glb")

knife(); switch_stand(); buffer_stop(); jerrycan(); barrel(); items()
print("props ok")
