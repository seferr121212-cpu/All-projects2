extends RefCounted
## Accumulates flat-shaded low-poly primitives (boxes, prisms) with vertex
## colours into one ArrayMesh, so a whole room shares one draw call per
## material. Vertices are in the space of the MeshInstance the batch ends up
## in (world space for locations, part space for character limbs).
## Optional fake ambient occlusion darkens vertices close to the floor.

const AO_HEIGHT := 1.1
const AO_MIN := 0.62

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var ao := true


func is_empty() -> bool:
	return verts.is_empty()


func vertex_count() -> int:
	return verts.size()


func _shade(c: Color, p: Vector3, n: Vector3) -> Color:
	var f := 1.0
	if ao:
		f = lerpf(AO_MIN, 1.0, clampf(p.y / AO_HEIGHT, 0.0, 1.0))
	if n.y > 0.7:
		f *= 1.08  # top faces catch a little more light: stylised
	elif n.y < -0.7:
		f *= 0.8
	return Color(c.r * f, c.g * f, c.b * f, c.a)


## Quad a-b-c-d listed counter-clockwise seen from the front, flat normal.
## Emitted clockwise, which is Godot's front-face winding.
func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	for p in [a, c, b, a, d, c]:
		verts.append(p)
		normals.append(n)
		colors.append(_shade(col, p, n))


func add_tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	for p in [a, c, b]:
		verts.append(p)
		normals.append(n)
		colors.append(_shade(col, p, n))


## Box of `size` centred at xf.origin, oriented by xf.basis.
func add_box(xf: Transform3D, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var c: Array[Vector3] = []
	for i in 8:
		var local := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		c.append(xf * local)
	add_quad(c[4], c[5], c[7], c[6], col)  # +z
	add_quad(c[1], c[0], c[2], c[3], col)  # -z
	add_quad(c[5], c[1], c[3], c[7], col)  # +x
	add_quad(c[0], c[4], c[6], c[2], col)  # -x
	add_quad(c[2], c[6], c[7], c[3], col)  # +y
	add_quad(c[0], c[1], c[5], c[4], col)  # -y


## Box whose faces are split into cells of about `step` metres, so per-vertex
## lighting (forced on the Compatibility renderer) reaches the middle of big
## surfaces such as walls and containers.
func add_box_tiled(xf: Transform3D, size: Vector3, col: Color, step: float = 1.0) -> void:
	if maxf(size.x, maxf(size.y, size.z)) <= step * 1.5:
		add_box(xf, size, col)
		return
	var h := size * 0.5
	# normal, u axis, v axis (u x v = normal, so quads come out counter-clockwise)
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var lu := absf(u.dot(size))
		var lv := absf(v.dot(size))
		var nu := maxi(1, int(ceil(lu / step)))
		var nv := maxi(1, int(ceil(lv / step)))
		var origin := n * absf(n.dot(h)) - u * lu * 0.5 - v * lv * 0.5
		for i in nu:
			for j in nv:
				var p0 := origin + u * (lu * i / nu) + v * (lv * j / nv)
				var du := u * (lu / nu)
				var dv := v * (lv / nv)
				add_quad(xf * p0, xf * (p0 + du), xf * (p0 + du + dv), xf * (p0 + dv), col)


## Upright prism (low-poly cylinder) of radius r and height h centred at
## xf.origin; its axis is xf.basis.y. Flat-shaded sides.
func add_prism(xf: Transform3D, r: float, h: float, col: Color, segments: int = 8, caps: bool = true) -> void:
	var top := Vector3(0, h * 0.5, 0)
	var bot := Vector3(0, -h * 0.5, 0)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := Vector3(sin(a0) * r, 0, cos(a0) * r)
		var p1 := Vector3(sin(a1) * r, 0, cos(a1) * r)
		add_quad(xf * (p0 + bot), xf * (p1 + bot), xf * (p1 + top), xf * (p0 + top), col)
		if caps:
			add_tri(xf * top, xf * (p0 + top), xf * (p1 + top), col)
			add_tri(xf * bot, xf * (p1 + bot), xf * (p0 + bot), col)


## Floor grid with per-cell tint jitter and baked contact shadows: `occluders`
## is an Array of Rect2 footprints (XZ) that darken nearby floor vertices.
func add_floor(size_x: float, size_z: float, cell: float, col: Color, occluders: Array, jitter: float = 0.05) -> void:
	var nx := maxi(1, int(ceil(size_x / cell)))
	var nz := maxi(1, int(ceil(size_z / cell)))
	var x0 := -size_x * 0.5
	var z0 := -size_z * 0.5
	var dx := size_x / nx
	var dz := size_z / nz
	var shade := PackedFloat32Array()
	shade.resize((nx + 1) * (nz + 1))
	for i in nx + 1:
		for j in nz + 1:
			var p := Vector2(x0 + i * dx, z0 + j * dz)
			var edge := minf(minf(p.x - x0, -x0 - p.x), minf(p.y - z0, -z0 - p.y))
			var f := lerpf(0.6, 1.0, clampf(edge / 1.4, 0.0, 1.0))
			for r: Rect2 in occluders:
				var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
				f = minf(f, lerpf(0.55, 1.0, clampf(p.distance_to(q) / 0.7, 0.0, 1.0)))
			shade[i * (nz + 1) + j] = f
	var n := Vector3.UP
	for i in nx:
		for j in nz:
			var h := hash(Vector2i(i, j)) % 1000 / 1000.0
			var tint := 1.0 + (h - 0.5) * 2.0 * jitter
			var corners := [Vector2i(i, j), Vector2i(i, j + 1), Vector2i(i + 1, j + 1), Vector2i(i + 1, j)]
			var ps: Array[Vector3] = []
			var cs: Array[Color] = []
			for k: Vector2i in corners:
				ps.append(Vector3(x0 + k.x * dx, 0.0, z0 + k.y * dz))
				var f := shade[k.x * (nz + 1) + k.y] * tint
				cs.append(Color(col.r * f, col.g * f, col.b * f))
			for idx in [0, 2, 1, 0, 3, 2]:
				verts.append(ps[idx])
				normals.append(n)
				colors.append(cs[idx])


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
