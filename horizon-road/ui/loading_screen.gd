class_name LoadingScreen
extends CanvasLayer
## Travel curtain: fades to a paper map card showing the route, distance and
## hours on the road while the next region loads.

const PAPER := Color(0.95, 0.91, 0.82)
const INK := Color(0.24, 0.19, 0.14)

var _fade := ColorRect.new()
var _card := PanelContainer.new()
var _title := Label.new()
var _detail := Label.new()
var _route: Control
var _progress: float = 0.0
var _from_pos := Vector2.ZERO
var _to_pos := Vector2.ZERO


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade.color = Color(0.1, 0.08, 0.06, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.set_corner_radius_all(10)
	st.set_content_margin_all(28)
	_card.add_theme_stylebox_override(&"panel", st)
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	_title.add_theme_font_size_override(&"font_size", 28)
	_title.add_theme_color_override(&"font_color", INK)
	col.add_child(_title)
	_route = Control.new()
	_route.custom_minimum_size = Vector2(640, 220)
	_route.draw.connect(_draw_route)
	col.add_child(_route)
	_detail.add_theme_color_override(&"font_color", Color(0.45, 0.38, 0.3))
	_detail.add_theme_font_size_override(&"font_size", 18)
	col.add_child(_detail)
	_card.add_child(col)
	_card.modulate.a = 0.0
	add_child(_card)


func show_journey(from_id: StringName, to_id: StringName, hours: float, km: int) -> void:
	var a: RegionDefinition = GameState.get_region_def(from_id)
	var b: RegionDefinition = GameState.get_region_def(to_id)
	_title.text = "%s  →  %s" % [tr(StringName(a.name_key)), tr(StringName(b.name_key))]
	_detail.text = tr(&"TRAVEL_DETAIL") % [km, hours]
	_from_pos = a.map_position
	_to_pos = b.map_position
	_progress = 0.0
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.7)
	t.tween_property(_card, "modulate:a", 1.0, 0.4)
	t.tween_method(func(v: float) -> void:
		_progress = v
		_route.queue_redraw(), 0.0, 1.0, 2.2)
	await t.finished


func hide_curtain() -> void:
	var t := create_tween()
	t.tween_property(_card, "modulate:a", 0.0, 0.3)
	t.tween_property(_fade, "color:a", 0.0, 0.9)


## A dotted road between the two places on a tiny map of Türkiye.
func _draw_route() -> void:
	var r := Rect2(Vector2.ZERO, _route.size)
	var lo := Vector2(minf(_from_pos.x, _to_pos.x), minf(_from_pos.y, _to_pos.y))
	var hi := Vector2(maxf(_from_pos.x, _to_pos.x), maxf(_from_pos.y, _to_pos.y))
	var span: Vector2 = (hi - lo).max(Vector2(1, 1))
	var to_screen := func(p: Vector2) -> Vector2:
		return r.position + Vector2(60, 40) + (p - lo) / span * (r.size - Vector2(120, 80))
	var a: Vector2 = to_screen.call(_from_pos)
	var b: Vector2 = to_screen.call(_to_pos)
	var ctrl: Vector2 = (a + b) * 0.5 + Vector2(0, -60)
	var prev: Vector2 = a
	for i: int in range(1, 41):
		var t: float = i / 40.0
		var p: Vector2 = a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
		if i % 2 == 0:
			_route.draw_line(prev, p, Color(0.6, 0.45, 0.3), 3.0)
		prev = p
	_route.draw_circle(a, 8.0, Color(0.3, 0.5, 0.3))
	_route.draw_circle(b, 8.0, Color(0.2, 0.45, 0.7))
	var t2: float = _progress
	var van: Vector2 = a.lerp(ctrl, t2).lerp(ctrl.lerp(b, t2), t2)
	_route.draw_rect(Rect2(van - Vector2(12, 8), Vector2(24, 14)), Color(0.22, 0.52, 0.52))
	_route.draw_rect(Rect2(van - Vector2(12, 8), Vector2(24, 6)), Color(0.95, 0.9, 0.8))
