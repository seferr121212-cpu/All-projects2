extends Node3D
## Orbit follow camera (right stick / right-mouse drag) on a SpringArm so it
## never clips through walls, plus a cinematic camera that frames two
## characters over the shoulder during dialogue.

const STICK_SPEED := 2.4
const MOUSE_SPEED := 0.005
const PITCH_MIN := -0.85
const PITCH_MAX := 0.25
const FOLLOW_LERP := 8.0
const CINE_LERP := 3.0

var target: Node3D
var yaw := 0.0
var pitch := -0.28
var height := 1.55
var follow_camera: Camera3D
var cine_camera: Camera3D
var _spring: SpringArm3D
var _focus := false
var _focus_listener := Vector3.ZERO
var _focus_speaker := Vector3.ZERO
var _rotating := false


func setup(follow_target: CollisionObject3D, distance: float, start_yaw: float) -> void:
	target = follow_target
	yaw = start_yaw
	_spring = SpringArm3D.new()
	_spring.spring_length = distance
	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	_spring.shape = sphere
	_spring.add_excluded_object(follow_target.get_rid())
	add_child(_spring)
	follow_camera = Camera3D.new()
	follow_camera.fov = 62.0
	follow_camera.near = 0.05
	follow_camera.far = 80.0
	_spring.add_child(follow_camera)
	cine_camera = Camera3D.new()
	cine_camera.fov = 45.0
	cine_camera.near = 0.05
	cine_camera.far = 80.0
	cine_camera.top_level = true
	add_child(cine_camera)
	follow_camera.current = true
	global_position = target.global_position + Vector3.UP * height
	rotation = Vector3(pitch, yaw, 0)


func _process(delta: float) -> void:
	if target == null:
		return
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if not _focus:
		yaw -= look.x * STICK_SPEED * delta
		pitch = clampf(pitch - look.y * STICK_SPEED * delta, PITCH_MIN, PITCH_MAX)
	global_position = global_position.lerp(target.global_position + Vector3.UP * height, clampf(FOLLOW_LERP * delta, 0, 1))
	rotation = Vector3(pitch, yaw, 0)
	if _focus:
		var dir := (_focus_speaker - _focus_listener)
		dir.y = 0
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
		var side := dir.cross(Vector3.UP).normalized()
		var eye := _focus_listener - dir * 1.3 + side * 0.65 + Vector3.UP * 1.65
		var look_at_pos := _focus_speaker + Vector3.UP * 1.5
		var goal := Transform3D(Basis.IDENTITY, eye).looking_at(look_at_pos, Vector3.UP)
		cine_camera.global_transform = cine_camera.global_transform.interpolate_with(goal, clampf(CINE_LERP * delta, 0, 1))


## Frame `speaker` over the shoulder of `listener` (world positions at feet).
func focus(listener: Vector3, speaker: Vector3) -> void:
	_focus_listener = listener
	_focus_speaker = speaker
	if not _focus:
		cine_camera.global_transform = follow_camera.global_transform
		cine_camera.current = true
	_focus = true


func release() -> void:
	if _focus:
		_focus = false
		# Point the follow camera the way the cinematic one looked.
		yaw = cine_camera.global_rotation.y
		follow_camera.current = true


func camera() -> Camera3D:
	return cine_camera if _focus else follow_camera


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		_rotating = event.pressed
	elif event is InputEventMouseMotion and _rotating and not _focus:
		var m := event as InputEventMouseMotion
		yaw -= m.relative.x * MOUSE_SPEED
		pitch = clampf(pitch - m.relative.y * MOUSE_SPEED, PITCH_MIN, PITCH_MAX)
