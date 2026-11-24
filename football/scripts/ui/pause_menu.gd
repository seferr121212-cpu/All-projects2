extends CanvasLayer
## Duraklatma menüsü (Esc / Start) ve maç sonu sonuç paneli. Oyun gerçekten durur.

var can_pause: Callable = func() -> bool: return true
var _panel: Control
var _title: Label
var _resume: Button
var _result_mode := false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	UIUtil.full_rect(_panel)
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	UIUtil.full_rect(dim)
	_panel.add_child(dim)
	var col := UIUtil.centered_column(_panel, 14)
	_title = UIUtil.title(tr("PAUSE_TITLE"), 48)
	col.add_child(_title)
	_resume = UIUtil.button(tr("PAUSE_RESUME"), close)
	col.add_child(_resume)
	col.add_child(UIUtil.button(tr("RESULT_PLAY_AGAIN"), func() -> void: Game.restart()))
	col.add_child(UIUtil.button(tr("MENU_SETTINGS"), _open_settings))
	col.add_child(UIUtil.button(tr("PAUSE_MAIN_MENU"), func() -> void: Game.go_main_menu()))
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	_panel.visible = true
	get_tree().paused = true
	_resume.visible = not _result_mode
	if _resume.visible:
		_resume.grab_focus()


func close() -> void:
	if _result_mode:
		return
	_panel.visible = false
	get_tree().paused = false


## Maç sonu: sonuç başlığı ile menüyü aç (devam düğmesi yok).
func show_result(text: String) -> void:
	_result_mode = true
	_title.text = text
	open()


func _open_settings() -> void:
	var s: Control = preload("res://scripts/ui/settings_menu.gd").new()
	s.embedded = true
	add_child(s)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _panel.visible:
			close()
		elif can_pause.call():
			open()
		get_viewport().set_input_as_handled()
