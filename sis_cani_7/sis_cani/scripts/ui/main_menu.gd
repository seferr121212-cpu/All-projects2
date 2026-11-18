class_name MainMenu
extends Control
## Ana menü.

var _main
var _beam: Polygon2D
var _halo: Sprite2D
var _t := 0.0


func setup(main) -> MainMenu:
	_main = main
	return self


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Loc.language_changed.connect(_build)


func _build() -> void:
	for c in get_children():
		if c is SettingsMenu:
			continue
		c.queue_free()
	var bgl := Background.new()
	bgl.drift = 30.0
	add_child(bgl)
	bgl.setup_key("c1")
	# uzak fenerin dönen huzmesi + yağmur + son işleme
	var fx := CanvasLayer.new()
	fx.layer = -9
	add_child(fx)
	_beam = Polygon2D.new()
	_beam.polygon = PackedVector2Array([Vector2(0, -6), Vector2(1500, -90), Vector2(1500, 90), Vector2(0, 6)])
	_beam.vertex_colors = PackedColorArray([Color(1, 0.85, 0.6, 0.5), Color(1, 0.85, 0.6, 0.0), Color(1, 0.85, 0.6, 0.0), Color(1, 0.85, 0.6, 0.5)])
	_beam.material = Art.glow_material()
	fx.add_child(_beam)
	_halo = Sprite2D.new()
	_halo.texture = Art.tex("fx/glow.png")
	_halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_halo.material = Art.glow_material()
	_halo.modulate = Color(1, 0.8, 0.5, 0.6)
	fx.add_child(_halo)
	var rain := CPUParticles2D.new()
	rain.texture = Art.tex("fx/rain.png")
	rain.position = Vector2(1100, -40)
	rain.amount = 200
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
	rain.scale_amount_max = 3.0
	rain.modulate = Color(1, 1, 1, 0.45)
	fx.add_child(rain)
	if bool(GameState.settings.get("postfx", true)):
		var pl := CanvasLayer.new()
		pl.layer = -1
		add_child(pl)
		var pr := ColorRect.new()
		pr.set_anchors_preset(Control.PRESET_FULL_RECT)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pm := ShaderMaterial.new()
		pm.shader = load("res://shaders/postfx.gdshader")
		pr.material = pm
		pl.add_child(pr)
	add_child(UIKit.dim_bg(0.35))
	var box := VBoxContainer.new()
	box.position = Vector2(180, 220)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var logo := TextureRect.new()
	logo.texture = Art.tex("ui/logo.png")
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.custom_minimum_size = Vector2(300 * 3, 80 * 3)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	box.add_child(logo)
	box.add_child(UIKit.label("FOG BELL  ·  " + Loc.t("UI_SUBTITLE"), 30, Color(1.0, 0.72, 0.42)))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 50)
	box.add_child(sp)
	var cont := UIKit.button(Loc.t("UI_CONTINUE"), func(): _main.continue_game())
	cont.disabled = not GameState.has_save()
	box.add_child(cont)
	var ng := UIKit.button(Loc.t("UI_NEW_GAME"), func(): _main.start_new_game())
	box.add_child(ng)
	box.add_child(UIKit.button(Loc.t("UI_CHAPTERS"), _chapters))
	box.add_child(UIKit.button(Loc.t("UI_ACHIEVEMENTS"), _achievements))
	box.add_child(UIKit.button(Loc.t("UI_SETTINGS"), func(): add_child(SettingsMenu.new())))
	box.add_child(UIKit.button(Loc.t("UI_QUIT"), func(): get_tree().quit()))
	_studio_badge()
	for c in get_children():
		if c is SettingsMenu and not c.is_queued_for_deletion():
			move_child(c, -1)
			return
	if cont.disabled:
		ng.grab_focus.call_deferred()
	else:
		cont.grab_focus.call_deferred()


func _overlay(title: String) -> VBoxContainer:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	return UIKit.frame(layer, title, Vector2(1240, 760))


func _top_layer() -> Control:
	return get_child(get_child_count() - 1) as Control


func _chapters() -> void:
	var box := _overlay(Loc.t("UI_CHAPTERS"))
	var layer := _top_layer()
	var unlocked := int(GameState.settings.get("unlocked", 1))
	var order := [[0, "CH0_TITLE", 1], [1, "CH1_TITLE", 1], [2, "CH2_TITLE", 2], [4, "CHI_TITLE", 3], [5, "CH5_TITLE", 4], [3, "CH3_TITLE", 5]]
	var page_range := {0: [], 1: [1, 2, 3, 4], 2: [5, 6, 7, 8], 4: [], 5: [], 3: [9, 10, 11, 12]}
	for o in order:
		var n: int = o[0]
		var b := UIKit.button(Loc.t(str(o[1])), func(): _main.start_chapter_select(n))
		b.add_theme_font_size_override("font_size", 30)
		b.disabled = int(o[2]) > unlocked
		if b.disabled:
			b.text += "  (" + Loc.t("UI_LOCKED") + ")"
		else:
			var pr: Array = page_range[n]
			var saved_pages: Array = GameState._read_json(GameState.SAVE_PATH).get("pages", [])
			if not pr.is_empty():
				var got := 0
				for pi in pr:
					if ("P%02d" % int(pi)) in saved_pages:
						got += 1
				b.text += "   ·  %d/%d" % [got, pr.size()]
		box.add_child(b)
	var back := UIKit.button(Loc.t("UI_BACK"), func(): layer.queue_free())
	box.add_child(back)
	back.grab_focus.call_deferred()


func _achievements() -> void:
	var box := _overlay(Loc.t("UI_ACHIEVEMENTS"))
	var layer := _top_layer()
	var got: Array = GameState.settings.get("achievements", [])
	for id in GameState.ACHIEVEMENTS:
		var ok: bool = id in got
		var l := UIKit.label(("✓  " if ok else "·  ") + Loc.t("ACH_" + id) + "  —  " + Loc.t("ACH_" + id + "_D"), 26,
			Color(1.0, 0.8, 0.5) if ok else Color(0.6, 0.62, 0.66))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	var back := UIKit.button(Loc.t("UI_BACK"), func(): layer.queue_free())
	box.add_child(back)
	back.grab_focus.call_deferred()


func _process(delta: float) -> void:
	if _beam == null or not is_instance_valid(_beam):
		return
	_t += delta
	# arka plandaki fenerin ekran konumu (deniz katmanı: parallax 0.06, menü kayması 30 px/sn)
	var off := _t * 30.0 * 0.06 / 2.0
	var sx := fposmod((520.0 - off) * 2.0, 1920.0)
	var pos := Vector2(sx, 424.0)
	_beam.position = pos
	_halo.position = pos
	var c := cos(_t * 0.9)
	_beam.scale = Vector2(c, 1.0)
	_beam.modulate.a = pow(absf(c), 0.5)
	# fener yalnızca Çan sonundan sonra yanar; öncesinde sönük ve zayıf bir kızıllık
	var lit := bool(GameState.settings.get("lit", false))
	_beam.visible = lit
	_halo.modulate = Color(1, 1, 1, 1) if lit else Color(0.5, 0.25, 0.2, 0.35)
	var hs := 0.35 + 0.65 * pow(1.0 - absf(c), 6.0)
	_halo.scale = Vector2(hs, hs)


## Sağ altta yarı saydam NexDrive Game Studio logosu; üzerine gelince belirginleşir.
func _studio_badge() -> void:
	var tex: Texture2D = Art.tex("ui/studio_logo.png")
	if tex == null:
		return
	var badge := TextureRect.new()
	badge.texture = tex
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	var w := 250.0
	var h := w * tex.get_size().y / tex.get_size().x
	badge.size = Vector2(w, h)
	badge.position = Vector2(1920.0 - w - 40.0, 1080.0 - h - 34.0)
	badge.modulate = Color(1, 1, 1, 0.0)
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(badge)
	var tw := badge.create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(badge, "modulate:a", 0.35, 1.5)
	badge.mouse_entered.connect(func(): badge.create_tween().tween_property(badge, "modulate:a", 0.8, 0.3))
	badge.mouse_exited.connect(func(): badge.create_tween().tween_property(badge, "modulate:a", 0.35, 0.5))
