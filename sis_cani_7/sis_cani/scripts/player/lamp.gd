class_name Lamp
extends Node2D
## Gaz lambası: 4 mod (kapalı, kısık, normal, yükseltilmiş), yakıt tüketimi,
## yükseltilmiş modda koni ışık ve aynalardan sekebilen huzme.

enum Mode { OFF, DIM, NORMAL, RAISED }

const RADIUS := { Mode.OFF: 0.0, Mode.DIM: 120.0, Mode.NORMAL: 220.0, Mode.RAISED: 170.0 }
const DRAIN := { Mode.OFF: 0.0, Mode.DIM: 0.3, Mode.NORMAL: 1.0, Mode.RAISED: 3.0 }
const CONE_LEN := 380.0
const CONE_HALF := 0.42       # radyan (~24°)
const BEAM_LEN := 1400.0
const BEAM_WIDTH := 28.0
const MAX_BOUNCES := 6

var base_mode: int = Mode.NORMAL
var mode: int = Mode.NORMAL
var aim: Vector2 = Vector2.RIGHT
var red := false
var infinite := false         # Son B kaçışında yakıt bitmez
var beam_points: PackedVector2Array = PackedVector2Array()
var _flicker := 1.0
var _t := 0.0
var _visual: Sprite2D
var _flame: AnimatedSprite2D
var facing := 1.0
var _light: PointLight2D
var _motes: CPUParticles2D
var _moths: CPUParticles2D
var _swing := 0.0
var _sputter := 0.0
var _sputter_t := 1.0
var _swing_v := 0.0
var _last_x := 0.0
var _cone: PointLight2D
var _beam_line: Line2D
var _beam_halo: Line2D
var _beam_dust: CPUParticles2D
var _key: PointLight2D       # oyuncuyu yandan, yumuşak aydınlatan ışık


func _ready() -> void:
	LightSystem.register(self)
	LightSystem.lamp = self
	_visual = Art.sprite_c("props/lamp_held.png")
	add_child(_visual)
	_flame = Art.animated("props/lamp_flame.png", 5, 6, {"burn": [0, 4, 10, true]}, "burn")
	_flame.position = Vector2(-5, 0)
	add_child(_flame)
	_light = Art.light(220.0, Color(1.0, 0.78, 0.5), 1.15, true)
	_light.height = 80.0
	_light.range_item_cull_mask = Art.LIGHT_MASK_WORLD
	add_child(_light)
	_key = Art.light(70.0, Color(1.0, 0.78, 0.5), 0.8)
	_key.range_item_cull_mask = Art.LIGHT_MASK_PLAYER
	_key.height = 26.0
	add_child(_key)
	_cone = PointLight2D.new()
	_cone.texture = Art.cone_texture()
	_cone.texture_scale = CONE_LEN * 1.1 / 128.0
	_cone.color = Color(1.0, 0.85, 0.6)
	_cone.energy = 1.3
	_cone.height = 40.0
	_cone.shadow_enabled = Art.use_normals
	_cone.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	_cone.visible = false
	add_child(_cone)
	_motes = CPUParticles2D.new()
	_motes.texture = Art.tex("fx/mote.png")
	_motes.amount = 14
	_motes.lifetime = 4.0
	_motes.preprocess = 4.0
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_motes.emission_sphere_radius = 110.0
	_motes.direction = Vector2(1, 0)
	_motes.spread = 180.0
	_motes.gravity = Vector2(0, -3)
	_motes.initial_velocity_min = 2.0
	_motes.initial_velocity_max = 8.0
	_motes.scale_amount_min = 0.5
	_motes.scale_amount_max = 1.0
	_motes.color = Color(1.0, 0.85, 0.6, 0.45)
	_motes.local_coords = false
	add_child(_motes)
	_moths = CPUParticles2D.new()
	_moths.texture = Art.tex("fx/moth.png")
	_moths.amount = 3
	_moths.lifetime = 3.0
	_moths.preprocess = 3.0
	_moths.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_moths.emission_sphere_radius = 26.0
	_moths.gravity = Vector2.ZERO
	_moths.orbit_velocity_min = 0.35
	_moths.orbit_velocity_max = 0.7
	_moths.initial_velocity_min = 5.0
	_moths.initial_velocity_max = 15.0
	_moths.scale_amount_min = 2.0
	_moths.scale_amount_max = 2.0
	var mt := AtlasTexture.new()
	mt.atlas = Art.tex("fx/moth.png")
	mt.region = Rect2(0, 0, 7, 5)
	_moths.texture = mt
	add_child(_moths)
	_beam_line = Line2D.new()
	_beam_line.top_level = true
	_beam_line.width = 8.0
	_beam_line.default_color = Color(1.0, 0.8, 0.5, 0.35)
	_beam_line.material = Art.glow_material()
	_beam_line.z_index = 5
	_beam_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_beam_line.gradient = Gradient.new()
	add_child(_beam_line)
	# huzmenin etrafında geniş, yumuşak hale + toz zerreleri: sert çizgi yerine ışık sütunu
	_beam_halo = Line2D.new()
	_beam_halo.top_level = true
	_beam_halo.width = 30.0
	_beam_halo.material = Art.glow_material()
	_beam_halo.z_index = 4
	_beam_halo.joint_mode = Line2D.LINE_JOINT_ROUND
	_beam_halo.gradient = Gradient.new()
	add_child(_beam_halo)
	_beam_dust = CPUParticles2D.new()
	_beam_dust.texture = Art.tex("fx/mote.png")
	_beam_dust.amount = 26
	_beam_dust.lifetime = 1.6
	_beam_dust.local_coords = false
	_beam_dust.emitting = false
	_beam_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_beam_dust.gravity = Vector2(0, 6)
	_beam_dust.spread = 180.0
	_beam_dust.initial_velocity_min = 3.0
	_beam_dust.initial_velocity_max = 10.0
	_beam_dust.scale_amount_min = 0.4
	_beam_dust.scale_amount_max = 0.9
	_beam_dust.material = Art.glow_material()
	_beam_dust.top_level = true
	_beam_dust.z_index = 5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.25, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	_beam_dust.color_ramp = ramp
	add_child(_beam_dust)


func _exit_tree() -> void:
	LightSystem.unregister(self)
	if LightSystem.lamp == self:
		LightSystem.lamp = null


func has_lamp() -> bool:
	return GameState.has_lamp


func is_light_on() -> bool:
	return has_lamp() and mode != Mode.OFF and GameState.fuel > 0.0


func is_static_light() -> bool:
	return false


func radius() -> float:
	return float(RADIUS[mode]) * _flicker * GameState.lamp_mult()


func get_light_circles() -> Array:
	return [Vector4(global_position.x, global_position.y, radius(), 1.0)]


func cycle_base_mode() -> void:
	match base_mode:
		Mode.NORMAL:
			base_mode = Mode.DIM
		Mode.DIM:
			base_mode = Mode.OFF
		_:
			base_mode = Mode.NORMAL
	AudioManager.play_sfx("click", -6.0)


## Koni ve huzme ışığı (LightSystem.is_lit içinde çağrılır).
func lights_extra(p: Vector2, margin: float) -> bool:
	if not is_light_on() or mode != Mode.RAISED:
		return false
	var v := p - global_position
	if v.length() < CONE_LEN * GameState.lamp_mult() * 0.85 + margin and absf(aim.angle_to(v)) < CONE_HALF:
		return true
	for i in range(beam_points.size() - 1):
		var c := Geometry2D.get_closest_point_to_segment(p, beam_points[i], beam_points[i + 1])
		if c.distance_to(p) < BEAM_WIDTH + margin:
			return true
	return false


func update_lamp(delta: float, want_raise: bool) -> void:
	_t += delta
	visible = has_lamp()
	if not has_lamp():
		mode = Mode.OFF
		beam_points = PackedVector2Array()
		_beam_line.points = beam_points
		_beam_halo.points = beam_points
		_beam_dust.emitting = false
		_light.visible = false
		_key.visible = false
		_cone.visible = false
		return
	mode = base_mode
	if want_raise and base_mode != Mode.OFF:
		mode = Mode.RAISED
	if GameState.fuel <= 0.0:
		mode = Mode.OFF
	# yakıt
	if not infinite and mode != Mode.OFF:
		GameState.fuel = maxf(0.0, GameState.fuel - float(DRAIN[mode]) * GameState.drain_mult() * delta)
		if GameState.fuel <= 0.0:
			GameState.ran_dry_this_chapter = true
	# titreme + az yakıtta cızırdama
	_flicker = 1.0
	# alev hiçbir zaman tam sabit değil: yalnız görsel, oyun yarıçapını etkilemez
	var life := 0.95 + 0.05 * sin(_t * 9.1) * sin(_t * 3.7 + 1.3)
	if GameState.fuel < 20.0 and mode != Mode.OFF:
		_flicker = 0.85 + 0.15 * sin(_t * 23.0) * sin(_t * 7.3)
		_sputter_t -= delta
		if _sputter_t <= 0.0:
			_sputter_t = randf_range(0.8, 2.5) * (GameState.fuel / 20.0 + 0.3)
			_sputter = 0.18
			AudioManager.play_sfx("sputter", -12.0, randf_range(0.8, 1.2))
	_sputter -= delta
	if _sputter > 0.0:
		_flicker *= 0.45
	_flame.visible = mode != Mode.OFF
	_flame.modulate = Color(1.0, 0.35, 0.3) if red else Color(1, 1, 1)
	var fs := (0.6 if mode == Mode.DIM else (1.3 if mode == Mode.RAISED else 1.0)) * _flicker * Art.SCALE
	_flame.scale = Vector2(fs, fs)
	_flame.position = Vector2(-2.5, -3.0) * fs
	_visual.modulate = Color(1.0, 0.6, 0.55) if red else Color(1, 1, 1)
	_visual.flip_h = facing < 0.0
	# yürürken sallanma (sarkaç)
	var vx := (global_position.x - _last_x) / maxf(delta, 0.001)
	_last_x = global_position.x
	_swing_v += (-_swing * 40.0 - vx * 0.004 - _swing_v * 4.0) * delta
	_swing = clampf(_swing + _swing_v * delta, -0.5, 0.5)
	_visual.rotation = _swing if mode != Mode.RAISED else 0.0
	_motes.emitting = mode != Mode.OFF
	_moths.emitting = mode != Mode.OFF and GameState.chapter != 2
	# huzme (yatay/dikey/45° yakınında hafif nişan yardımı)
	if mode == Mode.RAISED:
		var a := aim.angle()
		var sn := snappedf(a, PI / 4.0)
		if absf(a - sn) < deg_to_rad(4.5):
			aim = Vector2.RIGHT.rotated(sn)
		_compute_beam(delta)
	else:
		beam_points = PackedVector2Array()
	_beam_line.points = beam_points
	var on := mode != Mode.OFF
	_light.visible = on
	_light.texture_scale = maxf(radius(), 1.0) * 1.35 / 128.0
	_light.energy = (0.95 if mode == Mode.DIM else 1.25) * _flicker * life
	var warm := Color(1.0, 0.78, 0.5)
	if GameState.fuel < 25.0:
		warm = Color(1.0, 0.5, 0.26).lerp(warm, GameState.fuel / 25.0)
	_light.color = Color(1.0, 0.35, 0.28) if red else warm
	_key.visible = on
	_key.color = _light.color
	_key.energy = (0.55 if mode == Mode.DIM else 0.85) * _flicker * life
	_cone.visible = mode == Mode.RAISED
	_cone.texture_scale = CONE_LEN * 1.1 * GameState.lamp_mult() / 128.0
	_cone.rotation = aim.angle()
	_cone.color = _light.color
	_style_beam()


## Huzme: başta parlak, sonda sönen renk; etrafında geniş hale; ilk parçada uçuşan tozlar.
func _style_beam() -> void:
	var base := Color(1.0, 0.3, 0.25) if red else Color(1.0, 0.8, 0.5)
	var f := _flicker
	_set_fade(_beam_line.gradient, base, 0.5 * f, 0.08)
	_set_fade(_beam_halo.gradient, base, 0.11 * f, 0.0)
	_beam_halo.points = beam_points
	var has_beam := beam_points.size() >= 2
	_beam_dust.emitting = has_beam
	if has_beam:
		var a := beam_points[0]
		var b := beam_points[1]
		var seg := minf(a.distance_to(b), 420.0)
		var dir := (b - a).normalized()
		_beam_dust.global_position = a + dir * seg * 0.5
		_beam_dust.rotation = dir.angle()
		_beam_dust.emission_rect_extents = Vector2(seg * 0.5, 9.0)
		_beam_dust.color = Color(base.r, base.g, base.b, 0.55)


static func _set_fade(g: Gradient, c: Color, a0: float, a1: float) -> void:
	g.set_color(0, Color(c.r, c.g, c.b, a0))
	g.set_color(g.get_point_count() - 1, Color(c.r, c.g, c.b, a1))


# ------------------------------------------------------------------ beam
func _compute_beam(delta: float) -> void:
	var pts := PackedVector2Array()
	var o := global_position
	var d := aim.normalized()
	var remain := BEAM_LEN
	var focused := false
	var skip = null
	pts.append(o)
	var level = GameState.level
	var rects: Array = []
	if level and "beam_rects" in level:
		rects = level.beam_rects
	var mirrors := get_tree().get_nodes_in_group("mirror")
	var targets := get_tree().get_nodes_in_group("beam_target")
	for _b in MAX_BOUNCES + 1:
		var end := o + d * remain
		var best := remain + 1.0
		var hit_kind := ""
		var hit_obj = null
		var hit_normal := Vector2.ZERO
		# duvarlar
		for r in rects:
			var rr: Rect2 = r
			if rr.has_point(o):
				continue
			var corners := [rr.position, Vector2(rr.end.x, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y)]
			for k in 4:
				var ip = Geometry2D.segment_intersects_segment(o, end, corners[k], corners[(k + 1) % 4])
				if ip != null:
					var dist: float = o.distance_to(ip)
					if dist < best:
						best = dist
						hit_kind = "wall"
		# aynalar
		for m in mirrors:
			if m == skip or not m.has_method("get_segment"):
				continue
			var seg: Array = m.get_segment()
			var ip2 = Geometry2D.segment_intersects_segment(o, end, seg[0], seg[1])
			if ip2 != null:
				var dist2: float = o.distance_to(ip2)
				if dist2 < best:
					best = dist2
					hit_kind = "mirror"
					hit_obj = m
					var tangent: Vector2 = (seg[1] - seg[0]).normalized()
					hit_normal = tangent.orthogonal()
		# hedefler (kandil, mercek, mühür)
		for tg in targets:
			if tg == skip or not tg.has_method("beam_hit"):
				continue
			var c: Vector2 = tg.beam_center()
			var rad: float = tg.beam_radius
			var f := Geometry2D.segment_intersects_circle(o, end, c, rad)
			if f >= 0.0:
				var dist3 := f * remain
				if dist3 < best:
					best = dist3
					hit_kind = "target"
					hit_obj = tg
		if hit_kind == "":
			pts.append(end)
			break
		var hp := o + d * best
		pts.append(hp)
		remain -= best
		if hit_kind == "wall" or remain <= 10.0:
			break
		if hit_kind == "mirror":
			d = d.bounce(hit_normal).normalized()
			o = hp + d * 1.0
			skip = hit_obj
			continue
		if hit_kind == "target":
			hit_obj.beam_hit(focused, delta, red)
			if hit_obj.passes_beam:
				if hit_obj.focuses:
					focused = true
				o = hp + d * (hit_obj.beam_radius * 2.0 + 2.0)
				remain -= hit_obj.beam_radius * 2.0
				skip = hit_obj
				pts.append(o)
				continue
			break
	beam_points = pts
