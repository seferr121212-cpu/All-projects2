class_name PhotoOverlay
extends Control
## Viewfinder drawing: frame corners, thirds grid, focus reticle and a
## settings bar. Hidden during capture so it never ends up in the photo.

var _mode: PhotoMode
var _font: Font


func _init(mode: PhotoMode) -> void:
	_mode = mode
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = get_theme_default_font()


func _draw() -> void:
	var s: Vector2 = size
	var line := Color(1, 1, 1, 0.75)
	var faint := Color(1, 1, 1, 0.35)
	var m: float = 40.0
	var c: float = 60.0
	for corner: Vector2 in [Vector2(m, m), Vector2(s.x - m, m), Vector2(m, s.y - m), Vector2(s.x - m, s.y - m)]:
		var dx: float = c if corner.x < s.x * 0.5 else -c
		var dy: float = c if corner.y < s.y * 0.5 else -c
		draw_line(corner, corner + Vector2(dx, 0), line, 2.0)
		draw_line(corner, corner + Vector2(0, dy), line, 2.0)
	if _mode.show_grid:
		for i: int in [1, 2]:
			draw_line(Vector2(s.x * i / 3.0, 0), Vector2(s.x * i / 3.0, s.y), faint, 2.0, true)
			draw_line(Vector2(0, s.y * i / 3.0), Vector2(s.x, s.y * i / 3.0), faint, 2.0, true)
	var mid: Vector2 = s * 0.5
	draw_arc(mid, 18.0, 0.0, TAU, 32, line, 1.5)
	draw_line(mid - Vector2(6, 0), mid + Vector2(6, 0), line, 1.0)
	draw_line(mid - Vector2(0, 6), mid + Vector2(0, 6), line, 1.0)

	var cfg: PhotoConfig = _mode.config
	var items: Array[String] = [
		"%s  f/%.1f" % [tr(&"PHOTO_APERTURE"), cfg.apertures[_mode.aperture_index]],
		"%s  %+.1f EV" % [tr(&"PHOTO_EXPOSURE"), _mode.exposure_ev],
		"%s  %dmm" % [tr(&"PHOTO_ZOOM"), roundi(_fov_to_mm(_mode.fov))],
		"%s  %s" % [tr(&"PHOTO_FOCUS"), "%.0fm" % _mode.focus_distance if _mode.focus_distance < 999.0 else "∞"],
		"%s  %s" % [tr(&"PHOTO_FILTER"), tr(StringName(PhotoMode.FILTER_KEYS[_mode.filter_index]))],
	]
	var bar_y: float = s.y - m - 34.0
	var text: String = "    ·    ".join(items)
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_rect(Rect2(mid.x - width * 0.5 - 16, bar_y - 22, width + 32, 32), Color(0, 0, 0, 0.35))
	draw_string(_font, Vector2(mid.x - width * 0.5, bar_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.95))
	var help: String = tr(&"PHOTO_HELP")
	var hw: float = _font.get_string_size(help, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(_font, Vector2(mid.x - hw * 0.5, m + 24), help, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))


## Vertical FOV to a full-frame-equivalent focal length, for a familiar readout.
func _fov_to_mm(fov_deg: float) -> float:
	return 12.0 / tan(deg_to_rad(fov_deg) * 0.5)
