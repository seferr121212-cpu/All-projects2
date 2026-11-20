extends PanelContainer
## Settings list. Each row cycles through values with A / Enter / click,
## or with left/right. Changes apply and persist immediately.

signal closed

const UiTheme = preload("res://ui/ui_theme.gd")
const VOLUME_STEPS := [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]

var rows: Array = [
	{"key": "settings.language", "setting": "locale", "values": ["tr", "en"], "labels": ["lang.tr", "lang.en"]},
	{"key": "settings.choice_timer", "setting": "choice_timer_scale", "values": [1.0, 1.5, 2.0],
		"labels": ["settings.timer_normal", "settings.timer_slow", "settings.timer_slowest"]},
	{"key": "settings.qte_easy", "setting": "qte_easy", "values": [false, true], "labels": ["settings.off", "settings.on"]},
	{"key": "settings.qte_hold", "setting": "qte_hold_alternative", "values": [false, true],
		"labels": ["settings.off", "settings.on"]},
	{"key": "settings.subtitle_size", "setting": "subtitle_scale", "values": [1.0, 1.25, 1.5],
		"labels": ["settings.size_normal", "settings.size_large", "settings.size_xlarge"]},
	{"key": "settings.quality", "setting": "visual_quality", "values": ["high", "low"],
		"labels": ["settings.quality_high", "settings.quality_low"]},
	{"key": "settings.render_scale", "setting": "render_scale", "values": [1.0, 0.85, 0.7], "labels": []},
	{"key": "settings.auto_quality", "setting": "auto_quality", "values": [true, false],
		"labels": ["settings.on", "settings.off"]},
	{"key": "settings.music", "setting": "music_volume", "values": VOLUME_STEPS, "labels": []},
	{"key": "settings.sfx", "setting": "sfx_volume", "values": VOLUME_STEPS, "labels": []},
]

var _buttons: Array[Button] = []
var _back: Button


func _ready() -> void:
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(UiTheme.make_label("settings.title", UiTheme.FONT_HEADING))
	for i in rows.size():
		var b := UiTheme.make_button("", 900)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.pressed.connect(_cycle.bind(i, 1))
		b.gui_input.connect(_on_row_input.bind(i))
		box.add_child(b)
		_buttons.append(b)
	_back = UiTheme.make_button("menu.back", 900)
	_back.pressed.connect(_close)
	box.add_child(_back)
	var all: Array = []
	all.append_array(_buttons)
	all.append(_back)
	UiTheme.chain_focus(all)
	Localization.locale_changed.connect(_on_locale_changed)
	_refresh()


func _on_locale_changed(_locale: String) -> void:
	_refresh()


func open() -> void:
	visible = true
	_refresh()
	_buttons[0].grab_focus()


func _index_of(row: Dictionary) -> int:
	var current: Variant = SaveSystem.settings.get(row["setting"])
	var values: Array = row["values"]
	for i in values.size():
		var v: Variant = values[i]
		if typeof(v) == TYPE_FLOAT and typeof(current) in [TYPE_FLOAT, TYPE_INT]:
			if is_equal_approx(float(v), float(current)):
				return i
		elif typeof(v) == typeof(current) and v == current:
			return i
	return 0


func _refresh() -> void:
	for i in rows.size():
		var row: Dictionary = rows[i]
		var idx := _index_of(row)
		var value_text: String
		if (row["labels"] as Array).is_empty():
			value_text = Localization.t("settings.percent", {"v": int(round(float(row["values"][idx]) * 100.0))})
		else:
			value_text = Localization.t(row["labels"][idx])
		_buttons[i].text = "%s    < %s >" % [Localization.t(row["key"]), value_text]


func _cycle(i: int, dir: int) -> void:
	var row: Dictionary = rows[i]
	var values: Array = row["values"]
	var idx := (_index_of(row) + dir + values.size()) % values.size()
	SaveSystem.set_setting(row["setting"], values[idx])
	AudioBus.play("ui/move")
	_refresh()


func _on_row_input(event: InputEvent, i: int) -> void:
	if event.is_action_pressed("ui_left"):
		_cycle(i, -1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		_cycle(i, 1)
		accept_event()


func _close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
