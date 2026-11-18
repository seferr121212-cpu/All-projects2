class_name Crumble
extends StaticBody2D
## Çürük tahta: üstüne basıldıktan 0.6 sn sonra çöker, 4 sn sonra geri gelir.

var width := 140.0
var _t := -1.0
var _fallen := false
var _shape: CollisionShape2D
var _poly: Polygon2D


func _ready() -> void:
	collision_layer = 1
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width, 14)
	_shape.shape = r
	_shape.position = Vector2(width / 2.0, 7)
	add_child(_shape)
	_poly = Art.tiled_rect("tiles/planks.png", width, 16, Color(0.85, 0.75, 0.7))
	add_child(_poly)
	for cx in [width * 0.3, width * 0.7]:
		var crack := Line2D.new()
		crack.points = PackedVector2Array([Vector2(cx, 0), Vector2(cx + 4, 7), Vector2(cx - 2, 16)])
		crack.width = 2.0
		crack.default_color = Color(0.02, 0.02, 0.03)
		_poly.add_child(crack)
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var acs := CollisionShape2D.new()
	var ar := RectangleShape2D.new()
	ar.size = Vector2(width - 8, 10)
	acs.shape = ar
	acs.position = Vector2(width / 2.0, -5)
	a.add_child(acs)
	add_child(a)
	a.body_entered.connect(_on_step)


func _on_step(b: Node) -> void:
	if b is Kerem and _t < 0.0 and not _fallen:
		_t = 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if not _fallen:
		_poly.position = Vector2(randf_range(-2, 2), randf_range(-1, 1))
		if _t > 0.8:
			_fallen = true
			_shape.set_deferred("disabled", true)
			AudioManager.play_sfx("crumble", -4.0)
			var tw := create_tween()
			tw.tween_property(_poly, "position", Vector2(0, 300), 0.8)
			tw.parallel().tween_property(_poly, "modulate:a", 0.0, 0.8)
	elif _t > 4.6:
		_fallen = false
		_t = -1.0
		_shape.set_deferred("disabled", false)
		_poly.position = Vector2.ZERO
		_poly.modulate.a = 1.0
