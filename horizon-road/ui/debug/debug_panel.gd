class_name DebugPanel
extends CanvasLayer
## F3 panel for tuning atmosphere: scrub time, change time speed, force
## weather, toggle auto weather, switch language, see FPS.

var _panel: PanelContainer
var _fps: Label
var _time_slider: HSlider
var _auto_weather: CheckBox
var _syncing: bool = false


func _ready() -> void:
	layer = 10
	_panel = PanelContainer.new()
	_panel.position = Vector2(20, 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.78)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override(&"panel", style)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(340, 0)
	_panel.add_child(box)

	_fps = Label.new()
	box.add_child(_fps)

	box.add_child(_caption(&"DEBUG_TIME"))
	_time_slider = HSlider.new()
	_time_slider.min_value = 0.0
	_time_slider.max_value = 24.0
	_time_slider.step = 0.05
	_time_slider.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			TimeManager.set_time(v))
	box.add_child(_time_slider)

	box.add_child(_caption(&"DEBUG_TIME_SPEED"))
	var speeds := HBoxContainer.new()
	for s: float in [0.0, 1.0, 10.0, 60.0]:
		var b := Button.new()
		b.text = "II" if s == 0.0 else "%dx" % int(s)
		b.pressed.connect(func() -> void:
			TimeManager.paused = s == 0.0
			TimeManager.time_scale = maxf(s, 1.0))
		speeds.add_child(b)
	box.add_child(speeds)

	box.add_child(_caption(&"DEBUG_WEATHER"))
	var grid := GridContainer.new()
	grid.columns = 3
	for id: StringName in WeatherManager.get_weather_ids():
		var b := Button.new()
		b.text = WeatherManager.profiles[id].name_key
		b.pressed.connect(func() -> void: WeatherManager.set_weather(id, 0.15))
		grid.add_child(b)
	box.add_child(grid)
	_auto_weather = CheckBox.new()
	_auto_weather.text = "DEBUG_AUTO_WEATHER"
	_auto_weather.button_pressed = WeatherManager.auto_change
	_auto_weather.toggled.connect(func(on: bool) -> void: WeatherManager.auto_change = on)
	box.add_child(_auto_weather)

	var lang := Button.new()
	lang.text = "%s: TR / EN" % tr(&"DEBUG_LANGUAGE")
	lang.pressed.connect(Localization.cycle_locale)
	box.add_child(lang)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_panel"):
		visible = not visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if not visible:
		return
	_fps.text = "FPS %d  ·  %s  ·  %s" % [Engine.get_frames_per_second(), TimeManager.get_clock_string(), WeatherManager.target_id]
	_syncing = true
	_time_slider.value = TimeManager.time_of_day
	_syncing = false
	_auto_weather.set_pressed_no_signal(WeatherManager.auto_change)


func _caption(key: StringName) -> Label:
	var l := Label.new()
	l.text = key
	l.add_theme_color_override(&"font_color", Color(0.75, 0.8, 0.85))
	return l
