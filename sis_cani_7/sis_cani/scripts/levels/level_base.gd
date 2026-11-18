class_name LevelBase
extends Node2D
## Bölüm tabanı. Bölümler build() içinde yardımcı fonksiyonlarla kurulur:
## solid / ground / brazier / pickup / echo / trigger / crate / mover / mirror ...
## Koordinatlar: x sağa, y aşağı. Zemin üstü genelde y = 0 (yukarısı negatif).

var chapter := 1
var beam_rects: Array = []
var spawn := Vector2(200, 0)
var glow_layer: CanvasLayer
var darkness: DarknessOverlay
var background: Background
var foreground: Foreground
var postfx: CanvasLayer
var _post_mat: ShaderMaterial
var player: Kerem
var echoes: Array = []
var bounds := Rect2(-200, -4000, 20000, 5000)

# tema
var dark_value := 0.5
var fog_amount := 0.2
var solid_color := Color(-1, 0, 0)
var bg_key := "c1"
var default_style := "earth"
var weather_rain := false
var weather_motes := false
var lightning := false
var auto_scatter := true
var ambient_color := Color(0.42, 0.46, 0.6)
var moonlight := true
var scatter_set := ["tuft_a", "tuft_b", "tuft_c", "tuft_a", "rock_c", "rock_a", "bush"]
var _lightning_t := 20.0

const STYLES := {
	"earth": ["tiles/earth.png", "tiles/top_grass.png"],
	"earth_dark": ["tiles/earth_dark.png", "tiles/top_grass.png"],
	"planks": ["tiles/planks.png", "tiles/top_plank.png"],
	"cobble": ["tiles/cobble.png", "tiles/top_stone.png"],
	"rock": ["tiles/rock.png", "tiles/top_moss.png"],
	"rockwall": ["tiles/rock.png", ""],
	"brick": ["tiles/brick.png", "tiles/top_stone.png"],
	"brickwall": ["tiles/brick.png", ""],
	"stone": ["tiles/stone_wall.png", "tiles/top_stone.png"],
	"wood": ["tiles/wood_wall.png", "tiles/top_plank.png"],
}

var _auto_id := 0
var _puddles: Array = []
var _splash: CPUParticles2D
var _rain: CPUParticles2D
var _leaves: CPUParticles2D
var _world: Node2D
var _decor: Node2D


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func start(from_checkpoint: bool) -> void:
	GameState.level = self
	Art.use_normals = bool(GameState.settings.get("postfx", true))
	LightSystem.clear()
	background = Background.new()
	add_child(background)
	_decor = Node2D.new()
	_decor.z_index = -2
	add_child(_decor)
	_world = Node2D.new()
	add_child(_world)
	glow_layer = CanvasLayer.new()
	glow_layer.layer = 6
	glow_layer.follow_viewport_enabled = true
	add_child(glow_layer)
	darkness = DarknessOverlay.new()
	add_child(darkness)
	foreground = Foreground.new()
	add_child(foreground)
	postfx = CanvasLayer.new()
	postfx.layer = 8
	add_child(postfx)
	var pr := ColorRect.new()
	pr.set_anchors_preset(Control.PRESET_FULL_RECT)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = load("res://shaders/postfx.gdshader")
	pr.material = _post_mat
	postfx.add_child(pr)
	postfx.visible = bool(GameState.settings.get("postfx", true))
	var grade: Array = GRADES.get(bg_key, GRADES["c1"])
	_post_mat.set_shader_parameter("shadow_tint", grade[0])
	_post_mat.set_shader_parameter("high_tint", grade[1])
	_post_mat.set_shader_parameter("sepia", sepia)
	var cm := CanvasModulate.new()
	cm.color = ambient_color
	_world.add_child(cm)
	_cm = cm
	if moonlight:
		var moon := DirectionalLight2D.new()
		moon.color = Color(0.55, 0.65, 0.9)
		moon.energy = 0.35
		moon.height = 0.6
		moon.rotation = deg_to_rad(20.0)
		moon.shadow_enabled = true
		moon.shadow_color = Color(0, 0, 0, 0.6)
		_world.add_child(moon)
	build()
	background.setup(self)
	darkness.setup(self)
	foreground.setup(bg_key)
	_setup_weather()
	var lr := lens_rain if lens_rain >= 0.0 else (0.5 if weather_rain else 0.0)
	_post_mat.set_shader_parameter("rain_lens", lr)
	player = Kerem.new()
	_world.add_child(player)
	player.cam.limit_left = int(bounds.position.x)
	player.cam.limit_right = int(bounds.end.x)
	player.cam.limit_top = int(bounds.position.y)
	player.cam.limit_bottom = int(bounds.end.y)
	if from_checkpoint and GameState.has_checkpoint:
		player.teleport(GameState.checkpoint_pos)
	else:
		player.teleport(spawn)
	AudioManager.set_intensity(0)
	AudioManager.start_music()
	AudioManager.set_ambience(bg_key)
	await get_tree().process_frame
	on_start(from_checkpoint)


## Bölümler bunu doldurur.
func build() -> void:
	pass


## Bölüm başladığında (ilk kare sonrası) çağrılır.
func on_start(_from_checkpoint: bool) -> void:
	pass


## Yakalanınca: son kandile dön.
func respawn() -> void:
	for e in echoes:
		if is_instance_valid(e):
			e.reset()
	if player:
		var p := GameState.checkpoint_pos if GameState.has_checkpoint else spawn
		player.teleport(p)
		GameState.fuel = maxf(GameState.fuel, 50.0)
		player.lamp.base_mode = Lamp.Mode.NORMAL
		# adalet: yeniden doğuş noktasına çok yakın Yankıları uzaklaştır
		for e in echoes:
			if is_instance_valid(e) and not e.flying and e.global_position.distance_to(p) < 380.0:
				var sx := signf(e.global_position.x - p.x)
				if sx == 0.0:
					sx = 1.0
				e.global_position.x = p.x + sx * 420.0
	on_respawn()


func on_respawn() -> void:
	pass


func on_bell(_pos: Vector2) -> void:
	pass


func _process(_delta: float) -> void:
	_update_visuals(_delta)
	_update_lightning(_delta)
	_update_puddles()
	_update_danger(_delta)
	# yakındaki Yankılara göre müzik yoğunluğu
	if player == null or AudioManager.intensity >= 2:
		return
	var near := false
	for e in echoes:
		if is_instance_valid(e) and e.state in ["hunt", "charge", "lured"]:
			if e.global_position.distance_to(player.global_position) < 700.0:
				near = true
				break
	# histerezis: gerilim müziği hemen kesilmez (2.5 sn bekler)
	if near:
		_music_hold = 2.5
	else:
		_music_hold = maxf(0.0, _music_hold - _delta)
	AudioManager.set_intensity(1 if _music_hold > 0.0 else 0)


var _music_hold := 0.0
var sepia := 0.0                 # 1953 bölümü: eski film tonu
var lens_rain := -1.0            # <0: yağmur varsa otomatik
var _cm: CanvasModulate
var _cm_flash := 0.0
var _bend: Array = []            # Kerem geçerken eğilen otlar
const GRADES := {
	"c1": [Color(0.86, 0.93, 1.1), Color(1.1, 1.0, 0.88)],
	"c2": [Color(0.8, 1.0, 1.06), Color(1.08, 1.0, 0.9)],
	"c3": [Color(0.84, 0.9, 1.14), Color(1.1, 0.98, 0.86)],
	"c5": [Color(0.82, 0.92, 1.12), Color(1.12, 0.98, 0.84)],
}


# ======================================================================= helpers
func next_id(prefix: String) -> String:
	_auto_id += 1
	return "c%d_%s_%d" % [chapter, prefix, _auto_id]


func say_once(id: String, keys: Array, lock := false) -> void:
	if GameState.flag("say_" + id):
		return
	GameState.set_flag("say_" + id)
	await Dialogue.play(keys, lock)


## Sol üst köşe (x, y), genişlik, yükseklik. style: STYLES anahtarı (boşsa bölüm varsayılanı).
func solid(x: float, y: float, w: float, h: float, color := Color(-1, 0, 0), blocks_beam := true, style := "") -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.position = Vector2(x, y)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, h)
	cs.shape = r
	cs.position = Vector2(w, h) / 2.0
	b.add_child(cs)
	var st: String = style if style != "" else default_style
	var pair: Array = STYLES.get(st, STYLES["earth"])
	var tint := Color(1, 1, 1) if color.r < 0.0 else color
	b.add_child(Art.tiled_rect(pair[0], w, h, tint))
	# derinlik gölgesi: yüzeyden aşağı doğru kararır
	if h > 90.0:
		var shade := Polygon2D.new()
		var d := minf(h, 220.0)
		shade.polygon = PackedVector2Array([Vector2(0, 14), Vector2(w, 14), Vector2(w, d), Vector2(0, d)])
		shade.vertex_colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.01, 0.012, 0.02, 0.85), Color(0.01, 0.012, 0.02, 0.85)])
		b.add_child(shade)
		if h > d:
			var deep := ColorRect.new()
			deep.position = Vector2(0, d)
			deep.size = Vector2(w, h - d)
			deep.color = Color(0.01, 0.012, 0.02, 0.85)
			b.add_child(deep)
	# kenar gölgeleri
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2(1, 0), Vector2(1, h), Vector2(w - 1, h), Vector2(w - 1, 0)])
	edge.width = 2.0
	edge.default_color = Color(0.02, 0.025, 0.04, 0.9)
	b.add_child(edge)
	if pair[1] != "" and w > 30.0:
		var top := Art.tiled_rect(pair[1], w, 20)
		top.position = Vector2(0, -12)
		b.add_child(top)
	if blocks_beam:
		var occ := LightOccluder2D.new()
		var op := OccluderPolygon2D.new()
		op.polygon = PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
		occ.occluder = op
		b.add_child(occ)
	_world.add_child(b)
	if auto_scatter and st in ["earth", "earth_dark", "cobble", "rock"] and w >= 160.0 and h >= 30.0:
		_scatter(x, y, w)
	if blocks_beam:
		beam_rects.append(Rect2(x, y, w, h))
	return b


## Zemin: x1..x2 arası, üst yüzeyi top_y.
func ground(x1: float, x2: float, top_y: float, style := "", depth := 900.0) -> StaticBody2D:
	return solid(x1, top_y, x2 - x1, depth, Color(-1, 0, 0), true, style)


## Duvar/tavan: üst şeritsiz.
func wall(x: float, y: float, w: float, h: float, style := "") -> StaticBody2D:
	var st := style
	if st == "":
		st = "rockwall" if default_style == "rock" else "brickwall"
	return solid(x, y, w, h, Color(-1, 0, 0), true, st)


## Tek yönlü platform (alttan geçilebilir): raf, sahanlık.
func ledge(x: float, y: float, w: float, h := 16.0) -> StaticBody2D:
	var b := solid(x, y, w, h, Color(-1, 0, 0), false, "planks")
	var cs: CollisionShape2D = b.get_child(0)
	cs.one_way_collision = true
	return b


func decor_poly(points: Array, color: Color, z := -1) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(points)
	p.color = color
	p.z_index = z
	_decor.add_child(p)
	return p


## Dekor ev: duvar + kiremit çatı + pencereler (lit=true ise sıcak ışıklı pencere).
func house(x: float, ground_y: float, w: float, h: float, roof := 60.0, window := true, lit := false, stone := false) -> void:
	var path := "houses/house_%dx%d_%d_%d%d%d.png" % [int(w), int(h), int(roof), int(window), int(lit), int(stone)]
	if Art.tex(path) != null:
		var sp := Sprite2D.new()
		sp.texture = Art.ctex(path)
		sp.centered = false
		sp.scale = Vector2(Art.SCALE, Art.SCALE)
		sp.position = Vector2(x - 16.0, ground_y - sp.texture.get_size().y * Art.SCALE)
		sp.z_index = -3
		_decor.add_child(sp)
		if w >= 200.0:
			_chimney_smoke(x - 16.0 + (8.0 + w / 2.0 * 0.75) * 2.0 + 6.0, ground_y - h - roof * 0.55 - 34.0)
		if window and lit:
			var n2 := maxi(1, int(w / 140.0))
			for i in n2:
				ambient(x + w * (i + 0.5) / n2, ground_y - h + h * 0.25 + 26.0, 150, 0.29, false, 0.15)
				# pencereden yere düşen sıcak ışık lekesi
				var pool := Sprite2D.new()
				pool.texture = Art.light_texture()
				pool.material = Art.glow_material()
				pool.scale = Vector2(0.9, 0.12)
				pool.modulate = Color(0.55, 0.38, 0.18, 0.55)
				pool.position = Vector2(x + w * (i + 0.5) / n2 + 40.0, ground_y - 2.0)
				pool.z_index = -1
				_decor.add_child(pool)
		return
	var holder := Node2D.new()
	holder.position = Vector2(x, ground_y - h)
	holder.z_index = -3
	_decor.add_child(holder)
	var wall_tex := "tiles/stone_wall.png" if stone else "tiles/wood_wall.png"
	holder.add_child(Art.tiled_rect(wall_tex, w, h, Color(0.75, 0.75, 0.8)))
	var rp := Polygon2D.new()
	rp.polygon = PackedVector2Array([Vector2(-14, 2), Vector2(w / 2.0, -roof), Vector2(w + 14, 2)])
	rp.texture = Art.tex("tiles/roof.png")
	rp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	rp.texture_scale = Vector2(0.5, 0.5)
	holder.add_child(rp)
	var eave := Line2D.new()
	eave.points = PackedVector2Array([Vector2(-14, 2), Vector2(w / 2.0, -roof), Vector2(w + 14, 2)])
	eave.width = 4.0
	eave.default_color = Color(0.05, 0.04, 0.05)
	holder.add_child(eave)
	if window:
		var n := maxi(1, int(w / 140.0))
		for i in n:
			var wx := w * (i + 0.5) / n - 22.0
			var wy := h * 0.25
			var frame := ColorRect.new()
			frame.position = Vector2(wx - 4, wy - 4)
			frame.size = Vector2(52, 60)
			frame.color = Color(0.06, 0.05, 0.05)
			holder.add_child(frame)
			var glass := ColorRect.new()
			glass.position = Vector2(wx, wy)
			glass.size = Vector2(44, 52)
			glass.color = Color(1.0, 0.72, 0.38) if lit else Color(0.03, 0.035, 0.05)
			holder.add_child(glass)
			var bar := ColorRect.new()
			bar.position = Vector2(wx + 20, wy)
			bar.size = Vector2(4, 52)
			bar.color = Color(0.06, 0.05, 0.05)
			holder.add_child(bar)
			if lit:
				ambient(x + wx + 22, ground_y - h + wy + 26, 150, 0.29, false, 0.15)
	var door := ColorRect.new()
	door.position = Vector2(w - 70, h - 90)
	door.size = Vector2(46, 90)
	door.color = Color(0.05, 0.04, 0.04)
	holder.add_child(door)


## Dekor kütüphanesinden obje (art/decor). sway: rüzgarda sallanır. z>0: oyuncunun önünde.
func deco(id: String, x: float, y: float, z := -1, flip := false, sway := 0.0, tint := Color(1, 1, 1)) -> Sprite2D:
	var sp := Art.sprite("decor/%s.png" % id, flip)
	sp.modulate = tint
	if sway > 0.0:
		sp.material = Art.sway_material(sway)
	var holder := Node2D.new()
	holder.position = Vector2(x, y)
	holder.z_index = z
	holder.add_child(sp)
	_decor.add_child(holder)
	if id.begins_with("tuft") or id.begins_with("reed"):
		_bend.append(holder)
	return sp


## Tavandan sarkan dekor (kök, zincir, örümcek ağı): üst-ortası x, y'de.
func hang(id: String, x: float, y: float, sway := 1.2) -> Sprite2D:
	var sp := Art.sprite("decor/%s.png" % id)
	sp.position.y = 0
	if sway > 0.0:
		sp.material = Art.sway_material(sway, true)
	var holder := Node2D.new()
	holder.position = Vector2(x, y)
	holder.z_index = -1
	holder.add_child(sp)
	_decor.add_child(holder)
	return sp


## Zemin yüzeyine deterministik ot/taş serpiştirme.
func _scatter(x: float, y: float, w: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x * 31.0 + y * 17.0) + chapter * 1000
	var cx := x + rng.randf_range(10.0, 60.0)
	while cx < x + w - 20.0:
		var nm: String = scatter_set[rng.randi() % scatter_set.size()]
		var front := rng.randf() < 0.22 and nm.begins_with("tuft")
		var tint := Color(0.75, 0.78, 0.85) if not front else Color(0.45, 0.48, 0.55)
		deco(nm, cx, y + 2.0, 3 if front else -1, rng.randf() < 0.5, 1.4 if nm.begins_with("tuft") else 0.0, tint)
		if nm == "mushrooms":
			_glow_mushroom(cx, y, rng.randf() < 0.4)
		if weather_rain and rng.randf() < 0.12:
			puddle(cx + 40.0, y)
		cx += rng.randf_range(50.0, 150.0)


## Mağara mantarları hafif deniz yeşili parlar (bazıları gerçek ışık yayar).
func _glow_mushroom(x: float, y: float, real_light: bool) -> void:
	var g := Sprite2D.new()
	g.texture = Art.tex("fx/glow.png")
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	g.material = Art.glow_material()
	g.modulate = Color(0.35, 0.95, 0.85, 0.35)
	g.scale = Vector2(0.5, 0.35)
	g.position = Vector2(x, y - 10.0)
	g.z_index = -1
	_decor.add_child(g)
	var tw := g.create_tween().set_loops()
	tw.tween_property(g, "modulate:a", 0.15, randf_range(1.6, 2.8)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(g, "modulate:a", 0.4, randf_range(1.6, 2.8)).set_trans(Tween.TRANS_SINE)
	if real_light:
		ambient(x, y - 14.0, 85.0, 0.18, false, 0.0, Color(0.4, 0.95, 0.85))


## Sprite dekor (alt-ortası x, y'de).
func prop(path: String, x: float, y: float, z := -1, flip := false) -> Sprite2D:
	var sp := Art.sprite("props/%s.png" % path if not path.contains("/") else path, flip)
	var holder := Node2D.new()
	holder.position = Vector2(x, y)
	holder.z_index = z
	holder.add_child(sp)
	_decor.add_child(holder)
	return sp


func label_decor(text: String, pos: Vector2, size := 28, color := Color(0.75, 0.75, 0.7, 0.8)) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_world.add_child(l)
	return l


func brazier(id: String, x: float, y: float, checkpoint := true, beam_ignitable := false, chase := false) -> Brazier:
	var b := Brazier.new()
	b.id = id
	b.checkpoint = checkpoint
	b.beam_ignitable = beam_ignitable
	b.chase = chase
	b.position = Vector2(x, y)
	_world.add_child(b)
	return b


func pickup(kind: String, x: float, y: float, id := "", keys: Array = []) -> Pickup:
	var p := Pickup.new()
	p.kind = kind
	p.id = id if id != "" else next_id(kind)
	p.keys = keys
	p.position = Vector2(x, y)
	_world.add_child(p)
	return p


func echo(kind: int, x: float, y: float, forced := false, lure: Array = []) -> Echo:
	var e := Echo.new()
	e.forced_hunt = forced
	e.lure_keys = lure
	e.setup(kind, Vector2(x, y))
	_world.add_child(e)
	echoes.append(e)
	return e


func trigger(id: String, rect: Rect2, cb: Callable, once := true) -> Zone:
	var z := Zone.new()
	z.mode = "trigger"
	z.id = id
	z.once = once
	z.callback = cb
	z.size = rect.size
	z.position = rect.position
	if id != "" and once and GameState.flag("trg_" + id):
		z._fired = true
	_world.add_child(z)
	return z


func kill_zone(rect: Rect2) -> Zone:
	var z := Zone.new()
	z.mode = "kill"
	z.size = rect.size
	z.position = rect.position
	_world.add_child(z)
	return z


func crate(id: String, x: float, y: float) -> Crate:
	var c := Crate.new()
	c.id = id
	c.position = Vector2(x, y)
	_world.add_child(c)
	return c


func mover(id: String, rect: Rect2, travel: Vector2, duration := 1.6) -> Mover:
	var m := Mover.new()
	m.id = id
	m.size = rect.size
	m.travel = travel
	m.duration = duration
	m.position = rect.position
	_world.add_child(m)
	return m


func crumble(x: float, y: float, w: float) -> Crumble:
	var c := Crumble.new()
	c.width = w
	c.position = Vector2(x, y)
	_world.add_child(c)
	return c


func mirror(x: float, y: float, angle: float, rotatable := true, stand := 60.0) -> Mirror:
	var m := Mirror.new()
	m.angle_deg = angle
	m.rotatable = rotatable
	m.stand_height = stand
	m.position = Vector2(x, y)
	_world.add_child(m)
	return m


func lens(x: float, y: float) -> BeamTarget:
	var t := BeamTarget.new()
	t.kind = "lens"
	t.position = Vector2(x, y)
	_world.add_child(t)
	return t


func seal(id: String, x: float, y: float) -> BeamTarget:
	var t := BeamTarget.new()
	t.kind = "seal"
	t.id = id
	t.position = Vector2(x, y)
	_world.add_child(t)
	return t


func red_text(key: String, x: float, y: float) -> RedText:
	var r := RedText.new()
	r.key = key
	r.position = Vector2(x, y)
	_world.add_child(r)
	return r


func ambient(x: float, y: float, r: float, intensity := 0.6, safe := false, flicker := 0.0, col := Color(1.0, 0.72, 0.42)) -> AmbientLight:
	var a := AmbientLight.new()
	a.color = col
	a.light_radius = r
	a.intensity = intensity
	a.safe = safe
	a.flicker = flicker
	a.position = Vector2(x, y)
	_world.add_child(a)
	return a


func interactable(x: float, y: float, prompt: String, cb: Callable, once := true, hold := 0.0) -> Interactable:
	var i := Interactable.new()
	i.prompt = prompt
	i.on_use = cb
	i.once = once
	i.hold_time = hold
	i.position = Vector2(x, y)
	_world.add_child(i)
	return i


## Winch: basılı tutulur, sonra cb çalışır.
func winch(id: String, x: float, y: float, cb: Callable) -> Interactable:
	var use := func():
		GameState.set_flag("winch_" + id)
		AudioManager.play_sfx("door", -2.0, 1.3)
		cb.call()
	var w := interactable(x, y - 30, "INT_WINCH", use, true, 1.5)
	w.condition = func(): return not GameState.flag("winch_" + id)
	var spr := Art.sprite("props/winch.png")
	spr.position.y += 30
	w.add_child(spr)
	return w


func water(x: float, y: float, w: float, depth := 700.0) -> Water:
	var wt := Water.new()
	wt.width = w
	wt.depth = depth
	wt.position = Vector2(x, y)
	_world.add_child(wt)
	return wt


func add_world(n: Node) -> void:
	_world.add_child(n)


## Gizli alan: içine girilince önündeki sahte duvar saydamlaşır.
func secret(rect: Rect2, style := "") -> void:
	var st := style if style != "" else ("rockwall" if default_style == "rock" else "brickwall")
	var pair: Array = STYLES.get(st, STYLES["brickwall"])
	var cover := Art.tiled_rect(pair[0], rect.size.x, rect.size.y)
	cover.position = rect.position
	cover.z_index = 4
	_world.add_child(cover)
	var z := Zone.new()
	z.mode = "trigger"
	z.once = false
	z.size = rect.size
	z.position = rect.position
	_world.add_child(z)
	z.body_entered.connect(_secret_fade.bind(cover, 0.15))
	z.body_exited.connect(_secret_fade.bind(cover, 1.0))


func _secret_fade(b: Node, cover: Polygon2D, a: float) -> void:
	if b is Kerem:
		create_tween().tween_property(cover, "modulate:a", a, 0.4)


## Telsiz direği: isteğe bağlı Rıza Reis sohbeti.
func antenna(x: float, y: float, keys: Array, id: String) -> void:
	var holder := Node2D.new()
	holder.position = Vector2(x, y)
	holder.z_index = -1
	_decor.add_child(holder)
	var pole := Line2D.new()
	pole.points = PackedVector2Array([Vector2(0, 0), Vector2(0, -130)])
	pole.width = 4.0
	pole.default_color = Color(0.18, 0.18, 0.2)
	holder.add_child(pole)
	for i in 3:
		var bar := Line2D.new()
		bar.points = PackedVector2Array([Vector2(-14 + i * 4, -120 + i * 18), Vector2(14 - i * 4, -120 + i * 18)])
		bar.width = 3.0
		bar.default_color = Color(0.18, 0.18, 0.2)
		holder.add_child(bar)
	ambient(x, y - 132, 40, 0.25, false, 0.8, Color(1.0, 0.3, 0.25))
	var it := interactable(x, y - 40, "INT_ANTENNA", say_once.bind(id, keys), true)
	it.condition = func(): return GameState.has_radio and not GameState.flag("say_" + id)


func objective(key: String, target := Vector2.INF) -> void:
	if GameState.hud:
		GameState.hud.set_objective(Loc.t(key), target)
	GameState.set_flag("objective", key)


## Arka planda koşup kaybolan gölge (tempo için korkutma anı).
func shadow_run(x_from: float, x_to: float, y: float, dur := 1.4) -> void:
	var s := Art.animated("chars/echo_mimic.png", 20, 44, {"move": [0, 6, 14, true]}, "move")
	var holder := Node2D.new()
	holder.position = Vector2(x_from, y)
	holder.z_index = -2
	holder.modulate = Color(0.5, 0.55, 0.65, 0.85)
	s.flip_h = x_to < x_from
	holder.add_child(s)
	_decor.add_child(holder)
	AudioManager.play_sfx("whisper", -8.0, 1.3)
	var tw := create_tween()
	tw.tween_property(holder, "position:x", x_to, dur)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, dur).set_delay(dur * 0.6)
	tw.tween_callback(holder.queue_free)


func _chimney_smoke(x: float, y: float) -> void:
	var p := CPUParticles2D.new()
	p.texture = Art.tex("fx/mote.png")
	p.position = Vector2(x, y)
	p.z_index = -4
	p.amount = 18
	p.lifetime = 4.5
	p.preprocess = 4.5
	p.direction = Vector2(-0.3, -1)
	p.spread = 12.0
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 24.0
	p.gravity = Vector2(-10, -4)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.58, 0.65, 0.35))
	g.set_color(1, Color(0.55, 0.58, 0.65, 0.0))
	p.color_ramp = g
	_decor.add_child(p)


## Su birikintisi: yakındaki ışıkları yansıtır, yağmurda halka halka dalgalanır.
func puddle(x: float, y: float) -> void:
	var holder := Node2D.new()
	holder.position = Vector2(x, y)
	holder.z_index = 1
	_decor.add_child(holder)
	var sp := Art.sprite_c("decor/puddle.png")
	sp.position = Vector2(0, 2)
	holder.add_child(sp)
	var refl := Sprite2D.new()
	refl.texture = Art.tex("fx/glow.png")
	refl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	refl.material = Art.glow_material()
	refl.scale = Vector2(0.55, 0.06)
	refl.position = Vector2(0, 2)
	refl.modulate = Color(1, 0.7, 0.4, 0.0)
	holder.add_child(refl)
	_puddles.append(refl)
	if weather_rain:
		var r := CPUParticles2D.new()
		r.texture = Art.tex("fx/mote.png")
		r.position = Vector2(0, 2)
		r.amount = 4
		r.lifetime = 0.6
		r.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		r.emission_rect_extents = Vector2(36, 1)
		r.direction = Vector2(0, -1)
		r.spread = 60.0
		r.initial_velocity_min = 20.0
		r.initial_velocity_max = 40.0
		r.gravity = Vector2(0, 120)
		r.scale_amount_min = 0.5
		r.scale_amount_max = 1.0
		r.color = Color(0.7, 0.75, 0.85, 0.6)
		holder.add_child(r)


func _update_puddles() -> void:
	if _puddles.is_empty():
		return
	var circles := LightSystem.gather_circles()
	for refl in _puddles:
		var sp: Sprite2D = refl
		var best := 0.0
		var gp := sp.global_position
		for c in circles:
			var v: Vector4 = c
			var d := Vector2(v.x, v.y).distance_to(gp)
			if d < v.z * 1.4:
				best = maxf(best, (1.0 - d / (v.z * 1.4)) * v.w)
		sp.modulate.a = lerpf(sp.modulate.a, best * 0.9, 0.2)


## Ayak tozu.
func dust(pos: Vector2, amount := 5) -> void:
	if not is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 40.0
	p.gravity = Vector2(0, 40)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color = Color(0.6, 0.68, 0.8, 0.55) if weather_rain else Color(0.45, 0.48, 0.55, 0.5)
	if weather_rain:
		# ıslak zemin: toz yerine su sıçraması
		p.gravity = Vector2(0, 420)
		p.initial_velocity_min = 50.0
		p.initial_velocity_max = 110.0
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.0
	_world.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _setup_weather() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	if weather_rain:
		var r := CPUParticles2D.new()
		r.texture = Art.tex("fx/rain.png")
		r.position = Vector2(1100, -40)
		r.amount = 260
		r.lifetime = 1.2
		r.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		r.emission_rect_extents = Vector2(1300, 10)
		r.direction = Vector2(-0.25, 1)
		r.spread = 2.0
		r.gravity = Vector2.ZERO
		r.initial_velocity_min = 950.0
		r.initial_velocity_max = 1150.0
		r.scale_amount_min = 2.0
		r.scale_amount_max = 3.0
		r.modulate = Color(1, 1, 1, 0.5)
		layer.add_child(r)
		_rain = r
	if weather_rain:
		_splash = CPUParticles2D.new()
		_splash.texture = Art.tex("fx/mote.png")
		_splash.amount = 40
		_splash.lifetime = 0.35
		_splash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_splash.emission_rect_extents = Vector2(900, 1)
		_splash.direction = Vector2(0, -1)
		_splash.spread = 70.0
		_splash.initial_velocity_min = 25.0
		_splash.initial_velocity_max = 55.0
		_splash.gravity = Vector2(0, 260)
		_splash.scale_amount_min = 0.5
		_splash.scale_amount_max = 1.0
		_splash.color = Color(0.7, 0.75, 0.85, 0.5)
		_splash.local_coords = false
		_world.add_child(_splash)
	if bg_key == "c2":
		# mağara: havada süzülen parlak sporlar
		var sp := CPUParticles2D.new()
		sp.texture = Art.tex("fx/mote.png")
		sp.material = Art.glow_material()
		sp.position = Vector2(960, 540)
		sp.amount = 26
		sp.lifetime = 9.0
		sp.preprocess = 9.0
		sp.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		sp.emission_rect_extents = Vector2(980, 560)
		sp.direction = Vector2(0.3, -1)
		sp.spread = 60.0
		sp.gravity = Vector2(0, -3)
		sp.initial_velocity_min = 5.0
		sp.initial_velocity_max = 16.0
		sp.scale_amount_min = 1.0
		sp.scale_amount_max = 2.0
		var sg := Gradient.new()
		sg.set_color(0, Color(0.4, 0.95, 0.85, 0.0))
		sg.add_point(0.3, Color(0.4, 0.95, 0.85, 0.55))
		sg.set_color(2, Color(0.4, 0.95, 0.85, 0.0))
		sp.color_ramp = sg
		layer.add_child(sp)
	if weather_motes:
		var m := CPUParticles2D.new()
		m.texture = Art.tex("fx/mote.png")
		m.position = Vector2(960, 540)
		m.amount = 40
		m.lifetime = 8.0
		m.preprocess = 8.0
		m.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		m.emission_rect_extents = Vector2(980, 560)
		m.direction = Vector2(1, -0.2)
		m.spread = 180.0
		m.gravity = Vector2(0, -2)
		m.initial_velocity_min = 4.0
		m.initial_velocity_max = 14.0
		m.modulate = Color(1, 1, 1, 0.35)
		layer.add_child(m)


var _heart_t := 0.0


## En yakın avlanan Yankıya göre ekran kenarında nabız ve kalp atışı; Büyük Yankıya yakınken ekran bozulur.
func _update_danger(delta: float) -> void:
	if player == null:
		return
	var danger := 0.0
	var ab := 0.0
	for e in get_tree().get_nodes_in_group("echo"):
		if not is_instance_valid(e):
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if e is GreatEcho:
			if not e.tame:
				var dx: float = player.global_position.x - e.global_position.x
				danger = maxf(danger, clampf(1.0 - dx / 700.0, 0.0, 1.0))
				ab = maxf(ab, clampf(1.0 - dx / 600.0, 0.0, 1.0))
		elif e.state in ["hunt", "charge", "lured"]:
			danger = maxf(danger, clampf(1.0 - d / 520.0, 0.0, 1.0))
	if GameState.hud:
		GameState.hud.set_danger(danger)
	if _post_mat:
		_post_mat.set_shader_parameter("aberration", ab * 1.4)
	if danger > 0.15:
		_heart_t -= delta
		if _heart_t <= 0.0:
			_heart_t = lerpf(1.1, 0.42, danger)
			AudioManager.play_sfx("heart", lerpf(-18.0, -4.0, danger))
			if danger > 0.7:
				GameState.rumble(0.15, 0.0, 0.08)


func enable_leaves() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	_leaves = CPUParticles2D.new()
	_leaves.texture = Art.tex("fx/leaf.png")
	_leaves.position = Vector2(2000, 500)
	_leaves.amount = 26
	_leaves.lifetime = 3.0
	_leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_leaves.emission_rect_extents = Vector2(40, 480)
	_leaves.direction = Vector2(-1, 0.1)
	_leaves.spread = 15.0
	_leaves.initial_velocity_min = 600.0
	_leaves.initial_velocity_max = 900.0
	_leaves.angular_velocity_min = -360.0
	_leaves.angular_velocity_max = 360.0
	_leaves.gravity = Vector2(0, 60)
	_leaves.scale_amount_min = 2.0
	_leaves.scale_amount_max = 3.5
	_leaves.emitting = false
	layer.add_child(_leaves)


func _update_weather_follow() -> void:
	var w := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * 0.06) * sin(Time.get_ticks_msec() / 1000.0 * 0.023 + 1.0)
	if _rain:
		_rain.modulate.a = clampf(w, 0.35, 1.0)
	if _splash:
		_splash.modulate.a = clampf(w, 0.35, 1.0)
	if _splash and player:
		_splash.global_position = Vector2(player.global_position.x, player.global_position.y if player.is_on_floor() else _splash.global_position.y)
	if _leaves and player:
		_leaves.emitting = absf(player.wind) > 20.0


func _update_lightning(delta: float) -> void:
	_update_weather_follow()
	if not lightning:
		return
	_lightning_t -= delta
	if _lightning_t <= 0.0:
		_lightning_t = randf_range(16.0, 34.0)
		strike_lightning()


## Grafik: şimşekte dünya aydınlanır, yakıt azalınca renkler solar, otlar eğilir.
func _update_visuals(delta: float) -> void:
	if _cm:
		_cm_flash = maxf(0.0, _cm_flash - delta * 2.2)
		_cm.color = ambient_color.lerp(Color(0.78, 0.84, 1.0), _cm_flash)
	if _post_mat:
		var fl := 0.0
		if darkness:
			fl = clampf(float(darkness.flash) * 0.22, 0.0, 0.2)
		_post_mat.set_shader_parameter("flash", fl)
		var sat := 0.88
		if GameState.has_lamp and GameState.fuel < 25.0:
			sat = lerpf(0.5, 0.88, GameState.fuel / 25.0)
		_post_mat.set_shader_parameter("saturation", sat)
	if player == null or _bend.is_empty():
		return
	var px: float = player.global_position.x
	var py: float = player.global_position.y
	var pv: float = player.velocity.x
	for h in _bend:
		var n: Node2D = h
		var dx := n.position.x - px
		var want := 0.0
		if absf(dx) < 34.0 and absf(n.position.y - py) < 50.0:
			want = clampf(pv / 300.0, -1.0, 1.0) * 0.55 * (1.0 - absf(dx) / 34.0)
		n.skew = lerpf(n.skew, want, 10.0 * delta)


func strike_lightning() -> void:
	_cm_flash = 1.0
	if darkness:
		darkness.flash = 0.55
	if background:
		background.flash = 1.0
		background.bolt()
	await get_tree().create_timer(randf_range(0.4, 1.0)).timeout
	AudioManager.play_sfx("thunder")
	GameState.rumble(0.3, 0.3, 0.5)
	if player:
		player.shake(3.0, 0.6)


func chapter_done() -> void:
	if GameState.main:
		GameState.main.chapter_complete(chapter)
