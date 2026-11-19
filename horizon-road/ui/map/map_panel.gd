class_name MapPanel
extends CanvasLayer
## Region map (M, or the map table in the camper): painted from the terrain
## data, with you, the camper, people you've met and notable places.

const PAPER := Color(0.95, 0.91, 0.82)
const INK := Color(0.24, 0.19, 0.14)
const MAP_PX: int = 256

@export var travel_path: NodePath

var _travel: TravelController
var _frame := PanelContainer.new()
var _map := TextureRect.new()
var _overlay: Control
var _title := Label.new()


func _ready() -> void:
	layer = 19
	process_mode = Node.PROCESS_MODE_ALWAYS
	_travel = get_node_or_null(travel_path)
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"map"):
		if visible:
			close()
		elif GameState.is_gameplay():
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	var region: Region = GameState.current_region
	if region == null:
		return
	if _map.texture == null:
		_map.texture = ImageTexture.create_from_image(region.terrain.render_map_image(MAP_PX))
	var def_name: String = region.definition.name_key if region.definition else ""
	_title.text = "%s — %s" % [tr(&"MAP_TITLE"), tr(StringName(def_name))]
	GameState.set_context(GameState.Context.MENU)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_overlay.queue_redraw()


func close() -> void:
	visible = false
	GameState.set_context(GameState.Context.GAMEPLAY)
	if not DevCli.is_requested():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## World x/z -> point inside the map rect.
func world_to_map(p: Vector3, rect: Rect2) -> Vector2:
	var terrain: HighlandTerrain = GameState.current_region.terrain
	var half: float = terrain.size * 0.5
	return rect.position + Vector2((p.x + half) / terrain.size, (p.z + half) / terrain.size) * rect.size


func _draw_overlay() -> void:
	if GameState.current_region == null:
		return
	var rect := Rect2(Vector2.ZERO, _overlay.size)
	var font: Font = _overlay.get_theme_default_font()
	# Places worth visiting (from photo subjects).
	var seen: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"photo_subject"):
		var s := node as PhotoSubject
		if s.category not in [PhotoSubject.Category.LANDSCAPE, PhotoSubject.Category.STRUCTURE] or seen.has(s.subject_id):
			continue
		if s.subject_id in [&"SUBJ_OUR_CAMPER", &"SUBJ_YAYLA_HOUSE", &"SUBJ_MOUNTAIN_RANGE"]:
			continue
		seen[s.subject_id] = true
		var mp: Vector2 = world_to_map(s.global_position, rect)
		_overlay.draw_circle(mp, 4.0, INK)
		_overlay.draw_string(font, mp + Vector2(8, 5), tr(StringName(s.name_key)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
	for node: Node in get_tree().get_nodes_in_group(&"npc"):
		var npc := node as Npc
		if not GameState.people.has(String(npc.npc_id)):
			continue
		var mp: Vector2 = world_to_map(npc.global_position, rect)
		_overlay.draw_circle(mp, 6.0, Color(0.78, 0.45, 0.2))
		_overlay.draw_string(font, mp + Vector2(9, 5), npc.get_display_name().get_slice(" ", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.3, 0.1))
	if _travel:
		var cp: Vector2 = world_to_map(_travel.camper.global_position, rect)
		_overlay.draw_rect(Rect2(cp - Vector2(7, 5), Vector2(14, 10)), Color(0.22, 0.52, 0.52))
		_overlay.draw_string(font, cp + Vector2(10, -6), tr(&"MAP_CAMPER"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
		var body: Node3D = _travel.get_controlled_body()
		var me: Vector2 = world_to_map(body.global_position, rect)
		var fwd3: Vector3 = -_travel.follow_camera.global_basis.z
		var fwd := Vector2(fwd3.x, fwd3.z).normalized()
		var side := Vector2(-fwd.y, fwd.x)
		_overlay.draw_colored_polygon(PackedVector2Array([me + fwd * 14.0, me - fwd * 7.0 + side * 8.0, me - fwd * 7.0 - side * 8.0]), Color(0.85, 0.2, 0.15))


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22)
	style.border_color = Color(0.55, 0.38, 0.22)
	style.set_border_width_all(4)
	_frame.add_theme_stylebox_override(&"panel", style)
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	var col := VBoxContainer.new()
	_title.add_theme_font_size_override(&"font_size", 24)
	_title.add_theme_color_override(&"font_color", INK)
	col.add_child(_title)
	_map.custom_minimum_size = Vector2(760, 760)
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	_map.add_child(_overlay)
	col.add_child(_map)
	var next := Label.new()
	next.text = "MAP_NEXT_REGION"
	next.add_theme_color_override(&"font_color", Color(0.45, 0.38, 0.3))
	col.add_child(next)
	_frame.add_child(col)
	add_child(_frame)
