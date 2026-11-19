extends Control
## End-of-chapter screen with the graphical decision flowchart.
## Scroll with stick / D-pad / arrows (both axes) or the mouse wheel.

signal continued

const UiTheme = preload("res://ui/ui_theme.gd")
const FlowchartView = preload("res://ui/flowchart_view.gd")
const SCROLL_STEP := 140

var _scroll: ScrollContainer
var _flow: FlowchartView
var _title: Label
var _explored: Label
var _footer: Label
var _continue: Button


func _ready() -> void:
	UiTheme.full_rect(self)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.04, 0.97)
	UiTheme.full_rect(dim)
	add_child(dim)
	var margin := MarginContainer.new()
	UiTheme.full_rect(margin)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 100)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	_title = UiTheme.make_label("", UiTheme.FONT_HEADING, UiTheme.ACCENT)
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_title)
	_explored = UiTheme.make_label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	_explored.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_explored)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)
	_flow = FlowchartView.new()
	_scroll.add_child(_flow)
	_footer = UiTheme.make_label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	_footer.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_footer)
	_continue = UiTheme.make_button("summary.continue", 400)
	_continue.pressed.connect(_on_continue)
	box.add_child(_continue)


func _on_continue() -> void:
	visible = false
	continued.emit()


func show_summary(chapter: Dictionary, end_of_build: bool) -> void:
	var graph := DecisionManager.build_flowchart(chapter)
	_title.text = "%s  -  %s" % [Localization.t("summary.title"), Localization.t(str(chapter.get("title", "")))]
	_explored.text = Localization.t("summary.explored", {"p": FlowchartView.explored_percent(graph)})
	_footer.text = Localization.t("summary.end_of_build") if end_of_build else Localization.t("summary.missed_hint")
	_flow.set_graph(graph)
	visible = true
	_scroll.scroll_vertical = 0
	_scroll.scroll_horizontal = int(maxf(0.0, (_flow.custom_minimum_size.x - 1720.0) / 2.0))
	_continue.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var handled := true
	if event.is_action_pressed("ui_up") or event.is_action_pressed("camera_up"):
		_scroll.scroll_vertical -= SCROLL_STEP
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("camera_down"):
		_scroll.scroll_vertical += SCROLL_STEP
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("camera_left"):
		_scroll.scroll_horizontal -= SCROLL_STEP
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("camera_right"):
		_scroll.scroll_horizontal += SCROLL_STEP
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
