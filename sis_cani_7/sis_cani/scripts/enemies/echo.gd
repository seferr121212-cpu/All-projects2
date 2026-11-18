class_name Echo
extends CharacterBody2D
## Yankı düşmanları.
##   CRAWLER  (Sürünen):  yerde, yavaş, sese ve görüşe göre takip eder.
##   MIMIC    (Taklitçi): insan boyunda, bilinen bir sesle seslenir, yaklaşınca atılır.
##   WATCHER  (Bekleyen): havada asılı, hareketsiz. Işık üzerinden ÇEKİLİNCE saldırır.
## Kural: ışık alanındaki Yankı donar. Işık yoksa ve dokunursa Kerem yakalanır.

enum Kind { CRAWLER, MIMIC, WATCHER, WHISPER }

const KIND_NAMES := ["CRAWLER", "MIMIC", "WATCHER", "WHISPER"]

const GRAV := 1400.0

var kind: int = Kind.CRAWLER
var spawn_pos := Vector2.ZERO
var state := "idle"
var speed := 70.0
var detect := 420.0
var catch_r := 38.0
var flying := false
var size := Vector2(60, 26)
var lure_keys: Array = []
var forced_hunt := false

var _scatter_t := 0.0
var _scatter_from := Vector2.ZERO
var _lure_pos := Vector2.ZERO
var _lure_t := 0.0
var _lure_cd := 3.0
var _lit_t := 0.0
var _awake := false
var _charge_t := 0.0
var _t := 0.0
var _wander_dir := 1.0
var _wander_t := 0.0
var _frozen := false

var _spr: AnimatedSprite2D
var _eyes: Sprite2D
var _eye_offset := Vector2.ZERO
var _face := 1.0
var _smoke: CPUParticles2D
var _blink := 0.0
var _blink_t := 3.0
var _bell_fx := 0.0
var _whisper_t := 3.0
var _trail_t := 0.0
var _rim: ShaderMaterial
var _eye_light: PointLight2D
var _rim_v := 0.0


func setup(k: int, pos: Vector2) -> Echo:
	kind = k
	position = pos
	spawn_pos = pos
	return self


func _ready() -> void:
	add_to_group("echo")
	collision_layer = 4
	collision_mask = 1
	_t = randf() * 10.0
	match kind:
		Kind.CRAWLER:
			size = Vector2(62, 26)
			speed = 72.0
			detect = 440.0
		Kind.MIMIC:
			size = Vector2(30, 84)
			speed = 48.0
			detect = 620.0
		Kind.WATCHER:
			size = Vector2(48, 70)
			speed = 240.0
			detect = 0.0
			flying = true
		Kind.WHISPER:
			size = Vector2(36, 86)
			speed = 34.0
			detect = 900.0
			flying = true
	speed *= GameState.echo_speed_mult()
	if forced_hunt:
		detect = 4000.0
		speed *= 1.35
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	shape.shape = r
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)
	_build_visual()
	_emerge()


func _build_visual() -> void:
	var path := "chars/echo_crawler.png"
	var fw := 36
	var fh := 18
	match kind:
		Kind.MIMIC:
			path = "chars/echo_mimic.png"
			fw = 20
			fh = 44
		Kind.WATCHER:
			path = "chars/echo_watcher.png"
			fw = 28
			fh = 36
		Kind.WHISPER:
			path = "chars/echo_whisper.png"
			fw = 26
			fh = 46
	_spr = Art.animated(path, fw, fh, {"move": [0, 6, 8, true]}, "move")
	_spr.frame = randi() % 6
	_rim = ShaderMaterial.new()
	_rim.shader = load("res://shaders/echo_rim.gdshader")
	_spr.material = _rim
	add_child(_spr)
	_eye_light = Art.light(70.0, Color(1.0, 0.45, 0.35), 0.0)
	add_child(_eye_light)
	# sise karışan duman izi
	var smoke := CPUParticles2D.new()
	smoke.texture = Art.tex("fx/mote.png")
	smoke.position = Vector2(0, -fh * 1.2)
	smoke.amount = 14
	smoke.lifetime = 1.6
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(fw * 0.7, fh * 0.6)
	smoke.direction = Vector2(0, -1)
	smoke.spread = 40.0
	smoke.gravity = Vector2(0, -12)
	smoke.initial_velocity_min = 6.0
	smoke.initial_velocity_max = 18.0
	smoke.scale_amount_min = 1.5
	smoke.scale_amount_max = 3.0
	smoke.color = Color(0.02, 0.025, 0.04, 0.7)
	add_child(smoke)
	_smoke = smoke
	_eye_offset = Vector2(14, -24)
	if kind == Kind.MIMIC:
		_eye_offset = Vector2(3, -76)
	elif kind == Kind.WATCHER:
		_eye_offset = Vector2(2, -54)
	elif kind == Kind.WHISPER:
		_eye_offset = Vector2(2, -76)
	_eyes = Art.sprite_c("chars/eyes.png")
	_eyes.material = Art.glow_material()
	var layer = GameState.level.glow_layer if GameState.level and "glow_layer" in GameState.level else null
	if layer:
		layer.add_child(_eyes)
	else:
		add_child(_eyes)


func _exit_tree() -> void:
	if is_instance_valid(_eyes) and _eyes.get_parent() != self:
		_eyes.queue_free()


## Sisin içinden yavaşça belirir.
func _emerge() -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 1.4).set_delay(randf_range(0.0, 0.4))


func reset() -> void:
	_emerge()
	global_position = spawn_pos
	velocity = Vector2.ZERO
	state = "idle"
	_scatter_t = 0.0
	_lure_t = 0.0
	_awake = false
	_lit_t = 0.0


func on_bell(pos: Vector2, r: float) -> void:
	var d := global_position.distance_to(pos)
	if d < r:
		_scatter_burst()
		_bell_fx = 1.0
		state = "scatter"
		_scatter_t = 3.0
		_scatter_from = pos
	elif d < 900.0:
		_lure_pos = pos
		_lure_t = 4.0


func _scatter_burst() -> void:
	var b := CPUParticles2D.new()
	b.one_shot = true
	b.explosiveness = 0.9
	b.amount = 26
	b.lifetime = 1.1
	b.texture = Art.tex("fx/mote.png")
	b.direction = Vector2(0, -1)
	b.spread = 180.0
	b.initial_velocity_min = 60.0
	b.initial_velocity_max = 200.0
	b.gravity = Vector2(0, -30)
	b.damping_min = 80.0
	b.damping_max = 120.0
	b.scale_amount_min = 2.0
	b.scale_amount_max = 5.0
	var g := Gradient.new()
	g.set_color(0, Color(0.75, 0.8, 0.95, 0.8))
	g.set_color(1, Color(0.2, 0.22, 0.3, 0.0))
	b.color_ramp = g
	b.global_position = _center()
	b.z_index = 3
	get_parent().add_child(b)
	b.emitting = true
	get_tree().create_timer(1.6).timeout.connect(b.queue_free)


## Saldırı anında gözlerden geride kalan iz.
func _eye_trail() -> void:
	if not is_instance_valid(_eyes) or not _eyes.visible:
		return
	var g := Sprite2D.new()
	g.texture = _eyes.texture
	g.scale = _eyes.scale
	g.material = _eyes.material
	g.global_position = _eyes.global_position
	g.z_index = _eyes.z_index
	g.modulate = Color(1, 0.6, 0.5, 0.6)
	_eyes.get_parent().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.35)
	tw.tween_callback(g.queue_free)


func _center() -> Vector2:
	return global_position + Vector2(0, -size.y * 0.5)


func _physics_process(delta: float) -> void:
	_t += delta
	var p = GameState.player
	if p == null or not is_instance_valid(p):
		return
	var pc: Vector2 = p.global_position + Vector2(0, -30)
	var to_p := pc - _center()
	var lit := LightSystem.is_lit(_center(), size.x * 0.3)
	_frozen = false
	if to_p.length() < 520.0 and not KIND_NAMES[kind] in GameState.seen:
		GameState.see(KIND_NAMES[kind])
	match kind:
		Kind.WATCHER:
			_watcher(delta, lit, to_p)
		Kind.WHISPER:
			_whisper(delta, to_p)
		_:
			_ground(delta, lit, to_p, p)
	if not flying:
		if not is_on_floor():
			velocity.y = minf(velocity.y + GRAV * delta, 1200.0)
		else:
			velocity.y = 0.0
	move_and_slide()
	# yakalama
	if not _frozen and state != "scatter" and not p.dead and to_p.length() < catch_r + size.x * 0.3:
		p.caught()


func _ground(delta: float, lit: bool, to_p: Vector2, p) -> void:
	_lure_cd -= delta
	if state == "scatter":
		_scatter_t -= delta
		velocity.x = signf(global_position.x - _scatter_from.x) * speed * 1.6
		if _scatter_t <= 0.0:
			state = "idle"
		return
	if lit:
		state = "frozen"
		_frozen = true
		velocity.x = 0.0
		return
	var hear := detect
	var holding: bool = p.crouching and absf(p.velocity.x) < 10.0 and p.is_on_floor()
	if absf(p.velocity.x) > 200.0:
		hear *= 1.6
	elif holding:
		hear *= 0.15
		# nefesini tutan Kerem'in izi kaybolur (çok yakında değilse)
		if state == "hunt" and to_p.length() > 140.0:
			state = "idle"
			_wander_t = 2.0
	elif p.crouching:
		hear *= 0.55
	if _lure_t > 0.0:
		_lure_t -= delta
		state = "lured"
		var dx := _lure_pos.x - global_position.x
		velocity.x = signf(dx) * speed * 1.2 if absf(dx) > 20.0 else 0.0
		return
	if to_p.length() < hear and absf(to_p.y) < 260.0:
		if state != "hunt":
			_hunt_hint()
		state = "hunt"
		var sp := speed
		if kind == Kind.MIMIC and to_p.length() < 170.0:
			sp = speed * 3.2
		velocity.x = signf(to_p.x) * sp
		if kind == Kind.MIMIC and _lure_cd <= 0.0 and not lure_keys.is_empty() and not Dialogue.busy:
			_lure_cd = 9.0
			Dialogue.play([lure_keys[randi() % lure_keys.size()]])
	else:
		state = "idle"
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(1.5, 3.5)
			_wander_dir = -_wander_dir
		if absf(global_position.x - spawn_pos.x) > 120.0:
			_wander_dir = signf(spawn_pos.x - global_position.x)
		velocity.x = _wander_dir * speed * 0.3


func _hunt_hint() -> void:
	var hud = GameState.hud
	if hud == null:
		return
	if not GameState.flag("hint_breath"):
		GameState.set_flag("hint_breath")
		GameState.set_flag("hint_breath_t", GameState.playtime)
		hud.hint(Loc.t("HINT_HOLD_BREATH"), 7.0)
	elif not GameState.flag("hint_throw") and GameState.chapter >= 1 and GameState.playtime - float(GameState.flags.get("hint_breath_t", 0.0)) > 45.0:
		GameState.set_flag("hint_throw")
		hud.hint(Loc.t("HINT_THROW"), 7.0)


## Fısıltı: lamba ışığında donmaz. Yaklaşınca gazyağını emer. Kandil ışığı ya da çan onu dağıtır.
func _whisper(delta: float, to_p: Vector2) -> void:
	if state == "scatter":
		_scatter_t -= delta
		velocity = (global_position - _scatter_from).normalized() * 140.0
		if _scatter_t <= 0.0:
			state = "idle"
		return
	if LightSystem.is_lit_static(_center()):
		_frozen = true
		velocity = (global_position - GameState.player.global_position).normalized() * 40.0
		return
	if to_p.length() < detect:
		state = "hunt"
		velocity = to_p.normalized() * speed
		if to_p.length() < 230.0 and GameState.has_lamp:
			GameState.fuel = maxf(0.0, GameState.fuel - 6.0 * delta)
	else:
		state = "idle"
		velocity = Vector2(0, sin(_t * 1.1) * 8.0)


func _watcher(delta: float, lit: bool, to_p: Vector2) -> void:
	if state == "scatter":
		_scatter_t -= delta
		velocity = (global_position - _scatter_from).normalized() * 160.0
		if _scatter_t <= 0.0:
			state = "return"
		return
	if lit:
		_frozen = true
		_lit_t += delta
		if _lit_t > 0.25:
			_awake = true
		velocity = Vector2.ZERO
		if state != "charge":
			state = "watched"
		else:
			_charge_t = 0.0
		return
	_lit_t = 0.0
	if _awake:
		_awake = false
		state = "charge"
		_charge_t = 2.2
	match state:
		"charge":
			_charge_t -= delta
			velocity = to_p.normalized() * speed
			if _charge_t <= 0.0:
				state = "return"
		"return":
			var back := spawn_pos - global_position
			velocity = back.normalized() * 80.0
			if back.length() < 8.0:
				global_position = spawn_pos
				velocity = Vector2.ZERO
				state = "idle"
		_:
			velocity = Vector2(0, sin(_t * 1.3) * 6.0)


func _process(_delta: float) -> void:
	if absf(velocity.x) > 5.0:
		_face = signf(velocity.x)
	_spr.flip_h = _face < 0.0
	if _smoke:
		_smoke.emitting = not _frozen
	var dl := get_process_delta_time()
	_bell_fx = maxf(0.0, _bell_fx - dl * 2.0)
	_blink_t -= dl
	if _blink_t <= 0.0:
		_blink = 0.12
		_blink_t = randf_range(2.0, 5.0)
	_blink -= dl
	_rim_v = move_toward(_rim_v, 1.0 if _frozen else 0.0, dl * 5.0)
	if _rim:
		_rim.set_shader_parameter("glow", _rim_v)
	if _eye_light:
		var hunting: bool = state in ["hunt", "charge", "lured"] and not _frozen
		_eye_light.energy = move_toward(_eye_light.energy, 0.7 if hunting else 0.0, dl * 2.0)
		_eye_light.position = Vector2(_eye_offset.x * _face, _eye_offset.y)
	if _frozen:
		_spr.pause()
		var pulse := 0.5 + 0.5 * sin(_t * 9.0)
		_spr.modulate = Color(0.62 + pulse * 0.12, 0.68 + pulse * 0.12, 0.8 + pulse * 0.15, 0.95)
	else:
		_spr.play("move")
		_spr.speed_scale = 1.6 if state in ["hunt", "charge", "lured"] else 0.8
		_spr.modulate = Color(1, 1, 1, 0.96)
		# lamba sönmek üzereyken Yankılar titreşir, daha "gerçek" görünür
		if GameState.has_lamp and GameState.fuel < 20.0:
			_spr.modulate.a = randf_range(0.6, 1.0)
			_spr.offset.x = randf_range(-0.6, 0.6)
		else:
			_spr.offset.x = 0.0
	# konumsal fısıltı
	_whisper_t -= dl
	if _whisper_t <= 0.0:
		_whisper_t = randf_range(5.0, 10.0)
		var pl = GameState.player
		if pl != null and is_instance_valid(pl) and not _frozen and modulate.a > 0.5:
			var dd: float = pl.global_position.distance_to(global_position)
			if dd < 1100.0 and dd > 120.0:
				AudioManager.play_at("whisper", global_position, -18.0 if state == "idle" else -10.0, randf_range(0.75, 1.15))
	# saldırı izi
	var fast := state == "charge" or (kind == Kind.MIMIC and absf(velocity.x) > speed * 2.0)
	if fast:
		_trail_t -= dl
		if _trail_t <= 0.0:
			_trail_t = 0.04
			_eye_trail()
	if _bell_fx > 0.0:
		_spr.modulate = _spr.modulate.lerp(Color(2.0, 2.0, 2.2, 0.4), _bell_fx)
		_spr.scale = Vector2(Art.SCALE * (1.0 + _bell_fx * 0.4), Art.SCALE * (1.0 - _bell_fx * 0.3))
	else:
		_spr.scale = Vector2(Art.SCALE, Art.SCALE)
	if is_instance_valid(_eyes):
		_eyes.global_position = global_position + Vector2(_eye_offset.x * _face, _eye_offset.y)
		_eyes.modulate.a = 0.3 if _frozen else (1.0 if state in ["hunt", "charge", "lured"] else 0.7)
		_eyes.visible = visible and _blink <= 0.0
