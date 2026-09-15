# Bakes fir branch-spray cards (albedo+alpha) from Poly Haven fir_tree_01 twig atlas.
import bpy, math, random, os
ROOT = "/Users/jurek/Downloads/Claude/Projects/Timberline Express"
TW = ROOT + "/Niepotrzebne/ph/trees/"
OUT = ROOT + "/game/assets/textures/trees/"
os.makedirs(OUT, exist_ok=True)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

# sprite rects in 256-grid (x0,y0,x1,y1 from top), stem at bottom-center
SPR = {"S": (14,0,40,255), "A": (80,104,162,198), "B": (163,118,242,211), "C": (168,12,238,93), "D": (49,14,105,79), "F": (127,67,159,101)}

def twig_mat():
    m = bpy.data.materials.new("twig")
    m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    tc = nt.nodes.new("ShaderNodeTexImage"); tc.image = bpy.data.images.load(TW + "fir_tree_01_twig_diff_2k.jpg")
    ta = nt.nodes.new("ShaderNodeTexImage"); ta.image = bpy.data.images.load(TW + "fir_tree_01_twig_alpha_2k.png")
    ta.image.colorspace_settings.name = "Non-Color"
    uv = nt.nodes.new("ShaderNodeUVMap")
    nt.links.new(uv.outputs[0], tc.inputs[0]); nt.links.new(uv.outputs[0], ta.inputs[0])
    nt.links.new(tc.outputs[0], em.inputs[0])
    nt.links.new(ta.outputs[0], mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1]); nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], o.inputs[0])
    m.surface_render_method = "BLENDED"
    return m

def sprite_quad(key, pos, ang, length, z, mat):
    x0,y0,x1,y1 = SPR[key]
    w = (x1-x0)/(y1-y0) * length
    import bmesh
    me = bpy.data.meshes.new("q"); bm = bmesh.new()
    # local: stem at origin, grows along +Y
    vs = [bm.verts.new(v) for v in ((-w/2,0,0),(w/2,0,0),(w/2,length,0),(-w/2,length,0))]
    f = bm.faces.new(vs)
    uvl = bm.loops.layers.uv.new("UVMap")
    u0,u1 = x0/256, x1/256; v0,v1 = 1-y1/256, 1-y0/256
    for lp,(u,v) in zip(f.loops, ((u0,v0),(u1,v0),(u1,v1),(u0,v1))): lp[uvl].uv = (u,v)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new("q", me); bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    ob.location = (pos[0], pos[1], z); ob.rotation_euler = (0,0,ang)
    return ob

def setup_render(w, h, ortho, cam_loc):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
    sc.eevee.taa_render_samples = 32
    cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"; cd.ortho_scale = ortho
    cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
    cam.location = cam_loc; cam.rotation_euler = (0,0,0)

def bake(name, builder, w, h, ortho, cam_loc):
    reset(); mat = twig_mat(); random.seed(hash(name) & 0xffff)
    builder(mat)
    setup_render(w, h, ortho, cam_loc)
    bpy.context.scene.render.filepath = OUT + name + ".png"
    bpy.ops.render.render(write_still=True)

def spray(mat):
    # branch along +X from 0 to 2.0 (card 2x1 world units), side twigs
    L = 2.0; n = 22; z = 0.0
    for i in range(n):
        t = i/(n-1); x = 0.05 + t*(L-0.35)
        s = 0.5*(1-t*0.5) * random.uniform(0.85,1.05)
        for side in (-1,1):
            ang = -math.pi/2 + side*math.radians(random.uniform(40,58))  # point along +x, outward
            key = random.choice("AB")
            z += 0.001
            sprite_quad(key, (x, side*0.02), ang, s, z, mat)
    # central stem
    sprite_quad("S", (0.0, 0.0), -math.pi/2, L-0.3, -0.01, mat).scale = (0.18, 1, 1)
    # tip sprays pointing forward
    for k in range(3):
        z += 0.001
        sprite_quad(random.choice("AB"), (L-0.45+k*0.05, random.uniform(-0.03,0.03)), -math.pi/2+random.uniform(-0.3,0.3), 0.5, z, mat)

def tip(mat):
    # upright crown tip: card 1 wide, 2 tall, stem along +Y
    z = 0.0
    for i in range(14):
        t = i/13; y = t*1.6
        s = 0.55*(1-t*0.6)
        for side in (-1,1):
            ang = side*math.radians(random.uniform(40,65))
            z += 0.001
            sprite_quad(random.choice("AB"), (side*0.01, y), ang, s, z, mat)
    z += 0.001; sprite_quad("A", (0,1.5), 0, 0.5, z, mat)

def pine_mat():
    m = bpy.data.materials.new("pine_twig")
    m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial"); em = nt.nodes.new("ShaderNodeEmission"); tr = nt.nodes.new("ShaderNodeBsdfTransparent"); mix = nt.nodes.new("ShaderNodeMixShader")
    tc = nt.nodes.new("ShaderNodeTexImage"); tc.image = bpy.data.images.load(TW + "pine_tree_01_twig_diff_2k.jpg")
    ta = nt.nodes.new("ShaderNodeTexImage"); ta.image = bpy.data.images.load(TW + "pine_tree_01_twig_alpha_2k.png"); ta.image.colorspace_settings.name = "Non-Color"
    uv = nt.nodes.new("ShaderNodeUVMap")
    nt.links.new(uv.outputs[0], tc.inputs[0]); nt.links.new(uv.outputs[0], ta.inputs[0])
    nt.links.new(tc.outputs[0], em.inputs[0]); nt.links.new(ta.outputs[0], mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1]); nt.links.new(em.outputs[0], mix.inputs[2]); nt.links.new(mix.outputs[0], o.inputs[0])
    m.surface_render_method = "BLENDED"
    return m

def pine_tuft(_mat):
    m = pine_mat()
    SPR["P1"] = (9,12,54,112); SPR["P2"] = (167,88,238,132)
    z = 0.0
    for i in range(46):
        a = random.uniform(0, math.tau)
        L = random.uniform(0.55, 0.95)
        z += 0.001
        sprite_quad("P1", (math.cos(a)*0.04, math.sin(a)*0.04), a - math.pi/2, L, z, m)

bake("pine_tuft_card", pine_tuft, 1024, 1024, 2.0, (0.0, 0.0, 5.0))
bake("fir_branch_card", spray, 1024, 512, 2.0, (1.0, 0.0, 5.0))
bake("fir_tip_card", tip, 512, 1024, 2.0, (0.0, 1.0, 5.0))
print("baked")
