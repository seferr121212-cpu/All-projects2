"""Generates Horizon Road's stylized models with Blender (bpy) and exports
them as .glb with linear vertex colours (COLOR_0), Y-up, facing -Z in Godot.
Run: python tools/blender_models.py <out_dir>   (needs `pip install bpy`)."""
import bpy, bmesh, math, random, sys, os
from mathutils import Vector, Matrix, noise

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/models/blender"
os.makedirs(OUT, exist_ok=True)


def lin(c):
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def obj_from_bm(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def paint(ob, col, jitter=0.0, seed=0, grad=None):
    """Per-face colour with optional jitter and a vertical gradient (bottom, top)."""
    rnd = random.Random(seed)
    me = ob.data
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", 'FLOAT_COLOR', 'CORNER')
    zs = [v.co.z for v in me.vertices] or [0]
    z0, z1 = min(zs), max(zs)
    for poly in me.polygons:
        k = 1.0 + rnd.uniform(-jitter, jitter)
        c = col
        if grad:
            t = (poly.center.z - z0) / max(z1 - z0, 1e-4)
            c = tuple(grad[0][i] + (grad[1][i] - grad[0][i]) * t for i in range(3))
        c = lin(tuple(min(max(x * k, 0), 1) for x in c))
        for li in poly.loop_indices:
            attr.data[li].color = (*c, 1.0)
    me.color_attributes.active_color = attr


def displace(ob, strength, scale, seed=0, flat=True):
    off = Vector((seed * 13.1, seed * 7.7, seed * 3.3))
    for v in ob.data.vertices:
        n = noise.noise(v.co * scale + off)
        v.co += v.normal * n * strength
    for p in ob.data.polygons:
        p.use_smooth = not flat


def mod(ob, kind, **kw):
    m = ob.modifiers.new(kind, kind)
    for k, v in kw.items():
        setattr(m, k, v)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=m.name)


def ico(r, sub, loc=(0, 0, 0), scale=(1, 1, 1), name="ico"):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    return obj_from_bm(bm, name)


def cone(r1, r2, h, seg, loc=(0, 0, 0), name="cone", rot=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=h)
    bmesh.ops.translate(bm, vec=(0, 0, h / 2), verts=bm.verts)
    if rot:
        bmesh.ops.rotate(bm, matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    return obj_from_bm(bm, name)


def cube(size, loc=(0, 0, 0), name="cube", bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    ob = obj_from_bm(bm, name)
    if bevel > 0:
        mod(ob, 'BEVEL', width=bevel, segments=2)
    return ob


def branch(p0, p1, r0, r1, seg=6, name="br"):
    d = Vector(p1) - Vector(p0)
    rot = d.to_track_quat('Z', 'Y').to_matrix().to_4x4()
    return cone(r0, r1, d.length, seg, loc=p0, name=name, rot=rot)


def smooth_all(obs, smooth):
    for ob in obs:
        for p in ob.data.polygons:
            p.use_smooth = smooth


def bake_ao(ob, rays=22, strength=0.9, ground=True, seed=1):
    """Bakes ambient occlusion into the vertex colours (multiplied per corner).
    Hemisphere rays are cast against the mesh itself and a virtual ground plane
    at z = 0, so crevices, under-eaves and contact areas read darker."""
    from mathutils.bvhtree import BVHTree
    me = ob.data
    attr = me.color_attributes.active_color
    if attr is None or len(me.vertices) == 0:
        return
    dg = bpy.context.evaluated_depsgraph_get()
    tree = BVHTree.FromObject(ob, dg)
    size = max(ob.dimensions) or 1.0
    dist = min(max(size * 0.16, 0.22), 1.6)
    rnd = random.Random(seed)
    dirs = []
    for _ in range(rays):  # cosine-ish hemisphere samples in tangent space (z up)
        u, v = rnd.random(), rnd.random()
        r = math.sqrt(u); a = math.tau * v
        dirs.append(Vector((r * math.cos(a), r * math.sin(a), math.sqrt(max(0.0, 1 - u)))))
    occ = []
    for v in me.vertices:
        n = v.normal.normalized()
        t = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
        b = n.cross(t)
        o = v.co + n * 0.01
        hit = 0.0
        for d in dirs:
            w = t * d.x + b * d.y + n * d.z
            h = tree.ray_cast(o, w, dist)
            if h[0] is not None:
                hit += 1.0 - 0.5 * (h[3] / dist)
            elif ground and w.z < -0.02:
                tg = -o.z / w.z
                if 0 <= tg < dist:
                    hit += 1.0 - 0.5 * (tg / dist)
        occ.append(hit / rays)
    for poly in me.polygons:
        for li in poly.loop_indices:
            k = 1.0 - strength * occ[me.loops[li].vertex_index]
            c = attr.data[li].color
            attr.data[li].color = (c[0] * k, c[1] * k, c[2] * k, c[3])


def export(name, obs):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    if not name.endswith("_win"):
        bake_ao(bpy.context.view_layer.objects.active)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_vertex_color='ACTIVE', export_all_vertex_colors=False,
                              export_materials='NONE', export_apply=True, export_yup=True)
    print("exported", path)


# --- Vegetation --------------------------------------------------------------

def spruce(seed):
    reset(); rnd = random.Random(seed)
    obs = [cone(0.28, 0.12, 2.2, 7, name="trunk")]
    paint(obs[0], (0.35, 0.24, 0.16), 0.08, seed)
    h = rnd.uniform(9.0, 12.0); tiers = 6
    for i in range(tiers):
        t = i / tiers
        r = (1.0 - t) * 2.6 + 0.35
        z = 1.4 + t * (h - 2.4)
        c = cone(r, r * 0.12, h / tiers * 1.9, 9, loc=(0, 0, z), name="tier")
        # Drooping skirt: pull the rim down and jitter it.
        for v in c.data.vertices:
            if v.co.z < z + 0.1:
                v.co.z -= rnd.uniform(0.15, 0.45)
                v.co.x *= rnd.uniform(0.85, 1.1); v.co.y *= rnd.uniform(0.85, 1.1)
        dark, light = (0.07, 0.2, 0.1), (0.15, 0.32, 0.15)
        paint(c, None, 0.12, seed + i, grad=(dark, light))
        obs.append(c)
    export(f"spruce_{seed}", obs)


def broadleaf(seed, leaf=(0.22, 0.42, 0.14), name="broadleaf"):
    reset(); rnd = random.Random(seed)
    bark = (0.36, 0.27, 0.19)
    obs = [branch((0, 0, 0), (0.1, 0, 2.6), 0.3, 0.2, name="trunk")]
    tips = []
    for i in range(4):
        a = i * math.tau / 4 + rnd.uniform(-0.4, 0.4)
        tip = (math.cos(a) * 1.3, math.sin(a) * 1.3, 3.8 + rnd.uniform(-0.3, 0.5))
        obs.append(branch((0.1, 0, 2.3), tip, 0.14, 0.07, name="br")); tips.append(tip)
    for ob in obs:
        paint(ob, bark, 0.08, seed)
    crowns = [(0.1, 0, 4.4, 2.0)] + [(t[0], t[1], t[2] + 0.3, rnd.uniform(1.2, 1.6)) for t in tips]
    for i, (x, y, z, r) in enumerate(crowns):
        c = ico(r, 2, loc=(x, y, z), scale=(1, 1, 0.82), name="crown")
        displace(c, r * 0.35, 0.9, seed + i)
        mod(c, 'DECIMATE', decimate_type='COLLAPSE', ratio=0.45)
        paint(c, None, 0.1, seed + i, grad=(tuple(x * 0.7 for x in leaf), tuple(min(x * 1.25, 1) for x in leaf)))
        obs.append(c)
    export(f"{name}_{seed}", obs)


def poplar(seed):
    reset(); rnd = random.Random(seed)
    obs = [cone(0.2, 0.1, 2.5, 6, name="trunk")]
    paint(obs[0], (0.55, 0.52, 0.45), 0.05, seed)
    c = ico(1.0, 3, loc=(0, 0, 6.8), scale=(1.05, 1.05, 5.2), name="crown")
    displace(c, 0.35, 1.6, seed)
    mod(c, 'DECIMATE', decimate_type='COLLAPSE', ratio=0.35)
    paint(c, None, 0.1, seed, grad=((0.25, 0.38, 0.12), (0.5, 0.62, 0.24)))
    obs.append(c)
    export(f"poplar_{seed}", obs)


def olive(seed):
    reset(); rnd = random.Random(seed)
    bark = (0.42, 0.38, 0.32)
    obs = [branch((0, 0, 0), (0.25, 0.1, 1.2), 0.32, 0.22, name="trunk"),
           branch((0.25, 0.1, 1.1), (-0.6, 0.2, 2.2), 0.17, 0.08),
           branch((0.25, 0.1, 1.1), (0.9, -0.4, 2.1), 0.17, 0.08),
           branch((0.25, 0.1, 1.1), (0.2, 0.8, 2.3), 0.15, 0.07)]
    for ob in obs:
        paint(ob, bark, 0.1, seed)
    for i in range(6):
        p = (rnd.uniform(-1.2, 1.2), rnd.uniform(-1.2, 1.2), rnd.uniform(2.1, 2.9))
        c = ico(rnd.uniform(0.8, 1.1), 2, loc=p, scale=(1, 1, 0.7), name="crown")
        displace(c, 0.3, 1.4, seed + i)
        mod(c, 'DECIMATE', decimate_type='COLLAPSE', ratio=0.4)
        paint(c, None, 0.1, seed + i, grad=((0.33, 0.4, 0.26), (0.58, 0.64, 0.46)))
        obs.append(c)
    export(f"olive_{seed}", obs)


def rock(seed):
    reset()
    r = ico(1.0, 3, scale=(1.3, 1.0, 0.75), name="rock")
    displace(r, 0.45, 0.8, seed)
    displace(r, 0.12, 3.0, seed + 5)
    mod(r, 'DECIMATE', decimate_type='COLLAPSE', ratio=0.18)
    for v in r.data.vertices:
        v.co.z = max(v.co.z, -0.35)
    paint(r, None, 0.12, seed, grad=((0.36, 0.35, 0.32), (0.55, 0.54, 0.5)))
    export(f"rock_{seed}", [r])


def bush(seed):
    reset(); rnd = random.Random(seed); obs = []
    for i in range(5):
        p = (rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), rnd.uniform(0.35, 0.7))
        c = ico(rnd.uniform(0.45, 0.7), 2, loc=p, scale=(1, 1, 0.8), name="b")
        displace(c, 0.15, 2.0, seed + i)
        mod(c, 'DECIMATE', decimate_type='COLLAPSE', ratio=0.45)
        paint(c, None, 0.12, seed + i, grad=((0.12, 0.26, 0.1), (0.28, 0.46, 0.18)))
        obs.append(c)
    export(f"bush_{seed}", obs)


# --- Characters --------------------------------------------------------------
# Blender +Y becomes Godot -Z (the way characters face).

SKIN = (0.86, 0.68, 0.54)


def head(obs, z, skin, hair=None, seed=0):
    h = ico(0.15, 3, loc=(0, 0, z), scale=(0.95, 1.0, 1.08), name="head")
    paint(h, skin); smooth_all([h], True); obs.append(h)
    for x in (-0.05, 0.05):
        e = ico(0.022, 2, loc=(x, 0.135, z + 0.015), name="eye"); paint(e, (0.08, 0.06, 0.05)); obs.append(e)
        hl = ico(0.007, 1, loc=(x + 0.006, 0.152, z + 0.024), name="glint"); paint(hl, (1, 1, 1)); obs.append(hl)
        br = cube((0.05, 0.012, 0.014), loc=(x, 0.14, z + 0.06), name="brow"); paint(br, (0.25, 0.18, 0.12)); obs.append(br)
        ear = ico(0.035, 1, loc=(x * 3.0, 0.0, z), scale=(0.5, 1, 1.2), name="ear"); paint(ear, skin); obs.append(ear)
    n = ico(0.03, 2, loc=(0, 0.15, z - 0.02), scale=(0.8, 1, 1.1), name="nose"); paint(n, tuple(c * 0.95 for c in skin)); obs.append(n)
    m = cube((0.05, 0.01, 0.01), loc=(0, 0.14, z - 0.07), name="mouth"); paint(m, (0.55, 0.28, 0.25)); obs.append(m)
    for ob in obs[-12:]:
        for p in ob.data.polygons:
            p.use_smooth = True
    if hair:
        hr = ico(0.16, 3, loc=(0, -0.02, z + 0.04), scale=(1.0, 1.0, 0.9), name="hair")
        for v in hr.data.vertices:
            if v.co.y > 0.04 and v.co.z < z + 0.08:
                v.co.y -= 0.06
        paint(hr, hair); smooth_all([hr], True); obs.append(hr)


def limb(obs, p0, p1, r0, r1, col, seg=10):
    b = branch(p0, p1, r0, r1, seg, name="limb"); paint(b, col); smooth_all([b], True); obs.append(b)
    j = ico(r1, 2, loc=p1, name="joint"); paint(j, col); smooth_all([j], True); obs.append(j)


def torso(obs, z0, z1, rw, rd, col, bevel=True):
    t = ico(1.0, 3, loc=(0, 0, (z0 + z1) / 2), scale=(rw, rd, (z1 - z0) / 2), name="torso")
    paint(t, col); smooth_all([t], True); obs.append(t)


def villager_woman():
    reset(); obs = []
    skirt = (0.34, 0.2, 0.36); top = (0.62, 0.2, 0.18); scarf = (0.96, 0.76, 0.24)
    s = cone(0.36, 0.2, 0.9, 16, loc=(0, 0, 0.05), name="skirt"); paint(s, skirt); smooth_all([s], True); obs.append(s)
    ap = cone(0.2, 0.15, 0.55, 12, loc=(0, 0.13, 0.18), name="apron"); ap.scale = (1, 0.6, 1); paint(ap, (0.92, 0.9, 0.82)); obs.append(ap)
    torso(obs, 0.88, 1.42, 0.2, 0.15, top)
    for side in (-1, 1):
        limb(obs, (side * 0.2, 0, 1.36), (side * 0.27, 0.05, 1.05), 0.065, 0.055, top)
        limb(obs, (side * 0.27, 0.05, 1.05), (side * 0.24, 0.16, 0.86), 0.05, 0.045, top)
        hand = ico(0.05, 2, loc=(side * 0.24, 0.18, 0.82), name="hand"); paint(hand, SKIN); smooth_all([hand], True); obs.append(hand)
        sh = ico(0.07, 2, loc=(side * 0.1, 0.05, 0.04), scale=(1, 1.6, 0.6), name="shoe"); paint(sh, (0.2, 0.15, 0.1)); obs.append(sh)
    nk = cone(0.06, 0.055, 0.1, 10, loc=(0, 0, 1.42), name="neck"); paint(nk, SKIN); obs.append(nk)
    head(obs, 1.6, SKIN)
    sc = ico(0.172, 3, loc=(0, -0.01, 1.62), scale=(1.0, 1.0, 1.05), name="yazma")
    bm = bmesh.new(); bm.from_mesh(sc.data)
    # Open the face: drop the front verts between chin and brow.
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.05 and 1.5 < v.co.z < 1.69], context='VERTS')
    bm.to_mesh(sc.data); bm.free()
    paint(sc, scarf); smooth_all([sc], True); obs.append(sc)
    band = cube((0.3, 0.03, 0.035), loc=(0, 0.12, 1.7), name="oya"); paint(band, (0.85, 0.25, 0.2)); obs.append(band)
    knot = ico(0.05, 2, loc=(0, -0.17, 1.52), name="knot"); paint(knot, scarf); obs.append(knot)
    basket = cone(0.2, 0.27, 0.55, 14, loc=(0, -0.3, 0.95), name="kufe")
    paint(basket, (0.62, 0.47, 0.27), 0.08); obs.append(basket)
    leaves = ico(0.22, 2, loc=(0, -0.3, 1.5), scale=(1, 1, 0.35), name="leaves"); paint(leaves, (0.24, 0.45, 0.16), 0.1); obs.append(leaves)
    export("villager_woman", obs)


def villager_man(name="villager_man", coat=(0.2, 0.32, 0.52), cap=(0.35, 0.3, 0.25), beard=False):
    reset(); obs = []
    for side in (-1, 1):
        limb(obs, (side * 0.11, 0, 0.92), (side * 0.11, 0.02, 0.48), 0.085, 0.075, coat)
        limb(obs, (side * 0.11, 0.02, 0.48), (side * 0.11, 0, 0.1), 0.07, 0.06, coat)
        sh = ico(0.08, 2, loc=(side * 0.11, 0.05, 0.05), scale=(1, 1.7, 0.6), name="boot"); paint(sh, (0.2, 0.14, 0.1)); obs.append(sh)
        limb(obs, (side * 0.24, 0, 1.42), (side * 0.3, 0.03, 1.1), 0.07, 0.06, coat)
        limb(obs, (side * 0.3, 0.03, 1.1), (side * 0.28, 0.12, 0.86), 0.06, 0.05, coat)
        hand = ico(0.055, 2, loc=(side * 0.28, 0.13, 0.82), name="hand"); paint(hand, SKIN); smooth_all([hand], True); obs.append(hand)
    torso(obs, 0.85, 1.5, 0.25, 0.17, coat)
    belt = cone(0.25, 0.25, 0.06, 16, loc=(0, 0, 0.92), name="belt"); paint(belt, (0.18, 0.13, 0.1)); obs.append(belt)
    nk = cone(0.065, 0.06, 0.1, 10, loc=(0, 0, 1.5), name="neck"); paint(nk, SKIN); obs.append(nk)
    head(obs, 1.7, (0.8, 0.6, 0.46))
    mo = cube((0.12, 0.03, 0.03), loc=(0, 0.145, 1.645), name="moustache", bevel=0.01); paint(mo, (0.22, 0.18, 0.15)); obs.append(mo)
    if beard:
        bd = ico(0.13, 2, loc=(0, 0.06, 1.6), scale=(1, 0.8, 0.8), name="beard"); paint(bd, (0.75, 0.74, 0.72)); smooth_all([bd], True); obs.append(bd)
    cp = ico(0.165, 3, loc=(0, -0.01, 1.8), scale=(1, 1.05, 0.45), name="cap"); paint(cap, cap) if False else paint(cp, cap); smooth_all([cp], True); obs.append(cp)
    peak = cube((0.22, 0.12, 0.025), loc=(0, 0.15, 1.79), name="peak", bevel=0.01); paint(peak, tuple(c * 0.85 for c in cap)); obs.append(peak)
    export(name, obs)


def traveller():
    jacket = (0.92, 0.5, 0.18); trousers = (0.22, 0.26, 0.34)
    reset(); obs = []
    torso(obs, 0.86, 1.48, 0.23, 0.15, jacket)
    zip_ = cube((0.03, 0.01, 0.5), loc=(0, 0.15, 1.17), name="zip"); paint(zip_, (0.8, 0.8, 0.78)); obs.append(zip_)
    pack = cube((0.34, 0.2, 0.46), loc=(0, -0.24, 1.2), name="pack", bevel=0.05); paint(pack, (0.32, 0.4, 0.3)); obs.append(pack)
    hips = ico(1.0, 2, loc=(0, 0, 0.86), scale=(0.21, 0.13, 0.09), name="hips"); paint(hips, trousers); smooth_all([hips], True); obs.append(hips)
    nk = cone(0.06, 0.055, 0.1, 10, loc=(0, 0, 1.48), name="neck"); paint(nk, SKIN); obs.append(nk)
    head(obs, 1.66, SKIN, hair=(0.3, 0.2, 0.12))
    beanie = ico(0.165, 3, loc=(0, -0.01, 1.74), scale=(1, 1, 0.62), name="beanie"); paint(beanie, (0.78, 0.2, 0.15)); smooth_all([beanie], True); obs.append(beanie)
    export("traveller_body", obs)
    reset(); obs = []
    limb(obs, (0, 0, 0), (0, 0.02, -0.42), 0.085, 0.075, trousers)
    limb(obs, (0, 0.02, -0.42), (0, 0, -0.78), 0.075, 0.065, trousers)
    sh = ico(0.085, 2, loc=(0, 0.05, -0.83), scale=(1, 1.7, 0.6), name="boot"); paint(sh, (0.32, 0.22, 0.14)); obs.append(sh)
    export("traveller_leg", obs)
    reset(); obs = []
    limb(obs, (0, 0, 0), (0, 0.02, -0.3), 0.07, 0.06, jacket)
    limb(obs, (0, 0.02, -0.3), (0, 0.05, -0.55), 0.06, 0.05, jacket)
    hand = ico(0.055, 2, loc=(0, 0.05, -0.6), name="hand"); paint(hand, SKIN); smooth_all([hand], True); obs.append(hand)
    export("traveller_arm", obs)


if __name__ == "__main__":
    for s in (1, 2, 3):
        spruce(s)
    for s in (1, 2):
        broadleaf(s)
        rock(s)
        bush(s)
        olive(s)
    broadleaf(3, leaf=(0.32, 0.48, 0.18), name="apricot")
    rock(3)
    poplar(1)
    villager_woman()
    villager_man()
    villager_man("fisherman", coat=(0.25, 0.3, 0.38), cap=(0.15, 0.2, 0.32), beard=True)
    villager_man("shepherd", coat=(0.38, 0.32, 0.25), cap=(0.2, 0.18, 0.16), beard=True)
    traveller()
