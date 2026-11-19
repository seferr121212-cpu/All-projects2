class_name PropPlacer
extends Node3D
## Places one kind of prop at hand-picked spots (x, z, yaw degrees), snapped
## to the terrain, with an optional box collider and photo subject.

@export var terrain_path: NodePath
## "tent", "beehive", "pottery", "sheep_pen"
@export var kind: String = "tent"
@export var spots: Array[Vector3] = []
@export var collider: Vector3 = Vector3.ZERO
@export var subject_id: StringName = &""
@export var subject_radius: float = 3.0


func _ready() -> void:
	var terrain := get_node(terrain_path) as HighlandTerrain
	var mesh: Mesh
	match kind:
		"tent":
			mesh = AssetLibrary.meshes("nomad_tent", [AnatoliaMeshes.nomad_tent()])[0]
		"beehive":
			mesh = null
		"pottery":
			mesh = AnatoliaMeshes.pottery_wheel()
		_:
			mesh = AnatoliaMeshes.nomad_tent()
	for i: int in spots.size():
		var s: Vector3 = spots[i]
		var body := StaticBody3D.new()
		add_child(body)
		body.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(s.z)), Vector3(s.x, terrain.height_at(s.x, s.y) - 0.05, s.y))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh if mesh else AnatoliaMeshes.beehive(530 + i)
		body.add_child(mi)
		if collider != Vector3.ZERO:
			var shape := BoxShape3D.new()
			shape.size = collider
			var col := CollisionShape3D.new()
			col.shape = shape
			col.position.y = collider.y * 0.5
			body.add_child(col)
		if subject_id != &"" and i == 0:
			var subject := PhotoSubject.new()
			subject.subject_id = subject_id
			subject.name_key = String(subject_id)
			subject.category = PhotoSubject.Category.STRUCTURE
			subject.radius = subject_radius
			subject.value = 0.75
			subject.own_body = body
			subject.position = Vector3(0, 1.2, 0)
			body.add_child(subject)
