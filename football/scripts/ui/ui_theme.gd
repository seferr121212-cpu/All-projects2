class_name UITheme
extends RefCounted
## Sade koyu tema (yerleşik bileşenler, tek yerden). Sonradan .tres ile değiştirilebilir.

const BG := Color("#0f1511")
const PANEL := Color("#18211b")
const PANEL_HI := Color("#223026")
const ACCENT := Color("#3fa34d")
const TEXT := Color("#e8efe9")
const MUTED := Color("#93a598")


static func _box(color: Color, radius := 6, border := Color.TRANSPARENT, border_w := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	for cls in ["Label", "Button", "OptionButton", "CheckBox", "CheckButton", "TabContainer", "SpinBox", "LineEdit"]:
		t.set_color("font_color", cls, TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, _box(PANEL_HI))
		t.set_stylebox("hover", cls, _box(PANEL_HI.lightened(0.12)))
		t.set_stylebox("pressed", cls, _box(ACCENT.darkened(0.2)))
		t.set_stylebox("focus", cls, _box(Color.TRANSPARENT, 6, ACCENT, 2))
		t.set_stylebox("disabled", cls, _box(PANEL))
	# Onay kutusu: düğme arka planı yok, yalnızca odak çerçevesi
	for cls in ["CheckBox", "CheckButton"]:
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(st, cls, StyleBoxEmpty.new())
		t.set_stylebox("focus", cls, _box(Color.TRANSPARENT, 6, ACCENT, 2))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 10))
	t.set_stylebox("panel", "Panel", _box(PANEL, 10))
	t.set_stylebox("panel", "TabContainer", _box(PANEL, 8))
	t.set_stylebox("tab_selected", "TabContainer", _box(ACCENT.darkened(0.25), 6))
	t.set_stylebox("tab_unselected", "TabContainer", _box(PANEL_HI, 6))
	t.set_stylebox("tab_hovered", "TabContainer", _box(PANEL_HI.lightened(0.1), 6))
	t.set_stylebox("slider", "HSlider", _box(PANEL_HI, 3))
	t.set_stylebox("grabber_area", "HSlider", _box(ACCENT, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(ACCENT.lightened(0.2), 3))
	t.set_color("font_color", "TooltipLabel", TEXT)
	return t
