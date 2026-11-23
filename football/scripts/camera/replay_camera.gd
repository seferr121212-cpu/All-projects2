class_name ReplayCamera
extends Camera3D
## Tekrar kamerası: alçak açıdan, verilen odak noktasını (tekrar karesindeki top) izler.
## Faz 5'te gol tekrarlarında ReplayRecorder ile birlikte kullanılacak.

@export var distance := 12.0
@export var height := 3.0
@export var orbit_speed := 0.15 # rad/s, yavaş dönen sinematik açı

var focus := Vector3.ZERO
var _angle := 0.6


func _process(delta: float) -> void:
	if not current:
		return
	_angle += orbit_speed * delta
	var offset := Vector3(sin(_angle), 0.0, cos(_angle)) * distance + Vector3.UP * height
	global_position = global_position.lerp(focus + offset, 1.0 - exp(-4.0 * delta))
	look_at(focus + Vector3.UP * 0.5, Vector3.UP)
