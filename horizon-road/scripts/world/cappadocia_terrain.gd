class_name CappadociaTerrain
extends HighlandTerrain
## Kapadokya: a broad valley floor of vineyards and orchards between eroded
## tuff mesas banded cream, rose and ochre. A dry stream lined with poplars
## winds through it; Erciyes and Hasan Dağı stand snowy on the horizon.

## Volcano cones on the horizon: (x, z, height, radius).
const VOLCANOES: Array[Vector4] = [Vector4(2500.0, -700.0, 640.0, 950.0), Vector4(-2300.0, 1250.0, 360.0, 700.0)]

var _road_near := PackedFloat32Array()
var _near_cell: float = 6.0
var _near_res: int = 0


func _init() -> void:
	terrain_seed = 4219
	road_loop = PackedVector2Array([
		Vector2(-200, 60), Vector2(-160, -40), Vector2(-70, -105), Vector2(40, -120), Vector2(140, -85),
		Vector2(205, 5), Vector2(175, 105), Vector2(85, 165), Vector2(-40, 170), Vector2(-150, 135),
	])
	road_spurs = [PackedVector2Array([Vector2(40, -120), Vector2(48, -190), Vector2(58, -260), Vector2(66, -318)])]
	lake_center = Vector2(99999, 99999)
	lake_radius = 0.0
	tea_garden_radius = 0.0


## Dry stream bed through the valley (z for a given x).
func stream_z(x: float) -> float:
	return 25.0 + 45.0 * sin(x * 0.009 + 0.4) + x * 0.08


func forest_mask(x: float, z: float) -> float:
	var near_stream: float = exp(-pow((z - stream_z(x)) / 34.0, 2.0))
	var orchards: float = smoothstep(0.0, 0.35, _noise_mask.get_noise_2d(x * 1.3 + 40.0, z * 1.3))
	return clampf(near_stream * 0.9 + orchards * 0.35 * (1.0 - _mesa(x, z)), 0.0, 1.0) * (1.0 - _mesa(x, z))


func _compute_water_level() -> float:
	_bake_road_proximity()
	return -50.0


func is_water(_x: float, _z: float) -> bool:
	return false


## Distance (m) to the nearest road centreline, from control polylines; used
## before the real roads exist so mesas keep clear of them.
func _bake_road_proximity() -> void:
	var half: float = size * 0.5
	_near_res = int(size / _near_cell) + 1
	_road_near.resize(_near_res * _near_res)
	var segs: Array[PackedVector2Array] = []
	var loop := road_loop.duplicate()
	loop.append(road_loop[0])
	segs.append(loop)
	for s: PackedVector2Array in road_spurs:
		segs.append(s)
	for iz: int in _near_res:
		for ix: int in _near_res:
			var p := Vector2(-half + ix * _near_cell, -half + iz * _near_cell)
			var best: float = INF
			for poly: PackedVector2Array in segs:
				for k: int in poly.size() - 1:
					best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[k], poly[k + 1])))
			_road_near[iz * _near_res + ix] = best


func _road_near_at(x: float, z: float) -> float:
	var half: float = size * 0.5
	var ix: int = clampi(roundi((x + half) / _near_cell), 0, _near_res - 1)
	var iz: int = clampi(roundi((z + half) / _near_cell), 0, _near_res - 1)
	return _road_near[iz * _near_res + ix]


## 0..1: how much of a tuff mesa stands here (steep-sided).
func _mesa(x: float, z: float) -> float:
	if _road_near.is_empty():
		return 0.0
	var r: float = Vector2(x, z).length() / (size * 0.5)
	var n: float = _noise_mask.get_noise_2d(x * 0.55, z * 0.55) + smoothstep(0.55, 0.95, r) * 0.6
	var stream_clear: float = smoothstep(18.0, 40.0, absf(z - stream_z(x)))
	var road_clear: float = smoothstep(26.0, 48.0, _road_near_at(x, z))
	return smoothstep(0.04, 0.24, n) * road_clear * stream_clear


func _base_height(x: float, z: float) -> float:
	var floor_h: float = _noise_hills.get_noise_2d(x, z) * 5.0 + _noise_detail.get_noise_2d(x, z) * 0.7
	floor_h -= 2.5 * exp(-pow((z - stream_z(x)) / 9.0, 2.0))
	var m: float = _mesa(x, z)
	if m <= 0.0:
		return floor_h
	var r: float = Vector2(x, z).length() / (size * 0.5)
	var top: float = 19.0 + _noise_hills.get_noise_2d(x * 0.7 + 300.0, z * 0.7) * 8.0 + smoothstep(0.6, 1.0, r) * 22.0
	# Gullies bite into the mesa edges (ridged noise), leaving fins and spurs.
	var gully: float = (1.0 - (_noise_ridge.get_noise_2d(x * 1.6, z * 1.6) * 0.5 + 0.5)) * 14.0 * (1.0 - m * 0.6)
	# Rounded, wave-like crests rather than flat table tops.
	var waves: float = sin(x * 0.045 + _noise_detail.get_noise_2d(x, z) * 3.0) * 2.5 * m
	return floor_h + maxf(m * top - gully + waves, 0.0)


func _surface_for(_i: int, x: float, z: float, slope: float) -> Surface:
	if slope > 0.3:
		return Surface.ROCK
	if _mesa(x, z) < 0.3 and absf(z - stream_z(x)) < 5.0:
		return Surface.SAND
	return Surface.GRASS


func _vertex_color(ix: int, iz: int) -> Color:
	var i: int = iz * resolution + ix
	var x: float = -_half + ix * cell
	var z: float = -_half + iz * cell
	var h: float = heights[i]
	var v: float = _noise_mask.get_noise_2d(x * 1.5, z * 1.5) * 0.5 + 0.5
	# Steppe: straw and sage, greener on the irrigated valley floor.
	var steppe := Color(0.7, 0.64, 0.42).lerp(Color(0.6, 0.6, 0.4), v)
	var floor_green := Color(0.46, 0.52, 0.26).lerp(Color(0.56, 0.56, 0.32), v)
	var c: Color = steppe.lerp(floor_green, forest_mask(x, z) * 0.8 * smoothstep(12.0, 3.0, h))
	c = c.darkened(clampf(_curvature(ix, iz) * 0.05, 0.0, 0.15))
	match surfaces[i]:
		Surface.ROCK:
			# Horizontal tuff strata, slightly wavy.
			var band: int = int(floor((h + sin(x * 0.05) * 1.2 + z * 0.01) / 3.2))
			c = AnatoliaMeshes.TUFF_BANDS[posmod(band, AnatoliaMeshes.TUFF_BANDS.size())]
			c = c.darkened(v * 0.08)
		Surface.SAND:
			c = Color(0.82, 0.74, 0.58)
	var road_d: float = road_distance[i]
	if road_d < road_half_width + 1.5:
		c = c.lerp(Color(0.78, 0.7, 0.55), 0.5 * (1.0 - smoothstep(road_half_width, road_half_width + 1.5, road_d)))
	return c


func _build_water() -> void:
	pass


func _backdrop_height(x: float, z: float, t: float, _a: float) -> float:
	# Stepped tuff tablelands...
	var n: float = _backdrop_noise.get_noise_2d(x * 0.7, z * 0.7) * 0.5 + 0.5
	var q: float = n * 4.0
	var steps: float = (floor(q) + smoothstep(0.75, 1.0, fposmod(q, 1.0))) / 4.0
	var h: float = 15.0 + steps * 150.0 * smoothstep(0.0, 0.25, t) + t * 50.0
	# ...and the volcanoes.
	for v: Vector4 in VOLCANOES:
		var d: float = Vector2(x, z).distance_to(Vector2(v.x, v.y))
		if d < v.w:
			var k: float = 1.0 - d / v.w
			h = maxf(h, v.z * pow(k, 1.25) + 30.0)
	return h


func _backdrop_color(p: Vector3, t: float) -> Color:
	var steppe := Color(0.7, 0.62, 0.45).lerp(Color(0.66, 0.6, 0.52), t)
	var band: int = int(p.y / 22.0)
	return steppe.lerp(AnatoliaMeshes.TUFF_BANDS[band % 4], 0.45)
