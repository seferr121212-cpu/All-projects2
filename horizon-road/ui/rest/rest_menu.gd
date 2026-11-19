class_name RestMenu
extends CanvasLayer
## Rest in the camper bed: sleep until morning or nap a few hours. Fades to
## black, moves time forward, lets the weather change, then autosaves.

signal rested(hours: float)

const PAPER := Color(0.97, 0.94, 0.88, 0.97)
const INK := Color(0.24, 0.19, 0.14)

var _panel := PanelContainer.new()
var _fade := ColorRect.new()
var _busy: bool = false


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


## Hours from `now` until the next occurrence of `target` (always > 0).
static func hours_until(now: float, target: float) -> float:
	var h: float = fposmod(target - now, 24.0)
	return h if h > 0.01 else 24.0


func open() -> void:
	if not GameState.is_gameplay():
		return
	GameState.set_context(GameState.Context.MENU)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel.visible = true


func close() -> void:
	_panel.visible = false
	GameState.set_context(GameState.Context.GAMEPLAY)
	if not DevCli.is_requested():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()


func rest(until_morning: bool) -> void:
	if _busy:
		return
	_busy = true
	_panel.visible = false
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.8)
	await tween.finished
	var hours: float = hours_until(TimeManager.time_of_day, GameState.ECONOMY.wake_hour) if until_morning else GameState.ECONOMY.nap_hours
	apply_rest(hours)
	await get_tree().create_timer(0.6).timeout
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, 1.0)
	GameState.notify((tr(&"REST_GOOD_MORNING") % GameState.get_display_name()) if until_morning else tr(&"REST_RESTED"))
	_busy = false
	close()


## The state change of resting, separate from the fade so tests can call it.
static func apply_rest(hours: float) -> void:
	TimeManager.advance_hours(hours)
	if hours >= 6.0:
		# A night passes: new day, new weather.
		WeatherManager.set_weather(WeatherManager._pick_weighted(), 0.0)
	SaveManager.autosave()


func _build() -> void:
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	style.border_color = Color(0.55, 0.38, 0.22)
	style.set_border_width_all(3)
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	var title := Label.new()
	title.text = "REST_TITLE"
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", INK)
	col.add_child(title)
	for spec: Array in [["REST_UNTIL_MORNING", true], ["REST_NAP", false]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(380, 44)
		var morning: bool = spec[1]
		b.pressed.connect(func() -> void: rest(morning))
		col.add_child(b)
	var cancel := Button.new()
	cancel.text = "UI_CANCEL"
	cancel.pressed.connect(close)
	col.add_child(cancel)
	_panel.add_child(col)
	add_child(_panel)
