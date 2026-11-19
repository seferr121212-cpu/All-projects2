extends CharacterBody3D
## Third-person walker. Camera-relative movement from the left stick / WASD.
## Movement is enabled only during exploration.

const WALK_SPEED := 2.3
const TURN_SPEED := 10.0
const GRAVITY := 9.8

var enabled := false
var camera_pivot: Node3D
var visual: Node3D


func setup(character_id: String, body: Node3D) -> void:
	name = "Player_" + character_id
	visual = body
	add_child(body)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	shape.shape = cap
	shape.position.y = 0.85
	add_child(shape)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if enabled:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var yaw := camera_pivot.global_rotation.y if camera_pivot else 0.0
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)
	velocity.x = dir.x * WALK_SPEED
	velocity.z = dir.z * WALK_SPEED
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if visual and dir.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), TURN_SPEED * delta)


func facing() -> Vector3:
	return Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y)) if visual else Vector3.FORWARD


## Turn to look at a world position (used when a conversation starts).
func face(target: Vector3) -> void:
	if visual:
		var d := target - global_position
		visual.rotation.y = atan2(d.x, d.z)
