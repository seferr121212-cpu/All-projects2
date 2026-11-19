"""Houses, fairy chimneys, tents and boats for Horizon Road, built with bpy.
Blender -Y becomes Godot +Z (house fronts face -Y here = +Z in Godot).
Each house exports <name>.glb (body) and <name>_win.glb (glass, glows at night).
Run: python tools/blender_structures.py <out_dir>"""
import sys, math, random
import bpy
import bmesh
from mathutils import Vector, Matrix, noise
sys.path.insert(0, __import__("os").path.dirname(__file__))
import blender_models as bm_
from blender_models import reset, obj_from_bm, paint, mod, ico, cone, cube, branch, smooth_all, export, lin


def box(size, loc, col, rot=(0, 0, 0), jitter=0.0, seed=0, bevel=0.0, cuts=0):
    """Box centred at loc, rotated by Euler XYZ (radians), optionally subdivided/bevelled."""
    b = bmesh.new()
    bmesh.ops.create_cube(b, size=1.0)
    if cuts:
        bmesh.ops.subdivide_edges(b, edges=b.edges[:], cuts=cuts, use_grid_fill=True)
    bmesh.ops.scale(b, vec=size, verts=b.verts)
    m = Matrix.Translation(loc) @ __import__("mathutils").Euler(rot).to_matrix().to_4x4()
    bmesh.ops.transform(b, matrix=m, verts=b.verts)
    ob = obj_from_bm(b, "box")
    if bevel > 0:
        mod(ob, 'BEVEL', width=bevel, segments=1)
    paint(ob, col, jitter, seed)
    return ob


def beam(p0, p1, w, h, col, jitter=0.0, seed=0):
    """Rectangular timber between two points."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    rot = d.to_track_quat('Z', 'Y').to_matrix().to_4x4()
    b = bmesh.new()
    bmesh.ops.create_cube(b, size=1.0)
    bmesh.ops.scale(b, vec=(w, h, d.length), verts=b.verts)
    bmesh.ops.transform(b, matrix=Matrix.Translation((p0 + p1) / 2) @ rot, verts=b.verts)
    ob = obj_from_bm(b, "beam")
    paint(ob, col, jitter, seed)
    return ob


def paint_fn(ob, fn):
    """Per-face colour from fn(face_center, face_normal) -> rgb (sRGB)."""
    me = ob.data
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", 'FLOAT_COLOR', 'CORNER')
    for poly in me.polygons:
        c = lin(tuple(min(max(x, 0), 1) for x in fn(poly.center, poly.normal)))
        for li in poly.loop_indices:
            attr.data[li].color = (*c, 1.0)
    me.color_attributes.active_color = attr


def lathe(profile, seg, name="lathe", wobble=0.0, seed=0, flute=0.0, flutes=7):
    """Surface of revolution around Z. profile = [(r, z)], bottom to top; closed top/bottom if r==0."""
    b = bmesh.new()
    rings = []
    off = seed * 5.3
    for (r, z) in profile:
        ring = []
        for s in range(seg):
            a = s / seg * math.tau
            rr = r
            if r > 0:
                rr *= 1 + wobble * noise.noise(Vector((math.cos(a) * 1.7, math.sin(a) * 1.7, z * 0.35 + off)))
                rr *= 1 - flute * (0.5 + 0.5 * math.cos(a * flutes + z * 0.4 + seed))
            ring.append(b.verts.new((math.cos(a) * rr, math.sin(a) * rr, z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for s in range(seg):
            s2 = (s + 1) % seg
            b.faces.new((rings[i][s], rings[i][s2], rings[i + 1][s2], rings[i + 1][s]))
    if profile[0][0] > 0:
        b.faces.new(list(reversed(rings[0])))
    if profile[-1][0] > 0:
        b.faces.new(rings[-1])
    bmesh.ops.remove_doubles(b, verts=b.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(b, faces=b.faces)
    return obj_from_bm(b, name)


def tri_prism(w, d, h, loc, col, seed=0):
    """Gable: triangle (width w, height h) extruded depth d along Y."""
    b = bmesh.new()
    x, y, z = loc
    v = [b.verts.new(p) for p in [(x - w / 2, y - d / 2, z), (x + w / 2, y - d / 2, z), (x, y - d / 2, z + h),
                                  (x - w / 2, y + d / 2, z), (x + w / 2, y + d / 2, z), (x, y + d / 2, z + h)]]
    for f in [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]:
        b.faces.new([v[i] for i in f])
    bmesh.ops.recalc_face_normals(b, faces=b.faces)
    ob = obj_from_bm(b, "gable")
    paint(ob, col, 0.03, seed)
    return ob


def stone_wall(size, loc, base, seed, rough=0.04, rows=None):
    """Wall block with individually tinted stone courses and mortar-dark joints."""
    rnd = random.Random(seed)
    ob = box(size, loc, base, cuts=0)
    b = bmesh.new(); b.from_mesh(ob.data)
    sx, sy, sz = size
    rows = rows or max(2, int(sz / 0.42))
    bmesh.ops.subdivide_edges(b, edges=[e for e in b.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 1e-4], cuts=rows - 1, use_grid_fill=True)
    cols_x = max(2, int(sx / 0.6)); cols_y = max(2, int(sy / 0.6))
    bmesh.ops.subdivide_edges(b, edges=[e for e in b.edges if abs(e.verts[0].co.x - e.verts[1].co.x) > sx * 0.9], cuts=cols_x - 1, use_grid_fill=True)
    bmesh.ops.subdivide_edges(b, edges=[e for e in b.edges if abs(e.verts[0].co.y - e.verts[1].co.y) > sy * 0.9], cuts=cols_y - 1, use_grid_fill=True)
    # Inset every face slightly so joints read as mortar lines.
    side = [f for f in b.faces if abs(f.normal.z) < 0.5]
    res = bmesh.ops.inset_individual(b, faces=side, thickness=0.035, depth=0.025)
    b.to_mesh(ob.data); b.free()
    me = ob.data
    stone_faces = set()
    for p in me.polygons:
        stone_faces.add(p.index)
    off = Vector((seed * 3.1, seed * 1.7, 0))
    for v in me.vertices:
        v.co += Vector((noise.noise(v.co * 2.1 + off), noise.noise(v.co * 2.3 - off), 0)) * rough

    def col(c, n):
        k = 0.82 + rnd.random() * 0.3
        warm = rnd.uniform(-0.04, 0.04)
        return (base[0] * k + warm, base[1] * k, base[2] * k - warm)
    paint_fn(ob, col)
    # Darken the thin joint ring faces (small area) to read as mortar.
    attr = me.color_attributes["Col"]
    for p in me.polygons:
        if p.area < 0.02 and abs(p.normal.z) < 0.9:
            for li in p.loop_indices:
                c = attr.data[li].color
                attr.data[li].color = (c[0] * 0.55, c[1] * 0.55, c[2] * 0.55, 1)
    return ob


def tile_roof(w, d, h, z0, col, seed, overhang=0.5, rows=7):
    """Gable roof of overlapping tile courses along X slopes; ridge along Y."""
    rnd = random.Random(seed)
    obs = []
    half = w / 2 + overhang
    ang = math.atan2(h, half)
    slope = math.hypot(half, h)
    for side in (-1, 1):
        for r in range(rows):
            t0 = r / rows
            # course centre along the slope from eave (t=0) to ridge (t=1)
            t = t0 + 0.5 / rows
            x = side * half * (1 - t)
            z = z0 + h * t - overhang * h / half * (1 - t) * 0 + 0.06
            k = 0.88 + rnd.random() * 0.2
            c = tuple(min(1, ch * k) for ch in col)
            ob = box((slope / rows * 1.25, d + 2 * overhang, 0.09), (x, 0, z), c,
                     rot=(0, side * ang, 0), cuts=0)
            # Corrugate along Y to suggest round tiles.
            for v in ob.data.vertices:
                pass
            obs.append(ob)
    ridge = box((0.32, d + 2 * overhang + 0.1, 0.22), (0, 0, z0 + h + 0.06), tuple(c * 0.8 for c in col), bevel=0.04)
    obs.append(ridge)
    # Tile ribs: thin half-round rows across each slope.
    n = int((d + 2 * overhang) / 0.32)
    for side in (-1, 1):
        for i in range(n):
            y = -(d / 2 + overhang) + (i + 0.5) * (d + 2 * overhang) / n
            p0 = Vector((side * half, y, z0 + 0.1))
            p1 = Vector((side * 0.12, y, z0 + h + 0.08))
            rib = branch(p0, p1, 0.07, 0.07, 4, name="rib")
            k = 0.82 + rnd.random() * 0.25
            paint(rib, tuple(min(1, ch * k) for ch in col))
            obs.append(rib)
    return obs


def window_set(obs, wins, p, facing, size=(0.9, 1.0), frame=(0.88, 0.85, 0.78), shutter=None, sill=True):
    """Frame + mullion cross on body, glass pane into wins. facing: 'x+','x-','y+','y-'."""
    w, h = size
    x, y, z = p
    t = 0.07
    if facing[0] == 'y':
        s = 1 if facing[1] == '+' else -1
        wins.append(box((w, 0.04, h), (x, y + s * 0.01, z), (1, 1, 1)))
        for dx in (-w / 2, w / 2):
            obs.append(box((t, 0.12, h + t), (x + dx, y + s * 0.03, z), frame))
        for dz in (-h / 2, h / 2):
            obs.append(box((w + t, 0.12, t), (x, y + s * 0.03, z + dz), frame))
        obs.append(box((0.04, 0.08, h), (x, y + s * 0.05, z), frame))
        obs.append(box((w, 0.08, 0.04), (x, y + s * 0.05, z + h * 0.1), frame))
        if sill:
            obs.append(box((w + 0.25, 0.22, 0.07), (x, y + s * 0.1, z - h / 2 - 0.05), tuple(c * 0.85 for c in frame)))
        if shutter:
            for dx in (-1, 1):
                obs.append(box((w * 0.5, 0.05, h * 1.02), (x + dx * w * 0.78, y + s * 0.07, z), shutter, jitter=0.05))
    else:
        s = 1 if facing[1] == '+' else -1
        wins.append(box((0.04, w, h), (x + s * 0.01, y, z), (1, 1, 1)))
        for dy in (-w / 2, w / 2):
            obs.append(box((0.12, t, h + t), (x + s * 0.03, y + dy, z), frame))
        for dz in (-h / 2, h / 2):
            obs.append(box((0.12, w + t, t), (x + s * 0.03, y, z + dz), frame))
        obs.append(box((0.08, 0.04, h), (x + s * 0.05, y, z), frame))
        obs.append(box((0.08, w, 0.04), (x + s * 0.05, y, z + h * 0.1), frame))
        if sill:
            obs.append(box((0.22, w + 0.25, 0.07), (x + s * 0.1, y, z - h / 2 - 0.05), tuple(c * 0.85 for c in frame)))
        if shutter:
            for dy in (-1, 1):
                obs.append(box((0.05, w * 0.5, h * 1.02), (x + s * 0.07, y + dy * w * 0.78, z), shutter, jitter=0.05))


def door(obs, x, y, z0, w, h, col, frame, facing_y=-1, arch=False):
    obs.append(box((w, 0.1, h), (x, y + facing_y * 0.02, z0 + h / 2), col, jitter=0.04))
    for i in range(3):  # planks
        obs.append(box((0.03, 0.04, h * 0.95), (x - w / 3 + i * w / 3 + w / 6 - w / 6, y + facing_y * 0.08, z0 + h / 2), tuple(c * 0.75 for c in col)))
    obs.append(ico(0.04, 1, loc=(x + w * 0.35, y + facing_y * 0.1, z0 + h * 0.5), name="knob"))
    paint(obs[-1], (0.75, 0.62, 0.3))
    for dx in (-w / 2 - 0.06, w / 2 + 0.06):
        obs.append(box((0.12, 0.16, h + 0.1), (x + dx, y + facing_y * 0.04, z0 + h / 2), frame))
    if arch:
        a = lathe([(w / 2 + 0.14, 0), (w / 2 + 0.14, 0.16)], 16, name="arch")
        for v in a.data.vertices:  # turn into half ring standing on the door
            v.co = Vector((v.co.x, v.co.z - 0.08, max(v.co.y, 0)))
        a.location = (x, y + facing_y * 0.05, z0 + h)
        paint(a, frame)
        obs.append(a)
    else:
        obs.append(box((w + 0.36, 0.18, 0.14), (x, y + facing_y * 0.05, z0 + h + 0.07), frame))
    obs.append(box((w + 0.5, 0.5, 0.12), (x, y + facing_y * 0.3, z0 - 0.02), (0.6, 0.58, 0.55), jitter=0.05))


def finish(name, obs, wins):
    smooth_all(obs, False)
    export(name, obs)
    if wins:
        export(name + "_win", wins)


# --- Houses -----------------------------------------------------------------

def yayla_house(seed, wood=(0.56, 0.38, 0.24), roof=(0.6, 0.25, 0.18)):
    """Black Sea highland house: stone ground floor, log upper floor, balcony, tiled gable."""
    reset(); obs = []; wins = []
    rnd = random.Random(seed)
    w, d = 6.0, 7.5
    obs.append(stone_wall((w, d, 2.9), (0, 0, 0.45), (0.58, 0.56, 0.52), seed, rough=0.05))
    # Log storey: stacked logs with alternating tint and protruding corner ends.
    z = 1.9
    i = 0
    while z < 4.45:
        k = 0.9 + 0.15 * (i % 2) + rnd.uniform(-0.05, 0.05)
        c = tuple(ch * k for ch in wood)
        for (sx, sy, px, py) in ((w + 0.5, 0.26, 0, -d / 2), (w + 0.5, 0.26, 0, d / 2), (0.26, d + 0.5, -w / 2, 0), (0.26, d + 0.5, w / 2, 0)):
            ob = box((sx, sy, 0.24), (px, py, z + 0.12), c, bevel=0.05)
            obs.append(ob)
        z += 0.25; i += 1
    obs.append(box((w - 0.1, d - 0.1, 2.55), (0, 0, 3.15), tuple(c * 0.8 for c in wood)))
    # Gables and roof.
    rh = 2.0
    obs.append(tri_prism(w + 0.4, d + 0.4, rh, (0, 0, 4.45), tuple(c * 0.92 for c in wood), seed))
    obs += tile_roof(w + 0.4, d + 0.4, rh, 4.45, roof, seed, overhang=0.7, rows=6)
    # Rafter ends under the eaves.
    for yy in [-d / 2 - 0.2 + j * (d + 0.4) / 6 for j in range(7)]:
        for side in (-1, 1):
            obs.append(box((0.9, 0.12, 0.12), (side * (w / 2 + 0.45), yy, 4.4), tuple(c * 0.6 for c in wood)))
    # Front balcony on stone floor with railing.
    obs.append(box((w + 0.6, 1.1, 0.14), (0, -d / 2 - 0.6, 1.95), tuple(c * 0.8 for c in wood), bevel=0.02))
    for x in (-w / 2 - 0.15, w / 2 + 0.15, 0):
        obs.append(box((0.16, 0.16, 2.5), (x, -d / 2 - 1.05, 0.75), tuple(c * 0.7 for c in wood)))
    obs.append(box((w + 0.6, 0.1, 0.1), (0, -d / 2 - 1.1, 2.95), wood))
    for j in range(22):
        x = -w / 2 - 0.15 + j * (w + 0.3) / 21
        obs.append(box((0.05, 0.05, 0.95), (x, -d / 2 - 1.1, 2.48), tuple(c * (0.85 + 0.1 * (j % 2)) for c in wood)))
    obs.append(box((0.12, 0.12, 2.6), (-w / 2 - 0.15, -d / 2 - 1.1, 3.2), wood))
    obs.append(box((0.12, 0.12, 2.6), (w / 2 + 0.15, -d / 2 - 1.1, 3.2), wood))
    door(obs, -1.2, -d / 2 - 0.02, 0.0, 1.0, 1.9, (0.36, 0.23, 0.14), (0.45, 0.43, 0.4))
    for p, f in (((1.4, -d / 2 - 0.15, 3.2), 'y-'), ((-1.4, -d / 2 - 0.15, 3.2), 'y-'), ((1.6, d / 2 + 0.15, 3.2), 'y+'),
                 ((w / 2 + 0.15, 1.6, 3.2), 'x+'), ((w / 2 + 0.15, -1.6, 3.2), 'x+'), ((-w / 2 - 0.15, 0, 3.2), 'x-'),
                 ((1.4, -d / 2 - 0.02, 1.15), 'y-')):
        window_set(obs, wins, p, f, size=(0.8, 0.95), frame=(0.9, 0.87, 0.8), sill=f != 'y-' or p[2] < 2)
    # Stone chimney with slate cap.
    obs.append(stone_wall((0.7, 0.7, 2.2), (1.4, 1.6, 5.9), (0.55, 0.53, 0.5), seed + 3, rough=0.02, rows=4))
    obs.append(box((0.95, 0.95, 0.1), (1.4, 1.6, 7.05), (0.3, 0.3, 0.32)))
    # Woodpile against the side wall.
    for j in range(14):
        lg = branch((w / 2 + 0.25, -2.6 + (j % 7) * 0.24, 0.15 + (j // 7) * 0.22), (w / 2 + 0.95, -2.6 + (j % 7) * 0.24, 0.15 + (j // 7) * 0.22), 0.1, 0.1, 6)
        paint(lg, (0.55, 0.4, 0.26), 0.1, j); obs.append(lg)
    finish(f"house_yayla_{seed}", obs, wins)


def ege_house(seed, tiled=True, blue=(0.15, 0.4, 0.75)):
    """Whitewashed Aegean house: rounded plaster, blue door/shutters, bougainvillea."""
    reset(); obs = []; wins = []
    rnd = random.Random(seed)
    w, d, h = 5.8, 6.4, 3.8
    white = (0.96, 0.95, 0.91)
    body = box((w, d, h + 0.6), (0, 0, h / 2 - 0.3), white, bevel=0.12)
    obs.append(body)
    obs.append(box((w + 0.06, d + 0.06, 0.55), (0, 0, -0.05), (0.55, 0.6, 0.66)))  # painted plinth
    if tiled:
        obs.append(tri_prism(w, d, 1.3, (0, 0, h - 0.02), white, seed))
        obs += tile_roof(w, d, 1.3, h - 0.02, (0.8, 0.4, 0.25), seed, overhang=0.35, rows=5)
    else:
        obs.append(box((w + 0.12, d + 0.12, 0.35), (0, 0, h + 0.12), white, bevel=0.08))
        dm = ico(0.85, 3, loc=(w * 0.22, d * 0.2, h + 0.95), scale=(1, 1, 0.85), name="dome")
        for v in dm.data.vertices:
            v.co.z = max(v.co.z, h + 0.95)
        paint(dm, blue); smooth_all([dm], True)
        obs.append(box((1.5, 1.5, 0.75), (w * 0.22, d * 0.2, h + 0.6), white, bevel=0.06))
        obs.append(dm)
        # Outside stair to the roof terrace.
        for j in range(8):
            obs.append(box((0.9, 0.38, 0.46 * (j + 1)), (w / 2 + 0.45, -d / 2 + 0.6 + j * 0.38, 0.23 * (j + 1) - 0.3), white))
    door(obs, -w * 0.2, -d / 2, -0.3, 1.0, 2.1, blue, white, arch=True)
    for p, f in (((w * 0.2, -d / 2 - 0.02, 1.6), 'y-'), ((-w / 2 - 0.02, 0.8, 1.6), 'x-'), ((w / 2 + 0.02, -0.6, 1.6), 'x+'),
                 ((0.6, d / 2 + 0.02, 1.6), 'y+')):
        window_set(obs, wins, p, f, size=(0.75, 0.9), frame=white, shutter=blue)
    # Bougainvillea over a wooden pergola post at the front corner.
    obs.append(box((0.12, 0.12, 3.0), (w * 0.42, -d / 2 - 0.9, 1.2), (0.42, 0.3, 0.2)))
    obs.append(box((w * 0.5, 0.12, 0.12), (w * 0.2, -d / 2 - 0.9, 2.7), (0.42, 0.3, 0.2)))
    for j in range(9):
        b = ico(rnd.uniform(0.35, 0.55), 2, loc=(w * 0.42 + rnd.uniform(-0.9, 0.3), -d / 2 - 0.55 + rnd.uniform(-0.4, 0.2), 1.6 + rnd.uniform(0, 1.4)), name="bloom")
        for v in b.data.vertices:
            v.co += v.normal * noise.noise(v.co * 4 + Vector((j, 0, 0))) * 0.12
        paint(b, (0.86, 0.2, 0.52), 0.15, j); obs.append(b)
    for j in range(3):  # potted plants by the door
        pot = cone(0.2, 0.26, 0.4, 10, loc=(-w * 0.2 - 1.0 + j * 0.45 if j < 2 else -w * 0.2 + 0.9, -d / 2 - 0.45, -0.3), name="pot")
        paint(pot, (0.72, 0.38, 0.24)); obs.append(pot)
        lf = ico(0.28, 2, loc=(pot.data.vertices[0].co.x * 0 + (-w * 0.2 - 1.0 + j * 0.45 if j < 2 else -w * 0.2 + 0.9), -d / 2 - 0.45, 0.35), name="leaf")
        paint(lf, (0.25, 0.48, 0.2), 0.12, j); obs.append(lf)
    finish(f"house_ege_{seed}", obs, wins)


def tuff_house(seed):
    """Kapadokya cut-stone house: ashlar walls, arched door, carved band, pigeon holes."""
    reset(); obs = []; wins = []
    rnd = random.Random(seed)
    w, d, h = 6.4, 6.8, 4.2
    stone = (0.9, 0.8, 0.66) if seed % 2 else (0.88, 0.72, 0.6)
    obs.append(stone_wall((w, d, h + 0.8), (0, 0, h / 2 - 0.4), stone, seed, rough=0.015))
    obs.append(box((w + 0.2, d + 0.2, 0.22), (0, 0, h - 0.6), tuple(c * 0.93 for c in stone), bevel=0.04))  # carved band
    for j in range(16):
        x = -w / 2 + 0.2 + j * (w - 0.4) / 15
        obs.append(box((0.12, 0.08, 0.12), (x, -d / 2 - 0.12, h - 0.6), tuple(c * 0.8 for c in stone)))
    obs.append(box((w + 0.25, d + 0.25, 0.4), (0, 0, h + 0.2), tuple(c * 0.96 for c in stone), bevel=0.05))  # parapet
    obs.append(box((w - 0.3, d - 0.3, 0.2), (0, 0, h + 0.32), (0.62, 0.52, 0.42)))  # earthen roof
    door(obs, 0.0, -d / 2, -0.1, 1.1, 2.2, (0.4, 0.26, 0.16), tuple(c * 0.86 for c in stone), arch=True)
    for x in (-2.0, 2.0):
        window_set(obs, wins, (x, -d / 2 - 0.02, 1.7), 'y-', size=(0.7, 1.0), frame=tuple(c * 0.85 for c in stone))
    window_set(obs, wins, (w / 2 + 0.02, 0.8, 1.7), 'x+', size=(0.7, 1.0), frame=tuple(c * 0.85 for c in stone))
    window_set(obs, wins, (-w / 2 - 0.02, -0.8, 1.7), 'x-', size=(0.7, 1.0), frame=tuple(c * 0.85 for c in stone))
    # Pigeon holes (güvercinlik) on the side, white-rimmed.
    for j in range(6):
        y = -2.2 + j * 0.85
        obs.append(box((0.08, 0.38, 0.38), (w / 2 + 0.01, y, h - 0.15), (0.94, 0.93, 0.9)))
        obs.append(box((0.1, 0.24, 0.26), (w / 2 + 0.03, y, h - 0.17), (0.12, 0.09, 0.08)))
    # Stone bench and pumpkins/apricots drying on the roof.
    obs.append(box((1.8, 0.45, 0.45), (2.0, -d / 2 - 0.4, 0.1), tuple(c * 0.9 for c in stone), bevel=0.05))
    for j in range(7):
        p = ico(0.16, 1, loc=(-2 + j * 0.45, 1.5, h + 0.5), scale=(1, 1, 0.8), name="dry")
        paint(p, (0.92, 0.55, 0.15), 0.12, j); obs.append(p)
    finish(f"house_tuff_{seed}", obs, wins)


def plateau_house(seed):
    """Eastern plateau house: rough stone, flat earthen roof on protruding poplar beams, tezek stack."""
    reset(); obs = []; wins = []
    rnd = random.Random(seed)
    w, d, h = 7.0, 5.8, 3.0
    obs.append(stone_wall((w, d, h + 0.8), (0, 0, h / 2 - 0.4), (0.5, 0.46, 0.42), seed, rough=0.07))
    for j in range(9):  # beam ends
        x = -w / 2 + 0.3 + j * (w - 0.6) / 8
        for s in (-1, 1):
            lg = branch((x, s * (d / 2 - 0.1), h + 0.05), (x, s * (d / 2 + 0.35), h + 0.05), 0.09, 0.08, 6)
            paint(lg, (0.5, 0.38, 0.26), 0.1, j); obs.append(lg)
    roof = box((w + 0.5, d + 0.5, 0.45), (0, 0, h + 0.32), (0.55, 0.45, 0.34), bevel=0.15)
    for v in roof.data.vertices:
        if v.co.z > h + 0.4:
            v.co.z += 0.12 * (1 - (abs(v.co.x) / (w / 2 + 0.3)) ** 2)
    paint(roof, (0.55, 0.45, 0.34), 0.05, seed); obs.append(roof)
    roller = branch((-0.6, 0, h + 0.75), (0.6, 0, h + 0.75), 0.22, 0.22, 10)  # stone roof roller
    paint(roller, (0.6, 0.58, 0.55)); obs.append(roller)
    door_col = (0.25, 0.35, 0.55) if seed % 2 == 0 else (0.45, 0.28, 0.18)
    door(obs, -1.4, -d / 2, -0.1, 1.0, 2.0, door_col, (0.42, 0.33, 0.24))
    window_set(obs, wins, (1.4, -d / 2 - 0.02, 1.4), 'y-', size=(0.8, 0.8), frame=(0.45, 0.35, 0.25), sill=False)
    window_set(obs, wins, (w / 2 + 0.02, 0, 1.4), 'x+', size=(0.7, 0.7), frame=(0.45, 0.35, 0.25), sill=False)
    # Tezek (dung-cake) pyramid stack beside the house.
    for lvl in range(6):
        n = 6 - lvl
        for j in range(n):
            cake = cone(0.24, 0.24, 0.1, 8, loc=(-w / 2 - 1.3 + (j - n / 2) * 0.32, 1.0, lvl * 0.2 + 0.0), name="tezek")
            cake.rotation_euler = (math.radians(70), 0, 0)
            mod(cake, 'TRIANGULATE')
            paint(cake, (0.36, 0.28, 0.2), 0.12, lvl * 10 + j); obs.append(cake)
    # Hay on the roof edge.
    hay = ico(0.9, 2, loc=(w * 0.25, d * 0.2, h + 0.75), scale=(1.2, 1, 0.6), name="hay")
    paint(hay, (0.8, 0.68, 0.38), 0.1); obs.append(hay)
    finish(f"house_plateau_{seed}", obs, wins)


# --- Kapadokya ---------------------------------------------------------------

TUFF = [(0.92, 0.84, 0.7), (0.88, 0.7, 0.58), (0.95, 0.9, 0.8), (0.86, 0.74, 0.54)]


def fairy_chimney(seed, carved):
    reset(); obs = []
    rnd = random.Random(seed)
    h = rnd.uniform(9.0, 14.0)
    br = rnd.uniform(2.6, 3.4) * h / 11
    neck = rnd.uniform(0.6, 0.9)
    prof = []
    for i in range(15):
        t = i / 14
        r = br + (neck - br) * t ** 0.55 + 0.25 * math.exp(-((t - 0.03) / 0.06) ** 2)
        prof.append((r * 1.15 if i == 0 else r, -0.6 + t * (h + 0.6)))
    body = lathe(prof, 28, "chimney", wobble=0.18, seed=seed, flute=0.08, flutes=rnd.choice((5, 7, 9)))
    sub_z = {}

    def band(c, n):
        zz = c.z + noise.noise(Vector((c.x * 0.4, c.y * 0.4, seed))) * 0.5
        f = zz / 1.6 + seed
        i0 = int(math.floor(f)); t = f - i0; t = t * t * (3 - 2 * t)
        c0 = TUFF[i0 % len(TUFF)]; c1 = TUFF[(i0 + 1) % len(TUFF)]
        b = tuple((c0[q] + (c1[q] - c0[q]) * t) * 0.55 + TUFF[0][q] * 0.45 for q in range(3))
        k = 1.0 - 0.25 * max(0.0, -n.z) - 0.08 * (1 - min(1, c.z / 2))
        return tuple(ch * k for ch in b)
    paint_fn(body, band)
    smooth_all([body], True)
    obs.append(body)
    # Basalt cap: flattened, overhanging, faceted.
    cap = ico(neck * 2.0, 2, loc=(0, 0, h + 0.35), scale=(1, 0.9, 0.5), name="cap")
    for v in cap.data.vertices:
        v.co += v.normal * noise.noise(v.co * 1.6 + Vector((seed, 0, 0))) * 0.25
    paint(cap, (0.28, 0.22, 0.2), 0.12, seed); obs.append(cap)
    neck_ob = cone(neck * 1.05, neck * 1.3, 0.5, 12, loc=(0, 0, h - 0.2), name="neck")
    paint(neck_ob, (0.6, 0.5, 0.42)); obs.append(neck_ob)
    if carved:
        a = rnd.uniform(0, math.tau)
        rr = br * 0.92
        dr = box((0.95, 0.6, 1.8), (math.cos(a) * rr, math.sin(a) * rr, 0.9), (0.14, 0.1, 0.08), rot=(0, 0, a + math.pi / 2))
        obs.append(dr)
        for k in range(3):
            wa = a + rnd.uniform(-1.3, 1.3)
            wz = rnd.uniform(0.25, 0.55) * h
            t = (wz + 0.6) / (h + 0.6)
            wr = (br + (neck - br) * t ** 0.55) * 0.9
            obs.append(box((0.55, 0.5, 0.7), (math.cos(wa) * wr, math.sin(wa) * wr, wz), (0.14, 0.1, 0.08), rot=(0, 0, wa + math.pi / 2)))
    finish(f"fairy_chimney_{seed}", obs, None)


def nomad_tent(seed):
    """Kıl çadır: black goat-hair tent with sagging roof between poles, reed walls, kilim."""
    reset(); obs = []
    w, d = 7.0, 4.6
    poles = [-2.8, -1.4, 0, 1.4, 2.8]
    # Roof cloth: grid with sag between poles.
    b = bmesh.new()
    nx, ny = 28, 14
    vs = []
    for i in range(nx + 1):
        row = []
        for j in range(ny + 1):
            x = -w / 2 + w * i / nx
            y = -d / 2 + d * j / ny
            ridge = 2.3 - 0.35 * min(abs(x - p) for p in poles) / 0.7
            z = 1.0 + (ridge - 1.0) * (1 - abs(y) / (d / 2)) ** 1.1
            row.append(b.verts.new((x, y, z)))
        vs.append(row)
    for i in range(nx):
        for j in range(ny):
            b.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
    roof = obj_from_bm(b, "roof")
    mod(roof, 'SOLIDIFY', thickness=0.05)
    paint_fn(roof, lambda c, n: (0.15, 0.12, 0.11) if int((c.x + 10) / 0.7) % 2 else (0.2, 0.16, 0.14))
    obs.append(roof)
    for x in poles:
        obs.append(box((0.09, 0.09, 2.4), (x, 0, 1.2), (0.45, 0.35, 0.25)))
    reed = (0.72, 0.62, 0.42)
    for (sz, loc) in (((w - 0.2, 0.05, 1.0), (0, d / 2 - 0.05, 0.5)), ((0.05, d - 0.2, 1.0), (-w / 2 + 0.05, 0, 0.5)), ((0.05, d - 0.2, 1.0), (w / 2 - 0.05, 0, 0.5))):
        r = box(sz, loc, reed, cuts=6)
        paint_fn(r, lambda c, n: (0.74, 0.63, 0.42) if int((c.x + c.y + 10) / 0.18) % 2 else (0.64, 0.54, 0.36))
        obs.append(r)
    # Kilim rug in front, rolled one beside it.
    k = box((2.6, 1.6, 0.03), (0, -d / 2 - 1.0, 0.02), (0.7, 0.18, 0.15), cuts=6)
    paint_fn(k, lambda c, n: [(0.72, 0.18, 0.15), (0.9, 0.7, 0.3), (0.2, 0.25, 0.45)][int(abs(c.x) / 0.25 + abs(c.y + d / 2 + 1.0) / 0.25) % 3])
    obs.append(k)
    roll = branch((-2.6, -d / 2 - 0.4, 0.2), (-1.0, -d / 2 - 0.4, 0.2), 0.2, 0.2, 10)
    paint(roll, (0.72, 0.18, 0.15)); obs.append(roll)
    for side in (-1, 1):
        for x in (-w * 0.4, 0, w * 0.4):
            p0 = Vector((x, side * d / 2, 1.0)); p1 = Vector((x * 1.1, side * (d / 2 + 1.7), 0.0))
            rp = branch(p0, p1, 0.02, 0.02, 4); paint(rp, (0.6, 0.55, 0.45)); obs.append(rp)
            obs.append(box((0.06, 0.06, 0.35), tuple(p1 + Vector((0, 0, 0.1))), (0.45, 0.35, 0.25)))
    # Copper pot on a stone hearth.
    for j in range(6):
        a = j / 6 * math.tau
        st = ico(0.13, 1, loc=(2.2 + math.cos(a) * 0.4, -d / 2 - 1.2 + math.sin(a) * 0.4, 0.06), name="st")
        paint(st, (0.5, 0.48, 0.45), 0.1, j); obs.append(st)
    pot = ico(0.25, 2, loc=(2.2, -d / 2 - 1.2, 0.3), scale=(1, 1, 0.8), name="pot")
    paint(pot, (0.72, 0.4, 0.22)); smooth_all([pot], True); obs.append(pot)
    finish(f"nomad_tent_{seed}", obs, None)


# --- Coast ---------------------------------------------------------------------

def boat(seed, hull_col):
    """Kayık: lofted double-ended hull (bow +Y), white topsides, coloured band, wheelhouse."""
    reset(); obs = []
    L, B, D = 5.4, 1.9, 0.95
    b = bmesh.new()
    nsec, nper = 16, 10
    rings = []
    for i in range(nsec + 1):
        t = i / nsec  # 0 stern, 1 bow
        y = -L / 2 + L * t
        beam = B / 2 * (math.sin(math.pi * (0.08 + 0.84 * t)) ** 0.7)
        sheer = D + 0.25 * (2 * t - 1) ** 2 + 0.15 * max(0, t - 0.7) / 0.3
        keel = 0.08 * (1 - abs(2 * t - 1) ** 3)
        ring = []
        for k in range(nper + 1):
            u = k / nper  # 0 port gunwale -> 1 starboard gunwale
            a = math.pi * u
            x = -math.cos(a) * beam
            z = keel + (sheer - keel) * (1 - math.sin(a) ** 1.6)
            ring.append(b.verts.new((x, y, z)))
        rings.append(ring)
    for i in range(nsec):
        for k in range(nper):
            b.faces.new((rings[i][k], rings[i + 1][k], rings[i + 1][k + 1], rings[i][k + 1]))
    bmesh.ops.remove_doubles(b, verts=b.verts, dist=1e-3)
    hull = obj_from_bm(b, "hull")
    mod(hull, 'SOLIDIFY', thickness=0.06)
    bottom = (0.6, 0.18, 0.14)
    paint_fn(hull, lambda c, n: bottom if c.z < 0.28 else (hull_col if c.z < 0.62 else (0.95, 0.94, 0.9)) if n.z < 0.6 or abs(c.x) > 0.6 else (0.55, 0.4, 0.26))
    smooth_all([hull], True)
    obs.append(hull)
    # Gunwale rail, deck boards, thwarts, stem post.
    for side in (-1, 1):
        pts = [(side * B / 2 * (math.sin(math.pi * (0.08 + 0.84 * t)) ** 0.7), -L / 2 + L * t, D + 0.25 * (2 * t - 1) ** 2 + 0.15 * max(0, t - 0.7) / 0.3) for t in [i / 12 for i in range(13)]]
        for p0, p1 in zip(pts, pts[1:]):
            r = branch(p0, p1, 0.05, 0.05, 5); paint(r, (0.45, 0.32, 0.2)); obs.append(r)
    obs.append(box((B * 0.82, L * 0.78, 0.05), (0, 0, 0.5), (0.58, 0.43, 0.28), cuts=0))
    for y in (-1.2, 0.2, 1.4):
        obs.append(box((B * 0.82, 0.22, 0.06), (0, y, 0.8), (0.62, 0.46, 0.3)))
    stem = branch((0, L / 2 - 0.05, 0.1), (0, L / 2 + 0.15, D + 0.65), 0.07, 0.05, 6); paint(stem, (0.45, 0.32, 0.2)); obs.append(stem)
    # Wheelhouse aft.
    obs.append(box((1.1, 1.1, 1.0), (0, -1.5, 1.0), (0.95, 0.94, 0.9), bevel=0.04))
    obs.append(box((1.3, 1.3, 0.1), (0, -1.5, 1.55), hull_col, bevel=0.03))
    for y in (-0.94,):
        obs.append(box((0.8, 0.04, 0.4), (0, y, 1.15), (0.15, 0.2, 0.25)))
    # Mast, boom, furled tarp, net pile, tyre fenders.
    obs.append(box((0.08, 0.08, 2.6), (0, 0.9, 1.8), (0.42, 0.3, 0.2)))
    obs.append(box((0.06, 1.6, 0.06), (0, 0.4, 1.4), (0.42, 0.3, 0.2)))
    tarp = ico(0.4, 2, loc=(0, 0.4, 1.35), scale=(0.5, 2.0, 0.35), name="tarp"); paint(tarp, (0.85, 0.82, 0.72)); obs.append(tarp)
    net = ico(0.55, 2, loc=(0.1, 1.5, 0.8), scale=(1, 1.2, 0.45), name="net")
    for v in net.data.vertices:
        v.co += v.normal * noise.noise(v.co * 5) * 0.08
    paint(net, (0.3, 0.45, 0.5), 0.15); obs.append(net)
    for j in range(5):
        fl = ico(0.07, 1, loc=(0.3 + j * 0.05, 1.3 + j * 0.1, 1.05), name="float"); paint(fl, (0.95, 0.5, 0.15)); obs.append(fl)
    for side in (-1, 1):
        for y in (-0.8, 0.6):
            ty = lathe([(0.17, -0.06), (0.22, 0), (0.17, 0.06)], 12, "tyre")
            ty.rotation_euler = (0, math.pi / 2, 0)
            ty.location = (side * (B / 2 + 0.06), y, 0.75)
            bpy_apply(ty)
            paint(ty, (0.1, 0.1, 0.1)); obs.append(ty)
    finish(f"boat_{seed}", obs, None)


def bpy_apply(ob):
    import bpy
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


if __name__ == "__main__":
    yayla_house(1, wood=(0.56, 0.38, 0.24), roof=(0.62, 0.26, 0.18))
    yayla_house(2, wood=(0.48, 0.32, 0.2), roof=(0.38, 0.4, 0.43))
    ege_house(1, True, (0.15, 0.4, 0.75))
    ege_house(2, False, (0.12, 0.32, 0.62))
    tuff_house(1)
    tuff_house(2)
    plateau_house(1)
    plateau_house(2)
    for s in (1, 2, 3, 4):
        fairy_chimney(s, s % 2 == 1)
    nomad_tent(1)
    boat(1, (0.2, 0.45, 0.75))
    boat(2, (0.8, 0.25, 0.2))
    boat(3, (0.25, 0.6, 0.45))
    boat(4, (0.95, 0.75, 0.25))
