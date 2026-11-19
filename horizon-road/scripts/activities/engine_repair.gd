class_name EngineRepairActivity
extends MiniGameActivity
## Recep's second job: tune up a neighbour's tractor. He calls out the order
## of four bolts (they light up in turn); repeat it with the arrow keys /
## d-pad or by clicking. Three rounds, each a step longer.

const BOLT_POS: Array[Vector2] = [Vector2(360, 70), Vector2(560, 190), Vector2(360, 310), Vector2(160, 190)]
const BOLT_ACTIONS: Array[StringName] = [&"ui_up", &"ui_right", &"ui_down", &"ui_left"]

var sequence: Array[int] = []
var entered: int = 0
var round_index: int = 0
var correct: int = 0
var total: int = 0
var _show_t: float = 0.0
var _showing: bool = false
var _flash: int = -1
var _flash_t: float = 0.0


func _ready() -> void:
	activity_id = &"engine_repair"
	npc_id = &"recep"
	prompt_key = "ACT_REPAIR_START"
	title_key = "ACT_REPAIR_TITLE"
	help_key = "ACT_REPAIR_HELP"
	base_pay = ECONOMY.repair_pay
	super._ready()
	var tractor := MeshInstance3D.new()
	tractor.mesh = _tractor_mesh()
	add_child(tractor)


func _game_start() -> void:
	round_index = 0
	correct = 0
	total = 0
	_new_round()


func _new_round() -> void:
	sequence.clear()
	for i: int in 3 + round_index:
		sequence.append(_rng.randi() % 4)
	entered = 0
	_showing = true
	_show_t = -0.6


func _game_input(event: InputEvent) -> bool:
	if _showing:
		return false
	var pick: int = -1
	for i: int in 4:
		if event.is_action_pressed(BOLT_ACTIONS[i]):
			pick = i
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m: Vector2 = canvas.get_local_mouse_position()
		for i: int in 4:
			if m.distance_to(BOLT_POS[i]) < 50.0:
				pick = i
	if pick < 0:
		return false
	press_bolt(pick)
	return true


func press_bolt(i: int) -> void:
	_flash = i
	_flash_t = 0.25
	total += 1
	if sequence[entered] == i:
		correct += 1
	entered += 1
	if entered >= sequence.size():
		round_index += 1
		if round_index >= 3:
			finish_game(float(correct) / total)
		else:
			_new_round()


func _game_process(delta: float) -> void:
	_flash_t -= delta
	if _showing:
		_show_t += delta
		var idx: int = int(floor(_show_t / 0.6))
		_flash = sequence[idx] if _show_t >= 0.0 and idx < sequence.size() and fmod(_show_t, 0.6) < 0.4 else -1
		if idx >= sequence.size():
			_showing = false
			_flash = -1
			hint.text = tr(&"ACT_REPAIR_YOUR_TURN")
		else:
			hint.text = tr(&"ACT_REPAIR_WATCH")


func _game_draw(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.3, 0.32, 0.34))
	c.draw_rect(Rect2(Vector2(200, 100), Vector2(320, 180)), Color(0.55, 0.2, 0.15))
	c.draw_rect(Rect2(Vector2(230, 130), Vector2(260, 120)), Color(0.4, 0.4, 0.42))
	for i: int in 4:
		var lit: bool = _flash == i and (_showing or _flash_t > 0.0)
		c.draw_circle(BOLT_POS[i], 38, Color(0.95, 0.75, 0.25) if lit else Color(0.7, 0.7, 0.72))
		c.draw_circle(BOLT_POS[i], 22, Color(0.5, 0.5, 0.52))
		var arrow: String = ["▲", "▶", "▼", "◀"][i]
		c.draw_string(ThemeDB.fallback_font, BOLT_POS[i] + Vector2(-9, 8), arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.15, 0.15, 0.15))
	c.draw_string(ThemeDB.fallback_font, Vector2(20, 360), "%d / 3" % mini(round_index + 1, 3), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.9, 0.85))


static func _tractor_mesh() -> ArrayMesh:
	var b := LowPolyMeshes.Builder.new(710)
	var red := Color(0.72, 0.18, 0.12)
	b.add(LowPolyMeshes._box(Vector3(1.4, 1.0, 2.6)), LowPolyMeshes._at(Vector3(0, 1.1, 0)), red)
	b.add(LowPolyMeshes._box(Vector3(1.0, 0.6, 1.2)), LowPolyMeshes._at(Vector3(0, 1.3, -1.6)), red.darkened(0.1))
	b.add(LowPolyMeshes._box(Vector3(0.5, 0.5, 0.6)), LowPolyMeshes._at(Vector3(0, 1.85, 0.6)), Color(0.2, 0.2, 0.22))
	b.add(LowPolyMeshes._cone(0.08, 0.08, 0.9, 6), LowPolyMeshes._at(Vector3(0.3, 2.0, -1.4)), Color(0.25, 0.25, 0.25))
	for x: float in [-0.85, 0.85]:
		b.add(LowPolyMeshes._cone(0.75, 0.75, 0.4, 12), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x, 0.75, 0.7)), Color(0.12, 0.12, 0.12))
		b.add(LowPolyMeshes._cone(0.42, 0.42, 0.3, 10), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x * 0.85, 0.42, -1.6)), Color(0.12, 0.12, 0.12))
	return b.commit(LowPolyMeshes.vertex_color_material(0.6))
