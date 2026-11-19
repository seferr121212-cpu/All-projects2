class_name GarageStation
extends Node3D
## Recep's village garage and fuel pump, snapped to the ground.

func _ready() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = LowPolyMeshes.garage()
	add_child(mi)
	var body := StaticBody3D.new()
	for spec: Array in [
		[Vector3(6.0, 3.0, 0.3), Vector3(0, 1.5, 2.4)],
		[Vector3(0.3, 3.0, 5.0), Vector3(-3.0, 1.5, 0)],
		[Vector3(0.3, 3.0, 5.0), Vector3(3.0, 1.5, 0)],
		[Vector3(0.7, 1.6, 0.6), Vector3(4.2, 0.8, -1.5)],
	]:
		var shape := BoxShape3D.new()
		shape.size = spec[0]
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position = spec[1]
		body.add_child(col)
	add_child(body)
	var subject := PhotoSubject.new()
	subject.subject_id = &"SUBJ_GARAGE"
	subject.name_key = "SUBJ_GARAGE"
	subject.category = PhotoSubject.Category.STRUCTURE
	subject.radius = 3.5
	subject.value = 0.55
	subject.own_body = body
	subject.position = Vector3(0, 1.8, 0)
	add_child(subject)
	_snap.call_deferred()


func _snap() -> void:
	var region: Region = GameState.current_region
	if region:
		var p: Vector3 = global_position
		var lowest: float = INF
		for c: Vector3 in [Vector3(-3, 0, -2.5), Vector3(3, 0, -2.5), Vector3(-3, 0, 2.5), Vector3(3, 0, 2.5)]:
			var w: Vector3 = global_transform * c
			lowest = minf(lowest, region.get_ground_height(w.x, w.z))
		global_position.y = lowest - 0.1
