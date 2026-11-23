extends Camera3D
## Test için yörünge kamera: sağ tık + sürükle döndürür, tekerlek yakınlaştırır,
## hedefi (topu) yumuşak takip eder.

@export var target_path: NodePath
@export var follow_speed := 4.0

var yaw := -PI * 0.5 + 0.6
var pitch := -0.35
var distance := 18.0

var _target: Node3D
var _focus := Vector3.ZERO


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target:
		_focus = _target.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch - event.relative.y * 0.005, -1.4, -0.05)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(3.0, distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(120.0, distance * 1.1)


func _process(delta: float) -> void:
	if _target:
		_focus = _focus.lerp(_target.global_position, 1.0 - exp(-follow_speed * delta))
	var offset := Vector3(cos(pitch) * sin(yaw), -sin(pitch), cos(pitch) * cos(yaw)) * distance
	global_position = _focus + offset
	look_at(_focus, Vector3.UP)
