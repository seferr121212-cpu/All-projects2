"""Rigged, animated characters for Horizon Road (bpy). Each exports
<name>_rig.glb with a skeleton and the actions idle / walk / work / talk.
Characters face +Y here (-Z in Godot). Parts are rigidly skinned to bones,
cloth that hangs over the legs (skirts, cloaks) blends hips -> thighs.
Run: python tools/blender_characters.py <out_dir>"""
import sys, os, math, random
import bpy, bmesh
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(__file__))
from blender_models import reset, paint, ico, cone, cube, branch, smooth_all, head, OUT, SKIN
from blender_structures import lathe, paint_fn, box

S = lambda c, k: tuple(min(1.0, x * k) for x in c)

# Joint positions (x is the character's left for positive x; mirrored for -x).
HIP_Z = 0.93
J = {
    "hips": ((0, 0, HIP_Z), (0, 0, 1.08)),
    "spine": ((0, 0, 1.08), (0, 0, 1.44)),
    "neck": ((0, 0, 1.44), (0, 0, 1.53)),
    "head": ((0, 0, 1.53), (0, 0, 1.85)),
    "upper_arm": ((0.205, 0, 1.40), (0.245, -0.01, 1.13)),
    "forearm": ((0.245, -0.01, 1.13), (0.255, 0.03, 0.89)),
    "hand": ((0.255, 0.03, 0.89), (0.258, 0.04, 0.8)),
    "thigh": ((0.095, 0, HIP_Z - 0.02), (0.1, 0.01, 0.5)),
    "shin": ((0.1, 0.01, 0.5), (0.1, -0.01, 0.09)),
    "foot": ((0.1, -0.01, 0.09), (0.1, 0.14, 0.03)),
}
PARENT = {"spine": "hips", "neck": "spine", "head": "neck", "upper_arm": "spine", "forearm": "upper_arm",
          "hand": "forearm", "thigh": "hips", "shin": "thigh", "foot": "shin"}
SIDED = {"upper_arm", "forearm", "hand", "thigh", "shin", "foot"}


def jp(name, side, end=0):
    p = J[name][end]
    return (p[0] * side, p[1], p[2])


def bone_name(name, side):
    return f"{name}.{'L' if side > 0 else 'R'}" if name in SIDED else name


def weigh(obs, bone):
    """bone: name, or fn(co) -> {bone: weight}."""
    for ob in obs:
        for v in ob.data.vertices:
            ws = bone(v.co) if callable(bone) else {bone: 1.0}
            for b, w in ws.items():
                if w <= 0:
                    continue
                g = ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b)
                g.add([v.index], w, 'REPLACE')


class Body:
    def __init__(self):
        reset()
        self.obs = []

    def add(self, ob, bone, smooth=True):
        smooth_all([ob], smooth)
        weigh([ob], bone)
        self.obs.append(ob)
        return ob

    def limb(self, p0, p1, r0, r1, col, bone, seg=12, cap=True):
        b = branch(p0, p1, r0, r1, seg, name="limb")
        paint(b, col)
        self.add(b, bone)
        if cap:
            j = ico(r1 * 1.02, 2, loc=p1, name="joint")
            paint(j, col)
            self.add(j, bone)

    def shell(self, prof, depth, col, bone, seg=20, fn=None, front_flat=0.0):
        """Elliptic lathe: prof [(r, z)], y radius = r * depth."""
        dense = []
        for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
            n = max(1, int(abs(z1 - z0) / 0.02))
            dense += [(r0 + (r1 - r0) * k / n, z0 + (z1 - z0) * k / n) for k in range(n)]
        dense.append(prof[-1])
        ob = lathe(dense, seg, "shell")
        for v in ob.data.vertices:
            v.co.y *= depth
            if front_flat and v.co.y > 0:
                v.co.y *= 1 - front_flat
        if fn:
            paint_fn(ob, fn)
        else:
            paint(ob, col)
        return self.add(ob, bone)


def torso_w(co):
    t = min(1, max(0, (co.z - 1.0) / 0.14))
    return {"hips": 1 - t, "spine": t}


def drape_w(strength):
    def f(co):
        t = min(1, max(0, (HIP_Z - co.z) / 0.8))
        s = min(1, abs(co.x) / 0.1)
        w = strength * t * s
        return {"hips": 1 - w, ("thigh.L" if co.x > 0 else "thigh.R"): w}
    return f


def base_body(b, skin, shirt, trousers, shoes, sleeve=None, woman=False, boots=False):
    sleeve = sleeve or shirt
    # Legs.
    for side in (-1, 1):
        if trousers:
            b.limb(jp("thigh", side), jp("thigh", side, 1), 0.078, 0.06, trousers, bone_name("thigh", side))
            b.limb(jp("shin", side), jp("shin", side, 1), 0.058, 0.046, trousers, bone_name("shin", side))
        if boots:
            bt = cone(0.062, 0.058, 0.32, 12, loc=(0.1 * side, -0.01, 0.06), name="boot")
            paint(bt, shoes); b.add(bt, bone_name("shin", side))
        sh = ico(1.0, 2, loc=(0.1 * side, 0.045, 0.045), scale=(0.058, 0.125, 0.048), name="shoe")
        for v in sh.data.vertices:
            v.co.z = max(v.co.z, 0.0)
        paint(sh, shoes); b.add(sh, bone_name("foot", side))
        sole = box((0.11, 0.25, 0.025), (0.1 * side, 0.045, 0.012), S(shoes, 0.6))
        b.add(sole, bone_name("foot", side), smooth=False)
    # Torso: waist in, chest out, rounded shoulders.
    if woman:
        prof = [(0.0, 0.86), (0.16, 0.87), (0.175, 0.95), (0.145, 1.05), (0.165, 1.2), (0.18, 1.3), (0.175, 1.39), (0.12, 1.45), (0.05, 1.47), (0, 1.475)]
    else:
        prof = [(0.0, 0.86), (0.165, 0.87), (0.178, 0.95), (0.165, 1.05), (0.185, 1.2), (0.205, 1.33), (0.195, 1.41), (0.12, 1.46), (0.05, 1.48), (0, 1.485)]
    b.shell(prof, 0.62, shirt, torso_w)
    for side in (-1, 1):
        dl = ico(1.0, 2, loc=(0.19 * side, 0, 1.385), scale=(0.07, 0.075, 0.065), name="deltoid")
        paint(dl, sleeve); b.add(dl, bone_name("upper_arm", side))
        b.limb(jp("upper_arm", side), jp("upper_arm", side, 1), 0.058, 0.05, sleeve, bone_name("upper_arm", side))
        b.limb(jp("forearm", side), jp("forearm", side, 1), 0.048, 0.04, sleeve, bone_name("forearm", side), cap=False)
        cuff = cone(0.046, 0.046, 0.04, 12, loc=(0.255 * side, 0.03, 0.89), name="cuff")
        paint(cuff, S(sleeve, 0.85)); b.add(cuff, bone_name("forearm", side))
        hd = ico(1.0, 2, loc=(0.258 * side, 0.035, 0.85), scale=(0.034, 0.02, 0.04), name="palm")
        paint(hd, skin); b.add(hd, bone_name("hand", side))
        for fi in range(4):  # four fingers, slightly curled
            fx = 0.258 * side + (fi - 1.5) * 0.0105 * side
            ln = (0.05, 0.058, 0.055, 0.042)[fi]
            f = branch((fx, 0.035, 0.835), (fx, 0.05, 0.835 - ln), 0.0075, 0.0055, 6, name="finger")
            paint(f, skin); b.add(f, bone_name("hand", side))
            tip = ico(0.0058, 1, loc=(fx, 0.05, 0.835 - ln), name="tip"); paint(tip, skin); b.add(tip, bone_name("hand", side))
        th = branch((0.245 * side, 0.045, 0.855), (0.232 * side, 0.075, 0.83), 0.009, 0.006, 6, name="thumb")
        paint(th, skin); b.add(th, bone_name("hand", side))
    nk = cone(0.055, 0.05, 0.12, 12, loc=(0, 0, 1.43), name="neck")
    paint(nk, skin); b.add(nk, "neck")


def add_head(b, skin, hair=None):
    mark = len(b.obs)
    tmp = []
    head(tmp, 1.665, skin, hair=hair)
    # Rounder cheeks, whites of the eyes and eyelids for a friendlier face.
    for x in (-1, 1):
        ck = ico(0.04, 2, loc=(0.075 * x, 0.1, 1.64), scale=(1, 0.7, 0.9), name="cheek")
        paint(ck, tuple(min(1, c * 1.06 + 0.03) for c in skin)); tmp.append(ck)
        wh = ico(0.034, 2, loc=(0.052 * x, 0.128, 1.683), scale=(1, 0.55, 0.8), name="eyewhite"); paint(wh, (0.97, 0.96, 0.93)); tmp.append(wh)
        lid = ico(0.036, 2, loc=(0.052 * x, 0.132, 1.706), scale=(1.05, 0.5, 0.32), name="lid"); paint(lid, tuple(c * 0.88 for c in skin)); tmp.append(lid)
    for ob in tmp:
        for v in ob.data.vertices:
            v.co = Vector((v.co.x * 0.93, v.co.y * 0.93, 1.665 + (v.co.z - 1.665) * 0.93))
        weigh([ob], "head")
        b.obs.append(ob)


# --- Characters ----------------------------------------------------------------

def villager_man():
    b = Body()
    shirt = (0.92, 0.9, 0.84); vest = (0.18, 0.2, 0.24); trousers = (0.3, 0.27, 0.24)
    base_body(b, SKIN_M, shirt, trousers, (0.2, 0.14, 0.1), sleeve=shirt)
    # Yelek: open-front vest over the shirt with pocket flaps and buttons.
    vp = [(0.183, 0.98), (0.172, 1.05), (0.19, 1.2), (0.21, 1.33), (0.2, 1.41), (0.13, 1.455)]
    b.shell(vp, 0.64, vest, torso_w, fn=lambda c, n: shirt if (abs(c.x) < 0.035 and c.y > 0) else vest)
    for side in (-1, 1):
        b.add(box((0.08, 0.02, 0.03), (0.1 * side, 0.125, 1.16), S(vest, 0.7)), "spine", smooth=False)
    for z in (1.12, 1.2, 1.28, 1.36):
        bt = ico(0.011, 1, loc=(0.0, 0.115 + (z - 1.12) * 0.05, z), name="btn"); paint(bt, (0.85, 0.82, 0.75)); b.add(bt, "spine")
    belt = cone(0.182, 0.182, 0.05, 20, loc=(0, 0, 0.93), name="belt")
    for v in belt.data.vertices:
        v.co.y *= 0.64
    paint(belt, (0.16, 0.11, 0.08)); b.add(belt, "hips")
    b.add(box((0.05, 0.02, 0.04), (0, 0.118, 0.955), (0.8, 0.7, 0.35)), "hips", smooth=False)
    add_head(b, SKIN_M)
    mo = cube((0.11, 0.03, 0.028), loc=(0, 0.128, 1.615), name="moustache", bevel=0.01); paint(mo, (0.22, 0.18, 0.15)); b.add(mo, "head")
    cap = (0.34, 0.3, 0.26)
    cp = ico(0.155, 3, loc=(0, -0.01, 1.765), scale=(1, 1.08, 0.42), name="kasket"); paint(cp, cap); b.add(cp, "head")
    pk = ico(1.0, 2, loc=(0, 0.13, 1.745), scale=(0.11, 0.07, 0.015), name="peak"); paint(pk, S(cap, 0.8)); b.add(pk, "head")
    rig_export("villager_man", b)


def shepherd():
    b = Body()
    shirt = (0.8, 0.76, 0.66); trousers = (0.25, 0.23, 0.2); felt = (0.42, 0.34, 0.24)
    base_body(b, SKIN_M, shirt, trousers, (0.2, 0.14, 0.1), sleeve=felt, boots=True)
    # Kepenek: stiff felt cloak, square shoulders, open at the front.
    kp = [(0.0, 1.47), (0.12, 1.47), (0.27, 1.41), (0.28, 1.3), (0.27, 1.0), (0.29, 0.7), (0.31, 0.5)]
    ob = lathe(kp, 24, "kepenek")
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y > 0.15 and abs(f.calc_center_median().x) < 0.11 and f.calc_center_median().z < 1.4], context='FACES')
    bm.to_mesh(ob.data); bm.free()
    for v in ob.data.vertices:
        v.co.y *= 0.72
    import blender_models as bmm
    bmm.mod(ob, 'SOLIDIFY', thickness=0.025)
    paint_fn(ob, lambda c, n: S(felt, 0.75) if c.z < 0.56 else felt)
    b.add(ob, lambda co: {**drape_w(0.35)(co), "spine": 1.0} if co.z > 1.05 else drape_w(0.35)(co))
    add_head(b, SKIN_M)
    bd = ico(0.12, 2, loc=(0, 0.06, 1.57), scale=(1, 0.8, 0.8), name="beard"); paint(bd, (0.62, 0.6, 0.58)); b.add(bd, "head")
    cp = ico(0.15, 3, loc=(0, 0, 1.76), scale=(1, 1, 0.55), name="cap"); paint(cp, (0.2, 0.18, 0.16)); b.add(cp, "head")
    # Crook (çoban değneği) in the right hand.
    st = branch((-0.26, 0.05, 0.02), (-0.26, 0.05, 1.5), 0.016, 0.014, 6); paint(st, (0.45, 0.32, 0.2)); b.add(st, "hand.R")
    hk = lathe([(0.07, 0), (0.07, 0.03)], 10, "hook")
    for v in hk.data.vertices:
        v.co = Vector((v.co.x - 0.26, 0.05 + v.co.z, 1.5 + max(v.co.y, 0)))
    paint(hk, (0.45, 0.32, 0.2)); b.add(hk, "hand.R")
    rig_export("shepherd", b)


def fisherman():
    b = Body()
    navy = (0.15, 0.22, 0.38)
    stripes = lambda c, n: (0.15, 0.3, 0.62) if int(c.z / 0.055) % 2 else (0.93, 0.93, 0.9)
    base_body(b, SKIN_M, (0.93, 0.93, 0.9), (0.28, 0.33, 0.45), (0.12, 0.12, 0.12), sleeve=(0.93, 0.93, 0.9), boots=True)
    # Repaint torso and sleeves with breton stripes.
    for ob in b.obs:
        if ob.name.startswith("shell") or ob.name.startswith("deltoid") or ob.name.startswith("limb") and ob.data.vertices[0].co.z > 1.0:
            paint_fn(ob, stripes)
    # Rolled trouser cuffs above the boots.
    for side in (-1, 1):
        rc = cone(0.064, 0.064, 0.06, 12, loc=(0.1 * side, -0.01, 0.36), name="roll"); paint(rc, (0.24, 0.29, 0.4)); b.add(rc, bone_name("shin", side))
    add_head(b, (0.74, 0.54, 0.4))
    bd = ico(0.13, 2, loc=(0, 0.05, 1.57), scale=(1, 0.8, 0.85), name="beard"); paint(bd, (0.88, 0.87, 0.85)); b.add(bd, "head")
    cp = ico(0.152, 3, loc=(0, 0, 1.76), scale=(1, 1, 0.5), name="cap"); paint(cp, navy); b.add(cp, "head")
    pk = ico(1.0, 2, loc=(0, 0.125, 1.745), scale=(0.1, 0.06, 0.012), name="peak"); paint(pk, (0.08, 0.08, 0.1)); b.add(pk, "head")
    rig_export("fisherman", b)


def villager_woman():
    b = Body()
    blouse = (0.94, 0.9, 0.84); vest = (0.55, 0.14, 0.16); skirt = (0.32, 0.2, 0.42); scarf = (0.96, 0.78, 0.26)
    base_body(b, SKIN, blouse, None, (0.22, 0.15, 0.1), sleeve=blouse, woman=True)
    # Şalvar ankles under the skirt.
    for side in (-1, 1):
        b.limb((0.09 * side, 0.0, 0.5), jp("shin", side, 1), 0.065, 0.05, (0.3, 0.2, 0.35), bone_name("shin", side))
        b.limb(jp("thigh", side), jp("thigh", side, 1), 0.075, 0.065, (0.3, 0.2, 0.35), bone_name("thigh", side), cap=False)
    # Long floral skirt, widening to mid-calf.
    fl = random.Random(5)
    flowers = [(fl.uniform(0, math.tau), fl.uniform(0.33, 0.95), fl.choice([(0.95, 0.75, 0.3), (0.9, 0.4, 0.45), (0.95, 0.93, 0.88)])) for _ in range(70)]

    def floral(c, n):
        a = math.atan2(c.y, c.x)
        for fa, fz, col in flowers:
            da = abs((a - fa + math.pi) % math.tau - math.pi) * 0.28
            if da * da + (c.z - fz) ** 2 < 0.03 ** 2:
                return col
        return skirt
    sp = [(0.17, 1.0), (0.2, 0.92), (0.26, 0.7), (0.3, 0.45), (0.31, 0.3)]
    sp = [(sp[i][0] + (sp[i + 1][0] - sp[i][0]) * k / 16, sp[i][1] + (sp[i + 1][1] - sp[i][1]) * k / 16) for i in range(len(sp) - 1) for k in range(16)] + [sp[-1]]
    sk = lathe(sp, 64, "skirt")
    for v in sk.data.vertices:
        v.co.y *= 0.82
    paint_fn(sk, floral); b.add(sk, drape_w(0.6))
    hem = lathe([(0.312, 0.3), (0.312, 0.33)], 24, "hem")
    for v in hem.data.vertices:
        v.co.y *= 0.82
    paint(hem, (0.95, 0.75, 0.3)); b.add(hem, drape_w(0.6))
    # Striped apron (önlük): a curved front panel just outside the skirt.
    ap = bmesh.new()
    rows = []
    for i in range(7):
        z = 1.0 - i * 0.1
        r = 0.2 + (0.31 - 0.2) * (1.0 - z) / 0.7 + 0.015
        rows.append([ap.verts.new((math.sin(a) * r, math.cos(a) * r * 0.82, z)) for a in [(-0.75 + j * 0.25) for j in range(7)]])
    for i in range(6):
        for j in range(6):
            ap.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
    from blender_models import obj_from_bm
    apo = obj_from_bm(ap, "apron")
    import blender_models as bmm
    bmm.mod(apo, 'SOLIDIFY', thickness=0.01)
    paint_fn(apo, lambda c, n: (0.95, 0.93, 0.85) if int((math.atan2(c.x, c.y) + 1) / 0.12) % 2 else (0.75, 0.2, 0.2))
    b.add(apo, drape_w(0.5))
    # Short embroidered vest.
    vp = [(0.17, 1.12), (0.18, 1.2), (0.19, 1.3), (0.185, 1.39), (0.125, 1.445)]
    b.shell(vp, 0.66, vest, torso_w, fn=lambda c, n: blouse if (abs(c.x) < 0.045 and c.y > 0) else ((0.95, 0.75, 0.3) if abs(abs(c.x) - 0.05) < 0.012 and c.y > 0 else vest))
    sash = cone(0.165, 0.165, 0.07, 20, loc=(0, 0, 1.03), name="sash")
    for v in sash.data.vertices:
        v.co.y *= 0.64
    paint(sash, (0.85, 0.55, 0.2)); b.add(sash, "hips")
    add_head(b, SKIN)
    # Yazma: head scarf with an open face and oya trim, knot at the nape.
    sc = ico(0.16, 3, loc=(0, -0.01, 1.685), scale=(1.0, 1.0, 1.05), name="yazma")
    bm = bmesh.new(); bm.from_mesh(sc.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.04 and 1.57 < v.co.z < 1.75], context='VERTS')
    bm.to_mesh(sc.data); bm.free()
    paint_fn(sc, lambda c, n: (0.85, 0.3, 0.25) if random.Random(int(c.x * 60) + int(c.z * 60) * 7).random() < 0.08 else scarf)
    b.add(sc, "head")
    for k in range(9):
        x = -0.1 + k * 0.025
        zz = 1.755
        yy = -0.01 + math.sqrt(max(0.0, 0.165 ** 2 - x * x - ((zz - 1.685) / 1.05) ** 2))
        o = ico(0.014, 1, loc=(x, yy, zz), name="oya")
        paint(o, (0.9, 0.3, 0.3) if k % 2 else (0.98, 0.98, 0.95)); b.add(o, "head")
    tail = cone(0.07, 0.02, 0.2, 10, loc=(0, -0.13, 1.42), name="tail"); paint(tail, scarf); b.add(tail, "neck")
    # Küfe on the back with tea leaves.
    kf = lathe([(0.15, 0.95), (0.2, 1.25), (0.2, 1.27)], 14, "kufe")
    for v in kf.data.vertices:
        v.co.y = v.co.y * 0.75 - 0.27
    paint_fn(kf, lambda c, n: (0.62, 0.47, 0.27) if int(c.z / 0.05) % 2 else (0.52, 0.38, 0.22)); b.add(kf, "spine")
    lv = ico(0.17, 2, loc=(0, -0.27, 1.28), scale=(1.1, 0.8, 0.35), name="leaves"); paint(lv, (0.24, 0.45, 0.16), 0.12); b.add(lv, "spine")
    for side in (-1, 1):
        st = branch((0.09 * side, 0.1, 1.42), (0.12 * side, -0.16, 1.24), 0.012, 0.012, 4); paint(st, (0.4, 0.3, 0.2)); b.add(st, "spine")
    rig_export("villager_woman", b)


def traveller():
    b = Body()
    jacket = (0.92, 0.5, 0.18); jeans = (0.22, 0.28, 0.4)
    base_body(b, SKIN, jacket, jeans, (0.36, 0.25, 0.15), sleeve=jacket)
    for side in (-1, 1):
        lace = box((0.06, 0.08, 0.04), (0.1 * side, 0.08, 0.085), (0.5, 0.36, 0.22)); b.add(lace, bone_name("foot", side), smooth=False)
        pk = box((0.08, 0.02, 0.08), (0.1 * side, 0.112, 1.05), S(jacket, 0.82)); b.add(pk, torso_w, smooth=False)
    zp = box((0.012, 0.02, 0.5), (0, 0.118, 1.18), (0.85, 0.85, 0.82)); b.add(zp, torso_w, smooth=False)
    col = cone(0.1, 0.085, 0.07, 14, loc=(0, -0.005, 1.44), name="collar"); paint(col, S(jacket, 0.9)); b.add(col, "neck")
    # Backpack with straps and a rolled mat.
    pack = box((0.3, 0.17, 0.44), (0, -0.2, 1.2), (0.32, 0.4, 0.3), bevel=0.04); b.add(pack, "spine")
    lid = box((0.3, 0.19, 0.08), (0, -0.2, 1.43), (0.26, 0.33, 0.24), bevel=0.03); b.add(lid, "spine")
    mat = branch((-0.2, -0.22, 0.98), (0.2, -0.22, 0.98), 0.06, 0.06, 10); paint(mat, (0.75, 0.2, 0.15)); b.add(mat, "spine")
    for side in (-1, 1):
        sp = branch((0.09 * side, 0.08, 1.43), (0.11 * side, 0.12, 1.1), 0.012, 0.012, 4); paint(sp, (0.15, 0.15, 0.15)); b.add(sp, "spine")
    add_head(b, SKIN, hair=(0.3, 0.2, 0.12))
    bn = ico(0.152, 3, loc=(0, -0.01, 1.73), scale=(1, 1, 0.66), name="beanie"); paint(bn, (0.78, 0.2, 0.15)); b.add(bn, "head")
    rim = cone(0.153, 0.153, 0.04, 20, loc=(0, -0.01, 1.71), name="rim"); paint(rim, (0.68, 0.16, 0.12)); b.add(rim, "head")
    rig_export("traveller", b)


SKIN_M = (0.8, 0.6, 0.46)


# --- Rig + animation ---------------------------------------------------------------

def make_armature():
    arm_data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_data.edit_bones
    for name in ["hips", "spine", "neck", "head", "upper_arm", "forearm", "hand", "thigh", "shin", "foot"]:
        for side in ((1, -1) if name in SIDED else (1,)):
            e = eb.new(bone_name(name, side))
            e.head = jp(name, side); e.tail = jp(name, side, 1)
            e.roll = 0.0
            if name in PARENT:
                e.parent = eb[bone_name(PARENT[name], side if PARENT[name] in SIDED else 1)]
                e.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


def pose(arm, f, rots, hips_dz=0.0):
    """rots: {bone: [(axis 'X'|'Y'|'Z', degrees), ...]} in armature space."""
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        R = Matrix.Identity(3)
        for axis, deg in rots.get(pb.name, []):
            R = Matrix.Rotation(math.radians(deg), 3, axis) @ R
        M = pb.bone.matrix_local.to_3x3()
        pb.rotation_quaternion = (M.inverted() @ R @ M).to_quaternion()
        pb.location = (M.inverted() @ Vector((0, 0, hips_dz))) if pb.name == "hips" else Vector()
        pb.keyframe_insert("rotation_quaternion", frame=f)
        pb.keyframe_insert("location", frame=f)


def anim_walk(arm, f, p):
    s = math.sin(2 * math.pi * p); c = math.cos(2 * math.pi * p)
    r = {}
    for side, sg in ((1, 1), (-1, -1)):
        ss, cc = s * sg, c * sg
        t = 26 * ss
        k = -6 - 48 * max(0.0, cc) ** 1.4
        r[bone_name("thigh", side)] = [('X', t)]
        r[bone_name("shin", side)] = [('X', k)]
        r[bone_name("foot", side)] = [('X', -0.6 * (t + k) - 4)]
        r[bone_name("upper_arm", side)] = [('X', -20 * ss), ('Y', 4 * side)]
        r[bone_name("forearm", side)] = [('X', 14 + 12 * max(0.0, -ss))]
    r["hips"] = [('Z', 5 * s)]
    r["spine"] = [('Z', -8 * s), ('X', 3)]
    r["head"] = [('Z', 3 * s)]
    pose(arm, f, r, hips_dz=0.028 * abs(c) - 0.02)


def anim_idle(arm, f, p):
    s = math.sin(2 * math.pi * p)
    r = {"spine": [('X', 1.5 * s)], "neck": [('X', -1.0 * s)], "head": [('Z', 9 * math.sin(2 * math.pi * p + 1)), ('X', 2 * math.sin(4 * math.pi * p))]}
    for side in (1, -1):
        r[bone_name("upper_arm", side)] = [('X', 2 * s), ('Y', -3 * side)]
        r[bone_name("forearm", side)] = [('X', 8 + 2 * s)]
    pose(arm, f, r)


def anim_work(arm, f, p):
    e = 0.5 - 0.5 * math.cos(2 * math.pi * p)
    pick = math.sin(6 * math.pi * p) * e
    r = {"spine": [('X', -38 * e)], "hips": [('X', -8 * e)], "head": [('X', -10 * e)]}
    for side in (1, -1):
        r[bone_name("upper_arm", side)] = [('X', (55 + 10 * pick * side) * e)]
        r[bone_name("forearm", side)] = [('X', (30 + 15 * pick * side) * e)]
        r[bone_name("thigh", side)] = [('X', 10 * e)]
        r[bone_name("shin", side)] = [('X', -16 * e)]
        r[bone_name("foot", side)] = [('X', 4 * e)]
    pose(arm, f, r, hips_dz=-0.04 * e)


def anim_talk(arm, f, p):
    g = math.sin(4 * math.pi * p)
    r = {"head": [('X', 4 * math.sin(6 * math.pi * p)), ('Z', 6 * math.sin(2 * math.pi * p))], "spine": [('Z', 3 * g)],
         "upper_arm.L": [('X', 28 + 6 * g), ('Y', -10)], "forearm.L": [('X', 55 + 18 * g), ('Z', -10 * g)],
         "upper_arm.R": [('X', 6), ('Y', 4)], "forearm.R": [('X', 14 + 6 * math.sin(2 * math.pi * p))]}
    pose(arm, f, r)


ANIMS = [("idle", anim_idle, 90, 10), ("walk", anim_walk, 30, 2), ("work", anim_work, 90, 5), ("talk", anim_talk, 90, 5)]


def rig_export(name, b):
    arm = make_armature()
    bpy.ops.object.select_all(action='DESELECT')
    for ob in b.obs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = b.obs[0]
    bpy.ops.object.join()
    body = b.obs[0]
    body.name = name
    body.parent = arm
    m = body.modifiers.new("Armature", 'ARMATURE')
    m.object = arm
    arm.animation_data_create()
    for an, fn, frames, step in ANIMS:
        act = bpy.data.actions.new(an)
        act.use_fake_user = True
        arm.animation_data.action = act
        for f in range(0, frames + 1, step):
            fn(arm, f, f / frames)
        tr = arm.animation_data.nla_tracks.new()
        tr.name = an
        tr.strips.new(an, 0, act)
        arm.animation_data.action = None
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True); body.select_set(True)
    path = os.path.join(OUT, name + "_rig.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_vertex_color='ACTIVE', export_all_vertex_colors=False,
                              export_materials='NONE', export_apply=False, export_yup=True,
                              export_animations=True, export_animation_mode='NLA_TRACKS',
                              export_force_sampling=True, export_frame_step=1)
    print("exported", path)


if __name__ == "__main__":
    villager_woman()
    villager_man()
    shepherd()
    fisherman()
    traveller()
