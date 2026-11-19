class_name ChimneyField
extends Node3D
## Clusters of fairy chimneys (peri bacaları) snapped to the terrain, each
## with a cylinder collider. One photo subject per cluster.

@export var terrain_path: NodePath
## Cluster centre (x, z), radius, count.
@export var clusters: Array[Vector4] = []
@export var field_seed: int = 9


func _ready() -> void:
	var terrain := get_node(terrain_path) as HighlandTerrain
	var rng := RandomNumberGenerator.new()
	rng.seed = field_seed
	var variants: Array[Mesh] = []
	for i: int in 8:
		variants.append(AnatoliaMeshes.fairy_chimney(field_seed * 10 + i, i % 3 == 0))
	variants = AssetLibrary.meshes("fairy_chimney", variants)
	for ci: int in clusters.size():
		var c: Vector4 = clusters[ci]
		var placed: Array[Vector2] = []
		var tries: int = 0
		while placed.size() < int(c.w) and tries < int(c.w) * 20:
			tries += 1
			var p := Vector2(c.x, c.y) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * c.z
			if Vector2(c.x, c.y).distance_to(p) > c.z or terrain.distance_to_road(p.x, p.y) < terrain.road_half_width + 7.0:
				continue
			if terrain.normal_at(p.x, p.y).y < 0.8:
				continue
			var ok: bool = true
			for q: Vector2 in placed:
				if q.distance_to(p) < 7.5:
					ok = false
					break
			if not ok:
				continue
			placed.append(p)
			_place(terrain, p, variants[rng.randi() % variants.size()], rng)
		var subject := PhotoSubject.new()
		subject.subject_id = &"SUBJ_FAIRY_CHIMNEYS"
		subject.name_key = "SUBJ_FAIRY_CHIMNEYS"
		subject.category = PhotoSubject.Category.LANDSCAPE
		subject.radius = c.z * 0.8
		subject.value = 0.85
		add_child(subject)
		subject.global_position = Vector3(c.x, terrain.height_at(c.x, c.y) + 7.0, c.y)


func _place(terrain: HighlandTerrain, p: Vector2, mesh: Mesh, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var s: float = rng.randf_range(0.8, 1.25)
	body.global_transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), Vector3(p.x, terrain.height_at(p.x, p.y) - 0.2, p.y))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var shape := CylinderShape3D.new()
	shape.radius = mesh.get_aabb().size.x * 0.32
	shape.height = mesh.get_aabb().size.y
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = shape.height * 0.5
	body.add_child(col)
