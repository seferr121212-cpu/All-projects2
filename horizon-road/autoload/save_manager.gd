extends Node
## JSON save games + ConfigFile settings. Stage 1 covers the core state;
## album, NPCs and upgrades plug into `_collect()` / `_apply()` in later stages.

signal game_saved(slot: String)
signal game_loaded(slot: String)

const SAVE_DIR: String = "user://saves"
const SETTINGS_PATH: String = "user://settings.cfg"
const SAVE_VERSION: int = 1

var settings := ConfigFile.new()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	settings.load(SETTINGS_PATH)


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
	}


func _apply(data: Dictionary) -> void:
	GameState.from_dict(data.get("game", {}))
	TimeManager.from_dict(data.get("time", {}))
	WeatherManager.from_dict(data.get("weather", {}))


func _slot_path(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot.validate_filename()]
