class_name TeaStation
extends Node3D
## Fadime's tea shelter at the edge of the garden, snapped to the slope.

func _ready() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = LowPolyMeshes.tea_shelter()
	add_child(mi)
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 0.8, 0.8)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.4, 0)
	body.add_child(col)
	add_child(body)
	_snap.call_deferred()


func _snap() -> void:
	var region: Region = GameState.current_region
	if region:
		global_position.y = region.get_ground_height(global_position.x, global_position.z) - 0.05
