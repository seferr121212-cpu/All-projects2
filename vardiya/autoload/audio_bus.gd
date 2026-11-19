extends Node
## Audio buses and simple one-shot playback. Version 1 has no voice acting;
## all sounds are optional placeholders (missing files are silently skipped).

const BUSES: PackedStringArray = ["Music", "SFX", "UI"]
const SOUND_DIR := "res://assets/audio/"
const UI_PLAYERS := 4

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")
	for i in UI_PLAYERS:
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)


func apply_volumes(settings: Dictionary) -> void:
	_set_volume("Master", float(settings.get("master_volume", 1.0)))
	_set_volume("Music", float(settings.get("music_volume", 0.8)))
	_set_volume("SFX", float(settings.get("sfx_volume", 0.8)))
	_set_volume("UI", float(settings.get("sfx_volume", 0.8)))


func _set_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)


func _stream(sound_name: String) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var stream: AudioStream = null
	for ext in [".ogg", ".wav"]:
		var path: String = SOUND_DIR + sound_name + ext
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	_cache[sound_name] = stream
	return stream


## Play a short UI/SFX cue, e.g. "ui/select". No-op if the file is absent.
func play(sound_name: String) -> void:
	var stream := _stream(sound_name)
	if stream == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return


func play_music(track: String) -> void:
	var stream := _stream("music/" + track)
	if stream == null or _music.stream == stream:
		return
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()
