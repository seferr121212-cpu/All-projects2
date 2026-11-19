"""Rigged quadrupeds (cow, sheep, cat, dog) with idle / walk / graze actions.
Animals face +Y (Godot -Z). Run: python tools/blender_animals.py <out_dir>"""
import sys, os, math, random
import bpy
from mathutils import Vector, Matrix, noise
sys.path.insert(0, os.path.dirname(__file__))
from blender_models import paint, ico, cone, branch, OUT
from blender_structures import paint_fn, lathe
from blender_characters import Body, weigh, pose

LEGS = ("fl", "fr", "bl", "br")


def bones_for(L, H, leg_h, neck_up):
    """L body length, H shoulder height. Returns {bone: (head, tail, parent)}."""
    y0, y1 = -L * 0.38, L * 0.38
    b = {"body": ((0, y0, H), (0, 0, H), None), "chest": ((0, 0, H), (0, y1, H), "body"),
         "neck": ((0, y1, H), (0, y1 + L * 0.12, H + neck_up), "chest"),
         "head": ((0, y1 + L * 0.12, H + neck_up), (0, y1 + L * 0.3, H + neck_up), "neck"),
         "tail": ((0, y0, H), (0, y0 - L * 0.2, H - 0.1), "body")}
    for leg in LEGS:
        x = 0.4 * (1 if leg[1] == "l" else -1)
        y = y1 * 0.85 if leg[0] == "f" else y0 * 0.85
        par = "chest" if leg[0] == "f" else "body"
        b["up_" + leg] = ((x, y, H - 0.05), (x, y, leg_h), par)
        b["lo_" + leg] = ((x, y, leg_h), (x, y, 0.02), "up_" + leg)
    return b


def make_rig(spec, scale):
    ad = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", ad)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    for name, (h, t, p) in spec.items():
        e = ad.edit_bones.new(name)
        e.head = Vector(h) * 1; e.tail = Vector(t)
        e.head.x *= scale; e.tail.x *= scale
    for name, (h, t, p) in spec.items():
        if p:
            ad.edit_bones[name].parent = ad.edit_bones[p]
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


def walk(arm, f, p, amp=20):
    s = math.sin(2 * math.pi * p); c = math.cos(2 * math.pi * p)
    r = {}
    for leg in LEGS:
        ph = 1 if leg in ("fl", "br") else -1  # diagonal gait
        r["up_" + leg] = [('X', amp * s * ph)]
        r["lo_" + leg] = [('X', (-22 if leg[0] == "f" else 18) * max(0.0, c * ph))]
    r["head"] = [('X', 3 * c)]
    r["tail"] = [('Z', 12 * s)]
    pose(arm, f, r, hips_dz=0.0)


def idle(arm, f, p):
    s = math.sin(2 * math.pi * p)
    pose(arm, f, {"head": [('Z', 14 * math.sin(2 * math.pi * p + 0.7)), ('X', 3 * s)], "tail": [('Z', 20 * math.sin(4 * math.pi * p))], "chest": [('X', 0.8 * s)]})


def graze(arm, f, p):
    e = min(1.0, 4 * p, 4 * (1 - p))
    chew = math.sin(10 * math.pi * p)
    pose(arm, f, {"neck": [('X', -55 * e)], "head": [('X', (-15 + 4 * chew) * e)], "tail": [('Z', 15 * math.sin(4 * math.pi * p))],
                  "up_fl": [('X', 6 * e)], "up_fr": [('X', 6 * e)]})


def export_rig(name, b, spec, scale=1.0):
    arm = make_rig(spec, scale)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in b.obs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = b.obs[0]
    bpy.ops.object.join()
    body = b.obs[0]; body.name = name; body.parent = arm
    body.modifiers.new("Armature", 'ARMATURE').object = arm
    arm.animation_data_create()
    for an, fn, frames, step in (("idle", idle, 90, 5), ("walk", walk, 30, 2), ("work", graze, 120, 4)):
        act = bpy.data.actions.new(an); act.use_fake_user = True
        arm.animation_data.action = act
        for f in range(0, frames + 1, step):
            fn(arm, f, f / frames)
        tr = arm.animation_data.nla_tracks.new(); tr.name = an; tr.strips.new(an, 0, act)
        arm.animation_data.action = None
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True); body.select_set(True)
    path = os.path.join(OUT, name + "_rig.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_vertex_color='ACTIVE',
                              export_all_vertex_colors=False, export_materials='NONE', export_apply=False, export_yup=True,
                              export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True)
    print("exported", path)


def scaled(spec, k):
    return {n: (tuple(v * k for v in h), tuple(v * k for v in t), p) for n, (h, t, p) in spec.items()}


def quad(name, k, L, H, leg_h, neck_up, coat, belly, legc, hoof, fn_coat=None, wool=False, ears=None, horns=False,
         snout=None, tailc=None, head_r=0.22, xs=1.0):
    spec = scaled(bones_for(L, H, leg_h, neck_up), k)
    for n in spec:
        h, t, p = spec[n]
        spec[n] = ((h[0] * xs, h[1], h[2]), (t[0] * xs, t[1], t[2]), p)
    B = Body()
    S = lambda v: tuple(x * k for x in v)
    Hk, Lk = H * k, L * k
    # Torso: elliptic barrel split between body (rear) and chest (front).
    tor = ico(1.0, 3, loc=(0, 0, Hk - 0.02 * k), scale=(0.5 * k * xs, Lk * 0.47, 0.4 * k), name="torso")
    for v in tor.data.vertices:
        if wool:
            v.co += v.normal * (0.05 + 0.04 * noise.noise(v.co * 9 / k)) * k
    if fn_coat:
        paint_fn(tor, fn_coat)
    else:
        paint_fn(tor, lambda c, n: belly if n.z < -0.5 else coat)
    B.add(tor, lambda co: {"body": 1 - min(1, max(0, (co.y + 0.1 * k) / (0.3 * k))), "chest": min(1, max(0, (co.y + 0.1 * k) / (0.3 * k)))})
    for leg in LEGS:
        h = spec["up_" + leg][0]; m = spec["up_" + leg][1]; t = spec["lo_" + leg][1]
        upc = coat if not wool else legc
        B.limb(h, m, 0.15 * k * xs, 0.09 * k * xs, upc if leg_h > 0 else legc, "up_" + leg)
        B.limb(m, t, 0.085 * k * xs, 0.07 * k * xs, legc, "lo_" + leg)
        hf = cone(0.08 * k * xs, 0.075 * k * xs, 0.07 * k, 8, loc=(t[0], t[1], 0), name="hoof"); paint(hf, hoof); B.add(hf, "lo_" + leg)
    nh, nt = spec["neck"][0], spec["neck"][1]
    B.limb(nh, nt, 0.24 * k * xs, 0.18 * k * xs, coat, "neck")
    hh, ht = Vector(spec["head"][0]), Vector(spec["head"][1])
    hd = ico(1.0, 2, loc=(hh + ht) / 2, scale=(head_r * k * xs * 0.75, (ht - hh).length * 0.6, head_r * k * 0.8), name="head")
    paint(hd, coat if not wool else legc); B.add(hd, "head")
    if snout:
        sn = ico(1.0, 2, loc=ht - Vector((0, 0.02 * k, 0.04 * k)), scale=(head_r * 0.55 * k * xs, head_r * 0.5 * k, head_r * 0.45 * k), name="snout")
        paint(sn, snout); B.add(sn, "head")
    for side in (-1, 1):
        e = ico(0.025 * k, 1, loc=((hh + ht) / 2) + Vector((side * head_r * 0.62 * k * xs, 0.05 * k, 0.06 * k)), name="eye")
        paint(e, (0.06, 0.05, 0.05)); B.add(e, "head")
        if ears:
            ear = ico(1.0, 1, loc=hh + Vector((side * head_r * 0.9 * k * xs, 0, head_r * 0.6 * k)),
                      scale=tuple(q * k for q in ears[0]), name="ear")
            paint(ear, ears[1]); B.add(ear, "head")
        if horns:
            hn = branch(hh + Vector((side * 0.1 * k, 0.04 * k, 0.12 * k)), hh + Vector((side * 0.24 * k, 0.1 * k, 0.26 * k)), 0.035 * k, 0.005, 6)
            paint(hn, (0.9, 0.86, 0.75)); B.add(hn, "head")
    th, tt = spec["tail"][0], spec["tail"][1]
    tl = branch(th, tt, 0.03 * k, 0.02 * k, 6); paint(tl, tailc or coat); B.add(tl, "tail")
    tip = ico(0.05 * k, 1, loc=tt, name="tip"); paint(tip, tailc or coat); B.add(tip, "tail")
    return B, spec


def cow(i, coat):
    spots = random.Random(i)
    pts = [Vector((spots.uniform(-0.4, 0.4), spots.uniform(-0.8, 0.8), spots.uniform(1.0, 1.4))) for _ in range(6)]
    fn = (lambda c, n: (0.95, 0.94, 0.9) if min((c - p).length for p in pts) < 0.22 else coat) if i == 2 else None
    B, spec = quad(f"cow_{i}", 1.0, 1.8, 1.2, 0.62, 0.12, coat, tuple(x * 0.9 for x in coat), tuple(x * 0.7 for x in coat),
                   (0.15, 0.12, 0.1), fn_coat=fn, ears=((0.12, 0.05, 0.06), coat), horns=True, snout=(0.85, 0.7, 0.65),
                   tailc=tuple(x * 0.6 for x in coat), head_r=0.3, xs=0.8)
    udder = ico(0.13, 2, loc=(0, -0.5, 0.82), scale=(1, 1, 0.7), name="udder"); paint(udder, (0.9, 0.7, 0.68)); B.add(udder, "body")
    bell = cone(0.06, 0.04, 0.09, 8, loc=(0, spec["neck"][0][1] + 0.12, spec["neck"][0][2] - 0.25), name="bell"); paint(bell, (0.8, 0.65, 0.3)); B.add(bell, "neck")
    export_rig(f"cow_{i}", B, spec)


def sheep():
    B, spec = quad("sheep", 0.55, 1.6, 1.25, 0.6, 0.1, (0.92, 0.89, 0.82), (0.88, 0.85, 0.78), (0.2, 0.18, 0.17), (0.1, 0.1, 0.1),
                   wool=True, ears=((0.14, 0.05, 0.05), (0.2, 0.18, 0.17)), snout=(0.15, 0.13, 0.12), head_r=0.3, xs=0.95)
    export_rig("sheep", B, spec)


def cat(i, fur):
    stripe = (lambda c, n: tuple(x * 0.75 for x in fur) if int(c.y / 0.035) % 2 else fur) if i == 1 else None
    B, spec = quad(f"cat_{i}", 0.27, 1.6, 1.0, 0.5, 0.45, fur, (0.95, 0.93, 0.9) if i != 3 else fur, fur, fur, fn_coat=stripe,
                   ears=((0.09, 0.03, 0.12), fur), snout=(0.95, 0.92, 0.88) if i != 3 else fur, tailc=fur, head_r=0.4, xs=0.5)
    export_rig(f"cat_{i}", B, spec)


def dog(i, fur):
    B, spec = quad(f"dog_{i}", 0.5, 1.6, 1.15, 0.55, 0.4, fur, (0.9, 0.85, 0.75), fur, (0.15, 0.12, 0.1),
                   ears=((0.05, 0.03, 0.1), tuple(x * 0.7 for x in fur)), snout=tuple(x * 0.8 for x in fur), tailc=fur, head_r=0.4, xs=0.6)
    export_rig(f"dog_{i}", B, spec)


if __name__ == "__main__":
    cow(1, (0.45, 0.3, 0.2)); cow(2, (0.2, 0.17, 0.15)); cow(3, (0.62, 0.48, 0.34))
    sheep()
    cat(1, (0.9, 0.55, 0.25)); cat(2, (0.55, 0.55, 0.55)); cat(3, (0.15, 0.15, 0.15))
    dog(1, (0.85, 0.75, 0.55)); dog(2, (0.35, 0.28, 0.22))
