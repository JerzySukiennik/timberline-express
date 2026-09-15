# Renders side-view albedo+alpha sprites of each fir variant for distant crossed-quad impostors.
import sys, os; sys.path.insert(0, os.path.dirname(__file__))
from common import *
import mathutils
OUT = ROOT + "/game/assets/textures/trees/"
for v in ("fir_a", "fir_b", "fir_c"):
    reset()
    bpy.ops.import_scene.gltf(filepath=MODELS + f"trees/{v}.glb")
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    # emission-only so the sprite carries pure albedo; alpha from the card textures
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            if not m or not m.use_nodes: continue
            nt = m.node_tree; b = nt.nodes.get("Principled BSDF")
            if not b: continue
            col = b.inputs["Base Color"]; alpha = b.inputs["Alpha"]
            em = nt.nodes.new("ShaderNodeEmission"); tr = nt.nodes.new("ShaderNodeBsdfTransparent"); mix = nt.nodes.new("ShaderNodeMixShader")
            if col.links: nt.links.new(col.links[0].from_socket, em.inputs[0])
            else: em.inputs[0].default_value = col.default_value
            if alpha.links: nt.links.new(alpha.links[0].from_socket, mix.inputs[0])
            else: mix.inputs[0].default_value = 1.0
            nt.links.new(tr.outputs[0], mix.inputs[1]); nt.links.new(em.outputs[0], mix.inputs[2])
            out = nt.nodes.get("Material Output"); nt.links.new(mix.outputs[0], out.inputs[0])
            m.surface_render_method = "BLENDED"
    mn = mathutils.Vector((1e9,1e9,1e9)); mx = -mn
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(c); mn = mathutils.Vector(map(min, mn, w)); mx = mathutils.Vector(map(max, mx, w))
    h = mx.z - mn.z; wdt = max(mx.x - mn.x, mx.y - mn.y)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"; sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x = 512; sc.render.resolution_y = 1024
    sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
    cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"; cd.ortho_scale = max(h, wdt * 2.0) * 1.02
    cam = link(bpy.data.objects.new("c", cd)); sc.camera = cam
    cam.location = ((mn.x+mx.x)/2, mn.y - 50, mn.z + cd.ortho_scale/2)
    cam.rotation_euler = (math.pi/2, 0, 0)
    sc.render.filepath = OUT + f"{v}_impostor.png"
    bpy.ops.render.render(write_still=True)
    print(v, "height", round(h,2), "ortho", round(cd.ortho_scale,2))
