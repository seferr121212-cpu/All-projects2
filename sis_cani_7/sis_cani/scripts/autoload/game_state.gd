extends Node
## Oyun durumu, envanter, kayıt sistemi, ayarlar, başarımlar ve giriş haritası.

signal inventory_changed

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const MAX_FUEL := 100.0

var main = null     # scripts/main.gd
var player = null   # Kerem
var level = null    # LevelBase
var hud = null      # HUD

var input_locked: int = 0

var chapter: int = 1
var flags: Dictionary = {}
var pages: Array = []
var tapes: Array = []
var letters: Array = []
var seen: Array = []          # Yankı ansiklopedisi: görülen türler
var wicks: int = 0            # lamba fitili yükseltmeleri
var gears: int = 0
var stat_time := 0.0
var stat_caught := 0
var stat_braziers := 0
var playtime := 0.0
var has_lamp: bool = false
var has_radio: bool = false
var has_bell: bool = false
var has_red: bool = false
var fuel: float = MAX_FUEL
var checkpoint_pos: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false
var ran_dry_this_chapter: bool = false

var settings: Dictionary = {
	"lang": "tr",
	"voice_lang": "tr",
	"subtitles": true,
	"music": 0.7,
	"sfx": 0.9,
	"voice": 1.0,
	"unlocked": 1,
	"postfx": true,
	"fullscreen": false,
	"shake": true,
	"master": 1.0,
	"sub_size": 1,
	"difficulty": 1,
	"timer": false,
	"captions": true,
	"vsync": true,
	"max_fps": 0,
	"binds": {},
	"window": 1,
	"lang_chosen": false,
	"lit": false,
	"achievements": [],
}

const ACHIEVEMENTS := ["NO_DARK", "POSTMAN", "BELL", "SILENCE", "DARK", "LETTERS", "BELLS", "WICKS", "GHOST", "KEEPER", "PROLOGUE", "TAPES"]
const LOG_PATH := "user://log.txt"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()
	apply_binds()


func _process(delta: float) -> void:
	if level != null and is_instance_valid(level) and not get_tree().paused:
		stat_time += delta
		playtime += delta


# ------------------------------------------------------------------ zorluk
func drain_mult() -> float:
	return [0.6, 1.0, 1.4][clampi(int(settings.get("difficulty", 1)), 0, 2)]


func echo_speed_mult() -> float:
	return [0.8, 1.0, 1.2][clampi(int(settings.get("difficulty", 1)), 0, 2)]


func dark_limit() -> float:
	return [11.0, 8.0, 5.0][clampi(int(settings.get("difficulty", 1)), 0, 2)]


func lamp_mult() -> float:
	return 1.0 + 0.12 * wicks


func see(kind: String) -> void:
	if not kind in seen:
		seen.append(kind)
		if hud:
			hud.toast(Loc.t("UI_BESTIARY") + ": " + Loc.t("BEST_" + kind))


func add_letter(id: String) -> void:
	if not id in letters:
		letters.append(id)
		inventory_changed.emit()
		if letters.size() >= 6:
			unlock("LETTERS")


# ------------------------------------------------------------------ tuş atama
const REBINDABLE := ["move_left", "move_right", "jump", "crouch", "run", "interact", "bell", "red_glass", "journal"]
var _default_keys: Dictionary = {}


func key_of(action: String) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev.physical_keycode
	return 0


func set_bind(action: String, keycode: int) -> void:
	var binds: Dictionary = settings.get("binds", {})
	binds[action] = keycode
	settings["binds"] = binds
	save_settings()
	apply_binds()


func reset_binds() -> void:
	settings["binds"] = {}
	save_settings()
	for a in _default_keys.keys():
		_replace_keys(a, _default_keys[a])


func apply_binds() -> void:
	if _default_keys.is_empty():
		for a in REBINDABLE:
			var ks: Array = []
			for ev in InputMap.action_get_events(a):
				if ev is InputEventKey:
					ks.append(ev.physical_keycode)
			_default_keys[a] = ks
	var binds: Dictionary = settings.get("binds", {})
	for a in binds.keys():
		if InputMap.has_action(a):
			_replace_keys(a, [int(binds[a])])


func _replace_keys(action: String, keys: Array) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = int(k)
		InputMap.action_add_event(action, e)


# ------------------------------------------------------------------ input
func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _joy_button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _setup_input() -> void:
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_key("crouch", [KEY_S, KEY_CTRL, KEY_DOWN])
	_key("run", [KEY_SHIFT])
	_key("interact", [KEY_E])
	_key("bell", [KEY_Q])
	_key("red_glass", [KEY_F])
	_key("journal", [KEY_TAB])
	_key("pause", [KEY_ESCAPE])
	_key("screenshot", [KEY_F12])
	_key("photo", [KEY_H])
	_key("throw", [KEY_T])
	_key("smoke_test", [KEY_F9])
	_joy_button("throw", JOY_BUTTON_RIGHT_SHOULDER)
	_mouse("lamp_raise", MOUSE_BUTTON_LEFT)
	_mouse("lamp_cycle", MOUSE_BUTTON_RIGHT)
	_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_joy_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_joy_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_joy_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_joy_axis("run", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy_axis("lamp_raise", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_joy_button("jump", JOY_BUTTON_A)
	_joy_button("crouch", JOY_BUTTON_B)
	_joy_button("interact", JOY_BUTTON_X)
	_joy_button("bell", JOY_BUTTON_Y)
	_joy_button("lamp_cycle", JOY_BUTTON_LEFT_SHOULDER)
	_joy_button("red_glass", JOY_BUTTON_DPAD_UP)
	_joy_button("journal", JOY_BUTTON_BACK)
	_joy_button("pause", JOY_BUTTON_START)


# ------------------------------------------------------------------ flags
func flag(name: String) -> bool:
	return bool(flags.get(name, false))


func set_flag(name: String, value: Variant = true) -> void:
	flags[name] = value


func get_flag_value(name: String, default: Variant = null) -> Variant:
	return flags.get(name, default)


# ------------------------------------------------------------------ inventory
func add_fuel(amount: float) -> void:
	fuel = clampf(fuel + amount, 0.0, MAX_FUEL)


func add_page(id: String) -> void:
	if id in pages:
		return
	pages.append(id)
	inventory_changed.emit()
	if pages.size() >= 12:
		unlock("POSTMAN")


func add_tape(id: String) -> void:
	if id in tapes:
		return
	tapes.append(id)
	inventory_changed.emit()
	if "Y01" in tapes and "Y02" in tapes and "Y03" in tapes:
		unlock("TAPES")


# ------------------------------------------------------------------ game flow
func new_game() -> void:
	flags = {}
	pages = []
	tapes = []
	letters = []
	seen = []
	wicks = 0
	playtime = 0.0
	gears = 0
	has_lamp = false
	has_radio = false
	has_bell = false
	has_red = false
	fuel = MAX_FUEL
	has_checkpoint = false
	chapter = 1


## Bölüm seçimiyle başlarken o bölüme kadar kazanılmış eşyaları ver.
func prepare_chapter_select(n: int) -> void:
	var keep_pages: Array = []
	var keep_tapes: Array = []
	if has_save():
		var d := _read_json(SAVE_PATH)
		keep_pages = d.get("pages", [])
		keep_tapes = d.get("tapes", [])
	var keep_letters: Array = []
	if has_save():
		keep_letters = _read_json(SAVE_PATH).get("letters", [])
	new_game()
	pages = keep_pages
	tapes = keep_tapes
	letters = keep_letters
	chapter = n
	if n >= 2:
		has_lamp = true
		has_radio = true
	if n >= 3:
		has_bell = true
		has_red = true
	if n == 4:
		has_lamp = true
		has_bell = true
		has_red = true


func begin_chapter(n: int, from_checkpoint: bool) -> void:
	chapter = n
	ran_dry_this_chapter = false
	stat_time = 0.0
	stat_caught = 0
	stat_braziers = 0
	if not from_checkpoint:
		has_checkpoint = false
		if n == 3:
			gears = 0


func set_checkpoint(pos: Vector2) -> void:
	checkpoint_pos = pos
	has_checkpoint = true
	get_tree().call_group("crate", "save_state")
	save_game()
	if hud:
		hud.saved_icon()


# ------------------------------------------------------------------ save
func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		return data
	if not path.ends_with(".bak") and FileAccess.file_exists(path + ".bak"):
		return _read_json(path + ".bak")
	return {}


## Olay günlüğü (user://log.txt): test ve hata ayıklama için.
func log_event(msg: String) -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line("[%s] %s" % [Time.get_datetime_string_from_system(), msg])


func _write_json(path: String, data: Dictionary) -> void:
	# önceki kaydı yedekle (bozulursa .bak'tan okunur)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var d := {
		"chapter": chapter,
		"flags": flags,
		"pages": pages,
		"tapes": tapes,
		"letters": letters,
		"seen": seen,
		"wicks": wicks,
		"playtime": playtime,
		"gears": gears,
		"has_lamp": has_lamp,
		"has_radio": has_radio,
		"has_bell": has_bell,
		"has_red": has_red,
		"fuel": fuel,
		"checkpoint": [checkpoint_pos.x, checkpoint_pos.y],
		"has_checkpoint": has_checkpoint,
	}
	_write_json(SAVE_PATH, d)


func load_game() -> bool:
	var d := _read_json(SAVE_PATH)
	if d.is_empty():
		return false
	chapter = int(d.get("chapter", 1))
	flags = d.get("flags", {})
	pages = d.get("pages", [])
	tapes = d.get("tapes", [])
	letters = d.get("letters", [])
	seen = d.get("seen", [])
	wicks = int(d.get("wicks", 0))
	playtime = float(d.get("playtime", 0.0))
	gears = int(d.get("gears", 0))
	has_lamp = bool(d.get("has_lamp", false))
	has_radio = bool(d.get("has_radio", false))
	has_bell = bool(d.get("has_bell", false))
	has_red = bool(d.get("has_red", false))
	fuel = float(d.get("fuel", MAX_FUEL))
	var cp: Array = d.get("checkpoint", [0, 0])
	checkpoint_pos = Vector2(float(cp[0]), float(cp[1]))
	has_checkpoint = bool(d.get("has_checkpoint", false))
	return true


# ------------------------------------------------------------------ settings
func load_settings() -> void:
	var d := _read_json(SETTINGS_PATH)
	for k in d.keys():
		settings[k] = d[k]
	apply_settings()


func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)


## Gamepad titreşimi (bağlı her pad için).
func rumble(weak: float, strong: float, dur: float) -> void:
	for id in Input.get_connected_joypads():
		Input.start_joy_vibration(id, weak, strong, dur)


func apply_settings() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(settings.get("vsync", true)) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(settings.get("max_fps", 0))
	var fs := bool(settings.get("fullscreen", false))
	if not fs and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		var sizes := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
		var ws: Vector2i = sizes[clampi(int(settings.get("window", 1)), 0, 2)]
		if DisplayServer.window_get_size() != ws:
			DisplayServer.window_set_size(ws)
			var sc := DisplayServer.screen_get_size()
			DisplayServer.window_set_position((sc - ws) / 2)
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want and not Engine.is_editor_hint():
		DisplayServer.window_set_mode(want)
	Loc.lang = str(settings["lang"])
	Loc.voice_lang = str(settings["voice_lang"])
	Loc.language_changed.emit()
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").apply_volumes()


# ------------------------------------------------------------------ achievements
func unlock(id: String) -> void:
	var list: Array = settings["achievements"]
	if id in list:
		return
	list.append(id)
	settings["achievements"] = list
	save_settings()
	SteamBridge.unlock(id)
	if hud:
		hud.toast(Loc.t("ACH_UNLOCKED") + ": " + Loc.t("ACH_" + id))
