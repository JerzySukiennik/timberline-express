# Small 0-4-0 steam locomotive + tender. Blender +Y = front. Rail top z=0.
import sys, os; sys.path.insert(0, os.path.dirname(__file__))
from vkit import *

def loco():
    reset(); clear_mats()
    root = empty("SteamLoco", (0,0,0))
    body = box("Body", (0.1, 5.6, 0.55), (0.52, 0.15, 0.78), "black", root)
    box("frameL", (0.1, 5.6, 0.55), (-0.52, 0.15, 0.78), "black", body)
    for y in (2.95, -2.65):
        box(f"bufbeam{y}", (2.2, 0.22, 0.42), (0, y, 0.92), "red", body)
        for x in (-0.75, 0.75):
            cyl(f"bufstock{x}{y}", 0.07, 0.3, (x, y+(0.2 if y>0 else -0.2), 0.95), "Y", "black", body, verts=14)
            cyl(f"bufhead{x}{y}", 0.17, 0.05, (x, y+(0.36 if y>0 else -0.36), 0.95), "Y", "steel", body, verts=20)
        box(f"coupler{y}", (0.14, 0.3, 0.12), (0, y+(0.25 if y>0 else -0.25), 0.9), "iron", body)
    # running boards / valances
    for x in (-0.98, 0.98):
        box(f"runboard{x}", (0.42, 3.6, 0.04), (x, 0.9, 1.12), "plate", body)
        box(f"valance{x}", (0.03, 3.6, 0.16), (x*1.2, 0.9, 1.04), "green", body)
    # cylinders
    for x in (-0.98, 0.98):
        cyl(f"cyl{x}", 0.26, 0.85, (x, 2.3, 0.85), "Y", "green", body, verts=24)
        cyl(f"cylcapf{x}", 0.28, 0.06, (x, 2.75, 0.85), "Y", "black", body, verts=24)
        cyl(f"cylcapb{x}", 0.28, 0.06, (x, 1.85, 0.85), "Y", "black", body, verts=24)
        box(f"slidebar{x}", (0.04, 1.1, 0.05), (x, 1.3, 0.97), "steel", body)
    # boiler
    cyl("boiler", 0.64, 3.3, (0, 0.75, 1.78), "Y", "green", body, verts=40)
    for y in (-0.6, 0.4, 1.4, 2.3):
        cyl(f"band{y}", 0.655, 0.05, (0, y, 1.78), "Y", "brass", body, verts=40)
    cyl("smokebox", 0.67, 0.6, (0, 2.7, 1.78), "Y", "black", body, verts=40)
    cyl("smokedoor", 0.6, 0.08, (0, 3.02, 1.78), "Y", "black", body, verts=40, r2=0.52)
    cyl("doorhandle", 0.04, 0.12, (0, 3.08, 1.78), "Y", "brass", body, verts=10)
    box("saddle", (0.9, 0.7, 0.5), (0, 2.6, 1.2), "black", body)
    cyl("chimney", 0.16, 0.75, (0, 2.7, 2.72), "Z", "black", body, verts=24, r2=0.2)
    cyl("chimneylip", 0.24, 0.08, (0, 2.7, 3.1), "Z", "black", body, verts=24)
    cyl("dome", 0.28, 0.45, (0, 1.0, 2.5), "Z", "brass", body, verts=28, r2=0.22)
    cyl("domecap", 0.22, 0.12, (0, 1.0, 2.76), "Z", "brass", body, verts=28, r2=0.05)
    cyl("safetyvalve", 0.08, 0.3, (0, -0.35, 2.55), "Z", "brass", body, verts=14)
    cyl("sandbox", 0.18, 0.35, (0, 0.2, 2.5), "Z", "green", body, verts=20)
    box("headlamp", (0.28, 0.25, 0.3), (0, 3.05, 2.6), "black", body)
    anim(box("Headlight", (0.2, 0.02, 0.2), (0, 3.18, 2.6), "Headlight", root, bevel=0))
    # firebox + cab
    box("firebox", (1.3, 0.9, 1.2), (0, -1.3, 1.6), "green", body)
    box("cabfloor", (2.2, 1.9, 0.08), (0, -2.0, 1.12), "planks", body)
    box("cabfront", (2.2, 0.08, 1.95), (0, -1.0, 2.12), "green", body)  # spectacle plate (windows as dark insets)
    for x in (-0.6, 0.6):
        cyl(f"window{x}", 0.2, 0.1, (x, -0.98, 2.35), "Y", "glass", body, verts=20)
    for x in (-1.08, 1.08):
        box(f"cabside{x}", (0.06, 1.9, 1.0), (x, -2.0, 1.66), "green", body)
        box(f"cabsidepost{x}", (0.06, 0.1, 1.95), (x, -2.9, 2.12), "green", body)
        box(f"cabsidefront{x}", (0.06, 0.4, 1.95), (x, -1.2, 2.12), "green", body)
        box(f"handrail{x}", (0.03, 0.03, 0.9), (x*1.05, -2.95, 1.6), "brass", body)
    box("cabroof", (2.4, 2.2, 0.07), (0, -1.95, 3.12), "black", body)
    box("tenderdeck", (2.1, 3.3, 0.08), (0, 0, -9), "plate", body) if False else None
    # backhead (inside cab, rear face of firebox)
    box("backhead", (1.3, 0.05, 1.5), (0, -1.08, 1.9), "black", body)
    box("fireholerim", (0.52, 0.06, 0.4), (0, -1.12, 1.5), "iron", body)
    anim(box("FireGlow", (0.4, 0.02, 0.3), (0, -1.09, 1.5), "FireGlow", root, bevel=0))
    door = anim(box("FireboxDoor", (0.44, 0.04, 0.34), (0, -1.16, 1.5), "iron", root, pivot=(-0.22, -1.16, 1.5)))
    box("doorgrip", (0.06, 0.06, 0.08), (0.16, -1.2, 1.5), "brass", door); join_children(door)
    box("coalshelf", (2.0, 0.6, 0.3), (0, -2.75, 1.3), "black", body)  # front of tender meets here
    # gauges
    cyl("gaugeP", 0.1, 0.05, (0.35, -1.12, 2.35), "Y", "brass", body, verts=24)
    anim(cyl("GaugeFace", 0.085, 0.01, (0.35, -1.15, 2.35), "Y", "gauge_face", root, verts=24))
    anim(box("NeedlePressure", (0.008, 0.005, 0.07), (0.35, -1.16, 2.38), "needle", root, pivot=(0.35, -1.16, 2.35), bevel=0))
    cyl("sightglass", 0.02, 0.35, (-0.35, -1.12, 2.2), "Z", "glass", body, verts=10)
    anim(cyl("WaterLevel", 0.016, 0.33, (-0.35, -1.13, 2.2), "Z", "WaterLevel", root, verts=10, pivot=(-0.35, -1.13, 2.035)))
    # controls
    reg = anim(box("Regulator", (0.5, 0.04, 0.04), (0.22, -1.16, 2.1), "brass", root, pivot=(0, -1.16, 2.1)))
    box("reggrip", (0.05, 0.1, 0.05), (0.46, -1.2, 2.1), "wood", reg); join_children(reg)
    rev = anim(box("Reverser", (0.05, 0.05, 0.9), (0.8, -1.7, 1.6), "iron", root, pivot=(0.8, -1.7, 1.16)))
    box("revgrip", (0.07, 0.07, 0.14), (0.8, -1.7, 2.05), "wood", rev); join_children(rev)
    box("revquad", (0.08, 0.5, 0.1), (0.8, -1.7, 1.2), "iron", body)
    brk = anim(box("BrakeHandle", (0.05, 0.05, 0.6), (-0.8, -1.6, 1.5), "iron", root, pivot=(-0.8, -1.6, 1.2)))
    box("brkgrip", (0.07, 0.07, 0.12), (-0.8, -1.6, 1.8), "wood", brk); join_children(brk)
    box("brkstand", (0.12, 0.12, 0.1), (-0.8, -1.6, 1.2), "iron", body)
    cyl("whistle", 0.05, 0.25, (0.3, -1.0, 3.28), "Z", "brass", body, verts=14)
    wp = anim(cyl("WhistlePull", 0.012, 0.6, (0.3, -1.25, 2.5), "Z", "rope", root, verts=8, pivot=(0.3, -1.25, 2.8)))
    cyl("whistleknob", 0.03, 0.06, (0.3, -1.25, 2.2), "Z", "wood", wp, verts=10); join_children(wp)
    # wheels + rods
    for (y, tag) in ((0.95, "F"), (-0.55, "R")):
        for x in (-0.72, 0.72):
            w = anim(spoked_wheel(f"Wheel_{tag}{'L' if x<0 else 'R'}", (x, y, 0.55), 0.55, width=0.13, spokes=12, parent=root, m="black", counterweight=True))
            join_children(w)
            cyl(f"axle{tag}{x}", 0.07, 0.3, (x*0.7, y, 0.55), "X", "iron", body, verts=12)
    for x in (-1.0, 1.0):
        rod = anim(box(f"CouplingRod_{'L' if x<0 else 'R'}", (0.05, 1.6, 0.09), (x*0.86, 0.2, 0.55), "steel", root, bevel=0.015))
        cyl(f"rodboss{x}a", 0.07, 0.07, (x*0.86, 0.95, 0.55), "X", "steel", rod, verts=14)
        cyl(f"rodboss{x}b", 0.07, 0.07, (x*0.86, -0.55, 0.55), "X", "steel", rod, verts=14)
        join_children(rod)
        pr = anim(box(f"PistonRod_{'L' if x<0 else 'R'}", (0.05, 1.3, 0.05), (x*0.98, 1.3, 0.85), "steel", root, bevel=0.01))
        box(f"crosshead{x}", (0.1, 0.2, 0.12), (x*0.98, 0.7, 0.9), "steel", pr); join_children(pr)
    join_children(body)
    for nm, p in (("M_CouplerF",(0,3.3,0.9)),("M_CouplerR",(0,-3.0,0.9)),("M_FireDoor",(0,-1.25,1.5)),("M_Regulator",(0.46,-1.22,2.1)),
                  ("M_Reverser",(0.8,-1.7,2.05)),("M_Brake",(-0.8,-1.6,1.8)),("M_Whistle",(0.3,-1.25,2.2)),("M_Smoke",(0,2.7,3.15)),
                  ("M_SafetyValve",(0,-0.35,2.75)),("M_Cab",(0,-2.0,1.16))):
        empty(nm, p, root)
    export_glb(MODELS + "vehicles/steam_loco.glb", list(bpy.context.scene.objects))
    preview(PREV + "steam.png", target=(0,0.2,1.5), dist=9, elev=0.25, az=0.9)
    preview(PREV + "steam_cab.png", target=(0,-1.1,1.9), dist=2.2, elev=0.1, az=-1.57)

def tender():
    reset(); clear_mats()
    root = empty("Tender", (0,0,0))
    body = box("Body", (0.12, 3.4, 0.4), (0.55, 0, 0.8), "black", root)
    box("frameL", (0.12, 3.4, 0.4), (-0.55, 0, 0.8), "black", body)
    box("deck", (2.1, 3.3, 0.08), (0, 0, 1.04), "plate", body)
    box("tank", (2.0, 1.9, 1.1), (0, -0.65, 1.63), "green", body)
    box("tanklip", (2.06, 1.96, 0.05), (0, -0.65, 2.2), "black", body)
    box("bunkerL", (0.06, 1.3, 0.8), (-0.97, 0.95, 1.48), "green", body)
    box("bunkerR", (0.06, 1.3, 0.8), (0.97, 0.95, 1.48), "green", body)
    box("bunkerF", (2.0, 0.06, 0.45), (0, 1.58, 1.3), "green", body)
    box("bunkerslope", (1.9, 1.2, 0.06), (0, 0.95, 1.2), "black", body, rot=(math.radians(-12),0,0))
    box("coalpile", (1.8, 1.0, 0.25), (0, 0.8, 1.4), "black", body)
    cyl("hatchring", 0.28, 0.06, (0.4, -0.9, 2.22), "Z", "black", body, verts=24)
    lid = anim(cyl("WaterHatch", 0.3, 0.04, (0.4, -0.9, 2.26), "Z", "iron", root, verts=24, pivot=(0.1, -0.9, 2.26)))
    for y in (1.75, -1.75):
        box(f"bufbeam{y}", (2.2, 0.2, 0.38), (0, y, 0.9), "red", body)
        box(f"coupler{y}", (0.14, 0.3, 0.12), (0, y*1.08, 0.9), "iron", body)
    for (y, tag) in ((0.9, "F"), (-0.9, "R")):
        for x in (-0.72, 0.72):
            w = anim(spoked_wheel(f"Wheel_{tag}{'L' if x<0 else 'R'}", (x, y, 0.4), 0.4, width=0.11, spokes=10, parent=root)); join_children(w)
        box(f"axlebox{tag}", (2.0, 0.3, 0.25), (0, y, 0.55), "black", body)
    for x in (-1.0, 1.0):
        box(f"ladder{x}", (0.04, 0.04, 1.1), (x, -1.8, 1.6), "iron", body)
    join_children(body)
    for nm, p in (("M_CouplerF",(0,1.95,0.9)),("M_CouplerR",(0,-1.95,0.9)),("M_WaterHatch",(0.4,-0.9,2.3)),("M_Bunker",(0,0.95,1.5))):
        empty(nm, p, root)
    export_glb(MODELS + "vehicles/tender.glb", list(bpy.context.scene.objects))
    preview(PREV + "tender.png", target=(0,0,1.2), dist=6, elev=0.35, az=0.8)

loco(); tender()
print("steam ok")
