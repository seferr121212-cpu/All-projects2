class_name Mover
extends AnimatableBody2D
## Hareket eden katı: kapı, köprü, sal, kapak. activate() ile hedefe gider.
## loop_travel verilirse sonra gidip gelir (sal gibi).

var id := ""
var size := Vector2(40, 200)
var travel := Vector2(0, -220)
var duration := 1.6
var loop_travel := Vector2.ZERO
var loop_duration := 6.0
var color := Color(1, 1, 1)
var tex_path := "tiles/wood_wall.png"
var activated := false
var _origin := Vector2.ZERO


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = size / 2.0
	add_child(cs)
	add_child(Art.tiled_rect(tex_path, size.x, size.y, color))
	var occ := LightOccluder2D.new()
	var op := OccluderPolygon2D.new()
	op.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	occ.occluder = op
	add_child(occ)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y), Vector2.ZERO])
	edge.width = 2.0
	edge.default_color = Color(0.03, 0.035, 0.05)
	add_child(edge)
	_origin = position
	if id != "" and GameState.flag("mv_" + id):
		position = _origin + travel
		activated = true
		_start_loop()


func activate() -> void:
	if activated:
		return
	activated = true
	if id != "":
		GameState.set_flag("mv_" + id)
	AudioManager.play_sfx("door", -4.0)
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "position", _origin + travel, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_start_loop)


func _start_loop() -> void:
	if loop_travel == Vector2.ZERO:
		return
	var a := _origin + travel
	var tw := create_tween().set_loops()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_interval(1.2)
	tw.tween_property(self, "position", a + loop_travel, loop_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(self, "position", a, loop_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
