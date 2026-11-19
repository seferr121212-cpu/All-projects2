extends Control
## Pause overlay (runs while the tree is paused). Also opened automatically
## when the gamepad disconnects.

signal quit_to_menu

const UiTheme = preload("res://ui/ui_theme.gd")
const SettingsMenu = preload("res://ui/settings_menu.gd")

var _main: PanelContainer
var _message: Label
var _resume: Button
var _settings: SettingsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiTheme.full_rect(self)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	UiTheme.full_rect(dim)
	add_child(dim)
	var center := CenterContainer.new()
	UiTheme.full_rect(center)
	add_child(center)
	_main = PanelContainer.new()
	center.add_child(_main)
	var box := VBoxContainer.new()
	_main.add_child(box)
	box.add_child(UiTheme.make_label("pause.title", UiTheme.FONT_HEADING))
	_message = UiTheme.make_label("", UiTheme.FONT_SMALL, UiTheme.ACCENT)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(620, 0)
	box.add_child(_message)
	_resume = UiTheme.make_button("pause.resume", 620)
	_resume.pressed.connect(close)
	var settings := UiTheme.make_button("pause.settings", 620)
	settings.pressed.connect(func() -> void:
		_main.visible = false
		_settings.open())
	var quit := UiTheme.make_button("pause.quit_menu", 620)
	quit.pressed.connect(func() -> void:
		close()
		quit_to_menu.emit())
	for b in [_resume, settings, quit]:
		box.add_child(b)
	UiTheme.chain_focus([_resume, settings, quit])
	var note := UiTheme.make_label("pause.autosave_note", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(620, 0)
	box.add_child(note)
	_settings = SettingsMenu.new()
	_settings.visible = false
	center.add_child(_settings)
	_settings.closed.connect(func() -> void:
		_main.visible = true
		_resume.grab_focus())


func open(message_key: String = "") -> void:
	_message.text = message_key
	_message.visible = message_key != ""
	visible = true
	_main.visible = true
	_settings.visible = false
	get_tree().paused = true
	_resume.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _settings.visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
