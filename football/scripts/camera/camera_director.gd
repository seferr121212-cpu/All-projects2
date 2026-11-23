class_name CameraDirector
extends Node
## Kamera yönetimi: oyun kameraları arasında geçiş (camera_next) ve tekrar kamerası.

signal camera_changed(camera: Camera3D)

var cameras: Array[Camera3D] = []
var replay_camera: ReplayCamera
var active_index := 0
var in_replay := false


func add_camera(cam: Camera3D) -> void:
	cameras.append(cam)
	if cameras.size() == 1:
		set_active(0)


func active_camera() -> Camera3D:
	if in_replay and replay_camera:
		return replay_camera
	return cameras[active_index] if not cameras.is_empty() else null


func set_active(i: int) -> void:
	if cameras.is_empty():
		return
	active_index = posmod(i, cameras.size())
	if not in_replay:
		cameras[active_index].make_current()
	camera_changed.emit(active_camera())


func next_camera() -> void:
	set_active(active_index + 1)


func begin_replay() -> void:
	if replay_camera == null:
		return
	in_replay = true
	replay_camera.make_current()
	camera_changed.emit(replay_camera)


func end_replay() -> void:
	in_replay = false
	set_active(active_index)


func _unhandled_input(event: InputEvent) -> void:
	if not in_replay and event.is_action_pressed("camera_next"):
		next_camera()
