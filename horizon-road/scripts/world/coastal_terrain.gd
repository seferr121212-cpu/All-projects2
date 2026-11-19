class_name CoastalTerrain
extends HighlandTerrain
## Aegean fishing village: a bay with a sandy beach and turquoise shallows,
## terraced olive slopes behind it, a rocky headland to the east and low dry
## hills to the north. Islands rise from the sea on the horizon.

@export var headland_center: Vector2 = Vector2(235, 110)
@export var headland_radius: float = 70.0
## Olive grove band on the slopes (distance from the shore, in metres).
@export var grove_from: float = 60.0
@export var grove_to: float = 230.0

var _noise_island := FastNoiseLite.new()


func _init() -> void:
	terrain_seed = 3501
	road_loop = PackedVector2Array([
		Vector2(-250, -10), Vector2(-180, 10), Vector2(-110, 10), Vector2(-40, 10), Vector2(30, 0),
		Vector2(100, 25), Vector2(170, 45), Vector2(240, 30), Vector2(260, -50), Vector2(200, -140),
		Vector2(100, -175), Vector2(0, -160), Vector2(-110, -150), Vector2(-210, -110), Vector2(-265, -60),
	])
	road_spurs = [PackedVector2Array([Vector2(0, -160), Vector2(-8, -220), Vector2(-15, -275), Vector2(-20, -315)])]
	lake_center = Vector2(99999, 99999)
	lake_radius = 0.0
	tea_garden_radius = 0.0


## Coastline z for a given x: positive side (larger z) is sea.
func coast_z(x: float) -> float:
	return 70.0 + 35.0 * sin(x * 0.011 + 0.5) - 70.0 * exp(-pow((x - 40.0) / 80.0, 2.0))


## Signed distance-ish to the shore: > 0 at sea, < 0 inland.
func sea_side(x: float, z: float) -> float:
	var s: float = z - coast_z(x)
	var hd: float = Vector2(x, z).distance_to(headland_center)
	if hd < headland_radius:
		s -= smoothstep(0.0, 1.0, 1.0 - hd / headland_radius) * 55.0
	return s


func is_water(x: float, z: float) -> bool:
	return height_at(x, z) < water_level


func distance_inland(x: float, z: float) -> float:
	return -sea_side(x, z)


## Olive groves: a band on the slopes, broken into terraces/patches.
func forest_mask(x: float, z: float) -> float:
	var d: float = distance_inland(x, z)
	var band: float = smoothstep(grove_from, grove_from + 30.0, d) * (1.0 - smoothstep(grove_to - 40.0, grove_to, d))
	var patches: float = smoothstep(-0.2, 0.3, _noise_mask.get_noise_2d(x * 0.7, z * 0.7))
	return clampf(band * patches, 0.0, 1.0)


func _compute_water_level() -> float:
	_noise_island.seed = terrain_seed + 21
	_noise_island.frequency = 0.0011
	return 0.0


func _base_height(x: float, z: float) -> float:
	var s: float = sea_side(x, z)
	if s > 0.0:
		# Shallow turquoise shelf, then deeper blue.
		return -0.4 - minf(s * 0.07, 2.5) - maxf(s - 60.0, 0.0) * 0.12
	var d: float = -s
	var beach: float = smoothstep(0.0, 22.0, d) * 1.6
	var hills: float = smoothstep(15.0, 170.0, d) * (_noise_hills.get_noise_2d(x, z) * 12.0 + 16.0 + d * 0.06)
	var r: float = Vector2(x, minf(z, 0.0)).length() / (size * 0.5)
	var rim: float = pow(smoothstep(0.62, 1.1, r), 2.0) * 55.0
	rim += (_noise_ridge.get_noise_2d(x, z) * 0.5 + 0.5) * 20.0 * smoothstep(0.7, 1.0, r)
	var hd: float = Vector2(x, z).distance_to(headland_center)
	var headland: float = smoothstep(0.0, 1.0, maxf(0.0, 1.0 - hd / (headland_radius * 1.3))) * 14.0
	return beach + hills + rim + headland + _noise_detail.get_noise_2d(x, z) * 0.8


func _surface_for(i: int, x: float, z: float, slope: float) -> Surface:
	var d: float = distance_inland(x, z)
	if slope > 0.3:
		return Surface.ROCK
	if d < 20.0:
		return Surface.ROCK if Vector2(x, z).distance_to(headland_center) < headland_radius else Surface.SAND
	return Surface.GRASS


func _vertex_color(ix: int, iz: int) -> Color:
	var i: int = iz * resolution + ix
	var x: float = -_half + ix * cell
	var z: float = -_half + iz * cell
	var h: float = heights[i]
	var d: float = distance_inland(x, z)
	var dry := Color(0.68, 0.64, 0.38)
	var green := Color(0.48, 0.55, 0.26)
	var v: float = _noise_mask.get_noise_2d(x * 1.5, z * 1.5) * 0.5 + 0.5
	var c: Color = dry.lerp(green, v * 0.6)
	c = c.lerp(Color(0.56, 0.5, 0.36), forest_mask(x, z) * 0.45)  # tilled grove soil
	var curvature: float = _curvature(ix, iz)
	c = c.darkened(clampf(curvature * 0.05, 0.0, 0.15))
	match surfaces[i]:
		Surface.SAND:
			c = Color(0.93, 0.86, 0.68).lerp(Color(0.85, 0.76, 0.58), smoothstep(10.0, 20.0, d))
		Surface.ROCK:
			c = Color(0.72, 0.7, 0.66).lerp(Color(0.6, 0.58, 0.52), v)
	if h < water_level + 0.3:
		# Underwater: pale sand in the shallows, darker seagrass further out.
		c = Color(0.86, 0.82, 0.66).lerp(Color(0.35, 0.45, 0.35), smoothstep(-0.5, -3.0, h))
	var road_d: float = road_distance[i]
	if road_d < road_half_width + 1.5:
		c = c.lerp(Color(0.75, 0.68, 0.5), 0.5 * (1.0 - smoothstep(road_half_width, road_half_width + 1.5, road_d)))
	return c


func _build_water() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(7000, 7000)
	mesh.subdivide_width = 24
	mesh.subdivide_depth = 24
	var noise_tex := NoiseTexture2D.new()
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.as_normal_map = true
	noise_tex.bump_strength = 8.0
	var n := FastNoiseLite.new()
	n.frequency = 0.035
	noise_tex.noise = n
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter(&"normal_noise", noise_tex)
	mat.set_shader_parameter(&"shallow_color", Color(0.3, 0.85, 0.82))
	mat.set_shader_parameter(&"deep_color", Color(0.02, 0.22, 0.42))
	mat.set_shader_parameter(&"depth_range", 6.0)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, water_level, 1200)
	add_child(mi)


## Islands out at sea, dry hills inland.
func _backdrop_height(x: float, z: float, t: float, a: float) -> float:
	var seaward: float = smoothstep(-0.1, 0.35, sin(a))  # +z is the sea
	var hills: float = 20.0 + (_backdrop_noise.get_noise_2d(x * 1.2, z * 1.2) * 0.5 + 0.5) * 110.0 * smoothstep(0.0, 0.3, t) + t * 40.0
	var island: float = _noise_island.get_noise_2d(x, z)
	var island_h: float = -20.0
	if island > 0.2 and t > 0.25:
		# Rounded, low islands (smoothstep dome), not spikes.
		island_h = smoothstep(0.2, 0.55, island) * 130.0 - 8.0
	return lerpf(hills, island_h, seaward)


func _backdrop_color(p: Vector3, t: float) -> Color:
	if p.y < 2.0:
		return Color(0.85, 0.8, 0.62)
	var scrub := Color(0.42, 0.46, 0.26).lerp(Color(0.5, 0.55, 0.5), t)
	return scrub.lerp(Color(0.62, 0.56, 0.4), clampf(sin(p.x * 0.01 + p.z * 0.007) * 0.5 + 0.2, 0.0, 0.6))
