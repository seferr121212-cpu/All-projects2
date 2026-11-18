class_name AmbientLight
extends Node2D
## Sabit ortam ışığı: tekne feneri, pencere, uzaktaki Yusuf'un ışığı.
## safe=true ise oyun kuralları açısından da ışıktır (Yankılar donar).

var light_radius := 260.0
var intensity := 0.6
var safe := false
var flicker := 0.0
var on := true
var _t := 0.0
var color := Color(1.0, 0.72, 0.42)
var _pl: PointLight2D


func _ready() -> void:
	LightSystem.register(self)
	_pl = Art.light(light_radius * 1.2, color, 0.6 + intensity * 0.9, safe)
	add_child(_pl)


func _exit_tree() -> void:
	LightSystem.unregister(self)


func _process(delta: float) -> void:
	_t += delta
	if _pl:
		_pl.visible = on
		var f := 1.0 - flicker * (0.5 + 0.5 * sin(_t * 17.0) * sin(_t * 5.3))
		_pl.energy = (0.6 + intensity * 0.9) * f


func is_light_on() -> bool:
	return on


func is_static_light() -> bool:
	return safe


func get_light_circles() -> Array:
	var f := 1.0 - flicker * (0.5 + 0.5 * sin(_t * 17.0) * sin(_t * 5.3))
	var w := intensity * f
	if not safe:
		w = minf(w, 0.29)
	return [Vector4(global_position.x, global_position.y, light_radius * (0.9 + 0.1 * f), w)]
