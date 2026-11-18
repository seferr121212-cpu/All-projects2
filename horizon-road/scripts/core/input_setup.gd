class_name InputSetup
extends RefCounted
## Registers default keyboard/mouse and gamepad bindings at startup.
## Done in code (not project.godot) so the remapping UI in a later stage can
## reset to these defaults from one place.

const DEADZONE: float = 0.2


static func register_default_actions() -> void:
	# Vehicle
	_add("accelerate", [KEY_W, KEY_UP], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_add("brake_reverse", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_add("steer_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_add("steer_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_add("handbrake", [KEY_SPACE], [JOY_BUTTON_B], [])
	_add("headlights", [KEY_L], [JOY_BUTTON_DPAD_UP], [])
	# On foot
	_add("move_forward", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_add("move_back", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_add("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_add("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_add("sprint", [KEY_SHIFT], [JOY_BUTTON_LEFT_STICK], [])
	# Camera
	_add("camera_left", [], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_add("camera_right", [], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_add("camera_up", [], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_add("camera_down", [], [], [[JOY_AXIS_RIGHT_Y, 1.0]])
	_add("toggle_camera", [KEY_C], [JOY_BUTTON_Y], [])
	# General
	_add("interact", [KEY_E], [JOY_BUTTON_X], [])
	_add("pause", [KEY_ESCAPE], [JOY_BUTTON_START], [])
	_add("debug_panel", [KEY_F3], [JOY_BUTTON_BACK], [])


static func _add(action: StringName, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, DEADZONE)
	for key: int in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key as Key
		InputMap.action_add_event(action, ev)
	for button: int in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = button as JoyButton
		InputMap.action_add_event(action, jb)
	for axis_pair: Array in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axis_pair[0] as JoyAxis
		jm.axis_value = axis_pair[1]
		InputMap.action_add_event(action, jm)
