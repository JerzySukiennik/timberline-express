# Small center-cab industrial electric locomotive: battery hood front, generator hood rear. Blender +Y = front.
import sys, os; sys.path.insert(0, os.path.dirname(__file__))
from vkit import *

def electric():
    reset(); clear_mats()
    root = empty("ElectricLoco", (0,0,0))
    body = box("Body", (2.2, 7.0, 0.35), (0, 0, 1.0), "black", root)
    box("deck", (2.5, 7.2, 0.06), (0, 0, 1.2), "plate", body)
    for y in (3.62, -3.62):
        box(f"bufbeam{y}", (2.5, 0.2, 0.45), (0, y, 0.98), "yellow", body)
        for i in range(5):  # hazard stripes
            box(f"stripe{y}{i}", (0.18, 0.02, 0.5), (-1.0+i*0.5, y+(0.11 if y>0 else -0.11), 0.98), "black", body, rot=(0, math.radians(35), 0), bevel=0)
        box(f"coupler{y}", (0.14, 0.3, 0.12), (0, y+(0.25 if y>0 else -0.25), 0.9), "iron", body)
        for x in (-0.8, 0.8):
            cyl(f"buf{x}{y}", 0.15, 0.25, (x, y+(0.2 if y>0 else -0.2), 1.0), "Y", "steel", body, verts=18)
    # railings along walkways
    for x in (-1.2, 1.2):
        for y in (-3.4, -2.2, -1.2, 1.2, 2.2, 3.4):
            cyl(f"stanchion{x}{y}", 0.02, 0.95, (x, y, 1.7), "Z", "yellow", body, verts=8)
        for ya, yb in ((-3.4, -1.2), (1.2, 3.4)):
            cyl(f"rail{x}{ya}", 0.02, yb-ya, (x, (ya+yb)/2, 2.15), "Y", "yellow", body, verts=8)
            cyl(f"railmid{x}{ya}", 0.016, yb-ya, (x, (ya+yb)/2, 1.7), "Y", "yellow", body, verts=8)
    # cab
    box("cabL", (0.08, 2.0, 2.0), (-1.05, 0, 2.23), "yellow", body)
    box("cabR", (0.08, 2.0, 0.8), (1.05, 0, 1.63), "yellow", body)
    box("cabRtop", (0.08, 2.0, 0.35), (1.05, 0, 3.05), "yellow", body)
    box("cabRpost", (0.08, 0.3, 2.0), (1.05, 0.85, 2.23), "yellow", body)
    for y in (1.0, -1.0):
        box(f"cabwall{y}", (2.18, 0.08, 0.9), (0, y, 1.68), "yellow", body)
        box(f"cabwalltop{y}", (2.18, 0.08, 0.35), (0, y, 3.05), "yellow", body)
        for x in (-0.95, 0.0, 0.95):
            box(f"cabmullion{y}{x}", (0.14, 0.08, 0.75), (x, y, 2.5), "yellow", body)
        for x in (-0.48, 0.48):
            box(f"glass{y}{x}", (0.78, 0.02, 0.72), (x, y, 2.5), "glass", body, bevel=0)
    box("cabroof", (2.5, 2.4, 0.1), (0, 0, 3.28), "cream", body)
    box("cabfloor", (2.1, 1.9, 0.05), (0, 0, 1.25), "planks", body)
    # hoods
    box("batthood", (1.5, 2.2, 1.1), (0, 2.15, 1.78), "yellow", body)
    box("batthoodtop", (1.56, 2.26, 0.06), (0, 2.15, 2.36), "black", body)
    for i in range(6):
        box(f"louver{i}", (0.02, 0.28, 0.04), (0.76, 1.4+i*0.3, 1.9), "black", body, bevel=0)
        box(f"louverL{i}", (0.02, 0.28, 0.04), (-0.76, 1.4+i*0.3, 1.9), "black", body, bevel=0)
    box("genhood", (1.5, 2.2, 0.7), (0, -2.15, 1.58), "yellow", body)
    box("genhoodroof", (1.56, 2.26, 0.05), (0, -2.15, 1.96), "black", body)
    # generator unit sits exposed on the rear walkway, right side
    box("genbase", (0.9, 1.0, 0.1), (0.0, -3.0, 2.02), "black", body)
    gen = box("genblock", (0.7, 0.75, 0.55), (0.0, -3.0, 2.35), "red", body)
    for i in range(7):
        box(f"fin{i}", (0.74, 0.02, 0.45), (0.0, -3.3+i*0.1, 2.35), "black", body, bevel=0)
    cyl("genmuffler", 0.07, 0.5, (0.3, -2.6, 2.7), "Z", "iron", body, verts=12)
    cyl("fuelneck", 0.06, 0.12, (-0.25, -2.75, 2.66), "Z", "steel", body, verts=12)
    anim(cyl("FuelCap", 0.075, 0.04, (-0.25, -2.75, 2.74), "Z", "black", root, verts=14))
    box("genpanel", (0.04, 0.35, 0.3), (0.38, -2.8, 2.35), "black", body)
    anim(cyl("GenButton", 0.04, 0.03, (0.41, -2.8, 2.4), "X", "needle", root, verts=12))
    anim(cyl("GenLamp", 0.025, 0.02, (0.41, -2.72, 2.26), "X", "Headlight", root, verts=10))
    # battery boxes visible under hood side door
    for i in range(3):
        box(f"battery{i}", (0.35, 0.5, 0.3), (0.95, 1.55+i*0.55, 1.4), "black", body)
    # cable from generator to battery hood along walkway
    cyl("cable", 0.025, 5.4, (-0.85, -0.3, 1.26), "Y", "rubber", body, verts=8)
    # headlights
    for y, s in ((3.26, 1), (-3.26, -1)):
        box(f"lamphouse{y}", (0.3, 0.2, 0.3), (0, y, 2.55 if y>0 else 2.2), "black", body)
        anim(box(f"Headlight{'F' if y>0 else 'R'}", (0.22, 0.02, 0.22), (0, y+s*0.11, 2.55 if y>0 else 2.2), "Headlight", root, bevel=0))
    # controls (desk at front of cab, driver faces +Y)
    box("desk", (1.4, 0.5, 0.9), (0, 0.65, 1.7), "black", body, rot=(0,0,0))
    box("desktop", (1.4, 0.55, 0.05), (0, 0.62, 2.18), "plate", body, rot=(math.radians(-15),0,0))
    ctl = anim(box("Controller", (0.05, 0.05, 0.3), (0.3, 0.6, 2.36), "steel", root, pivot=(0.3, 0.6, 2.2)))
    cyl("ctlknob", 0.04, 0.08, (0.3, 0.6, 2.52), "Z", "black", ctl, verts=12); join_children(ctl)
    brk = anim(box("BrakeValve", (0.05, 0.25, 0.04), (-0.35, 0.72, 2.24), "steel", root, pivot=(-0.35, 0.6, 2.24)))
    cyl("brkknob", 0.035, 0.07, (-0.35, 0.84, 2.24), "Z", "red", brk, verts=12); join_children(brk)
    rev = anim(box("Reverser", (0.2, 0.04, 0.04), (0.0, 0.5, 2.26), "steel", root, pivot=(-0.08, 0.5, 2.26)))
    cyl("revknob", 0.03, 0.06, (0.1, 0.5, 2.26), "Z", "black", rev, verts=10); join_children(rev)
    anim(cyl("HornButton", 0.04, 0.03, (0.55, 0.78, 2.22), "Z", "needle", root, verts=12))
    for nm, x in (("Battery", -0.2), ("Amps", 0.2)):
        cyl(f"gauge{nm}", 0.1, 0.05, (x, 0.9, 2.5), "Y", "black", body, verts=24)
        anim(cyl(f"GaugeFace{nm}", 0.085, 0.01, (x, 0.87, 2.5), "Y", "gauge_face", root, verts=24))
        anim(box(f"Needle{nm}", (0.008, 0.005, 0.07), (x, 0.86, 2.53), "needle", root, pivot=(x, 0.86, 2.5), bevel=0))
    box("breakerpanel", (0.6, 0.06, 0.6), (-0.5, -0.95, 2.2), "black", body)
    brkr = anim(box("MainBreaker", (0.06, 0.3, 0.05), (-0.5, -0.8, 2.2), "steel", root, pivot=(-0.5, -0.92, 2.2)))
    box("brkrgrip", (0.25, 0.05, 0.06), (-0.5, -0.66, 2.2), "red", brkr); join_children(brkr)
    # bogies
    for (y, tag) in ((2.3, "F"), (-2.3, "R")):
        bog = anim(box(f"Bogie_{tag}", (2.0, 2.2, 0.35), (0, y, 0.62), "black", root, pivot=(0, y, 0.45)))
        for x in (-0.95, 0.95):
            box(f"sideframe{tag}{x}", (0.1, 2.4, 0.3), (x, y, 0.5), "yellow", bog)
            for yy in (y-0.7, y+0.7):
                box(f"axlebox{tag}{x}{yy}", (0.16, 0.3, 0.3), (x, yy, 0.45), "black", bog)
                box(f"spring{tag}{x}{yy}", (0.12, 0.25, 0.12), (x, yy, 0.68), "steel", bog)
        join_children(bog)
        for yy, n in ((y+0.7, "1"), (y-0.7, "2")):
            for x in (-0.72, 0.72):
                w = anim(spoked_wheel(f"Wheel_{tag}{n}{'L' if x<0 else 'R'}", (x, yy, 0.45), 0.45, width=0.12, spokes=0, parent=root, m="black"))
                cyl(f"disc{tag}{n}{x}", 0.4, 0.05, (x, yy, 0.45), "X", "black", w, verts=24)
                join_children(w)
    join_children(body)
    for nm, p in (("M_CouplerF",(0,4.0,0.9)),("M_CouplerR",(0,-4.0,0.9)),("M_Controller",(0.3,0.6,2.52)),("M_BrakeValve",(-0.35,0.84,2.24)),
                  ("M_Reverser",(0.1,0.5,2.26)),("M_Horn",(0.55,0.78,2.22)),("M_Breaker",(-0.5,-0.66,2.2)),("M_FuelCap",(-0.25,-2.75,2.8)),
                  ("M_GenButton",(0.43,-2.8,2.4)),("M_Cab",(0,-0.2,1.28)),("M_Exhaust",(0.3,-2.6,2.98))):
        empty(nm, p, root)
    export_glb(MODELS + "vehicles/electric_loco.glb", list(bpy.context.scene.objects))
    preview(PREV + "electric.png", target=(0,0,1.7), dist=10, elev=0.25, az=0.8)
    preview(PREV + "electric_rear.png", target=(0,-2.5,1.9), dist=6, elev=0.35, az=-0.9)

electric()
print("electric ok")
