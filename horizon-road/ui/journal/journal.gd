class_name Journal
extends CanvasLayer
## Travel journal (J): album of photos, collection of discovered subjects,
## and (from stage 3) the people met along the way. Styled like a paper
## notebook; the world pauses while it is open.

const PAPER := Color(0.95, 0.92, 0.85)
const INK := Color(0.24, 0.19, 0.14)
const INK_SOFT := Color(0.45, 0.38, 0.3)
const ACCENT := Color(0.78, 0.45, 0.2)
const MOMENT_IDS: Array[StringName] = PhotoScorer.MOMENT_IDS

var _tabs := TabContainer.new()
var _album_grid := GridContainer.new()
var _album_empty := Label.new()
var _collection_box := VBoxContainer.new()
var _detail := PanelContainer.new()
var _detail_image := TextureRect.new()
var _detail_text := Label.new()
var _detail_entry: Dictionary = {}
var _people_box := VBoxContainer.new()
var _drawing_grid := GridContainer.new()
var _drawing_empty := Label.new()


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	GameState.album.photo_added.connect(func(_e: Dictionary) -> void:
		if visible:
			_refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"journal"):
		if visible:
			close()
		elif GameState.is_gameplay():
			open()
		else:
			return
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"pause"):
		if _detail.visible:
			_detail.visible = false
		else:
			close()
		get_viewport().set_input_as_handled()


func open() -> void:
	GameState.set_context(GameState.Context.JOURNAL)
	_refresh()
	_detail.visible = false
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	get_tree().paused = false
	GameState.set_context(GameState.Context.GAMEPLAY)
	if not DevCli.is_requested():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Static labels hold translation keys and auto-translate; only dynamic text uses tr().
func _refresh() -> void:
	_tabs.set_tab_title(0, tr(&"JOURNAL_ALBUM"))
	_tabs.set_tab_title(1, tr(&"JOURNAL_COLLECTION"))
	_tabs.set_tab_title(2, tr(&"JOURNAL_DRAWINGS"))
	_tabs.set_tab_title(3, tr(&"JOURNAL_PEOPLE"))
	_fill_album()
	_fill_collection()
	_fill_people()
	_fill_drawings()


# --- Album -----------------------------------------------------------------

func _fill_album() -> void:
	for child: Node in _album_grid.get_children():
		child.queue_free()
	var entries: Array[Dictionary] = GameState.album.entries
	_album_empty.visible = entries.is_empty()
	# Newest first, like flipping back from the latest page.
	for i: int in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i]
		var card := VBoxContainer.new()
		var button := TextureButton.new()
		button.texture_normal = GameState.album.get_thumbnail(entry)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		button.custom_minimum_size = Vector2(256, 144)
		button.pressed.connect(_show_detail.bind(entry))
		card.add_child(button)
		var caption := _label("%s   %s" % [_stars(entry), _when(entry)], 15, INK_SOFT)
		card.add_child(caption)
		_album_grid.add_child(card)


func _fill_drawings() -> void:
	for child: Node in _drawing_grid.get_children():
		child.queue_free()
	var entries: Array[Dictionary] = GameState.drawings.entries
	_drawing_empty.visible = entries.is_empty()
	for i: int in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i]
		var card := VBoxContainer.new()
		var button := TextureButton.new()
		button.texture_normal = GameState.drawings.get_thumbnail(entry)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		button.custom_minimum_size = Vector2(256, 144)
		button.pressed.connect(_show_detail.bind(entry))
		card.add_child(button)
		card.add_child(_label("✎   %s" % _when(entry), 15, INK_SOFT))
		_drawing_grid.add_child(card)


func _show_detail(entry: Dictionary) -> void:
	_detail_entry = entry
	var is_drawing: bool = entry.get("kind", "") == "drawing"
	_detail_image.texture = GameState.drawings.load_full(entry) if is_drawing else GameState.album.load_full(entry)
	var names: PackedStringArray = []
	var moments: PackedStringArray = []
	for item: Dictionary in entry.get("subject_list", []):
		if int(item.category) == PhotoSubject.Category.MOMENT:
			moments.append(tr(StringName(item.name_key)))
		else:
			names.append(tr(StringName(item.name_key)))
	var lines: PackedStringArray = [
		"%s   ·   %s   ·   %s" % [_when(entry), tr(&"REGION_BLACKSEA_HIGHLAND") if entry.get("region", "") == "blacksea_highland" else entry.get("region", ""),
			tr(StringName(WeatherManager.profiles.get(StringName(entry.get("weather", "clear")), WeatherManager.profiles[&"clear"]).name_key))],
		("%s: %d" % [tr(&"JOURNAL_STROKES"), int(entry.get("strokes", 0))]) if is_drawing else ("%s: %s  %d" % [tr(&"JOURNAL_SCORE"), _stars(entry), int(entry.get("score", 0))]),
		"%s: %s" % [tr(&"JOURNAL_SUBJECTS"), ", ".join(names) if not names.is_empty() else "—"],
	]
	if not moments.is_empty():
		lines.append("%s: %s" % [tr(&"JOURNAL_MOMENTS"), ", ".join(moments)])
	lines.append("%s: %d ₺" % [tr(&"JOURNAL_VALUE"), int(entry.get("value", 0))])
	for fb: Variant in entry.get("feedback", []):
		lines.append("· " + tr(StringName(fb)))
	_detail_text.text = "\n".join(lines)
	_detail.visible = true


# --- Collection ------------------------------------------------------------

func _fill_collection() -> void:
	for child: Node in _collection_box.get_children():
		child.queue_free()
	# Known = everything photographable in loaded regions + all moments.
	var known: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"photo_subject"):
		var s := node as PhotoSubject
		known[String(s.subject_id)] = {"name_key": s.name_key, "category": s.category}
	for m: StringName in MOMENT_IDS:
		known[String(m)] = {"name_key": String(m), "category": PhotoSubject.Category.MOMENT}
	for id: String in GameState.album.discovered:
		if not known.has(id):
			known[id] = GameState.album.discovered[id]
	for cat: int in PhotoSubject.Category.size():
		var ids: Array = known.keys().filter(func(k: String) -> bool: return int(known[k].category) == cat)
		if ids.is_empty():
			continue
		ids.sort()
		var found: int = ids.filter(func(k: String) -> bool: return GameState.album.is_discovered(StringName(k))).size()
		var header := _label("%s   —   %s" % [tr(StringName(PhotoSubject.CATEGORY_KEYS[cat])), tr(&"JOURNAL_DISCOVERED") % [found, ids.size()]], 20, INK)
		_collection_box.add_child(header)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override(&"h_separation", 18)
		for id: String in ids:
			var discovered: bool = GameState.album.is_discovered(StringName(id))
			var text: String = ("✓ " + tr(StringName(known[id].name_key))) if discovered else ("○ " + tr(&"JOURNAL_UNKNOWN"))
			flow.add_child(_label(text, 16, INK if discovered else INK_SOFT))
		_collection_box.add_child(flow)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		_collection_box.add_child(spacer)


# --- People ----------------------------------------------------------------

func _fill_people() -> void:
	for child: Node in _people_box.get_children():
		child.queue_free()
	if GameState.people.is_empty():
		_people_box.add_child(_label("JOURNAL_EMPTY_PEOPLE", 18, INK_SOFT))
		return
	var levels: int = GameState.ECONOMY.level_thresholds.size()
	for id: String in GameState.people:
		var info: Dictionary = GameState.people[id]
		var level: int = GameState.get_relationship_level(StringName(id))
		var row := VBoxContainer.new()
		row.add_child(_label("%s   —   %s" % [tr(StringName(info.get("name_key", id))), tr(StringName(info.get("role_key", "")))], 21, INK))
		var hearts: String = "♥".repeat(level + 1) + "♡".repeat(levels - level - 1)
		row.add_child(_label("%s  %s   (%d)" % [hearts, tr(StringName(GameState.ECONOMY.level_keys[level])), GameState.get_relationship(StringName(id))], 17, ACCENT))
		var note := _label(tr(StringName(info.get("note_key", ""))), 16, INK_SOFT)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(note)
		_people_box.add_child(row)


# --- Layout ----------------------------------------------------------------

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.03, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var book := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(10)
	style.set_content_margin_all(28)
	style.border_color = Color(0.55, 0.38, 0.22)
	style.set_border_width_all(6)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 16
	book.add_theme_stylebox_override(&"panel", style)
	book.set_anchors_preset(Control.PRESET_FULL_RECT)
	book.offset_left = 120
	book.offset_right = -120
	book.offset_top = 70
	book.offset_bottom = -70
	add_child(book)

	var column := VBoxContainer.new()
	book.add_child(column)
	var header := HBoxContainer.new()
	var title := _label("", 30, INK)
	title.text = "JOURNAL_TITLE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "JOURNAL_CLOSE"
	close_button.flat = true
	close_button.add_theme_color_override(&"font_color", INK_SOFT)
	close_button.pressed.connect(close)
	_style_button(close_button)
	header.add_child(close_button)
	column.add_child(header)

	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_color_override(&"font_selected_color", ACCENT)
	_tabs.add_theme_color_override(&"font_unselected_color", INK_SOFT)
	var clear_panel := StyleBoxEmpty.new()
	_tabs.add_theme_stylebox_override(&"panel", clear_panel)
	_tabs.add_theme_stylebox_override(&"tab_selected", _tab_style(Color(0.99, 0.97, 0.92), ACCENT))
	_tabs.add_theme_stylebox_override(&"tab_unselected", _tab_style(Color(0.88, 0.83, 0.73), Color(0, 0, 0, 0)))
	_tabs.add_theme_stylebox_override(&"tab_hovered", _tab_style(Color(0.93, 0.89, 0.8), Color(0, 0, 0, 0)))
	_tabs.add_theme_color_override(&"font_hovered_color", INK)
	_tabs.add_theme_font_size_override(&"font_size", 18)
	column.add_child(_tabs)

	var album_scroll := ScrollContainer.new()
	album_scroll.name = "Album"
	var album_column := VBoxContainer.new()
	album_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_album_empty.text = "JOURNAL_EMPTY_ALBUM"
	_album_empty.add_theme_color_override(&"font_color", INK_SOFT)
	album_column.add_child(_album_empty)
	_album_grid.columns = 4
	_album_grid.add_theme_constant_override(&"h_separation", 18)
	_album_grid.add_theme_constant_override(&"v_separation", 14)
	album_column.add_child(_album_grid)
	album_scroll.add_child(album_column)
	_tabs.add_child(album_scroll)

	var collection_scroll := ScrollContainer.new()
	collection_scroll.name = "Collection"
	_collection_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_scroll.add_child(_collection_box)
	_tabs.add_child(collection_scroll)

	var drawing_scroll := ScrollContainer.new()
	drawing_scroll.name = "Drawings"
	var drawing_col := VBoxContainer.new()
	drawing_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawing_empty.text = "JOURNAL_EMPTY_DRAWINGS"
	_drawing_empty.add_theme_color_override(&"font_color", INK_SOFT)
	drawing_col.add_child(_drawing_empty)
	_drawing_grid.columns = 4
	_drawing_grid.add_theme_constant_override(&"h_separation", 18)
	_drawing_grid.add_theme_constant_override(&"v_separation", 14)
	drawing_col.add_child(_drawing_grid)
	drawing_scroll.add_child(drawing_col)
	_tabs.add_child(drawing_scroll)

	var people_scroll := ScrollContainer.new()
	people_scroll.name = "People"
	_people_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_people_box.add_theme_constant_override(&"separation", 16)
	people_scroll.add_child(_people_box)
	_tabs.add_child(people_scroll)

	# Detail view overlays the book.
	var dstyle := style.duplicate() as StyleBoxFlat
	dstyle.set_content_margin_all(20)
	_detail.add_theme_stylebox_override(&"panel", dstyle)
	_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail.offset_left = 160
	_detail.offset_right = -160
	_detail.offset_top = 100
	_detail.offset_bottom = -100
	var dcol := VBoxContainer.new()
	_detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dcol.add_child(_detail_image)
	_detail_text.add_theme_color_override(&"font_color", INK)
	_detail_text.add_theme_font_size_override(&"font_size", 17)
	dcol.add_child(_detail_text)
	var back := Button.new()
	back.text = "JOURNAL_BACK"
	_style_button(back)
	back.pressed.connect(func() -> void: _detail.visible = false)
	dcol.add_child(back)
	_detail.add_child(dcol)
	_detail.visible = false
	add_child(_detail)


func _tab_style(bg: Color, underline: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.corner_radius_top_left = 6
	st.corner_radius_top_right = 6
	st.set_content_margin_all(10)
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.border_color = underline
	st.border_width_bottom = 3
	return st


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.88, 0.83, 0.73)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.93, 0.86, 0.72)
	button.add_theme_stylebox_override(&"normal", normal)
	button.add_theme_stylebox_override(&"hover", hover)
	button.add_theme_stylebox_override(&"pressed", hover)
	button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	button.add_theme_color_override(&"font_color", INK)
	button.add_theme_color_override(&"font_hover_color", ACCENT)
	button.flat = false


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	return l


func _stars(entry: Dictionary) -> String:
	var n: int = int(entry.get("stars", 1))
	return "★".repeat(n) + "☆".repeat(3 - n)


func _when(entry: Dictionary) -> String:
	var hour: float = float(entry.get("hour", 0.0))
	return "%s · %02d:%02d" % [tr(&"UI_DAY") % int(entry.get("day", 1)), int(hour), int(fposmod(hour, 1.0) * 60.0)]
