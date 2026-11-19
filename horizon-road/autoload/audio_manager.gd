extends Node
## Layered ambience driven by time of day, weather and region, plus one-shot
## helpers (thunder). Music arrives in a later stage on the Music bus.

const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_AMBIENCE: StringName = &"Ambience"
const SILENT_DB: float = -60.0
## How fast layer volumes chase their targets (per second, linear in dB space).
const FADE_DB_PER_SEC: float = 18.0

var _wind: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _bird_streams: Array[AudioStreamWAV] = []
var _thunder_stream: AudioStreamWAV
var _bird_timer: float = 2.0
var _rng := RandomNumberGenerator.new()
## Region-specific multiplier (e.g. coastal regions have fewer forest birds).
var region_bird_density: float = 1.0

# Music: sparse pieces with long silences in between.
const MUSIC_DB: float = -6.0
var _music := AudioStreamPlayer.new()
var _pieces: Dictionary = {}
var _music_style: String = ""
var _music_silence: float = 12.0
var _music_task: int = -1
var _music_mutex := Mutex.new()


func _ready() -> void:
	_rng.randomize()
	_ensure_buses()
	_wind = _make_loop(ProceduralAudio.wind())
	_rain = _make_loop(ProceduralAudio.rain())
	_crickets = _make_loop(ProceduralAudio.crickets())
	for i: int in 6:
		_bird_streams.append(ProceduralAudio.bird_chirp(100 + i))
	_thunder_stream = ProceduralAudio.thunder()
	_music.bus = BUS_MUSIC
	_music.volume_db = MUSIC_DB
	add_child(_music)
	_music.finished.connect(func() -> void: _music_silence = _rng.randf_range(60.0, 150.0))


func _process(delta: float) -> void:
	var w: WeatherProfile = WeatherManager.current
	var night: float = TimeManager.get_night_factor()
	_fade(_wind, _lin_to_db(0.25 + w.wind * 0.75) - 6.0, delta)
	_fade(_rain, _lin_to_db(w.rain), delta)
	_fade(_crickets, _lin_to_db(night * (1.0 - w.rain) * (1.0 - w.snow) * 0.6), delta)
	_update_birds(delta, w, night)
	_update_music(delta)


## Called by each region: generate its pieces on a worker thread.
func set_music_style(style: String) -> void:
	if style == _music_style:
		return
	_music_style = style
	_music.stop()
	_music_silence = 10.0
	_music_mutex.lock()
	_pieces.clear()
	_music_mutex.unlock()
	if DisplayServer.get_name() == "headless":
		return  # tests and CI don't need music
	_music_task = WorkerThreadPool.add_task(_generate_pieces.bind(style), false, "music")


func _generate_pieces(style: String) -> void:
	var seed_base: int = hash(style)
	for mood: String in ["day", "night", "drive"]:
		var stream: AudioStreamWAV = MusicGenerator.generate(style, mood, seed_base + mood.hash())
		_music_mutex.lock()
		if style == _music_style:
			_pieces[mood] = stream
		_music_mutex.unlock()


## Starts a piece now (title screen) if one is ready.
func play_music_now() -> void:
	_music_silence = 0.0


func _update_music(delta: float) -> void:
	if _music.playing:
		return
	_music_silence -= delta
	if _music_silence > 0.0:
		return
	var mood: String = "day"
	if TimeManager.get_night_factor() > 0.6:
		mood = "night"
	var travel := get_tree().get_first_node_in_group(&"travel") as TravelController
	if travel and GameState.player_mode == GameState.PlayerMode.DRIVING and travel.camper.get_speed_kmh() > 25.0:
		mood = "drive"
	_music_mutex.lock()
	var stream: AudioStreamWAV = _pieces.get(mood, _pieces.get("day"))
	_music_mutex.unlock()
	if stream == null:
		_music_silence = 2.0
		return
	_music.stream = stream
	_music.play()


func _exit_tree() -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
	_music.stop()
	_music.stream = null
	# Stop loops explicitly so their playbacks are freed on quit.
	for player: AudioStreamPlayer in [_wind, _rain, _crickets]:
		player.stop()
		player.stream = null


func play_thunder(distance_delay: float) -> void:
	await get_tree().create_timer(distance_delay).timeout
	var player := AudioStreamPlayer.new()
	player.stream = _thunder_stream
	player.bus = BUS_AMBIENCE
	player.volume_db = -2.0 - distance_delay * 2.0
	player.pitch_scale = _rng.randf_range(0.8, 1.1)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _update_birds(delta: float, w: WeatherProfile, night: float) -> void:
	_bird_timer -= delta
	if _bird_timer > 0.0:
		return
	var activity: float = w.birds * (1.0 - night) * region_bird_density
	_bird_timer = lerpf(9.0, 1.5, activity) * _rng.randf_range(0.6, 1.4)
	if activity < 0.05 or _rng.randf() > activity + 0.2:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var bird := AudioStreamPlayer3D.new()
	bird.stream = _bird_streams[_rng.randi() % _bird_streams.size()]
	bird.bus = BUS_AMBIENCE
	bird.unit_size = 18.0
	bird.volume_db = _rng.randf_range(-14.0, -6.0)
	bird.pitch_scale = _rng.randf_range(0.85, 1.2)
	add_child(bird)
	var angle: float = _rng.randf() * TAU
	bird.global_position = camera.global_position + Vector3(cos(angle), 0.4, sin(angle)) * _rng.randf_range(10.0, 35.0)
	bird.play()
	bird.finished.connect(bird.queue_free)


func _make_loop(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS_AMBIENCE
	player.volume_db = SILENT_DB
	add_child(player)
	player.play()
	return player


func _fade(player: AudioStreamPlayer, target_db: float, delta: float) -> void:
	player.volume_db = move_toward(player.volume_db, target_db, FADE_DB_PER_SEC * delta)


func _lin_to_db(value: float) -> float:
	return SILENT_DB if value <= 0.001 else maxf(linear_to_db(value), SILENT_DB)


func _ensure_buses() -> void:
	for bus_name: StringName in [BUS_MUSIC, BUS_SFX, BUS_AMBIENCE]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"Master")
