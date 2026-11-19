extends Control
## Journal: every clue / note collected so far, newest last. Pauses the game.

const UiTheme = preload("res://ui/ui_theme.gd")

var _scroll: ScrollContainer
var _list: VBoxContainer
var _close: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiTheme.full_rect(self)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.04, 0.95)
	UiTheme.full_rect(dim)
	add_child(dim)
	var margin := MarginContainer.new()
	UiTheme.full_rect(margin)
	margin.add_theme_constant_override("margin_left", 260)
	margin.add_theme_constant_override("margin_right", 260)
	margin.add_theme_constant_override("margin_top", 90)
	margin.add_theme_constant_override("margin_bottom", 90)
	add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	box.add_child(UiTheme.make_label("journal.title", UiTheme.FONT_HEADING, UiTheme.ACCENT))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_close = UiTheme.make_button("journal.close", 400)
	_close.pressed.connect(close)
	box.add_child(_close)


func open() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if GameState.journal.is_empty():
		_list.add_child(UiTheme.make_label("journal.empty", UiTheme.FONT_BODY, UiTheme.TEXT_DIM))
	for key: String in GameState.journal:
		var l := UiTheme.make_label("-  " + Localization.t(key))
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(1300, 0)
		_list.add_child(l)
	visible = true
	get_tree().paused = true
	_close.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("journal") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("camera_up"):
		_scroll.scroll_vertical -= 120
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("camera_down"):
		_scroll.scroll_vertical += 120
		get_viewport().set_input_as_handled()
