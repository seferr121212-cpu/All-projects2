extends Node
## Ses: bus kurulumu (Yankı ve Telsiz filtreleri), kod ile üretilen yer tutucu sesler,
## 3 katmanlı dinamik müzik. Gerçek ses dosyaları audio/ klasörüne konunca onları kullanır.

const RATE := 22050
const LOW_RATE := 11025

var sfx: Dictionary = {}
var _sfx_players: Array = []
var _music: Array = []          # [safe, tension, chase]
var _music_target := [1.0, 0.0, 0.0]
var _ambient: AudioStreamPlayer
var _amb2: AudioStreamPlayer
var _amb_streams: Dictionary = {}
var _drip_t := 0.0
var drips := false
var intensity: int = 0          # 0 güvenli, 1 gerilim, 2 kovalama
var _ready_done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "SFX"
	add_child(_ambient)
	_amb2 = AudioStreamPlayer.new()
	_amb2.bus = "SFX"
	add_child(_amb2)
	call_deferred("_generate")


func _bus(bus_name: String, send: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return idx
	idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)
	return idx


func _make_buses() -> void:
	_bus("Music", "Master")
	_bus("SFX", "Master")
	_bus("Voice", "Master")
	var echo := _bus("Echo", "Voice")
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.85
	rev.wet = 0.45
	AudioServer.add_bus_effect(echo, rev)
	var dly := AudioEffectDelay.new()
	AudioServer.add_bus_effect(echo, dly)
	var ps := AudioEffectPitchShift.new()
	ps.pitch_scale = 0.92
	AudioServer.add_bus_effect(echo, ps)
	var radio := _bus("Radio", "Voice")
	var bp := AudioEffectBandPassFilter.new()
	bp.cutoff_hz = 1800.0
	AudioServer.add_bus_effect(radio, bp)
	var dist := AudioEffectDistortion.new()
	dist.drive = 0.35
	AudioServer.add_bus_effect(radio, dist)
	apply_volumes()


func apply_volumes() -> void:
	var s: Dictionary = GameState.settings
	_set_vol("Master", float(s.get("master", 1.0)))
	_set_vol("Music", float(s.get("music", 0.7)))
	_set_vol("SFX", float(s.get("sfx", 0.9)))
	_set_vol("Voice", float(s.get("voice", 1.0)))


func _set_vol(bus_name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))


# ------------------------------------------------------------------ synthesis
func _wav(samples: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _tone(dur: float, freqs: Array, decay: float, noise := 0.0, smooth := 1.0, rate := RATE) -> AudioStreamWAV:
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var prev := 0.0
	var norm := 0.0
	var amps := PackedFloat32Array()
	var ws := PackedFloat32Array()
	for j in freqs.size():
		amps.append(pow(0.6, j))
		ws.append(TAU * float(freqs[j]))
		norm += pow(0.6, j)
	norm = maxf(norm, 1.0)
	var fc := freqs.size()
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for j in fc:
			v += sin(ws[j] * t) * amps[j]
		v /= norm
		if noise > 0.0:
			prev = lerpf(prev, rng.randf_range(-1.0, 1.0), smooth)
			v += prev * noise
		v *= exp(-t * decay) * minf(1.0, t * 300.0)
		out[i] = v * 0.8
	return _wav(out, rate)


func _drone(freqs: Array, pulse: float, rate := LOW_RATE) -> AudioStreamWAV:
	# 8 saniyelik döngü; tüm frekanslar 1/8 Hz'in katı olmalı ki döngü kesintisiz olsun.
	var dur := 8.0
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for j in freqs.size():
			v += sin(TAU * float(freqs[j]) * t) * (0.5 + 0.5 * sin(TAU * 0.125 * (j + 1) * t))
		v /= float(freqs.size())
		if pulse > 0.0:
			v *= 0.6 + 0.4 * absf(sin(TAU * pulse * t))
		out[i] = v * 0.5
	return _wav(out, rate, true)


func _heartbeat(rate := LOW_RATE) -> AudioStreamWAV:
	var n := int(0.7 * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for st in [0.0, 0.22]:
			var tt: float = t - st
			if tt > 0.0:
				v += sin(TAU * 48.0 * tt) * exp(-tt * 18.0) * (1.0 if st == 0.0 else 0.7)
		out[i] = v
	return _wav(out, rate)


func _sea(rate := LOW_RATE) -> AudioStreamWAV:
	var dur := 8.0
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var prev := 0.0
	for i in n:
		var t := float(i) / rate
		prev = lerpf(prev, rng.randf_range(-1.0, 1.0), 0.04)
		out[i] = prev * (0.35 + 0.3 * sin(TAU * 0.25 * t)) * 1.6
	return _wav(out, rate, true)


## Döngülü gürültü: smooth küçükse uğultu (rüzgar), büyükse hışırtı (yağmur). wobble: 8 sn içinde dalgalanma.
func _noise_loop(smooth: float, wobble: float, vol: float, rate := LOW_RATE) -> AudioStreamWAV:
	var n := int(8.0 * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var prev := 0.0
	for i in n:
		var t := float(i) / rate
		prev = lerpf(prev, rng.randf_range(-1.0, 1.0), smooth)
		var amp := 1.0 if wobble == 0.0 else (0.45 + 0.55 * absf(sin(TAU * wobble * t)))
		out[i] = prev * amp * vol * (1.0 if smooth > 0.1 else 3.0)
	# döngü kesintisini yumuşat
	for i in 400:
		var k := float(i) / 400.0
		out[n - 400 + i] = lerpf(out[n - 400 + i], out[i], k)
	return _wav(out, rate, true)


## Bölüme göre ortam sesleri: "c1" deniz+yağmur, "c2" mağara+damla, "c3" rüzgar+yağmur.
func set_ambience(key: String) -> void:
	if not _ready_done:
		await get_tree().process_frame
	var a := "sea"
	var b := "rain"
	drips = false
	match key:
		"c2":
			a = "cave"
			b = ""
			drips = true
		"c3":
			a = "wind"
			b = "rain"
	_ambient.stream = _amb_streams.get(a, null)
	_ambient.volume_db = -12.0
	_ambient.play()
	if b != "":
		_amb2.stream = _amb_streams.get(b, null)
		_amb2.volume_db = -16.0
		_amb2.play()
	else:
		_amb2.stop()


func _generate() -> void:
	sfx["bell_big"] = _load_or("res://audio/sfx/bell_big.ogg", func(): return _tone(6.0, [180.0, 432.0, 594.0, 905.0, 1210.0], 0.55))
	sfx["bell_hand"] = _load_or("res://audio/sfx/bell_hand.ogg", func(): return _tone(2.0, [620.0, 1490.0, 2050.0], 2.2))
	sfx["ignite"] = _load_or("res://audio/sfx/ignite.ogg", func(): return _tone(0.9, [90.0], 3.5, 0.9, 0.35))
	sfx["pickup"] = _load_or("res://audio/sfx/pickup.ogg", func(): return _tone(0.7, [880.0, 1320.0], 5.0))
	sfx["whisper"] = _load_or("res://audio/sfx/whisper.ogg", func(): return _tone(2.4, [], 1.1, 1.0, 0.08))
	sfx["click"] = _load_or("res://audio/sfx/click.ogg", func(): return _tone(0.18, [320.0, 640.0], 25.0, 0.3, 0.5))
	sfx["door"] = _load_or("res://audio/sfx/door.ogg", func(): return _tone(1.4, [55.0, 70.0], 1.8, 0.6, 0.03))
	sfx["static"] = _load_or("res://audio/sfx/static.ogg", func(): return _tone(1.0, [], 0.4, 0.7, 0.6))
	sfx["page"] = _load_or("res://audio/sfx/page.ogg", func(): return _tone(0.4, [], 6.0, 0.8, 0.25))
	sfx["step"] = _load_or("res://audio/sfx/step.ogg", func(): return _tone(0.12, [70.0], 30.0, 0.8, 0.25))
	sfx["drip"] = _load_or("res://audio/sfx/drip.ogg", func(): return _tone(0.35, [1650.0, 2470.0], 14.0))
	sfx["discover"] = _load_or("res://audio/sfx/discover.ogg", func(): return _tone(2.2, [392.0, 493.9, 587.3, 784.0], 1.6))
	sfx["splash"] = _load_or("res://audio/sfx/splash.ogg", func(): return _tone(0.5, [], 6.0, 0.9, 0.4))
	sfx["heart"] = _load_or("res://audio/sfx/heart.ogg", func(): return _heartbeat())
	sfx["sputter"] = _load_or("res://audio/sfx/sputter.ogg", func(): return _tone(0.25, [], 12.0, 0.9, 0.5))
	sfx["thunder"] = _load_or("res://audio/sfx/thunder.ogg", func(): return _tone(3.5, [38.0, 52.0], 0.9, 1.0, 0.02))
	sfx["whistle"] = _load_or("res://audio/sfx/whistle.ogg", func(): return _tone(4.0, [392.0, 466.0, 587.0, 784.0], 0.45, 0.2, 0.7))
	sfx["whoosh"] = _load_or("res://audio/sfx/whoosh.ogg", func(): return _tone(0.45, [], 7.0, 1.0, 0.12))
	sfx["creak"] = _load_or("res://audio/sfx/creak.ogg", func(): return _tone(0.6, [180.0, 187.0], 4.0, 0.25, 0.2))
	sfx["scrape"] = _load_or("res://audio/sfx/scrape.ogg", func(): return _tone(0.35, [], 3.0, 0.9, 0.08))
	sfx["chime"] = _load_or("res://audio/sfx/chime.ogg", func(): return _tone(5.0, [262.0, 629.0, 865.0], 0.7))
	sfx["crumble"] = _load_or("res://audio/sfx/crumble.ogg", func(): return _tone(0.8, [60.0], 3.0, 0.9, 0.15))
	var safe = _load_or("res://audio/music/safe.ogg", func(): return _drone([55.0, 82.5, 110.0], 0.0))
	var tension = _load_or("res://audio/music/tension.ogg", func(): return _drone([55.0, 58.25, 87.5], 0.0))
	var chase = _load_or("res://audio/music/chase.ogg", func(): return _drone([55.0, 58.25, 110.0, 116.5], 2.0))
	for s in [safe, tension, chase]:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.stream = s
		p.volume_db = -80.0
		add_child(p)
		_music.append(p)
	_ambient.stream = _load_or("res://audio/sfx/ambient_sea.ogg", func(): return _sea())
	_amb_streams["sea"] = _ambient.stream
	_amb_streams["rain"] = _load_or("res://audio/sfx/ambient_rain.ogg", func(): return _noise_loop(0.55, 0.0, 0.9))
	_amb_streams["wind"] = _load_or("res://audio/sfx/ambient_wind.ogg", func(): return _noise_loop(0.03, 0.125, 1.0))
	_amb_streams["cave"] = _load_or("res://audio/sfx/ambient_cave.ogg", func(): return _noise_loop(0.015, 0.0, 0.5))
	_ambient.volume_db = -14.0
	_ready_done = true


func _load_or(path: String, fallback: Callable) -> AudioStream:
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is AudioStream:
			return r
	return fallback.call()


# ------------------------------------------------------------------ play
var _cap_t: Dictionary = {}


func play_sfx(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not sfx.has(name):
		return
	if bool(GameState.settings.get("captions", true)) and GameState.hud and StringsDB.UI.has("CAP_" + name):
		var now := Time.get_ticks_msec() / 1000.0
		if now - float(_cap_t.get(name, -10.0)) > 2.0:
			_cap_t[name] = now
			GameState.hud.caption(Loc.t("CAP_" + name))
	for p in _sfx_players:
		var ap: AudioStreamPlayer = p
		if not ap.playing:
			ap.stream = sfx[name]
			ap.volume_db = volume_db
			ap.pitch_scale = pitch
			ap.play()
			return


## Dünyada bir noktadan gelen ses (stereo konum + uzaklıkla sönümleme).
var _pos_players: Array = []


func play_at(name: String, pos: Vector2, volume_db := 0.0, pitch := 1.0) -> void:
	if not sfx.has(name):
		return
	if _pos_players.is_empty():
		for i in 8:
			var ap2 := AudioStreamPlayer2D.new()
			ap2.bus = "SFX"
			ap2.max_distance = 1600.0
			ap2.attenuation = 1.6
			add_child(ap2)
			_pos_players.append(ap2)
	for q in _pos_players:
		var a: AudioStreamPlayer2D = q
		if not a.playing:
			a.global_position = pos
			a.stream = sfx[name]
			a.volume_db = volume_db
			a.pitch_scale = pitch
			a.play()
			return


## Menü sesleri: altyazı göstermez.
func ui_sfx(name: String, volume_db := -14.0, pitch := 1.0) -> void:
	if not sfx.has(name):
		return
	for p in _sfx_players:
		var ap: AudioStreamPlayer = p
		if not ap.playing:
			ap.stream = sfx[name]
			ap.volume_db = volume_db
			ap.pitch_scale = pitch
			ap.play()
			return


# ------------------------------------------------------------------ açılış/menü müziği
var _theme: AudioStreamPlayer
var _theme_name := ""


## Açılış ve menü müzikleri (audio/music/studio|intro|menu.ogg). Eskisini yumuşakça keser.
func play_theme(name: String, fade := 1.0, loop := false) -> void:
	if name == _theme_name and _theme and _theme.playing:
		return
	var path := "res://audio/music/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return
	var st = load(path)
	if st == null:
		return
	if st is AudioStreamOggVorbis:
		st.loop = loop
	stop_theme(fade)
	var ap := AudioStreamPlayer.new()
	ap.bus = "Music"
	ap.stream = st
	ap.volume_db = -40.0 if fade > 0.05 else 0.0
	add_child(ap)
	ap.play()
	if fade > 0.05:
		create_tween().tween_property(ap, "volume_db", 0.0, fade).set_trans(Tween.TRANS_SINE)
	_theme = ap
	_theme_name = name


func stop_theme(fade := 1.0) -> void:
	if _theme and is_instance_valid(_theme):
		var old := _theme
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, maxf(fade, 0.05))
		tw.tween_callback(old.queue_free)
	_theme = null
	_theme_name = ""


func start_music() -> void:
	stop_theme(1.5)
	if not _ready_done:
		await get_tree().process_frame
		if not _ready_done:
			_generate()
	for p in _music:
		var ap: AudioStreamPlayer = p
		if not ap.playing:
			ap.play()
	if not _ambient.playing:
		_ambient.play()


func stop_music() -> void:
	for p in _music:
		(p as AudioStreamPlayer).stop()
	_ambient.stop()
	_amb2.stop()
	drips = false


func set_intensity(level: int) -> void:
	intensity = level
	_music_target = [1.0, 0.0, 0.0]
	if level == 1:
		_music_target = [0.35, 1.0, 0.0]
	elif level >= 2:
		_music_target = [0.0, 0.5, 1.0]


func _process(delta: float) -> void:
	if drips:
		_drip_t -= delta
		if _drip_t <= 0.0:
			_drip_t = randf_range(1.2, 4.5)
			play_sfx("drip", randf_range(-22.0, -12.0), randf_range(0.8, 1.3))
	for i in _music.size():
		var ap: AudioStreamPlayer = _music[i]
		var cur := db_to_linear(ap.volume_db)
		var target: float = _music_target[i]
		cur = move_toward(cur, target, delta / 1.5)
		ap.volume_db = linear_to_db(maxf(cur, 0.0001))
