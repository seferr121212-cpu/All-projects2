class_name Kerem
extends CharacterBody2D
## Oynanabilir karakter: yürüme/koşma/eğilme/zıplama, lamba kontrolü, etkileşim,
## el çanı, kırmızı cam, sandık itme, karanlık zamanlayıcısı, yakalanma, ekran sarsıntısı.

const WALK := 165.0
const RUN := 290.0
const CROUCH_SPEED := 80.0
const CARRY_SPEED := 190.0
const RAISED_SPEED := 120.0
const JUMP_V := -620.0
const GRAV_UP := 1500.0
const GRAV_DOWN := 2500.0
const ACCEL := 2600.0
const AIR_ACCEL := 1700.0
const DECEL := 3200.0
const STAND_H := 64.0
const CROUCH_H := 38.0
const DARK_LIMIT := 8.0
const BELL_RADIUS := 300.0
const BELL_COOLDOWN := 20.0
const KW := 24
const KH := 40

var lamp: Lamp
var cam: Camera2D
var _shape: CollisionShape2D
var _rect: RectangleShape2D
var _visual: Node2D
var _spr: AnimatedSprite2D

var facing := 1.0
var crouching := false
var carrying := false
var dead := false
var wind := 0.0
var coyote := 0.0
var jump_buf := 0.0
var dark_timer := 0.0
var off_timer := 0.0
var bell_cd := 0.0
var hold_t := 0.0
var interact_target = null
var _using_pad := false
var _look := 0.0
var _shake := 0.0
var _shake_t := 0.0
var _shake_dur := 0.0
var _shake_clock := 0.0
var _was_floor := true
var _step_t := 0.0
var _blob: Sprite2D
var _breath_t := 2.0
var _zoom := 1.75
var _idle_t := 0.0
var _look_t := 0.0
var _fall_v := 0.0
var throw_cd := 0.0
const THROW_COOLDOWN := 3.0
const STEP_UP := 14.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 10.0
	_rect = RectangleShape2D.new()
	_rect.size = Vector2(26, STAND_H)
	_shape = CollisionShape2D.new()
	_shape.shape = _rect
	_shape.position = Vector2(0, -STAND_H / 2.0)
	add_child(_shape)
	_visual = Node2D.new()
	add_child(_visual)
	_spr = Art.animated("chars/kerem.png", KW, KH, {"idle": [0, 4, 3, true]}, "idle")
	_visual.add_child(_spr)
	# Lamba ışığı oyuncuyu patlatmasın: oyuncu kendi ışık katmanında
	_spr.light_mask = Art.LIGHT_MASK_PLAYER
	# zifiri karanlıkta da siluet okunsun: yalnız oyuncuyu etkileyen soğuk, zayıf bir dolgu ışığı
	# (oyun kuralı değil; LightSystem'e kayıtlı değil, Yankıları etkilemez)
	var rim := Art.light(60.0, Color(0.55, 0.65, 0.95), 0.45)
	rim.range_item_cull_mask = Art.LIGHT_MASK_PLAYER
	rim.position = Vector2(-18, -70)
	rim.height = 40.0
	add_child(rim)
	_fix_frames()
	_blob = Art.sprite_c("fx/blob.png")
	_blob.position = Vector2(0, 0)
	_blob.z_index = -1
	add_child(_blob)
	move_child(_blob, 0)
	lamp = Lamp.new()
	add_child(lamp)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 5.0
	cam.offset = Vector2(0, -90)
	cam.zoom = Vector2(1.75, 1.75)
	add_child(cam)
	cam.make_current()
	GameState.player = self


## Sprite sayfasındaki satır düzeni farklı: (zıplama 2 kare aynı satırda, eğilme 6 kare aynı satırda)
func _fix_frames() -> void:
	var sf := Art.frames("chars/kerem.png", KW, KH, {
		"idle": [0, 4, 3, true],
		"walk": [1, 8, 11, true],
		"run": [2, 8, 15, true],
		"carry": [5, 8, 9, true],
		"carry_idle": [6, 4, 3, true],
	})
	var t := Art.ctex("chars/kerem.png")
	for anim in ["jump_up", "jump_fall", "crouch", "crouch_walk"]:
		sf.add_animation(anim)
	_add(sf, t, "jump_up", 3, [0], 1)
	_add(sf, t, "jump_fall", 3, [1], 1)
	_add(sf, t, "crouch", 4, [0, 1], 2)
	_add(sf, t, "crouch_walk", 4, [2, 3, 4, 5], 8)
	_spr.sprite_frames = sf
	_spr.play("idle")


func _add(sf: SpriteFrames, t: Texture2D, anim: String, row: int, cols: Array, fps: float) -> void:
	sf.set_animation_speed(anim, fps)
	for c in cols:
		var a := AtlasTexture.new()
		a.atlas = t
		a.region = Rect2(int(c) * KW, row * KH, KW, KH)
		sf.add_frame(anim, a)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_using_pad = false
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		_using_pad = true


func locked() -> bool:
	return GameState.input_locked > 0 or dead


func _set_crouch(v: bool) -> void:
	crouching = v
	var h := CROUCH_H if v else STAND_H
	_rect.size = Vector2(26, h)
	_shape.position = Vector2(0, -h / 2.0)


func _can_stand() -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(24, STAND_H - 4)
	q.shape = r
	q.transform = Transform2D(0.0, global_position + Vector2(0, -STAND_H / 2.0 - 2))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func _physics_process(delta: float) -> void:
	if dead:
		return
	var lk := locked()
	var dir := 0.0
	if not lk:
		dir = Input.get_axis("move_left", "move_right")
		if absf(dir) < 0.2:
			dir = 0.0
	# eğilme
	var want_crouch := (not lk) and Input.is_action_pressed("crouch") and not carrying and is_on_floor()
	if want_crouch and not crouching:
		_set_crouch(true)
	elif not want_crouch and crouching and _can_stand():
		_set_crouch(false)
	# hız: koşu her zaman serbest, ama koşarken Yankılar daha uzaktan duyar
	var speed := WALK
	if crouching:
		speed = CROUCH_SPEED
	elif not lk and Input.is_action_pressed("run"):
		speed = RUN
	if lamp.mode == Lamp.Mode.RAISED and not crouching:
		speed = minf(speed, RAISED_SPEED)
	if carrying:
		speed = CARRY_SPEED
	var target := dir * speed + wind
	var acc := ACCEL if is_on_floor() else AIR_ACCEL
	if dir == 0.0 and is_on_floor():
		acc = DECEL
	velocity.x = move_toward(velocity.x, target, acc * delta)
	# yerçekimi: düşerken daha ağır (daha net zıplama hissi)
	if is_on_floor():
		coyote = 0.11
	else:
		coyote -= delta
		var g := GRAV_UP if velocity.y < 0.0 else GRAV_DOWN
		velocity.y = minf(velocity.y + g * delta, 1400.0)
	jump_buf -= delta
	if not lk and Input.is_action_just_pressed("jump"):
		jump_buf = 0.14
	if jump_buf > 0.0 and coyote > 0.0 and not crouching:
		velocity.y = JUMP_V * (0.82 if carrying else 1.0)
		jump_buf = 0.0
		coyote = 0.0
	if Input.is_action_just_released("jump") and velocity.y < -200.0:
		velocity.y *= 0.5
	move_and_slide()
	_step_up(dir)
	# iniş (sert inişte toz + sarsıntı)
	if not is_on_floor():
		_fall_v = maxf(_fall_v, velocity.y)
	if is_on_floor() and not _was_floor:
		_spr.scale = Vector2(Art.SCALE * 1.08, Art.SCALE * 0.92)
		if _fall_v > 300.0 and GameState.level and GameState.level.has_method("dust"):
			GameState.level.dust(global_position, 7)
		if _fall_v > 950.0:
			_spr.scale = Vector2(Art.SCALE * 1.18, Art.SCALE * 0.8)
			shake(4.0, 0.25)
			AudioManager.play_sfx("step", -4.0, 0.7)
			GameState.rumble(0.3, 0.5, 0.2)
			if GameState.level and GameState.level.has_method("dust"):
				for i in 3:
					GameState.level.dust(global_position + Vector2(randf_range(-20, 20), 0))
		_fall_v = 0.0
	_was_floor = is_on_floor()
	_spr.scale = _spr.scale.lerp(Vector2(Art.SCALE, Art.SCALE), 12.0 * delta)
	# sandık itme
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other = col.get_collider()
		if other is Crate and absf(col.get_normal().x) > 0.7 and not crouching:
			other.push(-col.get_normal().x * 110.0)
	_update_aim(dir)
	_update_lamp(delta, lk)
	_update_interaction(delta, lk)
	_update_tools(delta, lk)
	_update_dark(delta)
	_animate(dir)
	_update_camera(delta)


## Küçük basamaklara takılmadan çıkar (sandıklar hariç).
func _step_up(dir: float) -> void:
	if dir == 0.0 or not is_on_floor() or not is_on_wall() or crouching:
		return
	var c := get_last_slide_collision()
	if c == null or c.get_collider() is Crate or absf(c.get_normal().x) < 0.7:
		return
	var up := Vector2(0, -STEP_UP)
	if test_move(global_transform, up):
		return
	if test_move(global_transform.translated(up), Vector2(dir * 6.0, 0)):
		return
	global_position += Vector2(dir * 6.0, -STEP_UP)


func throw_pebble() -> void:
	throw_cd = THROW_COOLDOWN
	var pb := Pebble.new()
	var aim := Vector2(facing, 0.0)
	if lamp.mode == Lamp.Mode.RAISED:
		aim = lamp.aim
	pb.vel = Vector2(aim.x * 520.0, minf(aim.y * 520.0, 0.0) - 380.0)
	if GameState.level:
		GameState.level.add_world(pb)
	else:
		get_parent().add_child(pb)
	pb.global_position = global_position + Vector2(10.0 * facing, -44)
	AudioManager.play_sfx("whoosh", -14.0, 1.5)
	if not GameState.flag("hint_throw_used"):
		GameState.set_flag("hint_throw_used")


func _update_aim(dir: float) -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > 0.3:
		lamp.aim = stick.normalized()
		_using_pad = true
	elif not _using_pad and lamp.mode == Lamp.Mode.RAISED:
		var v := get_global_mouse_position() - lamp.global_position
		if v.length() > 4.0:
			lamp.aim = v.normalized()
	else:
		lamp.aim = Vector2(facing, 0.0)
	# bakış yönü: lamba kaldırılmışsa nişana göre, yoksa yürüme yönüne göre
	if lamp.mode == Lamp.Mode.RAISED and absf(lamp.aim.x) > 0.15:
		facing = signf(lamp.aim.x)
	elif dir != 0.0:
		facing = signf(dir)
	_visual.scale.x = facing
	var hand_y := -23.0 if not crouching else -6.0
	if lamp.mode == Lamp.Mode.RAISED and not crouching:
		hand_y = -34.0
	lamp.position = Vector2(11.0 * facing, hand_y)
	lamp.facing = facing


func _update_lamp(delta: float, lk: bool) -> void:
	var want_raise := (not lk) and Input.is_action_pressed("lamp_raise")
	if want_raise and Input.is_action_just_pressed("lamp_raise") and GameState.has_lamp:
		AudioManager.play_sfx("whoosh", -16.0, 0.8)
	if not lk and Input.is_action_just_pressed("lamp_cycle") and GameState.has_lamp:
		lamp.cycle_base_mode()
	lamp.update_lamp(delta, want_raise)


func _update_interaction(delta: float, lk: bool) -> void:
	interact_target = null
	if lk:
		hold_t = 0.0
		return
	var best := 1e9
	for n in get_tree().get_nodes_in_group("interactable"):
		if not n.has_method("can_interact") or not n.can_interact(self):
			continue
		var d: float = n.global_position.distance_to(global_position + Vector2(0, -30))
		if d >= n.radius:
			continue
		# bakılan yöndekiler öncelikli
		var dx: float = n.global_position.x - global_position.x
		if absf(dx) > 12.0 and signf(dx) != facing:
			d *= 1.6
		if d < best:
			best = d
			interact_target = n
	if interact_target == null:
		hold_t = 0.0
		return
	var ht: float = interact_target.hold_time
	if ht <= 0.0:
		if Input.is_action_just_pressed("interact"):
			interact_target.interact(self)
	else:
		if Input.is_action_pressed("interact"):
			hold_t += delta
			if hold_t >= ht:
				hold_t = 0.0
				interact_target.interact(self)
		else:
			hold_t = 0.0


func hold_progress() -> float:
	if interact_target == null:
		return 0.0
	var ht: float = interact_target.hold_time
	if ht <= 0.0:
		return 0.0
	return clampf(hold_t / ht, 0.0, 1.0)


func _update_tools(delta: float, lk: bool) -> void:
	bell_cd = maxf(0.0, bell_cd - delta)
	throw_cd = maxf(0.0, throw_cd - delta)
	if lk:
		return
	if Input.is_action_just_pressed("throw") and throw_cd <= 0.0 and GameState.chapter >= 1:
		throw_pebble()
	if GameState.has_bell and Input.is_action_just_pressed("bell") and bell_cd <= 0.0:
		ring_bell()
	if GameState.has_red and Input.is_action_just_pressed("red_glass"):
		lamp.red = not lamp.red
		AudioManager.play_sfx("click", -4.0, 0.8)


func ring_bell() -> void:
	bell_cd = BELL_COOLDOWN
	AudioManager.play_sfx("bell_hand")
	shake(4.0, 0.3)
	GameState.rumble(0.4, 0.2, 0.3)
	for e in get_tree().get_nodes_in_group("echo"):
		if e.has_method("on_bell"):
			e.on_bell(global_position, BELL_RADIUS)
	if GameState.level and GameState.level.has_method("on_bell"):
		GameState.level.on_bell(global_position)
	if GameState.hud:
		GameState.hud.bell_wave(global_position)


func _update_dark(delta: float) -> void:
	if not GameState.has_lamp:
		dark_timer = 0.0
		return
	if GameState.fuel <= 0.0 and not LightSystem.is_lit_static(global_position + Vector2(0, -30)):
		dark_timer += delta
		if dark_timer >= GameState.dark_limit():
			dark_timer = 0.0
			caught()
	else:
		dark_timer = 0.0
	if lamp.base_mode == Lamp.Mode.OFF and GameState.fuel > 0.0:
		off_timer += delta
		if off_timer >= 30.0:
			GameState.unlock("DARK")
	else:
		off_timer = 0.0


func dark_remaining() -> float:
	if GameState.has_lamp and GameState.fuel <= 0.0 and dark_timer > 0.0:
		return GameState.dark_limit() - dark_timer
	return -1.0


func is_running() -> bool:
	return absf(velocity.x) > WALK + 20.0


func _animate(dir: float) -> void:
	var anim := "idle"
	if not is_on_floor():
		anim = "jump_up" if velocity.y < 0.0 else "jump_fall"
	elif crouching:
		anim = "crouch_walk" if absf(velocity.x) > 10.0 else "crouch"
	elif carrying:
		anim = "carry" if absf(velocity.x) > 10.0 else "carry_idle"
	elif absf(velocity.x) > WALK + 20.0:
		anim = "run"
	elif absf(velocity.x) > 12.0:
		anim = "walk"
	# uzun süre durunca etrafına bakınır
	if anim == "idle" and not locked():
		_idle_t += get_physics_process_delta_time()
		if _idle_t > 6.0:
			_idle_t = 0.0
			_look_t = 1.3
	else:
		_idle_t = 0.0
		_look_t = 0.0
	if _look_t > 0.0:
		_look_t -= get_physics_process_delta_time()
		_visual.scale.x = -facing
	if _spr.animation != anim:
		_spr.play(anim)
	# adım: ses + hafif toz
	var dt := get_physics_process_delta_time()
	if is_on_floor() and absf(velocity.x) > 12.0:
		_step_t -= dt * absf(velocity.x) / 100.0
		if _step_t <= 0.0:
			_step_t = 0.95
			var pitch := 0.75 if GameState.chapter == 2 else 1.0
			AudioManager.play_sfx("step", -14.0 if absf(velocity.x) < WALK + 20.0 else -9.0, pitch * randf_range(0.85, 1.15))
			if GameState.level and GameState.level.has_method("dust"):
				GameState.level.dust(global_position - Vector2(8.0 * facing, 0), 8 if absf(velocity.x) > WALK + 20.0 else 4)
	# ayak altı gölgesi: havadayken küçülür
	_blob.visible = is_on_floor()
	# soğuk havada nefes buharı
	_breath_t -= dt
	if _breath_t <= 0.0:
		_breath_t = randf_range(2.2, 3.4) if not is_running() else 1.1
		_breath()


func _breath() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 6
	p.lifetime = 1.2
	p.explosiveness = 0.8
	p.position = Vector2(14.0 * facing, (-50.0 if not crouching else -30.0))
	p.direction = Vector2(facing, -0.4)
	p.spread = 20.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 22.0
	p.gravity = Vector2(0, -8)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.85, 0.88, 0.95, 0.25)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


func _update_camera(delta: float) -> void:
	# ara sahnede sinematik yaklaşma
	var want_zoom := 2.15 if GameState.input_locked > 0 else 1.75
	_zoom = lerpf(_zoom, want_zoom, 1.6 * delta)
	cam.zoom = Vector2(_zoom, _zoom)
	# önden bakış: gidilen yöne biraz daha fazla görüş
	var want := facing * 140.0 if absf(velocity.x) > 20.0 else _look * 0.98
	_look = lerpf(_look, want, 2.0 * delta)
	var off := Vector2(_look, -90.0)
	if _shake_t > 0.0:
		# rastgele zıplama yerine yumuşak, sönümlenen titreşim (göz yormaz)
		_shake_t -= delta
		_shake_clock += delta
		var k := clampf(_shake_t / maxf(_shake_dur, 0.001), 0.0, 1.0)
		k *= k
		var tt := _shake_clock * 38.0
		off += Vector2(sin(tt) + 0.5 * sin(tt * 2.3 + 1.1), cos(tt * 1.3 + 0.4) + 0.5 * sin(tt * 2.9)) * 0.67 * _shake * k
	cam.offset = off


func shake(amount: float, time: float) -> void:
	if not bool(GameState.settings.get("shake", true)):
		return
	_shake = maxf(_shake if _shake_t > 0.0 else 0.0, amount)
	_shake_t = maxf(_shake_t, time)
	_shake_dur = _shake_t


## Pröloğ (14 yaşında Kerem) ve ara bölüm (genç Hüsnü) için görünüm.
func set_look(kind: String) -> void:
	match kind:
		"child":
			_visual.scale.y = 0.82
			_spr.modulate = Color(0.85, 0.88, 1.0)
		"husnu":
			_spr.modulate = Color(0.62, 0.7, 0.95)
		_:
			_visual.scale.y = 1.0
			_spr.modulate = Color(1, 1, 1)


func set_carrying(v: bool) -> void:
	carrying = v


func caught() -> void:
	if dead:
		return
	dead = true
	velocity = Vector2.ZERO
	GameState.stat_caught += 1
	AudioManager.play_sfx("whisper")
	shake(8.0, 0.5)
	GameState.rumble(0.6, 0.9, 0.6)
	if GameState.hud:
		await GameState.hud.caught_fx()
	if GameState.main:
		await GameState.main.fade_out(0.7)
	if GameState.level:
		GameState.level.respawn()
	dead = false
	off_timer = 0.0
	if GameState.main:
		await GameState.main.fade_in(0.7)


func teleport(p: Vector2) -> void:
	global_position = p
	velocity = Vector2.ZERO
	cam.reset_smoothing()
