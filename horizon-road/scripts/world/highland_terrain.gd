class_name HighlandTerrain
extends Node3D
## Hand-shaped (seeded, not procedural-random) highland: a meadow plateau
## ringed by forested ridges, a gravel road loop, a spur to a viewpoint and a
## small lake. Builds flat-shaded chunk meshes, a heightmap collider, the road
## mesh, the water surface and a distant mountain backdrop.

enum Surface { GRASS, ROAD, MUD, ROCK, SNOW }

const TERRAIN_SHADER: Shader = preload("res://assets/shaders/terrain.gdshader")
const ROAD_SHADER: Shader = preload("res://assets/shaders/road.gdshader")
const WATER_SHADER: Shader = preload("res://assets/shaders/water.gdshader")

@export var terrain_seed: int = 1907
@export var size: float = 720.0
@export var cell: float = 3.0
@export var chunk_cells: int = 40
@export var road_half_width: float = 2.8
## Closed road loop control points (x, z), hand-placed.
@export var road_loop: PackedVector2Array = PackedVector2Array([
	Vector2(-150, 30), Vector2(-138, -60), Vector2(-85, -128), Vector2(0, -152), Vector2(85, -128),
	Vector2(142, -65), Vector2(160, 20), Vector2(128, 102), Vector2(55, 145), Vector2(-25, 155),
	Vector2(-98, 128), Vector2(-142, 88),
])
## Open spur roads: each entry is a polyline.
@export var road_spurs: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(85, -128), Vector2(118, -160), Vector2(150, -182), Vector2(178, -190)]),
]
@export var lake_center: Vector2 = Vector2(25, -15)
@export var lake_radius: float = 34.0
## Tea garden on the south-facing slope: centre, radius.
@export var tea_garden_center: Vector2 = Vector2(20, 205)
@export var tea_garden_radius: float = 48.0

var resolution: int
var heights: PackedFloat32Array
var road_distance: PackedFloat32Array
var surfaces: PackedByteArray
var water_level: float = 0.0
var spawn_transform: Transform3D
var viewpoint_position: Vector3
var road_paths: Array[PackedVector3Array] = []

var _noise_hills := FastNoiseLite.new()
var _noise_detail := FastNoiseLite.new()
var _noise_ridge := FastNoiseLite.new()
var _noise_mask := FastNoiseLite.new()
var _half: float


func _ready() -> void:
	build()


func build() -> void:
	var t0: int = Time.get_ticks_msec()
	_setup_noise()
	_half = size * 0.5
	resolution = int(size / cell) + 1
	water_level = _base_height(lake_center.x, lake_center.y) - 1.2
	_compute_heights()
	_build_roads()
	_classify_surfaces()
	_build_chunks()
	_build_collision()
	_build_road_meshes()
	_build_water()
	_build_backdrop()
	print("[HighlandTerrain] built in %d ms" % (Time.get_ticks_msec() - t0))


# --- Queries ---------------------------------------------------------------

## Exact height of the rendered triangle under (x, z).
func height_at(x: float, z: float) -> float:
	var gx: float = clampf((x + _half) / cell, 0.0, resolution - 1.001)
	var gz: float = clampf((z + _half) / cell, 0.0, resolution - 1.001)
	var ix: int = int(gx)
	var iz: int = int(gz)
	var fx: float = gx - ix
	var fz: float = gz - iz
	var h00: float = heights[iz * resolution + ix]
	var h10: float = heights[iz * resolution + ix + 1]
	var h01: float = heights[(iz + 1) * resolution + ix]
	var h11: float = heights[(iz + 1) * resolution + ix + 1]
	if fx > fz:
		return h00 + (h10 - h00) * fx + (h11 - h10) * fz
	return h00 + (h11 - h01) * fx + (h01 - h00) * fz


func normal_at(x: float, z: float) -> Vector3:
	var e: float = cell
	var dx: float = height_at(x + e, z) - height_at(x - e, z)
	var dz: float = height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


func surface_at(x: float, z: float) -> Surface:
	var i: int = _nearest_index(x, z)
	if road_distance[i] < road_half_width:
		return Surface.ROAD
	return surfaces[i] as Surface


func distance_to_road(x: float, z: float) -> float:
	return road_distance[_nearest_index(x, z)]


func is_in_lake(x: float, z: float, margin: float = 0.0) -> bool:
	return Vector2(x, z).distance_to(lake_center) < lake_radius + margin


func is_inside(x: float, z: float, margin: float = 0.0) -> bool:
	return absf(x) < _half - margin and absf(z) < _half - margin


func in_tea_garden(x: float, z: float) -> bool:
	return Vector2(x, z).distance_to(tea_garden_center) < tea_garden_radius


## 0..1 mask where forests grow (used by vegetation).
func forest_mask(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length() / _half
	var ring: float = smoothstep(0.5, 0.72, r)
	var patches: float = smoothstep(0.1, 0.45, _noise_mask.get_noise_2d(x * 0.8, z * 0.8))
	return clampf(maxf(ring, patches * 0.7), 0.0, 1.0)


# --- Height field ----------------------------------------------------------

func _setup_noise() -> void:
	_noise_hills.seed = terrain_seed
	_noise_hills.frequency = 0.0045
	_noise_hills.fractal_octaves = 3
	_noise_detail.seed = terrain_seed + 1
	_noise_detail.frequency = 0.03
	_noise_detail.fractal_octaves = 2
	_noise_ridge.seed = terrain_seed + 2
	_noise_ridge.frequency = 0.006
	_noise_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_noise_ridge.fractal_octaves = 4
	_noise_mask.seed = terrain_seed + 3
	_noise_mask.frequency = 0.012


## Plateau shape before roads and lake are carved in.
func _base_height(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length() / (size * 0.5)
	# Low rim: enough to frame the plateau, low enough that the sky and the
	# far ranges stay visible from the road.
	var bowl: float = smoothstep(0.6, 1.1, r)
	var rim: float = bowl * bowl * 48.0
	var ridges: float = (_noise_ridge.get_noise_2d(x, z) * 0.5 + 0.5) * 30.0 * smoothstep(0.62, 1.0, r)
	var hills: float = _noise_hills.get_noise_2d(x, z) * 14.0
	var detail: float = _noise_detail.get_noise_2d(x, z) * 1.6
	# Gentle overall tilt so the plateau drains towards the lake side.
	var tilt: float = z * 0.025
	return rim + ridges + hills + detail + tilt


func _compute_heights() -> void:
	heights.resize(resolution * resolution)
	for iz: int in resolution:
		var z: float = -_half + iz * cell
		for ix: int in resolution:
			var x: float = -_half + ix * cell
			var h: float = _base_height(x, z)
			var d: float = Vector2(x, z).distance_to(lake_center)
			if d < lake_radius * 1.9:
				# Bowl-shaped lake bed, then a shore ring that never dips under water.
				var bed: float = water_level + (d / lake_radius - 1.0) * 2.6
				var w: float = 1.0 - smoothstep(lake_radius, lake_radius * 1.9, d)
				h = lerpf(h, bed, w)
				if d > lake_radius * 0.98:
					h = maxf(h, water_level + 0.25 + (d - lake_radius) * 0.04)
			heights[iz * resolution + ix] = h


# --- Roads -----------------------------------------------------------------

func _build_roads() -> void:
	road_distance.resize(resolution * resolution)
	road_distance.fill(INF)
	var road_height := PackedFloat32Array()
	road_height.resize(resolution * resolution)

	road_paths.clear()
	road_paths.append(_road_path(road_loop, true))
	for spur: PackedVector2Array in road_spurs:
		road_paths.append(_road_path(spur, false))

	var flat_radius: float = road_half_width + 2.6
	var blend_radius: float = road_half_width + 14.0
	var reach: int = int(ceil(blend_radius / cell))
	for path: PackedVector3Array in road_paths:
		for p: Vector3 in path:
			var cx: int = roundi((p.x + _half) / cell)
			var cz: int = roundi((p.z + _half) / cell)
			for iz: int in range(maxi(cz - reach, 0), mini(cz + reach + 1, resolution)):
				for ix: int in range(maxi(cx - reach, 0), mini(cx + reach + 1, resolution)):
					var i: int = iz * resolution + ix
					var d: float = Vector2(-_half + ix * cell - p.x, -_half + iz * cell - p.z).length()
					if d < road_distance[i]:
						road_distance[i] = d
						road_height[i] = p.y
	for i: int in heights.size():
		var d: float = road_distance[i]
		if d < blend_radius:
			var t: float = smoothstep(flat_radius, blend_radius, d)
			heights[i] = lerpf(road_height[i] - 0.04, heights[i], t)

	var loop: PackedVector3Array = road_paths[0]
	var a: Vector3 = loop[0]
	var b: Vector3 = loop[6]
	spawn_transform = Transform3D(Basis.looking_at((b - a) * Vector3(1, 0, 1), Vector3.UP), a + Vector3(0, 0.6, 0))
	var spur_end: PackedVector3Array = road_paths[road_paths.size() - 1]
	viewpoint_position = spur_end[spur_end.size() - 1]


## Smooth curve through control points, with heights following the terrain
## but averaged so the road never gets bumpy.
func _road_path(points: PackedVector2Array, closed: bool) -> PackedVector3Array:
	var curve := Curve3D.new()
	curve.bake_interval = 1.5
	var count: int = points.size()
	var total: int = count + (1 if closed else 0)
	for k: int in total:
		var i: int = k % count
		var prev: Vector2 = points[(i - 1 + count) % count] if (closed or i > 0) else points[i]
		var next: Vector2 = points[(i + 1) % count] if (closed or i < count - 1) else points[i]
		var tangent: Vector2 = (next - prev) * 0.22
		var p := Vector3(points[i].x, 0.0, points[i].y)
		curve.add_point(p, -Vector3(tangent.x, 0, tangent.y), Vector3(tangent.x, 0, tangent.y))
	var baked: PackedVector3Array = curve.get_baked_points()
	var n: int = baked.size()
	var hs := PackedFloat32Array()
	hs.resize(n)
	for i: int in n:
		hs[i] = _height_grid_sample(baked[i].x, baked[i].z)
	for _pass: int in 4:
		var smoothed := PackedFloat32Array()
		smoothed.resize(n)
		for i: int in n:
			var sum: float = 0.0
			var weight: float = 0.0
			for k: int in range(-8, 9):
				var j: int = i + k
				if closed:
					j = posmod(j, n)
				elif j < 0 or j >= n:
					continue
				sum += hs[j]
				weight += 1.0
			smoothed[i] = sum / weight
		hs = smoothed
	for i: int in n:
		baked[i].y = hs[i]
	return baked


func _height_grid_sample(x: float, z: float) -> float:
	var ix: int = clampi(roundi((x + _half) / cell), 0, resolution - 1)
	var iz: int = clampi(roundi((z + _half) / cell), 0, resolution - 1)
	return heights[iz * resolution + ix]


func _build_road_meshes() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = ROAD_SHADER
	for path: PackedVector3Array in road_paths:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var along: float = 0.0
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		var prev_v: float = 0.0
		for i: int in path.size():
			var p: Vector3 = path[i]
			var ahead: Vector3 = path[mini(i + 1, path.size() - 1)]
			var behind: Vector3 = path[maxi(i - 1, 0)]
			var tangent: Vector3 = (ahead - behind) * Vector3(1, 0, 1)
			tangent = tangent.normalized()
			var right: Vector3 = tangent.cross(Vector3.UP).normalized()
			var l: Vector3 = p - right * road_half_width + Vector3(0, 0.05, 0)
			var r: Vector3 = p + right * road_half_width + Vector3(0, 0.05, 0)
			if i > 0:
				along += p.distance_to(path[i - 1])
				var v: float = along / 6.0
				# Quad prev_l, prev_r, r, l -- clockwise from above.
				_road_vertex(st, prev_l, 0.0, prev_v)
				_road_vertex(st, r, 1.0, v)
				_road_vertex(st, prev_r, 1.0, prev_v)
				_road_vertex(st, prev_l, 0.0, prev_v)
				_road_vertex(st, l, 0.0, v)
				_road_vertex(st, r, 1.0, v)
				prev_v = v
			prev_l = l
			prev_r = r
		var mesh: ArrayMesh = st.commit()
		mesh.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.name = "Road"
		mi.mesh = mesh
		add_child(mi)


func _road_vertex(st: SurfaceTool, p: Vector3, u: float, v: float) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(u, v))
	st.add_vertex(p)


# --- Surfaces & colours ----------------------------------------------------

func _classify_surfaces() -> void:
	surfaces.resize(resolution * resolution)
	for iz: int in resolution:
		for ix: int in resolution:
			var i: int = iz * resolution + ix
			var x: float = -_half + ix * cell
			var z: float = -_half + iz * cell
			var slope: float = 1.0 - _grid_normal(ix, iz).y
			var s: Surface = Surface.GRASS
			if slope > 0.28:
				s = Surface.ROCK
			elif heights[i] > 95.0:
				s = Surface.SNOW
			elif _noise_mask.get_noise_2d(x * 2.3 + 500.0, z * 2.3) > 0.42 and slope < 0.06:
				s = Surface.MUD
			elif Vector2(x, z).distance_to(lake_center) < lake_radius * 1.12:
				s = Surface.MUD
			surfaces[i] = s


func _grid_normal(ix: int, iz: int) -> Vector3:
	var l: float = heights[iz * resolution + maxi(ix - 1, 0)]
	var r: float = heights[iz * resolution + mini(ix + 1, resolution - 1)]
	var d: float = heights[maxi(iz - 1, 0) * resolution + ix]
	var u: float = heights[mini(iz + 1, resolution - 1) * resolution + ix]
	return Vector3(l - r, 2.0 * cell, d - u).normalized()


func _vertex_color(ix: int, iz: int) -> Color:
	var i: int = iz * resolution + ix
	var x: float = -_half + ix * cell
	var z: float = -_half + iz * cell
	var h: float = heights[i]
	var meadow_var: float = _noise_mask.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
	var lush := Color(0.26, 0.45, 0.15)
	var dry := Color(0.47, 0.53, 0.22)
	var c: Color = lush.lerp(dry, meadow_var * 0.55)
	var forest: float = forest_mask(x, z)
	c = c.lerp(Color(0.17, 0.27, 0.12), forest * 0.75)
	if in_tea_garden(x, z):
		c = c.lerp(Color(0.38, 0.3, 0.2), 0.55)
	match surfaces[i]:
		Surface.ROCK:
			c = Color(0.42, 0.41, 0.38).lerp(Color(0.32, 0.36, 0.26), meadow_var * 0.6)
		Surface.SNOW:
			c = Color(0.85, 0.88, 0.92)
		Surface.MUD:
			c = c.lerp(Color(0.38, 0.33, 0.22), 0.42)
	var road_d: float = road_distance[i]
	if road_d < road_half_width + 1.5:
		c = c.lerp(Color(0.4, 0.4, 0.24), 0.45 * (1.0 - smoothstep(road_half_width, road_half_width + 1.5, road_d)))
	if h < water_level + 0.15:
		c = Color(0.33, 0.33, 0.24)
	return c


# --- Mesh & collision ------------------------------------------------------

func _build_chunks() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	var colors: Array[Color] = []
	colors.resize(resolution * resolution)
	for iz: int in resolution:
		for ix: int in resolution:
			colors[iz * resolution + ix] = _vertex_color(ix, iz)
	var cells: int = resolution - 1
	for cz0: int in range(0, cells, chunk_cells):
		for cx0: int in range(0, cells, chunk_cells):
			var verts := PackedVector3Array()
			var normals := PackedVector3Array()
			var cols := PackedColorArray()
			for iz: int in range(cz0, mini(cz0 + chunk_cells, cells)):
				for ix: int in range(cx0, mini(cx0 + chunk_cells, cells)):
					var p00 := _grid_point(ix, iz)
					var p10 := _grid_point(ix + 1, iz)
					var p01 := _grid_point(ix, iz + 1)
					var p11 := _grid_point(ix + 1, iz + 1)
					var c00: Color = colors[iz * resolution + ix]
					var c10: Color = colors[iz * resolution + ix + 1]
					var c01: Color = colors[(iz + 1) * resolution + ix]
					var c11: Color = colors[(iz + 1) * resolution + ix + 1]
					_face(verts, normals, cols, p00, p10, p11, (c00 + c10 + c11) / 3.0)
					_face(verts, normals, cols, p00, p11, p01, (c00 + c11 + c01) / 3.0)
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_COLOR] = cols
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [cx0 / chunk_cells, cz0 / chunk_cells]
			mi.mesh = mesh
			add_child(mi)


func _grid_point(ix: int, iz: int) -> Vector3:
	return Vector3(-_half + ix * cell, heights[iz * resolution + ix], -_half + iz * cell)


func _face(verts: PackedVector3Array, normals: PackedVector3Array, cols: PackedColorArray,
		a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n: Vector3 = (c - a).cross(b - a).normalized()
	var lin: Color = color.srgb_to_linear()
	verts.append(a)
	verts.append(b)
	verts.append(c)
	for k: int in 3:
		normals.append(n)
		cols.append(lin)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	add_child(body)
	var shape := HeightMapShape3D.new()
	shape.map_width = resolution
	shape.map_depth = resolution
	# The collider is uniformly scaled by `cell`, so heights are stored divided by it.
	var scaled := PackedFloat32Array()
	scaled.resize(heights.size())
	for i: int in heights.size():
		scaled[i] = heights[i] / cell
	shape.map_data = scaled
	var col := CollisionShape3D.new()
	col.shape = shape
	col.scale = Vector3.ONE * cell
	body.add_child(col)


func _build_water() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * lake_radius * 2.6
	mesh.subdivide_width = 8
	mesh.subdivide_depth = 8
	var noise_tex := NoiseTexture2D.new()
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.as_normal_map = true
	noise_tex.bump_strength = 6.0
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	noise_tex.noise = n
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter(&"normal_noise", noise_tex)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Lake"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(lake_center.x, water_level, lake_center.y)
	add_child(mi)


## Far mountain ring outside the playable map. No collision; fog turns it
## into layered silhouettes, which sells the scale of the highlands.
func _build_backdrop() -> void:
	var inner: float = _half * 0.95
	var outer: float = 3200.0
	var rings: int = 14
	var segments: int = 96
	var noise := FastNoiseLite.new()
	noise.seed = terrain_seed + 9
	noise.frequency = 0.0012
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 4
	var pts: Array[PackedVector3Array] = []
	for ri: int in rings + 1:
		var t: float = float(ri) / rings
		var radius: float = lerpf(inner, outer, pow(t, 1.6))
		var row := PackedVector3Array()
		for si: int in segments:
			var a: float = TAU * si / segments
			var x: float = cos(a) * radius
			var z: float = sin(a) * radius
			var peak: float = (noise.get_noise_2d(x, z) * 0.5 + 0.5)
			var h: float = 30.0 + peak * peak * 340.0 * smoothstep(0.0, 0.35, t) + t * 90.0
			if ri == 0:
				h = _base_height(x * (_half * 0.98) / radius, z * (_half * 0.98) / radius) - 10.0
			row.append(Vector3(x, h, z))
		pts.append(row)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	for ri: int in rings:
		var t: float = float(ri) / rings
		for si: int in segments:
			var s2: int = (si + 1) % segments
			var a: Vector3 = pts[ri][si]
			var b: Vector3 = pts[ri][s2]
			var c: Vector3 = pts[ri + 1][si]
			var d: Vector3 = pts[ri + 1][s2]
			var forest := Color(0.16, 0.26, 0.14).lerp(Color(0.3, 0.36, 0.34), t)
			var col_a: Color = forest if a.y < 380.0 else Color(0.8, 0.83, 0.88)
			var col_b: Color = forest if d.y < 380.0 else Color(0.8, 0.83, 0.88)
			_face(verts, normals, cols, a, d, b, col_a)
			_face(verts, normals, cols, a, c, d, col_b)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Backdrop"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _nearest_index(x: float, z: float) -> int:
	var ix: int = clampi(roundi((x + _half) / cell), 0, resolution - 1)
	var iz: int = clampi(roundi((z + _half) / cell), 0, resolution - 1)
	return iz * resolution + ix
