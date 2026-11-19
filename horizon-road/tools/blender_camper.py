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


if __name__ == "__main__":
    cabin()
