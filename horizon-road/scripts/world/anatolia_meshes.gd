class_name AnatoliaMeshes
extends RefCounted
## Meshes for the inland regions (Kapadokya, Doğu Anadolu): fairy chimneys,
## hot-air balloons, tuff and stone houses, steppe trees, nomad tents, sheep.
## Same flat-shaded vertex-colour language as LowPolyMeshes.



## Revolves a (radius, height) profile around Y. `color_at(t, seg)` gives the
## colour of each band; faces are wound outwards whatever the profile order.
static func lathe(b: LowPolyMeshes.Builder, profile: PackedVector2Array, segments: int, origin: Vector3,
		color_at: Callable, jitter: float = 0.0, squash: Vector3 = Vector3.ONE) -> void:
	var rings: Array[PackedVector3Array] = []
	for pi: int in profile.size():
		var ring := PackedVector3Array()
		for s: int in segments:
			var a: float = TAU * s / segments
			var r: float = profile[pi].x
			if jitter > 0.0 and r > 0.01:
				r *= 1.0 + b.rng.randf_range(-jitter, jitter)
			ring.append(origin + Vector3(cos(a) * r * squash.x, profile[pi].y * squash.y, sin(a) * r * squash.z))
		rings.append(ring)
	for pi: int in profile.size() - 1:
		var t: float = float(pi) / maxf(profile.size() - 2, 1)
		for s: int in segments:
			var s2: int = (s + 1) % segments
			var col: Color = color_at.call(t, s)
			var axis_y: float = origin.y + (profile[pi].y + profile[pi + 1].y) * 0.5 * squash.y
			var centre := Vector3(origin.x, axis_y, origin.z)
			_tri_out(b, rings[pi][s], rings[pi + 1][s], rings[pi + 1][s2], centre, col)
			_tri_out(b, rings[pi][s], rings[pi + 1][s2], rings[pi][s2], centre, col)


static func _tri_out(b: LowPolyMeshes.Builder, p0: Vector3, p1: Vector3, p2: Vector3, centre: Vector3, col: Color) -> void:
	if (p0 - p1).length_squared() < 1e-8 and (p1 - p2).length_squared() < 1e-8:
		return
	var n: Vector3 = (p2 - p0).cross(p1 - p0)
	if n.length_squared() < 1e-10:
		return
	if n.dot((p0 + p1 + p2) / 3.0 - centre) < 0.0:
		b.tri(p0, p2, p1, col)
	else:
		b.tri(p0, p1, p2, col)


# --- Kapadokya ---------------------------------------------------------------

const TUFF_BANDS: Array[Color] = [
	Color(0.9, 0.82, 0.68), Color(0.86, 0.68, 0.58), Color(0.93, 0.88, 0.78), Color(0.84, 0.72, 0.52),
]


## Peri bacası: a tapering tuff cone with a dark basalt cap; some have doors
## and windows cut into them.
static func fairy_chimney(seed_value: int, carved: bool) -> ArrayMesh:
	var b := LowPolyMeshes.Builder.new(seed_value)
	var h: float = b.rng.randf_range(7.0, 16.0)
	var base_r: float = b.rng.randf_range(2.2, 3.6) * h / 11.0
	var neck: float = b.rng.randf_range(0.55, 0.95) * clampf(h / 10.0, 0.8, 1.3)
	var prof := PackedVector2Array()
	var steps: int = 9
	for i: int in steps + 1:
		var t: float = float(i) / steps
		# Flared foot, long slender taper, a slight pinch under the cap.
		var r: float = lerpf(base_r, neck, pow(t, 0.55)) * (1.0 + 0.35 * pow(1.0 - t, 6.0))
		if t > 0.85:
			r *= 0.92
		prof.append(Vector2(r, t * h - 0.6))
	var band_offset: int = b.rng.randi() % 4
	lathe(b, prof, 9, Vector3.ZERO, func(t: float, _s: int) -> Color:
		return TUFF_BANDS[(int(t * 5.0) + band_offset) % TUFF_BANDS.size()], 0.08)
	# Basalt cap: a flattened, slightly tilted hat.
	var cap_r: float = neck * b.rng.randf_range(1.4, 1.9)
	var cap := PackedVector2Array([Vector2(0.0, 0.0), Vector2(cap_r, 0.25), Vector2(cap_r * 0.95, 0.75), Vector2(cap_r * 0.5, 1.35), Vector2(0.0, 1.6)])
	var basalt := Color(0.36, 0.3, 0.27)
	var cap_b := LowPolyMeshes.Builder.new(seed_value + 7)
	lathe(cap_b, cap, 8, Vector3.ZERO, func(_t: float, _s: int) -> Color: return basalt, 0.1)
	var tilt := Basis(Vector3(b.rng.randf_range(-1, 1), 0, b.rng.randf_range(-1, 1)).normalized(), b.rng.randf_range(0.0, 0.18))
	var cap_mesh: ArrayMesh = cap_b.commit()
	b.st.append_from(cap_mesh, 0, Transform3D(tilt, Vector3(0, h - 0.75, 0)))
	if carved:
		var dark := Color(0.16, 0.12, 0.1)
		var door_a: float = b.rng.randf() * TAU
		var door_r: float = lerpf(base_r, neck, pow(0.08, 0.55)) * 1.1
		b.add(LowPolyMeshes._box(Vector3(0.9, 1.7, 0.3)), Transform3D(Basis(Vector3.UP, -door_a + PI * 0.5), Vector3(cos(door_a) * (door_r - 0.05), 0.55, sin(door_a) * (door_r - 0.05))), dark)
		for k: int in b.rng.randi_range(2, 4):
			var wa: float = door_a + b.rng.randf_range(-1.2, 1.2)
			var wy: float = b.rng.randf_range(0.25, 0.6) * h
			var wr: float = lerpf(base_r, neck, pow(wy / h, 0.55)) * 0.98
			b.add(LowPolyMeshes._box(Vector3(0.5, 0.7, 0.3)), Transform3D(Basis(Vector3.UP, -wa + PI * 0.5), Vector3(cos(wa) * wr, wy, sin(wa) * wr)), dark)
	return b.commit(LowPolyMeshes.vertex_color_material(0.95))


## Hot-air balloon: striped gores, wicker basket, ropes. Origin at the basket floor.
static func balloon(seed_value: int, colors: Array[Color]) -> ArrayMesh:
	var b := LowPolyMeshes.Builder.new(seed_value)
	var env := PackedVector2Array([
		Vector2(0.55, 0.0), Vector2(1.4, 0.7), Vector2(2.9, 2.2), Vector2(3.9, 4.0), Vector2(4.25, 5.8),
		Vector2(4.0, 7.4), Vector2(3.2, 8.7), Vector2(1.8, 9.6), Vector2(0.0, 9.95),
	])
	lathe(b, env, 16, Vector3(0, 3.2, 0), func(t: float, s: int) -> Color:
		var c: Color = colors[s % colors.size()]
		# A contrasting crown band near the top.
		return c.lightened(0.15) if t > 0.8 and s % 2 == 0 else c, 0.0)
	var wicker := Color(0.55, 0.4, 0.24)
	b.add(LowPolyMeshes._box(Vector3(1.15, 0.95, 1.15)), LowPolyMeshes._at(Vector3(0, 0.48, 0)), wicker, 0.0, 0.05)
	b.add(LowPolyMeshes._box(Vector3(1.25, 0.1, 1.25)), LowPolyMeshes._at(Vector3(0, 0.97, 0)), wicker.darkened(0.25))
	b.add(LowPolyMeshes._box(Vector3(0.45, 0.35, 0.45)), LowPolyMeshes._at(Vector3(0, 2.6, 0)), Color(0.25, 0.25, 0.27))
	for c: Vector2 in [Vector2(-0.55, -0.55), Vector2(0.55, -0.55), Vector2(-0.55, 0.55), Vector2(0.55, 0.55)]:
		var from := Vector3(c.x, 1.0, c.y)
		var to := Vector3(c.x * 0.75, 3.2, c.y * 0.75)
		var mid: Vector3 = (from + to) * 0.5
		var len: float = from.distance_to(to)
		b.add(LowPolyMeshes._box(Vector3(0.03, len, 0.03)), Transform3D(Basis(Quaternion(Vector3.UP, (to - from).normalized())), mid), Color(0.3, 0.26, 0.22))
	return b.commit(LowPolyMeshes.vertex_color_material(0.6))


## Kesme taş (cut tuff) house: cubic, flat roof with a low parapet, arched
## door, dovecote holes under the eaves. Same dictionary as LowPolyMeshes.ege_house.
static func tuff_house(seed_value: int) -> Dictionary:
	var b := LowPolyMeshes.Builder.new(seed_value)
	var stone: Color = TUFF_BANDS[seed_value % TUFF_BANDS.size()].lerp(Color(0.9, 0.84, 0.72), 0.4)
	var w: float = b.rng.randf_range(5.0, 7.0)
	var d: float = b.rng.randf_range(5.5, 7.5)
	var h: float = b.rng.randf_range(3.6, 4.8)
	b.add(LowPolyMeshes._box(Vector3(w, h, d)), LowPolyMeshes._at(Vector3(0, h * 0.5 - 0.3, 0)), stone, 0.02, 0.03)
	b.add(LowPolyMeshes._box(Vector3(w + 0.2, 0.25, d + 0.2)), LowPolyMeshes._at(Vector3(0, h - 0.3, 0)), stone.darkened(0.06))
	for side: float in [-1.0, 1.0]:
		b.add(LowPolyMeshes._box(Vector3(w + 0.2, 0.5, 0.25)), LowPolyMeshes._at(Vector3(0, h + 0.05, side * (d * 0.5))), stone.darkened(0.03))
		b.add(LowPolyMeshes._box(Vector3(0.25, 0.5, d + 0.2)), LowPolyMeshes._at(Vector3(side * w * 0.5, h + 0.05, 0)), stone.darkened(0.03))
	if seed_value % 2 == 0:
		# Upper room set back on the roof terrace.
		var w2: float = w * 0.5
		b.add(LowPolyMeshes._box(Vector3(w2, 2.6, d * 0.55)), LowPolyMeshes._at(Vector3(-w * 0.2, h + 1.0, d * 0.15)), stone.lightened(0.03), 0.02)
		b.add(LowPolyMeshes._box(Vector3(w2 + 0.15, 0.2, d * 0.55 + 0.15)), LowPolyMeshes._at(Vector3(-w * 0.2, h + 2.35, d * 0.15)), stone.darkened(0.06))
	# Arched door and a wooden lintel.
	var door := Color(0.36, 0.22, 0.14)
	b.add(LowPolyMeshes._box(Vector3(1.2, 1.7, 0.1)), LowPolyMeshes._at(Vector3(w * 0.15, 0.55, -d * 0.5 - 0.04)), door)
	b.add(LowPolyMeshes._cone(0.6, 0.6, 0.1, 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(w * 0.15, 1.4, -d * 0.5 - 0.04)), door)
	b.add(LowPolyMeshes._box(Vector3(1.8, 0.18, 0.2)), LowPolyMeshes._at(Vector3(w * 0.15, 2.15, -d * 0.5 - 0.08)), stone.darkened(0.15))
	# Dovecote holes (güvercinlik), whitewashed rims.
	for k: int in 4:
		var x: float = -w * 0.35 + k * 0.45
		b.add(LowPolyMeshes._box(Vector3(0.3, 0.3, 0.06)), LowPolyMeshes._at(Vector3(x, h - 0.85, -d * 0.5 - 0.03)), Color(0.95, 0.93, 0.88))
		b.add(LowPolyMeshes._box(Vector3(0.16, 0.18, 0.08)), LowPolyMeshes._at(Vector3(x, h - 0.88, -d * 0.5 - 0.05)), Color(0.1, 0.08, 0.07))
	var wb := LowPolyMeshes.Builder.new(seed_value + 1)
	for p: Vector3 in [Vector3(-w * 0.25, 1.5, -d * 0.5 - 0.04), Vector3(-w * 0.5 - 0.04, 1.5, 0.6), Vector3(w * 0.5 + 0.04, 1.5, -0.4)]:
		var size := Vector3(0.75, 0.95, 0.06) if absf(p.z) > absf(p.x) else Vector3(0.06, 0.95, 0.75)
		wb.add(LowPolyMeshes._box(size), LowPolyMeshes._at(p), Color.WHITE)
		b.add(LowPolyMeshes._box(size * Vector3(1.3, 0.25, 1.3) + Vector3(0, 0, 0)), LowPolyMeshes._at(p + Vector3(0, 0.6, 0)), stone.darkened(0.12))
	return {"body": b.commit(LowPolyMeshes.vertex_color_material(0.9)), "windows": wb.commit(), "size": Vector3(w, h, d)}


## Lombardy poplar: tall narrow column, the signature tree of Anatolian valleys.
static func poplar(seed_value: int = 400) -> ArrayMesh:
	var b := LowPolyMeshes.Builder.new(seed_value)
	b.add(LowPolyMeshes._cone(0.2, 0.12, 2.0, 6), LowPolyMeshes._at(Vector3(0, 1.0, 0)), Color(0.55, 0.52, 0.45))
	var leaf := Color(0.42, 0.56, 0.2)
	b.add(LowPolyMeshes._sphere(1.0, 10.0, 8, 6), LowPolyMeshes._at(Vector3(0, 6.6, 0)), leaf, 0.12, 0.1)
	b.add(LowPolyMeshes._sphere(0.7, 4.0, 7, 3), LowPolyMeshes._at(Vector3(0.3, 9.6, 0.1)), leaf.lightened(0.05), 0.1, 0.1)
	return b.commit(LowPolyMeshes.foliage_material(0.08, 11.0, 0.35))


## Apricot / walnut orchard tree: short trunk, round crown.
static func apricot(seed_value: int = 401) -> ArrayMesh:
	var b := LowPolyMeshes.Builder.new(seed_value)
	b.add(LowPolyMeshes._cone(0.18, 0.12, 1.4, 6), Transform3D(Basis(Vector3.FORWARD, 0.08), Vector3(0, 0.7, 0)), Color(0.4, 0.3, 0.22))
	var leaf := Color(0.32, 0.48, 0.18)
	for i: int in 4:
		var p := Vector3(b.rng.randf_range(-0.7, 0.7), b.rng.randf_range(1.9, 2.5), b.rng.randf_range(-0.7, 0.7))
		b.add(LowPolyMeshes._sphere(0.9, 1.3, 7, 3), LowPolyMeshes._at(p), leaf.lightened(b.rng.randf_range(-0.05, 0.08)), 0.15, 0.1)
	return b.commit(LowPolyMeshes.foliage_material(0.06, 3.0, 0.3))


## Low bush vine (bağ) grown without wires, as in Kapadokya.
static func vine(seed_value: int = 402) -> ArrayMesh:
	var b := LowPolyMeshes.Builder.new(seed_value)
	b.add(LowPolyMeshes._cone(0.06, 0.05, 0.4, 5), LowPolyMeshes._at(Vector3(0, 0.2, 0)), Color(0.4, 0.3, 0.22))
	b.add(LowPolyMeshes._sphere(0.6, 0.65, 7, 3), LowPolyMeshes._at(Vector3(0, 0.55, 0)), Color(0.36, 0.5, 0.2), 0.12, 0.12)
	return b.commit(LowPolyMeshes.foliage_material(0.04, 1.0, 0.3))


## Grey-green steppe cushion (geven, kekik).
static func steppe_bush(seed_value: int = 403) -> ArrayMesh:
	var b := LowPolyMeshes.Builder.new(seed_value)
	for i: int in 3:
		var p := Vector3(b.rng.randf_range(-0.3, 0.3), 0.0, b.rng.randf_range(-0.3, 0.3))
		b.add(LowPolyMeshes._sphere(0.45, 0.5, 6, 3), LowPolyMeshes._at(p + Vector3(0, 0.15, 0)), Color(0.5, 0.52, 0.36).lightened(b.rng.randf_range(-0.05, 0.05)), 0.1, 0.1)
	return b.commit(LowPolyMeshes.foliage_material(0.03, 0.6, 0.2))


## Potter's kick wheel with a stool and a stack of pots.
static func pottery_wheel() -> ArrayMesh:
	var b := LowPolyMeshes.Builder.new(404)
	var wood := Color(0.5, 0.36, 0.22)
	b.add(LowPolyMeshes._box(Vector3(1.2, 0.08, 1.0)), LowPolyMeshes._at(Vector3(0, 0.75, 0)), wood)
	for x: float in [-0.5, 0.5]:
		for z: float in [-0.4, 0.4]:
			b.add(LowPolyMeshes._box(Vector3(0.08, 0.75, 0.08)), LowPolyMeshes._at(Vector3(x, 0.37, z)), wood.darkened(0.1))
	b.add(LowPolyMeshes._cone(0.45, 0.45, 0.08, 14), LowPolyMeshes._at(Vector3(0, 0.12, 0)), wood.darkened(0.2))
	b.add(LowPolyMeshes._cone(0.03, 0.03, 0.7, 6), LowPolyMeshes._at(Vector3(0, 0.45, 0)), Color(0.3, 0.3, 0.3))
	b.add(LowPolyMeshes._cone(0.3, 0.3, 0.06, 14), LowPolyMeshes._at(Vector3(0, 0.82, 0)), Color(0.45, 0.42, 0.4))
	b.add(LowPolyMeshes._cone(0.2, 0.24, 0.3, 10), LowPolyMeshes._at(Vector3(0, 1.0, 0)), Color(0.7, 0.38, 0.26))
	var clay := Color(0.74, 0.4, 0.26)
	for i: int in 5:
		var p := Vector3(1.0 + (i % 3) * 0.45, 0.0, -0.4 + (i / 3) * 0.5)
		var pot := PackedVector2Array([Vector2(0.12, 0), Vector2(0.2, 0.12), Vector2(0.22, 0.28), Vector2(0.12, 0.45), Vector2(0.1, 0.55), Vector2(0.0, 0.55)])
		lathe(b, pot, 8, p, func(_t: float, _s: int) -> Color: return clay.lightened((i % 2) * 0.08), 0.0)
	return b.commit(LowPolyMeshes.vertex_color_material(0.85))


# --- Doğu Anadolu --------------------------------------------------------------

## Göçer çadırı: black goat-hair tent with a ridge and guy ropes.
static func nomad_tent(seed_value: int = 500) -> ArrayMesh:
	var b := LowPolyMeshes.Builder.new(seed_value)
	var hair := Color(0.16, 0.13, 0.12)
	var w: float = 7.0
	var d: float = 4.6
	var ridge: float = 2.3
	var eave: float = 1.0
	for z0: float in [-d * 0.5]:
		var fl := Vector3(-w * 0.5, eave, z0)
		var fr := Vector3(w * 0.5, eave, z0)
		var bl := Vector3(-w * 0.5, eave, -z0)
		var br := Vector3(w * 0.5, eave, -z0)
		var tl := Vector3(-w * 0.45, ridge, 0)
		var tr := Vector3(w * 0.45, ridge, 0)
		var c := Vector3(0, 1.4, 0)
		_tri_out(b, fl, fr, tr, c, hair); _tri_out(b, fl, tr, tl, c, hair)
		_tri_out(b, bl, br, tr, c, hair.lightened(0.04)); _tri_out(b, bl, tr, tl, c, hair.lightened(0.04))
		_tri_out(b, fl, bl, tl, c, hair); _tri_out(b, fr, br, tr, c, hair)
	# Side walls of woven reed, kilim rolled at the front.
	var reed := Color(0.72, 0.62, 0.42)
	b.add(LowPolyMeshes._box(Vector3(w - 0.2, 1.0, 0.06)), LowPolyMeshes._at(Vector3(0, 0.5, d * 0.5 - 0.05)), reed)
	b.add(LowPolyMeshes._box(Vector3(0.06, 1.0, d - 0.2)), LowPolyMeshes._at(Vector3(-w * 0.5 + 0.05, 0.5, 0)), reed)
	b.add(LowPolyMeshes._box(Vector3(0.06, 1.0, d - 0.2)), LowPolyMeshes._at(Vector3(w * 0.5 - 0.05, 0.5, 0)), reed)
	b.add(LowPolyMeshes._cone(0.2, 0.2, 2.2, 8), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-1.5, 0.2, -d * 0.5 - 0.4)), Color(0.72, 0.18, 0.15))
	for x: float in [-w * 0.45, 0.0, w * 0.45]:
		b.add(LowPolyMeshes._box(Vector3(0.08, ridge + 0.3, 0.08)), LowPolyMeshes._at(Vector3(x, (ridge + 0.3) * 0.5, 0)), Color(0.45, 0.35, 0.25))
	for side: float in [-1.0, 1.0]:
		for x: float in [-w * 0.4, w * 0.4]:
			var from := Vector3(x, eave, side * d * 0.5)
			var to := Vector3(x * 1.1, 0.0, side * (d * 0.5 + 1.6))
			var mid: Vector3 = (from + to) * 0.5
			b.add(LowPolyMeshes._box(Vector3(0.03, 0.03, from.distance_to(to))), Transform3D(Basis.looking_at(to - from, Vector3.UP), mid), Color(0.6, 0.55, 0.45))
	return b.commit(LowPolyMeshes.vertex_color_material(0.95))


## Flat-roofed stone/earth house of the eastern plateau, with a dung-cake stack (tezek).
static func plateau_house(seed_value: int) -> Dictionary:
	var b := LowPolyMeshes.Builder.new(seed_value)
	var stone := Color(0.6, 0.55, 0.48).lerp(Color(0.52, 0.47, 0.42), (seed_value % 3) * 0.3)
	var w: float = b.rng.randf_range(6.0, 8.0)
	var d: float = b.rng.randf_range(5.0, 6.5)
	var h: float = b.rng.randf_range(2.8, 3.3)
	b.add(LowPolyMeshes._box(Vector3(w, h, d)), LowPolyMeshes._at(Vector3(0, h * 0.5 - 0.3, 0)), stone, 0.03, 0.05)
	# Earth roof with a slight overhang, grass growing on it.
	b.add(LowPolyMeshes._box(Vector3(w + 0.5, 0.35, d + 0.5)), LowPolyMeshes._at(Vector3(0, h - 0.15, 0)), Color(0.5, 0.42, 0.32))
	b.add(LowPolyMeshes._box(Vector3(w + 0.3, 0.12, d + 0.3)), LowPolyMeshes._at(Vector3(0, h + 0.08, 0)), Color(0.45, 0.5, 0.28), 0.02)
	b.add(LowPolyMeshes._box(Vector3(0.5, 0.9, 0.5)), LowPolyMeshes._at(Vector3(w * 0.3, h + 0.5, 0.5)), stone.darkened(0.1))
	var door := Color(0.25, 0.35, 0.55) if seed_value % 2 == 0 else Color(0.45, 0.28, 0.18)
	b.add(LowPolyMeshes._box(Vector3(1.1, 1.9, 0.1)), LowPolyMeshes._at(Vector3(-w * 0.2, 0.65, -d * 0.5 - 0.04)), door)
	# Tezek stack beside the house.
	for k: int in 6:
		b.add(LowPolyMeshes._cone(0.35, 0.35, 0.12, 8), LowPolyMeshes._at(Vector3(w * 0.5 + 0.9, 0.06 + k * 0.13, -d * 0.2), b.rng.randf()), Color(0.35, 0.28, 0.2))
	var wb := LowPolyMeshes.Builder.new(seed_value + 1)
	for p: Vector3 in [Vector3(w * 0.2, 1.4, -d * 0.5 - 0.04), Vector3(w * 0.5 + 0.04, 1.4, 0.5)]:
		var size := Vector3(0.7, 0.7, 0.06) if absf(p.z) > absf(p.x) else Vector3(0.06, 0.7, 0.7)
		wb.add(LowPolyMeshes._box(size), LowPolyMeshes._at(p), Color.WHITE)
	return {"body": b.commit(LowPolyMeshes.vertex_color_material(0.95)), "windows": wb.commit(), "size": Vector3(w, h, d)}


## Woolly sheep (Akkaraman): fluffy body, dark face and legs. Faces -Z.
static func sheep(seed_value: int = 510) -> ArrayMesh:
	var b := LowPolyMeshes.Builder.new(seed_value)
	var wool := Color(0.9, 0.87, 0.8)
	b.add(LowPolyMeshes._sphere(0.42, 0.62, 8, 4), LowPolyMeshes._at(Vector3(0, 0.62, 0), 0.0, Vector3(1.0, 1.0, 1.45)), wool, 0.04, 0.03)
	b.add(LowPolyMeshes._sphere(0.2, 0.3, 6, 3), LowPolyMeshes._at(Vector3(0, 0.82, -0.62), 0.0, Vector3(0.9, 1.0, 1.3)), Color(0.2, 0.18, 0.17))
	b.add(LowPolyMeshes._sphere(0.12, 0.16, 5, 2), LowPolyMeshes._at(Vector3(0, 0.9, -0.5)), wool)
	for side: float in [-1.0, 1.0]:
		b.add(LowPolyMeshes._box(Vector3(0.18, 0.05, 0.08)), LowPolyMeshes._at(Vector3(side * 0.18, 0.86, -0.55)), Color(0.2, 0.18, 0.17))
	for x: float in [-0.18, 0.18]:
		for z: float in [-0.35, 0.35]:
			b.add(LowPolyMeshes._box(Vector3(0.08, 0.42, 0.08)), LowPolyMeshes._at(Vector3(x, 0.21, z)), Color(0.18, 0.16, 0.15))
	return b.commit(LowPolyMeshes.vertex_color_material(0.95))


## Dry-stone sheep pen (ağıl) ring with a gap facing -Z.
static func stone_pen(radius: float, gap_deg: float) -> ArrayMesh:
	var b := LowPolyMeshes.Builder.new(520)
	var stone := Color(0.55, 0.52, 0.47)
	var n: int = int(TAU * radius / 0.9)
	for i: int in n:
		var a: float = TAU * i / n
		var deg: float = rad_to_deg(wrapf(a - PI * 1.5, -PI, PI))
		if absf(deg) < gap_deg * 0.5:
			continue
		var p := Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		b.add(LowPolyMeshes._box(Vector3(1.0, b.rng.randf_range(0.8, 1.05), 0.55)), Transform3D(Basis(Vector3.UP, -a + PI * 0.5), p + Vector3(0, 0.45, 0)), stone.lightened(b.rng.randf_range(-0.06, 0.06)), 0.05)
	return b.commit(LowPolyMeshes.vertex_color_material(0.95))


## Wooden beehive box on a stone (Doğu honey: Bingöl/Hakkari style).
static func beehive(seed_value: int = 530) -> ArrayMesh:
	var b := LowPolyMeshes.Builder.new(seed_value)
	var paint: Array[Color] = [Color(0.3, 0.5, 0.7), Color(0.85, 0.75, 0.3), Color(0.75, 0.35, 0.25), Color(0.4, 0.6, 0.35)]
	b.add(LowPolyMeshes._box(Vector3(0.6, 0.25, 0.6)), LowPolyMeshes._at(Vector3(0, 0.12, 0)), Color(0.55, 0.52, 0.48))
	b.add(LowPolyMeshes._box(Vector3(0.55, 0.55, 0.65)), LowPolyMeshes._at(Vector3(0, 0.52, 0)), paint[seed_value % paint.size()])
	b.add(LowPolyMeshes._box(Vector3(0.66, 0.08, 0.74)), LowPolyMeshes._at(Vector3(0, 0.84, 0)), Color(0.4, 0.4, 0.42))
	b.add(LowPolyMeshes._box(Vector3(0.2, 0.04, 0.02)), LowPolyMeshes._at(Vector3(0, 0.3, -0.33)), Color(0.1, 0.1, 0.1))
	return b.commit(LowPolyMeshes.vertex_color_material(0.8))
