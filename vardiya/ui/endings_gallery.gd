extends PanelContainer
## Endings gallery (main menu). Reads the profile, not a save slot: an ending
## stays unlocked across slots and new games. Locked endings show "? ? ?" and
## a hint. Each row is a focusable button so the list scrolls with the pad.

signal closed

const UiTheme = preload("res://ui/ui_theme.gd")

var _count: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _back: Button


func _ready() -> void:
	custom_minimum_size = Vector2(1300, 820)
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(UiTheme.make_label("gallery.title", UiTheme.FONT_HEADING, UiTheme.ACCENT))
	_count = UiTheme.make_label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	_count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_count)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_back = UiTheme.make_button("menu.back", 400)
	_back.pressed.connect(close)
	box.add_child(_back)


## Rows: [{"id", "unlocked", "title", "text"}] with text already localized.
func rows() -> Array:
	var out: Array = []
	for id: String in DecisionManager.ending_ids():
		var d := DecisionManager.ending_details(id)
		var unlocked := SaveSystem.is_ending_unlocked(id)
		out.append({
			"id": id,
			"unlocked": unlocked,
			"title": Localization.t(str(d["title"])) if unlocked else Localization.t("gallery.locked"),
			"text": Localization.t(str(d["description"])) if unlocked
				else Localization.t("gallery.hint", {"hint": Localization.t(str(d["hint"]))}),
		})
	return out


func open() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var focusables: Array = []
	var data := rows()
	var unlocked := 0
	for r: Dictionary in data:
		if r["unlocked"]:
			unlocked += 1
		var b := Button.new()
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(1220, 120)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = "%s\n%s" % [r["title"], r["text"]]
		b.add_theme_color_override("font_color", UiTheme.ACCENT if r["unlocked"] else UiTheme.TEXT_DIM)
		b.add_theme_color_override("font_focus_color", UiTheme.TEXT)
		b.focus_entered.connect(_scroll.ensure_control_visible.bind(b))
		_list.add_child(b)
		focusables.append(b)
	_count.text = Localization.t("gallery.count", {"n": unlocked, "total": data.size()})
	focusables.append(_back)
	UiTheme.chain_focus(focusables)
	visible = true
	(focusables[0] as Control).grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()
