extends Node
## Diyalog oynatıcı. Satırları anahtarla oynatır (C1_010 gibi), altyazı gösterir,
## varsa res://audio/vo/<dil>/<ANAHTAR>.ogg (veya .wav) dosyasını uygun filtre bus'ından çalar.
##
## Kullanım:  await Dialogue.play(["C1_010", "C1_011"], true)   # true = oyuncu kilitli (ara sahne)
##            Dialogue.play(["C1_031"])                         # beklemeden, oynanış sırasında

signal sequence_finished

var busy := false
var _skip := false
var _locked_seq := false
var _layer: CanvasLayer
var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _skip_hint: Label
var _voice: AudioStreamPlayer
var _portrait: TextureRect
var portrait_override := {}   # "kerem" -> "kerem_child" gibi (pröloğ, ara bölüm)
var _queue_count := 0
var _abort := false


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 45
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -760
	_panel.offset_right = 760
	_panel.offset_top = -250
	_panel.offset_bottom = -70
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	_panel.add_child(hb)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(120, 120)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_portrait)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 26)
	_speaker.add_theme_color_override("font_color", Color(1.0, 0.72, 0.42))
	vb.add_child(_speaker)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 34)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_text)
	_skip_hint = Label.new()
	_skip_hint.add_theme_font_size_override("font_size", 18)
	_skip_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(_skip_hint)
	_panel.visible = false
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)


func _unhandled_input(event: InputEvent) -> void:
	if busy and _locked_seq and event.is_action_pressed("interact"):
		_skip = true
		get_viewport().set_input_as_handled()


func stop_all() -> void:
	_skip = true
	_abort = true
	_voice.stop()
	_panel.visible = false


func play(keys: Array, lock := false) -> void:
	_queue_count += 1
	while busy:
		await sequence_finished
	_queue_count -= 1
	busy = true
	_abort = false
	_locked_seq = lock
	if lock:
		GameState.input_locked += 1
	for k in keys:
		if _abort:
			break
		await _play_line(str(k))
	if lock:
		GameState.input_locked = maxi(0, GameState.input_locked - 1)
	busy = false
	_locked_seq = false
	_panel.visible = false
	sequence_finished.emit()


func _voice_stream(key: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://audio/vo/%s/%s.%s" % [Loc.voice_lang, key, ext]
		if ResourceLoader.exists(path):
			var r = load(path)
			if r is AudioStream:
				return r
	return null


func _play_line(key: String) -> void:
	_skip = false
	var text := Loc.t(key)
	var flt := Loc.filter(key)
	var spk := Loc.speaker(key)
	var show_subs: bool = bool(GameState.settings.get("subtitles", true)) or flt == "caption"
	_speaker.text = Loc.speaker_name(key)
	_text.text = text
	_skip_hint.text = Loc.t("UI_SKIP") if _locked_seq else ""
	var col := Color(1, 1, 1)
	match flt:
		"echo":
			col = Color(0.72, 0.78, 0.86)
			_text.text = "~ " + text + " ~"
		"radio":
			col = Color(0.85, 0.95, 0.85)
		"inner":
			col = Color(0.9, 0.9, 0.9, 0.85)
			_text.text = "(" + text + ")"
		"letter":
			col = Color(1.0, 0.93, 0.8)
		"caption":
			col = Color(1.0, 0.85, 0.6)
	_text.add_theme_color_override("font_color", col)
	if spk == "text":
		_speaker.text = ""
	var sz: int = int(GameState.settings.get("sub_size", 1))
	_text.add_theme_font_size_override("font_size", [28, 34, 44][clampi(sz, 0, 2)])
	_speaker.add_theme_font_size_override("font_size", [22, 26, 32][clampi(sz, 0, 2)])
	_panel.visible = show_subs and text != ""
	# portre
	var pk := spk
	if portrait_override.has(spk):
		pk = str(portrait_override[spk])
	var ptex: Texture2D = null
	if pk in ["kerem", "yusuf", "riza", "husnu", "kerem_child", "husnu_young"]:
		ptex = Art.tex("portraits/%s.png" % pk)
	_portrait.texture = ptex
	_portrait.visible = ptex != null
	var dur := clampf(1.6 + text.length() * 0.055, 2.2, 11.0)
	# daktilo efekti
	_text.visible_ratio = 0.0
	var tw := create_tween()
	tw.tween_property(_text, "visible_ratio", 1.0, clampf(text.length() * 0.022, 0.3, 1.8))
	var stream := _voice_stream(key)
	if stream:
		_voice.stream = stream
		match flt:
			"echo":
				_voice.bus = "Echo"
			"radio":
				_voice.bus = "Radio"
			_:
				_voice.bus = "Voice"
		_voice.play()
		dur = stream.get_length() + 0.35
	elif flt == "radio":
		AudioManager.play_sfx("static", -18.0)
	var t := 0.0
	while t < dur and not _skip:
		await get_tree().process_frame
		if _skip and _text.visible_ratio < 1.0:
			# ilk basış: yazının tamamını göster, ikinci basış: geç
			tw.kill()
			_text.visible_ratio = 1.0
			_skip = false
		if not get_tree().paused:
			t += get_process_delta_time()
	_voice.stop()
	_panel.visible = false
	await get_tree().create_timer(0.12).timeout
