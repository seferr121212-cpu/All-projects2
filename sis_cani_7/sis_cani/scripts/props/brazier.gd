class_name Brazier
extends Interactable
## Demir kandil: kalıcı ışık alanı, kayıt noktası ve yakıt ikmali.

signal lit

var id := ""
var is_lit := false
var checkpoint := true
var chase := false
var beam_ignitable := false
var light_radius := 290.0
var beam_radius := 42.0
var passes_beam := false
var focuses := false
var _flame: CPUParticles2D
var _fire: AnimatedSprite2D
var _plight: PointLight2D
var _flare := 0.0
var _smoke: CPUParticles2D
var _t := 0.0
var _ring: Sprite2D
var _haze: ColorRect


func _ready() -> void:
	super()
	prompt = "INT_BRAZIER"
	radius = 95.0
	LightSystem.register(self)
	if beam_ignitable:
		add_to_group("beam_target")
	add_child(Art.sprite("props/brazier.png"))
	# yerde sıcak ışık halkası
	_ring = Sprite2D.new()
	_ring.texture = Art.light_texture()
	_ring.material = Art.glow_material()
	_ring.scale = Vector2(1.5, 0.16)
	_ring.modulate = Color(0.6, 0.38, 0.15, 0.6)
	_ring.position = Vector2(0, -2)
	_ring.z_index = -1
	_ring.visible = false
	add_child(_ring)
	_fire = Art.animated("props/flame.png", 16, 22, {"burn": [0, 8, 12, true]}, "burn")
	_fire.position = Vector2(-16, -96)
	_fire.visible = false
	_fire.material = Art.glow_material()
	add_child(_fire)
	_flame = CPUParticles2D.new()
	_flame.position = Vector2(0, -60)
	_flame.amount = 10
	_flame.lifetime = 1.4
	_flame.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_flame.emission_rect_extents = Vector2(10, 2)
	_flame.direction = Vector2(0, -1)
	_flame.spread = 25.0
	_flame.gravity = Vector2(8, -40)
	_flame.initial_velocity_min = 20.0
	_flame.initial_velocity_max = 60.0
	_flame.scale_amount_min = 2.0
	_flame.scale_amount_max = 3.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.8, 0.4, 1.0))
	g.set_color(1, Color(0.9, 0.3, 0.1, 0.0))
	_flame.color_ramp = g
	_flame.emitting = false
	add_child(_flame)
	_smoke = CPUParticles2D.new()
	_smoke.texture = Art.tex("fx/mote.png")
	_smoke.position = Vector2(0, -100)
	_smoke.amount = 12
	_smoke.lifetime = 3.5
	_smoke.direction = Vector2(0, -1)
	_smoke.spread = 10.0
	_smoke.initial_velocity_min = 18.0
	_smoke.initial_velocity_max = 30.0
	_smoke.gravity = Vector2(-6, 0)
	_smoke.scale_amount_min = 3.0
	_smoke.scale_amount_max = 7.0
	var sg := Gradient.new()
	sg.set_color(0, Color(0.3, 0.3, 0.33, 0.35))
	sg.set_color(1, Color(0.3, 0.3, 0.33, 0.0))
	_smoke.color_ramp = sg
	_smoke.emitting = false
	add_child(_smoke)
	_plight = Art.light(light_radius * 1.3, Color(1.0, 0.66, 0.36), 1.25, true)
	_plight.position = Vector2(0, -70)
	_plight.visible = false
	add_child(_plight)
	if id != "" and not chase and GameState.flag(flag_name()):
		set_lit(true, false)


func _exit_tree() -> void:
	LightSystem.unregister(self)
	if _haze and is_instance_valid(_haze):
		_haze.queue_free()


func flag_name() -> String:
	return "c%d_brz_%s" % [GameState.chapter, id]


func can_interact(p) -> bool:
	return not is_lit and super(p)


func interact(_p) -> void:
	if not GameState.has_lamp or GameState.fuel <= 0.0:
		if GameState.hud:
			GameState.hud.toast(Loc.t("HINT_NEED_LAMP"))
		return
	light_up()


func light_up() -> void:
	if is_lit:
		return
	set_lit(true, true)


func set_lit(v: bool, fx: bool) -> void:
	is_lit = v
	_flame.emitting = v
	_fire.visible = v
	_plight.visible = v
	if _ring:
		_ring.visible = v
	_smoke.emitting = v
	_set_haze(v)
	if not v:
		return
	if fx:
		AudioManager.play_sfx("ignite")
		_fire.scale = Vector2(Art.SCALE * 1.6, Art.SCALE * 1.6)
		var burst := CPUParticles2D.new()
		burst.one_shot = true
		burst.explosiveness = 0.95
		burst.amount = 24
		burst.lifetime = 0.9
		burst.position = Vector2(0, -60)
		burst.direction = Vector2(0, -1)
		burst.spread = 80.0
		burst.initial_velocity_min = 80.0
		burst.initial_velocity_max = 220.0
		burst.gravity = Vector2(0, 260)
		burst.scale_amount_min = 1.5
		burst.scale_amount_max = 3.0
		burst.color = Color(1.0, 0.75, 0.35)
		burst.material = Art.glow_material()
		add_child(burst)
		burst.emitting = true
		get_tree().create_timer(1.5).timeout.connect(burst.queue_free)
		_flare = 2.0
		_shock_ring()
		GameState.rumble(0.2, 0.0, 0.15)
		create_tween().tween_property(_fire, "scale", Vector2(Art.SCALE, Art.SCALE), 0.5)
		if GameState.player:
			GameState.player.shake(3.0, 0.2)
		GameState.stat_braziers += 1
		if id != "" and not chase:
			GameState.set_flag(flag_name())
		if checkpoint and not chase:
			GameState.set_checkpoint(global_position + Vector2(50, 0))
	lit.emit()


func extinguish() -> void:
	is_lit = false
	_flame.emitting = false
	_fire.visible = false
	_plight.visible = false
	_smoke.emitting = false


func is_light_on() -> bool:
	return is_lit


func is_static_light() -> bool:
	return true


func get_light_circles() -> Array:
	return [Vector4(global_position.x, global_position.y - 60.0, light_radius * (0.96 + 0.04 * sin(_t * 9.0)), 1.0)]


func beam_center() -> Vector2:
	return global_position + Vector2(0, -44)


func beam_hit(_focused: bool, _delta: float, _red: bool) -> void:
	if beam_ignitable and not is_lit:
		light_up()


func _process(delta: float) -> void:
	_t += delta
	_flare = maxf(0.0, _flare - delta * 2.5)
	if is_lit:
		_plight.energy = 1.2 + 0.12 * sin(_t * 11.0) * sin(_t * 4.3) + _flare
		_ring.modulate.a = 0.5 + 0.1 * sin(_t * 11.0) * sin(_t * 4.3) + _flare * 0.2
	if is_lit and GameState.player and is_instance_valid(GameState.player):
		if GameState.player.global_position.distance_to(global_position) < 170.0:
			GameState.add_fuel(12.0 * delta)


## Alevin üstünde sıcak hava dalgalanması (ışık katmanında, dünyayı bükerek).
func _set_haze(on: bool) -> void:
	if not on:
		if _haze and is_instance_valid(_haze):
			_haze.queue_free()
		_haze = null
		return
	if _haze != null or not bool(GameState.settings.get("postfx", true)):
		return
	var lv = GameState.level
	if lv == null or lv.glow_layer == null:
		return
	_haze = ColorRect.new()
	_haze.size = Vector2(90, 150)
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/heat_haze.gdshader")
	_haze.material = m
	lv.glow_layer.add_child(_haze)
	_haze.position = global_position + Vector2(-45, -250)


## Yanma anında genişleyen ışık halkası.
func _shock_ring() -> void:
	var r := Sprite2D.new()
	r.texture = Art.light_texture()
	r.material = Art.glow_material()
	r.position = Vector2(0, -60)
	r.scale = Vector2(0.2, 0.2)
	r.modulate = Color(1.0, 0.7, 0.35, 0.7)
	add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "scale", Vector2(4.5, 4.5), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(r, "modulate:a", 0.0, 0.55)
	tw.tween_callback(r.queue_free)
