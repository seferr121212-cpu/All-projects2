class_name Background
extends CanvasLayer
## Katmanlı parallax arka plan (art/bg/*.png). Her katman yatayda döşenir.

const LAYERS := {
	"c1": [["bg/c1_sky.png", 0.02, 0.0], ["bg/c1_sea.png", 0.06, 0.02], ["bg/c1_village.png", 0.18, 0.05], ["bg/c1_fog.png", 0.35, 0.08], ["bg/c1_reeds.png", 0.55, 0.1]],
	"c2": [["bg/c2_back.png", 0.1, 0.05], ["bg/c2_mid.png", 0.3, 0.1], ["bg/c2_fog.png", 0.5, 0.12]],
	"c5": [["bg/c3_sky.png", 0.02, 0.0], ["bg/c3_sea.png", 0.05, 0.02], ["bg/c5_factory.png", 0.12, 0.05], ["bg/c3_fog.png", 0.3, 0.08]],
	"c3": [["bg/c3_sky.png", 0.02, 0.0], ["bg/c3_sea.png", 0.05, 0.02], ["bg/c3_cliff.png", 0.15, 0.06], ["bg/c3_fog.png", 0.3, 0.08]],
}

var flash := 0.0
var drift := 0.0          # menü için otomatik kayma (piksel/sn)
var tower_light := 0.0
var _sprites: Array = []
var _params: Array = []
var _base_cam := Vector2.INF
var _t := 0.0
var _key := ""
var _gull_t := 6.0
var _star_t := 8.0


func _init() -> void:
	layer = -10


func setup(level) -> void:
	setup_key(str(level.bg_key))


func setup_key(key: String) -> void:
	_key = key
	for s in _sprites:
		s.queue_free()
	_sprites.clear()
	_params.clear()
	var list: Array = LAYERS.get(key, LAYERS["c1"])
	for l in list:
		var s := Sprite2D.new()
		s.texture = Art.tex(str(l[0]))
		s.centered = false
		s.scale = Vector2(2, 2)
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, 960, 540)
		add_child(s)
		_sprites.append(s)
		_params.append([float(l[1]), float(l[2])])


func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport()
	var cam_pos := Vector2(_t * drift, 0.0)
	if drift == 0.0:
		var ct := vp.get_canvas_transform()
		cam_pos = ct.affine_inverse() * Vector2.ZERO
	if _base_cam == Vector2.INF:
		_base_cam = cam_pos
	flash = move_toward(flash, 0.0, delta * 2.5)
	if _key == "c1" and drift == 0.0:
		_gull_t -= delta
		if _gull_t <= 0.0:
			_gull_t = randf_range(10.0, 22.0)
			_gulls()
	# açık gökte ara sıra kayan yıldız (köy ve menü)
	if _key in ["c1", "menu", "prologue"]:
		_star_t -= delta
		if _star_t <= 0.0:
			_star_t = randf_range(18.0, 40.0)
			_shooting_star()
	var bright := 1.0 + flash * 1.5
	for i in _sprites.size():
		var s: Sprite2D = _sprites[i]
		var p: Array = _params[i]
		s.region_rect = Rect2(cam_pos.x * float(p[0]) / 2.0, 0, 960, 540)
		s.position.y = clampf(-(cam_pos.y - _base_cam.y) * float(p[1]), -260.0, 260.0)
		s.modulate = Color(bright, bright, bright * 1.05)


## Gökyüzünde çatallı şimşek (sky ile uzak katman arasında).
func bolt() -> void:
	var l := Line2D.new()
	var x := randf_range(200.0, 1700.0)
	var y := 0.0
	var pts := PackedVector2Array([Vector2(x, y)])
	while y < randf_range(420.0, 620.0):
		y += randf_range(30.0, 70.0)
		x += randf_range(-50.0, 50.0)
		pts.append(Vector2(x, y))
	l.points = pts
	l.width = 4.0
	l.default_color = Color(0.85, 0.9, 1.0, 1.0)
	l.material = Art.glow_material()
	add_child(l)
	if _sprites.size() > 1:
		move_child(l, 1)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.08)
	tw.tween_callback(l.queue_free)


## Uzaktan geçen martı sürüsü.
func _gulls() -> void:
	var n := randi_range(2, 4)
	var y0 := randf_range(160.0, 320.0)
	var dir := 1.0 if randf() < 0.5 else -1.0
	for i in n:
		var g := AnimatedSprite2D.new()
		g.sprite_frames = Art.frames("fx/gull.png", 15, 7, {"fly": [0, 4, 7, true]})
		g.play("fly")
		g.frame = i % 4
		g.scale = Vector2(2, 2)
		g.flip_h = dir < 0.0
		g.modulate = Color(0.75, 0.8, 0.9, 0.85)
		var sx := -60.0 if dir > 0.0 else 1980.0
		g.position = Vector2(sx - dir * i * 50.0, y0 + i * 18.0 + randf_range(-8, 8))
		add_child(g)
		if _sprites.size() > 2:
			move_child(g, 2)
		var tw := create_tween()
		tw.tween_property(g, "position:x", g.position.x + dir * 2200.0, randf_range(14.0, 20.0))
		tw.parallel().tween_property(g, "position:y", g.position.y - 60.0, 16.0)
		tw.tween_callback(g.queue_free)


func _shooting_star() -> void:
	var l := Line2D.new()
	l.width = 2.0
	l.default_color = Color(0.9, 0.92, 1.0, 0.9)
	l.gradient = Gradient.new()
	l.gradient.set_color(0, Color(1, 1, 1, 0.0))
	l.gradient.set_color(1, Color(1, 1, 1, 0.9))
	var start := Vector2(randf_range(300.0, 1600.0), randf_range(40.0, 220.0))
	var dir := Vector2(randf_range(-1.0, 1.0), 0.35).normalized()
	l.points = PackedVector2Array([start, start + dir * 4.0])
	l.material = Art.glow_material()
	add_child(l)
	if _sprites.size() > 1:
		move_child(l, 1)
	var tw := create_tween()
	tw.tween_method(func(v: float): l.points = PackedVector2Array([start + dir * maxf(0.0, v - 120.0), start + dir * v]), 0.0, 420.0, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.tween_callback(l.queue_free)
