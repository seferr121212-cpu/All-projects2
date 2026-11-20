extends Node
## Three save slots in a versioned JSON format, in-chapter autosave,
## per-chapter start snapshots (for "replay from chapter start") and
## player settings. No manual save: decisions cannot be undone.
## A separate profile file (independent of slots) remembers which endings
## have ever been reached, for the endings gallery.

signal saved(slot: int)
signal settings_changed

const FORMAT_VERSION := 1
const SLOT_COUNT := 3
const CHAPTER_INDEX_PATH := "res://data/chapters/index.json"
const SETTINGS_PATH := "user://settings.json"
const PROFILE_VERSION := 1

var save_dir := "user://saves/"
var profile_path := "user://profile.json"
## {"version", "endings": [ending ids in unlock order], "credits_seen": bool}
var profile: Dictionary = {}
var active_slot := -1
## chapter_id -> GameState dict captured when that chapter began.
var chapter_snapshots: Dictionary = {}

var settings: Dictionary = default_settings()
var chapter_order: Array = []
## Final scenes, one per ending (index.json "epilogues"); not part of chapter_order.
var epilogues: Array = []


static func default_settings() -> Dictionary:
	return {
		"locale": "tr",
		"choice_timer_scale": 1.0,
		"qte_easy": false,
		"qte_hold_alternative": false,
		"subtitle_scale": 1.0,
		"visual_quality": "high",
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 0.8,
	}


func _ready() -> void:
	chapter_order = _load_chapter_order()
	load_settings()
	load_profile()


func _load_chapter_order() -> Array:
	var f := FileAccess.open(CHAPTER_INDEX_PATH, FileAccess.READ)
	if f == null:
		push_error("SaveSystem: missing %s" % CHAPTER_INDEX_PATH)
		return []
	var data: Variant = JSON.parse_string(f.get_as_text())
	var out: Array = []
	epilogues.clear()
	if typeof(data) == TYPE_DICTIONARY:
		for c: Dictionary in data.get("chapters", []):
			out.append(c)
		for c: Dictionary in data.get("epilogues", []):
			epilogues.append(c)
	return out


func first_chapter_id() -> String:
	return str(chapter_order[0]["id"]) if not chapter_order.is_empty() else ""


func chapter_info(chapter_id: String) -> Dictionary:
	for c: Dictionary in chapter_order + epilogues:
		if c["id"] == chapter_id:
			return c
	return {}


func is_epilogue(chapter_id: String) -> bool:
	for c: Dictionary in epilogues:
		if c["id"] == chapter_id:
			return true
	return false


func is_last_story_chapter(chapter_id: String) -> bool:
	return not chapter_order.is_empty() and str(chapter_order[chapter_order.size() - 1]["id"]) == chapter_id


func _chapter_index(chapter_id: String) -> int:
	for i in chapter_order.size():
		if chapter_order[i]["id"] == chapter_id:
			return i
	return -1


# --- Settings -----------------------------------------------------------------

func load_settings() -> void:
	settings = default_settings()
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f != null:
		var data: Variant = JSON.parse_string(f.get_as_text())
		if typeof(data) == TYPE_DICTIONARY:
			for key: String in data:
				if settings.has(key):
					settings[key] = data[key]
	_apply_settings()


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_apply_settings()
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(settings, "\t"))
	settings_changed.emit()


func _apply_settings() -> void:
	Localization.set_locale(str(settings["locale"]))
	AudioBus.apply_volumes(settings)


# --- Profile (endings gallery) ---------------------------------------------------

func load_profile() -> void:
	profile = {"version": PROFILE_VERSION, "endings": [], "credits_seen": false}
	var f := FileAccess.open(profile_path, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	for id: Variant in data.get("endings", []):
		if typeof(id) == TYPE_STRING and not profile["endings"].has(id):
			profile["endings"].append(id)
	profile["credits_seen"] = bool(data.get("credits_seen", false))


func _write_profile() -> bool:
	var tmp := profile_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(profile, "\t"))
	f.close()
	if FileAccess.file_exists(profile_path):
		DirAccess.remove_absolute(profile_path)
	return DirAccess.rename_absolute(tmp, profile_path) == OK


## Returns true if this ending was not unlocked before.
func unlock_ending(ending_id: String) -> bool:
	if ending_id == "" or profile["endings"].has(ending_id):
		return false
	profile["endings"].append(ending_id)
	_write_profile()
	return true


func is_ending_unlocked(ending_id: String) -> bool:
	return profile.get("endings", []).has(ending_id)


func unlocked_endings() -> Array:
	return profile.get("endings", []).duplicate()


func mark_credits_seen() -> void:
	if not profile.get("credits_seen", false):
		profile["credits_seen"] = true
		_write_profile()


# --- Slots ----------------------------------------------------------------------

func slot_path(slot: int) -> String:
	return save_dir + "slot_%d.json" % slot


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func any_save() -> bool:
	for i in SLOT_COUNT:
		if has_save(i):
			return true
	return false


## Most recently written slot, or -1.
func latest_slot() -> int:
	var best := -1
	var best_time := -1
	for i in SLOT_COUNT:
		if has_save(i):
			var t := FileAccess.get_modified_time(slot_path(i))
			if t > best_time:
				best_time = t
				best = i
	return best


## Lightweight metadata for the slot menu, {} if empty or unreadable.
func read_meta(slot: int) -> Dictionary:
	var data := _read(slot)
	if data.is_empty():
		return {}
	return {
		"chapter": data["state"].get("current_chapter", ""),
		"saved_at": data.get("saved_at", ""),
		"play_time_sec": data["state"].get("play_time_sec", 0.0),
		"chapters": data.get("chapter_snapshots", {}).keys(),
	}


func new_game(slot: int) -> void:
	GameState.reset()
	active_slot = slot
	chapter_snapshots.clear()
	begin_chapter(first_chapter_id())


## Snapshot the state at a chapter boundary, then autosave.
func begin_chapter(chapter_id: String) -> void:
	GameState.current_chapter = chapter_id
	GameState.current_node = ""
	# An epilogue sits after every story chapter: it keeps all story snapshots.
	var idx := chapter_order.size() if is_epilogue(chapter_id) else _chapter_index(chapter_id)
	for key: String in chapter_snapshots.keys():
		var k := _chapter_index(key)
		if k == -1:
			k = chapter_order.size()  # earlier epilogue snapshot: always later than any story chapter
		if k >= idx:
			chapter_snapshots.erase(key)
	chapter_snapshots[chapter_id] = GameState.to_dict()
	autosave()


func autosave() -> bool:
	if active_slot < 0:
		return false
	var data := {
		"format_version": FORMAT_VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "0")),
		"saved_at": Time.get_datetime_string_from_system(true),
		"state": GameState.to_dict(),
		"chapter_snapshots": chapter_snapshots.duplicate(true),
	}
	var ok := _write(active_slot, data)
	if ok:
		saved.emit(active_slot)
	return ok


func load_slot(slot: int) -> bool:
	var data := _read(slot)
	if data.is_empty():
		return false
	active_slot = slot
	chapter_snapshots = data.get("chapter_snapshots", {})
	GameState.from_dict(data["state"])
	return true


## Replay from the start of a chapter. Later chapter snapshots are discarded,
## because the story will be re-decided from here.
func restart_chapter(slot: int, chapter_id: String) -> bool:
	if not load_slot(slot) or not chapter_snapshots.has(chapter_id):
		return false
	GameState.from_dict(chapter_snapshots[chapter_id])
	begin_chapter(chapter_id)
	return true


func delete_slot(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))
	if slot == active_slot:
		active_slot = -1


func _write(slot: int, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: cannot write %s" % tmp)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


func _read(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("state"):
		push_error("SaveSystem: corrupt save in slot %d" % slot)
		return {}
	return migrate(data)


## Upgrade older save formats step by step. Newer-than-known saves are refused.
func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("format_version", 0))
	if version > FORMAT_VERSION:
		push_error("SaveSystem: save format %d is newer than supported %d" % [version, FORMAT_VERSION])
		return {}
	if version < 1:
		# v0 (pre-release) had no snapshots.
		data["chapter_snapshots"] = data.get("chapter_snapshots", {})
		version = 1
	data["format_version"] = version
	return data
