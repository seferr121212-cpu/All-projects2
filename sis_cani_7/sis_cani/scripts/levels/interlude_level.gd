class_name InterludeLevel
extends LevelBase
## ARA BÖLÜM: KIRLANGIÇ ADASI, 1953. Hüsnü Usta'nın hatırası.
## Hüsnü Sinop'tan döner, fener sönmüştür. Köylüler sisin içinde birer birer Yankıya dönüşür.
## Oyuncu iskeleden kuleye koşar ve feneri yakar — bir saat geç.

const UP := 0.0

var _villagers: Array = []
var _done := false


func _init() -> void:
	super()
	chapter = 4
	spawn = Vector2(200, 0)
	bounds = Rect2(-200, -1400, 4400, 1800)
	dark_value = 0.34
	fog_amount = 0.34
	bg_key = "c1"
	default_style = "cobble"
	weather_rain = true
	lightning = true
	ambient_color = Color(0.33, 0.37, 0.52)
	sepia = 0.7


func build() -> void:
	GameState.has_lamp = true
	GameState.fuel = 100.0
	water(-200, 40, 800, 600)
	solid(100, 0, 500, 26, Color(-1, 0, 0), true, "planks")     # iskele
	wall(-200, -1400, 20, 1800, "stone")
	prop("boat", -40, 70, -1)
	ground(600, 4000, 0, "cobble")
	wall(4000, -1400, 40, 1800, "stone")
	# köy (aynı köy, 24 yıl önce: pencereler hâlâ yanıyor)
	house(900, 0, 220, 180, 60, true, true)
	house(1500, 0, 260, 200, 70, true, false, true)
	house(2100, 0, 200, 170, 60, true, true)
	house(2700, 0, 180, 140, 50, false)
	deco("lamppost", 1300, 0)
	deco("fence", 1900, 0)
	deco("signpost", 2450, 0)
	brazier("i1", 1400, 0)
	brazier("i2", 2550, 0)
	pickup("letter", 1250, -22, "L05")
	pickup("letter", 2260, -22, "L06")
	pickup("oil", 3000, -20)
	# köylüler: koşan siluetler, sonra Yankıya dönüşecekler
	for x in [1100.0, 1700.0, 2300.0, 2900.0]:
		var v := prop("chars/riza.png", x, 0, -1, x > 2000.0)
		v.modulate = Color(0.55, 0.58, 0.7)
		_villagers.append([v, x])
		trigger("", Rect2(x - 260, -200, 40, 200), _villager_lost.bind(_villagers.size() - 1))
	# kule kapısı (sonda)
	var tower := Art.tiled_rect("tiles/brick.png", 300, 1300, Color(0.6, 0.62, 0.7))
	tower.position = Vector2(3650, -1300)
	tower.z_index = -3
	add_world(tower)
	interactable(3780, -40, "INT_LENS_LIGHT", _light_the_lamp)
	trigger("", Rect2(3300, -300, 40, 300), func(): say_once("hu_wife", ["HU_006", "HU_007"]))
	echo(Echo.Kind.MIMIC, 3450, 0, false, ["HU_006"])


func on_start(_from_checkpoint: bool) -> void:
	player.set_look("husnu")
	Dialogue.portrait_override = {"husnu": "husnu_young"}
	objective("OBJ_HU_1", Vector2(3780, -60))
	await Dialogue.play(["HU_000", "HU_001", "HU_002"], true)
	strike_lightning()
	await Dialogue.play(["HU_003", "HU_004"])


## Köylü siste kaybolur, yerinde bir Sürünen belirir.
func _villager_lost(i: int) -> void:
	var pair: Array = _villagers[i]
	var v: Sprite2D = pair[0]
	var x: float = pair[1]
	AudioManager.play_sfx("whisper", -6.0, 0.9 + i * 0.1)
	var tw := create_tween()
	tw.tween_property(v, "modulate:a", 0.0, 1.2)
	await tw.finished
	echo(Echo.Kind.CRAWLER, x, 0, true)
	if i == 1:
		say_once("hu_quiet", ["HU_005"])


func _light_the_lamp() -> void:
	if _done:
		return
	_done = true
	GameState.input_locked += 1
	await Dialogue.play(["HU_009"], false)
	AudioManager.play_sfx("bell_big")
	darkness.flash = 1.0
	for e in echoes:
		if is_instance_valid(e):
			create_tween().tween_property(e, "modulate:a", 0.0, 1.5)
	ambient(3800, -900, 1200, 1.0, true)
	await get_tree().create_timer(2.0).timeout
	await GameState.main.fade_out(2.0)
	await Dialogue.play(["HU_008"], true)
	GameState.input_locked = maxi(0, GameState.input_locked - 1)
	Dialogue.portrait_override = {}
	chapter_done()
