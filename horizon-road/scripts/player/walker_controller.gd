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


var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _swing: float = 0.0


func _ready() -> void:
	var parts: Dictionary = LowPolyMeshes.traveller_parts()
	for key: String in ["body", "leg", "arm"]:
		parts[key] = AssetLibrary.meshes("traveller_" + key, [parts[key]])[0]
	var body := MeshInstance3D.new()
	body.mesh = parts.body
	_visual.add_child(body)
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.11 * side, 0.86, 0)
		var leg := MeshInstance3D.new()
		leg.mesh = parts.leg
		hip.add_child(leg)
		_visual.add_child(hip)
		_legs.append(hip)
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.3 * side, 1.43, 0)
		shoulder.rotation.z = -0.08 * side
		var arm := MeshInstance3D.new()
		arm.mesh = parts.arm
		shoulder.add_child(arm)
		_visual.add_child(shoulder)
		_arms.append(shoulder)


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
	# Walk cycle: legs swing opposite each other, arms counter to the legs.
	var amount: float = clampf(horizontal.length() / sprint_speed, 0.0, 1.0) * 0.75
	_swing = lerpf(_swing, amount, 1.0 - exp(-8.0 * delta))
	var phase: float = sin(_bob_time)
	for i: int in 2:
		var sgn: float = 1.0 if i == 0 else -1.0
		_legs[i].rotation.x = phase * _swing * sgn
		_arms[i].rotation.x = -phase * _swing * 0.8 * sgn
