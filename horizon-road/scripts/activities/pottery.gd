class_name PotteryActivity
extends MiniGameActivity
## Avanos pottery with Zeynep: throw a pot on the kick wheel. Keep the wheel
## speed in the green band (tap to kick) while holding to pull the clay up.
## Pulling while the wheel is too slow or too fast wobbles the pot. The final
## shape (height, evenness) gives the score.

const TARGET_HEIGHT: float = 1.0
const BAND: Vector2 = Vector2(0.45, 0.75)

var speed: float = 0.0
var height: float = 0.0
var wobble: float = 0.0
var pulling: bool = false
var _t: float = 0.0
var _profile: PackedFloat32Array = PackedFloat32Array()
var _shelf: Node3D


func _ready() -> void:
	activity_id = &"pottery"
	npc_id = &"zeynep"
	prompt_key = "ACT_POTTERY_SIT"
	title_key = "ACT_POTTERY_TITLE"
	help_key = "ACT_POTTERY_HELP"
	base_pay = ECONOMY.pottery_pay
	super._ready()
	var wheel := MeshInstance3D.new()
	wheel.mesh = AnatoliaMeshes.pottery_wheel()
	add_child(wheel)
	_shelf = Node3D.new()
	add_child(_shelf)


func _game_start() -> void:
	speed = 0.3
	height = 0.15
	wobble = 0.0
	_t = 0.0
	pulling = false
	_profile.resize(24)
	for i: int in _profile.size():
		_profile[i] = 0.0


func in_band() -> bool:
	return speed >= BAND.x and speed <= BAND.y


func _game_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"handbrake") or event.is_action_pressed(&"ui_accept"):
		# Space / A: kick the wheel.
		speed = minf(speed + 0.14, 1.0)
		return true
	if event.is_action_pressed(&"interact") or (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		pulling = (event as InputEvent).is_pressed()
		return true
	if event.is_action_released(&"interact"):
		pulling = false
		return true
	if event.is_action_pressed(&"photo_mode") or event.is_action_pressed(&"accelerate"):
		_finish()
		return true
	return false


func _game_process(delta: float) -> void:
	_t += delta
	speed = maxf(speed - delta * 0.12, 0.0)
	if pulling:
		var good: bool = in_band()
		height = minf(height + delta * (0.16 if good else 0.07), 1.25)
		if not good:
			wobble = minf(wobble + delta * 0.35, 1.0)
		var row: int = clampi(int(height / 1.25 * (_profile.size() - 1)), 0, _profile.size() - 1)
		_profile[row] = wobble * sin(_t * 9.0) * 0.5
		if height >= 1.25:
			_finish()


## Score: closeness to the target height, minus the wobble.
func shape_score() -> float:
	var h: float = 1.0 - absf(height - TARGET_HEIGHT) / TARGET_HEIGHT
	return clampf(h * (1.0 - wobble * 0.6), 0.0, 1.0)


func _finish() -> void:
	finish_game(shape_score())


func _on_finished() -> void:
	# The fresh pot appears drying on the bench.
	var b := LowPolyMeshes.Builder.new(700 + GameState.get_counter("zeynep.pottery.count"))
	var h: float = 0.35 + height * 0.25
	var prof := PackedVector2Array([Vector2(0.1, 0), Vector2(0.18, h * 0.25), Vector2(0.2 + wobble * 0.04, h * 0.55), Vector2(0.1, h * 0.85), Vector2(0.12, h), Vector2(0.0, h)])
	AnatoliaMeshes.lathe(b, prof, 10, Vector3.ZERO, func(_t2: float, _s: int) -> Color: return Color(0.62, 0.42, 0.32), 0.0)
	var pot := MeshInstance3D.new()
	pot.mesh = b.commit(LowPolyMeshes.vertex_color_material(0.9))
	pot.position = Vector3(-0.3, 0.8, 0.0)
	for c: Node in _shelf.get_children():
		c.queue_free()
	_shelf.add_child(pot)


func _game_draw(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0.86, 0.78, 0.66))
	var cx: float = r.size.x * 0.42
	var base_y: float = r.size.y - 50.0
	# Wheel head.
	var spin: float = _t * (2.0 + speed * 14.0)
	c.draw_rect(Rect2(Vector2(cx - 130, base_y), Vector2(260, 16)), Color(0.42, 0.36, 0.32))
	for i: int in 6:
		var x: float = cx + cos(spin + i * TAU / 6.0) * 120.0
		if sin(spin + i * TAU / 6.0) > 0.0:
			c.draw_rect(Rect2(Vector2(x - 3, base_y), Vector2(6, 16)), Color(0.3, 0.26, 0.24))
	# The pot, drawn as stacked rings: belly low, narrowing to the neck.
	var px_h: float = height * 240.0
	var rows: int = 30
	for i: int in rows:
		var k: float = float(i) / (rows - 1)
		var y: float = base_y - k * px_h
		var prow: int = clampi(int(k * height / 1.25 * (_profile.size() - 1)), 0, _profile.size() - 1)
		var belly: float = sin(k * PI * 0.85 + 0.25)
		var w: float = 40.0 + 60.0 * belly * (1.0 - height * 0.2) + _profile[prow] * 30.0
		var shade: float = 0.88 + 0.12 * sin(spin * 2.0 + i * 0.7)
		c.draw_rect(Rect2(Vector2(cx - w + _profile[prow] * 18.0, y - px_h / rows - 1.0), Vector2(w * 2.0, px_h / rows + 2.0)), Color(0.72, 0.42, 0.28) * shade)
	if pulling:
		c.draw_circle(Vector2(cx - 70, base_y - px_h * 0.9), 12, Color(0.95, 0.8, 0.7))
		c.draw_circle(Vector2(cx + 70, base_y - px_h * 0.9), 12, Color(0.95, 0.8, 0.7))
	# Speed gauge with the green band.
	var gx: float = r.size.x - 150.0
	var gauge := Rect2(Vector2(gx, 30), Vector2(36, r.size.y - 80))
	c.draw_rect(gauge, Color(0.35, 0.3, 0.28))
	var band := Rect2(Vector2(gx, gauge.end.y - gauge.size.y * BAND.y), Vector2(36, gauge.size.y * (BAND.y - BAND.x)))
	c.draw_rect(band, Color(0.45, 0.75, 0.4))
	var sy: float = gauge.end.y - gauge.size.y * speed
	c.draw_rect(Rect2(Vector2(gx - 8, sy - 3), Vector2(52, 6)), Color(1, 0.95, 0.85))
	# Target height line.
	var ty: float = base_y - TARGET_HEIGHT * 240.0
	c.draw_dashed_line(Vector2(cx - 150, ty), Vector2(cx + 150, ty), Color(0.4, 0.3, 0.25, 0.6), 2.0, 8.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(gx - 40, 22), tr(&"ACT_POTTERY_SPEED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 0.25, 0.2))
