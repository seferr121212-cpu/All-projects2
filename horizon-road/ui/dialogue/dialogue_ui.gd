class_name DialogueUI
extends CanvasLayer
## Conversation panel: speaker name/role/relationship, typewriter text,
## choices (mouse, number keys, gamepad), name entry and a photo picker.
## Drives a DialogueRunner; owns the DIALOGUE input context while open.

const PAPER := Color(0.97, 0.94, 0.88, 0.96)
const INK := Color(0.24, 0.19, 0.14)
const INK_SOFT := Color(0.47, 0.4, 0.32)
const ACCENT := Color(0.78, 0.45, 0.2)
const CHARS_PER_SEC: float = 45.0

@export var travel_path: NodePath

var runner: DialogueRunner
var npc: Npc
var _travel: TravelController
var _panel := PanelContainer.new()
var _name := Label.new()
var _meta := Label.new()
var _text := Label.new()
var _hint := Label.new()
var _choices := VBoxContainer.new()
var _name_row := HBoxContainer.new()
var _name_edit := LineEdit.new()
var _picker := PanelContainer.new()
var _picker_grid := GridContainer.new()
var _picker_title := Label.new()
var _shop := PanelContainer.new()
var _shop_list := VBoxContainer.new()
var _shop_header := Label.new()
var _typing: bool = false
var _waiting_advance: bool = false


func _ready() -> void:
	add_to_group(&"dialogue_ui")
	layer = 15
	_travel = get_node_or_null(travel_path)
	_build()
	visible = false


func start(who: Npc) -> void:
	if not GameState.is_gameplay():
		return
	npc = who
	npc.talking = true
	runner = DialogueRunner.new(who.data, self)
	runner.line_shown.connect(_on_line)
	runner.choices_shown.connect(_on_choices)
	runner.name_requested.connect(_on_name_requested)
	runner.photo_picker_requested.connect(_open_picker.bind(false))
	runner.drawing_picker_requested.connect(_open_picker.bind(true))
	runner.shop_requested.connect(_open_shop)
	runner.ended.connect(_close)
	GameState.set_context(GameState.Context.DIALOGUE)
	if _travel:
		_travel.suspend_control()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_frame_conversation()
	_refresh_header()
	runner.start()


## Over-the-shoulder framing: camera behind the player, looking at the NPC's face.
func _frame_conversation() -> void:
	if _travel == null or GameState.player_mode != GameState.PlayerMode.ON_FOOT:
		return
	var walker: WalkerController = _travel.walker
	var to_npc: Vector3 = npc.global_position - walker.global_position
	var yaw: float = atan2(-to_npc.x, -to_npc.z)
	walker.get_node(^"Visual").rotation.y = yaw
	_travel.follow_camera.yaw = yaw + 0.9
	_travel.follow_camera.pitch = -0.08


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _shop.visible:
		if event.is_action_pressed(&"pause"):
			_close_shop()
			get_viewport().set_input_as_handled()
		return
	if _picker.visible:
		if event.is_action_pressed(&"pause"):
			_picker.visible = false
			runner.cancel_photo()
			get_viewport().set_input_as_handled()
		return
	if _name_row.visible:
		return
	var advance: bool = event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") \
			or (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and _choices.get_child_count() == 0)
	if advance:
		get_viewport().set_input_as_handled()
		if _typing:
			_text.visible_ratio = 1.0
			_typing = false
			_after_typing()
		elif _waiting_advance:
			_waiting_advance = false
			runner.advance()
		return
	if event is InputEventKey and event.pressed and _choices.get_child_count() > 0:
		var k: int = (event as InputEventKey).keycode - KEY_1
		if k >= 0 and k < _choices.get_child_count():
			get_viewport().set_input_as_handled()
			_pick(k)


func _process(delta: float) -> void:
	if not visible or not _typing:
		return
	var total: int = maxi(_text.get_total_character_count(), 1)
	_text.visible_ratio = minf(_text.visible_ratio + CHARS_PER_SEC * delta / total, 1.0)
	if _text.visible_ratio >= 1.0:
		_typing = false
		_after_typing()


func _on_line(text: String) -> void:
	_refresh_header()
	_clear_choices()
	_name_row.visible = false
	_text.text = text
	_text.visible_ratio = 0.0
	_typing = true
	_hint.text = ""


func _after_typing() -> void:
	var node: Dictionary = runner.data.nodes.get(runner.current_id, {})
	if node.has("choices"):
		runner.advance()
	else:
		_waiting_advance = true
		_hint.text = "UI_DIALOGUE_CONTINUE"


func _on_choices(choices: Array[Dictionary]) -> void:
	_clear_choices()
	_hint.text = ""
	for i: int in choices.size():
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, choices[i].label]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_choice(b)
		b.pressed.connect(_pick.bind(i))
		_choices.add_child(b)
	if _choices.get_child_count() > 0:
		_focus_first_choice.call_deferred()


func _focus_first_choice() -> void:
	if _choices.get_child_count() > 0 and _choices.get_child(0).is_inside_tree():
		(_choices.get_child(0) as Button).grab_focus()


func _pick(index: int) -> void:
	_clear_choices()
	runner.choose(index)
	_refresh_header()


func _on_name_requested(text: String) -> void:
	_on_line(text)
	_typing = false
	_text.visible_ratio = 1.0
	_name_row.visible = true
	_name_edit.text = GameState.player_name
	_name_edit.grab_focus.call_deferred()


func _submit_name(_t: String = "") -> void:
	_name_row.visible = false
	runner.submit_name(_name_edit.text)
	_refresh_header()


func _open_picker(drawings: bool) -> void:
	for child: Node in _picker_grid.get_children():
		child.queue_free()
	_picker_title.text = "UI_PICK_DRAWING" if drawings else "UI_PICK_PHOTO"
	var book: RefCounted = GameState.drawings if drawings else GameState.album
	var entries: Array[Dictionary] = book.entries
	for i: int in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i]
		var card := VBoxContainer.new()
		var b := TextureButton.new()
		b.texture_normal = book.get_thumbnail(entry)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		b.custom_minimum_size = Vector2(224, 126)
		b.pressed.connect(func() -> void:
			_picker.visible = false
			runner.choose_photo(entry))
		card.add_child(b)
		var sold: bool = String(runner.npc_id) in entry.get("sold_to", [])
		var stars: int = int(entry.get("stars", 1))
		var caption := Label.new()
		caption.text = "★".repeat(stars) + "☆".repeat(3 - stars) + ("   " + tr(&"UI_SOLD") if sold else "")
		caption.add_theme_color_override(&"font_color", INK_SOFT)
		card.add_child(caption)
		_picker_grid.add_child(card)
	_picker.visible = true


# --- Upgrade shop -------------------------------------------------------------

func _open_shop() -> void:
	_fill_shop()
	_shop.visible = true


func _close_shop() -> void:
	_shop.visible = false
	runner.close_shop()


func _fill_shop() -> void:
	for c: Node in _shop_list.get_children():
		_shop_list.remove_child(c)
		c.queue_free()
	var level: int = GameState.get_relationship_level(npc.npc_id)
	var discount: int = roundi(GameState.ECONOMY.friend_discount_per_level * level * 100.0)
	_shop_header.text = "%s   ·   %d ₺%s" % [tr(&"UI_SHOP_TITLE"), GameState.money,
			("   ·   " + tr(&"UI_FRIEND_DISCOUNT") % discount) if discount > 0 else ""]
	for u: Dictionary in UpgradeCatalog.all():
		var id: String = u.id
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 14)
		var icon := Label.new()
		icon.text = u.get("icon", "•")
		icon.add_theme_font_size_override(&"font_size", 26)
		icon.add_theme_color_override(&"font_color", ACCENT)
		icon.custom_minimum_size = Vector2(36, 0)
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cur: int = GameState.get_upgrade_level(id)
		var maxl: int = UpgradeCatalog.max_level(id)
		var title := Label.new()
		title.text = "%s   %s" % [tr(StringName(u.name_key)), "●".repeat(cur) + "○".repeat(maxl - cur)]
		title.add_theme_font_size_override(&"font_size", 19)
		title.add_theme_color_override(&"font_color", INK)
		info.add_child(title)
		var desc := Label.new()
		desc.text = tr(StringName(u.desc_key))
		desc.add_theme_color_override(&"font_color", INK_SOFT)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)
		row.add_child(info)
		var buy := Button.new()
		var price: int = GameState.upgrade_price(id, npc.npc_id)
		buy.custom_minimum_size = Vector2(170, 0)
		_style_choice(buy)
		if price < 0:
			buy.text = tr(&"UI_MAXED")
			buy.disabled = true
		else:
			buy.text = tr(&"UI_BUY") % price
			buy.disabled = price > GameState.money
			buy.pressed.connect(func() -> void:
				if GameState.buy_upgrade(id, npc.npc_id):
					GameState.notify(tr(&"UI_UPGRADE_FITTED") % tr(StringName(u.name_key)))
					GameState.add_relationship(npc.npc_id, 3)
				_fill_shop())
		row.add_child(buy)
		_shop_list.add_child(row)
		_shop_list.add_child(HSeparator.new())


func _close() -> void:
	visible = false
	_picker.visible = false
	_shop.visible = false
	if npc:
		npc.talking = false
	GameState.set_context(GameState.Context.GAMEPLAY)
	if _travel:
		_travel.restore_control()
	if not DevCli.is_requested():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh_header() -> void:
	if npc == null:
		return
	_name.text = npc.get_display_name()
	var level: int = GameState.get_relationship_level(npc.npc_id)
	var hearts: String = "♥".repeat(level + 1) + "♡".repeat(GameState.ECONOMY.level_thresholds.size() - level - 1)
	_meta.text = "%s   ·   %s %s" % [tr(StringName(npc.data.get("role_key", ""))), hearts, tr(StringName(GameState.ECONOMY.level_keys[level]))]


func _clear_choices() -> void:
	for c: Node in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()


# --- Layout ----------------------------------------------------------------

func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	style.border_color = Color(0.55, 0.38, 0.22)
	style.set_border_width_all(3)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 12
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.anchor_left = 0.18
	_panel.anchor_right = 0.82
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	# Zero-height box growing upwards: the panel sizes itself to its content.
	_panel.offset_top = -40
	_panel.offset_bottom = -40
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	_panel.add_child(col)
	var header := HBoxContainer.new()
	_name.add_theme_font_size_override(&"font_size", 24)
	_name.add_theme_color_override(&"font_color", ACCENT)
	header.add_child(_name)
	_meta.add_theme_color_override(&"font_color", INK_SOFT)
	_meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_meta)
	col.add_child(header)
	_text.add_theme_font_size_override(&"font_size", 21)
	_text.add_theme_color_override(&"font_color", INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 56)
	col.add_child(_text)
	col.add_child(_choices)
	_name_edit.placeholder_text = "UI_NAME_PLACEHOLDER"
	_name_edit.custom_minimum_size = Vector2(280, 0)
	_name_edit.max_length = 20
	var field := StyleBoxFlat.new()
	field.bg_color = Color(1.0, 0.99, 0.96)
	field.border_color = ACCENT
	field.set_border_width_all(2)
	field.set_corner_radius_all(6)
	field.set_content_margin_all(8)
	_name_edit.add_theme_stylebox_override(&"normal", field)
	_name_edit.add_theme_stylebox_override(&"focus", field)
	_name_edit.add_theme_color_override(&"font_color", INK)
	_name_edit.add_theme_color_override(&"caret_color", ACCENT)
	_name_edit.add_theme_color_override(&"font_placeholder_color", INK_SOFT)
	_name_edit.add_theme_font_size_override(&"font_size", 19)
	_name_edit.text_submitted.connect(_submit_name)
	_name_row.add_child(_name_edit)
	var ok := Button.new()
	ok.text = "UI_NAME_CONFIRM"
	_style_choice(ok)
	ok.pressed.connect(_submit_name)
	_name_row.add_child(ok)
	_name_row.visible = false
	col.add_child(_name_row)
	_hint.add_theme_color_override(&"font_color", INK_SOFT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_hint)

	var pstyle := style.duplicate() as StyleBoxFlat
	_picker.add_theme_stylebox_override(&"panel", pstyle)
	_picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker.offset_left = 220
	_picker.offset_right = -220
	_picker.offset_top = 90
	_picker.offset_bottom = -380
	var pcol := VBoxContainer.new()
	_picker_title.add_theme_font_size_override(&"font_size", 22)
	_picker_title.add_theme_color_override(&"font_color", INK)
	pcol.add_child(_picker_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker_grid.columns = 5
	_picker_grid.add_theme_constant_override(&"h_separation", 14)
	_picker_grid.add_theme_constant_override(&"v_separation", 10)
	scroll.add_child(_picker_grid)
	pcol.add_child(scroll)
	var cancel := Button.new()
	cancel.text = "UI_CANCEL"
	_style_choice(cancel)
	cancel.pressed.connect(func() -> void:
		_picker.visible = false
		runner.cancel_photo())
	pcol.add_child(cancel)
	_picker.add_child(pcol)
	_picker.visible = false
	add_child(_picker)

	var sstyle := style.duplicate() as StyleBoxFlat
	_shop.add_theme_stylebox_override(&"panel", sstyle)
	_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.offset_left = 300
	_shop.offset_right = -300
	_shop.offset_top = 70
	_shop.offset_bottom = -70
	var scol := VBoxContainer.new()
	scol.add_theme_constant_override(&"separation", 10)
	_shop_header.add_theme_font_size_override(&"font_size", 24)
	_shop_header.add_theme_color_override(&"font_color", ACCENT)
	scol.add_child(_shop_header)
	var sscroll := ScrollContainer.new()
	sscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sscroll.add_child(_shop_list)
	scol.add_child(sscroll)
	var close := Button.new()
	close.text = "UI_CLOSE"
	_style_choice(close)
	close.pressed.connect(_close_shop)
	scol.add_child(close)
	_shop.add_child(scol)
	_shop.visible = false
	add_child(_shop)


func _style_choice(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.9, 0.85, 0.75)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(9)
	normal.content_margin_left = 14
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.95, 0.86, 0.68)
	hover.border_color = ACCENT
	hover.border_width_left = 4
	b.add_theme_stylebox_override(&"normal", normal)
	b.add_theme_stylebox_override(&"hover", hover)
	b.add_theme_stylebox_override(&"focus", hover)
	b.add_theme_stylebox_override(&"pressed", hover)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.86, 0.83, 0.78)
	b.add_theme_stylebox_override(&"disabled", disabled)
	b.add_theme_color_override(&"font_disabled_color", INK_SOFT)
	b.add_theme_color_override(&"font_color", INK)
	b.add_theme_color_override(&"font_hover_color", INK)
	b.add_theme_color_override(&"font_focus_color", INK)
	b.add_theme_font_size_override(&"font_size", 18)
