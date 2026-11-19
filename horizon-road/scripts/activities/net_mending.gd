class_name NetMendingActivity
extends MiniGameActivity
## Hasan's second job: mend torn net on the quay. Torn meshes open up one
## after another; move the shuttle (arrows / d-pad / mouse) and tie them off
## with E / click. Holes left too long tear wider and are worth less.

const COLS: int = 10
const ROWS: int = 6
const DURATION: float = 40.0

var holes: Dictionary = {}  # Vector2i -> age
var cursor := Vector2i(5, 3)
var mended: float = 0.0
var opened: int = 0
var time_left: float = DURATION
var _spawn_t: float = 0.0


func _ready() -> void:
	activity_id = &"net_mend"
	npc_id = &"hasan"
	prompt_key = "ACT_MEND_START"
	title_key = "ACT_MEND_TITLE"
	help_key = "ACT_MEND_HELP"
	base_pay = ECONOMY.mending_pay
	super._ready()
	var pile := MeshInstance3D.new()
	pile.mesh = LowPolyMeshes.net_pile()
	add_child(pile)


func _game_start() -> void:
	holes.clear()
	mended = 0.0
	opened = 0
	time_left = DURATION
	_spawn_t = 0.5


func _cell_rect(cell: Vector2i) -> Rect2:
	var w: float = canvas.size.x / COLS
	var h: float = canvas.size.y / ROWS
	return Rect2(Vector2(cell.x * w, cell.y * h), Vector2(w, h))


func _game_input(event: InputEvent) -> bool:
	var moved: bool = false
	for pair: Array in [[&"ui_left", Vector2i(-1, 0)], [&"ui_right", Vector2i(1, 0)], [&"ui_up", Vector2i(0, -1)], [&"ui_down", Vector2i(0, 1)]]:
		if event.is_action_pressed(pair[0]):
			cursor = (cursor + pair[1]).clamp(Vector2i.ZERO, Vector2i(COLS - 1, ROWS - 1))
			moved = true
	if moved:
		return true
	if event is InputEventMouseMotion:
		var m: Vector2 = canvas.get_local_mouse_position()
		cursor = Vector2i(int(m.x / (canvas.size.x / COLS)), int(m.y / (canvas.size.y / ROWS))).clamp(Vector2i.ZERO, Vector2i(COLS - 1, ROWS - 1))
		return false
	if is_press(event):
		mend(cursor)
		return true
	return false


func mend(cell: Vector2i) -> void:
	if holes.has(cell):
		var age: float = holes[cell]
		mended += clampf(1.2 - age / 8.0, 0.4, 1.0)
		holes.erase(cell)


func _game_process(delta: float) -> void:
	time_left -= delta
	for k: Vector2i in holes.keys():
		holes[k] = float(holes[k]) + delta
	_spawn_t -= delta
	if _spawn_t <= 0.0 and time_left > 2.0:
		_spawn_t = _rng.randf_range(0.8, 1.6)
		var cell := Vector2i(_rng.randi() % COLS, _rng.randi() % ROWS)
		if not holes.has(cell):
			holes[cell] = 0.0
			opened += 1
	if time_left <= 0.0:
		finish_game(mended / maxf(opened, 1))


func _game_draw(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.62, 0.55, 0.45))
	var w: float = c.size.x / COLS
	var h: float = c.size.y / ROWS
	var twine := Color(0.2, 0.42, 0.55)
	for x: int in COLS + 1:
		c.draw_line(Vector2(x * w, 0), Vector2(x * w, c.size.y), twine, 2.0)
	for y: int in ROWS + 1:
		c.draw_line(Vector2(0, y * h), Vector2(c.size.x, y * h), twine, 2.0)
	for k: Vector2i in holes:
		var r: Rect2 = _cell_rect(k)
		var grow: float = clampf(float(holes[k]) / 8.0, 0.0, 1.0)
		c.draw_rect(r.grow(-2.0), Color(0.62, 0.55, 0.45))
		c.draw_circle(r.get_center(), 10.0 + grow * 16.0, Color(0.3, 0.24, 0.18))
	var cr: Rect2 = _cell_rect(cursor)
	c.draw_rect(cr.grow(-3.0), Color(1.0, 0.9, 0.5), false, 4.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(10, 24), "%d s" % ceili(maxf(time_left, 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1))
