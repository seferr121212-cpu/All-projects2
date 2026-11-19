class_name VegetationScatter
extends Node3D
## Seeded scatter of trees, tea rows, rocks, grass and flowers onto the
## terrain, batched into chunked MultiMeshes so off-screen chunks are culled
## and small things (grass, flowers) fade out with distance.

@export var terrain_path: NodePath
@export var scatter_seed: int = 42
@export var chunk_size: float = 90.0
## Small cells for grass/flowers so visibility-range culling doesn't pop.
@export var detail_chunk_size: float = 24.0
@export var spruce_count: int = 3200
@export var broadleaf_count: int = 450
@export var rock_count: int = 700
@export var grass_count: int = 90000
@export var shrub_count: int = 900
@export var fern_count: int = 2600
@export var birch_count: int = 220
@export var reed_count: int = 320
@export var flower_count: int = 6000
@export_range(0.25, 1.0) var density_scale: float = 1.0
## "highland" (spruce, tea, ferns) or "coastal" (olive, cypress, pine, maquis).
@export var biome: String = "highland"

## World positions of every tea bush (tea harvest places shoots on them).
var tea_positions: PackedVector3Array = PackedVector3Array()
var _terrain: HighlandTerrain
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_terrain = get_node(terrain_path) as HighlandTerrain
	var t0: int = Time.get_ticks_msec()
	_rng.seed = scatter_seed
	density_scale = minf(density_scale, float(Settings.quality().density))
	if biome == "coastal":
		_scatter_coastal()
	elif biome == "steppe" or biome == "plateau":
		_scatter_steppe()
	else:
		_scatter_spruces()
		_scatter_broadleaves()
		_scatter_tea_rows()
		_scatter_understory()
	_scatter_rocks()
	_scatter_grass()
	_scatter_flowers()
	print("[VegetationScatter] built in %d ms" % (Time.get_ticks_msec() - t0))


func _scatter_spruces() -> void:
	var variants: Array[Mesh] = [LowPolyMeshes.spruce(1), LowPolyMeshes.spruce(2), LowPolyMeshes.spruce(3)]
	var buckets: Array[Dictionary] = [{}, {}, {}]
	var placed: int = 0
	var attempts: int = 0
	while placed < int(spruce_count * density_scale) and attempts < spruce_count * 12:
		attempts += 1
		var p: Vector2 = _random_point()
		if not _clear_of_features(p, 7.0, 6.0):
			continue
		var forest: float = _terrain.forest_mask(p.x, p.y)
		if _rng.randf() > forest:
			continue
		var n: Vector3 = _terrain.normal_at(p.x, p.y)
		if n.y < 0.62:
			continue
		var s: float = _rng.randf_range(0.7, 1.45)
		var xf := _ground_transform(p, s, 0.35, 0.04)
		_add(buckets[_rng.randi() % variants.size()], xf, _tint(0.1))
		placed += 1
	for i: int in variants.size():
		_build(buckets[i], variants[i], "Spruce%d" % i, 0.0, true)


func _scatter_broadleaves() -> void:
	var mesh: Mesh = LowPolyMeshes.broadleaf()
	var bucket: Dictionary = {}
	var placed: int = 0
	var attempts: int = 0
	while placed < int(broadleaf_count * density_scale) and attempts < broadleaf_count * 20:
		attempts += 1
		var p: Vector2 = _random_point()
		if not _clear_of_features(p, 8.0, 8.0):
			continue
		var forest: float = _terrain.forest_mask(p.x, p.y)
		# Broadleaves sit at forest edges, not deep inside.
		if forest < 0.12 or forest > 0.65 or _rng.randf() > 0.5:
			continue
		if _terrain.normal_at(p.x, p.y).y < 0.75:
			continue
		_add(bucket, _ground_transform(p, _rng.randf_range(0.8, 1.3), 0.3, 0.05), _tint(0.12))
		placed += 1
	_build(bucket, mesh, "Broadleaf", 0.0, true)


## Tea is planted in contour-following hedgerows on the garden slope.
func _scatter_tea_rows() -> void:
	var mesh: Mesh = LowPolyMeshes.tea_bush()
	var bucket: Dictionary = {}
	var c: Vector2 = _terrain.tea_garden_center
	var r: float = _terrain.tea_garden_radius
	# Rows run perpendicular to the slope (downhill direction).
	var n: Vector3 = _terrain.normal_at(c.x, c.y)
	var downhill := Vector2(n.x, n.z)
	if downhill.length() < 0.01:
		downhill = Vector2(0, 1)
	downhill = downhill.normalized()
	var along := Vector2(-downhill.y, downhill.x)
	var row_spacing: float = 1.9
	var bush_spacing: float = 0.95
	var rows: int = int(r * 2.0 / row_spacing)
	for row: int in rows:
		var offset: float = -r + row * row_spacing
		var steps: int = int(r * 2.0 / bush_spacing)
		for k: int in steps:
			var t: float = -r + k * bush_spacing
			var wobble: float = sin(t * 0.08 + row * 0.5) * 1.2
			var p: Vector2 = c + along * t + downhill * (offset + wobble)
			if p.distance_to(c) > r * (0.85 + 0.15 * sin(t * 0.2)):
				continue
			if _terrain.distance_to_road(p.x, p.y) < 5.0:
				continue
			var s: float = _rng.randf_range(0.85, 1.1)
			var xf := _ground_transform(p, s, 0.08, 0.0)
			# Align with the row so hedges read as continuous lines.
			xf.basis = Basis(Vector3.UP, atan2(along.x, along.y)).scaled(Vector3(s, s * _rng.randf_range(0.85, 1.1), s * 1.3))
			_add(bucket, xf, _tint(0.08))
			tea_positions.append(xf.origin + Vector3(0, 0.85 * s, 0))
	_build(bucket, mesh, "TeaRows", 220.0, true)


## Shrubs at forest edges, ferns on the forest floor, birches near open
## meadows and the lake, reeds along the shore.
func _scatter_understory() -> void:
	var shrubs: Array[Dictionary] = [{}, {}]
	var shrub_meshes: Array[Mesh] = [LowPolyMeshes.shrub(50), LowPolyMeshes.shrub(51)]
	var ferns: Dictionary = {}
	var birches: Dictionary = {}
	var reeds: Dictionary = {}
	var n_shrub: int = 0
	var n_fern: int = 0
	var n_birch: int = 0
	for i: int in int((shrub_count + fern_count + birch_count) * 6 * density_scale):
		var p: Vector2 = _random_point()
		if not _clear_of_features(p, 3.0, 2.0):
			continue
		if _terrain.normal_at(p.x, p.y).y < 0.7:
			continue
		var forest: float = _terrain.forest_mask(p.x, p.y)
		if forest > 0.55 and n_fern < fern_count * density_scale:
			_add(ferns, _ground_transform(p, _rng.randf_range(0.8, 1.4), 0.03, 0.1), _tint(0.12), detail_chunk_size)
			n_fern += 1
		elif forest > 0.12 and forest < 0.6 and n_shrub < shrub_count * density_scale:
			_add(shrubs[n_shrub % 2], _ground_transform(p, _rng.randf_range(0.7, 1.5), 0.15, 0.05), _tint(0.12))
			n_shrub += 1
		elif forest > 0.02 and forest < 0.35 and n_birch < birch_count * density_scale and _rng.randf() < 0.3:
			_add(birches, _ground_transform(p, _rng.randf_range(0.8, 1.25), 0.2, 0.05), _tint(0.08))
			n_birch += 1
	# Reeds in a ring hugging the lake shore.
	var c: Vector2 = _terrain.lake_center
	for i: int in int(reed_count * density_scale):
		var a: float = _rng.randf() * TAU
		var d: float = _terrain.lake_radius * _rng.randf_range(0.9, 1.08)
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * d
		if _terrain.distance_to_road(p.x, p.y) < 6.0:
			continue
		_add(reeds, _ground_transform(p, _rng.randf_range(0.8, 1.2), 0.05, 0.0), _tint(0.1), detail_chunk_size)
	for i: int in shrubs.size():
		_build(shrubs[i], shrub_meshes[i], "Shrubs%d" % i, 0.0, true)
	_build(ferns, LowPolyMeshes.fern(), "Ferns", 70.0, false)
	_build(birches, LowPolyMeshes.birch(), "Birches", 0.0, true)
	_build(reeds, LowPolyMeshes.reeds(), "Reeds", 120.0, false)


## Aegean slopes: olive groves planted in rows on terraces, umbrella pines on
## the hills, cypress sentinels near roads and houses, maquis everywhere.
func _scatter_coastal() -> void:
	var olives: Array[Dictionary] = [{}, {}]
	var olive_meshes: Array[Mesh] = [LowPolyMeshes.olive(100), LowPolyMeshes.olive(110)]
	var grid: float = 9.0
	for gz: int in int(_terrain.size / grid):
		for gx: int in int(_terrain.size / grid):
			var p := Vector2(-_terrain.size * 0.5 + (gx + 0.5) * grid, -_terrain.size * 0.5 + (gz + 0.5) * grid)
			p += Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2))
			if _terrain.forest_mask(p.x, p.y) < 0.35 or not _clear_of_features(p, 5.0, 0.0):
				continue
			if _terrain.normal_at(p.x, p.y).y < 0.8:
				continue
			_add(olives[(gx + gz) % 2], _ground_transform(p, _rng.randf_range(0.8, 1.2), 0.2, 0.06), _tint(0.08))
	var pines: Dictionary = {}
	var cypresses: Dictionary = {}
	var maquis: Array[Dictionary] = [{}, {}]
	var maquis_meshes: Array[Mesh] = [LowPolyMeshes.maquis(103), LowPolyMeshes.maquis(113)]
	var coast := _terrain as CoastalTerrain
	for i: int in int(9000 * density_scale):
		var p: Vector2 = _random_point()
		if not _clear_of_features(p, 3.5, 0.0):
			continue
		var inland: float = coast.distance_inland(p.x, p.y) if coast else 100.0
		if inland < 18.0:
			continue
		var up: float = _terrain.normal_at(p.x, p.y).y
		var roll: float = _rng.randf()
		if roll < 0.05 and inland > 120.0 and up > 0.75:
			_add(pines, _ground_transform(p, _rng.randf_range(0.8, 1.3), 0.3, 0.05), _tint(0.08))
		elif roll < 0.08 and _terrain.distance_to_road(p.x, p.y) < 14.0:
			_add(cypresses, _ground_transform(p, _rng.randf_range(0.8, 1.2), 0.2, 0.0), _tint(0.06))
		elif roll < 0.5 and _terrain.forest_mask(p.x, p.y) < 0.3:
			_add(maquis[i % 2], _ground_transform(p, _rng.randf_range(0.7, 1.6), 0.1, 0.05), _tint(0.1))
	for i: int in olives.size():
		_build(olives[i], olive_meshes[i], "Olives%d" % i, 0.0, true)
	_build(pines, LowPolyMeshes.umbrella_pine(), "Pines", 0.0, true)
	_build(cypresses, LowPolyMeshes.cypress(), "Cypresses", 0.0, true)
	for i: int in maquis.size():
		_build(maquis[i], maquis_meshes[i], "Maquis%d" % i, 0.0, true)


## Inland Anatolia: poplars and orchards along water, vine plots on the
## valley floor (Kapadokya), cushion bushes on the open steppe.
func _scatter_steppe() -> void:
	var poplars: Dictionary = {}
	var orchards: Array[Dictionary] = [{}, {}]
	var orchard_meshes: Array[Mesh] = [AnatoliaMeshes.apricot(401), AnatoliaMeshes.apricot(411)]
	var bushes: Array[Dictionary] = [{}, {}]
	var bush_meshes: Array[Mesh] = [AnatoliaMeshes.steppe_bush(403), AnatoliaMeshes.steppe_bush(413)]
	var vines: Dictionary = {}
	var vine_noise := FastNoiseLite.new()
	vine_noise.seed = scatter_seed + 31
	vine_noise.frequency = 0.012
	var vine_plots: bool = biome == "steppe"
	for i: int in int(14000 * density_scale):
		var p: Vector2 = _random_point()
		if not _clear_of_features(p, 3.5, 2.0):
			continue
		var up: float = _terrain.normal_at(p.x, p.y).y
		if up < 0.8:
			continue
		var wet: float = _terrain.forest_mask(p.x, p.y)
		var roll: float = _rng.randf()
		if roll < 0.06 * wet:
			_add(poplars, _ground_transform(p, _rng.randf_range(0.8, 1.25), 0.2, 0.02), _tint(0.08))
		elif roll < 0.2 * wet:
			_add(orchards[i % 2], _ground_transform(p, _rng.randf_range(0.8, 1.2), 0.15, 0.04), _tint(0.1))
		elif roll < 0.5:
			_add(bushes[i % 2], _ground_transform(p, _rng.randf_range(0.6, 1.4), 0.1, 0.05), _tint(0.1))
	if vine_plots:
		# Rectangular vineyard plots in rows, low bush vines.
		var grid: float = 2.6
		for gz: int in int(_terrain.size / grid):
			for gx: int in int(_terrain.size / grid):
				var p := Vector2(-_terrain.size * 0.5 + (gx + 0.5) * grid, -_terrain.size * 0.5 + (gz + 0.5) * grid * 1.4)
				if vine_noise.get_noise_2d(p.x, p.y) < 0.3 or not _clear_of_features(p, 4.0, 0.0):
					continue
				if _terrain.normal_at(p.x, p.y).y < 0.92 or _terrain.height_at(p.x, p.y) > 10.0:
					continue
				_add(vines, _ground_transform(p, _rng.randf_range(0.8, 1.1), 0.05, 0.0), _tint(0.08), detail_chunk_size * 2.0)
	_build(poplars, AnatoliaMeshes.poplar(), "Poplars", 0.0, true)
	for i: int in 2:
		_build(orchards[i], orchard_meshes[i], "Orchard%d" % i, 0.0, true)
		_build(bushes[i], bush_meshes[i], "SteppeBush%d" % i, 160.0, false)
	_build(vines, AnatoliaMeshes.vine(), "Vines", 180.0, true)


func _scatter_rocks() -> void:
	var variants: Array[Mesh] = [LowPolyMeshes.rock(4), LowPolyMeshes.rock(5)]
	var buckets: Array[Dictionary] = [{}, {}]
	for i: int in int(rock_count * density_scale):
		var p: Vector2 = _random_point()
		if not _clear_of_features(p, 4.5, 3.0):
			continue
		var n: Vector3 = _terrain.normal_at(p.x, p.y)
		var steep: float = 1.0 - n.y
		if _rng.randf() > 0.15 + steep * 3.0:
			continue
		var s: float = _rng.randf_range(0.3, 1.8) * (1.0 + steep * 2.0)
		var xf := _ground_transform(p, s, 0.3 * s, 0.2)
		xf.basis = xf.basis.scaled(Vector3(1.0, _rng.randf_range(0.5, 1.0), _rng.randf_range(0.7, 1.3)))
		_add(buckets[i % 2], xf, _tint(0.1))
	for i: int in variants.size():
		_build(buckets[i], variants[i], "Rocks%d" % i, 0.0, true)


func _scatter_grass() -> void:
	var dry: bool = biome == "steppe" or biome == "coastal"
	var variants: Array[Mesh] = [LowPolyMeshes.grass_tuft(5, 9, 0.42, dry), LowPolyMeshes.grass_tuft(8, 12, 0.6, dry)]
	var buckets: Array[Dictionary] = [{}, {}]
	for i: int in int(grass_count * density_scale):
		var p: Vector2 = _random_point(0.62)
		if _terrain.distance_to_road(p.x, p.y) < _terrain.road_half_width + 0.3:
			continue
		if _terrain.is_in_lake(p.x, p.y, 1.0) or _terrain.in_tea_garden(p.x, p.y) or _terrain.is_water(p.x, p.y):
			continue
		if _terrain.surface_at(p.x, p.y) != HighlandTerrain.Surface.GRASS:
			continue
		var s: float = _rng.randf_range(0.7, 1.4)
		var xf := _ground_transform(p, s, 0.02, 0.0)
		var meadow := Color(1.0, 1.0, 1.0).lerp(Color(1.12, 1.04, 0.8), _rng.randf() * 0.35)
		if biome == "plateau":
			meadow = Color(1.0, 1.0, 1.0).lerp(Color(1.25, 1.1, 0.7), _rng.randf() * 0.6)
		elif dry:
			meadow = Color(1.0, 1.0, 1.0).lerp(Color(0.9, 0.95, 0.85), _rng.randf())
		_add(buckets[i % 2], xf, meadow, detail_chunk_size)
	for i: int in variants.size():
		_build(buckets[i], variants[i], "Grass%d" % i, 75.0, false)


func _scatter_flowers() -> void:
	var colors: Array[Color] = [Color(0.95, 0.85, 0.2), Color(0.62, 0.42, 0.85), Color(0.97, 0.97, 0.95), Color(0.9, 0.35, 0.3)]
	var noise := FastNoiseLite.new()
	noise.seed = scatter_seed + 7
	noise.frequency = 0.02
	for ci: int in colors.size():
		var mesh: Mesh = LowPolyMeshes.flower_tuft(colors[ci], 20 + ci)
		var bucket: Dictionary = {}
		var count: int = int(flower_count * density_scale / colors.size())
		var placed: int = 0
		for i: int in count * 3:
			var p: Vector2 = _random_point(0.6)
			# Flowers bloom in drifts, one colour per patch.
			if noise.get_noise_2d(p.x + ci * 300.0, p.y) < 0.25:
				continue
			if _terrain.surface_at(p.x, p.y) != HighlandTerrain.Surface.GRASS:
				continue
			if _terrain.distance_to_road(p.x, p.y) < 4.0 or _terrain.forest_mask(p.x, p.y) > 0.4:
				continue
			_add(bucket, _ground_transform(p, _rng.randf_range(0.8, 1.3), 0.02, 0.0), Color.WHITE, detail_chunk_size)
			placed += 1
			if placed >= count:
				break
		_build(bucket, mesh, "Flowers%d" % ci, 70.0, false)


# --- Helpers ---------------------------------------------------------------

func _random_point(area_fraction: float = 1.0) -> Vector2:
	var half: float = _terrain.size * 0.5 * area_fraction
	return Vector2(_rng.randf_range(-half, half), _rng.randf_range(-half, half))


func _clear_of_features(p: Vector2, road_margin: float, lake_margin: float) -> bool:
	if not _terrain.is_inside(p.x, p.y, 4.0):
		return false
	if _terrain.distance_to_road(p.x, p.y) < _terrain.road_half_width + road_margin:
		return false
	if _terrain.is_in_lake(p.x, p.y, lake_margin) or _terrain.in_tea_garden(p.x, p.y) or _terrain.is_water(p.x, p.y):
		return false
	for keep_clear: Node in get_tree().get_nodes_in_group(&"vegetation_clearing"):
		var c := keep_clear as Node3D
		if c and Vector2(c.global_position.x, c.global_position.z).distance_to(p) < float(c.get_meta(&"radius", 10.0)):
			return false
	return true


func _ground_transform(p: Vector2, scale_value: float, sink: float, tilt: float) -> Transform3D:
	var y: float = _terrain.height_at(p.x, p.y) - sink
	var basis := Basis(Vector3.UP, _rng.randf() * TAU)
	if tilt > 0.0:
		basis = Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf() * tilt) * basis
	return Transform3D(basis.scaled(Vector3.ONE * scale_value), Vector3(p.x, y, p.y))


func _tint(amount: float) -> Color:
	var k: float = _rng.randf_range(-amount, amount)
	return Color(1.0 + k, 1.0 + k * 0.6, 1.0 + k * 0.8)


func _add(bucket: Dictionary, xf: Transform3D, color: Color, cell_size: float = chunk_size) -> void:
	var key := Vector2i(floori(xf.origin.x / cell_size), floori(xf.origin.z / cell_size))
	if not bucket.has(key):
		bucket[key] = []
	(bucket[key] as Array).append([xf, color])


func _build(bucket: Dictionary, mesh: Mesh, label: String, fade_distance: float, shadows: bool) -> void:
	for key: Variant in bucket:
		var items: Array = bucket[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = items.size()
		for i: int in items.size():
			mm.set_instance_transform(i, items[i][0])
			mm.set_instance_color(i, items[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [label, key.x, key.y]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if fade_distance > 0.0:
			mmi.visibility_range_end = fade_distance
			mmi.visibility_range_end_margin = fade_distance * 0.2
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)
