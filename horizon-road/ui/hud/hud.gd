class_name Hud
extends CanvasLayer
## Minimal, translucent HUD: clock + day + weather in a corner, and a
## context hint at the bottom. Everything else stays out of the way.

@export var travel_path: NodePath

var _travel: TravelController
var _clock: Label
var _info: Label
var _hint: Label
var _controls: Label
var _controls_timer: float = 14.0


func _ready() -> void:
	_travel = get_node_or_null(travel_path)
	var corner := VBoxContainer.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 28)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.alignment = BoxContainer.ALIGNMENT_END
	add_child(corner)
	_clock = _label(34, HORIZONTAL_ALIGNMENT_RIGHT)
	_info = _label(17, HORIZONTAL_ALIGNMENT_RIGHT)
	corner.add_child(_clock)
	corner.add_child(_info)

	_hint = _label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 70)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_hint)

	_controls = _label(15, HORIZONTAL_ALIGNMENT_CENTER)
	_controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 28)
	_controls.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_controls)


func _process(delta: float) -> void:
	_clock.text = TimeManager.get_clock_string()
	_info.text = "%s  ·  %s  ·  %s" % [
		tr(&"UI_DAY") % TimeManager.day,
		tr(StringName(TimeManager.get_phase_key())),
		tr(StringName(WeatherManager.current.name_key)),
	]
	_hint.text = _context_hint()
	_controls_timer -= delta
	_controls.text = tr(&"UI_CONTROLS_HINT")
	_controls.modulate.a = clampf(_controls_timer / 3.0, 0.0, 0.8)


func _context_hint() -> String:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not DevCli.is_requested():
		return tr(&"UI_CAPTURE_MOUSE")
	if _travel == null:
		return ""
	if GameState.player_mode == GameState.PlayerMode.DRIVING:
		return tr(&"UI_EXIT_VEHICLE") if _travel.camper.is_stopped() else ""
	return tr(&"UI_ENTER_VEHICLE") if _travel.can_enter_vehicle() else ""


func _label(font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.92))
	l.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override(&"shadow_offset_x", 0)
	l.add_theme_constant_override(&"shadow_offset_y", 2)
	l.add_theme_constant_override(&"shadow_outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
