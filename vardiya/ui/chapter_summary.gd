extends Control
## End-of-chapter decision overview (text flowchart for stage 2; the
## graphical node flowchart arrives in stage 3). Lists every choice node of
## the chapter in graph order: what was chosen, what was missed, and which
## decisions were never reached.

signal continued

const UiTheme = preload("res://ui/ui_theme.gd")

var _scroll: ScrollContainer
var _list: VBoxContainer
var _title: Label
var _explored: Label
var _footer: Label
var _continue: Button


func _ready() -> void:
	UiTheme.full_rect(self)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.04, 0.96)
	UiTheme.full_rect(dim)
	add_child(dim)
	var margin := MarginContainer.new()
	UiTheme.full_rect(margin)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 220)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 90)
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
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_footer = UiTheme.make_label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	_footer.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_footer)
	_continue = UiTheme.make_button("summary.continue", 400)
	_continue.pressed.connect(func() -> void:
		visible = false
		continued.emit())
	box.add_child(_continue)


func show_summary(chapter: Dictionary, end_of_build: bool) -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_title.text = "%s  -  %s" % [Localization.t("summary.title"), Localization.t(str(chapter.get("title", "")))]
	var entries := DecisionManager.build_chapter_summary(chapter)
	var total := 0
	var taken := 0
	for e: Dictionary in entries:
		var head := Localization.t(str(e["prompt"])) if str(e["prompt"]) != "" else str(e["decision_id"])
		if e["major"]:
			head = "%s   [%s]" % [head, Localization.t("dialogue.major")]
		_list.add_child(UiTheme.make_label(head, UiTheme.FONT_BODY, UiTheme.TEXT if e["visited"] else UiTheme.TEXT_DIM))
		if not e["visited"]:
			_list.add_child(UiTheme.make_label("      " + Localization.t("summary.unvisited"), UiTheme.FONT_SMALL, UiTheme.TEXT_DIM))
		for o: Dictionary in e["options"]:
			total += 1
			var marker := "      o  "
			var color := UiTheme.TEXT_DIM
			var suffix := ""
			if o["chosen"]:
				taken += 1
				marker = "      >  "
				color = UiTheme.ACCENT
				suffix = "   (%s)" % Localization.t("summary.chosen")
			_list.add_child(UiTheme.make_label(marker + Localization.t(str(o["text"])) + suffix, UiTheme.FONT_SMALL, color))
	for c in _list.get_children():
		(c as Label).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var pct := int(round(100.0 * taken / total)) if total > 0 else 0
	_explored.text = Localization.t("summary.explored", {"p": pct})
	_footer.text = Localization.t("summary.end_of_build") if end_of_build else Localization.t("summary.missed_hint")
	visible = true
	_scroll.scroll_vertical = 0
	_continue.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Scroll the list with up/down (stick, D-pad, arrows) or the right stick.
	if event.is_action_pressed("ui_up") or event.is_action_pressed("camera_up"):
		_scroll.scroll_vertical -= 120
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("camera_down"):
		_scroll.scroll_vertical += 120
		get_viewport().set_input_as_handled()
