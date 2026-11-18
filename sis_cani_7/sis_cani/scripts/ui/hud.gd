class_name HUD
extends CanvasLayer
## Oyun içi arayüz: gazyağı göstergesi, lamba modu, el çanı bekleme süresi,
## etkileşim istemi + basılı tutma çubuğu, bildirimler, ipuçları, karanlık geri sayımı.

var _fuel_bar: ProgressBar
var _fuel_label: Label
var _mode_label: Label
var _bell_label: Label
var _prompt: Label
var _hold_bar: ProgressBar
var _toast_box: VBoxContainer
var _hint: Label
var _dark: Label
var _vignette: ColorRect
var _hint_t := 0.0
var _root: Control
var _obj_label: Label
var _obj_target := Vector2.INF
var _arrow: TextureRect
var _arrow_dist: Label
var _obj_flash := 0.0
var _bar_top: ColorRect
var _bar_bot: ColorRect
var _bars := 0.0
var _lamp_icon: TextureRect
var _danger_rect: TextureRect
var _danger := 0.0
var _caught_rect: TextureRect
var _save_icon: TextureRect
var _cap_box: VBoxContainer
var _timer_label: Label
var photo_mode := false
var _last_fuel := -1.0
var _refill := 0.0
var _idle_ui := 0.0
var _stuck_t := 0.0
var _stuck_key := ""
var _step_label: Label
var _markers: Array = []


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(0, 0, 0, 0)
	_root.add_child(_vignette)
	_danger_rect = _edge_vignette(Color(0.35, 0.02, 0.04))
	_caught_rect = _edge_vignette(Color(0.0, 0.0, 0.02))
	_caught_rect.modulate.a = 0.0
	_save_icon = TextureRect.new()
	_save_icon.texture = Art.tex("ui/lamp_icon.png")
	_save_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_save_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_save_icon.size = Vector2(36, 48)
	_save_icon.position = Vector2(1840, 990)
	_save_icon.pivot_offset = Vector2(18, 24)
	_save_icon.modulate.a = 0.0
	_save_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_save_icon)
	_cap_box = VBoxContainer.new()
	# diyalog kutusunun (alt 250 px) üstünde, yukarı doğru büyür; portreyle çakışmaz
	_cap_box.anchor_top = 1.0
	_cap_box.anchor_bottom = 1.0
	_cap_box.offset_left = 40
	_cap_box.offset_right = 600
	_cap_box.offset_top = -262
	_cap_box.offset_bottom = -262
	_cap_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cap_box.alignment = BoxContainer.ALIGNMENT_END
	_cap_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cap_box)
	_timer_label = _label("", 24, Color(1, 1, 1, 0.7))
	_timer_label.position = Vector2(1700, 1030)
	_root.add_child(_timer_label)
	_bar_top = ColorRect.new()
	_bar_top.color = Color(0, 0, 0)
	_bar_top.size = Vector2(1920, 0)
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar_top)
	_bar_bot = ColorRect.new()
	_bar_bot.color = Color(0, 0, 0)
	_bar_bot.size = Vector2(1920, 0)
	_bar_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar_bot)
	# sol üst: lamba
	var panel := ColorRect.new()
	panel.position = Vector2(22, 20)
	panel.size = Vector2(680, 200)
	panel.color = Color(0, 0, 0, 0.0)
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.55))
	g.set_color(1, Color(0, 0, 0, 0.0))
	grad.gradient = g
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(1, 0)
	var pt := TextureRect.new()
	pt.texture = grad
	pt.position = Vector2(0, 10)
	pt.size = Vector2(760, 230)
	pt.stretch_mode = TextureRect.STRETCH_SCALE
	pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pt)
	var box := VBoxContainer.new()
	box.position = Vector2(40, 34)
	box.custom_minimum_size = Vector2(320, 0)
	_root.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_lamp_icon = TextureRect.new()
	_lamp_icon.texture = Art.tex("ui/lamp_icon.png")
	_lamp_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lamp_icon.custom_minimum_size = Vector2(36, 48)
	_lamp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lamp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_lamp_icon)
	_fuel_label = _label("", 22, Color(1.0, 0.75, 0.45))
	_fuel_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_fuel_label)
	_fuel_bar = ProgressBar.new()
	_fuel_bar.max_value = 100
	_fuel_bar.show_percentage = false
	_fuel_bar.custom_minimum_size = Vector2(300, 14)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(1.0, 0.62, 0.25)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	_fuel_bar.add_theme_stylebox_override("fill", fg)
	_fuel_bar.add_theme_stylebox_override("background", bg)
	box.add_child(_fuel_bar)
	_mode_label = _label("", 18, Color(1, 1, 1, 0.6))
	box.add_child(_mode_label)
	_bell_label = _label("", 18, Color(0.9, 0.8, 0.55, 0.8))
	box.add_child(_bell_label)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 12)
	box.add_child(sp)
	_obj_label = _label("", 24, Color(0.95, 0.93, 0.88))
	_obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obj_label.custom_minimum_size = Vector2(620, 0)
	box.add_child(_obj_label)
	# "Nasıl": hedefin altında ne yapılacağını adım adım anlatan satır
	_step_label = _label("", 20, Color(0.82, 0.86, 0.92))
	_step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step_label.custom_minimum_size = Vector2(620, 0)
	box.add_child(_step_label)
	for i in 6:
		var mk := _label("◆", 30, Color(1.0, 0.78, 0.45))
		mk.visible = false
		mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(mk)
		_markers.append(mk)
	_arrow = TextureRect.new()
	_arrow.texture = Art.tex("ui/arrow.png")
	_arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arrow.size = Vector2(48, 48)
	_arrow.pivot_offset = Vector2(24, 24)
	_arrow.stretch_mode = TextureRect.STRETCH_SCALE
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	_root.add_child(_arrow)
	_arrow_dist = _label("", 20, Color(1.0, 0.85, 0.6))
	_arrow_dist.visible = false
	_root.add_child(_arrow_dist)
	# orta alt: istem
	_prompt = _label("", 26, Color(1, 1, 1, 0.9))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(800, 40)
	_root.add_child(_prompt)
	_hold_bar = ProgressBar.new()
	_hold_bar.show_percentage = false
	_hold_bar.max_value = 1.0
	_hold_bar.size = Vector2(160, 8)
	var hfg := StyleBoxFlat.new()
	hfg.bg_color = Color(1, 0.85, 0.6)
	_hold_bar.add_theme_stylebox_override("fill", hfg)
	_hold_bar.add_theme_stylebox_override("background", bg)
	_root.add_child(_hold_bar)
	# sağ üst: bildirimler
	_toast_box = VBoxContainer.new()
	_toast_box.anchor_left = 1.0
	_toast_box.anchor_right = 1.0
	_toast_box.offset_left = -620
	_toast_box.offset_right = -40
	_toast_box.offset_top = 34
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(_toast_box)
	# üst orta: ipucu
	_hint = _label("", 24, Color(1, 1, 1, 0.85))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.offset_left = -600
	_hint.offset_right = 600
	_hint.offset_top = 120
	_hint.offset_bottom = 220
	_root.add_child(_hint)
	_dark = _label("", 42, Color(1.0, 0.4, 0.3))
	_dark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dark.anchor_left = 0.5
	_dark.anchor_right = 0.5
	_dark.anchor_top = 0.5
	_dark.anchor_bottom = 0.5
	_dark.offset_left = -500
	_dark.offset_right = 500
	_dark.offset_top = -200
	_dark.offset_bottom = -140
	_root.add_child(_dark)


## Kenarlardan içe doğru koyulaşan tam ekran vinyet.
func _edge_vignette(col: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.0))
	g.add_point(0.55, Color(col.r, col.g, col.b, 0.0))
	g.set_color(g.get_point_count() - 1, Color(col.r, col.g, col.b, 1.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.05, 0.5)
	t.width = 256
	t.height = 256
	var r := TextureRect.new()
	r.texture = t
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate.a = 0.0
	r.pivot_offset = Vector2(960, 540)
	_root.add_child(r)
	return r


## Otomatik kayıt: köşede yanıp sönen lamba.
func saved_icon() -> void:
	var tw := create_tween()
	tw.tween_property(_save_icon, "modulate:a", 1.0, 0.3)
	tw.tween_property(_save_icon, "modulate:a", 0.3, 0.4)
	tw.tween_property(_save_icon, "modulate:a", 1.0, 0.4)
	tw.tween_property(_save_icon, "modulate:a", 0.0, 0.6)


## Ses altyazısı (erişilebilirlik): sol altta kısa süreli.
func caption(text: String) -> void:
	# aynı ses altyazısı zaten ekrandaysa yığma (ör. art arda cızırdama)
	for c in _cap_box.get_children():
		if c is Label and (c as Label).text == text and c.modulate.a > 0.5:
			return
	var l := _label(text, 22, Color(0.85, 0.88, 0.95, 0.85))
	_cap_box.add_child(l)
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func set_photo_mode(v: bool) -> void:
	photo_mode = v
	_root.visible = not v


func set_danger(v: float) -> void:
	_danger = v


## Yakalanma: karanlık kenarlardan içe kapanır.
func caught_fx() -> void:
	_caught_rect.modulate.a = 0.0
	_caught_rect.scale = Vector2(1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(_caught_rect, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(_caught_rect, "scale", Vector2(0.55, 0.55), 0.6).set_ease(Tween.EASE_IN)
	await tw.finished
	var tw2 := create_tween()
	tw2.tween_interval(0.9)
	tw2.tween_property(_caught_rect, "modulate:a", 0.0, 0.6)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func toast(text: String) -> void:
	var l := _label(text, 24, Color(1, 0.92, 0.8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toast_box.add_child(l)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


func hint(text: String, secs := 6.0) -> void:
	_hint.text = text
	_hint_t = secs


func set_objective(text: String, target := Vector2.INF) -> void:
	_obj_label.text = "◆ " + Loc.t("OBJ") + ": " + text
	_obj_target = target
	_obj_flash = 2.0
	AudioManager.play_sfx("discover", -16.0, 1.2)


func clear_objective() -> void:
	_obj_label.text = ""
	_obj_target = Vector2.INF


func _update_arrow() -> void:
	_arrow.visible = false
	_arrow_dist.visible = false
	var p = GameState.player
	if _obj_target == Vector2.INF or p == null or not is_instance_valid(p) or GameState.input_locked > 0:
		return
	# Bekçi zorluğunda yön oku yok
	if int(GameState.settings.get("difficulty", 1)) >= 2:
		return
	var ct := get_viewport().get_canvas_transform()
	var size := get_viewport().get_visible_rect().size
	var sp: Vector2 = ct * _obj_target
	var margin := 70.0
	var inside := sp.x > margin and sp.x < size.x - margin and sp.y > margin and sp.y < size.y - margin
	var dist: float = p.global_position.distance_to(_obj_target) / 40.0
	if dist < 3.0:
		return
	var center := size / 2.0
	var dir := (sp - center).normalized()
	var pos := sp + Vector2(0, -90)
	if not inside:
		var tx := (size.x / 2.0 - margin) / maxf(absf(dir.x), 0.001)
		var ty := (size.y / 2.0 - margin) / maxf(absf(dir.y), 0.001)
		pos = center + dir * minf(tx, ty)
		_arrow.rotation = dir.angle()
	else:
		_arrow.rotation = PI / 2.0
	_arrow.position = pos - Vector2(24, 24)
	_arrow.modulate.a = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 300.0))
	_arrow.visible = true
	_arrow_dist.text = "%d m" % int(dist)
	_arrow_dist.position = pos + Vector2(-24, 28)
	_arrow_dist.visible = true


var _hx_done := false


## Takılınca (20 sn) yakındaki kullanılabilir nesnelerin üstünde parlayan işaret.
func _update_markers(p) -> void:
	var on := _stuck_t > 20.0 and GameState.input_locked == 0 and int(GameState.settings.get("difficulty", 1)) < 2
	var used := 0
	if on:
		var ct := get_viewport().get_canvas_transform()
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 220.0)
		for n in get_tree().get_nodes_in_group("interactable"):
			if used >= _markers.size():
				break
			if not n.has_method("can_interact") or not n.can_interact(p):
				continue
			if n.global_position.distance_to(p.global_position) > 1100.0:
				continue
			var sp: Vector2 = ct * (n.global_position + Vector2(0, -95))
			if sp.x < 0 or sp.x > 1920 or sp.y < 0 or sp.y > 1080:
				continue
			var mk: Label = _markers[used]
			mk.position = sp - Vector2(10, 20 + 6.0 * pulse)
			mk.modulate.a = pulse
			mk.visible = true
			used += 1
	for i in range(used, _markers.size()):
		_markers[i].visible = false


## Metindeki {interact} gibi yer tutucuları oyuncunun gerçek tuşlarıyla değiştirir.
static func keys_text(t: String) -> String:
	var tr := str(GameState.settings.get("lang", "tr")) == "tr"
	for a in ["interact", "bell", "red_glass", "crouch", "throw", "jump", "run"]:
		var k := GameState.key_of(a)
		var kn := OS.get_keycode_string(k) if k != 0 else "?"
		t = t.replace("{" + a + "}", "[" + kn + "]")
	t = t.replace("{red}", "[" + OS.get_keycode_string(GameState.key_of("red_glass")) + "]")
	t = t.replace("{raise}", "[Sol Tık]" if tr else "[Left Click]")
	return t


func bell_wave(_pos: Vector2) -> void:
	if GameState.level and GameState.level.darkness:
		GameState.level.darkness.flash = 0.25


func _process(delta: float) -> void:
	var p = GameState.player
	if bool(GameState.settings.get("timer", false)):
		var t := int(GameState.playtime)
		_timer_label.text = "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]
	else:
		_timer_label.text = ""
	_bars = move_toward(_bars, 1.0 if GameState.input_locked > 0 else 0.0, delta * 2.0)
	var bh := 110.0 * _bars
	_bar_top.size = Vector2(1920, bh)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * lerpf(4.0, 12.0, _danger))
	_danger_rect.modulate.a = lerpf(_danger_rect.modulate.a, _danger * (0.35 + 0.35 * pulse), 0.2)
	_bar_bot.size = Vector2(1920, bh)
	_bar_bot.position = Vector2(0, 1080 - bh)
	_obj_flash = maxf(0.0, _obj_flash - delta)
	_obj_label.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.75, 0.4), clampf(_obj_flash, 0.0, 1.0))
	_update_arrow()
	_hint_t -= delta
	_hint.modulate.a = clampf(_hint_t, 0.0, 1.0)
	if p == null or not is_instance_valid(p):
		return
	var has_lamp := GameState.has_lamp
	_fuel_bar.visible = has_lamp
	_fuel_label.visible = has_lamp
	_lamp_icon.visible = has_lamp
	_mode_label.visible = has_lamp
	# takılma ipucu: aynı hedefte 75 sn kalınırsa
	var ok: String = str(GameState.flags.get("objective", ""))
	if ok != _stuck_key:
		_stuck_key = ok
		_stuck_t = 0.0
		_hx_done = false
		_step_label.text = ("→ " + keys_text(Loc.t("STEP_" + ok))) if StringsDB.UI.has("STEP_" + ok) else ""
	elif GameState.input_locked == 0 and ok != "":
		_stuck_t += delta
		if _stuck_t > 35.0 and not _hx_done and StringsDB.UI.has("HX_" + ok):
			_hx_done = true
			hint(keys_text(Loc.t("HX_" + ok)), 12.0)
	_step_label.visible = _obj_label.text != "" and GameState.input_locked == 0
	_update_markers(p)
	if has_lamp:
		# yakıt dolarken parıltı; sakin anlarda HUD solar
		if _last_fuel >= 0.0 and GameState.fuel > _last_fuel + 0.05:
			_refill = 1.0
		_last_fuel = GameState.fuel
		_refill = maxf(0.0, _refill - delta * 1.5)
		var calm: bool = GameState.fuel > 60.0 and _danger < 0.05 and p.interact_target == null and _refill <= 0.0
		_idle_ui = clampf(_idle_ui + (delta if calm else -delta * 4.0), 0.0, 6.0)
		var ua := 1.0 if _idle_ui < 4.0 else lerpf(1.0, 0.35, clampf(_idle_ui - 4.0, 0.0, 1.0))
		for c in [_fuel_bar, _fuel_label, _lamp_icon, _mode_label]:
			c.modulate.a = ua
		_fuel_bar.self_modulate = Color(1, 1, 1).lerp(Color(1.8, 1.4, 0.7), _refill)
		_fuel_bar.value = GameState.fuel
		_fuel_label.text = "%d" % int(GameState.fuel)
		_lamp_icon.modulate = Color(1, 1, 1) if p.lamp.mode != 0 else Color(0.5, 0.5, 0.55)
		if GameState.fuel < 20.0:
			_fuel_label.modulate = Color(1, 0.5, 0.4) if int(Time.get_ticks_msec() / 400) % 2 == 0 else Color(1, 1, 1)
		else:
			_fuel_label.modulate = Color(1, 1, 1)
		var m: int = p.lamp.mode
		var names := ["○", "◔", "◑", "●"]
		_mode_label.text = names[m] + ("   ▲ " + Loc.t("PICKUP_RED") if p.lamp.red else "")
	_bell_label.visible = GameState.has_bell
	if GameState.has_bell:
		var cd: float = p.bell_cd
		_bell_label.text = Loc.t("PICKUP_BELL") + (": %d" % int(ceil(cd)) if cd > 0.0 else " [Q]")
	# istem
	var tgt = p.interact_target
	if tgt != null and is_instance_valid(tgt) and GameState.input_locked == 0:
		var key: String = "[E] " if float(tgt.hold_time) <= 0.0 else "[E] … "
		_prompt.text = key + tgt.prompt_text()
		_prompt.visible = true
		var sp: Vector2 = get_viewport().get_canvas_transform() * (tgt.global_position + Vector2(0, -70))
		_prompt.position = sp - Vector2(400, 20)
		_hold_bar.position = sp + Vector2(-80, 26)
	else:
		_prompt.visible = false
	var hp: float = p.hold_progress()
	_hold_bar.visible = hp > 0.0
	_hold_bar.value = hp
	# karanlık
	var dr: float = p.dark_remaining()
	if dr >= 0.0:
		_dark.text = Loc.t("HINT_LAMP_OUT") + "  %d" % int(ceil(dr))
		_vignette.color = Color(0, 0, 0, clampf(1.0 - dr / 8.0, 0.0, 0.7))
	else:
		_dark.text = ""
		_vignette.color = Color(0, 0, 0, 0)
