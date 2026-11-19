extends Node
## JSON save games + ConfigFile settings. Stage 1 covers the core state;
## album, NPCs and upgrades plug into `_collect()` / `_apply()` in later stages.

signal game_saved(slot: String)
signal game_loaded(slot: String)

const SAVE_DIR: String = "user://saves"
const SETTINGS_PATH: String = "user://settings.cfg"
const SAVE_VERSION: int = 2
const AUTOSAVE_SLOT: String = "autosave"
const QUICK_SLOT: String = "quick"
const MANUAL_SLOT: String = "manual"

var settings := ConfigFile.new()
var _autosave_timer: float = 0.0
## True while a save is being applied (systems can skip intro toasts etc.).
var is_loading: bool = false
## Save data waiting for its region scene to finish loading.
var _pending: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	settings.load(SETTINGS_PATH)


func _process(delta: float) -> void:
	if GameState.current_region == null or not GameState.is_gameplay() or DevCli.is_requested():
		return
	_autosave_timer += delta
	if _autosave_timer >= GameState.ECONOMY.autosave_interval:
		autosave()


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_gameplay():
		return
	if event.is_action_pressed(&"quicksave"):
		if save_game(QUICK_SLOT):
			GameState.notify(tr(&"UI_SAVED"))
	elif event.is_action_pressed(&"quickload"):
		if load_game(QUICK_SLOT):
			GameState.notify(tr(&"UI_LOADED"))


func _notification(what: int) -> void:
	# Leaving the game never loses progress.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and GameState.current_region and not DevCli.is_requested():
		autosave()


## Most recently written of the player's slots, or "" when there is none.
func latest_slot() -> String:
	var best: String = ""
	var best_time: int = -1
	for slot: String in [AUTOSAVE_SLOT, QUICK_SLOT, MANUAL_SLOT]:
		if has_save(slot):
			var t: int = FileAccess.get_modified_time(_slot_path(slot))
			if t > best_time:
				best_time = t
				best = slot
	return best


func load_latest() -> bool:
	var slot: String = latest_slot()
	return slot != "" and load_game(slot)


func delete_all_saves() -> void:
	for slot: String in [AUTOSAVE_SLOT, QUICK_SLOT, MANUAL_SLOT]:
		if has_save(slot):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path(slot)))


func autosave() -> void:
	_autosave_timer = 0.0
	save_game(AUTOSAVE_SLOT)


## Called by the region when it is ready: resume the last session if any.
func has_pending() -> bool:
	return not _pending.is_empty()


## Applies a save waiting for this region; DevCli runs may resume with --continue.
func continue_if_possible() -> bool:
	if not _pending.is_empty():
		var data: Dictionary = _pending
		_pending = {}
		_apply(data)
		game_loaded.emit("pending")
		return true
	if DevCli.is_requested() and OS.get_cmdline_user_args().has("--continue"):
		return load_game(AUTOSAVE_SLOT)
	return false


func save_game(slot: String = "manual") -> bool:
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(_collect(), "\t"))
	game_saved.emit(slot)
	return true


func load_game(slot: String = "manual") -> bool:
	if not has_save(slot):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(slot)))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Save file '%s' is corrupt" % slot)
		return false
	# A save from another region: switch scenes first, apply once it's ready.
	var region_id := StringName(data.get("game", {}).get("region", ""))
	if region_id != &"" and region_id != GameState.current_region_id and GameState.REGIONS.has(region_id):
		_pending = data
		GameState.journey_started = true
		GameState.current_region = null
		get_tree().change_scene_to_file(GameState.get_region_def(region_id).scene_path)
		return true
	_apply(data)
	game_loaded.emit(slot)
	return true


func has_save(slot: String = "manual") -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func get_setting(section: String, key: String, default: Variant) -> Variant:
	return settings.get_value(section, key, default)


func set_setting(section: String, key: String, value: Variant) -> void:
	settings.set_value(section, key, value)
	settings.save(SETTINGS_PATH)


func _collect() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"game": GameState.to_dict(),
		"time": TimeManager.to_dict(),
		"weather": WeatherManager.to_dict(),
		"world": _collect_participants(),
	}


func _apply(data: Dictionary) -> void:
	is_loading = true
	_apply_sections(data)
	is_loading = false


func _apply_sections(data: Dictionary) -> void:
	GameState.from_dict(data.get("game", {}))
	TimeManager.from_dict(data.get("time", {}))
	WeatherManager.from_dict(data.get("weather", {}))
	var world: Dictionary = data.get("world", {})
	for node: Node in get_tree().get_nodes_in_group(&"save_participant"):
		var key: String = node.call(&"save_key")
		if world.has(key):
			node.call(&"from_save", world[key])


## Scene objects that persist themselves (camper position, active jobs...).
func _collect_participants() -> Dictionary:
	var out: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"save_participant"):
		out[node.call(&"save_key")] = node.call(&"to_save")
	return out


func _slot_path(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot.validate_filename()]
