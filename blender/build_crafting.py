# Crafting items, primitive tools and placeable stations.
import sys, os, random; sys.path.insert(0, os.path.dirname(__file__))
from vkit import *
import mathutils

def out(path, prev=None, **kw):
    export_glb(MODELS + path, list(bpy.context.scene.objects))
    if prev: preview(PREV + prev, **kw)

def rock_blob(name, r, loc, material, parent=None, seed=1, squash=0.8):
    random.seed(seed)
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    for v in bm.verts:
        v.co *= random.uniform(0.8, 1.15); v.co.z *= squash
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new(name, me)); ob.location = loc
    boxuv(me, 4.0); me.materials.append(material if not isinstance(material, str) else mat(material))
    if parent: ob.parent = parent
    return ob

STONE = None
def stone_mat():
    return pbr("stone", ROOT+"/game/assets/textures/rock/boulder_01_diff_1k.jpg", ROOT+"/game/assets/textures/rock/boulder_01_nor_gl_1k.jpg", color=(0.7,0.7,0.7,1))

def bark_mat():
    return pbr("bark", PH+"trees/fir_tree_01_bark_diff_2k.jpg", PH+"trees/fir_tree_01_bark_nor_gl_2k.jpg")

# ---------------- primitive tools (handle along +Z Blender = up) ----------------
def stone_axe():
    reset(); clear_mats()
    root = empty("StoneAxe", (0,0,0))
    cyl("handle", 0.016, 0.55, (0,0,0.275), "Z", bark_mat(), root, verts=10, r2=0.014)
    rock_blob("head", 0.05, (0.045, 0, 0.5), stone_mat(), root, seed=3, squash=0.55).scale = (1.4, 0.45, 1.0)
    cyl("lash", 0.02, 0.07, (0,0,0.5), "Z", "rope", root, verts=10)
    out("tools/stone_axe.glb", "stone_axe.png", target=(0,0,0.3), dist=1.2, elev=0.2, az=0.4)

def stone_pickaxe():
    reset(); clear_mats()
    root = empty("StonePickaxe", (0,0,0))
    cyl("handle", 0.017, 0.62, (0,0,0.31), "Z", bark_mat(), root, verts=10, r2=0.015)
    h = rock_blob("head", 0.05, (0, 0, 0.58), stone_mat(), root, seed=5, squash=1.0)
    h.scale = (2.8, 0.5, 0.55)
    cyl("lash", 0.021, 0.07, (0,0,0.58), "Z", "rope", root, verts=10)
    out("tools/stone_pickaxe.glb")

def stone_knife():
    reset(); clear_mats()
    root = empty("StoneKnife", (0,0,0))
    cyl("handle", 0.013, 0.1, (0,-0.05,0), "Y", bark_mat(), root, verts=10)
    b = rock_blob("blade", 0.04, (0, 0.06, 0), stone_mat(), root, seed=9, squash=0.25)
    b.scale = (0.45, 1.6, 1.0)
    cyl("lash", 0.016, 0.03, (0,0.0,0), "Y", "rope", root, verts=10)
    empty("M_Grip", (0,-0.05,0), root); empty("M_Tip", (0,0.12,0), root)
    out("tools/stone_knife.glb")

def hammer():
    reset(); clear_mats()
    root = empty("Hammer", (0,0,0))
    cyl("handle", 0.015, 0.36, (0,0,0.18), "Z", "wood", root, verts=10)
    box("head", (0.12, 0.035, 0.035), (0.02, 0, 0.36), "iron", root, bevel=0.006)
    out("tools/hammer.glb")

def spear():
    reset(); clear_mats()
    root = empty("Spear", (0,0,0))
    cyl("shaft", 0.014, 1.5, (0,0,0.75), "Z", "wood", root, verts=10)
    rock_blob("tip", 0.03, (0,0,1.54), stone_mat(), root, seed=11, squash=1.0).scale = (0.5, 0.25, 2.0)
    cyl("lash", 0.018, 0.06, (0,0,1.48), "Z", "rope", root, verts=10)
    out("tools/spear.glb")

def bow():
    reset(); clear_mats()
    root = empty("Bow", (0,0,0))
    # limb as curved chain of cylinders along Z with bend toward -Y
    pts = []
    for i in range(13):
        t = i/12.0; z = (t-0.5)*1.2; y = -0.18*(1-(2*t-1)**2)
        pts.append((0, y, z))
    for i in range(12):
        a = mathutils.Vector(pts[i]); b = mathutils.Vector(pts[i+1]); mid = (a+b)/2; d = (b-a)
        c = cyl(f"limb{i}", 0.012 if 3<i<8 else 0.009, d.length*1.05, mid, "Z", "wood", root, verts=8)
        c.rotation_mode = "QUATERNION"; c.rotation_quaternion = d.to_track_quat("Z","Y")
    cyl("string", 0.0015, 1.2, (0,0,0), "Z", "rope", root, verts=4)
    cyl("grip", 0.016, 0.12, (0,-0.18,0), "Z", "rope", root, verts=10)
    empty("M_Grip", (0,-0.18,0), root)
    out("tools/bow.glb")

def arrow():
    reset(); clear_mats()
    root = empty("Arrow", (0,0,0))
    cyl("shaft", 0.004, 0.7, (0,0,0.35), "Z", "wood", root, verts=6)
    rock_blob("tip", 0.012, (0,0,0.71), stone_mat(), root, seed=13).scale = (0.6, 0.3, 2.2)
    for k in range(3):
        a = k*2.094
        box(f"fletch{k}", (0.002, 0.018, 0.08), (math.cos(a)*0.008, math.sin(a)*0.008, 0.06), pbr("feather", color=(0.85,0.82,0.75,1)), root, rot=(0,0,a), bevel=0)
    out("items/arrow.glb")

# ---------------- materials / items ----------------
def items():
    reset(); clear_mats(); root = empty("Stick", (0,0,0))
    cyl("s", 0.013, 0.45, (0,0,0), "Y", bark_mat(), root, verts=8, r2=0.009)
    cyl("twig", 0.006, 0.1, (0.02,0.1,0), "Y", bark_mat(), root, verts=6).rotation_euler = (0,0,-0.6)
    out("items/stick.glb")
    reset(); clear_mats(); root = empty("Plank", (0,0,0))
    box("p", (0.18, 0.9, 0.03), (0,0,0), "planks", root, bevel=0.004)
    out("items/plank.glb")
    reset(); clear_mats(); root = empty("Rope", (0,0,0))
    for k in range(5):
        c = cyl(f"coil{k}", 0.07, 0.015, (0,0,k*0.014), "Z", "rope", root, verts=18); c.scale = (1,1,1)
    cyl("hole", 0.04, 0.08, (0,0,0.03), "Z", pbr("dark", color=(0.2,0.16,0.1,1)), root, verts=12)
    out("items/rope.glb")
    for name, col, seed in (("iron_ore", (0.55,0.3,0.2,1), 21), ("copper_ore", (0.3,0.55,0.45,1), 22)):
        reset(); clear_mats()
        root = empty(name, (0,0,0))
        rock_blob("rock", 0.08, (0,0,0), stone_mat(), root, seed=seed)
        random.seed(seed)
        vein = pbr(name+"_vein", color=col, rough=0.5, metal=0.4)
        for k in range(6):
            rock_blob(f"v{k}", 0.022, (random.uniform(-0.06,0.06), random.uniform(-0.06,0.06), random.uniform(0.0,0.05)), vein, root, seed=seed+k)
        out(f"items/{name}.glb")
    for name, col in (("iron_ingot", (0.4,0.4,0.42,1)), ("copper_ingot", (0.75,0.42,0.25,1))):
        reset(); clear_mats(); root = empty(name, (0,0,0))
        m = pbr(name, color=col, rough=0.35, metal=1.0)
        me = bpy.data.meshes.new("ingot"); bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=0.09, radius2=0.065, depth=0.05)
        bm.to_mesh(me); bm.free()
        ob = link(bpy.data.objects.new("ingot", me)); ob.rotation_euler = (0,0,math.pi/4); ob.scale = (1.6,0.7,1)
        me.materials.append(m); ob.parent = root
        out(f"items/{name}.glb")
    reset(); clear_mats(); root = empty("Nails", (0,0,0))
    random.seed(3)
    for k in range(9):
        c = cyl(f"n{k}", 0.003, 0.07, (random.uniform(-0.03,0.03), random.uniform(-0.03,0.03), 0.02), "X", "steel", root, verts=6)
        c.rotation_euler = (0, 0, random.uniform(0, 3.14))
    out("items/nails.glb")
    reset(); clear_mats(); root = empty("Bandage", (0,0,0))
    cyl("roll", 0.04, 0.07, (0,0,0), "Z", pbr("cloth", color=(0.9,0.88,0.82,1), rough=0.95), root, verts=16)
    out("items/bandage.glb")
    reset(); clear_mats(); root = empty("Leather", (0,0,0))
    box("hide", (0.35, 0.28, 0.01), (0,0,0), pbr("leather", color=(0.45,0.3,0.18,1), rough=0.8), root, bevel=0.004)
    out("items/leather.glb")
    for name, col in (("steam_kit", (0.22,0.35,0.2,1)), ("electric_kit", (0.85,0.6,0.15,1)), ("rail_kit", (0.35,0.33,0.3,1))):
        reset(); clear_mats(); root = empty(name, (0,0,0))
        box("crate", (0.5, 0.35, 0.3), (0,0,0.15), "planks", root, bevel=0.01)
        box("band", (0.52, 0.06, 0.32), (0,0,0.15), pbr(name+"_band", color=col, rough=0.5, metal=0.3), root, bevel=0.005)
        out(f"items/{name}.glb")

# ---------------- stations ----------------
def campfire():
    reset(); clear_mats(); random.seed(2)
    root = empty("Campfire", (0,0,0))
    for k in range(9):
        a = k/9*math.tau
        rock_blob(f"stone{k}", 0.09, (math.cos(a)*0.42, math.sin(a)*0.42, 0.04), stone_mat(), root, seed=k+30)
    for k in range(5):
        a = k/5*math.tau
        c = cyl(f"log{k}", 0.035, 0.55, (math.cos(a)*0.12, math.sin(a)*0.12, 0.18), "Z", bark_mat(), root, verts=8)
        c.rotation_euler = (math.sin(a)*0.8, -math.cos(a)*0.8, 0)
    cyl("ash", 0.3, 0.02, (0,0,0.01), "Z", pbr("ash", color=(0.08,0.07,0.06,1), rough=1.0), root, verts=16)
    for x in (-0.5, 0.5):
        cyl(f"post{x}", 0.018, 0.75, (x,0,0.37), "Z", "wood", root, verts=8)
    cyl("spit", 0.012, 1.05, (0,0,0.72), "X", "wood", root, verts=8)
    empty("M_Fire", (0,0,0.2), root); empty("M_Cook", (0,0,0.72), root)
    out("props/campfire.glb", "campfire.png", target=(0,0,0.3), dist=2.2, elev=0.5, az=0.6)

def workbench():
    reset(); clear_mats()
    root = empty("Workbench", (0,0,0))
    box("top", (1.6, 0.75, 0.08), (0,0,0.86), "planks", root, bevel=0.01)
    for x in (-0.7, 0.7):
        for y in (-0.3, 0.3):
            box(f"leg{x}{y}", (0.09, 0.09, 0.82), (x, y, 0.41), "wood", root)
    box("shelf", (1.45, 0.6, 0.04), (0,0,0.25), "planks", root)
    box("vise", (0.16, 0.12, 0.12), (0.62, -0.32, 0.96), "iron", root)
    cyl("saw", 0.004, 0.5, (-0.3, 0.1, 0.91), "X", "steel", root, verts=6)
    box("sawblade", (0.45, 0.1, 0.004), (-0.3, 0.16, 0.905), "steel", root, bevel=0)
    empty("M_Use", (0, -0.4, 1.0), root)
    out("props/workbench.glb", "workbench.png", target=(0,0,0.7), dist=3, elev=0.4, az=0.9)

def furnace():
    reset(); clear_mats(); random.seed(4)
    root = empty("Furnace", (0,0,0))
    for ring in range(6):
        z = 0.12 + ring*0.2
        r = 0.55 - ring*0.05
        n = 12 - ring
        for k in range(n):
            a = k/n*math.tau + ring*0.2
            if ring < 2 and abs(math.sin(a) + 1.0) < 0.35:
                continue
            rock_blob(f"s{ring}_{k}", 0.13, (math.cos(a)*r, math.sin(a)*r, z), stone_mat(), root, seed=ring*20+k, squash=0.75)
    cyl("chimney", 0.14, 0.5, (0,0,1.45), "Z", "iron", root, verts=12)
    anim(box("FurnaceGlow", (0.28, 0.02, 0.2), (0, -0.5, 0.22), "FireGlow", root, bevel=0))
    empty("M_Use", (0, -0.65, 0.4), root); empty("M_Smoke", (0,0,1.75), root)
    out("props/furnace.glb", "furnace.png", target=(0,0,0.7), dist=3.2, elev=0.3, az=-1.2)

def chest():
    reset(); clear_mats()
    root = empty("Chest", (0,0,0))
    box("body", (0.9, 0.55, 0.5), (0,0,0.25), "planks", root, bevel=0.01)
    for x in (-0.44, 0.44):
        box(f"band{x}", (0.03, 0.57, 0.52), (x*0.9,0,0.25), "iron", root, bevel=0.004)
    lid = anim(box("Lid", (0.92, 0.57, 0.12), (0,0,0.56), "planks", root, pivot=(0, 0.28, 0.5), bevel=0.01))
    box("latch", (0.08, 0.03, 0.1), (0, -0.29, 0.48), "iron", root, bevel=0.004)
    empty("M_Use", (0, -0.3, 0.6), root)
    out("props/chest.glb")

def bed():
    reset(); clear_mats()
    root = empty("Bed", (0,0,0))
    box("frame", (0.95, 2.0, 0.25), (0,0,0.2), "planks", root, bevel=0.01)
    box("mattress", (0.85, 1.85, 0.14), (0,0,0.38), pbr("straw", color=(0.62,0.5,0.3,1), rough=1.0), root, bevel=0.04)
    box("blanket", (0.88, 1.2, 0.06), (0,-0.3,0.47), pbr("wool", color=(0.35,0.12,0.1,1), rough=1.0), root, bevel=0.03)
    box("pillow", (0.6, 0.35, 0.1), (0,0.72,0.5), pbr("linen", color=(0.8,0.76,0.66,1), rough=1.0), root, bevel=0.04)
    empty("M_Use", (0.5, 0, 0.5), root)
    out("props/bed.glb")

stone_axe(); stone_pickaxe(); stone_knife(); hammer(); spear(); bow(); arrow(); items(); campfire(); workbench(); furnace(); chest(); bed()
print("crafting ok")
