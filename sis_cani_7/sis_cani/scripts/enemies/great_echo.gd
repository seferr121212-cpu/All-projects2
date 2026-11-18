class_name GreatEcho
extends Node2D
## Büyük Yankı (Hüsnü Usta). Bölüm 2 kovalamacası ve Son B'deki sis duvarı.
## Işık onu yavaşlatır, el çanı 3 saniye geri iter. Kerem'e yetişirse yakalar.

signal belled

var speed := 118.0
var lit_speed := 42.0
var active := true
var tame := false
var is_fog_wall := false
var _stun := 0.0
var _t := 0.0
var _spr: AnimatedSprite2D
var _eyes: Node2D


func _ready() -> void:
	add_to_group("echo")
	_spr = Art.animated("chars/great_echo.png", 150, 180, {"move": [0, 4, 5, true]}, "move")
	var k := 1.5 if is_fog_wall else 1.0
	_spr.scale = Vector2(Art.SCALE, Art.SCALE) * k
	_spr.position = Vector2(-230 * k, -340 * k)
	if is_fog_wall:
		_spr.modulate = Color(0.55, 0.6, 0.7, 0.9)
	add_child(_spr)
	_eyes = Node2D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in (3 if is_fog_wall else 7):
		var e := Art.sprite_c("chars/eyes.png")
		e.material = Art.glow_material()
		e.position = Vector2(rng.randf_range(-120, 0), rng.randf_range(-260, -90)) * k
		_eyes.add_child(e)
	var layer = GameState.level.glow_layer if GameState.level and "glow_layer" in GameState.level else null
	if layer:
		layer.add_child(_eyes)
	else:
		add_child(_eyes)


func _exit_tree() -> void:
	if is_instance_valid(_eyes) and _eyes.get_parent() != self:
		_eyes.queue_free()


func front() -> Vector2:
	return global_position + Vector2(40, -140)


func on_bell(pos: Vector2, _r: float) -> void:
	if pos.distance_to(front()) < 650.0:
		_stun = 3.0
		belled.emit()


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_eyes):
		_eyes.global_position = global_position
		_eyes.modulate.a = 0.5 + 0.5 * absf(sin(_t * 1.7))
	var p = GameState.player
	if not active or p == null or not is_instance_valid(p):
		return
	if not "GREAT" in GameState.seen:
		GameState.see("GREAT")
	global_position.y = lerpf(global_position.y, p.global_position.y + 20.0, 2.0 * delta)
	if tame:
		return
	var sp := speed
	if LightSystem.is_lit(front(), 70.0):
		sp = lit_speed
	if _stun > 0.0:
		_stun -= delta
		sp = -70.0
	global_position.x += sp * delta
	# çok geride kalırsa oyuncuya yakın bir yere sıçrar (kovalama hep hissedilsin)
	if p.global_position.x - global_position.x > 1100.0:
		global_position.x = p.global_position.x - 1100.0
	if not p.dead and p.global_position.x - front().x < 30.0:
		p.caught()
