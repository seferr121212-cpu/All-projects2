class_name Crate
extends CharacterBody2D
## İtilebilir sandık. Platform kurmak için kullanılır.

var id := ""
var _push := 0.0


func _ready() -> void:
	add_to_group("crate")
	collision_layer = 1
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(60, 60)
	cs.shape = r
	cs.position = Vector2(0, -30)
	add_child(cs)
	add_child(Art.sprite("props/crate.png"))
	var occ := LightOccluder2D.new()
	var op := OccluderPolygon2D.new()
	op.polygon = PackedVector2Array([Vector2(-28, -2), Vector2(28, -2), Vector2(28, -58), Vector2(-28, -58)])
	occ.occluder = op
	add_child(occ)
	if id != "":
		var saved = GameState.get_flag_value("crate_" + id)
		if saved is Array and saved.size() == 2:
			position = Vector2(float(saved[0]), float(saved[1]))


func push(v: float) -> void:
	_push = v


var _scrape_t := 0.0


func _physics_process(delta: float) -> void:
	velocity.x = _push
	# sürtünme sesi (itilirken aralıklı)
	_scrape_t -= delta
	if absf(_push) > 1.0 and is_on_floor() and _scrape_t <= 0.0:
		_scrape_t = 0.3
		AudioManager.play_at("scrape", global_position, -10.0, randf_range(0.85, 1.1))
	_push = 0.0
	if not is_on_floor():
		velocity.y = minf(velocity.y + 1400.0 * delta, 1200.0)
	else:
		velocity.y = 0.0
	move_and_slide()


func save_state() -> void:
	if id != "":
		GameState.set_flag("crate_" + id, [position.x, position.y])
