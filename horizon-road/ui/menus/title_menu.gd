class_name TitleMenu
extends CanvasLayer
## Title screen over the live highland: the camera drifts slowly around the
## parked camper. Continue, start a new journey, settings, quit.

var _settings: SettingsMenu
var _panel := VBoxContainer.new()
var _continue: Button
var _confirm := PanelContainer.new()
var _orbit: float = 0.0


func _ready() -> void:
	layer = 42
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.55))
	g.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	grad.custom_minimum_size = Vector2(900, 0)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(grad)
	_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_panel.offset_left = 120
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.add_theme_constant_override(&"separation", 12)
	var title := UIStyle.label("GAME_TITLE", 84, Color(1.0, 0.95, 0.85))
	title.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override(&"shadow_offset_y", 4)
	_panel.add_child(title)
	_panel.add_child(UIStyle.label("TITLE_SUBTITLE", 22, Color(1.0, 0.9, 0.75, 0.9)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	_panel.add_child(spacer)
	_continue = UIStyle.make_button("TITLE_CONTINUE", _on_continue, 22)
	_panel.add_child(_continue)
	_panel.add_child(UIStyle.make_button("TITLE_NEW", _on_new, 22))
	_panel.add_child(UIStyle.make_button("PAUSE_SETTINGS", func() -> void:
		_panel.visible = false
		_settings.open(), 22))
	_panel.add_child(UIStyle.make_button("PAUSE_QUIT", func() -> void: get_tree().quit(), 22))
	for b: Node in _panel.get_children():
		if b is Button:
			(b as Button).custom_minimum_size = Vector2(320, 0)
			(b as Button).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(_panel)
	var credits := UIStyle.label("TITLE_CREDITS", 14, Color(1, 1, 1, 0.7))
	credits.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	credits.offset_left = 120
	credits.offset_top = -50
	add_child(credits)
	_build_confirm()
	_settings = SettingsMenu.new()
	add_child(_settings)
	_settings.closed.connect(func() -> void: _panel.visible = true)


func open() -> void:
	var has_save: bool = SaveManager.latest_slot() != ""
	_continue.visible = has_save
	_confirm.visible = false
	_panel.visible = true
	visible = true
	GameState.set_context(GameState.Context.MENU)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_music_now()
	(_continue if has_save else _panel.get_child(4) as Button).grab_focus.call_deferred()


func close() -> void:
	visible = false
	GameState.set_context(GameState.Context.GAMEPLAY)
	if not DevCli.is_requested():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not visible:
		return
	# Slow cinematic drift around the camper.
	var travel := get_tree().get_first_node_in_group(&"travel") as TravelController
	if travel:
		_orbit += delta * 0.05
		travel.follow_camera.yaw = travel.camper.global_rotation.y + 2.2 + _orbit
		travel.follow_camera.pitch = -0.12


func _on_continue() -> void:
	close()
	SaveManager.load_latest()


func _on_new() -> void:
	if SaveManager.latest_slot() != "" and not _confirm.visible:
		_confirm.visible = true
		return
	close()
	GameState.new_game()


func _build_confirm() -> void:
	UIStyle.panel(_confirm)
	_confirm.set_anchors_preset(Control.PRESET_CENTER)
	_confirm.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm.grow_vertical = Control.GROW_DIRECTION_BOTH
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	var l := UIStyle.label("TITLE_NEW_CONFIRM", 19)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(460, 0)
	col.add_child(l)
	col.add_child(UIStyle.make_button("TITLE_NEW", _on_new))
	col.add_child(UIStyle.make_button("UI_CANCEL", func() -> void: _confirm.visible = false))
	_confirm.add_child(col)
	_confirm.visible = false
	add_child(_confirm)
