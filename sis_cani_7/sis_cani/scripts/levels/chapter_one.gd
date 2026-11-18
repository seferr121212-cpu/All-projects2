class_name ChapterOne
extends LevelBase
## BÖLÜM 1: İSKELE VE KÖY
## 1-1 tekne ve iskele · 1-2 liman deposu · 1-3 köy yolu · 1-4 kahvehane
## 1-5 köy okulu · 1-6 uçurum köprüsü → mağaraya iniş

const UP := -150.0   # x=3200'den sonra zemin üstü

var _bridge: Mover
var _door: Mover
var _pack_spawned := false

const OBJ_POS := {
	"OBJ_PIER": Vector2(1500, -40),
	"OBJ_LAMP": Vector2(1620, -40),
	"OBJ_VILLAGE": Vector2(4700, UP - 60),
	"OBJ_RADIO": Vector2(5000, UP - 60),
	"OBJ_SCHOOL": Vector2(7300, UP - 60),
	"OBJ_BRIDGE": Vector2(7520, UP - 60),
	"OBJ_RUN": Vector2(8250, UP - 60),
	"OBJ_CAVE": Vector2(9200, UP - 60),
}


func _init() -> void:
	super()
	chapter = 1
	spawn = Vector2(360, 0)
	bounds = Rect2(-200, -1600, 9800, 2100)
	dark_value = 0.26
	ambient_color = Color(0.4, 0.45, 0.6)
	fog_amount = 0.22
	bg_key = "c1"
	default_style = "earth"
	weather_rain = true
	lightning = true


func build() -> void:
	# ---------------------------------------------------------- 1-1 TEKNE VE İSKELE
	water(-200, 40, 1600, 600)
	solid(300, 0, 1100, 26, Color(-1, 0, 0), true, "planks")       # iskele güvertesi
	for i in 9:
		decor_poly([Vector2(330 + i * 130, 26), Vector2(342 + i * 130, 26), Vector2(342 + i * 130, 160), Vector2(330 + i * 130, 160)], Color(0.07, 0.06, 0.06), -1)
	wall(-200, -1600, 20, 2100)
	prop("boat", 60, 70, -1)
	prop("chars/riza.png", 170, 10, -1, true)
	ambient(40, -60, 380, 0.8, true)
	trigger("c1_intro", Rect2(320, -200, 120, 200), _intro)
	prop("pier_bell", 914, 0, -1)
	interactable(914, -70, "INT_LOOK", func(): say_once("c1_bell", ["C1_020", "C1_021"]))
	trigger("c1_land", Rect2(1300, -200, 60, 200), _land)

	# ---------------------------------------------------------- 1-2 LİMAN DEPOSU
	ground(1400, 3200, 0)
	house(1420, 0, 1180, 300, 80, false, false, true)
	wall(1450, -300, 1150, 40, "wood")              # depo tavanı
	pickup("lamp", 1620, -20, "c1_lamp")
	pickup("oil", 1880, -20)
	ledge(2330, -100, 170)
	pickup("page", 2415, -122, "P01")
	trigger("c1_first_echo", Rect2(2020, -200, 60, 200), func(): say_once("c1_echo", ["C1_031", "C1_032"]))
	echo(Echo.Kind.CRAWLER, 2260, 0)
	crate("c1_box_a", 2120, 0)

	# ---------------------------------------------------------- 1-3 KÖY YOLU
	house(2700, 0, 220, 180, 60, true, true)
	house(3350, UP, 260, 200, 70, true, false, true)
	house(3700, UP, 200, 170, 60, true, true)
	trigger("c1_village", Rect2(2650, -200, 60, 200), _village_enter)
	var b1 := brazier("b1", 2860, 0)
	trigger("c1_brazier_hint", Rect2(2700, -200, 60, 200), _b1_hint)
	b1.lit.connect(func(): say_once("c1_b1_lit", ["C1_041"]))
	crate("c1_box_b", 3020, 0)
	ground(3200, 3900, UP, "cobble")
	kill_zone(Rect2(3900, 120, 200, 400))
	solid(3900, 260, 200, 400)
	crumble(3900, UP, 100)
	crumble(4000, UP, 100)
	ground(4100, 7600, UP, "cobble")
	pickup("oil_small", 3500, UP - 20)
	echo(Echo.Kind.CRAWLER, 3620, UP)
	echo(Echo.Kind.CRAWLER, 4420, UP)
	trigger("c1_runner", Rect2(3300, UP - 200, 60, 200), _runner)

	# ---------------------------------------------------------- 1-4 KAHVEHANE
	house(4620, UP, 1080, 280, 70, true, true, true)
	brazier("b2", 4800, UP)
	trigger("c1_cafe", Rect2(4680, UP - 200, 60, 200), _cafe)
	prop("desk", 5190, UP, -1)
	var radio := interactable(5000, UP - 40, "INT_RADIO", _radio, true)
	radio.condition = func(): return not GameState.flag("c1_radio_done")
	var rs := Art.sprite("props/radio.png")
	rs.position.y += 30
	radio.add_child(rs)
	pickup("page", 5300, UP - 22, "P02")
	_door = mover("c1_cafe_door", Rect2(5700, UP - 200, 40, 200), Vector2(0, -200))

	# ---------------------------------------------------------- 1-5 KÖY OKULU
	house(5900, UP, 1400, 300, 100, true, false, true)
	brazier("b3", 6000, UP)
	prop("board", 6450, UP - 110, -1)
	label_decor("1953", Vector2(6418, UP - 175), 34, Color(0.8, 0.82, 0.78, 0.7))
	for i in 4:
		prop("school_desk", 6250 + i * 120, UP, -1)
	ledge(6250, UP - 70, 150)
	pickup("page", 6325, UP - 92, "P03")
	trigger("c1_mimic", Rect2(6120, UP - 200, 60, 200), _school_scare)
	echo(Echo.Kind.MIMIC, 6780, UP, false, ["C1_060", "C1_062"])
	pickup("oil", 6950, UP - 20)

	# ---------------------------------------------------------- 1-6 UÇURUM KÖPRÜSÜ
	brazier("b4", 7300, UP)
	trigger("c1_bridge_radio", Rect2(7360, UP - 200, 60, 200), _bridge_radio)
	kill_zone(Rect2(7600, 200, 400, 400))
	_bridge = mover("c1_bridge", Rect2(7600, UP - 300, 400, 18), Vector2(0, 300), 2.2)
	_bridge.tex_path = "tiles/planks.png"
	winch("c1w", 7520, UP, _lower_bridge)
	ground(8000, 9600, UP, "earth_dark")
	var b5 := brazier("b5", 8250, UP)
	b5.lit.connect(_b5_lit)
	house(8350, UP, 180, 140, 50, false)
	pickup("page", 8440, UP - 22, "P04")
	# mağara girişi + Yusuf'un uzak ışığı
	decor_poly([Vector2(9050, UP), Vector2(9500, UP), Vector2(9500, UP - 420), Vector2(9200, UP - 360), Vector2(9050, UP - 200)], Color(0.02, 0.022, 0.03), -1)
	ambient(9380, UP - 60, 140, 0.28, false, 0.7)
	trigger("c1_end", Rect2(9150, UP - 200, 80, 200), _ending)
	wall(9500, -1600, 40, 2100)
	dress()


## Set dekoru: iskele eşyaları, çitler, mezarlık, ölü ağaçlar.
func dress() -> void:
	# iskele
	deco("barrel", 520, 0)
	deco("barrel", 556, 0, -1, true)
	deco("crates", 650, 0)
	deco("rope", 740, 0)
	deco("net", 820, 0)
	deco("lamppost", 1060, 0)
	deco("sacks", 1180, 0)
	deco("anchor", 1320, 0)
	deco("wreck", 1150, 92, -2)
	# depo
	deco("crates", 1760, 0)
	deco("barrel", 1990, 0)
	deco("sacks", 2210, 0)
	hang("cobweb", 1480, -260, 0.0)
	# köy yolu
	deco("fence", 2580, 0)
	deco("dead_tree", 3090, 0, -2)
	deco("signpost", 3260, UP)
	label_decor("FENER →", Vector2(3225, UP - 92), 16, Color(0.85, 0.8, 0.7, 0.8))
	deco("lamppost", 3560, UP)
	deco("fence_broken", 3820, UP)
	deco("bush", 4200, UP, -1, false, 0.0, Color(0.8, 0.85, 0.9))
	deco("fence", 4460, UP)
	# kahvehane
	deco("barrel", 4720, UP)
	deco("sacks", 5520, UP)
	hang("lantern_hang", 4950, UP - 280, 0.6)
	# okul + mezarlık
	deco("grave_a", 7080, UP)
	deco("grave_b", 7140, UP)
	deco("grave_a", 7210, UP, -1, true)
	deco("dead_tree", 7180, UP, -2, true)
	# köprü ve öte yaka
	deco("rock_b", 7470, UP)
	deco("dead_tree", 8120, UP, -2)
	deco("fence_broken", 8620, UP, -1, true)
	deco("grave_b", 8800, UP)
	deco("rock_a", 8990, UP)
	# --- genişletme: mektuplar, telsiz direkleri, iç sesler, gizli oda
	pickup("letter", 1000, -22, "L03")
	pickup("letter", 1700, -22, "L01")
	pickup("letter", 6500, UP - 22, "L02")
	antenna(2560, 0, ["RT_01", "RT_02"], "c1_rt_a")
	antenna(6660, UP, ["RT_03", "RT_04"], "c1_rt_b")
	interactable(3560, UP - 60, "INT_LOOK", say_once.bind("c1_in1", ["IN_01"]))
	interactable(7140, UP - 30, "INT_LOOK", say_once.bind("c1_in2", ["IN_02"]))
	interactable(7225, UP - 30, "INT_GRAVE", say_once.bind("c1_fatma", ["FG_01"]))
	# depo sonunda sahte duvarın arkasında fitil
	secret(Rect2(2440, -300, 160, 300), "wood")
	pickup("wick", 2520, -24, "c1_wick")
	_chime_t = 25.0


# ---------------------------------------------------------------- events
func _land() -> void:
	if not GameState.has_lamp:
		objective("OBJ_LAMP", OBJ_POS["OBJ_LAMP"])


func _runner() -> void:
	shadow_run(3900, 2900, UP - 10, 1.6)
	say_once("c1_runner", ["C1_091"])


func _cafe() -> void:
	if not GameState.flag("c1_radio_done"):
		objective("OBJ_RADIO", OBJ_POS["OBJ_RADIO"])
	say_once("c1_cafe", ["C1_050"])


func _bridge_radio() -> void:
	if not GameState.flag("winch_c1w"):
		objective("OBJ_BRIDGE", OBJ_POS["OBJ_BRIDGE"])
	say_once("c1_br", ["C1_070"])


func _b5_lit() -> void:
	AudioManager.set_intensity(0)
	objective("OBJ_CAVE", OBJ_POS["OBJ_CAVE"])


func _b1_hint() -> void:
	if GameState.hud:
		GameState.hud.hint(Loc.t("HINT_BRAZIER") + "\n" + Loc.t("HINT_CYCLE"))
	say_once("c1_b1", ["C1_040"])


func _intro() -> void:
	if GameState.hud:
		GameState.hud.hint(Loc.t("HINT_MOVE"), 8.0)
	await Dialogue.play(["C1_010", "C1_005", "C1_006", "C1_011", "C1_012", "C1_013", "C1_014", "C1_015"], true)
	GameState.has_radio = true
	if GameState.hud:
		GameState.hud.toast(Loc.t("PICKUP_RADIO"))
	objective("OBJ_PIER", OBJ_POS["OBJ_PIER"])
	await get_tree().create_timer(1.5).timeout
	strike_lightning()
	await Dialogue.play(["C1_090"])


func _village_enter() -> void:
	objective("OBJ_VILLAGE", OBJ_POS["OBJ_VILLAGE"])


func _school_scare() -> void:
	objective("OBJ_SCHOOL", OBJ_POS["OBJ_SCHOOL"])
	if GameState.flag("say_c1_mimic"):
		return
	# lamba bir anlığına söner, gölge yaklaşır
	player.lamp.base_mode = Lamp.Mode.OFF
	AudioManager.play_sfx("whisper", -2.0)
	player.shake(3.0, 0.5)
	Dialogue.play(["C1_092"])
	await get_tree().create_timer(1.6).timeout
	player.lamp.base_mode = Lamp.Mode.NORMAL
	say_once("c1_mimic", ["C1_060", "C1_061", "C1_062", "C1_063", "C1_064"])


func _radio() -> void:
	await Dialogue.play(["C1_051"])
	GameState.main.open_radio(_radio_fixed)


func _radio_fixed() -> void:
	GameState.set_flag("c1_radio_done")
	await Dialogue.play(["C1_052", "C1_053", "C1_054", "C1_055", "C1_056", "C1_057"])
	_door.activate()
	objective("OBJ_SCHOOL", OBJ_POS["OBJ_SCHOOL"])


func _lower_bridge() -> void:
	_bridge.activate()
	player.shake(4.0, 1.5)
	await get_tree().create_timer(1.0).timeout
	_spawn_pack()
	objective("OBJ_RUN", OBJ_POS["OBJ_RUN"])
	await Dialogue.play(["C1_071", "C1_072"])
	if GameState.hud:
		GameState.hud.hint(Loc.t("HINT_DIM"))


func _spawn_pack() -> void:
	if _pack_spawned:
		return
	_pack_spawned = true
	AudioManager.set_intensity(2)
	for i in 6:
		echo(Echo.Kind.CRAWLER, 6850 + i * 55, UP, true)


func _ending() -> void:
	AudioManager.set_intensity(0)
	await Dialogue.play(["C1_080", "C1_081", "C1_082", "C1_083"], true)
	chapter_done()


func on_start(from_checkpoint: bool) -> void:
	if from_checkpoint:
		var key := str(GameState.get_flag_value("objective", "OBJ_PIER"))
		if OBJ_POS.has(key):
			objective(key, OBJ_POS[key])
		if GameState.flag("winch_c1w") and player.global_position.x < 8000.0:
			_spawn_pack()


func on_respawn() -> void:
	if AudioManager.intensity >= 2:
		AudioManager.set_intensity(0)


# ----------------------------------------------------- uzaktan çan tınısı (fener)
var _chime_t := 25.0


func _physics_process(delta: float) -> void:
	_chime_t -= delta
	if _chime_t <= 0.0:
		_chime_t = randf_range(40.0, 70.0)
		if not Dialogue.busy and GameState.input_locked == 0:
			AudioManager.play_sfx("chime", -26.0, randf_range(0.95, 1.02))
