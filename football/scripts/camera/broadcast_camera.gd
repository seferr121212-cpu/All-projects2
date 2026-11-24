class_name BroadcastCamera
extends Camera3D
## Yayın kamerası: tribün tarafından (+Z), yüksekten topu yumuşak takip eder.
## Odak ve konum saha sınırlarıyla kısıtlıdır; ceza sahası yakınında hafif yakınlaşır.

const PD = preload("res://scripts/match/pitch_dimensions.gd")

@export var target_path: NodePath
@export var height := 22.0
@export var side_distance := 30.0 # dış çizgiden (+Z) uzaklık
@export var lead_time := 0.35 # topun hızına göre ileri bakma (s)
@export var follow_speed := 3.0
@export var fov_wide := 40.0
@export var fov_close := 31.0

var target: Node3D
var _focus := Vector3.ZERO


func _ready() -> void:
	if target == null and not target_path.is_empty():
		target = get_node_or_null(target_path) as Node3D
	if target:
		_focus = compute_focus(target.global_position, Vector3.ZERO)
	snap()


func snap() -> void:
	global_position = compute_position(_focus)
	look_at(_focus, Vector3.UP)


func _process(delta: float) -> void:
	if target == null:
		return
	var vel := Vector3.ZERO
	if target is RigidBody3D:
		vel = (target as RigidBody3D).linear_velocity
	var desired := compute_focus(target.global_position, vel * lead_time)
	_focus = _focus.lerp(desired, 1.0 - exp(-follow_speed * delta))
	global_position = global_position.lerp(compute_position(_focus), 1.0 - exp(-follow_speed * delta))
	look_at(_focus, Vector3.UP)
	var zoom := clampf((absf(_focus.x) - (PD.HALF_LENGTH - 25.0)) / 15.0, 0.0, 1.0)
	fov = lerpf(fov, lerpf(fov_wide, fov_close, zoom), 1.0 - exp(-2.0 * delta))


## Odak noktası: top + ileri bakış; saha içinde tutulur, z ekseninde yarı takip.
static func compute_focus(ball_pos: Vector3, lead: Vector3) -> Vector3:
	var p := ball_pos + Vector3(lead.x, 0.0, lead.z)
	return Vector3(
		clampf(p.x, -PD.HALF_LENGTH + 6.0, PD.HALF_LENGTH - 6.0),
		0.0,
		clampf(p.z * 0.6, -PD.HALF_WIDTH * 0.5, PD.HALF_WIDTH * 0.5))


## Kamera konumu: tribün hattında, odağı x'te %85 izler (kale arkasına taşmaz).
func compute_position(focus: Vector3) -> Vector3:
	return Vector3(
		clampf(focus.x * 0.85, -PD.HALF_LENGTH + 15.0, PD.HALF_LENGTH - 15.0),
		height,
		PD.HALF_WIDTH + side_distance)
