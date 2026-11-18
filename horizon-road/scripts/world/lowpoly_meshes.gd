class_name LowPolyMeshes
extends RefCounted
## Builds flat-shaded, vertex-coloured placeholder meshes from primitives.
## Stand-ins until CC0 model packs (Kenney/Quaternius) are dropped into
## assets/models; the faceted look is intentional and matches the art style.

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


static func rock(seed_value: int = 4) -> ArrayMesh:
	var b := Builder.new(seed_value)
	b.add(_sphere(1.0, 1.3, 6, 3), _at(Vector3(0, 0.25, 0)), Color(0.45, 0.44, 0.41), 0.22, 0.08)
	return b.commit(vertex_color_material(0.9))


## Grass tuft: a few double-sided blades with up-facing normals so they light
## like the ground beneath them instead of flickering per blade.
static func grass_tuft(seed_value: int = 5, blades: int = 6, height: float = 0.5) -> ArrayMesh:
	var b := Builder.new(seed_value)
	var root := Color(0.2, 0.33, 0.1)
	var tip := Color(0.5, 0.62, 0.26)
	for i: int in blades:
		var angle: float = b.rng.randf() * TAU
		var offset := Vector3(b.rng.randf_range(-0.18, 0.18), 0, b.rng.randf_range(-0.18, 0.18))
		var side := Vector3(cos(angle), 0, sin(angle)) * 0.045
		var lean := Vector3(b.rng.randf_range(-0.15, 0.15), 0, b.rng.randf_range(-0.15, 0.15))
		var top: Vector3 = offset + lean + Vector3(0, height * b.rng.randf_range(0.6, 1.2), 0)
		var p0: Vector3 = offset - side
		var p1: Vector3 = offset + side
		var mid := root.lerp(tip, 0.5)
		b.tri(p0, top, p1, mid, Vector3.UP)
		b.tri(p1, top, p0, mid, Vector3.UP)
	return b.commit(foliage_material(0.18, 0.6, 0.45))


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


# --- Vehicle ---------------------------------------------------------------

## Retro two-tone camper van. Origin at ground level, facing -Z.
## Wheels are returned separately so the controller can spin and steer them.
static func camper_body() -> ArrayMesh:
	var b := Builder.new(11)
	var teal := Color(0.22, 0.52, 0.52)
	var cream := Color(0.93, 0.88, 0.76)
	var trim := Color(0.2, 0.2, 0.22)
	var glass := Color(0.12, 0.16, 0.2)
	var length: float = 4.8
	var width: float = 2.0
	# Lower teal body and upper cream body.
	b.add(_box(Vector3(width, 1.0, length)), _at(Vector3(0, 0.95, 0)), teal)
	b.add(_box(Vector3(width - 0.04, 1.05, length - 0.7)), _at(Vector3(0, 1.95, 0.35)), cream)
	# Sloped cab front (wedge) with windscreen.
	var front_z: float = -length * 0.5
	var cab_back: float = front_z + 0.25
	var hw: float = (width - 0.04) * 0.5
	var y0: float = 1.45
	var y1: float = 2.47
	var base_l := Vector3(-hw, y0, front_z)
	var base_r := Vector3(hw, y0, front_z)
	var top_l := Vector3(-hw, y1, cab_back + 0.45)
	var top_r := Vector3(hw, y1, cab_back + 0.45)
	b.tri(base_l, top_r, top_l, cream)
	b.tri(base_l, base_r, top_r, cream)
	# Close the wedge sides down to the lower body.
	b.tri(base_l, top_l, Vector3(-hw, y0, top_l.z), cream)
	b.tri(base_r, Vector3(hw, y0, top_r.z), top_r, cream)
	var inset := Vector3(0, 0, -0.02)
	var g0 := base_l.lerp(top_l, 0.18) + Vector3(0.12, 0, 0) + inset
	var g1 := base_r.lerp(top_r, 0.18) + Vector3(-0.12, 0, 0) + inset
	var g2 := base_l.lerp(top_l, 0.9) + Vector3(0.12, 0, 0) + inset
	var g3 := base_r.lerp(top_r, 0.9) + Vector3(-0.12, 0, 0) + inset
	b.tri(g0, g3, g2, glass)
	b.tri(g0, g1, g3, glass)
	# Side windows (both sides) and rear window.
	for side: float in [-1.0, 1.0]:
		for z: float in [-1.15, 0.25, 1.45]:
			var wsize := Vector3(0.04, 0.6, 0.95 if z > -1.0 else 0.7)
			b.add(_box(wsize), _at(Vector3(side * (hw + 0.01), 2.08, z)), glass)
	b.add(_box(Vector3(1.4, 0.55, 0.04)), _at(Vector3(0, 2.08, length * 0.5 - 0.02)), glass)
	# Roof rack + spare tyre + side stripe.
	b.add(_box(Vector3(width - 0.3, 0.06, 2.6)), _at(Vector3(0, 2.55, 0.6)), trim)
	for z: float in [-0.6, 0.6, 1.8]:
		b.add(_box(Vector3(width - 0.2, 0.1, 0.06)), _at(Vector3(0, 2.6, z)), trim)
	b.add(_box(Vector3(1.1, 0.35, 1.0)), _at(Vector3(0, 2.75, 1.2)), Color(0.55, 0.42, 0.28), 0.03)
	b.add(_cone(0.36, 0.36, 0.22, 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.3, length * 0.5 + 0.12)), trim)
	b.add(_box(Vector3(width + 0.02, 0.1, length + 0.02)), _at(Vector3(0, 1.42, 0)), cream.darkened(0.08))
	# Bumpers, headlights, taillights.
	b.add(_box(Vector3(width + 0.1, 0.22, 0.2)), _at(Vector3(0, 0.55, front_z - 0.05)), Color(0.75, 0.75, 0.73))
	b.add(_box(Vector3(width + 0.1, 0.22, 0.2)), _at(Vector3(0, 0.55, length * 0.5 + 0.05)), Color(0.75, 0.75, 0.73))
	for side: float in [-1.0, 1.0]:
		b.add(_cone(0.16, 0.16, 0.06, 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(side * 0.68, 1.05, front_z - 0.02)), Color(1.0, 0.97, 0.85))
		b.add(_box(Vector3(0.18, 0.3, 0.04)), _at(Vector3(side * 0.82, 1.05, length * 0.5 + 0.01)), Color(0.8, 0.12, 0.1))
	# Wheel arches (dark).
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.45, 1.5]:
			b.add(_box(Vector3(0.05, 0.75, 1.0)), _at(Vector3(x * (width * 0.5 + 0.005), 0.6, z)), trim)
	return b.commit(vertex_color_material(0.55))


static func wheel() -> ArrayMesh:
	var b := Builder.new(12)
	var tyre := _cone(0.42, 0.42, 0.32, 12)
	b.add(tyre, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), Color(0.1, 0.1, 0.11))
	b.add(_cone(0.22, 0.22, 0.34, 8), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), Color(0.85, 0.85, 0.82))
	return b.commit(vertex_color_material(0.7))


## Traveller on foot: rain jacket, backpack. ~1.75 m tall, origin at feet.
static func traveller() -> ArrayMesh:
	var b := Builder.new(13)
	var jacket := Color(0.9, 0.48, 0.18)
	b.add(_box(Vector3(0.18, 0.85, 0.2)), _at(Vector3(-0.11, 0.42, 0)), Color(0.22, 0.25, 0.32))
	b.add(_box(Vector3(0.18, 0.85, 0.2)), _at(Vector3(0.11, 0.42, 0)), Color(0.22, 0.25, 0.32))
	b.add(_sphere(0.27, 0.75, 8, 4), _at(Vector3(0, 1.17, 0)), jacket)
	b.add(_box(Vector3(0.36, 0.45, 0.2)), _at(Vector3(0, 1.2, 0.2)), Color(0.32, 0.4, 0.3))
	b.add(_sphere(0.14, 0.28, 8, 4), _at(Vector3(0, 1.62, 0)), Color(0.87, 0.7, 0.56))
	b.add(_sphere(0.15, 0.16, 8, 3), _at(Vector3(0, 1.72, 0)), Color(0.75, 0.2, 0.15))
	return b.commit(vertex_color_material(0.8))
