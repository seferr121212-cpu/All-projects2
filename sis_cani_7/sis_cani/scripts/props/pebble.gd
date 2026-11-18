class_name Pebble
extends Node2D
## Atılan çakıl taşı. Yay çizerek uçar, düştüğü yerde ses çıkarır ve Yankıları oraya çeker.

const GRAV := 1300.0
var vel := Vector2.ZERO
var _life := 3.0
var _spr: Sprite2D


func _ready() -> void:
	z_index = 2
	_spr = Art.sprite_c("props/pebble.png")
	add_child(_spr)


func _physics_process(delta: float) -> void:
	_life -= delta
	vel.y = minf(vel.y + GRAV * delta, 1400.0)
	var from := global_position
	var to := from + vel * delta
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	_spr.rotation += delta * 12.0 * signf(vel.x)
	if not hit.is_empty():
		_land(hit["position"])
		return
	global_position = to
	if _life <= 0.0:
		_land(global_position)


func _land(pos: Vector2) -> void:
	set_physics_process(false)
	global_position = pos
	AudioManager.play_at("click", pos, -4.0, 0.55)
	AudioManager.play_at("step", pos, -2.0, 1.4)
	for e in get_tree().get_nodes_in_group("echo"):
		if e.has_method("on_bell") and e.global_position.distance_to(pos) < 700.0:
			e.on_bell(pos, 0.0)
	if GameState.level and GameState.level.has_method("dust"):
		GameState.level.dust(pos)
	# yere düşmüş taş bir süre kalır, sonra solar
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(self, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)
