class_name EndingEscape
extends LevelBase
## SON B: Kerem Yusuf'u sırtında tekneye taşır. Lambayı Yusuf tutar (yakıt bitmez),
## Kerem el çanıyla sis duvarını geri iter.

var _fog: GreatEcho


func _init() -> void:
	super()
	chapter = 3
	spawn = Vector2(260, 0)
	bounds = Rect2(-800, -1200, 4400, 1700)
	dark_value = 0.36
	ambient_color = Color(0.34, 0.38, 0.52)
	fog_amount = 0.35
	bg_key = "c3"
	weather_rain = true
	lightning = true


func build() -> void:
	GameState.has_checkpoint = false
	GameState.has_lamp = true
	GameState.fuel = 100.0
	wall(-800, -1200, 20, 1700, "stone")
	ground(-800, 3000, 0)
	solid(900, -60, 160, 60)
	solid(1700, -70, 200, 70)
	solid(2300, -50, 120, 50)
	water(3000, 60, 600, 500)
	# tekne + Rıza
	prop("boat", 3230, 70, -1, true)
	prop("chars/riza.png", 3120, 10, -1)
	ambient(3240, -40, 380, 0.8, true)
	trigger("", Rect2(2900, -300, 80, 300), _reached_boat)
	trigger("", Rect2(600, -300, 40, 300), func(): Dialogue.play(["EB_010", "EB_011"]))
	trigger("", Rect2(1800, -300, 40, 300), func(): Dialogue.play(["EB_012", "EB_013"]))
	deco("dead_tree", 400, 0, -2)
	deco("rock_b", 1300, 0)
	deco("fence_broken", 2000, 0)
	deco("anchor", 2700, 0)
	deco("barrel", 2820, 0)
	wall(3500, -1200, 40, 1700, "stone")


func on_start(_from_checkpoint: bool) -> void:
	enable_leaves()
	player.wind = -30.0
	player.set_carrying(true)
	player.lamp.infinite = true
	AudioManager.set_intensity(2)
	_fog = GreatEcho.new()
	_fog.is_fog_wall = true
	_fog.speed = 150.0
	_fog.lit_speed = 95.0
	_fog.position = Vector2(-500, 0)
	add_world(_fog)
	objective("OBJ_ESCAPE", Vector2(3000, -60))


func on_respawn() -> void:
	if _fog:
		_fog.global_position.x = player.global_position.x - 700.0
	player.set_carrying(true)


func _reached_boat() -> void:
	if _fog:
		_fog.tame = true
	await Dialogue.play(["EB_003"], true)
	GameState.main.finish_ending("B")
