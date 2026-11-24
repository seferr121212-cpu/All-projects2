class_name SettingsStore
extends RefCounted
## Kullanıcı ayarları: grafik, ses, dil, tuş atamaları. user://settings.json'a kaydedilir.

const PATH := "user://settings.json"
const REBINDABLE: Array[String] = ["move_up", "move_down", "move_left", "move_right", "sprint",
	"pass_short", "pass_through", "pass_lob", "shoot", "tackle", "shoulder", "skill",
	"switch_player", "camera_next", "pause", "reset_ball"]
const SHADOW_SIZES := [0, 1024, 2048, 4096]
const MSAA_MODES := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]

var data := {}
var _default_events := {} # aksiyon -> varsayılan olaylar (Input Map'ten)


static func defaults() -> Dictionary:
	return {
		"graphics": {"fullscreen": false, "vsync": true, "shadows": 2, "msaa": 1, "scale": 1.0},
		"audio": {"master": 0.8, "sfx": 0.8, "crowd": 0.7},
		"language": "tr",
		"bindings": {},
	}


func _init() -> void:
	data = defaults()


## Proje Input Map'indeki varsayılanları saklar ("Varsayılana dön" için).
func capture_default_bindings() -> void:
	for a in REBINDABLE:
		if InputMap.has_action(a):
			_default_events[a] = InputMap.action_get_events(a).duplicate()


func load_from(path := PATH) -> void:
	data = defaults()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for section in ["graphics", "audio"]:
		if parsed.has(section) and typeof(parsed[section]) == TYPE_DICTIONARY:
			for k in parsed[section]:
				data[section][k] = parsed[section][k]
	if parsed.has("language"):
		data.language = str(parsed.language)
	if parsed.has("bindings") and typeof(parsed.bindings) == TYPE_DICTIONARY:
		data.bindings = parsed.bindings


func save_to(path := PATH) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "  "))
	return OK


func apply(tree: SceneTree) -> void:
	apply_graphics(tree)
	apply_audio()
	apply_language()
	apply_bindings()


func apply_graphics(tree: SceneTree) -> void:
	var g: Dictionary = data.graphics
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if g.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if g.vsync else DisplayServer.VSYNC_DISABLED)
	var root := tree.root
	root.msaa_3d = MSAA_MODES[clampi(int(g.msaa), 0, MSAA_MODES.size() - 1)]
	root.scaling_3d_scale = clampf(float(g.scale), 0.5, 1.0)
	var shadow_size: int = SHADOW_SIZES[clampi(int(g.shadows), 0, 3)]
	if shadow_size > 0:
		RenderingServer.directional_shadow_atlas_set_size(shadow_size, true)


func shadows_enabled() -> bool:
	return int(data.graphics.shadows) > 0


func apply_audio() -> void:
	ensure_audio_buses()
	var a: Dictionary = data.audio
	_set_bus_volume("Master", float(a.master))
	_set_bus_volume("SFX", float(a.sfx))
	_set_bus_volume("Crowd", float(a.crowd))


## SFX ve Crowd ses kanallarını (Master'a bağlı) oluşturur.
static func ensure_audio_buses() -> void:
	for bus_name in ["SFX", "Crowd"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")


static func _set_bus_volume(bus_name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(clampf(linear, 0.0, 1.0)))
		AudioServer.set_bus_mute(i, linear <= 0.001)


func apply_language() -> void:
	TranslationServer.set_locale(str(data.language))


# --- Tuş atamaları ----------------------------------------------------------------

## Olayın türü: klavye/fare -> "keyboard", gamepad -> "gamepad".
static func event_kind(ev: InputEvent) -> String:
	if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
		return "gamepad"
	return "keyboard"


static func event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"type": "key", "code": int(ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode)}
	if ev is InputEventMouseButton:
		return {"type": "mouse", "button": int(ev.button_index)}
	if ev is InputEventJoypadButton:
		return {"type": "joy_button", "button": int(ev.button_index)}
	if ev is InputEventJoypadMotion:
		return {"type": "joy_axis", "axis": int(ev.axis), "value": signf(ev.axis_value)}
	return {}


static func dict_to_event(d: Dictionary) -> InputEvent:
	match str(d.get("type", "")):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(d.code)
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = int(d.button)
			return m
		"joy_button":
			var b := InputEventJoypadButton.new()
			b.button_index = int(d.button)
			return b
		"joy_axis":
			var j := InputEventJoypadMotion.new()
			j.axis = int(d.axis)
			j.axis_value = float(d.value)
			return j
	return null


## Bir aksiyonun klavye ya da gamepad atamasını değiştirir (aynı türdeki eski olaylar silinir).
func set_binding(action: String, ev: InputEvent) -> void:
	var kind := event_kind(ev)
	var kept: Array[InputEvent] = []
	for old in InputMap.action_get_events(action):
		if event_kind(old) != kind:
			kept.append(old)
	kept.append(ev)
	InputMap.action_erase_events(action)
	var serial := []
	for e in kept:
		InputMap.action_add_event(action, e)
		serial.append(event_to_dict(e))
	data.bindings[action] = serial


func apply_bindings() -> void:
	for action in data.bindings:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for d in data.bindings[action]:
			var ev := dict_to_event(d)
			if ev:
				InputMap.action_add_event(action, ev)


func reset_bindings() -> void:
	data.bindings = {}
	for a in _default_events:
		InputMap.action_erase_events(a)
		for e in _default_events[a]:
			InputMap.action_add_event(a, e)


## Arayüzde gösterilecek atama metni (ör. "Shift", "Joy 0").
static func binding_text(action: String, kind: String) -> String:
	var parts: Array[String] = []
	for e in InputMap.action_get_events(action):
		if event_kind(e) != kind:
			continue
		if e is InputEventKey:
			var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
			# Klavye düzenine göre ad (headless sunucu bunu desteklemez)
			if e.physical_keycode != 0 and DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(e.physical_keycode)
			parts.append(OS.get_keycode_string(code))
		elif e is InputEventMouseButton:
			parts.append("Mouse %d" % e.button_index)
		elif e is InputEventJoypadButton:
			parts.append("Joy %d" % e.button_index)
		elif e is InputEventJoypadMotion:
			parts.append("Axis %d%s" % [e.axis, "+" if e.axis_value > 0 else "-"])
	return ", ".join(parts) if not parts.is_empty() else "-"
