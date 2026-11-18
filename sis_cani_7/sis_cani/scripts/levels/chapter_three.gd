class_name ChapterThree
extends LevelBase
## BÖLÜM 3: FENER KULESİ VE SONLAR
## 3-1 kule tabanı (ayna) · 3-2 sarmal merdiven · 3-3 bekçi odası · 3-4 dış balkon (rüzgar, Baba'nın Yankısı)
## 3-5 mekanizma odası (3 dişli) · 3-6 mercek odası → seçim: Son A "Çan" / Son B "Sessizlik"

const T := -2470.0          # kule tepe katı zemini
const STEP := 95.0
const PATTERN := [1540.0, 1840.0, 2140.0, 2400.0, 2140.0, 1840.0]
const PLAT_W := 260.0

var _door: Mover
var _hatch: Mover
var _rope: Interactable
var _yusuf: Interactable
var _ending := false


func _init() -> void:
	super()
	chapter = 3
	spawn = Vector2(120, 0)
	bounds = Rect2(-200, -3400, 7000, 3700)
	dark_value = 0.3
	ambient_color = Color(0.36, 0.4, 0.54)
	fog_amount = 0.2
	bg_key = "c3"
	default_style = "earth"
	weather_rain = true
	lightning = true


func build() -> void:
	wall(-200, -3400, 20, 3700, "stone")

	# ---------------------------------------------------------- 3-1 KULE TABANI
	ground(-200, 2720, 0)
	brazier("b1", 400, 0)
	mirror(900, -60, 0.0, true, 60.0)
	mirror(900, -500, -45.0, false, 0.0)
	solid(1250, -460, 200, 40, Color(-1, 0, 0), true, "stone")
	var b2 := brazier("b2", 1350, -460, false, true)
	_door = mover("c3_door", Rect2(1480, -300, 40, 300), Vector2(0, -300))
	trigger("c3_door_obj", Rect2(600, -300, 60, 300), _door_goal)
	b2.lit.connect(func(): _door.activate())
	pickup("oil", 1150, -20)

	# ---------------------------------------------------------- 3-2 SARMAL MERDİVEN
	var inner := Art.tiled_rect("tiles/brick.png", 1160, -T + 340, Color(0.42, 0.44, 0.5))
	inner.position = Vector2(1520, T - 340)
	inner.z_index = -4
	add_world(inner)                                  # kulenin iç duvarı (arka plan)
	wall(1480, T - 340, 40, -300.0 - (T - 340), "brickwall")   # sol duvar (kapının üstü)
	wall(2680, T, 40, -T, "brickwall")                # sağ duvar (alt)
	wall(2680, T - 340, 40, 140, "brickwall")         # sağ duvar (balkon kapısının üstü)
	wall(1480, T - 380, 1240, 40, "brickwall")        # oda tavanı
	solid(1820, T, 860, 40, Color(-1, 0, 0), true, "brick")   # tepe kat zemini
	trigger("c3_stairs", Rect2(1560, -200, 60, 200), _stairs)
	for i in range(1, 26):
		var x: float = PATTERN[(i - 1) % 6]
		var y := -STEP * i
		if i % 5 == 0 and i != 25:
			crumble(x, y, PLAT_W)
		else:
			ledge(x, y, PLAT_W, 18.0)
		if i == 9:
			brazier("b2s", x + PLAT_W / 2.0, y)
		elif i == 18:
			brazier("b3", x + PLAT_W / 2.0, y)
		elif i == 12:
			pickup("page", x + 130, y - 22, "P09")
		elif i == 24:
			pickup("gear", x + 130, y - 22, "c3_gear1")
		elif i == 7 or i == 16:
			echo(Echo.Kind.CRAWLER, x + 200, y)
		elif i == 14:
			echo(Echo.Kind.MIMIC, x + 200, y, false, ["M3_01"])
		elif i == 15:
			trigger("c3_m3", Rect2(x, y - 140, PLAT_W, 140), func(): say_once("c3_m3", ["M3_02"]))
		elif i == 21:
			pickup("oil", x + 130, y - 20)

	# ---------------------------------------------------------- 3-3 BEKÇİ ODASI
	prop("desk", 2030, T, -1)
	prop("photo", 2020, T - 60, 0)
	interactable(2020, T - 40, "INT_LOOK", func(): say_once("c3_photo", ["C3_020"]))
	prop("letters", 2290, T, 0)
	interactable(2290, T - 30, "INT_LOOK", func(): say_once("c3_letters", ["C3_021"]))
	pickup("page", 2170, T - 22, "P10")
	brazier("b4", 2450, T)
	pickup("gear", 2600, T - 22, "c3_gear2")

	# ---------------------------------------------------------- 3-4 DIŞ BALKON
	solid(2720, T, 480, 40, Color(-1, 0, 0), true, "stone")
	solid(3300, T, 400, 40, Color(-1, 0, 0), true, "stone")
	solid(3790, T, 2850, 40, Color(-1, 0, 0), true, "stone")
	kill_zone(Rect2(2720, T + 380, 1700, 400))
	for x in range(2740, 4400, 60):
		if (x > 3200 and x < 3300) or (x > 3700 and x < 3790):
			continue
		decor_poly([Vector2(x, T), Vector2(x + 4, T), Vector2(x + 4, T - 46), Vector2(x, T - 46)], Color(0.12, 0.12, 0.14))
	trigger("c3_father", Rect2(2920, T - 200, 60, 200), _father_echo)
	trigger("c3_top", Rect2(1900, T - 200, 60, 200), _gear_goal, false)
	trigger("c3_mech_area", Rect2(4420, T - 200, 60, 200), _gear_goal, false)
	pickup("page", 3960, T - 22, "P11")
	pickup("gear", 4300, T - 22, "c3_gear3")

	# ---------------------------------------------------------- 3-5 MEKANİZMA ODASI
	var inner2 := Art.tiled_rect("tiles/brick.png", 2200, 340, Color(0.42, 0.44, 0.5))
	inner2.position = Vector2(4400, T - 340)
	inner2.z_index = -4
	add_world(inner2)
	wall(4400, T - 380, 2250, 40, "brickwall")   # tavan
	wall(6600, T - 1000, 40, 1100, "brickwall")  # sağ duvar
	brazier("b5", 4560, T)
	pickup("page", 4720, T - 22, "P12")
	var mech := interactable(4920, T - 40, "INT_MECH", _mechanism, false)
	mech.condition = func(): return not _hatch.activated
	var ms := Art.sprite("props/mechanism.png")
	ms.position.y += 40
	mech.add_child(ms)
	_hatch = mover("c3_hatch", Rect2(5150, T - 340, 40, 340), Vector2(0, -340))
	_hatch.tex_path = "tiles/brick.png"

	# ---------------------------------------------------------- 3-6 MERCEK ODASI
	prop("lens_big", 5900, T - 30, -1)
	prop("big_bell", 5350, T - 236, 0)
	decor_poly([Vector2(5348, T - 236), Vector2(5352, T - 236), Vector2(5352, T - 40), Vector2(5348, T - 40)], Color(0.55, 0.48, 0.36))   # çan ipi
	prop("chars/yusuf_lying.png", 6130, T, 0)
	ambient(6120, T - 30, 120, 0.25, false, 0.5)
	dress()
	trigger("c3_final", Rect2(5420, T - 200, 60, 200), _final_talk)
	_rope = interactable(5350, T - 40, "INT_BELL_ROPE", _ending_a, true, 3.0)
	_rope.enabled = GameState.flag("c3_talk_done")
	_yusuf = interactable(6110, T - 30, "INT_YUSUF", _ending_b, true)
	_yusuf.enabled = GameState.flag("c3_talk_done")


## Set dekoru: kule pencereleri, örümcek ağları, zincirler, bekçi eşyaları.
func dress() -> void:
	deco("dead_tree", 240, 0, -2)
	deco("rock_b", 560, 0)
	deco("fence_broken", 700, 0)
	deco("bush", 1180, 0, -1, false, 0.0, Color(0.8, 0.85, 0.9))
	deco("anchor", 1420, 0)
	for y in [-420.0, -1000.0, -1600.0, -2150.0]:
		var wnd := deco("tower_window", 2100, y, -3)
		wnd.modulate = Color(0.8, 0.85, 0.95)
		ambient(2100, y - 30, 170, 0.25, false, 0.0, Color(0.55, 0.68, 1.0))
	for y in [-700.0, -1400.0, -2000.0]:
		hang("cobweb", 1520, y, 0.0)
	hang("chain", 2620, T - 340, 0.6)
	deco("barrel", 2560, T)
	deco("crates", 1900, T)
	deco("candles", 2030, T - 58)
	hang("lantern_hang", 2350, T - 340, 0.4)
	hang("cobweb", 4440, T - 340, 0.0)
	deco("barrel", 4700, T)
	deco("crates", 5050, T)
	hang("chain", 5600, T - 340, 0.7)
	hang("chain", 6300, T - 340, 0.7)
	hang("cobweb", 6560, T - 340, 0.0).flip_h = true
	# --- genişletme: babanın teknesi, telsiz, iç sesler, gizli oda, Fısıltılar
	var wr := deco("wreck", 1080, 6, -1)
	wr.modulate = Color(0.85, 0.85, 0.9)
	label_decor("YILDIZ", Vector2(1030, -40), 18, Color(0.85, 0.82, 0.7, 0.7))
	interactable(1080, -40, "INT_WRECK", say_once.bind("c3_wreck", ["W_01", "W_02"]))
	antenna(300, 0, ["RT_05", "RT_06"], "c3_rt_a")
	antenna(2900, T, ["RT_07", "RT_08"], "c3_rt_b")
	trigger("c3_in4", Rect2(1840, -1000, 200, 60), func(): say_once("c3_in4", ["IN_04"]))
	interactable(2560, T - 40, "INT_LOOK", say_once.bind("c3_in5", ["IN_05"]))
	secret(Rect2(1530, -240, 150, 240), "brickwall")
	pickup("wick", 1600, -24, "c3_wick")
	pickup("tape", 2420, T - 20, "Y01", ["Y01"])
	pickup("tape", 3620, T - 20, "Y02", ["Y02"])
	pickup("tape", 4820, T - 20, "Y03", ["Y03"])
	# kule pencerelerinden süzülen ışık huzmeleri
	for gx in [2250.0, 3300.0, 4400.0, 5800.0]:
		_god_ray(gx, T - 330.0)
	echo(Echo.Kind.WHISPER, 2200, -2000)
	echo(Echo.Kind.WHISPER, 3500, T - 120)


func _process(delta: float) -> void:
	super(delta)
	if player == null:
		return
	# balkonda rüzgar (sola iten hamleler)
	var p := player.global_position
	if p.x > 2720.0 and p.x < 4400.0 and p.y < T + 50.0 and p.y > T - 400.0:
		var t := Time.get_ticks_msec() / 1000.0
		player.wind = -110.0 * clampf(sin(t * 0.9) * 1.4, 0.0, 1.0)
	else:
		player.wind = 0.0


# ---------------------------------------------------------------- events
func _door_goal() -> void:
	if not _door.activated:
		objective("OBJ_C3_DOOR", Vector2(900, -60))


func _stairs() -> void:
	objective("OBJ_C3_CLIMB", Vector2(1700, T - 60))
	say_once("c3_st", ["C3_010"])


func _gear_goal() -> void:
	if GameState.gears < 3:
		objective("OBJ_C3_GEARS", Vector2(4300, T - 60))
	else:
		objective("OBJ_C3_MECH", Vector2(4920, T - 60))


func _father_echo() -> void:
	strike_lightning()
	var ghost := AmbientLight.new()
	ghost.light_radius = 90.0
	ghost.intensity = 0.2
	ghost.color = Color(0.6, 0.7, 1.0)
	ghost.position = Vector2(3400, T + 260)
	add_world(ghost)
	var fe := prop("chars/echo_mimic.png", 3400, T + 300, -1)
	fe.modulate = Color(0.7, 0.75, 0.85, 0.7)
	await Dialogue.play(["C3_030", "C3_031", "C3_032", "C3_033", "C3_034"])
	ghost.queue_free()


func _mechanism() -> void:
	if GameState.gears < 3:
		if GameState.hud:
			GameState.hud.toast(Loc.t("HINT_NEED_GEARS") + " (%d/3)" % GameState.gears)
		return
	await Dialogue.play(["C3_040"])
	AudioManager.play_sfx("door", 0.0, 0.7)
	player.shake(5.0, 1.2)
	_hatch.activate()
	objective("OBJ_C3_LENS", Vector2(5450, T - 60))


func _final_talk() -> void:
	await Dialogue.play(["C3_050", "C3_051", "C3_052", "C3_053", "C3_054", "C3_055", "C3_056", "C3_057",
		"C3_058", "C3_059", "C3_060", "C3_061", "C3_062", "C3_063"], true)
	GameState.set_flag("c3_talk_done")
	GameState.save_game()
	_rope.enabled = true
	_yusuf.enabled = true
	objective("OBJ_C3_CHOICE")


func _ending_a() -> void:
	if _ending:
		return
	_ending = true
	_yusuf.enabled = false
	GameState.input_locked += 1
	await Dialogue.play(["EA_000"], false)
	AudioManager.play_sfx("bell_big")
	darkness.flash = 1.0
	background.tower_light = 1.0
	for e in echoes:
		if is_instance_valid(e):
			var tw := create_tween()
			tw.tween_property(e, "modulate:a", 0.0, 1.5)
			tw.tween_callback(e.queue_free)
	var tw2 := create_tween()
	tw2.tween_property(self, "dark_value", 0.25, 4.0)
	ambient(5900, T - 190, 900, 1.0, true)
	if GameState.hud:
		GameState.hud.clear_objective()
	await get_tree().create_timer(2.0).timeout
	await Dialogue.play(["EA_001", "EA_002", "EA_003", "EA_004", "EA_005", "EA_006"], false)
	GameState.input_locked = maxi(0, GameState.input_locked - 1)
	GameState.main.finish_ending("A")


func _ending_b() -> void:
	if _ending:
		return
	_ending = true
	_rope.enabled = false
	await Dialogue.play(["EB_000", "EB_001", "EB_002"], true)
	GameState.main.ending_escape()


func on_start(from_checkpoint: bool) -> void:
	enable_leaves()
	if not from_checkpoint:
		objective("OBJ_C3_DOOR", Vector2(900, -60))
		await Dialogue.play(["C3_000", "C3_001", "C3_002"])
		Dialogue.play(["C3_090"])
	elif GameState.flag("c3_talk_done"):
		objective("OBJ_C3_CHOICE")
	elif player.global_position.y < T + 100:
		_gear_goal()
	else:
		objective("OBJ_C3_CLIMB", Vector2(1700, T - 60))


func _god_ray(x: float, y: float) -> void:
	var ray := Polygon2D.new()
	ray.polygon = PackedVector2Array([Vector2(0, 0), Vector2(46, 0), Vector2(190, 330), Vector2(60, 330)])
	ray.vertex_colors = PackedColorArray([Color(0.75, 0.82, 1.0, 0.22), Color(0.75, 0.82, 1.0, 0.22), Color(0.75, 0.82, 1.0, 0.0), Color(0.75, 0.82, 1.0, 0.0)])
	ray.material = Art.glow_material()
	ray.position = Vector2(x, y)
	ray.z_index = 2
	add_world(ray)
	var tw := ray.create_tween().set_loops()
	tw.tween_property(ray, "modulate:a", 0.45, randf_range(2.5, 4.0)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ray, "modulate:a", 1.0, randf_range(2.5, 4.0)).set_trans(Tween.TRANS_SINE)
