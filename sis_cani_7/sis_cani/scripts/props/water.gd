class_name Water
extends Node2D
## Karanlık su. İçine düşen yakalanır. rise() ile yükselir.

var width := 2000.0
var depth := 600.0
var _poly: Polygon2D
var _zone: Zone


func _ready() -> void:
	_poly = Polygon2D.new()
	_poly.polygon = PackedVector2Array([Vector2.ZERO, Vector2(width, 0), Vector2(width, depth), Vector2(0, depth)])
	_poly.color = Color(1, 1, 1, 1)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	_poly.material = m
	var lv = GameState.level
	if lv != null and lv.weather_rain:
		m.set_shader_parameter("rain", 1.0)
	var surf := Line2D.new()
	surf.points = PackedVector2Array([Vector2.ZERO, Vector2(width, 0)])
	surf.width = 3.0
	surf.default_color = Color(0.35, 0.45, 0.55, 0.6)
	surf.z_index = 3
	add_child(surf)
	_poly.z_index = 3
	add_child(_poly)
	_zone = Zone.new()
	_zone.mode = "kill"
	_zone.size = Vector2(width, depth)
	_zone.position = Vector2(0, 18)
	add_child(_zone)
	var sz := Zone.new()
	sz.mode = "trigger"
	sz.once = false
	sz.size = Vector2(width, 30)
	sz.position = Vector2(0, -6)
	sz.collision_mask = 2
	add_child(sz)
	sz.body_entered.connect(_splash)


func _splash(b) -> void:
	if not b is Node2D:
		return
	var pos: Vector2 = Vector2(b.global_position.x, global_position.y)
	AudioManager.play_at("splash", pos, 0.0, randf_range(0.8, 1.0))
	var s := CPUParticles2D.new()
	s.one_shot = true
	s.explosiveness = 0.95
	s.amount = 30
	s.lifetime = 0.9
	s.direction = Vector2(0, -1)
	s.spread = 35.0
	s.initial_velocity_min = 180.0
	s.initial_velocity_max = 420.0
	s.gravity = Vector2(0, 1100)
	s.scale_amount_min = 2.0
	s.scale_amount_max = 4.0
	s.color = Color(0.6, 0.7, 0.8, 0.8)
	s.z_index = 4
	s.global_position = pos
	get_parent().add_child(s)
	s.emitting = true
	get_tree().create_timer(1.3).timeout.connect(s.queue_free)


func rise(amount: float, dur: float) -> void:
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "position:y", position.y - amount, dur).set_trans(Tween.TRANS_SINE)
