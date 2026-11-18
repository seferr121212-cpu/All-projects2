class_name RedText
extends Node2D
## Sadece kırmızı camlı lamba ışığında görünen duvar yazısı.

signal revealed

var key := ""
var shown := false
var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.text = Loc.t(key)
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.15))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(520, 160)
	_label.position = Vector2(-260, -80)
	_label.modulate.a = 0.0
	add_child(_label)
	Loc.language_changed.connect(_relabel)


func _relabel() -> void:
	_label.text = Loc.t(key)


func _process(delta: float) -> void:
	var lamp = LightSystem.lamp
	var vis := false
	if lamp and is_instance_valid(lamp) and lamp.red and lamp.is_light_on():
		var d: float = lamp.global_position.distance_to(global_position)
		vis = d < lamp.radius() + 80.0 or lamp.lights_extra(global_position, 40.0)
	_label.modulate.a = move_toward(_label.modulate.a, 1.0 if vis else 0.0, delta * 2.5)
	if vis and _label.modulate.a > 0.6 and not shown:
		shown = true
		revealed.emit()
