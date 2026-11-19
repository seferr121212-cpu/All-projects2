class_name Settings
extends RefCounted
## Player settings (graphics, audio, gameplay, controls) stored in
## user://settings.cfg via SaveManager, applied at boot and on change.

const QUALITY_KEYS: Array[String] = ["QUALITY_LOW", "QUALITY_MEDIUM", "QUALITY_HIGH", "QUALITY_ULTRA"]
## Per quality level: MSAA, render scale, SSAO, SSIL, volumetric fog, SDFGI,
## shadow atlas, shadow distance, vegetation density.
const QUALITY: Array[Dictionary] = [
	{"msaa": Viewport.MSAA_DISABLED, "scale": 0.75, "ssao": false, "ssil": false, "volumetric": false, "sdfgi": false, "shadow_size": 2048, "shadow_distance": 120.0, "density": 0.45},
	{"msaa": Viewport.MSAA_2X, "scale": 1.0, "ssao": true, "ssil": false, "volumetric": true, "sdfgi": false, "shadow_size": 4096, "shadow_distance": 160.0, "density": 0.7},
	{"msaa": Viewport.MSAA_2X, "scale": 1.0, "ssao": true, "ssil": true, "volumetric": true, "sdfgi": false, "shadow_size": 4096, "shadow_distance": 220.0, "density": 1.0},
	{"msaa": Viewport.MSAA_4X, "scale": 1.0, "ssao": true, "ssil": true, "volumetric": true, "sdfgi": true, "shadow_size": 8192, "shadow_distance": 300.0, "density": 1.0},
]
const DEFAULTS: Dictionary = {
	"graphics": {"quality": 2, "fullscreen": true, "vsync": true, "max_fps": 0},
	"audio": {"Master": 1.0, "Music": 0.7, "SFX": 0.9, "Ambience": 0.9},
	"gameplay": {"day_length": 14.0, "mouse_sensitivity": 1.0, "invert_y": false},
}
## Actions the player can rebind on the keyboard (gamepad bindings stay).
const REBINDABLE: Array[StringName] = [
	&"accelerate", &"brake_reverse", &"steer_left", &"steer_right", &"move_forward", &"move_back",
	&"move_left", &"move_right", &"interact", &"handbrake", &"headlights", &"toggle_camera", &"sprint",
	&"photo_mode", &"sketch_mode", &"journal", &"map", &"quicksave", &"quickload",
]


static func get_value(section: String, key: String) -> Variant:
	return SaveManager.get_setting(section, key, DEFAULTS.get(section, {}).get(key))


static func set_value(section: String, key: String, value: Variant) -> void:
	SaveManager.set_setting(section, key, value)
	match section:
		"graphics":
			apply_graphics()
		"audio":
			apply_audio()
		"gameplay":
			apply_gameplay()


static func quality() -> Dictionary:
	return QUALITY[clampi(int(get_value("graphics", "quality")), 0, QUALITY.size() - 1)]


static func apply_all() -> void:
	apply_graphics()
	apply_audio()
	apply_gameplay()
	apply_controls()


static func apply_graphics() -> void:
	var q: Dictionary = quality()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var vp: Viewport = tree.root
	vp.msaa_3d = q.msaa
	vp.scaling_3d_scale = q.scale
	RenderingServer.directional_shadow_atlas_set_size(q.shadow_size, true)
	if DisplayServer.get_name() != "headless" and not DevCli.is_requested():
		var fs: bool = get_value("graphics", "fullscreen")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value("graphics", "vsync") else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(get_value("graphics", "max_fps"))
	for atmo: Node in tree.get_nodes_in_group(&"atmosphere"):
		(atmo as AtmosphereController).apply_quality(q)


static func apply_audio() -> void:
	for bus: String in ["Master", "Music", "SFX", "Ambience"]:
		var idx: int = AudioServer.get_bus_index(bus)
		if idx >= 0:
			var v: float = float(get_value("audio", bus))
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(idx, v <= 0.001)


static func apply_gameplay() -> void:
	TimeManager.day_length_minutes = float(get_value("gameplay", "day_length"))


## Keyboard rebinds are stored as physical keycodes per action.
static func apply_controls() -> void:
	for action: StringName in REBINDABLE:
		if SaveManager.settings.has_section_key("controls", String(action)):
			set_key(action, int(SaveManager.settings.get_value("controls", String(action))), false)


static func get_key(action: StringName) -> int:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return (ev as InputEventKey).physical_keycode
	return 0


static func key_label(action: StringName) -> String:
	var code: int = get_key(action)
	if code == 0:
		return "—"
	# Show the key as printed on the player's own keyboard layout (headless can't map layouts).
	if DisplayServer.get_name() == "headless":
		return OS.get_keycode_string(code)
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))


## Replaces the keyboard bindings of an action with one key.
static func set_key(action: StringName, code: int, persist: bool = true) -> void:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var k := InputEventKey.new()
	k.physical_keycode = code as Key
	InputMap.action_add_event(action, k)
	if persist:
		SaveManager.set_setting("controls", String(action), code)


static func reset_controls() -> void:
	InputSetup.register_default_actions()
	for action: StringName in REBINDABLE:
		if SaveManager.settings.has_section_key("controls", String(action)):
			SaveManager.settings.erase_section_key("controls", String(action))
	SaveManager.settings.save(SaveManager.SETTINGS_PATH)
