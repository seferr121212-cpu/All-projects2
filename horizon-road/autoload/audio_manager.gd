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


func _ready() -> void:
	_rng.randomize()
	_ensure_buses()
	_wind = _make_loop(ProceduralAudio.wind())
	_rain = _make_loop(ProceduralAudio.rain())
	_crickets = _make_loop(ProceduralAudio.crickets())
	for i: int in 6:
		_bird_streams.append(ProceduralAudio.bird_chirp(100 + i))
	_thunder_stream = ProceduralAudio.thunder()


func _process(delta: float) -> void:
	var w: WeatherProfile = WeatherManager.current
	var night: float = TimeManager.get_night_factor()
	_fade(_wind, _lin_to_db(0.25 + w.wind * 0.75) - 6.0, delta)
	_fade(_rain, _lin_to_db(w.rain), delta)
	_fade(_crickets, _lin_to_db(night * (1.0 - w.rain) * (1.0 - w.snow) * 0.6), delta)
	_update_birds(delta, w, night)


func _exit_tree() -> void:
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
