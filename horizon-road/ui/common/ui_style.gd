class_name UIStyle
extends RefCounted
## Shared "travel notebook" look for menus: paper panels, ink text, warm buttons.

const PAPER := Color(0.96, 0.93, 0.86, 0.97)
const INK := Color(0.24, 0.19, 0.14)
const INK_SOFT := Color(0.47, 0.4, 0.32)
const ACCENT := Color(0.78, 0.45, 0.2)
const BUTTON := Color(0.9, 0.85, 0.75)
const BUTTON_HOVER := Color(0.96, 0.8, 0.55)


static func panel(p: PanelContainer, margin: int = 26) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.set_corner_radius_all(10)
	st.set_content_margin_all(margin)
	st.border_color = Color(0.55, 0.38, 0.22)
	st.set_border_width_all(3)
	st.shadow_color = Color(0, 0, 0, 0.4)
	st.shadow_size = 14
	p.add_theme_stylebox_override(&"panel", st)


static func button(b: Button, font_size: int = 19) -> Button:
	var normal := StyleBoxFlat.new()
	normal.bg_color = BUTTON
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(10)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = BUTTON_HOVER
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.88, 0.85, 0.8)
	b.add_theme_stylebox_override(&"normal", normal)
	b.add_theme_stylebox_override(&"hover", hover)
	b.add_theme_stylebox_override(&"pressed", hover)
	b.add_theme_stylebox_override(&"focus", hover)
	b.add_theme_stylebox_override(&"disabled", disabled)
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		b.add_theme_color_override(c, INK)
	b.add_theme_color_override(&"font_disabled_color", INK_SOFT)
	b.add_theme_font_size_override(&"font_size", font_size)
	return b


static func label(text: String, font_size: int = 18, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	return l


static func make_button(text: String, action: Callable, font_size: int = 19) -> Button:
	var b := Button.new()
	b.text = text
	button(b, font_size)
	b.pressed.connect(action)
	return b


static func tabs(t: TabContainer) -> void:
	for spec: Array in [[&"tab_selected", Color(0.99, 0.97, 0.92), ACCENT], [&"tab_unselected", Color(0.88, 0.83, 0.73), Color(0, 0, 0, 0)], [&"tab_hovered", Color(0.93, 0.89, 0.8), Color(0, 0, 0, 0)]]:
		var st := StyleBoxFlat.new()
		st.bg_color = spec[1]
		st.corner_radius_top_left = 6
		st.corner_radius_top_right = 6
		st.set_content_margin_all(10)
		st.content_margin_left = 18
		st.content_margin_right = 18
		st.border_color = spec[2]
		st.border_width_bottom = 3
		t.add_theme_stylebox_override(spec[0], st)
	t.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	t.add_theme_color_override(&"font_selected_color", ACCENT)
	t.add_theme_color_override(&"font_unselected_color", INK_SOFT)
	t.add_theme_color_override(&"font_hovered_color", INK)


## Paper look for option buttons and their popup list.
static func option(o: OptionButton) -> void:
	button(o, 17)
	var popup: PopupMenu = o.get_popup()
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.set_content_margin_all(8)
	st.border_color = Color(0.55, 0.38, 0.22)
	st.set_border_width_all(2)
	popup.add_theme_stylebox_override(&"panel", st)
	popup.add_theme_color_override(&"font_color", INK)
	popup.add_theme_color_override(&"font_hover_color", ACCENT)
