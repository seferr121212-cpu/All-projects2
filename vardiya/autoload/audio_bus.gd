extends Node
## Audio buses, one-shot cues, an ambience bed and music, each with a
## crossfade. Version 1 has no voice acting. A file under assets/audio/
## (.ogg / .wav) wins when it exists; otherwise SoundSynth renders an
## own-work placeholder: UI cues on demand, loops on a worker thread so the
## main thread never stalls.

const SoundSynth = preload("res://scenes/audio/sound_synth.gd")
const BUSES: PackedStringArray = ["Music", "SFX", "UI"]
const SOUND_DIR := "res://assets/audio/"
const UI_PLAYERS := 4
const FADE_SEC := 1.5
const AMBIENCE_DB := -8.0
const MUSIC_DB := -10.0

var _players: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _ambience: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _tasks: Dictionary = {}  # cache key -> WorkerThreadPool task id
var _want := {"music": "", "ambience": ""}
var _current := {"music": "", "ambience": ""}
var _fades: Dictionary = {}  # player -> running Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")
	for i in UI_PLAYERS:
		_players.append(_make_player("UI"))
	for i in 2:
		_music.append(_make_player("Music"))
		_ambience.append(_make_player("SFX"))


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _exit_tree() -> void:
	for key: String in _tasks:
		WorkerThreadPool.wait_for_task_completion(int(_tasks[key]))
	_tasks.clear()


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


func _file_stream(sound_name: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		var path: String = SOUND_DIR + sound_name + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _stream(sound_name: String) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var stream := _file_stream(sound_name)
	if stream == null and sound_name.begins_with("ui/"):
		stream = SoundSynth.cue(sound_name)
	_cache[sound_name] = stream
	return stream


## Play a short UI/SFX cue, e.g. "ui/select".
func play(sound_name: String) -> void:
	var stream := _stream(sound_name)
	if stream == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return


## Music by mood id (SoundSynth.MUSIC) or a file under assets/audio/music/. "" fades out.
func play_music(track: String) -> void:
	_request("music", track)


func stop_music() -> void:
	_request("music", "")


## Ambience bed by id (SoundSynth.AMBIENCES) or a file under assets/audio/ambience/. "" fades out.
func play_ambience(id: String) -> void:
	_request("ambience", id)


func current(channel: String) -> String:
	return str(_current.get(channel, ""))


func _request(channel: String, id: String) -> void:
	_want[channel] = id
	if id == "":
		_switch(channel, "", null)
		return
	var key := channel + "/" + id
	if _cache.has(key):
		_switch(channel, id, _cache[key])
		return
	var file := _file_stream(key)
	if file != null:
		_cache[key] = file
		_switch(channel, id, file)
		return
	if not _tasks.has(key):
		_tasks[key] = WorkerThreadPool.add_task(_render.bind(channel, id), false, "audio " + key)


## Worker thread: pure computation, hands the stream back to the main thread.
func _render(channel: String, id: String) -> void:
	var stream: AudioStream = SoundSynth.music(id) if channel == "music" else SoundSynth.ambience(id)
	_on_rendered.call_deferred(channel, id, stream)


func _on_rendered(channel: String, id: String, stream: AudioStream) -> void:
	var key := channel + "/" + id
	if _tasks.has(key):
		WorkerThreadPool.wait_for_task_completion(int(_tasks[key]))
		_tasks.erase(key)
	_cache[key] = stream
	if str(_want[channel]) == id:
		_switch(channel, id, stream)


func _switch(channel: String, id: String, stream: AudioStream) -> void:
	if str(_current[channel]) == id:
		return
	_current[channel] = id
	var pair: Array[AudioStreamPlayer] = _music if channel == "music" else _ambience
	var target_db := MUSIC_DB if channel == "music" else AMBIENCE_DB
	var old := pair[0]
	var fresh := pair[1]
	pair[0] = fresh
	pair[1] = old
	if old.playing:
		var out := _fade(old)
		out.tween_property(old, "volume_db", -60.0, FADE_SEC)
		out.tween_callback(old.stop)
	if stream == null:
		return
	fresh.stream = stream
	fresh.volume_db = -60.0
	fresh.play()
	_fade(fresh).tween_property(fresh, "volume_db", target_db, FADE_SEC)


## New tween for `player`, cancelling a fade still running on it.
func _fade(player: AudioStreamPlayer) -> Tween:
	var running: Tween = _fades.get(player)
	if running and running.is_valid():
		running.kill()
	var tw := create_tween()
	_fades[player] = tw
	return tw
