class_name PhotoAlbum
extends RefCounted
## The travel album: photo files + index (album.json) under user://photos.
## Kept outside save slots on purpose, like a real camera roll: photos are
## never lost by loading an older save.

signal photo_added(entry: Dictionary)
signal subject_discovered(subject_id: StringName)

const DIR: String = "user://photos"
const INDEX_PATH: String = "user://photos/album.json"
const THUMB_SIZE := Vector2i(384, 216)

var entries: Array[Dictionary] = []
## subject or moment id -> {name_key, category, first_photo}
var discovered: Dictionary = {}
var _thumb_cache: Dictionary = {}


func load_index() -> void:
	entries.clear()
	discovered.clear()
	if not FileAccess.file_exists(INDEX_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Album index unreadable; starting empty")
		return
	for e: Variant in data.get("entries", []):
		if typeof(e) == TYPE_DICTIONARY and FileAccess.file_exists(e.get("path", "")):
			entries.append(e)
	discovered = data.get("discovered", {})


func save_index() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(INDEX_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write album index: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({"version": 1, "entries": entries, "discovered": discovered}, "\t"))


## Stores the image + thumbnail and records metadata. Returns the entry,
## including "new_subjects" (ids seen for the first time).
func add_photo(image: Image, info: Dictionary) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(DIR)
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var base: String = "%s/photo_%s_%03d" % [DIR, stamp, entries.size()]
	var path: String = base + ".png"
	var thumb_path: String = base + "_thumb.jpg"
	image.save_png(path)
	var thumb: Image = image.duplicate()
	thumb.resize(THUMB_SIZE.x, THUMB_SIZE.y, Image.INTERPOLATE_BILINEAR)
	thumb.save_jpg(thumb_path, 0.85)

	var entry: Dictionary = info.duplicate(true)
	entry["path"] = path
	entry["thumb"] = thumb_path
	var new_subjects: Array = []
	for item: Dictionary in entry.get("subject_list", []):
		if not discovered.has(item.id):
			discovered[item.id] = {"name_key": item.name_key, "category": item.category, "first_photo": path}
			new_subjects.append(item.id)
	entry["new_subjects"] = new_subjects
	entries.append(entry)
	save_index()
	photo_added.emit(entry)
	for id: Variant in new_subjects:
		subject_discovered.emit(StringName(id))
	return entry


func remove_photo(entry: Dictionary) -> void:
	entries.erase(entry)
	for key: String in ["path", "thumb"]:
		if FileAccess.file_exists(entry.get(key, "")):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(entry[key]))
	save_index()


func is_discovered(id: StringName) -> bool:
	return discovered.has(String(id)) or discovered.has(id)


func get_thumbnail(entry: Dictionary) -> Texture2D:
	var path: String = entry.get("thumb", "")
	if _thumb_cache.has(path):
		return _thumb_cache[path]
	var img := Image.load_from_file(path)
	if img == null:
		return null
	var tex := ImageTexture.create_from_image(img)
	_thumb_cache[path] = tex
	return tex


func load_full(entry: Dictionary) -> Texture2D:
	var img := Image.load_from_file(entry.get("path", ""))
	return ImageTexture.create_from_image(img) if img else null
