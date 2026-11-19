extends Control
## Modal yes/no prompt. "No" is focused by default (the safe answer).

signal answered(yes: bool)

const UiTheme = preload("res://ui/ui_theme.gd")

var _message: Label
var _yes: Button
var _no: Button


func _ready() -> void:
	UiTheme.full_rect(self)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	UiTheme.full_rect(dim)
	add_child(dim)
	var center := CenterContainer.new()
	UiTheme.full_rect(center)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_message = UiTheme.make_label("")
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(760, 0)
	box.add_child(_message)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_yes = UiTheme.make_button("confirm.yes", 240)
	_no = UiTheme.make_button("confirm.no", 240)
	row.add_child(_yes)
	row.add_child(_no)
	_yes.focus_neighbor_right = _yes.get_path_to(_no)
	_no.focus_neighbor_left = _no.get_path_to(_yes)
	_yes.pressed.connect(_answer.bind(true))
	_no.pressed.connect(_answer.bind(false))


func ask(message_key: String) -> void:
	_message.text = message_key
	visible = true
	_no.grab_focus()


func _answer(yes: bool) -> void:
	visible = false
	AudioBus.play("ui/select")
	answered.emit(yes)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_answer(false)
