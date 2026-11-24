extends Control
## Ayarlar: Grafik, Ses, Kontroller (tuş atama), Dil. Ana menüden sahne olarak ya da
## duraklatma menüsünden üst katman olarak açılır (embedded = true ise kapanınca kendini siler).

signal closed

var embedded := false
var _store: SettingsStore
var _status: Label
var _waiting_action := ""
var _waiting_kind := ""
var _bind_buttons := {} # "aksiyon|tür" -> Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_store = Game.settings
	UIUtil.full_rect(self)
	UIUtil.background(self)
	var margin := MarginContainer.new()
	UIUtil.full_rect(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)
	col.add_child(UIUtil.title(tr("MENU_SETTINGS"), 44))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)
	tabs.add_child(_graphics_tab())
	tabs.add_child(_audio_tab())
	tabs.add_child(_controls_tab())
	tabs.add_child(_language_tab())
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_theme_color_override("font_color", UITheme.MUTED)
	bottom.add_child(_status)
	bottom.add_child(UIUtil.button(tr("SETTINGS_SAVE"), _save, 180))
	var back := UIUtil.button(tr("MENU_BACK"), _close, 180)
	bottom.add_child(back)
	col.add_child(bottom)
	back.grab_focus.call_deferred()


func _graphics_tab() -> Control:
	var v := _tab_box(tr("SETTINGS_GRAPHICS"))
	var g: Dictionary = _store.data.graphics
	var wm := UIUtil.option([tr("SETTINGS_WINDOWED"), tr("SETTINGS_FULLSCREEN")], 1 if g.fullscreen else 0)
	wm.item_selected.connect(func(i: int) -> void: g.fullscreen = i == 1; _store.apply_graphics(get_tree()))
	v.add_child(UIUtil.row(tr("SETTINGS_WINDOW_MODE"), wm))
	var vs := CheckBox.new()
	vs.button_pressed = g.vsync
	vs.toggled.connect(func(on: bool) -> void: g.vsync = on; _store.apply_graphics(get_tree()))
	v.add_child(UIUtil.row(tr("SETTINGS_VSYNC"), vs))
	var sh := UIUtil.option([tr("SETTINGS_OFF"), tr("SETTINGS_LOW"), tr("SETTINGS_MEDIUM"), tr("SETTINGS_HIGH")], int(g.shadows))
	sh.item_selected.connect(func(i: int) -> void: g.shadows = i; _store.apply_graphics(get_tree()))
	v.add_child(UIUtil.row(tr("SETTINGS_SHADOWS"), sh))
	var aa := UIUtil.option([tr("SETTINGS_OFF"), "2x", "4x"], int(g.msaa))
	aa.item_selected.connect(func(i: int) -> void: g.msaa = i; _store.apply_graphics(get_tree()))
	v.add_child(UIUtil.row(tr("SETTINGS_MSAA"), aa))
	var sc := HSlider.new()
	sc.min_value = 0.5
	sc.max_value = 1.0
	sc.step = 0.05
	sc.value = float(g.scale)
	sc.value_changed.connect(func(x: float) -> void: g.scale = x; _store.apply_graphics(get_tree()))
	v.add_child(UIUtil.row(tr("SETTINGS_SCALE"), sc))
	return v.get_parent()


func _audio_tab() -> Control:
	var v := _tab_box(tr("SETTINGS_AUDIO"))
	var a: Dictionary = _store.data.audio
	for key in ["master", "sfx", "crowd"]:
		var s := HSlider.new()
		s.max_value = 1.0
		s.step = 0.05
		s.value = float(a[key])
		s.value_changed.connect(func(x: float) -> void: a[key] = x; _store.apply_audio())
		v.add_child(UIUtil.row(tr("SETTINGS_" + key.to_upper()), s))
	return v.get_parent()


func _controls_tab() -> Control:
	var v := _tab_box(tr("SETTINGS_CONTROLS"))
	var head := HBoxContainer.new()
	var spacer := Label.new()
	spacer.custom_minimum_size.x = 260
	head.add_child(spacer)
	for t in [tr("SETTINGS_KEYBOARD"), tr("SETTINGS_GAMEPAD")]:
		var l := Label.new()
		l.text = t
		l.custom_minimum_size.x = 230
		l.add_theme_color_override("font_color", UITheme.MUTED)
		head.add_child(l)
	v.add_child(head)
	for action in SettingsStore.REBINDABLE:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var l := Label.new()
		l.text = tr("ACTION_" + action)
		l.custom_minimum_size.x = 260
		h.add_child(l)
		for kind in ["keyboard", "gamepad"]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(220, 40)
			b.pressed.connect(_begin_rebind.bind(action, kind))
			h.add_child(b)
			_bind_buttons[action + "|" + kind] = b
		v.add_child(h)
	v.add_child(UIUtil.button(tr("SETTINGS_RESET_CONTROLS"), func() -> void: _store.reset_bindings(); _refresh_bindings(), 260))
	_refresh_bindings()
	return v.get_parent()


func _language_tab() -> Control:
	var v := _tab_box(tr("SETTINGS_LANGUAGE"))
	var langs := ["tr", "en"]
	var o := UIUtil.option(["Türkçe", "English"], langs.find(_store.data.language))
	o.item_selected.connect(func(i: int) -> void:
		_store.data.language = langs[i]
		_store.apply_language()
		# Metinler yeni dilde yeniden kurulsun
		if not embedded:
			get_tree().reload_current_scene())
	v.add_child(UIUtil.row(tr("SETTINGS_LANGUAGE"), o))
	return v.get_parent()


## Sekme: kaydırılabilir dikey kutu. Sekme adı ScrollContainer'ın adından gelir.
func _tab_box(tab_title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	return v


func _refresh_bindings() -> void:
	for key in _bind_buttons:
		var parts: PackedStringArray = key.split("|")
		_bind_buttons[key].text = SettingsStore.binding_text(parts[0], parts[1])


func _begin_rebind(action: String, kind: String) -> void:
	_waiting_action = action
	_waiting_kind = kind
	_bind_buttons[action + "|" + kind].text = tr("SETTINGS_PRESS_KEY")


func _input(event: InputEvent) -> void:
	if _waiting_action == "":
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_waiting_action = ""
		_refresh_bindings()
		get_viewport().set_input_as_handled()
		return
	var accept := false
	if _waiting_kind == "keyboard":
		accept = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	else:
		accept = (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.6)
	if not accept:
		return
	var ev: InputEvent = SettingsStore.dict_to_event(SettingsStore.event_to_dict(event))
	_store.set_binding(_waiting_action, ev)
	_waiting_action = ""
	_refresh_bindings()
	get_viewport().set_input_as_handled()


func _save() -> void:
	var err := _store.save_to()
	_status.text = tr("SETTINGS_SAVED") if err == OK else str(err)


func _close() -> void:
	if embedded:
		closed.emit()
		queue_free()
	else:
		Game.go_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_action == "" and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
