class_name UIKit
extends RefCounted
## Menüler için ortak stil yardımcıları.

static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 36)
	b.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.75, 0.45))
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.75, 0.45))
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.45))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# odak: ince kutu yerine soldan sağa sönen sıcak bir ışık şeridi
	b.flat = false
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 18
	empty.content_margin_right = 18
	empty.content_margin_top = 2
	empty.content_margin_bottom = 2
	for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, empty)
	b.add_theme_stylebox_override("focus", _focus_box())
	b.pressed.connect(cb)
	b.pressed.connect(func(): AudioManager.ui_sfx("click", -12.0, 0.9))
	b.focus_entered.connect(func(): AudioManager.ui_sfx("click", -24.0, 1.7))
	b.mouse_entered.connect(func(): b.grab_focus())
	return b


static func label(text: String, size := 30, color := Color(0.85, 0.87, 0.9)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func dim_bg(alpha := 0.75) -> ColorRect:
	var c := ColorRect.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.color = Color(0.01, 0.012, 0.02, alpha)
	return c


static func slider(value: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(360, 32)
	s.value_changed.connect(cb)
	return s


## Opak, kenarlıklı menü çerçevesi. Arkadaki her şeyi karartır, içerik kutusunu döndürür.
## scroll=true ise içerik kaydırılabilir (uzun listeler için).
static func frame(parent: Control, title: String, size: Vector2, scroll := false, back_alpha := 0.94) -> VBoxContainer:
	# Ekran 1920x1080 tabanlı (stretch: canvas_items). Ebeveynin boyutuna güvenmeden sabit konum.
	var screen := Vector2(1920, 1080)
	var back := ColorRect.new()
	back.position = Vector2.ZERO
	back.size = screen
	back.color = Color(0.01, 0.012, 0.02, back_alpha)
	parent.add_child(back)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.size = size
	panel.position = (screen - size) / 2.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.06, 0.08, 1.0)
	sb.border_color = Color(0.62, 0.45, 0.26)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 24
	sb.content_margin_left = 56
	sb.content_margin_right = 56
	sb.content_margin_top = 36
	sb.content_margin_bottom = 36
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	panel.add_child(outer)
	var t := label(title, 50, Color(1.0, 0.75, 0.45))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(t)
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(0.62, 0.45, 0.26, 0.6)
	outer.add_child(sep)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if scroll:
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		outer.add_child(sc)
		sc.add_child(box)
	else:
		outer.add_child(box)
	return box


static var _focus_sb: StyleBoxTexture = null


static func _focus_box() -> StyleBoxTexture:
	if _focus_sb == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.72, 0.4, 0.85))
		g.add_point(0.007, Color(1.0, 0.72, 0.4, 0.85))
		g.add_point(0.008, Color(1.0, 0.72, 0.4, 0.16))
		g.set_color(g.get_point_count() - 1, Color(1.0, 0.72, 0.4, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 512
		t.height = 4
		var sb := StyleBoxTexture.new()
		sb.texture = t
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		_focus_sb = sb
	return _focus_sb
