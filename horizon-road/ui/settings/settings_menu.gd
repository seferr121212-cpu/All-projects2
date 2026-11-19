class_name SettingsMenu
extends CanvasLayer
## Settings: graphics, audio, gameplay and key bindings. Opened from the
## title screen and the pause menu; every change applies immediately.

signal closed

var _tabs := TabContainer.new()
var _rebinding: StringName = &""
var _rebind_buttons: Dictionary = {}
var _day_label: Label


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var p := PanelContainer.new()
	UIStyle.panel(p)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 360
	p.offset_right = -360
	p.offset_top = 110
	p.offset_bottom = -110
	add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	p.add_child(col)
	col.add_child(UIStyle.label("SETTINGS_TITLE", 30))
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIStyle.tabs(_tabs)
	_tabs.add_theme_font_size_override(&"font_size", 19)
	col.add_child(_tabs)
	_build_graphics()
	_build_audio()
	_build_gameplay()
	_build_controls()
	col.add_child(UIStyle.make_button("UI_CLOSE", close))


func open() -> void:
	_tabs.set_tab_title(0, tr(&"SETTINGS_GRAPHICS"))
	_tabs.set_tab_title(1, tr(&"SETTINGS_AUDIO"))
	_tabs.set_tab_title(2, tr(&"SETTINGS_GAMEPLAY"))
	_tabs.set_tab_title(3, tr(&"SETTINGS_CONTROLS"))
	_refresh_keys()
	visible = true


func close() -> void:
	_rebinding = &""
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _rebinding != &"" and event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if k.physical_keycode != KEY_ESCAPE:
			Settings.set_key(_rebinding, k.physical_keycode)
		_rebinding = &""
		_refresh_keys()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()


func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", 14)
	scroll.add_child(v)
	_tabs.add_child(scroll)
	return v


func _row(parent: Control, key: String, control: Control) -> void:
	var h := HBoxContainer.new()
	var l := UIStyle.label(key, 18)
	l.custom_minimum_size = Vector2(340, 0)
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	parent.add_child(h)


func _option(items: Array, selected: int, on_select: Callable) -> OptionButton:
	var o := OptionButton.new()
	for it: String in items:
		o.add_item(it)
	o.selected = selected
	o.item_selected.connect(on_select)
	UIStyle.option(o)
	return o


func _check(on: bool, on_toggle: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.button_pressed = on
	c.toggled.connect(on_toggle)
	return c


func _slider(value: float, lo: float, hi: float, step: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(300, 28)
	s.value_changed.connect(on_change)
	return s


func _build_graphics() -> void:
	var v := _page("Graphics")
	_row(v, "SETTINGS_QUALITY", _option(Settings.QUALITY_KEYS.map(func(k: String) -> String: return tr(StringName(k))),
			int(Settings.get_value("graphics", "quality")), func(i: int) -> void: Settings.set_value("graphics", "quality", i)))
	_row(v, "SETTINGS_FULLSCREEN", _check(Settings.get_value("graphics", "fullscreen"), func(on: bool) -> void: Settings.set_value("graphics", "fullscreen", on)))
	_row(v, "SETTINGS_VSYNC", _check(Settings.get_value("graphics", "vsync"), func(on: bool) -> void: Settings.set_value("graphics", "vsync", on)))
	var caps: Array[int] = [0, 30, 60, 120]
	_row(v, "SETTINGS_MAX_FPS", _option([tr(&"SETTINGS_UNLIMITED"), "30", "60", "120"], maxi(caps.find(int(Settings.get_value("graphics", "max_fps"))), 0),
			func(i: int) -> void: Settings.set_value("graphics", "max_fps", caps[i])))
	var note := UIStyle.label("SETTINGS_QUALITY_NOTE", 15, UIStyle.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)


func _build_audio() -> void:
	var v := _page("Audio")
	for bus: String in ["Master", "Music", "SFX", "Ambience"]:
		_row(v, "SETTINGS_VOL_" + bus.to_upper(), _slider(float(Settings.get_value("audio", bus)), 0.0, 1.0, 0.05,
				func(x: float) -> void: Settings.set_value("audio", bus, x)))


func _build_gameplay() -> void:
	var v := _page("Gameplay")
	var langs: Array[String] = ["tr", "en"]
	_row(v, "SETTINGS_LANGUAGE", _option(["Türkçe", "English"], maxi(langs.find(Localization.get_locale()), 0),
			func(i: int) -> void:
				Localization.set_locale(langs[i])
				open()))
	_day_label = UIStyle.label("", 16, UIStyle.INK_SOFT)
	var day_box := HBoxContainer.new()
	var slider := _slider(float(Settings.get_value("gameplay", "day_length")), 6.0, 40.0, 1.0, func(x: float) -> void:
		Settings.set_value("gameplay", "day_length", x)
		_day_label.text = tr(&"SETTINGS_MINUTES") % x)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_box.add_child(slider)
	_day_label.text = tr(&"SETTINGS_MINUTES") % float(Settings.get_value("gameplay", "day_length"))
	day_box.add_child(_day_label)
	_row(v, "SETTINGS_DAY_LENGTH", day_box)
	_row(v, "SETTINGS_MOUSE", _slider(float(Settings.get_value("gameplay", "mouse_sensitivity")), 0.3, 2.5, 0.05,
			func(x: float) -> void: Settings.set_value("gameplay", "mouse_sensitivity", x)))
	_row(v, "SETTINGS_INVERT_Y", _check(Settings.get_value("gameplay", "invert_y"), func(on: bool) -> void: Settings.set_value("gameplay", "invert_y", on)))


func _build_controls() -> void:
	var v := _page("Controls")
	var hint := UIStyle.label("SETTINGS_REBIND_HINT", 15, UIStyle.INK_SOFT)
	v.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 24)
	grid.add_theme_constant_override(&"v_separation", 6)
	for action: StringName in Settings.REBINDABLE:
		var l := UIStyle.label("ACTION_" + String(action).to_upper(), 17)
		l.custom_minimum_size = Vector2(320, 0)
		grid.add_child(l)
		var b := Button.new()
		UIStyle.button(b, 17)
		b.custom_minimum_size = Vector2(180, 0)
		b.pressed.connect(func() -> void:
			_rebinding = action
			b.text = tr(&"SETTINGS_PRESS_KEY"))
		grid.add_child(b)
		_rebind_buttons[action] = b
	v.add_child(grid)
	v.add_child(UIStyle.make_button("SETTINGS_RESET_KEYS", func() -> void:
		Settings.reset_controls()
		_refresh_keys(), 17))


func _refresh_keys() -> void:
	for action: StringName in _rebind_buttons:
		(_rebind_buttons[action] as Button).text = Settings.key_label(action)
