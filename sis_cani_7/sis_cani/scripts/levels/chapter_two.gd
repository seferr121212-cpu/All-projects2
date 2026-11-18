class_name ChapterTwo
extends LevelBase
## BÖLÜM 2: MAĞARALAR VE SARNIÇ
## 2-1 mağara girişi · 2-2 sızıntılı tüneller (aynalar) · 2-3 Hüsnü Usta'nın odası
## 2-4 su basmış sarnıç · 2-5 kırmızı duvar (mercek + mühür) · 2-6 taş kuyu (kovalama)

var _door1: Mover
var _door2: Mover
var _gate: Mover
var _raft: Mover
var _water: Water
var _ge: GreatEcho = null
var _chase_braziers: Array = []
var _chase_on := false
var _chase_done := false
var _chase_trigger: Zone
var _tamed := false


func _init() -> void:
	super()
	chapter = 2
	spawn = Vector2(160, 0)
	bounds = Rect2(-200, -1000, 12400, 1700)
	dark_value = 0.3
	ambient_color = Color(0.34, 0.37, 0.48)
	moonlight = false
	fog_amount = 0.14
	bg_key = "c2"
	default_style = "rock"
	weather_motes = true
	scatter_set = ["tuft_cave", "rock_c", "mushrooms", "rock_a", "tuft_cave", "rock_c"]


func build() -> void:
	wall(-200, -1000, 200, 1700)           # sol duvar
	wall(-200, -1000, 12400, 300)          # tavan (alt kenarı y = -700)
	wall(12000, -1000, 200, 1700)          # sağ duvar

	# ---------------------------------------------------------- 2-1 MAĞARA GİRİŞİ
	ground(0, 5200, 0)
	decor_poly([Vector2(60, -700), Vector2(140, -700), Vector2(100, -560)], Color(0.04, 0.045, 0.055))
	label_decor("⇉", Vector2(430, -140), 46, Color(0.85, 0.85, 0.8, 0.7))
	label_decor("⇉  geri dönmek için", Vector2(760, -150), 26, Color(0.85, 0.85, 0.8, 0.6))
	trigger("c2_arrow1", Rect2(430, -200, 60, 200), func(): say_once("c2_a1", ["C2_010"]))
	trigger("c2_arrow2", Rect2(780, -200, 60, 200), func(): say_once("c2_a2", ["C2_011"]))
	pickup("page", 680, -22, "P05")
	pickup("oil_small", 1100, -20)
	pickup("oil", 1420, -20)
	echo(Echo.Kind.CRAWLER, 1280, 0)
	brazier("b1", 1560, 0)

	# ---------------------------------------------------------- 2-2 TÜNELLER (AYNA BULMACASI)
	trigger("c2_mirror", Rect2(1880, -200, 60, 200), _mirror_hint)
	var m1 := mirror(2200, -60, 0.0, true, 60.0)
	m1.used.connect(func(_p): say_once("c2_m2", ["C2_021"]))
	mirror(2200, -400, -45.0, false, 0.0)
	solid(3100, -360, 300, 40, Color(-1, 0, 0), true, "stone")
	var b2 := brazier("b2", 3250, -360, false, true)
	_door1 = mover("c2_door1", Rect2(3480, -300, 40, 300), Vector2(0, -300))
	b2.lit.connect(_b2_lit)
	pickup("oil", 2500, -20)
	pickup("page", 2820, -22, "P06")
	echo(Echo.Kind.CRAWLER, 2950, 0)
	echo(Echo.Kind.CRAWLER, 3330, 0)

	# ---------------------------------------------------------- 2-3 HÜSNÜ USTA'NIN ODASI
	brazier("b3", 3800, 0)
	trigger("c2_room", Rect2(3700, -200, 60, 200), func(): say_once("c2_room", ["C2_030"]))
	trigger("c2_rock1", Rect2(3550, -300, 60, 300), func(): _rockfall(3600))
	trigger("c2_cis", Rect2(4900, -300, 60, 300), func(): _obj("OBJ_C2_CISTERN"))
	prop("bed", 4040, 0, -1)
	prop("stove", 4275, 0, -1)
	for i in 4:
		prop("shelf", 4480 + i * 40, 0, -2)
	ambient(4275, -50, 170, 0.29, false, 0.3)
	pickup("bell", 4200, -24, "c2_bell")
	pickup("red", 4400, -24, "c2_red")
	pickup("tape", 4620, -20, "H01", ["C2_031", "C2_032"])

	# ---------------------------------------------------------- 2-4 SARNIÇ
	pickup("tape", 5060, -20, "H02", ["C2_040", "C2_041"])
	solid(5200, 600, 2000, 300)    # sarnıç tabanı
	var risen := GameState.flag("winch_c2w")
	_water = water(5200, 0.0 if risen else 250.0, 2000, 700)
	for x in [5600, 6200, 6800]:
		var col := Art.tiled_rect("tiles/brick.png", 60, 1300, Color(0.55, 0.58, 0.65))
		col.position = Vector2(x, -700)
		col.z_index = -2
		add_world(col)
	_raft = mover("c2_raft", Rect2(5240, 236, 170, 14), Vector2(0, -236), 3.0)
	_raft.loop_travel = Vector2(1780, 0)
	_raft.loop_duration = 7.0
	_raft.tex_path = "tiles/planks.png"
	winch("c2w", 5120, 0, _raise_water)
	trigger("c2_watchers", Rect2(5300, -300, 60, 300), func(): say_once("c2_w", ["C2_042"]))
	echo(Echo.Kind.WATCHER, 5900, -230)
	echo(Echo.Kind.WATCHER, 6500, -170)
	ground(7200, 11000, 0)
	pickup("page", 7290, -22, "P07")
	var doll := prop("doll", 7380, 0, -1)
	var di := interactable(7380, -30, "INT_DOLL", func(): _take_doll(doll))
	if GameState.flag("c2_doll"):
		doll.visible = false
		di.enabled = false
	brazier("b4", 7420, 0)
	pickup("tape", 7660, -20, "H03", ["C2_050", "C2_051", "C2_052"])

	# ---------------------------------------------------------- 2-5 KIRMIZI DUVAR
	var t1 := red_text("C2_060", 8000, -230)
	t1.revealed.connect(func(): say_once("c2_rt1", ["C2_060"]))
	var t2 := red_text("C2_061", 8420, -230)
	t2.revealed.connect(func(): say_once("c2_rt2", ["C2_061", "C2_062"]))
	trigger("c2_red_hint", Rect2(7800, -200, 60, 200), _red_hint)
	trigger("c2_shadow", Rect2(7600, -300, 60, 300), func(): shadow_run(8600, 7900, -10, 1.3))
	lens(8580, -36)
	var sl := seal("c2_seal", 8770, -36)
	_door2 = mover("c2_door2", Rect2(8800, -300, 40, 300), Vector2(0, -300))
	sl.triggered.connect(_seal_melted)
	pickup("page", 8700, -22, "P08")
	brazier("b5", 9000, 0)

	# ---------------------------------------------------------- 2-6 TAŞ KUYU (KOVALAMA)
	_chase_trigger = trigger("", Rect2(9200, -300, 60, 300), _start_chase, true)   # id yok: her denemede yeniden çalışır
	for x in [9900.0, 10650.0, 11350.0]:
		var cb := brazier("", x, 0, false, false, true)
		cb.lit.connect(_chase_lit)
		_chase_braziers.append(cb)
	wall(10150, -700, 300, 650)    # eğilme tüneli (alt kenar y = -50)
	pickup("oil_small", 10300, -20)
	kill_zone(Rect2(11000, 150, 90, 400))
	solid(11000, 300, 90, 300)
	ground(11090, 12000, 0)
	_gate = mover("", Rect2(11750, -300, 40, 300), Vector2(0, -300))
	decor_poly([Vector2(11850, 0), Vector2(11990, 0), Vector2(11990, -600), Vector2(11850, -600)], Color(0.025, 0.028, 0.035), -1)  # merdiven boşluğu
	trigger("c2_end", Rect2(11880, -300, 60, 300), _end_reached, false)
	dress()


## Set dekoru: sarkıtlar, sarkan kökler, zincirler, mantarlar, Hüsnü Usta'nın eşyaları.
func dress() -> void:
	for x in range(200, 12000, 430):
		if x > 5150 and x < 7250:
			continue
		hang("roots", x + (x % 7) * 20, -700, 1.0)
	for x in [5450.0, 5980.0, 6550.0, 7050.0]:
		hang("chain", x, -700, 0.8)
	for x in [980.0, 2660.0, 3320.0, 7600.0, 9600.0, 10900.0]:
		deco("stalagmite_a" if int(x) % 2 == 0 else "stalagmite_b", x, 0, -2, false, 0.0, Color(0.7, 0.72, 0.8))
	hang("cobweb", 3600, -700, 0.0)
	hang("cobweb", 4740, -700, 0.0).flip_h = true
	deco("candles", 4380, 0)
	deco("barrel", 4140, 0)
	deco("crates", 4820, 0)
	hang("lantern_hang", 4300, -700, 0.5)
	deco("rope", 5080, 0)
	deco("sacks", 7520, 0)
	deco("candles", 8320, 0)
	# --- genişletme
	pickup("letter", 1250, -22, "L04")
	trigger("c2_in3", Rect2(2600, -300, 40, 300), func(): say_once("c2_in3", ["IN_03"]))
	echo(Echo.Kind.WHISPER, 7950, -120)
	echo(Echo.Kind.WHISPER, 8500, -160)
	_build_bell_puzzle()


## İsteğe bağlı çan bulmacası (Hüsnü Usta'nın odası): kırmızı camla görünen yazı sırayı söyler.
var _bell_seq: Array = []


func _build_bell_puzzle() -> void:
	red_text("BP_01", 4600, -250)
	for i in 3:
		var bx := 4480.0 + i * 120.0
		var idx := i + 1
		var stand := Line2D.new()
		stand.points = PackedVector2Array([Vector2(bx, -700), Vector2(bx, -86)])
		stand.width = 3.0
		stand.default_color = Color(0.22, 0.2, 0.2)
		add_world(stand)
		prop("bell_%d" % idx, bx, -50, 0)
		interactable(bx, -60, "INT_RING", _ring_small.bind(idx), false)
	trigger("c2_bells_obj", Rect2(4440, -300, 40, 300), _bells_goal)


func _bells_goal() -> void:
	if not GameState.flag("c2_bells_done"):
		objective("OBJ_BELLS", Vector2(4600, -200))


func _ring_small(idx: int) -> void:
	if GameState.flag("c2_bells_done"):
		return
	AudioManager.play_sfx("bell_hand", -4.0, [1.5, 1.2, 1.0][idx - 1])
	_bell_seq.append(idx)
	if _bell_seq.size() == 3:
		if _bell_seq == [3, 1, 2]:
			GameState.set_flag("c2_bells_done")
			GameState.unlock("BELLS")
			pickup("wick", 4600, -24, "c2_wick")
			say_once("c2_bp2", ["BP_02"])
			objective("OBJ_C2_CISTERN", OBJ_POS["OBJ_C2_CISTERN"])
		else:
			Dialogue.play(["BP_03"])
		_bell_seq.clear()


# ---------------------------------------------------------------- events
const OBJ_POS := {
	"OBJ_C2_START": Vector2(1560, -60),
	"OBJ_C2_MIRROR": Vector2(2200, -60),
	"OBJ_C2_ROOM": Vector2(4200, -60),
	"OBJ_C2_CISTERN": Vector2(5120, -60),
	"OBJ_C2_SEAL": Vector2(8770, -60),
	"OBJ_C2_RUN": Vector2(11350, -60),
	"OBJ_C2_BELL": Vector2(11800, -60),
}


func _mirror_hint() -> void:
	_obj("OBJ_C2_MIRROR")
	say_once("c2_m", ["C2_020"])
	if GameState.hud:
		GameState.hud.hint(Loc.t("HINT_LAMP") + "\n" + Loc.t("HINT_MIRROR"))


func _b2_lit() -> void:
	_door1.activate()
	_obj("OBJ_C2_ROOM")


func _seal_melted() -> void:
	_door2.activate()
	objective("OBJ_C2_RUN", Vector2(9300, -60))


func _obj(key: String) -> void:
	objective(key, OBJ_POS[key])


func _rockfall(x: float) -> void:
	# tavandan taş düşer: sarsıntı + toz
	player.shake(6.0, 0.6)
	AudioManager.play_sfx("crumble", 0.0, 0.6)
	for i in 6:
		dust(Vector2(x + randf_range(-120, 120), 0))


func _red_hint() -> void:
	_obj("OBJ_C2_SEAL")
	if GameState.has_red and GameState.hud:
		GameState.hud.hint(Loc.t("HINT_RED"))


func _raise_water() -> void:
	_water.rise(250.0, 3.0)
	_raft.activate()


func _start_chase() -> void:
	if _chase_on or _chase_done:
		return
	_chase_on = true
	AudioManager.set_intensity(2)
	_ge = GreatEcho.new()
	_ge.position = Vector2(player.global_position.x - 750.0, 0)
	add_world(_ge)
	_obj("OBJ_C2_RUN")
	_rockfall(player.global_position.x)
	await Dialogue.play(["C2_070", "C2_071", "C2_072", "C2_073"])
	if GameState.hud:
		GameState.hud.hint(Loc.t("HINT_CROUCH"))


func _chase_lit() -> void:
	var all := true
	for b in _chase_braziers:
		if not b.is_lit:
			all = false
	if all and _chase_on:
		_gate.activate()
		_obj("OBJ_C2_BELL")
		if GameState.hud:
			GameState.hud.hint(Loc.t("HINT_BELL"))


func on_bell(_pos: Vector2) -> void:
	if not _chase_on or _tamed or _ge == null:
		return
	var all := true
	for b in _chase_braziers:
		if not b.is_lit:
			all = false
	if all and absf(player.global_position.x - _ge.global_position.x) < 900.0:
		_tame()


func _end_reached() -> void:
	if _tamed:
		return
	if _chase_on and _gate.activated:
		player.ring_bell()
		_tame()


func _tame() -> void:
	if _tamed:
		return
	_tamed = true
	_chase_done = true
	if _ge:
		_ge.tame = true
	AudioManager.set_intensity(0)
	await Dialogue.play(["C2_080", "C2_081", "C2_082", "C2_083", "C2_084"], true)
	if _ge:
		var tw := create_tween()
		tw.tween_property(_ge, "modulate:a", 0.0, 2.0)
		await tw.finished
		_ge.queue_free()
		_ge = null
	chapter_done()


func on_respawn() -> void:
	if _chase_on and not _chase_done:
		_chase_on = false
		if _ge:
			_ge.queue_free()
			_ge = null
		for b in _chase_braziers:
			b.extinguish()
		_chase_trigger.rearm()
		AudioManager.set_intensity(0)


func on_start(from_checkpoint: bool) -> void:
	if not from_checkpoint:
		GameState.fuel = 20.0
		_obj("OBJ_C2_START")
		Dialogue.play(["C2_000", "C2_001", "C2_002"])
	else:
		var key := str(GameState.get_flag_value("objective", "OBJ_C2_START"))
		if OBJ_POS.has(key):
			_obj(key)


func _take_doll(doll: Node) -> void:
	GameState.set_flag("c2_doll")
	if is_instance_valid(doll):
		doll.visible = false
	AudioManager.play_sfx("pickup", -6.0)
	Dialogue.play(["D_01"])
