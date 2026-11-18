class_name WalkerController
extends CharacterBody3D
## The traveller on foot. Moves relative to the camera, turns smoothly to
## face the walking direction and bobs a little -- calm, no jumping needed.

const GRAVITY: float = 20.0

@export var walk_speed: float = 3.2
@export var sprint_speed: float = 6.0
@export var acceleration: float = 12.0
@export var turn_speed: float = 10.0

var active: bool = false
var camera_yaw: float = 0.0

@onready var _visual: Node3D = $Visual
var _bob_time: float = 0.0


func _ready() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = LowPolyMeshes.traveller()
	_visual.add_child(mi)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if active:
		input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera_yaw)
	var target_speed: float = sprint_speed if Input.is_action_pressed(&"sprint") else walk_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(dir * target_speed, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	if horizontal.length() > 0.2:
		var target_yaw: float = atan2(-horizontal.x, -horizontal.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
		_bob_time += delta * horizontal.length() * 2.2
		_visual.position.y = absf(sin(_bob_time)) * 0.04
	else:
		_visual.position.y = lerpf(_visual.position.y, 0.0, 10.0 * delta)
