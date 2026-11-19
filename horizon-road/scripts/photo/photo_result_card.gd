class_name PhotoResultCard
extends PanelContainer
## Small "polaroid" that slides in after a shot: thumbnail, stars, what was
## captured and a friendly note. Fades out by itself.

var _thumb := TextureRect.new()
var _stars := Label.new()
var _lines := Label.new()
var _timer: float = 0.0


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.95, 0.9, 0.96)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	add_theme_stylebox_override(&"panel", style)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 60)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	add_child(box)
	_thumb.custom_minimum_size = Vector2(288, 162)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	box.add_child(_thumb)
	_stars.add_theme_font_size_override(&"font_size", 26)
	_stars.add_theme_color_override(&"font_color", Color(0.85, 0.6, 0.15))
	box.add_child(_stars)
	_lines.add_theme_color_override(&"font_color", Color(0.25, 0.2, 0.15))
	_lines.custom_minimum_size = Vector2(288, 0)
	_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_lines)
	visible = false


func show_result(entry: Dictionary, thumb: Texture2D) -> void:
	_thumb.texture = thumb
	var stars: int = entry.get("stars", 1)
	_stars.text = "★".repeat(stars) + "☆".repeat(3 - stars) + "   %d" % entry.get("score", 0)
	var lines: PackedStringArray = []
	var names: PackedStringArray = []
	for item: Dictionary in entry.get("subject_list", []):
		names.append(tr(StringName(item.name_key)))
	lines.append(", ".join(names) if not names.is_empty() else tr(&"PHOTO_NOTHING"))
	for id: Variant in entry.get("new_subjects", []):
		var key: String = GameState.album.discovered.get(id, {}).get("name_key", String(id))
		lines.append(tr(&"PHOTO_NEW_SUBJECT") % tr(StringName(key)))
	for fb: Variant in entry.get("feedback", []):
		lines.append(tr(StringName(fb)))
	lines.append(tr(&"PHOTO_SAVED"))
	_lines.text = "\n".join(lines)
	modulate.a = 1.0
	visible = true
	_timer = 4.5


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	modulate.a = clampf(_timer / 0.6, 0.0, 1.0)
	if _timer <= 0.0:
		visible = false
