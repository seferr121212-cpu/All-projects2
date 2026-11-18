class_name FollowCamera
extends Node3D
## Third-person orbit camera with an optional cockpit view. Recenters
## behind the van while driving if the player isn't steering the camera.

enum Mode { THIRD_PERSON, COCKPIT }

@export var mouse_sensitivity: float = 0.0025
@export var stick_sensitivity: float = 2.6
@export var vehicle_distance: float = 9.0
@export var vehicle_height: float = 2.4
@export var walker_distance: float = 4.2
@export var walker_height: float = 1.6
@export var cockpit_offset: Vector3 = Vector3(-0.45, 2.05, -1.35)
@export var recenter_delay: float = 1.8
@export var base_fov: float = 62.0

var target: Node3D
var mode: Mode = Mode.THIRD_PERSON
var yaw: float = 0.0
var pitch: float = -0.18
var follow_vehicle: bool = true

@onready var _spring: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
var _idle_time: float = 10.0
var _smoothed_pos := Vector3.ZERO


func _ready() -> void:
	camera.fov = base_fov
	camera.far = 4500.0
	camera.near = 0.1


func set_target(node: Node3D, is_vehicle: bool) -> void:
	target = node
	follow_vehicle = is_vehicle
	if mode == Mode.COCKPIT and not is_vehicle:
		mode = Mode.THIRD_PERSON
	_spring.clear_excluded_objects()
	if node is CollisionObject3D:
		_spring.add_excluded_object((node as CollisionObject3D).get_rid())
	_smoothed_pos = node.global_position
	yaw = node.global_rotation.y


func toggle_mode() -> void:
	if not follow_vehicle:
		return
	mode = Mode.COCKPIT if mode == Mode.THIRD_PERSON else Mode.THIRD_PERSON
	pitch = -0.05 if mode == Mode.COCKPIT else -0.18
	yaw = target.global_rotation.y


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_rotate_view(-motion.relative.x * mouse_sensitivity, -motion.relative.y * mouse_sensitivity)
	elif event.is_action_pressed(&"toggle_camera"):
		toggle_mode()


func _process(delta: float) -> void:
	if target == null:
		return
	var stick := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	if stick.length() > 0.0:
		_rotate_view(-stick.x * stick_sensitivity * delta, -stick.y * stick_sensitivity * delta)
	_idle_time += delta

	if mode == Mode.COCKPIT:
		_process_cockpit(delta)
	else:
		_process_third_person(delta)


func _process_third_person(delta: float) -> void:
	var speed: float = 0.0
	if follow_vehicle and target is CamperController:
		speed = (target as CamperController).speed
		if _idle_time > recenter_delay and absf(speed) > 2.0:
			var behind: float = target.global_rotation.y + (PI if speed < -0.5 else 0.0)
			yaw = lerp_angle(yaw, behind, 1.0 - exp(-1.6 * delta))
			pitch = lerpf(pitch, -0.2, 1.0 - exp(-1.0 * delta))
	var height: float = vehicle_height if follow_vehicle else walker_height
	var distance: float = vehicle_distance if follow_vehicle else walker_distance
	var goal: Vector3 = target.global_position + Vector3(0, height, 0)
	_smoothed_pos = _smoothed_pos.lerp(goal, 1.0 - exp(-10.0 * delta))
	global_position = _smoothed_pos
	rotation = Vector3(pitch, yaw, 0.0)
	_spring.spring_length = distance
	camera.fov = lerpf(camera.fov, base_fov + clampf(absf(speed) / 21.0, 0.0, 1.0) * 8.0, 1.0 - exp(-3.0 * delta))


func _process_cockpit(_delta: float) -> void:
	var visual: Node3D = target.get_node_or_null(^"Visual")
	var basis_src: Node3D = visual if visual else target
	global_position = basis_src.global_transform * cockpit_offset
	var rel_yaw: float = clampf(wrapf(yaw - target.global_rotation.y, -PI, PI), -1.9, 1.9)
	yaw = target.global_rotation.y + rel_yaw
	global_basis = basis_src.global_basis * Basis.from_euler(Vector3(pitch, rel_yaw, 0.0))
	_spring.spring_length = 0.0
	camera.fov = base_fov + 6.0


func _rotate_view(d_yaw: float, d_pitch: float) -> void:
	yaw += d_yaw
	pitch = clampf(pitch + d_pitch, -1.2, 0.5)
	_idle_time = 0.0
