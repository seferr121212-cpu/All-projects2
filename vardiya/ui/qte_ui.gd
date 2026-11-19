extends Control
## Action-moment overlay. Modes: press (one press in time), mash (N presses;
## becomes hold when the accessibility option is on), hold. Failing never
## ends the game; the story just takes the other branch.

const UiTheme = preload("res://ui/ui_theme.gd")

var _box: VBoxContainer
var _glyph: Label
var _text: Label
var _time_bg: ColorRect
var _time_bar: ColorRect
var _prog_bar: ColorRect
var _result: Label
var _params: Dictionary = {}
var _active := false


func _ready() -> void:
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER)
	_box.offset_left = -450
	_box.offset_right = 450
	_box.offset_top = -160
	_box.offset_bottom = 120
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_box)
	_glyph = UiTheme.make_label("", UiTheme.FONT_TITLE, UiTheme.ACCENT)
	_glyph.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_glyph)
	_text = UiTheme.make_label("", UiTheme.FONT_HEADING)
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_text)
	var bars := Control.new()
	bars.custom_minimum_size = Vector2(900, 30)
	_box.add_child(bars)
	_time_bg = ColorRect.new()
	_time_bg.color = Color(1, 1, 1, 0.15)
	_time_bg.position = Vector2(150, 0)
	_time_bg.size = Vector2(600, 8)
	bars.add_child(_time_bg)
	_time_bar = ColorRect.new()
	_time_bar.color = Color(0.9, 0.3, 0.2)
	_time_bar.position = _time_bg.position
	_time_bar.size = _time_bg.size
	bars.add_child(_time_bar)
	_prog_bar = ColorRect.new()
	_prog_bar.color = UiTheme.ACCENT
	_prog_bar.position = Vector2(150, 16)
	_prog_bar.size = Vector2(0, 8)
	bars.add_child(_prog_bar)
	_result = UiTheme.make_label("", UiTheme.FONT_HEADING)
	_result.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_result.set_anchors_preset(Control.PRESET_CENTER)
	_result.offset_left = -450
	_result.offset_right = 450
	_result.offset_top = 140
	_result.offset_bottom = 220
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.modulate.a = 0.0
	add_child(_result)
	_box.visible = false
	DialogueRunner.qte_started.connect(_on_started)
	DialogueRunner.qte_finished.connect(_on_finished)


func _on_started(_node: Dictionary, params: Dictionary) -> void:
	_params = params
	_active = true
	_box.visible = true
	var action := str(params.get("action", "qte_action"))
	var mode := str(params.get("mode", "press"))
	var how := "qte.press"
	if mode == "mash":
		how = "qte.mash"
	elif mode == "hold":
		how = "qte.hold"
	_glyph.text = InputRouter.prompt(action)
	_text.text = "%s  -  %s" % [Localization.t(str(params.get("prompt", ""))), Localization.t(how)]
	_prog_bar.visible = mode != "press"
	set_process(true)


func _on_finished(success: bool) -> void:
	_active = false
	_box.visible = false
	set_process(false)
	_result.text = Localization.t("qte.success" if success else "qte.fail")
	_result.add_theme_color_override("font_color", UiTheme.ACCENT if success else Color(0.9, 0.35, 0.3))
	var tw := create_tween()
	tw.tween_property(_result, "modulate:a", 1.0, 0.1)
	tw.tween_interval(0.9)
	tw.tween_property(_result, "modulate:a", 0.0, 0.4)


func _process(_delta: float) -> void:
	var q: Dictionary = DialogueRunner.qte
	if q.is_empty():
		return
	var ratio := clampf(float(q["time_left"]) / maxf(0.01, float(q["time_total"])), 0.0, 1.0)
	_time_bar.size.x = _time_bg.size.x * ratio
	_prog_bar.size.x = _time_bg.size.x * clampf(DialogueRunner.qte_progress(), 0.0, 1.0)
	if str(_params.get("mode", "press")) == "mash":
		_glyph.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.03)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	var action := str(_params.get("action", "qte_action"))
	if event.is_action_pressed(action):
		get_viewport().set_input_as_handled()
		if str(_params.get("mode", "")) == "hold":
			DialogueRunner.qte_set_holding(true)
		else:
			DialogueRunner.qte_press()
	elif event.is_action_released(action):
		get_viewport().set_input_as_handled()
		DialogueRunner.qte_set_holding(false)
