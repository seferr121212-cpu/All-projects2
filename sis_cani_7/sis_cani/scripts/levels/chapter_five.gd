class_name ChapterFive
extends LevelBase
## BÖLÜM 5 (oyunda "Bölüm III"): FABRİKA VE DALGAKIRAN
## 5-1 kuzey kıyısı · 5-2 su basmış avlu (savak + sandık) · 5-3 fabrika salonu (mesai kartları, aynalar, kepenk)
## 5-4 kazan dairesi (kazan + düdük) · 5-5 dalgakıran (yükselen gelgit) → fener kulesi

const PIT_X := 1700.0
const PIT_W := 1000.0
const PIT_D := 160.0
const ROOF := -520.0
const TIDE_START := 70.0
const TIDE_END := -60.0
const TIDE_SPEED := 1.45

const OBJ_POS := {
	"OBJ_C5_FACTORY": Vector2(1600, -60),
	"OBJ_C5_SLUICE": Vector2(1600, -60),
	"OBJ_C5_CRATE": Vector2(2640, 100),
	"OBJ_C5_SHUTTER": Vector2(3950, -100),
	"OBJ_C5_BOILER": Vector2(5800, -60),
	"OBJ_C5_BREAKWATER": Vector2(9500, -80),
}

var _pit_water: Water
var _sea: Water
var _shutter: Mover
var _iron: Mover
var _boiler_light: AmbientLight
var _boiler_fire: CPUParticles2D
var _boiler_ready := false
var _tide_on := false
var _ending := false


func _init() -> void:
	super()
	chapter = 5
	spawn = Vector2(140, 0)
	bounds = Rect2(-200, -1200, 9900, 1500)
	dark_value = 0.3
	ambient_color = Color(0.36, 0.4, 0.52)
	fog_amount = 0.18
	bg_key = "c5"
	default_style = "earth"
	weather_rain = true
	lightning = true
	scatter_set = ["tuft_a", "rock_a", "tuft_b", "rock_b"]


func build() -> void:
	wall(-200, -1200, 20, 1500, "stone")
	wall(9700, -1200, 20, 1500, "stone")

	# ---------------------------------------------------------- 5-1 KUZEY KIYISI
	ground(-200, PIT_X, 0)
	brazier("b1", 620, 0)
	pickup("oil", 940, -20)
	echo(Echo.Kind.CRAWLER, 1250, 0)
	deco("net", 300, 0)
	deco("anchor", 460, 0, -2)
	deco("rope", 1080, 0)
	deco("rock_b", 1380, 0)
	deco("signpost", 1500, 0)
	label_decor("KIRLANGIÇ KONSERVE  1931", Vector2(1880, -470), 22, Color(0.75, 0.72, 0.62, 0.6))
	trigger("c5_yard", Rect2(1460, -300, 60, 300), _yard_enter)

	# ---------------------------------------------------------- 5-2 SU BASMIŞ AVLU
	ground(PIT_X, PIT_X + PIT_W, PIT_D, "cobble")
	var drained := GameState.flag("winch_c5s")
	_pit_water = water(PIT_X, PIT_D + 70.0 if drained else 8.0, PIT_W, PIT_D + 40.0)
	_pit_water.visible = not drained
	var sl := winch("c5s", 1600, 0, _drain)
	sl.prompt = "INT_SLUICE"
	crate("c5_crate", 1880, PIT_D)
	for x in [1820.0, 2200.0, 2560.0]:
		hang("chain", x, ROOF, 0.6)
	pickup("oil_small", 2300, PIT_D - 20)
	trigger("c5_out", Rect2(2760, -300, 60, 300), _yard_out)

	# ---------------------------------------------------------- 5-3 FABRİKA SALONU
	ground(PIT_X + PIT_W, 6420, 0, "planks")
	wall(PIT_X + PIT_W - 40, -1200, 3760, 680, "brickwall")     # çatı (alt kenar y = -520)
	var inner := Art.tiled_rect("tiles/brick.png", 3700, -ROOF, Color(0.34, 0.36, 0.42))
	inner.position = Vector2(PIT_X + PIT_W, ROOF)
	inner.z_index = -4
	add_world(inner)
	# çatıdaki delikler: içeri yağmur ve ay ışığı
	for hx in [3300.0, 4650.0]:
		ambient(hx, -440, 220, 0.18, false, 0.0, Color(0.6, 0.7, 0.95))
	brazier("b2", 2900, 0)
	prop("timeclock", 3120, 0, -1)
	interactable(3120, -40, "INT_CARDS", say_once.bind("c5_cards", ["C5_020", "C5_021"]))
	for cx in [3260.0, 3520.0, 4250.0, 4620.0]:
		deco("conveyor", cx, 0, -2, false, 0.0, Color(0.75, 0.75, 0.8))
	for hx in [3380.0, 3780.0, 4420.0]:
		hang("hook", hx, ROOF, 0.9)
	deco("crates", 3020, 0)
	deco("barrel", 3680, 0)
	deco("sacks", 4780, 0)
	label_decor("KAZANI YAK.  — Y.", Vector2(3570, -230), 26, Color(0.9, 0.9, 0.85, 0.75))
	interactable(3640, -60, "INT_LOOK", say_once.bind("c5_note", ["C5_030", "C5_031"]))
	echo(Echo.Kind.MIMIC, 3420, 0, false, ["M5_01"])
	trigger("c5_m2", Rect2(3820, -300, 60, 300), func(): say_once("c5_m2", ["M5_02"]))
	interactable(3780, -120, "INT_LOOK", say_once.bind("c5_hook", ["C5_060"]))
	# ayna bulmacası → kepenk
	trigger("c5_mir", Rect2(3880, -300, 60, 300), func(): _obj("OBJ_C5_SHUTTER"))
	mirror(3950, -60, 0.0, true, 60.0)
	mirror(3950, -400, -45.0, false, 0.0)
	solid(4850, -360, 300, 40, Color(-1, 0, 0), true, "brick")
	var bh := brazier("b3h", 5000, -360, false, true)
	_shutter = mover("c5_shutter", Rect2(5230, ROOF, 40, -ROOF), Vector2(0, -460))
	_shutter.tex_path = "tiles/stone_wall.png"
	bh.lit.connect(_shutter_open)
	echo(Echo.Kind.WATCHER, 4480, -230)
	pickup("oil_small", 4300, -20)
	pickup("oil", 4700, -20)

	# ---------------------------------------------------------- 5-4 KAZAN DAİRESİ
	brazier("b4", 5400, 0)
	prop("boiler", 5800, 0, -1)
	var bi := interactable(5800, -40, "INT_BOILER", _light_boiler, false, 1.5)
	bi.condition = func(): return not GameState.flag("c5_boiler")
	prop("valve", 6120, 0, -1)
	var vi := interactable(6120, -40, "INT_VALVE", _whistle, false, 2.0)
	vi.condition = func(): return GameState.flag("c5_boiler") and not GameState.flag("c5_whistle")
	_boiler_light = ambient(5800, -40, 230, 0.55, true, 0.35)
	_boiler_light.on = GameState.flag("c5_boiler")
	_boiler_fire = CPUParticles2D.new()
	_boiler_fire.position = Vector2(5800, -24)
	_boiler_fire.amount = 14
	_boiler_fire.lifetime = 0.8
	_boiler_fire.direction = Vector2(0, -1)
	_boiler_fire.spread = 30.0
	_boiler_fire.initial_velocity_min = 20.0
	_boiler_fire.initial_velocity_max = 50.0
	_boiler_fire.gravity = Vector2(0, -30)
	_boiler_fire.color = Color(1.0, 0.6, 0.25)
	_boiler_fire.material = Art.glow_material()
	_boiler_fire.emitting = GameState.flag("c5_boiler")
	add_world(_boiler_fire)
	_boiler_ready = GameState.flag("c5_boiler")
	_iron = mover("c5_iron", Rect2(6380, ROOF, 40, -ROOF), Vector2(0, -460))
	_iron.tex_path = "tiles/stone_wall.png"
	hang("chain", 5600, ROOF, 0.6)
	hang("lantern_hang", 6000, ROOF, 0.4)
	deco("barrel", 5560, 0)
	deco("crates", 6260, 0)

	# ---------------------------------------------------------- 5-5 DALGAKIRAN
	_sea = water(6420, TIDE_START, 3300, 700)
	var segs := [[6420.0, 7050.0], [7170.0, 7650.0], [7770.0, 8150.0], [8270.0, 8850.0], [8970.0, 9700.0]]
	for sg in segs:
		solid(float(sg[0]), 0, float(sg[1]) - float(sg[0]), 140, Color(-1, 0, 0), true, "stone")
	brazier("b5", 7420, 0)
	brazier("b6", 8560, 0)
	echo(Echo.Kind.WHISPER, 7850, -170)
	echo(Echo.Kind.CRAWLER, 8420, 0)
	echo(Echo.Kind.WHISPER, 9050, -220)
	pickup("oil_small", 7950, -20)
	trigger("c5_bw", Rect2(6480, -300, 60, 300), _breakwater)
	trigger("c5_bw2", Rect2(8300, -300, 60, 300), func(): say_once("c5_bw2", ["C5_051"]))
	# fener kulesinin tabanı ve kapısı
	var tower := Art.tiled_rect("tiles/stone_wall.png", 260, 1200, Color(0.6, 0.62, 0.68))
	tower.position = Vector2(9440, -1200)
	tower.z_index = -2
	add_world(tower)
	decor_poly([Vector2(9500, 0), Vector2(9580, 0), Vector2(9580, -150), Vector2(9540, -180), Vector2(9500, -150)], Color(0.03, 0.03, 0.04), -1)
	ambient(9540, -120, 200, 0.4, true, 0.2)
	trigger("c5_end", Rect2(9500, -300, 80, 300), _end_reached, false)
	antenna(1000, 0, ["RT_09", "RT_10"], "c5_rt")


func _obj(key: String) -> void:
	objective(key, OBJ_POS[key])


func on_start(from_checkpoint: bool) -> void:
	if not from_checkpoint:
		GameState.fuel = maxf(GameState.fuel, 60.0)
		_obj("OBJ_C5_FACTORY")
		Dialogue.play(["C5_000", "C5_001", "C5_002"])


func on_respawn() -> void:
	# gelgit yeniden doğuşta geri çekilir (adil tekrar)
	if _tide_on and _sea:
		_sea.position.y = TIDE_START


var _spray_t := 2.0


func _physics_process(delta: float) -> void:
	if _tide_on and _sea and not _ending:
		_sea.position.y = maxf(TIDE_END, _sea.position.y - TIDE_SPEED * delta)
	# dalgakıran: taş aralıklarında patlayan dalga serpintisi
	if player and player.global_position.x > 6300.0 and _sea:
		_spray_t -= delta
		if _spray_t <= 0.0:
			_spray_t = randf_range(1.2, 2.6)
			var gaps := [7110.0, 7710.0, 8210.0, 8910.0]
			var gx: float = gaps[randi() % gaps.size()]
			if absf(gx - player.global_position.x) < 900.0:
				_wave_spray(Vector2(gx, minf(_sea.position.y, 20.0)))


func _wave_spray(pos: Vector2) -> void:
	var s := CPUParticles2D.new()
	s.texture = Art.tex("fx/mote.png")
	s.position = pos
	s.one_shot = true
	s.explosiveness = 0.85
	s.amount = 46
	s.lifetime = 1.3
	s.direction = Vector2(0, -1)
	s.spread = 28.0
	s.initial_velocity_min = 260.0
	s.initial_velocity_max = 560.0
	s.gravity = Vector2(-60, 900)
	s.scale_amount_min = 1.5
	s.scale_amount_max = 4.0
	s.color = Color(0.75, 0.82, 0.9, 0.7)
	s.z_index = 4
	add_world(s)
	s.emitting = true
	AudioManager.play_at("splash", pos, -8.0, randf_range(0.6, 0.8))
	get_tree().create_timer(1.8).timeout.connect(s.queue_free)


# ------------------------------------------------------------------ olaylar
func _yard_enter() -> void:
	if GameState.flag("winch_c5s"):
		return
	say_once("c5_yard", ["C5_010"])
	_obj("OBJ_C5_SLUICE")


func _drain() -> void:
	_pit_water.rise(-(PIT_D + 62.0), 4.0)
	player.shake(3.0, 1.2)
	get_tree().create_timer(4.2).timeout.connect(_drained)


func _drained() -> void:
	if is_instance_valid(_pit_water):
		_pit_water.visible = false
	say_once("c5_drained", ["C5_011"])
	_obj("OBJ_C5_CRATE")


func _yard_out() -> void:
	if not GameState.flag("c5_shutter"):
		_obj("OBJ_C5_SHUTTER")


func _shutter_open() -> void:
	GameState.set_flag("c5_shutter")
	_shutter.activate()
	AudioManager.play_sfx("door", 0.0, 0.7)
	_obj("OBJ_C5_BOILER")


func _light_boiler() -> void:
	if GameState.flag("c5_boiler"):
		return
	if GameState.fuel < 15.0:
		if GameState.hud:
			GameState.hud.hint(Loc.t("HINT_BOILER_FUEL"), 5.0)
		return
	GameState.fuel -= 15.0
	GameState.set_flag("c5_boiler")
	AudioManager.play_sfx("ignite", 0.0, 0.7)
	_boiler_light.on = true
	_boiler_fire.emitting = true
	player.shake(2.0, 0.4)
	Dialogue.play(["C5_040"])
	# karanlıktan Yankılar gelir: basınç dolana kadar dayan
	echo(Echo.Kind.CRAWLER, 6300, 0)._emerge()
	echo(Echo.Kind.CRAWLER, 5480, 0)._emerge()
	await get_tree().create_timer(7.0).timeout
	_boiler_ready = true
	AudioManager.play_sfx("click", -4.0, 0.6)
	Dialogue.play(["C5_041"])


func _whistle() -> void:
	if not _boiler_ready:
		if GameState.hud:
			GameState.hud.hint(Loc.t("HINT_BOILER_WAIT"), 3.0)
		return
	if GameState.flag("c5_whistle"):
		return
	GameState.set_flag("c5_whistle")
	AudioManager.play_sfx("whistle", 2.0)
	player.shake(6.0, 1.6)
	GameState.rumble(0.5, 0.8, 1.2)
	if darkness:
		darkness.flash = 0.5
	_steam_burst(Vector2(6120, -110))
	for e in get_tree().get_nodes_in_group("echo"):
		if e.has_method("on_bell"):
			e.on_bell(Vector2(6120, -60), 2600.0)
	fog_amount = 0.08
	await get_tree().create_timer(1.2).timeout
	_iron.activate()
	AudioManager.play_sfx("door", 0.0, 0.6)
	await Dialogue.play(["C5_042", "C5_043"])
	_obj("OBJ_C5_BREAKWATER")


func _steam_burst(pos: Vector2) -> void:
	var s := CPUParticles2D.new()
	s.texture = Art.tex("fx/mote.png")
	s.position = pos
	s.amount = 60
	s.lifetime = 2.6
	s.one_shot = true
	s.explosiveness = 0.6
	s.direction = Vector2(0, -1)
	s.spread = 25.0
	s.initial_velocity_min = 200.0
	s.initial_velocity_max = 380.0
	s.gravity = Vector2(30, -40)
	s.damping_min = 60.0
	s.damping_max = 90.0
	s.scale_amount_min = 4.0
	s.scale_amount_max = 10.0
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.92, 0.95, 0.7))
	g.set_color(1, Color(0.7, 0.72, 0.78, 0.0))
	s.color_ramp = g
	s.z_index = 3
	add_world(s)
	s.emitting = true
	get_tree().create_timer(3.5).timeout.connect(s.queue_free)


func _breakwater() -> void:
	if _tide_on:
		return
	_tide_on = true
	say_once("c5_bw", ["C5_050"])
	_obj("OBJ_C5_BREAKWATER")
	AudioManager.set_intensity(1)


func _end_reached() -> void:
	if _ending:
		return
	_ending = true
	chapter_done()
