extends RefCounted
## Code-built theme (no external font: Godot's built-in default font, which
## covers Turkish glyphs). Large sizes for 1080p TV distance; strong focus
## ring so gamepad navigation is always visible.

const ACCENT := Color(0.96, 0.66, 0.22)
const TEXT := Color(0.93, 0.92, 0.89)
const TEXT_DIM := Color(0.62, 0.62, 0.60)
const PANEL_BG := Color(0.08, 0.09, 0.10, 0.92)
const BUTTON_BG := Color(0.15, 0.16, 0.18, 0.95)
const BUTTON_HOVER := Color(0.22, 0.23, 0.26, 0.95)
const BG := Color(0.06, 0.07, 0.08)

const NARRATOR_COLOR := Color(0.70, 0.70, 0.68)
const LocationBuilder = preload("res://scenes/world/location_builder.gd")

const FONT_BODY := 30
const FONT_SMALL := 22
const FONT_TITLE := 96
const FONT_HEADING := 44


static func _box(color: Color, border: Color = Color.TRANSPARENT, border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(4)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY
	t.set_stylebox("normal", "Button", _box(BUTTON_BG))
	t.set_stylebox("hover", "Button", _box(BUTTON_HOVER))
	t.set_stylebox("pressed", "Button", _box(BUTTON_HOVER, ACCENT, 2))
	t.set_stylebox("disabled", "Button", _box(Color(0.1, 0.1, 0.11, 0.6)))
	var focus := _box(Color.TRANSPARENT, ACCENT, 4)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.4))
	t.set_constant("h_separation", "Button", 12)
	t.set_color("font_color", "Label", TEXT)
	var panel := _box(PANEL_BG)
	panel.content_margin_left = 48
	panel.content_margin_right = 48
	panel.content_margin_top = 36
	panel.content_margin_bottom = 36
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_constant("separation", "VBoxContainer", 14)
	t.set_constant("separation", "HBoxContainer", 14)
	return t


## Speaker name colour from data/characters.json.
static func speaker_color(speaker: String) -> Color:
	var info: Dictionary = LocationBuilder.characters().get(speaker, {})
	return LocationBuilder.color(info["color"]) if info.has("color") else NARRATOR_COLOR


static func make_button(text_key: String, min_width: float = 520.0) -> Button:
	var b := Button.new()
	b.text = text_key
	b.custom_minimum_size = Vector2(min_width, 64)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	return b


static func make_label(text_key: String, size: int = FONT_BODY, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text_key
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Wire vertical focus neighbours (wrapping) for a list of controls.
static func chain_focus(controls: Array) -> void:
	var list: Array = controls.filter(func(c: Control) -> bool: return c.visible and c.focus_mode != Control.FOCUS_NONE)
	var n := list.size()
	for i in n:
		var c: Control = list[i]
		c.focus_neighbor_top = c.get_path_to(list[(i - 1 + n) % n])
		c.focus_neighbor_bottom = c.get_path_to(list[(i + 1) % n])
		c.focus_previous = c.focus_neighbor_top
		c.focus_next = c.focus_neighbor_bottom


static func full_rect(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
