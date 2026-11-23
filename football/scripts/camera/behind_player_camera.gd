class_name BehindPlayerCamera
extends Camera3D
## Oyuncu arkası kamera: kontrol edilen oyuncunun bakış yönünün arkasından takip eder.

@export var team_path: NodePath
@export var distance := 7.5
@export var height := 3.5
@export var look_ahead := 6.0
@export var follow_speed := 5.0
@export var turn_speed := 2.5

var team: Team
var _dir := Vector3.RIGHT


func _ready() -> void:
	if team == null and not team_path.is_empty():
		team = get_node_or_null(team_path) as Team


func _process(delta: float) -> void:
	if team == null or team.controlled == null:
		return
	var p := team.controlled
	# Bakış yönü yavaşça döner (kamera sarsılmasın)
	_dir = _dir.slerp(p.facing.normalized(), 1.0 - exp(-turn_speed * delta)).normalized()
	var desired := p.global_position - _dir * distance + Vector3.UP * height
	desired.y = maxf(desired.y, 1.5)
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
	look_at(p.global_position + _dir * look_ahead + Vector3.UP * 1.0, Vector3.UP)
