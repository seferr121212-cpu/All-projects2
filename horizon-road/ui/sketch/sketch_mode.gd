class_name SketchMode
extends CanvasLayer
## Sketch mode (B): freezes the current view as a reference, opens an easel
## with a paper canvas, palette and brushes. No scoring -- the drawing is
## valued by effort and saved to the sketchbook (journal "Drawings" tab).

signal drawing_saved(entry: Dictionary)

const WOOD := Color(0.42, 0.29, 0.18)
const WOOD_DARK := Color(0.3, 0.2, 0.12)
const PAPER_UI := Color(0.95, 0.91, 0.82)
const INK := Color(0.24, 0.19, 0.14)
const BASE_PALETTE: Array[Color] = [
	Color(0.15, 0.15, 0.18), Color(0.98, 0.98, 0.96), Color(0.55, 0.75, 0.92), Color(0.2, 0.35, 0.65),
	Color(0.45, 0.7, 0.3), Color(0.16, 0.36, 0.18), Color(0.3, 0.55, 0.2), Color(0.85, 0.7, 0.3),
	Color(0.95, 0.55, 0.2), Color(0.8, 0.22, 0.18), Color(0.45, 0.3, 0.18), Color(0.55, 0.55, 0.55),
]
const KIT_PALETTE: Array[Color] = [
	Color(0.95, 0.6, 0.7), Color(0.55, 0.35, 0.7), Color(0.15, 0.5, 0.5), Color(0.3, 0.75, 0.75),
	Color(0.98, 0.8, 0.65), Color(0.75, 0.65, 0.88), Color(0.5, 0.5, 0.2), Color(0.9, 0.82, 0.6),
	Color(0.95, 0.78, 0.2), Color(0.5, 0.12, 0.15), Color(0.1, 0.15, 0.35), Color(0.7, 0.92, 0.75),
]
const SIZES: Array[float] = [3.0, 7.0, 15.0, 28.0]
const REFERENCE_LEVELS: Array[float] = [0.0, 0.25, 0.55]
const MINUTES_PER_SKETCH: float = 30.0

@export var travel_path: NodePath

var canvas := PaintCanvas.new()
var reference_index: int = 1
var _travel: TravelController
var _reference_tex: ImageTexture
var _subjects: Array = []
var _palette_grid := GridContainer.new()
var _tool_buttons: Dictionary = {}
var _size_buttons: Array[Button] = []
var _swatches: Array[Button] = []
var _ref_button := Button.new()
var _ref_thumb := TextureRect.new()
var _status := Label.new()
var _tool: String = "pencil"


func _ready() -> void:
	layer = 17
	process_mode = Node.PROCESS_MODE_ALWAYS
	_travel = get_node_or_null(travel_path)
	_build()
	visible = false
	GameState.upgrades_changed.connect(_rebuild_palette)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed(&"sketch_mode") and GameState.is_gameplay() and _can_start():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).ctrl_pressed and (event as InputEventKey).keycode == KEY_Z:
		canvas.undo()
		get_viewport().set_input_as_handled()


func _can_start() -> bool:
	if _travel == null:
		return true
	return GameState.player_mode != GameState.PlayerMode.DRIVING or _travel.camper.is_stopped()


func open() -> void:
	GameState.set_context(GameState.Context.SKETCH)
	if _travel:
		_travel.suspend_control()
	# Let the HUD hide before grabbing the reference frame.
	await get_tree().process_frame
	var cam: Camera3D = get_viewport().get_camera_3d()
	_subjects = []
	if cam:
		var eval: Dictionary = PhotoScorer.evaluate(cam, 50.0, 0.0, PhotoConfig.new())
		var seen: Dictionary = {}
		for s: Dictionary in eval.subjects:
			if not seen.has(s.id):
				seen[s.id] = true
				_subjects.append({"id": String(s.id), "name_key": s.name_key, "category": s.category})
		for m: StringName in eval.moments:
			_subjects.append({"id": String(m), "name_key": String(m), "category": PhotoSubject.Category.MOMENT})
	var ref: Image = await _capture()
	_reference_tex = ImageTexture.create_from_image(ref)
	_ref_thumb.texture = _reference_tex
	canvas.clear()
	canvas._undo.clear()
	_apply_reference()
	_rebuild_palette()
	_select_tool("pencil")
	_select_size(1)
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	get_tree().paused = false
	GameState.set_context(GameState.Context.GAMEPLAY)
	if _travel:
		_travel.restore_control()
	if not DevCli.is_requested():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func save_drawing() -> Dictionary:
	var image: Image = canvas.compose()
	var cov: float = canvas.coverage()
	var info: Dictionary = {
		"day": TimeManager.day,
		"hour": TimeManager.time_of_day,
		"region": String(GameState.current_region_id),
		"weather": String(WeatherManager.target_id),
		"subject_list": _subjects,
		"strokes": canvas.strokes,
		"colors": canvas.colors_used.size(),
		"coverage": cov,
		"value": DrawingBook.value_for(cov, canvas.colors_used.size(), not _subjects.is_empty()),
	}
	var entry: Dictionary = GameState.drawings.add_drawing(image, info)
	TimeManager.advance_hours(MINUTES_PER_SKETCH / 60.0)
	GameState.notify(tr(&"SKETCH_SAVED"))
	drawing_saved.emit(entry)
	close()
	return entry


func _capture() -> Image:
	if DisplayServer.get_name() == "headless":
		var blank := Image.create(640, 360, false, Image.FORMAT_RGB8)
		blank.fill(Color(0.5, 0.6, 0.5))
		return blank
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _apply_reference() -> void:
	canvas.set_reference(_reference_tex, REFERENCE_LEVELS[reference_index])
	_ref_button.text = tr(&"SKETCH_REFERENCE") + ": " + tr(StringName(["SKETCH_REF_OFF", "SKETCH_REF_FAINT", "SKETCH_REF_STRONG"][reference_index]))


# --- Tools -------------------------------------------------------------------

func _select_tool(tool: String) -> void:
	_tool = tool
	canvas.erasing = tool == "eraser"
	match tool:
		"pencil":
			canvas.brush_opacity = 1.0
			canvas.brush_softness = 0.15
		"soft":
			canvas.brush_opacity = 0.6
			canvas.brush_softness = 0.8
		"watercolor":
			canvas.brush_opacity = 0.22
			canvas.brush_softness = 0.9
	for key: String in _tool_buttons:
		(_tool_buttons[key] as Button).button_pressed = key == tool


func _select_size(index: int) -> void:
	canvas.brush_radius = SIZES[index] * (1.6 if _tool == "watercolor" else 1.0)
	for i: int in _size_buttons.size():
		_size_buttons[i].button_pressed = i == index


func _select_color(c: Color, swatch: Button) -> void:
	canvas.brush_color = c
	if _tool == "eraser":
		_select_tool("pencil")
	for s: Button in _swatches:
		s.button_pressed = s == swatch


func _rebuild_palette() -> void:
	for c: Node in _palette_grid.get_children():
		_palette_grid.remove_child(c)
		c.queue_free()
	_swatches.clear()
	var colors: Array[Color] = BASE_PALETTE.duplicate()
	var kit: int = GameState.get_upgrade_level("art_kit")
	if kit >= 1:
		colors.append_array(KIT_PALETTE)
	for c: Color in colors:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(40, 40)
		var st := StyleBoxFlat.new()
		st.bg_color = c
		st.set_corner_radius_all(20)
		st.border_color = Color(0.15, 0.1, 0.06)
		st.set_border_width_all(2)
		var sel := st.duplicate() as StyleBoxFlat
		sel.border_color = Color(1, 0.95, 0.8)
		sel.set_border_width_all(5)
		b.add_theme_stylebox_override(&"normal", st)
		b.add_theme_stylebox_override(&"hover", sel)
		b.add_theme_stylebox_override(&"pressed", sel)
		b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
		b.pressed.connect(_select_color.bind(c, b))
		_palette_grid.add_child(b)
		_swatches.append(b)
	if _tool_buttons.has("soft"):
		(_tool_buttons["soft"] as Button).visible = kit >= 1
		(_tool_buttons["watercolor"] as Button).visible = kit >= 2


# --- Layout ------------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.12, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_right = -40
	root.offset_top = 40
	root.offset_bottom = -40
	root.add_theme_constant_override(&"separation", 28)
	add_child(root)

	# Left: palette.
	var left := _panel_box()
	var lcol := VBoxContainer.new()
	lcol.add_child(_caption("SKETCH_PALETTE"))
	_palette_grid.columns = 4
	_palette_grid.add_theme_constant_override(&"h_separation", 8)
	_palette_grid.add_theme_constant_override(&"v_separation", 8)
	lcol.add_child(_palette_grid)
	left.add_child(lcol)
	root.add_child(left)

	# Centre: easel with canvas, then actions.
	var centre := VBoxContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override(&"separation", 16)
	var easel := PanelContainer.new()
	var est := StyleBoxFlat.new()
	est.bg_color = WOOD
	est.set_content_margin_all(18)
	est.set_corner_radius_all(4)
	est.border_color = WOOD_DARK
	est.set_border_width_all(4)
	est.shadow_color = Color(0, 0, 0, 0.5)
	est.shadow_size = 18
	easel.add_theme_stylebox_override(&"panel", est)
	easel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	easel.add_child(canvas)
	centre.add_child(easel)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override(&"separation", 12)
	_ref_button.pressed.connect(func() -> void:
		reference_index = (reference_index + 1) % REFERENCE_LEVELS.size()
		_apply_reference())
	for spec: Array in [
		[_ref_button, Callable()],
		[_button("SKETCH_UNDO"), canvas.undo],
		[_button("SKETCH_CLEAR"), canvas.clear],
		[_button("UI_CANCEL"), close],
		[_button("SKETCH_SAVE"), save_drawing],
	]:
		var b: Button = spec[0]
		_style(b)
		if spec[1] is Callable and (spec[1] as Callable).is_valid():
			b.pressed.connect(spec[1])
		actions.add_child(b)
	centre.add_child(actions)
	_status.add_theme_color_override(&"font_color", Color(0.85, 0.78, 0.65))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text = "SKETCH_HELP"
	centre.add_child(_status)
	root.add_child(centre)

	# Right: reference thumbnail, tools and brush sizes.
	var right := _panel_box()
	var rcol := VBoxContainer.new()
	rcol.add_theme_constant_override(&"separation", 8)
	rcol.add_child(_caption("SKETCH_VIEW"))
	_ref_thumb.custom_minimum_size = Vector2(240, 135)
	_ref_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ref_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rcol.add_child(_ref_thumb)
	rcol.add_child(_caption("SKETCH_TOOLS"))
	for tool: String in ["pencil", "soft", "watercolor", "eraser"]:
		var b := _button("SKETCH_TOOL_" + tool.to_upper())
		b.toggle_mode = true
		_style(b)
		b.pressed.connect(_select_tool.bind(tool))
		rcol.add_child(b)
		_tool_buttons[tool] = b
	rcol.add_child(_caption("SKETCH_SIZE"))
	var sizes := HBoxContainer.new()
	for i: int in SIZES.size():
		var b := Button.new()
		b.text = ["S", "M", "L", "XL"][i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(52, 40)
		_style(b)
		b.pressed.connect(_select_size.bind(i))
		sizes.add_child(b)
		_size_buttons.append(b)
	rcol.add_child(sizes)
	right.add_child(rcol)
	root.add_child(right)


func _panel_box() -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER_UI
	st.set_corner_radius_all(8)
	st.set_content_margin_all(16)
	p.add_theme_stylebox_override(&"panel", st)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _caption(key: String) -> Label:
	var l := Label.new()
	l.text = key
	l.add_theme_color_override(&"font_color", INK)
	l.add_theme_font_size_override(&"font_size", 18)
	return l


func _button(key: String) -> Button:
	var b := Button.new()
	b.text = key
	return b


func _style(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.9, 0.85, 0.75)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(9)
	var on := normal.duplicate() as StyleBoxFlat
	on.bg_color = Color(0.95, 0.75, 0.45)
	b.add_theme_stylebox_override(&"normal", normal)
	b.add_theme_stylebox_override(&"hover", on)
	b.add_theme_stylebox_override(&"pressed", on)
	b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	b.add_theme_color_override(&"font_color", INK)
	b.add_theme_color_override(&"font_pressed_color", INK)
	b.add_theme_color_override(&"font_hover_color", INK)
	b.add_theme_font_size_override(&"font_size", 17)
