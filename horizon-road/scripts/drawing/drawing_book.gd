class_name DrawingBook
extends RefCounted
## Sketchbook: drawing PNGs + thumbnails + index under user://drawings.
## Like the photo album it lives outside save slots, so artwork is never lost.

signal drawing_added(entry: Dictionary)

const DIR: String = "user://drawings"
const INDEX_PATH: String = "user://drawings/index.json"
const THUMB_SIZE := Vector2i(384, 216)

var entries: Array[Dictionary] = []
var _thumb_cache: Dictionary = {}


func load_index() -> void:
	entries.clear()
	if not FileAccess.file_exists(INDEX_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Sketchbook index unreadable; starting empty")
		return
	for e: Variant in data.get("entries", []):
		if typeof(e) == TYPE_DICTIONARY and FileAccess.file_exists(e.get("path", "")):
			entries.append(e)


func save_index() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(INDEX_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 1, "entries": entries}, "\t"))


func add_drawing(image: Image, info: Dictionary) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(DIR)
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var base: String = "%s/drawing_%s_%03d" % [DIR, stamp, entries.size()]
	image.save_png(base + ".png")
	var thumb: Image = image.duplicate()
	thumb.resize(THUMB_SIZE.x, THUMB_SIZE.y, Image.INTERPOLATE_BILINEAR)
	thumb.save_jpg(base + "_thumb.jpg", 0.9)
	var entry: Dictionary = info.duplicate(true)
	entry["kind"] = "drawing"
	entry["path"] = base + ".png"
	entry["thumb"] = base + "_thumb.jpg"
	entries.append(entry)
	save_index()
	drawing_added.emit(entry)
	return entry


func remove_drawing(entry: Dictionary) -> void:
	entries.erase(entry)
	for key: String in ["path", "thumb"]:
		if FileAccess.file_exists(entry.get(key, "")):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(entry[key]))
	save_index()


func get_thumbnail(entry: Dictionary) -> Texture2D:
	var path: String = entry.get("thumb", "")
	if not _thumb_cache.has(path):
		var img := Image.load_from_file(path)
		_thumb_cache[path] = ImageTexture.create_from_image(img) if img else null
	return _thumb_cache[path]


func load_full(entry: Dictionary) -> Texture2D:
	var img := Image.load_from_file(entry.get("path", ""))
	return ImageTexture.create_from_image(img) if img else null


## Sale value: effort (coverage, colours) plus a little for a real subject.
static func value_for(coverage: float, colors_used: int, has_subject: bool) -> int:
	return 6 + roundi(clampf(coverage, 0.0, 1.0) * 40.0) + mini(colors_used, 8) * 2 + (6 if has_subject else 0)
