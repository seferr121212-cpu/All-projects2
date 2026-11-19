extends Node
## Registers every input action at runtime (so remapping stays data-driven),
## tracks whether the player is on gamepad or keyboard/mouse and exposes
## prompt glyphs for the UI. The whole game must be playable with a gamepad only.

signal device_changed(using_gamepad: bool)
signal gamepad_disconnected
signal gamepad_connected

const STICK_DEADZONE := 0.35

## Choice slots, in diamond order: top, right, bottom, left.
const CHOICE_ACTIONS: PackedStringArray = ["choice_1", "choice_2", "choice_3", "choice_4"]

## Locale keys for gamepad glyphs (shown in prompts).
const PAD_GLYPH_KEYS := {
	JOY_BUTTON_A: "input.pad.a",
	JOY_BUTTON_B: "input.pad.b",
	JOY_BUTTON_X: "input.pad.x",
	JOY_BUTTON_Y: "input.pad.y",
	JOY_BUTTON_START: "input.pad.start",
	JOY_BUTTON_BACK: "input.pad.back",
	JOY_BUTTON_LEFT_SHOULDER: "input.pad.lb",
	JOY_BUTTON_RIGHT_SHOULDER: "input.pad.rb",
	JOY_BUTTON_DPAD_UP: "input.pad.dpad_up",
	JOY_BUTTON_DPAD_RIGHT: "input.pad.dpad_right",
	JOY_BUTTON_DPAD_DOWN: "input.pad.dpad_down",
	JOY_BUTTON_DPAD_LEFT: "input.pad.dpad_left",
}

var using_gamepad := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_actions()
	_ensure_ui_navigation()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	using_gamepad = Input.get_connected_joypads().size() > 0


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _btn(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


## Default bindings: action -> Array of InputEvents.
func default_bindings() -> Dictionary:
	return {
		"move_up": [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		"move_down": [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"move_left": [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"camera_up": [_axis(JOY_AXIS_RIGHT_Y, -1.0)],
		"camera_down": [_axis(JOY_AXIS_RIGHT_Y, 1.0)],
		"camera_left": [_axis(JOY_AXIS_RIGHT_X, -1.0)],
		"camera_right": [_axis(JOY_AXIS_RIGHT_X, 1.0)],
		"interact": [_key(KEY_E), _btn(JOY_BUTTON_A)],
		"advance": [_key(KEY_SPACE), _key(KEY_ENTER), _btn(JOY_BUTTON_A), _mouse(MOUSE_BUTTON_LEFT)],
		"choice_1": [_key(KEY_1), _key(KEY_UP), _btn(JOY_BUTTON_Y), _btn(JOY_BUTTON_DPAD_UP)],
		"choice_2": [_key(KEY_2), _key(KEY_RIGHT), _btn(JOY_BUTTON_B), _btn(JOY_BUTTON_DPAD_RIGHT)],
		"choice_3": [_key(KEY_3), _key(KEY_DOWN), _btn(JOY_BUTTON_A), _btn(JOY_BUTTON_DPAD_DOWN)],
		"choice_4": [_key(KEY_4), _key(KEY_LEFT), _btn(JOY_BUTTON_X), _btn(JOY_BUTTON_DPAD_LEFT)],
		"qte_action": [_key(KEY_SPACE), _btn(JOY_BUTTON_A)],
		"pause": [_key(KEY_ESCAPE), _btn(JOY_BUTTON_START)],
		"journal": [_key(KEY_J), _key(KEY_TAB), _btn(JOY_BUTTON_BACK)],
		"tab_prev": [_key(KEY_Q), _btn(JOY_BUTTON_LEFT_SHOULDER)],
		"tab_next": [_key(KEY_R), _btn(JOY_BUTTON_RIGHT_SHOULDER)],
		"debug_perf": [_key(KEY_F3)],
	}


func _register_actions() -> void:
	var bindings := default_bindings()
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2 if action.begins_with("move") or action.begins_with("camera") else 0.5)
		for ev: InputEvent in bindings[action]:
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)


## Make sure built-in ui_* actions work with D-pad, left stick, A and B.
func _ensure_ui_navigation() -> void:
	var extra := {
		"ui_accept": [_btn(JOY_BUTTON_A)],
		"ui_cancel": [_btn(JOY_BUTTON_B)],
		"ui_up": [_btn(JOY_BUTTON_DPAD_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		"ui_down": [_btn(JOY_BUTTON_DPAD_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"ui_left": [_btn(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"ui_right": [_btn(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
	}
	for action: String in extra:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for ev: InputEvent in extra[action]:
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	var pad := using_gamepad
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > STICK_DEADZONE:
			pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > 4.0:
			pad = false
	if pad != using_gamepad:
		using_gamepad = pad
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if pad else Input.MOUSE_MODE_VISIBLE
		device_changed.emit(pad)


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected:
		gamepad_connected.emit()
	else:
		gamepad_disconnected.emit()


## Returns a short, localized prompt glyph for an action on the active device.
func prompt(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for ev: InputEvent in InputMap.action_get_events(action):
		if using_gamepad and ev is InputEventJoypadButton:
			var b := (ev as InputEventJoypadButton).button_index
			if PAD_GLYPH_KEYS.has(b):
				return Localization.t(PAD_GLYPH_KEYS[b])
		elif not using_gamepad and ev is InputEventKey:
			var code := (ev as InputEventKey).physical_keycode
			var logical := DisplayServer.keyboard_get_keycode_from_physical(code)
			return OS.get_keycode_string(logical)
		elif not using_gamepad and ev is InputEventMouseButton:
			return Localization.t("input.mouse.left")
	return ""
