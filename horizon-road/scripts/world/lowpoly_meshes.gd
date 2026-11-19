class_name LowPolyMeshes
extends RefCounted
## Builds flat-shaded, vertex-coloured placeholder meshes from primitives.
## Stand-ins until CC0 model packs (Kenney/Quaternius) are dropped into
## assets/models; the faceted look is intentional and matches the art style.

const GRASS_SHADER: Shader = preload("res://assets/shaders/grass.gdshader")
const CAMPER_PAINT_SHADER: Shader = preload("res://assets/shaders/camper_paint.gdshader")
const FOLIAGE_SHADER: Shader = preload("res://assets/shaders/foliage.gdshader")


## Accumulates primitives into one SurfaceTool with per-face colours.
class Builder:
	var st := SurfaceTool.new()
	var rng := RandomNumberGenerator.new()

	func _init(seed_value: int = 0) -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		rng.seed = seed_value

	## Adds a primitive transformed by xf. jitter displaces vertices for organic shapes.
	func add(prim: PrimitiveMesh, xf: Transform3D, color: Color, jitter: float = 0.0, color_var: float = 0.0) -> Builder:
		var arrays: Array = prim.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var moved := PackedVector3Array()
		moved.resize(verts.size())
		for i: int in verts.size():
			var v: Vector3 = verts[i]
			if jitter > 0.0:
				# Hash the rest position so coincident seam vertices move together.
				var h := hash(Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0)) + Vector3i(rng.seed, 0, 0))
				var r := RandomNumberGenerator.new()
				r.seed = h
				v += Vector3(r.randf_range(-1, 1), r.randf_range(-1, 1), r.randf_range(-1, 1)) * jitter
			moved[i] = xf * v
		for t: int in range(0, indices.size(), 3):
			var a: Vector3 = moved[indices[t]]
			var b: Vector3 = moved[indices[t + 1]]
			var c: Vector3 = moved[indices[t + 2]]
			var n: Vector3 = (c - a).cross(b - a)
			if n.length_squared() < 1e-12:
				continue
			var face_color := color
			if color_var > 0.0:
				var k: float = rng.randf_range(-color_var, color_var)
				face_color = Color(color.r * (1.0 + k), color.g * (1.0 + k), color.b * (1.0 + k))
			_tri(a, b, c, n.normalized(), face_color)
		return self

	## Raw triangle, clockwise = front (Godot convention).
	func tri(a: Vector3, b: Vector3, c: Vector3, color: Color, normal: Vector3 = Vector3.ZERO) -> void:
		var n: Vector3 = normal if normal != Vector3.ZERO else (c - a).cross(b - a).normalized()
		_tri(a, b, c, n, color)

	## Triangle with a colour per corner (gradients on grass blades).
	func tri_grad(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, n: Vector3) -> void:
		var cols: Array[Color] = [ca, cb, cc]
		var vs: Array[Vector3] = [a, b, c]
		for i: int in 3:
			st.set_color(cols[i].srgb_to_linear())
			st.set_normal(n)
			st.add_vertex(vs[i])

	func _tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, color: Color) -> void:
		var lin: Color = color.srgb_to_linear()
		for v: Vector3 in [a, b, c]:
			st.set_color(lin)
			st.set_normal(n)
			st.add_vertex(v)

	func commit(material: Material = null) -> ArrayMesh:
		var mesh: ArrayMesh = st.commit()
		if material and mesh.get_surface_count() > 0:
			mesh.surface_set_material(0, material)
		return mesh


static func foliage_material(sway: float, sway_height: float, backlight: float = 0.3) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FOLIAGE_SHADER
	mat.set_shader_parameter(&"sway_strength", sway)
	mat.set_shader_parameter(&"sway_height", sway_height)
	mat.set_shader_parameter(&"backlight_amount", backlight)
	return mat


static func vertex_color_material(roughness: float = 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	return mat


static func _cone(bottom: float, top: float, height: float, segments: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = bottom
	m.top_radius = top
	m.height = height
	m.radial_segments = segments
	m.rings = 0
	m.cap_top = top > 0.0
	return m


static func _sphere(radius: float, height: float, segments: int, rings: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = segments
	m.rings = rings
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _at(pos: Vector3, rot_y: float = 0.0, scale: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y).scaled(scale), pos)


# --- Vegetation ------------------------------------------------------------

## Black Sea spruce: three stacked cones on a short trunk, ~9 m tall.
static func spruce(seed_value: int = 1) -> ArrayMesh:
	var b := Builder.new(seed_value)
	b.add(_cone(0.22, 0.16, 1.6, 6), _at(Vector3(0, 0.8, 0)), Color(0.33, 0.22, 0.14))
	var tiers: Array[Array] = [[2.3, 3.4, 1.2], [1.75, 3.0, 3.1], [1.15, 2.7, 4.9], [0.6, 2.0, 6.6]]
	var tint: float = 0.0
	for tier: Array in tiers:
		var greens := Color(0.11 + tint, 0.25 + tint * 1.4, 0.15 + tint)
		b.add(_cone(tier[0], 0.0, tier[1], 8), _at(Vector3(0, tier[2] + tier[1] * 0.5, 0), tint * 9.0), greens, 0.12, 0.1)
		tint += 0.018
	return b.commit(foliage_material(0.07, 9.0, 0.22))


## Rounded broadleaf tree (beech/alder) built from jittered blobs.
static func broadleaf(seed_value: int = 2) -> ArrayMesh:
	var b := Builder.new(seed_value)
	b.add(_cone(0.25, 0.17, 2.6, 6), _at(Vector3(0, 1.3, 0)), Color(0.36, 0.27, 0.18))
	var leaf := Color(0.25, 0.43, 0.16)
	b.add(_sphere(1.9, 3.0, 7, 4), _at(Vector3(0, 3.9, 0)), leaf, 0.3, 0.12)
	b.add(_sphere(1.3, 2.2, 6, 3), _at(Vector3(0.9, 4.9, 0.3)), leaf.lightened(0.06), 0.25, 0.12)
	b.add(_sphere(1.2, 2.0, 6, 3), _at(Vector3(-0.8, 4.6, -0.5)), leaf.darkened(0.05), 0.25, 0.12)
	return b.commit(foliage_material(0.1, 6.0, 0.32))


## Clipped tea bush (Camellia sinensis): glossy dark-green dome.
static func tea_bush(seed_value: int = 3) -> ArrayMesh:
	var b := Builder.new(seed_value)
	b.add(_sphere(0.62, 0.95, 8, 4), _at(Vector3(0, 0.38, 0), 0.0, Vector3(1.0, 1.0, 0.85)), Color(0.15, 0.38, 0.13), 0.06, 0.14)
	return b.commit(foliage_material(0.03, 1.0, 0.25))


## Low rounded shrub (rhododendron/hazel) for forest edges.
static func shrub(seed_value: int = 50) -> ArrayMesh:
	var b := Builder.new(seed_value)
	var leaf := Color(0.2, 0.38, 0.16)
	for i: int in 4:
		var p := Vector3(b.rng.randf_range(-0.5, 0.5), 0.0, b.rng.randf_range(-0.5, 0.5))
		var r: float = b.rng.randf_range(0.4, 0.65)
		b.add(_sphere(r, r * 1.5, 6, 3), _at(p + Vector3(0, r * 0.6, 0)), leaf.lightened(b.rng.randf_range(-0.05, 0.1)), 0.1, 0.12)
	return b.commit(foliage_material(0.05, 1.4, 0.3))


## Fern: arching fronds fanned out, double-sided.
static func fern(seed_value: int = 60) -> ArrayMesh:
	var b := Builder.new(seed_value)
	var green := Color(0.3, 0.5, 0.18)
	var fronds: int = 7
	for i: int in fronds:
		var a: float = TAU * i / fronds + b.rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side: Vector3 = dir.cross(Vector3.UP) * 0.09
		var length: float = b.rng.randf_range(0.45, 0.7)
		var mid: Vector3 = dir * length * 0.5 + Vector3(0, 0.38, 0)
		var tip: Vector3 = dir * length + Vector3(0, 0.15, 0)
		var col: Color = green.lightened(b.rng.randf_range(-0.05, 0.1))
		for pair: Array in [[Vector3.ZERO, mid], [mid, tip]]:
			var p0: Vector3 = pair[0]
			var p1: Vector3 = pair[1]
			b.tri(p0 - side * 0.3, p1, p0 + side * 0.3, col, Vector3.UP)
			b.tri(p0 + side * 0.3, p1, p0 - side * 0.3, col, Vector3.UP)
			b.tri(p1 - side, p1 + dir * 0.02, p1 + side, col, Vector3.UP)
			b.tri(p1 + side, p1 + dir * 0.02, p1 - side, col, Vector3.UP)
	return b.commit(foliage_material(0.08, 0.7, 0.45))


## Birch: slim white trunk with dark marks, small airy canopy.
static func birch(seed_value: int = 70) -> ArrayMesh:
	var b := Builder.new(seed_value)
	b.add(_cone(0.13, 0.08, 4.5, 6), _at(Vector3(0, 2.25, 0)), Color(0.9, 0.88, 0.82))
	for y: float in [0.8, 1.7, 2.6, 3.4]:
		b.add(_box(Vector3(0.2, 0.05, 0.2)), _at(Vector3(0, y, 0), b.rng.randf() * TAU), Color(0.2, 0.18, 0.16))
	var leaf := Color(0.45, 0.62, 0.22)
	for i: int in 4:
		var p := Vector3(b.rng.randf_range(-0.6, 0.6), b.rng.randf_range(3.8, 5.0), b.rng.randf_range(-0.6, 0.6))
		b.add(_sphere(0.8, 1.6, 6, 3), _at(p), leaf.lightened(b.rng.randf_range(-0.05, 0.08)), 0.18, 0.12)
	return b.commit(foliage_material(0.12, 6.0, 0.4))


## Lake reeds with cattail heads.
static func reeds(seed_value: int = 80) -> ArrayMesh:
	var b := Builder.new(seed_value)
	for i: int in 9:
		var base := Vector3(b.rng.randf_range(-0.35, 0.35), 0.0, b.rng.randf_range(-0.35, 0.35))
		var h: float = b.rng.randf_range(1.0, 1.7)
		var lean := Vector3(b.rng.randf_range(-0.12, 0.12), 0, b.rng.randf_range(-0.12, 0.12))
		var top: Vector3 = base + lean + Vector3(0, h, 0)
		var w := Vector3(0.025, 0, 0)
		var c := Color(0.42, 0.52, 0.24).lerp(Color(0.6, 0.55, 0.3), b.rng.randf())
		b.tri(base - w, top, base + w, c, Vector3.UP)
		b.tri(base + w, top, base - w, c, Vector3.UP)
		if i % 3 == 0:
			b.add(_cone(0.035, 0.035, 0.2, 5), _at(top - lean * 0.1 - Vector3(0, 0.12, 0)), Color(0.4, 0.26, 0.15))
	return b.commit(foliage_material(0.15, 1.6, 0.4))


static func rock(seed_value: int = 4) -> ArrayMesh:
	var b := Builder.new(seed_value)
	b.add(_sphere(1.0, 1.3, 6, 3), _at(Vector3(0, 0.25, 0)), Color(0.45, 0.44, 0.41), 0.22, 0.08)
	return b.commit(vertex_color_material(0.9))


## Grass tuft: a few double-sided blades with up-facing normals so they light
## like the ground beneath them instead of flickering per blade.
static func grass_tuft(seed_value: int = 5, blades: int = 6, height: float = 0.5) -> ArrayMesh:
	var b := Builder.new(seed_value)
	var root := Color(0.13, 0.24, 0.07)
	var mid := Color(0.3, 0.46, 0.14)
	var tip := Color(0.56, 0.7, 0.3)
	for i: int in blades:
		var angle: float = b.rng.randf() * TAU
		var offset := Vector3(b.rng.randf_range(-0.2, 0.2), 0, b.rng.randf_range(-0.2, 0.2))
		var side := Vector3(cos(angle), 0, sin(angle)) * b.rng.randf_range(0.035, 0.055)
		var lean := Vector3(b.rng.randf_range(-0.22, 0.22), 0, b.rng.randf_range(-0.22, 0.22))
		var h: float = height * b.rng.randf_range(0.55, 1.25)
		# Two segments so the blade arcs over instead of being a flat spike.
		var m: Vector3 = offset + lean * 0.3 + Vector3(0, h * 0.55, 0)
		var top: Vector3 = offset + lean + Vector3(0, h, 0)
		var shade: float = b.rng.randf_range(0.85, 1.15)
		var t: Color = tip * shade
		b.tri_grad(offset - side, m - side * 0.6, offset + side, root, mid, root, Vector3.UP)
		b.tri_grad(offset + side, m - side * 0.6, m + side * 0.6, root, mid, mid, Vector3.UP)
		b.tri_grad(m - side * 0.6, top, m + side * 0.6, mid, t, mid, Vector3.UP)
	return b.commit(grass_material())


static func grass_material() -> ShaderMaterial:
	var mat := foliage_material(0.18, 0.6, 0.5)
	mat.shader = GRASS_SHADER
	return mat


static func flower_tuft(petal_color: Color, seed_value: int = 6) -> ArrayMesh:
	var b := Builder.new(seed_value)
	for i: int in 3:
		var p := Vector3(b.rng.randf_range(-0.2, 0.2), 0, b.rng.randf_range(-0.2, 0.2))
		var h: float = b.rng.randf_range(0.3, 0.5)
		b.tri(p + Vector3(-0.015, 0, 0), p + Vector3(0, h, 0), p + Vector3(0.015, 0, 0), Color(0.25, 0.4, 0.15), Vector3.UP)
		b.tri(p + Vector3(0.015, 0, 0), p + Vector3(0, h, 0), p + Vector3(-0.015, 0, 0), Color(0.25, 0.4, 0.15), Vector3.UP)
		b.add(_sphere(0.06, 0.07, 5, 2), _at(p + Vector3(0, h, 0)), petal_color)
	return b.commit(foliage_material(0.12, 0.5, 0.5))


# --- Props -----------------------------------------------------------------

## Highland house: stone ground floor, timber upper floor, steep tin roof.
## Returns body mesh; windows are separate so they can glow at night.
static func yayla_house(seed_value: int, wood: Color, roof: Color) -> Dictionary:
	var b := Builder.new(seed_value)
	var w: float = 6.0
	var d: float = 7.5
	b.add(_box(Vector3(w, 2.6, d)), _at(Vector3(0, 0.5, 0)), Color(0.55, 0.53, 0.5), 0.05, 0.06)
	b.add(_box(Vector3(w + 0.3, 2.6, d + 0.3)), _at(Vector3(0, 3.1, 0)), wood, 0.0, 0.05)
	# Roof: two slabs meeting at the ridge, with overhang.
	var roof_h: float = 2.2
	var half: float = (w + 1.2) * 0.5
	var slope_len: float = Vector2(half, roof_h).length()
	var angle: float = atan2(roof_h, half)
	for side: float in [-1.0, 1.0]:
		var xf := Transform3D(Basis(Vector3.FORWARD, -side * angle), Vector3(side * half * 0.5, 4.4 + roof_h * 0.5, 0))
		b.add(_box(Vector3(slope_len, 0.18, d + 1.4)), xf, roof, 0.0, 0.04)
	# Gable triangles front/back.
	for z: float in [-(d + 0.3) * 0.5, (d + 0.3) * 0.5]:
		var s: float = signf(z)
		var l := Vector3(-(w + 0.3) * 0.5, 4.4, z)
		var r := Vector3((w + 0.3) * 0.5, 4.4, z)
		var top := Vector3(0, 4.4 + roof_h - 0.1, z)
		if s > 0.0:
			b.tri(l, top, r, wood.darkened(0.08))
		else:
			b.tri(r, top, l, wood.darkened(0.08))
	# Door, balcony beam, chimney.
	b.add(_box(Vector3(1.1, 2.0, 0.12)), _at(Vector3(-1.2, 1.0, d * 0.5 + 0.02)), Color(0.3, 0.2, 0.13))
	b.add(_box(Vector3(w + 0.6, 0.15, 0.9)), _at(Vector3(0, 1.9, d * 0.5 + 0.55)), wood.darkened(0.15))
	b.add(_box(Vector3(0.6, 1.6, 0.6)), _at(Vector3(1.4, 5.6, -1.5)), Color(0.5, 0.48, 0.45), 0.03)

	var wb := Builder.new(seed_value + 1)
	var windows: Array[Vector3] = [
		Vector3(1.4, 3.2, d * 0.5 + 0.17), Vector3(-1.4, 3.2, d * 0.5 + 0.17),
		Vector3(w * 0.5 + 0.17, 3.2, 1.6), Vector3(w * 0.5 + 0.17, 3.2, -1.6),
		Vector3(-w * 0.5 - 0.17, 3.2, 0.0), Vector3(1.4, 1.1, d * 0.5 + 0.02),
	]
	for p: Vector3 in windows:
		var size := Vector3(0.9, 1.0, 0.06) if absf(p.z) > absf(p.x) else Vector3(0.06, 1.0, 0.9)
		wb.add(_box(size), _at(p), Color.WHITE)
		# Window frame.
		var frame_size: Vector3 = size + Vector3(0.18 if size.x > 0.1 else 0.0, 0.18, 0.18 if size.z > 0.1 else 0.0)
		var outward: Vector3 = Vector3(p.x, 0.0, p.z).normalized()
		b.add(_box(frame_size), _at(p - outward * 0.03), Color(0.85, 0.82, 0.75))
	return {"body": b.commit(vertex_color_material(0.8)), "windows": wb.commit()}


static func hay_stack(seed_value: int = 7) -> ArrayMesh:
	var b := Builder.new(seed_value)
	b.add(_cone(0.12, 0.1, 3.4, 5), _at(Vector3(0, 1.7, 0)), Color(0.4, 0.3, 0.2))
	b.add(_sphere(1.1, 2.6, 7, 4), _at(Vector3(0, 1.2, 0)), Color(0.72, 0.6, 0.34), 0.12, 0.08)
	return b.commit(foliage_material(0.02, 3.0, 0.2))


## Brown highland cow (Karadeniz breed look), ~1.4 m tall, facing -Z.
static func cow(seed_value: int, coat: Color) -> ArrayMesh:
	var b := Builder.new(seed_value)
	var dark: Color = coat.darkened(0.35)
	b.add(_box(Vector3(0.75, 0.75, 1.6)), _at(Vector3(0, 1.0, 0.05)), coat, 0.04, 0.05)
	b.add(_box(Vector3(0.42, 0.45, 0.55)), _at(Vector3(0, 1.2, -0.95)), coat, 0.03)
	b.add(_box(Vector3(0.36, 0.26, 0.2)), _at(Vector3(0, 1.08, -1.25)), Color(0.85, 0.72, 0.65))
	for x: float in [-0.24, 0.24]:
		b.add(_cone(0.04, 0.0, 0.22, 4), Transform3D(Basis(Vector3.FORWARD, x * 4.0), Vector3(x, 1.5, -0.95)), Color(0.9, 0.86, 0.75))
		b.add(_box(Vector3(0.16, 0.08, 0.1)), _at(Vector3(x * 1.35, 1.38, -0.85)), dark)
		for z: float in [-0.5, 0.6]:
			b.add(_box(Vector3(0.16, 0.65, 0.16)), _at(Vector3(x * 1.1, 0.33, z)), dark)
	b.add(_box(Vector3(0.06, 0.6, 0.06)), Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.95, 0.9)), dark)
	return b.commit(vertex_color_material(0.9))


## Highland tea grower: patterned headscarf (yazma), cardigan, long skirt,
## apron and a wicker tea basket (küfe) on her back. ~1.65 m, faces -Z.
static func villager_woman(seed_value: int = 21) -> ArrayMesh:
	var b := Builder.new(seed_value)
	var skirt := Color(0.32, 0.22, 0.35)
	var cardigan := Color(0.55, 0.2, 0.18)
	var scarf := Color(0.95, 0.75, 0.25)
	var skin := Color(0.85, 0.66, 0.52)
	b.add(_cone(0.34, 0.22, 0.85, 8), _at(Vector3(0, 0.45, 0)), skirt, 0.0, 0.05)
	b.add(_box(Vector3(0.36, 0.55, 0.04)), _at(Vector3(0, 0.5, -0.22)), Color(0.9, 0.88, 0.8))
	b.add(_cone(0.24, 0.2, 0.55, 8), _at(Vector3(0, 1.15, 0)), cardigan, 0.0, 0.05)
	for x: float in [-0.27, 0.27]:
		b.add(_cone(0.07, 0.06, 0.5, 6), Transform3D(Basis(Vector3.FORWARD, x * 0.6), Vector3(x, 1.12, -0.03)), cardigan)
		b.add(_sphere(0.06, 0.1, 6, 3), _at(Vector3(x * 1.08, 0.86, -0.06)), skin)
	b.add(_sphere(0.13, 0.27, 10, 5), _at(Vector3(0, 1.52, 0)), skin)
	_face(b, Vector3(0, 1.52, 0), 0.13, Color(0.35, 0.28, 0.22))
	# Yazma tied over the hair, leaving the face open.
	b.add(_sphere(0.15, 0.24, 10, 4), _at(Vector3(0, 1.6, 0.045)), scarf, 0.0, 0.08)
	b.add(_box(Vector3(0.3, 0.035, 0.05)), _at(Vector3(0, 1.62, -0.08)), Color(0.85, 0.25, 0.2))
	b.add(_cone(0.12, 0.02, 0.22, 6), Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, 1.4, 0.13)), scarf.darkened(0.1))
	# Küfe: tapered wicker basket strapped to the back.
	b.add(_cone(0.2, 0.26, 0.55, 8), _at(Vector3(0, 1.2, 0.3)), Color(0.62, 0.48, 0.28), 0.0, 0.1)
	b.add(_cone(0.22, 0.22, 0.06, 8), _at(Vector3(0, 1.47, 0.3)), Color(0.24, 0.45, 0.16), 0.02)
	return b.commit(vertex_color_material(0.85))


## Village mechanic: blue overalls, flat cap, moustache, rag in pocket. ~1.75 m, faces -Z.
static func villager_man(seed_value: int = 22) -> ArrayMesh:
	var b := Builder.new(seed_value)
	var overalls := Color(0.2, 0.32, 0.52)
	var skin := Color(0.8, 0.6, 0.46)
	for x: float in [-0.12, 0.12]:
		b.add(_box(Vector3(0.18, 0.12, 0.3)), _at(Vector3(x, 0.06, -0.03)), Color(0.2, 0.15, 0.1))
		b.add(_box(Vector3(0.18, 0.8, 0.2)), _at(Vector3(x, 0.52, 0)), overalls)
	b.add(_box(Vector3(0.5, 0.66, 0.3)), _at(Vector3(0, 1.2, 0)), overalls, 0.02, 0.04)
	b.add(_box(Vector3(0.12, 0.1, 0.04)), _at(Vector3(0.12, 1.12, -0.16)), Color(0.85, 0.3, 0.2))
	for x: float in [-0.31, 0.31]:
		b.add(_box(Vector3(0.12, 0.58, 0.14)), Transform3D(Basis(Vector3.FORWARD, x * 0.2), Vector3(x, 1.15, 0)), overalls.lightened(0.05))
		b.add(_sphere(0.06, 0.11, 6, 3), _at(Vector3(x * 1.06, 0.84, 0)), skin)
	b.add(_cone(0.065, 0.065, 0.1, 6), _at(Vector3(0, 1.57, 0)), skin)
	b.add(_sphere(0.145, 0.3, 10, 5), _at(Vector3(0, 1.71, 0)), skin)
	_face(b, Vector3(0, 1.71, 0), 0.145, Color(0.2, 0.18, 0.16))
	b.add(_box(Vector3(0.12, 0.025, 0.03)), _at(Vector3(0, 1.66, -0.14)), Color(0.25, 0.22, 0.2))
	b.add(_sphere(0.16, 0.12, 10, 3), _at(Vector3(0, 1.82, 0.0)), Color(0.35, 0.3, 0.25))
	b.add(_box(Vector3(0.24, 0.025, 0.12)), _at(Vector3(0, 1.8, -0.15)), Color(0.3, 0.26, 0.22))
	return b.commit(vertex_color_material(0.8))


## Village garage: open shed with workbench, tyres, tool wall and a fuel pump.
static func garage() -> ArrayMesh:
	var b := Builder.new(43)
	var wall := Color(0.62, 0.58, 0.52)
	var tin := Color(0.45, 0.5, 0.55)
	b.add(_box(Vector3(6.0, 3.0, 0.2)), _at(Vector3(0, 1.5, 2.4)), wall, 0.0, 0.04)
	for x: float in [-3.0, 3.0]:
		b.add(_box(Vector3(0.2, 3.0, 5.0)), _at(Vector3(x, 1.5, 0)), wall, 0.0, 0.04)
	b.add(_box(Vector3(6.6, 0.12, 5.6)), Transform3D(Basis(Vector3.RIGHT, -0.1), Vector3(0, 3.15, 0)), tin, 0.0, 0.05)
	b.add(_box(Vector3(2.2, 0.08, 0.7)), _at(Vector3(-1.4, 0.9, 1.9)), Color(0.45, 0.32, 0.2))
	for x: float in [-2.4, -0.4]:
		b.add(_box(Vector3(0.08, 0.9, 0.6)), _at(Vector3(x, 0.45, 1.9)), Color(0.4, 0.28, 0.18))
	b.add(_box(Vector3(2.0, 1.0, 0.04)), _at(Vector3(-1.4, 1.8, 2.28)), Color(0.35, 0.3, 0.26))
	for i: int in 4:
		b.add(_cone(0.04, 0.04, 0.3, 4), Transform3D(Basis(Vector3.FORWARD, 0.5 * i), Vector3(-2.1 + i * 0.4, 1.8, 2.24)), Color(0.75, 0.75, 0.78))
	for i: int in 3:
		b.add(_cone(0.42, 0.42, 0.28, 10), _at(Vector3(2.2, 0.15 + i * 0.29, 1.6)), Color(0.12, 0.12, 0.13))
	# Fuel pump outside the shed.
	b.add(_box(Vector3(0.6, 1.5, 0.45)), _at(Vector3(4.2, 0.75, -1.5)), Color(0.82, 0.22, 0.18))
	b.add(_box(Vector3(0.5, 0.35, 0.05)), _at(Vector3(4.2, 1.15, -1.75)), Color(0.95, 0.92, 0.85))
	b.add(_sphere(0.22, 0.3, 8, 3), _at(Vector3(4.2, 1.65, -1.5)), Color(0.95, 0.95, 0.9))
	b.add(_box(Vector3(0.06, 0.6, 0.06)), _at(Vector3(4.55, 0.9, -1.5)), Color(0.15, 0.15, 0.15))
	return b.commit(vertex_color_material(0.8))


## Fresh tea shoot cluster (harvest target). Golden shoots are rarer bonuses.
static func tea_shoot(golden: bool) -> ArrayMesh:
	var b := Builder.new(31)
	var leaf: Color = Color(0.95, 0.8, 0.3) if golden else Color(0.55, 0.85, 0.3)
	for i: int in 5:
		var a: float = TAU * i / 5.0
		var p := Vector3(cos(a) * 0.08, 0.0, sin(a) * 0.08)
		b.add(_sphere(0.06, 0.18, 5, 2), Transform3D(Basis(Vector3(sin(a), 0, -cos(a)), 0.5), p + Vector3(0, 0.07, 0)), leaf)
	b.add(_cone(0.02, 0.0, 0.16, 4), _at(Vector3(0, 0.12, 0)), leaf.lightened(0.2))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.8, 0.2) if not golden else Color(1.0, 0.7, 0.15)
	mat.emission_energy_multiplier = 1.1
	return b.commit(mat)


## Tea shelter (çardak): posts, plank roof, table with teapot, stools, sacks.
static func tea_shelter() -> ArrayMesh:
	var b := Builder.new(41)
	var wood := Color(0.5, 0.35, 0.22)
	for x: float in [-1.6, 1.6]:
		for z: float in [-1.3, 1.3]:
			b.add(_box(Vector3(0.14, 2.4, 0.14)), _at(Vector3(x, 1.2, z)), wood)
	b.add(_box(Vector3(3.8, 0.1, 3.2)), Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 2.45, 0)), wood.darkened(0.15), 0.0, 0.06)
	b.add(_box(Vector3(1.2, 0.06, 0.7)), _at(Vector3(0, 0.75, 0)), wood.lightened(0.1))
	b.add(_box(Vector3(0.08, 0.72, 0.08)), _at(Vector3(0, 0.37, 0)), wood)
	for x: float in [-0.85, 0.85]:
		b.add(_cone(0.18, 0.16, 0.45, 6), _at(Vector3(x, 0.22, 0)), wood)
	# Double teapot (çaydanlık) and tulip glasses.
	b.add(_cone(0.13, 0.1, 0.18, 8), _at(Vector3(-0.2, 0.87, 0)), Color(0.8, 0.8, 0.82))
	b.add(_cone(0.09, 0.07, 0.13, 8), _at(Vector3(-0.2, 1.02, 0)), Color(0.85, 0.85, 0.87))
	for x: float in [0.15, 0.32]:
		b.add(_cone(0.03, 0.035, 0.08, 6), _at(Vector3(x, 0.82, 0.1)), Color(0.65, 0.2, 0.1))
	for i: int in 3:
		b.add(_sphere(0.32, 0.6, 7, 3), _at(Vector3(1.9, 0.28, -0.9 + i * 0.6), 0.0, Vector3(1.0, 1.0, 0.8)), Color(0.82, 0.76, 0.6), 0.05, 0.05)
	return b.commit(vertex_color_material(0.85))


# --- Aegean ----------------------------------------------------------------

## Old olive tree: twisted split trunk, silvery grey-green clumped crown.
static func olive(seed_value: int = 100) -> ArrayMesh:
	var b := Builder.new(seed_value)
	var bark := Color(0.42, 0.37, 0.3)
	b.add(_cone(0.32, 0.2, 1.3, 7), Transform3D(Basis(Vector3.FORWARD, 0.15), Vector3(0, 0.6, 0)), bark, 0.06)
	b.add(_cone(0.16, 0.1, 1.2, 6), Transform3D(Basis(Vector3.FORWARD, -0.5), Vector3(-0.35, 1.5, 0)), bark, 0.04)
	b.add(_cone(0.16, 0.1, 1.2, 6), Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0.15, 1.5, 0.3)), bark, 0.04)
	var leaf := Color(0.48, 0.55, 0.38)
	for i: int in 5:
		var p := Vector3(b.rng.randf_range(-1.0, 1.0), b.rng.randf_range(2.0, 2.7), b.rng.randf_range(-1.0, 1.0))
		b.add(_sphere(0.9, 1.1, 7, 3), _at(p, 0.0, Vector3(1.0, 0.75, 1.0)), leaf.lightened(b.rng.randf_range(-0.06, 0.08)), 0.15, 0.1)
	return b.commit(foliage_material(0.06, 3.0, 0.28))


## Italian cypress: tall dark flame shape.
static func cypress(seed_value: int = 101) -> ArrayMesh:
	var b := Builder.new(seed_value)
	b.add(_cone(0.18, 0.12, 0.8, 5), _at(Vector3(0, 0.4, 0)), Color(0.35, 0.26, 0.18))
	b.add(_sphere(0.7, 8.5, 8, 6), _at(Vector3(0, 4.9, 0)), Color(0.13, 0.25, 0.14), 0.1, 0.1)
	return b.commit(foliage_material(0.05, 9.0, 0.15))


## Umbrella (stone) pine: bare leaning trunk, flat dark canopy.
static func umbrella_pine(seed_value: int = 102) -> ArrayMesh:
	var b := Builder.new(seed_value)
	b.add(_cone(0.3, 0.18, 6.5, 6), Transform3D(Basis(Vector3.FORWARD, 0.12), Vector3(-0.35, 3.2, 0)), Color(0.5, 0.36, 0.26), 0.05)
	for i: int in 3:
		var p := Vector3(-0.8 + b.rng.randf_range(-1.2, 1.2), 6.8 + b.rng.randf_range(-0.2, 0.3), b.rng.randf_range(-1.0, 1.0))
		b.add(_sphere(2.2, 1.4, 9, 3), _at(p), Color(0.2, 0.36, 0.2).lightened(b.rng.randf_range(-0.04, 0.06)), 0.2, 0.08)
	return b.commit(foliage_material(0.06, 8.0, 0.22))


## Maquis shrub (mastic/thyme): low, grey-green.
static func maquis(seed_value: int = 103) -> ArrayMesh:
	var b := Builder.new(seed_value)
	for i: int in 3:
		var p := Vector3(b.rng.randf_range(-0.4, 0.4), 0.0, b.rng.randf_range(-0.4, 0.4))
		var r: float = b.rng.randf_range(0.3, 0.5)
		b.add(_sphere(r, r * 1.3, 6, 3), _at(p + Vector3(0, r * 0.5, 0)), Color(0.42, 0.48, 0.3).lightened(b.rng.randf_range(-0.05, 0.08)), 0.08, 0.12)
	return b.commit(foliage_material(0.04, 1.0, 0.25))


## Whitewashed Aegean house: cubic, terracotta or flat roof, blue door and
## shutters, a bougainvillea on the wall. Windows returned separately.
static func ege_house(seed_value: int, tiled_roof: bool, blue: Color) -> Dictionary:
	var b := Builder.new(seed_value)
	var white := Color(0.96, 0.95, 0.92)
	var w: float = b.rng.randf_range(5.0, 6.5)
	var d: float = b.rng.randf_range(5.5, 7.0)
	var h: float = b.rng.randf_range(3.2, 4.0)
	b.add(_box(Vector3(w, h, d)), _at(Vector3(0, h * 0.5 - 0.3, 0)), white, 0.02, 0.02)
	if tiled_roof:
		var rh: float = 1.3
		var half: float = (w + 0.6) * 0.5
		var ang: float = atan2(rh, half)
		var slope: float = Vector2(half, rh).length()
		for side: float in [-1.0, 1.0]:
			b.add(_box(Vector3(slope, 0.14, d + 0.6)), Transform3D(Basis(Vector3.FORWARD, -side * ang), Vector3(side * half * 0.5, h - 0.3 + rh * 0.5, 0)), Color(0.78, 0.38, 0.24), 0.0, 0.06)
		for zz: float in [-d * 0.5, d * 0.5]:
			var s: float = signf(zz)
			var l := Vector3(-w * 0.5, h - 0.3, zz)
			var r := Vector3(w * 0.5, h - 0.3, zz)
			var top := Vector3(0, h - 0.3 + rh - 0.1, zz)
			if s > 0.0:
				b.tri(l, top, r, white)
			else:
				b.tri(r, top, l, white)
	else:
		b.add(_box(Vector3(w + 0.1, 0.35, d + 0.1)), _at(Vector3(0, h - 0.2, 0)), white.darkened(0.04))
		b.add(_box(Vector3(1.4, 1.4, 1.4)), _at(Vector3(w * 0.25, h + 0.4, -d * 0.2)), white)
		b.add(_sphere(0.75, 0.8, 8, 3), _at(Vector3(w * 0.25, h + 1.1, -d * 0.2)), blue)
	b.add(_box(Vector3(1.0, 2.0, 0.1)), _at(Vector3(-w * 0.2, 0.7, -d * 0.5 - 0.03)), blue)
	b.add(_box(Vector3(0.12, 3.0, 0.12)), _at(Vector3(w * 0.42, 1.2, -d * 0.5 - 0.15)), Color(0.4, 0.3, 0.2))
	for i: int in 5:
		b.add(_sphere(0.45, 0.6, 6, 3), _at(Vector3(w * 0.42 + b.rng.randf_range(-0.5, 0.3), 2.0 + i * 0.25, -d * 0.5 - 0.25)), Color(0.85, 0.2, 0.5).lightened(b.rng.randf_range(-0.1, 0.1)), 0.08)
	var wb := Builder.new(seed_value + 1)
	for p: Vector3 in [Vector3(w * 0.15, 1.6, -d * 0.5 - 0.04), Vector3(-w * 0.5 - 0.04, 1.6, 0.8), Vector3(w * 0.5 + 0.04, 1.6, -0.6)]:
		var size := Vector3(0.8, 0.9, 0.06) if absf(p.z) > absf(p.x) else Vector3(0.06, 0.9, 0.8)
		wb.add(_box(size), _at(p), Color.WHITE)
		var shutter := Vector3(0.36, 0.95, 0.04) if size.x > 0.1 else Vector3(0.04, 0.95, 0.36)
		var off := Vector3(0.6, 0, 0) if size.x > 0.1 else Vector3(0, 0, 0.6)
		b.add(_box(shutter), _at(p + off), blue)
		b.add(_box(shutter), _at(p - off), blue)
	return {"body": b.commit(vertex_color_material(0.75)), "windows": wb.commit(), "size": Vector3(w, h, d)}


## Wooden fishing boat (kayık), painted hull, facing -Z.
static func boat(seed_value: int, hull: Color) -> ArrayMesh:
	var b := Builder.new(seed_value)
	b.add(_box(Vector3(1.8, 0.7, 5.0)), _at(Vector3(0, 0.35, 0)), hull, 0.0, 0.04)
	b.add(_cone(0.0, 0.9, 1.4, 4), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.UP, PI * 0.25), Vector3(0, 0.35, -3.1)), hull)
	b.add(_box(Vector3(1.9, 0.12, 5.1)), _at(Vector3(0, 0.72, 0)), Color(0.95, 0.93, 0.88))
	b.add(_box(Vector3(1.5, 0.08, 4.4)), _at(Vector3(0, 0.62, 0.1)), Color(0.55, 0.4, 0.26))
	b.add(_box(Vector3(1.2, 1.0, 1.2)), _at(Vector3(0, 1.1, 1.2)), Color(0.95, 0.93, 0.88))
	b.add(_box(Vector3(1.35, 0.1, 1.35)), _at(Vector3(0, 1.62, 1.2)), Color(0.2, 0.35, 0.6))
	b.add(_box(Vector3(0.08, 2.5, 0.08)), _at(Vector3(0, 1.9, -0.8)), Color(0.4, 0.3, 0.2))
	return b.commit(vertex_color_material(0.7))


## Stone pier (iskele) segment-built along -Z from its origin, with bollards.
static func pier(length: float, width: float) -> ArrayMesh:
	var b := Builder.new(104)
	var stone := Color(0.78, 0.74, 0.66)
	var segs: int = int(length / 2.0)
	for i: int in segs:
		b.add(_box(Vector3(width, 2.0, 2.02)), _at(Vector3(0, -0.6, -1.0 - i * 2.0)), stone.darkened(0.04 * (i % 3)), 0.0, 0.03)
	for i: int in range(1, segs, 3):
		for x: float in [-width * 0.5 + 0.3, width * 0.5 - 0.3]:
			b.add(_cone(0.14, 0.12, 0.45, 6), _at(Vector3(x, 0.62, -i * 2.0)), Color(0.25, 0.25, 0.27))
	return b.commit(vertex_color_material(0.85))


static func net_pile(seed_value: int = 105) -> ArrayMesh:
	var b := Builder.new(seed_value)
	b.add(_sphere(0.8, 0.6, 8, 3), _at(Vector3(0, 0.2, 0)), Color(0.35, 0.5, 0.55), 0.12, 0.1)
	for i: int in 6:
		b.add(_sphere(0.08, 0.1, 5, 2), _at(Vector3(b.rng.randf_range(-0.7, 0.7), 0.35, b.rng.randf_range(-0.6, 0.6))), Color(0.95, 0.55, 0.15))
	return b.commit(vertex_color_material(0.9))


static func buoy() -> ArrayMesh:
	var b := Builder.new(106)
	b.add(_sphere(0.22, 0.32, 8, 4), _at(Vector3(0, 0.05, 0)), Color(0.95, 0.5, 0.15))
	b.add(_box(Vector3(0.04, 0.4, 0.04)), _at(Vector3(0, 0.3, 0)), Color(0.2, 0.2, 0.2))
	return b.commit(vertex_color_material(0.5))


## Old fisherman: navy cap, white beard, striped shirt, rolled trousers.
static func fisherman(seed_value: int = 23) -> ArrayMesh:
	var b := Builder.new(seed_value)
	var shirt := Color(0.92, 0.92, 0.9)
	var skin := Color(0.72, 0.52, 0.38)
	for x: float in [-0.12, 0.12]:
		b.add(_box(Vector3(0.18, 0.12, 0.3)), _at(Vector3(x, 0.06, -0.03)), Color(0.15, 0.12, 0.1))
		b.add(_box(Vector3(0.18, 0.78, 0.2)), _at(Vector3(x, 0.5, 0)), Color(0.3, 0.35, 0.5))
	b.add(_box(Vector3(0.52, 0.66, 0.32)), _at(Vector3(0, 1.2, 0)), shirt, 0.02, 0.03)
	for y: float in [0.98, 1.12, 1.26, 1.4]:
		b.add(_box(Vector3(0.54, 0.05, 0.34)), _at(Vector3(0, y, 0)), Color(0.15, 0.3, 0.6))
	for x: float in [-0.31, 0.31]:
		b.add(_box(Vector3(0.12, 0.56, 0.14)), Transform3D(Basis(Vector3.FORWARD, x * 0.2), Vector3(x, 1.15, 0)), shirt)
		b.add(_sphere(0.065, 0.12, 6, 3), _at(Vector3(x * 1.06, 0.84, 0)), skin)
	b.add(_cone(0.065, 0.065, 0.1, 6), _at(Vector3(0, 1.57, 0)), skin)
	b.add(_sphere(0.145, 0.3, 10, 5), _at(Vector3(0, 1.71, 0)), skin)
	_face(b, Vector3(0, 1.71, 0), 0.145, Color(0.9, 0.9, 0.88))
	b.add(_sphere(0.13, 0.16, 8, 3), _at(Vector3(0, 1.6, -0.08)), Color(0.93, 0.93, 0.9), 0.02)
	b.add(_cone(0.16, 0.15, 0.12, 10), _at(Vector3(0, 1.84, 0)), Color(0.12, 0.16, 0.3))
	b.add(_box(Vector3(0.22, 0.03, 0.12)), _at(Vector3(0, 1.8, -0.15)), Color(0.08, 0.08, 0.1))
	return b.commit(vertex_color_material(0.8))


static func fish(color: Color) -> ArrayMesh:
	var b := Builder.new(107)
	b.add(_sphere(0.09, 0.14, 6, 3), _at(Vector3.ZERO, 0.0, Vector3(1.0, 1.0, 2.6)), color)
	b.add(_cone(0.0, 0.09, 0.14, 4), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.28)), color.darkened(0.2))
	return b.commit(vertex_color_material(0.35))


## Harbour cat, ~0.35 m tall, facing -Z.
static func cat(seed_value: int, fur: Color) -> ArrayMesh:
	var b := Builder.new(seed_value)
	b.add(_box(Vector3(0.18, 0.16, 0.42)), _at(Vector3(0, 0.22, 0)), fur, 0.01)
	b.add(_box(Vector3(0.16, 0.14, 0.14)), _at(Vector3(0, 0.33, -0.25)), fur)
	for x: float in [-0.05, 0.05]:
		b.add(_cone(0.035, 0.0, 0.07, 3), _at(Vector3(x, 0.43, -0.25)), fur.darkened(0.15))
		b.add(_sphere(0.012, 0.02, 4, 2), _at(Vector3(x * 0.8, 0.35, -0.325)), Color(0.4, 0.75, 0.3))
		for z: float in [-0.15, 0.15]:
			b.add(_box(Vector3(0.05, 0.16, 0.05)), _at(Vector3(x * 1.4, 0.08, z)), fur.darkened(0.05))
	b.add(_box(Vector3(0.04, 0.04, 0.3)), Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(0, 0.36, 0.3)), fur.darkened(0.1))
	return b.commit(vertex_color_material(0.9))


# --- Vehicle ---------------------------------------------------------------

## Retro two-tone camper van. Origin at ground level, facing -Z.
## Wheels are returned separately so the controller can spin and steer them.
static func camper_body() -> ArrayMesh:
	var b := Builder.new(11)
	var cream := Color(0.93, 0.88, 0.76)
	var trim := Color(0.16, 0.16, 0.18)
	var chrome := Color(0.66, 0.67, 0.7)
	var length: float = 4.8
	var width: float = 2.0
	var front_z: float = -2.4
	var back_z: float = 2.4
	for side: float in [-1.0, 1.0]:
		# Side mirror on a thin arm, mudflap.
		b.add(_box(Vector3(0.22, 0.04, 0.04)), _at(Vector3(side * 1.08, 1.72, -1.95)), trim)
		b.add(_box(Vector3(0.06, 0.22, 0.15)), _at(Vector3(side * 1.2, 1.72, -1.95)), chrome)
		b.add(_box(Vector3(0.3, 0.3, 0.02)), _at(Vector3(side * 0.86, 0.32, 2.02)), Color(0.1, 0.1, 0.11))
		# Headlight rims and tail lights.
		b.add(_cone(0.17, 0.17, 0.05, 14), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(side * 0.68, 1.05, front_z - 0.01)), chrome)
		b.add(_box(Vector3(0.16, 0.32, 0.05)), _at(Vector3(side * 0.8, 1.05, back_z + 0.01)), Color(0.78, 0.1, 0.08))
		# Indicator lamps.
		b.add(_box(Vector3(0.14, 0.07, 0.04)), _at(Vector3(side * 0.7, 0.8, front_z - 0.01)), Color(1.0, 0.6, 0.15))
		# Door handle.
		b.add(_box(Vector3(0.03, 0.04, 0.16)), _at(Vector3(side * 1.005, 1.6, -1.15)), chrome)
	# Front badge, V-shaped nose trim and chrome bumpers.
	b.add(_cone(0.16, 0.16, 0.04, 16), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.2, front_z - 0.01)), chrome)
	for side: float in [-1.0, 1.0]:
		b.add(_box(Vector3(0.62, 0.05, 0.03)), Transform3D(Basis(Vector3.FORWARD, side * 0.32), Vector3(side * 0.3, 1.32, front_z - 0.008)), cream.darkened(0.06))
	b.add(_box(Vector3(width + 0.06, 0.18, 0.16)), _at(Vector3(0, 0.55, front_z - 0.05)), chrome)
	b.add(_box(Vector3(width + 0.06, 0.18, 0.16)), _at(Vector3(0, 0.55, back_z + 0.05)), chrome)
	# Roof rack with a tied-down crate, roof vent, spare tyre with a cover.
	b.add(_box(Vector3(width - 0.4, 0.05, 2.6)), _at(Vector3(0, 2.6, 0.6)), trim)
	for z: float in [-0.6, 0.6, 1.8]:
		b.add(_box(Vector3(width - 0.3, 0.08, 0.06)), _at(Vector3(0, 2.62, z)), trim)
		for x: float in [-0.82, 0.82]:
			b.add(_box(Vector3(0.05, 0.14, 0.05)), _at(Vector3(x, 2.56, z)), trim)
	b.add(_box(Vector3(1.1, 0.35, 1.0)), _at(Vector3(0, 2.82, 1.2)), Color(0.55, 0.42, 0.28), 0.03)
	b.add(_box(Vector3(1.12, 0.04, 0.06)), _at(Vector3(0, 2.92, 1.05)), Color(0.2, 0.32, 0.5))
	b.add(_box(Vector3(0.5, 0.1, 0.5)), _at(Vector3(0, 2.56, -0.9)), Color(0.85, 0.85, 0.83))
	b.add(_cone(0.36, 0.36, 0.2, 14), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.3, back_z + 0.13)), Color(0.85, 0.5, 0.25))
	b.add(_cone(0.2, 0.2, 0.22, 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.3, back_z + 0.14)), cream)
	# Dark underside so the gap above the road isn't see-through.
	b.add(_box(Vector3(width - 0.2, 0.1, length - 0.4)), _at(Vector3(0, 0.5, 0)), Color(0.08, 0.08, 0.09))
	var mesh: ArrayMesh = b.commit(vertex_color_material(0.4))
	_add_camper_shell(mesh)
	return mesh


## Rounded van shell lofted along Z: rounded-rectangle cross sections with
## bevelled ends, smooth normals, painted by camper_paint.gdshader.
static func _add_camper_shell(mesh: ArrayMesh) -> void:
	const RING: int = 6  # points per corner arc
	var stations: Array[Vector4] = []  # (z, half width, bottom y, top y)
	var bevel: float = 0.3
	var front_inner: float = -2.4 + bevel
	var back_inner: float = 2.4 - bevel
	for k: int in range(6, -1, -1):
		var th: float = PI * 0.5 * k / 6.0
		var inset: float = bevel * (1.0 - cos(th))
		stations.append(Vector4(front_inner - bevel * sin(th), 1.0 - inset, 0.45 + inset * 0.6, 2.42 - inset * 1.2))
	for z: float in [-1.6, -0.8, 0.0, 0.8, 1.6]:
		stations.append(Vector4(z, 1.0, 0.45, 2.5))
	for k: int in 7:
		var th: float = PI * 0.5 * k / 6.0
		var inset: float = bevel * (1.0 - cos(th))
		stations.append(Vector4(back_inner + bevel * sin(th), 1.0 - inset, 0.45 + inset * 0.6, 2.48 - inset * 1.2))
	# The roof eases down towards the windscreen.
	var rings: Array[PackedVector3Array] = []
	for st4: Vector4 in stations:
		var top: float = st4.w - 0.08 * smoothstep(-1.4, -2.2, st4.x)
		rings.append(_rounded_section(st4.x, st4.y, st4.z, top, 0.4, 0.12, RING))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	var n: int = rings[0].size()
	for ri: int in rings.size() - 1:
		var mid_z: float = (stations[ri].x + stations[ri + 1].x) * 0.5
		for i: int in n:
			var j: int = (i + 1) % n
			_shell_tri(st, rings[ri][i], rings[ri + 1][i], rings[ri + 1][j], mid_z)
			_shell_tri(st, rings[ri][i], rings[ri + 1][j], rings[ri][j], mid_z)
	# Flat end caps.
	for cap: int in [0, rings.size() - 1]:
		var ring: PackedVector3Array = rings[cap]
		var centre := Vector3.ZERO
		for p: Vector3 in ring:
			centre += p
		centre /= ring.size()
		var out_dir: float = -1.0 if cap == 0 else 1.0
		for i: int in n:
			var a: Vector3 = ring[i]
			var c: Vector3 = ring[(i + 1) % n]
			var nrm: Vector3 = (c - centre).cross(a - centre)
			if nrm.z * out_dir < 0.0:
				st.add_vertex(centre); st.add_vertex(c); st.add_vertex(a)
			else:
				st.add_vertex(centre); st.add_vertex(a); st.add_vertex(c)
	st.index()
	st.generate_normals()
	var arrays: Array = st.commit_to_arrays()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = CAMPER_PAINT_SHADER
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


static func _rounded_section(z: float, hw: float, bottom: float, top: float, r_top: float, r_bottom: float, per_corner: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	# Corner centres and start angles, going round: bottom-right, top-right, top-left, bottom-left.
	var corners: Array = [
		[Vector2(hw - r_bottom, bottom + r_bottom), r_bottom, -PI * 0.5],
		[Vector2(hw - r_top, top - r_top), r_top, 0.0],
		[Vector2(-hw + r_top, top - r_top), r_top, PI * 0.5],
		[Vector2(-hw + r_bottom, bottom + r_bottom), r_bottom, PI],
	]
	for c: Array in corners:
		for k: int in per_corner:
			var a: float = float(c[2]) + PI * 0.5 * k / (per_corner - 1)
			var p: Vector2 = c[0] + Vector2(cos(a), sin(a)) * float(c[1])
			pts.append(Vector3(p.x, p.y, z))
	return pts


## Adds a triangle wound so its normal faces away from the shell's axis.
static func _shell_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, mid_z: float) -> void:
	var centroid: Vector3 = (a + b + c) / 3.0
	var outward: Vector3 = centroid - Vector3(0, 1.45, mid_z)
	var nrm: Vector3 = (c - a).cross(b - a)
	if nrm.dot(outward) < 0.0:
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
	else:
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)


static func wheel() -> ArrayMesh:
	var b := Builder.new(12)
	var tyre := _cone(0.42, 0.42, 0.32, 12)
	b.add(tyre, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), Color(0.1, 0.1, 0.11))
	b.add(_cone(0.22, 0.22, 0.34, 8), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), Color(0.85, 0.85, 0.82))
	return b.commit(vertex_color_material(0.7))


## Traveller on foot: rain jacket, backpack, cap. ~1.75 m tall, origin at feet, faces -Z.
static func traveller() -> ArrayMesh:
	var b := Builder.new(13)
	var jacket := Color(0.9, 0.48, 0.18)
	var trousers := Color(0.22, 0.25, 0.32)
	var skin := Color(0.87, 0.7, 0.56)
	for x: float in [-0.11, 0.11]:
		b.add(_box(Vector3(0.17, 0.12, 0.28)), _at(Vector3(x, 0.06, -0.03)), Color(0.32, 0.22, 0.14))
		b.add(_box(Vector3(0.16, 0.78, 0.18)), _at(Vector3(x, 0.5, 0)), trousers)
	b.add(_box(Vector3(0.46, 0.62, 0.28)), _at(Vector3(0, 1.17, 0)), jacket, 0.02, 0.04)
	b.add(_box(Vector3(0.5, 0.08, 0.3)), _at(Vector3(0, 0.88, 0)), jacket.darkened(0.15))
	b.add(_box(Vector3(0.04, 0.5, 0.02)), _at(Vector3(0, 1.17, -0.15)), Color(0.75, 0.75, 0.72))
	for x: float in [-0.29, 0.29]:
		b.add(_box(Vector3(0.12, 0.56, 0.14)), Transform3D(Basis(Vector3.FORWARD, x * 0.25), Vector3(x, 1.12, 0)), jacket)
		b.add(_sphere(0.055, 0.1, 6, 3), _at(Vector3(x * 1.08, 0.82, 0)), skin)
	b.add(_box(Vector3(0.36, 0.48, 0.2)), _at(Vector3(0, 1.2, 0.24)), Color(0.32, 0.4, 0.3), 0.02)
	b.add(_box(Vector3(0.3, 0.12, 0.08)), _at(Vector3(0, 1.0, 0.36)), Color(0.28, 0.35, 0.26))
	b.add(_cone(0.06, 0.06, 0.1, 6), _at(Vector3(0, 1.52, 0)), skin)
	b.add(_sphere(0.14, 0.3, 10, 5), _at(Vector3(0, 1.66, 0)), skin)
	_face(b, Vector3(0, 1.66, 0), 0.14, Color(0.3, 0.2, 0.12))
	b.add(_sphere(0.15, 0.17, 10, 4), _at(Vector3(0, 1.75, 0.01)), Color(0.75, 0.2, 0.15))
	b.add(_box(Vector3(0.22, 0.03, 0.12)), Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 1.73, -0.17)), Color(0.65, 0.17, 0.13))
	b.add(_box(Vector3(0.26, 0.08, 0.1)), _at(Vector3(0, 1.66, 0.11)), Color(0.3, 0.2, 0.12))
	return b.commit(vertex_color_material(0.8))


## Traveller split into parts for walk animation. Legs pivot at the hip
## (origin at the joint, hanging down -Y); arms pivot at the shoulder.
static func traveller_parts() -> Dictionary:
	var jacket := Color(0.9, 0.48, 0.18)
	var trousers := Color(0.22, 0.25, 0.32)
	var skin := Color(0.87, 0.7, 0.56)
	var mat := vertex_color_material(0.8)
	var body := Builder.new(13)
	body.add(_box(Vector3(0.46, 0.62, 0.28)), _at(Vector3(0, 1.17, 0)), jacket, 0.02, 0.04)
	body.add(_box(Vector3(0.5, 0.08, 0.3)), _at(Vector3(0, 0.88, 0)), jacket.darkened(0.15))
	body.add(_box(Vector3(0.04, 0.5, 0.02)), _at(Vector3(0, 1.17, -0.15)), Color(0.75, 0.75, 0.72))
	body.add(_box(Vector3(0.36, 0.48, 0.2)), _at(Vector3(0, 1.2, 0.24)), Color(0.32, 0.4, 0.3), 0.02)
	body.add(_box(Vector3(0.3, 0.12, 0.08)), _at(Vector3(0, 1.0, 0.36)), Color(0.28, 0.35, 0.26))
	body.add(_cone(0.06, 0.06, 0.1, 6), _at(Vector3(0, 1.52, 0)), skin)
	body.add(_sphere(0.14, 0.3, 10, 5), _at(Vector3(0, 1.66, 0)), skin)
	_face(body, Vector3(0, 1.66, 0), 0.14, Color(0.3, 0.2, 0.12))
	body.add(_sphere(0.15, 0.17, 10, 4), _at(Vector3(0, 1.75, 0.01)), Color(0.75, 0.2, 0.15))
	body.add(_box(Vector3(0.22, 0.03, 0.12)), Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 1.73, -0.17)), Color(0.65, 0.17, 0.13))
	body.add(_box(Vector3(0.26, 0.08, 0.1)), _at(Vector3(0, 1.66, 0.11)), Color(0.3, 0.2, 0.12))
	body.add(_box(Vector3(0.42, 0.12, 0.22)), _at(Vector3(0, 0.84, 0)), trousers)
	var leg := Builder.new(14)
	leg.add(_box(Vector3(0.16, 0.78, 0.18)), _at(Vector3(0, -0.39, 0)), trousers)
	leg.add(_box(Vector3(0.17, 0.12, 0.28)), _at(Vector3(0, -0.8, -0.03)), Color(0.32, 0.22, 0.14))
	var arm := Builder.new(15)
	arm.add(_box(Vector3(0.12, 0.56, 0.14)), _at(Vector3(0, -0.28, 0)), jacket)
	arm.add(_sphere(0.055, 0.1, 6, 3), _at(Vector3(0, -0.6, 0)), skin)
	return {"body": body.commit(mat), "leg": leg.commit(mat), "arm": arm.commit(mat)}


## Simple friendly face on a head sphere facing -Z: eyes, brows, nose.
static func _face(b: Builder, center: Vector3, radius: float, brow: Color) -> void:
	var front: float = -radius * 0.9
	for x: float in [-0.045, 0.045]:
		b.add(_sphere(0.017, 0.03, 6, 3), _at(center + Vector3(x, 0.01, front)), Color(0.08, 0.06, 0.05))
		b.add(_box(Vector3(0.045, 0.012, 0.012)), _at(center + Vector3(x, 0.045, front + 0.01)), brow)
	b.add(_cone(0.018, 0.0, 0.04, 4), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), center + Vector3(0, -0.02, front - 0.015)), Color(0.82, 0.6, 0.47))
	b.add(_box(Vector3(0.04, 0.008, 0.01)), _at(center + Vector3(0, -0.06, front + 0.02)), Color(0.6, 0.32, 0.28))
