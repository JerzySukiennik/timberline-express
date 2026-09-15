# Shared helpers for Timberline Express asset scripts (run via Blender CLI in background).
import bpy, bmesh, math, os
ROOT = "/Users/jurek/Downloads/Claude/Projects/Timberline Express"
PH = ROOT + "/Niepotrzebne/ph/"
MODELS = ROOT + "/game/assets/models/"
PREV = ROOT + "/Niepotrzebne/previews/"
os.makedirs(MODELS, exist_ok=True); os.makedirs(PREV, exist_ok=True)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def link(ob, coll=None):
    (coll or bpy.context.scene.collection).objects.link(ob); return ob

def img(path, noncolor=False):
    im = bpy.data.images.load(path, check_existing=True)
    if noncolor: im.colorspace_settings.name = "Non-Color"
    return im

def pbr(name, diff=None, nor=None, arm=None, alpha=None, color=(0.8,0.8,0.8,1), rough=0.7, metal=0.0, clip=False, uv_scale=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = color
    b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
    if diff:
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = img(diff)
        nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
        if alpha == "diff":
            nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
    if alpha and alpha != "diff":
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = img(alpha, True)
        nt.links.new(t.outputs["Color"], b.inputs["Alpha"])
    if nor:
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = img(nor, True)
        n = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(t.outputs["Color"], n.inputs["Color"])
        nt.links.new(n.outputs["Normal"], b.inputs["Normal"])
    if arm:
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = img(arm, True)
        s = nt.nodes.new("ShaderNodeSeparateColor"); nt.links.new(t.outputs["Color"], s.inputs["Color"])
        nt.links.new(s.outputs["Green"], b.inputs["Roughness"]); nt.links.new(s.outputs["Blue"], b.inputs["Metallic"])
    if clip:
        m.blend_method = "CLIP" if hasattr(m, "blend_method") else None
        m.surface_render_method = "DITHERED"
    return m

def export_glb(path, objs=None, **kw):
    bpy.ops.object.select_all(action="DESELECT")
    for o in (objs or bpy.context.scene.objects): o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_image_format="JPEG", export_jpeg_quality=88, export_yup=True, **kw)

def preview(path, target=(0,0,1), dist=6.0, elev=0.25, az=0.6, res=(900,900), lens=50, hdri=None):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"; sc.render.resolution_x, sc.render.resolution_y = res
    sc.view_settings.view_transform = "AgX"; sc.eevee.taa_render_samples = 24
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    if hdri:
        e = w.node_tree.nodes.new("ShaderNodeTexEnvironment"); e.image = img(hdri)
        w.node_tree.links.new(e.outputs[0], bg.inputs[0])
    else:
        bg.inputs[0].default_value = (0.55,0.62,0.7,1)
    bg.inputs[1].default_value = 1.0
    sun = bpy.data.lights.new("sun","SUN"); sun.energy = 3.5; so = link(bpy.data.objects.new("sun", sun)); so.rotation_euler = (math.radians(50), 0, math.radians(35))
    cd = bpy.data.cameras.new("cam"); cd.lens = lens; cam = link(bpy.data.objects.new("cam", cd)); sc.camera = cam
    import mathutils
    t = mathutils.Vector(target)
    cam.location = t + mathutils.Vector((math.cos(az)*math.cos(elev), math.sin(az)*math.cos(elev), math.sin(elev))) * dist
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)
