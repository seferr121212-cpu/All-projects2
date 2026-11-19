class_name PauseMenu
extends CanvasLayer
## Esc during play: resume, save, load, settings, title screen, quit.

var _settings: SettingsMenu
var _panel := PanelContainer.new()
var _load_button: Button


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.03, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	UIStyle.panel(_panel, 30)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	col.custom_minimum_size = Vector2(380, 0)
	col.add_child(UIStyle.label("PAUSE_TITLE", 30))
	col.add_child(UIStyle.make_button("PAUSE_RESUME", close))
	col.add_child(UIStyle.make_button("PAUSE_SAVE", func() -> void:
		if SaveManager.save_game(SaveManager.MANUAL_SLOT):
			GameState.notify(tr(&"UI_SAVED"))
			close()))
	_load_button = UIStyle.make_button("PAUSE_LOAD", func() -> void:
		close()
		if SaveManager.load_latest():
			GameState.notify(tr(&"UI_LOADED")))
	col.add_child(_load_button)
	col.add_child(UIStyle.make_button("PAUSE_SETTINGS", func() -> void:
		_panel.visible = false
		_settings.open()))
	col.add_child(UIStyle.make_button("PAUSE_TITLE_SCREEN", func() -> void:
		SaveManager.autosave()
		close()
		GameState.show_title()))
	col.add_child(UIStyle.make_button("PAUSE_QUIT", func() -> void:
		SaveManager.autosave()
		get_tree().quit()))
	_panel.add_child(col)
	add_child(_panel)
	_settings = SettingsMenu.new()
	add_child(_settings)
	_settings.closed.connect(func() -> void: _panel.visible = true)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if visible and _panel.visible:
		close()
		get_viewport().set_input_as_handled()
	elif not visible and GameState.is_gameplay():
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	_load_button.disabled = SaveManager.latest_slot() == ""
	visible = true
	_panel.visible = true
	GameState.set_context(GameState.Context.MENU)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	get_tree().paused = false
	GameState.set_context(GameState.Context.GAMEPLAY)
	if not DevCli.is_requested():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
