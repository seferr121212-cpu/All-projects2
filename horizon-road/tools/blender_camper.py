"""Camper cabin furnishing seen through the windows / open sliding door.
Van local space: x +-1.0, floor at Godot y 0.6, front at Godot z -2.4 (Blender +Y).
Run: python tools/blender_camper.py <out_dir>"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from blender_models import reset, paint, ico, cone, branch, export
from blender_structures import box, paint_fn, finish


def B(size, gz, gy, col, x=0.0, **kw):
    """Box using Godot-style (x, y up, z back) centre coordinates."""
    return box(size, (x, -gz, gy), col, **kw)


def cabin():
    reset(); obs = []
    wood = (0.62, 0.45, 0.3); cream = (0.92, 0.88, 0.78); orange = (0.88, 0.5, 0.22); dark = (0.15, 0.15, 0.16)
    obs.append(B((1.9, 4.5, 0.06), 0.0, 0.6, (0.45, 0.33, 0.24), cuts=8))  # floor planks
    paint_fn(obs[-1], lambda c, n: (0.48, 0.35, 0.25) if int((c.x + 1) / 0.16) % 2 else (0.42, 0.31, 0.22))
    obs.append(B((1.2, 1.0, 0.02), 0.5, 0.635, (0.7, 0.2, 0.18), cuts=4))  # rug
    paint_fn(obs[-1], lambda c, n: [(0.72, 0.2, 0.17), (0.92, 0.72, 0.3), (0.2, 0.3, 0.5)][int(abs(c.x) / 0.15 + abs(c.y + 0.5) / 0.15) % 3])
    # Cab: dashboard, wheel, two seats.
    obs.append(B((1.85, 0.45, 0.4), -2.1, 1.35, dark, bevel=0.05))
    w = branch((-0.45, 1.75, 1.5), (-0.45, 1.85, 1.62), 0.17, 0.17, 16); paint(w, (0.1, 0.1, 0.1)); obs.append(w)
    for x in (-0.45, 0.45):
        obs.append(B((0.55, 0.5, 0.15), -1.35, 1.0, orange, x=x, bevel=0.05))
        obs.append(B((0.55, 0.12, 0.7), -1.05, 1.4, orange, x=x, bevel=0.05))
    # Dinette: bench facing forward, table.
    obs.append(B((1.2, 0.5, 0.42), 0.1, 0.85, orange, x=-0.35, bevel=0.05))
    obs.append(B((1.2, 0.12, 0.55), 0.35, 1.3, orange, x=-0.35, bevel=0.05))
    obs.append(B((0.8, 0.6, 0.05), -0.5, 1.3, wood, x=-0.45, bevel=0.01))
    obs.append(B((0.06, 0.06, 0.7), -0.5, 0.95, (0.6, 0.6, 0.62), x=-0.45))
    mug = cone(0.04, 0.04, 0.09, 10, loc=(-0.3, 0.45, 1.33)); paint(mug, (0.9, 0.3, 0.2)); obs.append(mug)
    # Kitchenette on the left wall: counter, sink, stove, upper cupboards.
    obs.append(B((0.5, 1.3, 0.85), 1.05, 1.03, cream, x=-0.72, bevel=0.02))
    obs.append(B((0.52, 1.32, 0.04), 1.05, 1.47, wood, x=-0.72))
    obs.append(B((0.3, 0.35, 0.03), 0.8, 1.49, (0.7, 0.72, 0.75), x=-0.72))
    for dz in (1.2, 1.45):
        obs.append(B((0.16, 0.16, 0.02), dz, 1.5, dark, x=-0.72))
    obs.append(B((0.4, 1.3, 0.38), 1.05, 2.15, wood, x=-0.78, bevel=0.02))
    kettle = ico(0.08, 2, loc=(-0.72, -1.2, 1.57), scale=(1, 1, 0.9)); paint(kettle, (0.85, 0.2, 0.15)); obs.append(kettle)
    # Rear bed with blanket and pillows.
    obs.append(B((1.85, 0.9, 0.45), 2.0, 0.85, wood))
    obs.append(B((1.8, 0.88, 0.16), 2.0, 1.15, (0.3, 0.45, 0.6), cuts=4))
    paint_fn(obs[-1], lambda c, n: (0.3, 0.45, 0.62) if int((c.x + 1) / 0.2) % 2 else (0.9, 0.85, 0.75))
    for x in (-0.45, 0.45):
        p = ico(1.0, 2, loc=(x, -2.25, 1.3), scale=(0.3, 0.14, 0.08)); paint(p, (0.95, 0.93, 0.9)); obs.append(p)
    # Lamp, plant, photos on the wall.
    l = ico(0.08, 2, loc=(0.0, 0.2, 2.35)); paint(l, (1.0, 0.85, 0.55)); obs.append(l)
    pot = cone(0.08, 0.1, 0.14, 10, loc=(-0.72, -0.5, 1.49)); paint(pot, (0.7, 0.38, 0.24)); obs.append(pot)
    lf = ico(0.13, 2, loc=(-0.72, -0.5, 1.72)); paint(lf, (0.25, 0.5, 0.2), 0.15); obs.append(lf)
    for i, c in enumerate(((0.9, 0.7, 0.4), (0.4, 0.6, 0.8), (0.8, 0.4, 0.4))):
        obs.append(B((0.02, 0.18, 0.13), 1.5 + i * 0.22, 1.85, c, x=0.96))
    finish("camper_cabin", obs, None)


def tube_arc(cx, cy, cz, r, a0, a1, th, col, n=14, axis_x=True):
    """Arc of a round bar around the X axis (wheel arch), centre (cx, cy, cz) in Blender coords."""
    import math
    obs = []
    pts = [(cx, cy + math.cos(math.radians(a0 + (a1 - a0) * i / n)) * r, cz + math.sin(math.radians(a0 + (a1 - a0) * i / n)) * r) for i in range(n + 1)]
    for p0, p1 in zip(pts, pts[1:]):
        b = branch(p0, p1, th, th, 6); paint(b, col); obs.append(b)
    return obs


def wheel():
    """Tyre with tread blocks and sidewall lettering ring, steel rim, chrome hubcap with bolts. Axis X, radius 0.42."""
    import math
    reset(); obs = []
    from blender_structures import lathe
    # Tyre profile around the X axis: build along Z then rotate.
    tyre = lathe([(0.27, -0.16), (0.36, -0.17), (0.41, -0.15), (0.43, -0.10), (0.43, 0.10), (0.41, 0.15), (0.36, 0.17), (0.27, 0.16)], 40, "tyre")
    paint(tyre, (0.09, 0.09, 0.1)); obs.append(tyre)
    for i in range(24):  # tread blocks
        a = i / 24 * math.tau
        blk = box((0.05, 0.2, 0.05), (0.0, 0.0, 0.0), (0.06, 0.06, 0.065))
        blk.location = (math.cos(a) * 0.435, math.sin(a) * 0.435, 0)
        blk.rotation_euler = (0, 0, a)
        obs.append(blk)
    rim = lathe([(0.0, 0.17), (0.26, 0.17), (0.27, 0.12), (0.22, 0.10), (0.0, 0.10)], 28, "rim")
    paint(rim, (0.8, 0.8, 0.78)); obs.append(rim)
    rim2 = lathe([(0.0, -0.17), (0.26, -0.17), (0.27, -0.12), (0.22, -0.10), (0.0, -0.10)], 28, "rim2")
    paint(rim2, (0.55, 0.55, 0.55)); obs.append(rim2)
    cap = lathe([(0.0, 0.215), (0.1, 0.2), (0.17, 0.17), (0.0, 0.17)], 20, "hubcap")
    paint(cap, (0.95, 0.95, 0.93)); obs.append(cap)
    for i in range(5):
        a = i / 5 * math.tau
        bolt = ico(0.022, 1, loc=(math.cos(a) * 0.12, math.sin(a) * 0.12, 0.2), name="bolt"); paint(bolt, (0.4, 0.4, 0.42)); obs.append(bolt)
    import bpy
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    whole = bpy.context.view_layer.objects.active
    whole.rotation_euler = (0, math.radians(90), 0)  # axis Z -> X
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obs = [whole]
    export("camper_wheel", obs)


def extras():
    """Parts laid over the van body: arch flares, running boards, grille, awning, ladder, jerry can."""
    import math
    reset(); obs = []
    chrome = (0.82, 0.83, 0.85); black = (0.1, 0.1, 0.11); cream = (0.94, 0.89, 0.78); teal = (0.2, 0.5, 0.5)
    for side in (-1, 1):
        x = side * 1.0
        for gz in (-1.45, 1.5):  # Godot z of the wheel centres
            obs += tube_arc(x, -gz, 0.45, 0.55, -5, 185, 0.035, black)
            obs += tube_arc(x + side * 0.01, -gz, 0.45, 0.6, 0, 180, 0.02, chrome, n=10)
        # Running board and mud strip under the sill.
        obs.append(B((0.3, 2.0, 0.05), -0.25, 0.5, black, x=side * 1.07, bevel=0.01))
        obs.append(B((0.04, 2.0, 0.03), -0.25, 0.54, chrome, x=side * 1.2))
        # Window trim chrome strip along the belt line.
        obs.append(B((0.02, 4.0, 0.03), 0.0, 1.43, chrome, x=side * 1.005))
    # Front grille slats and rear engine louvres.
    for i in range(6):
        obs.append(B((0.55, 0.02, 0.025), -2.43, 0.78 + i * 0.05, chrome, x=0.0))
    for i in range(7):
        obs.append(B((0.5, 0.02, 0.02), 2.43, 0.72 + i * 0.045, black, x=0.0))
    # Rear ladder to the roof rack.
    for x in (-0.82, -0.62):
        obs.append(B((0.04, 0.05, 2.0), 2.48, 1.6, chrome, x=x))
    for i in range(8):
        obs.append(B((0.24, 0.04, 0.03), 2.47, 0.65 + i * 0.25, chrome, x=-0.72))
    # Rolled side awning (right side, above the sliding door) with striped canvas end.
    roll = branch((1.1, 0.9, 2.38), (1.1, -0.6, 2.38), 0.09, 0.09, 12)
    paint(roll, (0.95, 0.35, 0.2)); obs.append(roll)
    for z0 in (-0.5, 0.3):
        arm = branch((1.0, -z0, 2.3), (1.12, -z0, 2.38), 0.02, 0.02, 4); paint(arm, chrome); obs.append(arm)
    # Jerry can and a folding chair strapped to the rear-left.
    obs.append(B((0.18, 0.34, 0.5), 2.5, 1.05, (0.25, 0.4, 0.2), x=0.62, bevel=0.02))
    obs.append(B((0.14, 0.04, 0.12), 2.52, 1.33, black, x=0.62))
    chair = B((0.5, 0.05, 0.6), 2.46, 1.65, (0.8, 0.25, 0.2), x=0.1); obs.append(chair)
    obs.append(B((0.5, 0.05, 0.05), 2.46, 1.35, black, x=0.1))
    # Headlight glass domes and tail-light lenses.
    for side in (-1, 1):
        gl = ico(0.15, 2, loc=(side * 0.68, 2.4, 1.05), scale=(1, 0.45, 1), name="glass"); paint(gl, (0.95, 0.93, 0.8)); obs.append(gl)
        tl = ico(0.1, 2, loc=(side * 0.8, -2.42, 1.05), scale=(0.8, 0.4, 1.6), name="tail"); paint(tl, (0.85, 0.1, 0.08)); obs.append(tl)
    finish("camper_extras", obs, None)


if __name__ == "__main__":
    cabin()
    wheel()
    extras()
