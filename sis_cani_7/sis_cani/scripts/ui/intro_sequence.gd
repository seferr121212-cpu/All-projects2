class_name IntroSequence
extends Node
## Oyun açılışı: 1) NexDrive Game Studio logosu  2) SİS ÇANI sinematik başlık introsu.
## Herhangi bir tuş / tık / gamepad düğmesi ile geçilebilir.

var skip := false
var _layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed):
		skip = true
		get_viewport().set_input_as_handled()


## Süre kadar bekler; geçilirse erken döner.
func _wait(secs: float) -> void:
	var t := 0.0
	while t < secs and not skip:
		await get_tree().process_frame
		t += get_process_delta_time()


func _clear() -> void:
	if _layer and is_instance_valid(_layer):
		_layer.queue_free()
	for c in get_children():
		c.queue_free()
	_layer = null


func _fade_rect(layer: CanvasLayer, a: float) -> ColorRect:
	var r := ColorRect.new()
	r.position = Vector2.ZERO
	r.size = Vector2(1920, 1080)
	r.color = Color(0, 0, 0, a)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	return r


# ------------------------------------------------------------ 1) stüdyo logosu
func studio_splash() -> void:
	skip = false
	_layer = CanvasLayer.new()
	_layer.layer = 35
	add_child(_layer)
	var bg := ColorRect.new()
	bg.size = Vector2(1920, 1080)
	bg.color = Color(0.02, 0.025, 0.035)
	_layer.add_child(bg)
	# arkada hafif deniz yeşili parıltı
	var glow := Sprite2D.new()
	glow.texture = Art.tex("fx/glow.png")
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.material = Art.glow_material()
	glow.position = Vector2(960, 520)
	glow.scale = Vector2(9.0, 3.2)
	glow.modulate = Color(0.2, 0.6, 0.6, 0.0)
	_layer.add_child(glow)
	var tex: Texture2D = Art.tex("ui/studio_logo.png")
	var logo := TextureRect.new()
	logo.texture = tex
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var w := 820.0
	var h := w * tex.get_size().y / tex.get_size().x
	logo.size = Vector2(w, h)
	logo.pivot_offset = logo.size / 2.0
	logo.position = Vector2((1920.0 - w) / 2.0, (1080.0 - h) / 2.0 - 10.0)
	logo.modulate.a = 0.0
	logo.scale = Vector2(0.96, 0.96)
	logo.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_layer.add_child(logo)
	# logonun üzerinden geçen ışık şeridi (yalnızca logonun içinde görünür)
	var shine := Polygon2D.new()
	shine.polygon = PackedVector2Array([Vector2(0, -40), Vector2(70, -40), Vector2(-60, h + 40), Vector2(-130, h + 40)])
	shine.color = Color(1, 1, 1, 0.55)
	shine.position = Vector2(-200, 0)
	logo.add_child(shine)
	var fade := _fade_rect(_layer, 0.0)

	AudioManager.play_theme("studio", 0.0)
	await _wait(0.5)
	var tw := create_tween()
	tw.tween_property(logo, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(glow, "modulate:a", 0.35, 1.6)
	var zoom := create_tween()
	zoom.tween_property(logo, "scale", Vector2(1.0, 1.0), 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _wait(1.3)
	var sw := create_tween()
	sw.tween_property(shine, "position:x", w + 220.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(2.0)
	if skip:
		AudioManager.stop_theme(0.4)
	var out := create_tween()
	out.tween_property(fade, "color:a", 1.0, 0.4 if skip else 0.9)
	await out.finished
	tw.kill()
	zoom.kill()
	_clear()


# ------------------------------------------------------------ 2) başlık introsu
func title_intro() -> void:
	skip = false
	var tr := str(GameState.settings.get("lang", "tr")) == "tr"
	var bgl := Background.new()
	bgl.drift = 40.0
	add_child(bgl)
	bgl.setup_key("c1")
	AudioManager.set_ambience("c1")
	AudioManager.play_theme("intro", 0.0)
	_layer = CanvasLayer.new()
	_layer.layer = -8
	add_child(_layer)
	# büyük fener silueti
	var lh := Sprite2D.new()
	lh.texture = Art.tex("story/title_lighthouse.png")
	lh.centered = false
	lh.scale = Vector2(3, 3)
	lh.position = Vector2(1240, 1080 - 300 * 3 + 60)
	_layer.add_child(lh)
	var lantern := lh.position + Vector2(110, 40) * 3.0
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([Vector2(0, -14), Vector2(1900, -230), Vector2(1900, 230), Vector2(0, 14)])
	beam.vertex_colors = PackedColorArray([Color(1, 0.86, 0.6, 0.55), Color(1, 0.86, 0.6, 0.0), Color(1, 0.86, 0.6, 0.0), Color(1, 0.86, 0.6, 0.55)])
	beam.material = Art.glow_material()
	beam.position = lantern
	beam.visible = false
	_layer.add_child(beam)
	var halo := Sprite2D.new()
	halo.texture = Art.tex("fx/glow.png")
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	halo.material = Art.glow_material()
	halo.position = lantern
	halo.scale = Vector2(3.5, 3.5)
	halo.modulate = Color(1, 0.8, 0.5, 0.0)
	_layer.add_child(halo)
	# yağmur
	var rain := CPUParticles2D.new()
	rain.texture = Art.tex("fx/rain.png")
	rain.position = Vector2(1100, -40)
	rain.amount = 260
	rain.lifetime = 1.2
	rain.preprocess = 1.2
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(1300, 10)
	rain.direction = Vector2(-0.25, 1)
	rain.spread = 2.0
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 950.0
	rain.initial_velocity_max = 1150.0
	rain.scale_amount_min = 2.0
	rain.scale_amount_max = 2.0
	rain.modulate = Color(0.75, 0.8, 0.9, 0.45)
	_layer.add_child(rain)
	# başlık katmanı
	var top := CanvasLayer.new()
	top.layer = 35
	add_child(top)
	var title := TextureRect.new()
	title.texture = Art.tex("ui/logo.png")
	title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.size = Vector2(1200, 320)
	title.position = Vector2(110, 300)
	title.modulate.a = 0.0
	top.add_child(title)
	var font = load("res://fonts/Lora.ttf")
	var sub := Label.new()
	sub.text = "F O G   B E L L"
	sub.add_theme_font_override("font", font)
	sub.add_theme_font_size_override("font_size", 40)
	sub.add_theme_color_override("font_color", Color(0.85, 0.82, 0.76))
	sub.position = Vector2(300, 630)
	sub.modulate.a = 0.0
	top.add_child(sub)
	var place := Label.new()
	place.text = "Kırlangıç Adası · 1977" if tr else "Swallow Island · 1977"
	var it = load("res://fonts/Lora-Italic.ttf")
	place.add_theme_font_override("font", it)
	place.add_theme_font_size_override("font_size", 30)
	place.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45))
	place.position = Vector2(302, 690)
	place.modulate.a = 0.0
	top.add_child(place)
	var fade := _fade_rect(top, 1.0)

	# 0: karanlıktan açılış
	var f_in := create_tween()
	f_in.tween_property(fade, "color:a", 0.0, 2.6).set_trans(Tween.TRANS_SINE)
	await _wait(2.2)
	# 1: şimşek
	if not skip:
		bgl.flash = 1.0
		bgl.bolt()
		AudioManager.ui_sfx("thunder", -4.0, 1.0)
		create_tween().tween_property(bgl, "flash", 0.0, 0.7)
	await _wait(1.2)
	# 2: fener yanar, büyük çan çalar
	if not skip:
		AudioManager.ui_sfx("bell_big", -16.0, 1.0)
		beam.visible = true
		create_tween().tween_property(halo, "modulate:a", 0.8, 0.6)
	var beam_tw := create_tween().set_loops()
	beam_tw.tween_method(_spin_beam.bind(beam, halo), 0.0, TAU, 6.5)
	await _wait(0.8)
	# 3: başlık
	var ti := create_tween()
	ti.tween_property(title, "modulate:a", 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	ti.parallel().tween_property(title, "position:y", 280.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _wait(1.4)
	var ts := create_tween()
	ts.tween_property(sub, "modulate:a", 1.0, 1.2)
	ts.tween_property(place, "modulate:a", 1.0, 1.2)
	await _wait(4.2)
	# 4: kararma
	# menü teması introdan devralır
	AudioManager.play_theme("menu", 1.2 if skip else 2.5, true)
	var f_out := create_tween()
	f_out.tween_property(fade, "color:a", 1.0, 0.4 if skip else 1.4)
	await f_out.finished
	beam_tw.kill()
	for n in [f_in, ti, ts]:
		if n and n.is_valid():
			n.kill()
	_clear()


func _spin_beam(a: float, beam: Polygon2D, halo: Sprite2D) -> void:
	if not is_instance_valid(beam):
		return
	var c := cos(a)
	beam.scale = Vector2(-c, 1.0)
	beam.modulate.a = pow(absf(c), 0.5) if beam.visible else 0.0
	var hs := 2.6 + 3.2 * pow(1.0 - absf(c), 6.0)
	halo.scale = Vector2(hs, hs)
