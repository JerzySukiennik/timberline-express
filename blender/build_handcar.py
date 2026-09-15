# Pump handcar + flatcar. Blender +Y = vehicle front (Godot -Z). Rail top at z=0, track center x=0.
import sys, os; sys.path.insert(0, os.path.dirname(__file__))
from vkit import *
os.makedirs(MODELS + "vehicles", exist_ok=True)

def handcar():
    reset(); clear_mats()
    root = empty("Handcar", (0,0,0))
    body = box("Body", (0.16, 2.7, 0.2), (0.62, 0, 0.52), "wood", root)
    box("frameL", (0.16, 2.7, 0.2), (-0.62, 0, 0.52), "wood", body)
    for y in (-1.25, -0.4, 0.4, 1.25):
        box(f"cross{y}", (1.4, 0.14, 0.12), (0, y, 0.62), "wood", body)
    # deck boards along Y
    n = 10; W = 1.8
    for i in range(n):
        x = -W/2 + (i+0.5)*W/n
        box(f"board{i}", (W/n-0.012, 2.5, 0.05), (x, 0, 0.705), "planks", body, bevel=0.006)
    # end beams
    for y in (-1.36, 1.36):
        box(f"endbeam{y}", (1.9, 0.12, 0.22), (0, y, 0.6), "wood", body)
        box(f"coupler{y}", (0.12, 0.25, 0.1), (0, y*1.07, 0.55), "iron", body)
    # axle pedestals + axles
    for y in (-0.75, 0.75):
        for x in (-0.62, 0.62):
            box(f"ped{x}{y}", (0.18, 0.26, 0.18), (x, y, 0.34), "iron", body, bevel=0.01)
        cyl(f"axle{y}", 0.045, 1.5, (0, y, 0.3), "X", "iron", body, verts=12)
    # pump tower: two A-frames
    for x in (-0.22, 0.22):
        for y in (-0.28, 0.28):
            p0 = V((x, y, 0.73)); p1 = V((x*0.9, 0, 1.72))
            d = p1 - p0; L = d.length
            post = box(f"post{x}{y}", (0.08, 0.08, L), (p0+p1)/2, "wood", body)
            post.rotation_mode = "QUATERNION"; post.rotation_quaternion = d.to_track_quat("Z","Y")
        box(f"towercap{x}", (0.1, 0.18, 0.12), (x*0.9, 0, 1.72), "iron", body)
    cyl("pivotshaft", 0.03, 0.62, (0, 0, 1.72), "X", "steel", body, verts=12)
    # crank shaft under deck
    for x in (-0.62, 0.62):
        box(f"crankbrg{x}", (0.14, 0.2, 0.14), (x*0.98, 0.0, 0.42), "iron", body)
    cyl("crankshaft", 0.04, 1.3, (0, 0.0, 0.42), "X", "steel", body, verts=12)
    # brake shoes (static)
    for y in (-0.75, 0.75):
        for x in (-0.72, 0.72):
            box(f"shoe{x}{y}", (0.08, 0.1, 0.3), (x, y + (0.34 if y > 0 else -0.34), 0.3), "iron", body, bevel=0.01)
    # animated parts --------------------------------------------------------
    beam = anim(box("PumpBeam", (0.1, 2.1, 0.12), (0, 0, 1.72), "wood", root, bevel=0.015))
    for y in (-1.05, 1.05):
        cyl(f"handle{y}", 0.028, 1.05, (0, y, 1.72), "X", "wood", beam, verts=12)
        cyl(f"handlecap{y}a", 0.035, 0.06, (0.52, y, 1.72), "X", "iron", beam, verts=12)
        cyl(f"handlecap{y}b", 0.035, 0.06, (-0.52, y, 1.72), "X", "iron", beam, verts=12)
    box("beamstrap", (0.14, 0.4, 0.16), (0, 0, 1.72), "iron", beam)
    join_children(beam)
    rod = anim(cyl("PumpRod", 0.025, 1.0, (0, 0.30, 1.22), "Z", "steel", root, verts=10, pivot=(0, 0.30, 1.72)))
    crank = anim(cyl("Crank", 0.16, 0.05, (0.0, 0.0, 0.42), "X", "black", root, verts=24))
    box("crankarm", (0.06, 0.06, 0.2), (0.0, 0.0, 0.5), "iron", crank)
    join_children(crank)
    wheels = []
    for (nm, x, y) in (("Wheel_FL",-0.72,0.75),("Wheel_FR",0.72,0.75),("Wheel_RL",-0.72,-0.75),("Wheel_RR",0.72,-0.75)):
        w = anim(spoked_wheel(nm, (x, y, 0.3), 0.3, width=0.1, spokes=8, parent=root))
        join_children(w); wheels.append(w)
    lever = anim(box("BrakeLever", (0.06, 0.06, 0.95), (0.8, -1.15, 1.15), "wood", root, pivot=(0.8, -1.15, 0.7)))
    box("brakegrip", (0.08, 0.08, 0.14), (0.8, -1.15, 1.6), "iron", lever)
    box("brakequad", (0.12, 0.3, 0.06), (0.8, -1.15, 0.74), "iron", body)
    join_children(lever)
    dirl = anim(box("DirLever", (0.04, 0.04, 0.45), (0.45, 0.35, 0.95), "iron", root, pivot=(0.45, 0.35, 0.74)))
    cyl("dirknob", 0.035, 0.05, (0.45, 0.35, 1.18), "Z", "black", dirl, verts=12)
    box("dirquad", (0.1, 0.24, 0.05), (0.45, 0.35, 0.74), "iron", body)
    join_children(dirl)
    join_children(body)
    for nm, p in (("M_PumpHandleF",(0,1.05,1.72)),("M_PumpHandleR",(0,-1.05,1.72)),("M_BrakeGrip",(0.8,-1.15,1.6)),
                  ("M_DirKnob",(0.45,0.35,1.18)),("M_CouplerF",(0,1.45,0.55)),("M_CouplerR",(0,-1.45,0.55)),("M_CrankPin",(0,0.30,0.42))):
        empty(nm, p, root)
    objs = [o for o in bpy.context.scene.objects]
    export_glb(MODELS + "vehicles/handcar.glb", objs)
    preview(PREV + "handcar.png", target=(0,0,0.9), dist=5.5, elev=0.35, az=0.8)

def flatcar():
    reset(); clear_mats()
    root = empty("Flatcar", (0,0,0))
    body = box("Body", (0.2, 6.0, 0.28), (0.7, 0, 0.62), "wood", root)
    box("sillL", (0.2, 6.0, 0.28), (-0.7, 0, 0.62), "wood", body)
    box("sillOL", (0.14, 6.0, 0.24), (-1.43, 0, 0.66), "wood", body)
    box("sillOR", (0.14, 6.0, 0.24), (1.43, 0, 0.66), "wood", body)
    for y in [-2.9 + i*0.58 for i in range(11)]:
        box(f"cross{y}", (3.0, 0.14, 0.14), (0, y, 0.74), "wood", body)
    n = 16
    for i in range(n):
        x = -1.5 + (i+0.5)*3.0/n
        box(f"board{i}", (3.0/n-0.014, 6.0, 0.055), (x, 0, 0.84), "planks", body, bevel=0.006)
    for y in (-3.05, 3.05):
        box(f"end{y}", (3.0, 0.14, 0.3), (0, y, 0.7), "wood", body)
        box(f"coupler{y}", (0.12, 0.3, 0.1), (0, y*1.04, 0.58), "iron", body)
    for y in [-2.6, -1.3, 0.0, 1.3, 2.6]:
        for x in (-1.52, 1.52):
            box(f"stake{x}{y}", (0.06, 0.12, 0.18), (x, y, 0.72), "iron", body, bevel=0.008)
    for y in (-2.2, 2.2):
        box(f"bogie{y}", (1.7, 1.2, 0.18), (0, y, 0.42), "iron", body)
        for x in (-0.62, 0.62):
            box(f"ped{x}{y}", (0.2, 1.1, 0.26), (x*1.02, y, 0.36), "iron", body)
    wheels = []
    for y in (-2.6, -1.8, 1.8, 2.6):
        for x in (-0.72, 0.72):
            nm = f"Wheel_{'F' if y>0 else 'R'}{'L' if x<0 else 'R'}{abs(int(y*10))}"
            w = anim(spoked_wheel(nm, (x, y, 0.3), 0.3, width=0.1, spokes=8, parent=root)); join_children(w)
    join_children(body)
    for nm, p in (("M_CouplerF",(0,3.2,0.58)),("M_CouplerR",(0,-3.2,0.58))): empty(nm, p, root)
    export_glb(MODELS + "vehicles/flatcar.glb", list(bpy.context.scene.objects))
    preview(PREV + "flatcar.png", target=(0,0,0.6), dist=8, elev=0.4, az=0.8)

handcar(); flatcar()
print("handcar ok")
