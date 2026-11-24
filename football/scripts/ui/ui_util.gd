class_name UIUtil
extends RefCounted
## Menü kurulum yardımcıları (kodla UI; tema UITheme'den gelir).


static func full_rect(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)


static func background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	full_rect(bg)
	parent.add_child(bg)
	# Saha çizgisi motifi: orta çizgi ve orta yuvarlak (ince, soluk)
	var deco := Control.new()
	full_rect(deco)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(func() -> void:
		var s := deco.size
		var c := Color(UITheme.ACCENT, 0.12)
		deco.draw_line(Vector2(s.x * 0.5, 0), Vector2(s.x * 0.5, s.y), c, 2.0)
		deco.draw_arc(s * 0.5, minf(s.x, s.y) * 0.22, 0, TAU, 96, c, 2.0))
	parent.add_child(deco)


static func title(text: String, size := 56) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, cb: Callable, min_w := 320) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 52)
	b.pressed.connect(cb)
	return b


static func centered_column(parent: Control, sep := 14) -> VBoxContainer:
	var center := CenterContainer.new()
	full_rect(center)
	parent.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	center.add_child(v)
	return v


static func row(label_text: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(260, 0)
	l.add_theme_color_override("font_color", UITheme.MUTED)
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 320)
	h.add_child(control)
	return h


static func option(items: Array, selected := 0) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(clampi(selected, 0, maxi(items.size() - 1, 0)))
	return o
