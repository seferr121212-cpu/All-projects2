class_name PrologueLevel
extends LevelBase
## PRÖLOĞ: SİNOP, 1965. Çalınmayan çanın gecesi.
## Oyuncu 14 yaşındaki Kerem. Uyanır, çanın sesini duymaz, pencereden sisi görür.
## Kapıya gidince "Yusuf çalar" deyip yatağa döner. Oyuncunun elinden seçim alınır:
## Kerem o gece kalkmadı. (Bölüm 3'teki itirafın kökü burası.)

const W := 1700.0


func _init() -> void:
	super()
	chapter = 0
	spawn = Vector2(240, 0)
	bounds = Rect2(-100, -700, W + 200, 1000)
	dark_value = 0.34
	fog_amount = 0.1
	bg_key = "c1"
	default_style = "planks"
	auto_scatter = false
	weather_rain = false
	lightning = false
	moonlight = false
	ambient_color = Color(0.3, 0.33, 0.45)


func build() -> void:
	GameState.has_lamp = false
	GameState.has_radio = false
	# evin içi: arka duvar, tavan, zemin, yan duvarlar
	var back := Art.tiled_rect("tiles/wood_wall.png", W, 340, Color(0.55, 0.52, 0.55))
	back.position = Vector2(0, -340)
	back.z_index = -5
	add_world(back)
	ground(0, W, 0, "planks")
	wall(-100, -700, 100, 1000, "stone")
	wall(W, -700, 100, 1000, "stone")
	wall(0, -380, W, 40, "wood")
	# odalar arası kiriş
	for x in [600.0, 1200.0]:
		var beam := Art.tiled_rect("tiles/wood_wall.png", 24, 340, Color(0.4, 0.36, 0.34))
		beam.position = Vector2(x, -340)
		beam.z_index = -4
		add_world(beam)
	# yataklar, masa, ağlar
	prop("bed", 240, 0, -1)
	prop("bed", 470, 0, -1, true)
	prop("desk", 820, 0, -1)
	deco("candles", 800, -58)
	deco("net", 1000, 0)
	deco("barrel", 1100, 0)
	deco("sacks", 1320, 0)
	hang("lantern_hang", 900, -340, 0.3)
	ambient(820, -90, 260, 0.75, true, 0.12)                       # masa lambası
	# pencere: dışarıda sis ve uzakta babanın tekne feneri
	var frame := ColorRect.new()
	frame.position = Vector2(860, -280)
	frame.size = Vector2(170, 130)
	frame.color = Color(0.08, 0.06, 0.05)
	frame.z_index = -3
	add_world(frame)
	var glass := ColorRect.new()
	glass.position = Vector2(870, -270)
	glass.size = Vector2(150, 110)
	glass.color = Color(0.42, 0.46, 0.54)
	glass.z_index = -3
	add_world(glass)
	var bar := ColorRect.new()
	bar.position = Vector2(942, -270)
	bar.size = Vector2(6, 110)
	bar.color = Color(0.08, 0.06, 0.05)
	bar.z_index = -3
	add_world(bar)
	ambient(945, -215, 200, 0.29, false, 0.0, Color(0.6, 0.7, 0.95))   # ay ışığı
	_boat_light = ambient(1000, -230, 26, 0.0, false, 0.6)
	# etkileşimler
	interactable(470, -40, "INT_LOOK", say_once.bind("pr_bed", ["PR_003"]))
	interactable(945, -60, "INT_WINDOW", _window)
	interactable(1000, -40, "INT_LOOK", say_once.bind("pr_net", ["PR_009"]))
	var door := ColorRect.new()
	door.position = Vector2(1560, -170)
	door.size = Vector2(80, 170)
	door.color = Color(0.16, 0.11, 0.08)
	door.z_index = -3
	add_world(door)
	_door = interactable(1600, -40, "INT_DOOR_HOME", _door_used)
	_door.condition = func(): return GameState.flag("say_pr_window")


var _boat_light: AmbientLight
var _door: Interactable


func on_start(_from_checkpoint: bool) -> void:
	player.set_look("child")
	Dialogue.portrait_override = {"kerem": "kerem_child"}
	objective("OBJ_PR_1")
	await Dialogue.play(["PR_000", "PR_001", "PR_002"], true)
	objective("OBJ_PR_2", Vector2(945, -60))


func _window() -> void:
	if GameState.flag("say_pr_window"):
		return
	GameState.set_flag("say_pr_window")
	await Dialogue.play(["PR_004"], true)
	# uzakta, sisin içinde bir ışık yanıp söner
	var tw := create_tween()
	tw.tween_property(_boat_light, "intensity", 0.28, 1.5)
	await tw.finished
	await Dialogue.play(["PR_005"], true)
	var tw2 := create_tween()
	tw2.tween_property(_boat_light, "intensity", 0.0, 3.0)
	objective("OBJ_PR_3", Vector2(1600, -60))


func _door_used() -> void:
	if GameState.flag("pr_done"):
		return
	GameState.set_flag("pr_done")
	await Dialogue.play(["PR_006", "PR_007"], true)
	await GameState.main.fade_out(2.0)
	await Dialogue.play(["PR_008"], true)
	Dialogue.portrait_override = {}
	chapter_done()
