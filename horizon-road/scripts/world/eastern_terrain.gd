class_name EasternTerrain
extends HighlandTerrain
## Doğu Anadolu: a high, wide-open plateau of rolling steppe and summer
## pasture (yayla) around a cold mountain lake, dark basalt outcrops, and
## the twin snow cones of Ağrı filling the eastern horizon.

## (x, z, height, radius): Büyük Ağrı, Küçük Ağrı, and a lower ridge volcano west.
const VOLCANOES: Array[Vector4] = [
	Vector4(2600.0, -1100.0, 980.0, 1350.0), Vector4(1850.0, -380.0, 470.0, 620.0), Vector4(-2600.0, -600.0, 330.0, 800.0),
]


func _init() -> void:
	terrain_seed = 5303
	road_loop = PackedVector2Array([
		Vector2(-210, -20), Vector2(-170, -120), Vector2(-60, -170), Vector2(60, -160), Vector2(160, -100),
		Vector2(200, 10), Vector2(150, 120), Vector2(40, 175), Vector2(-80, 180), Vector2(-185, 90),
	])
	road_spurs = [PackedVector2Array([Vector2(160, -100), Vector2(215, -150), Vector2(265, -200), Vector2(305, -235)])]
	lake_center = Vector2(-60, 60)
	lake_radius = 58.0
	tea_garden_radius = 0.0


func forest_mask(x: float, z: float) -> float:
	# Treeless steppe; a few willows and poplars by the lake and village.
	var lake: float = 1.0 - smoothstep(lake_radius * 1.1, lake_radius * 1.8, Vector2(x, z).distance_to(lake_center))
	return lake * 0.25


func _base_height(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length() / (size * 0.5)
	var swell: float = _noise_hills.get_noise_2d(x * 0.8, z * 0.8) * 16.0
	var rim: float = pow(smoothstep(0.62, 1.1, r), 2.0) * 60.0
	rim += (_noise_ridge.get_noise_2d(x, z) * 0.5 + 0.5) * 26.0 * smoothstep(0.65, 1.0, r)
	# Basalt outcrops break the grass here and there.
	var crag: float = maxf(_noise_mask.get_noise_2d(x * 2.0 + 77.0, z * 2.0) - 0.45, 0.0) * 22.0
	return swell + rim + crag + _noise_detail.get_noise_2d(x, z) * 1.2


func _surface_for(i: int, x: float, z: float, slope: float) -> Surface:
	if slope > 0.3:
		return Surface.ROCK
	if Vector2(x, z).distance_to(lake_center) < lake_radius * 1.08:
		return Surface.MUD
	return Surface.GRASS


func _vertex_color(ix: int, iz: int) -> Color:
	var i: int = iz * resolution + ix
	var x: float = -_half + ix * cell
	var z: float = -_half + iz * cell
	var h: float = heights[i]
	var v: float = _noise_mask.get_noise_2d(x * 1.4, z * 1.4) * 0.5 + 0.5
	# Short summer pasture: fresh green in hollows, straw on the swells.
	var c: Color = Color(0.36, 0.5, 0.2).lerp(Color(0.55, 0.58, 0.3), smoothstep(0.35, 0.85, v) * 0.6)
	var curv: float = _curvature(ix, iz)
	c = c.lerp(Color(0.3, 0.48, 0.18), clampf(curv * 0.08, 0.0, 0.4))
	c = c.lerp(Color(0.64, 0.6, 0.36), clampf(-curv * 0.06, 0.0, 0.35))
	match surfaces[i]:
		Surface.ROCK:
			c = c.lerp(Color(0.42, 0.42, 0.36).lerp(Color(0.5, 0.48, 0.42), v), 0.65)
		Surface.MUD:
			c = c.lerp(Color(0.32, 0.4, 0.22), 0.5)
	var road_d: float = road_distance[i]
	if road_d < road_half_width + 1.5:
		c = c.lerp(c.darkened(0.15), 0.6 * (1.0 - smoothstep(road_half_width, road_half_width + 1.5, road_d)))
	if h < water_level + 0.15 and Vector2(x, z).distance_to(lake_center) < lake_radius * 1.25:
		c = Color(0.3, 0.32, 0.26)
	return c


func _backdrop_height(x: float, z: float, t: float, _a: float) -> float:
	var n: float = _backdrop_noise.get_noise_2d(x, z) * 0.5 + 0.5
	var h: float = 30.0 + pow(n, 1.6) * 260.0 * smoothstep(0.0, 0.3, t) + t * 70.0
	for v: Vector4 in VOLCANOES:
		var d: float = Vector2(x, z).distance_to(Vector2(v.x, v.y))
		if d < v.w:
			var k: float = 1.0 - d / v.w
			# Concave volcano flanks, slightly rounded summit.
			h = maxf(h, v.z * (pow(k, 1.6) - 0.04 * pow(k, 12.0)) + 40.0)
	return h


func _backdrop_color(p: Vector3, t: float) -> Color:
	var steppe := Color(0.4, 0.46, 0.24).lerp(Color(0.48, 0.5, 0.42), t)
	return steppe.lerp(Color(0.42, 0.38, 0.34), clampf((p.y - 160.0) / 200.0, 0.0, 0.8))
