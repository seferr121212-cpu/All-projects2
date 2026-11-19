extends Control
## Draws the chapter decision flowchart built by DecisionManager.build_flowchart:
## one row per layer, a header box per decision point with its options
## underneath, and edges from each option to the points it leads to.
## Taken path = accent; seen but not taken = dim text; never reached = "?".

const UiTheme = preload("res://ui/ui_theme.gd")
const HEADER := Vector2(300, 54)
const OPTION := Vector2(200, 46)
const OPTION_GAP := 14.0
const BLOCK_GAP := 60.0
const ROW_H := 210.0
const MARGIN := 40.0
const FONT_SIZE := 18

var _graph: Dictionary = {}
var _rects: Dictionary = {}  # point id -> {"header": Rect2, "options": [Rect2]}
var _font: Font


func set_graph(graph: Dictionary) -> void:
	_graph = graph
	_font = get_theme_default_font()
	_layout()
	queue_redraw()


func _block_width(p: Dictionary) -> float:
	var n: int = (p["options"] as Array).size()
	if p["kind"] in ["start", "end"]:
		return HEADER.x
	return maxf(HEADER.x, n * OPTION.x + (n - 1) * OPTION_GAP)


func _layout() -> void:
	_rects.clear()
	var rows: Dictionary = {}
	for p: Dictionary in _graph.get("points", []):
		var l := int(p["layer"])
		if not rows.has(l):
			rows[l] = []
		rows[l].append(p)
	var width := 0.0
	for l: int in rows:
		var w := 0.0
		for p: Dictionary in rows[l]:
			w += _block_width(p) + BLOCK_GAP
		width = maxf(width, w)
	width = maxf(width + MARGIN * 2.0, 1400.0)
	for l: int in rows:
		var row: Array = rows[l]
		var total := 0.0
		for p: Dictionary in row:
			total += _block_width(p)
		total += BLOCK_GAP * (row.size() - 1)
		var x := (width - total) / 2.0
		var y := MARGIN + l * ROW_H
		for p: Dictionary in row:
			var bw := _block_width(p)
			var header := Rect2(Vector2(x + (bw - HEADER.x) / 2.0, y), HEADER)
			var opts: Array = []
			if not p["kind"] in ["start", "end"]:
				var n: int = (p["options"] as Array).size()
				var ow := n * OPTION.x + (n - 1) * OPTION_GAP
				var ox := x + (bw - ow) / 2.0
				for i in n:
					opts.append(Rect2(Vector2(ox + i * (OPTION.x + OPTION_GAP), y + HEADER.y + 34), OPTION))
			_rects[p["id"]] = {"header": header, "options": opts}
			x += bw + BLOCK_GAP
	custom_minimum_size = Vector2(width, MARGIN * 2.0 + int(_graph.get("layers", 1)) * ROW_H)


func _fit(text: String, width: float) -> String:
	if _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x <= width:
		return text
	var t := text
	while t.length() > 1 and _font.get_string_size(t + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x > width:
		t = t.substr(0, t.length() - 1)
	return t + "..."


func _text(rect: Rect2, text: String, color: Color) -> void:
	var baseline := rect.position.y + rect.size.y / 2.0 + FONT_SIZE * 0.35
	draw_string(_font, Vector2(rect.position.x + 8, baseline), _fit(text, rect.size.x - 16),
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16, FONT_SIZE, color)


func _edge(from: Vector2, to: Vector2, color: Color, w: float) -> void:
	var pts := PackedVector2Array()
	var c1 := from + Vector2(0, (to.y - from.y) * 0.5)
	var c2 := to - Vector2(0, (to.y - from.y) * 0.5)
	for i in 17:
		var t := i / 16.0
		var a := from.lerp(c1, t)
		var b := c1.lerp(c2, t)
		var c := c2.lerp(to, t)
		pts.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	draw_polyline(pts, color, w, true)


func _draw() -> void:
	if _graph.is_empty():
		return
	var dim := Color(1, 1, 1, 0.18)
	var points: Dictionary = {}
	for p: Dictionary in _graph["points"]:
		points[p["id"]] = p
	# Edges first.
	for p: Dictionary in _graph["points"]:
		var r: Dictionary = _rects[p["id"]]
		var opts: Array = p["options"]
		for i in opts.size():
			var o: Dictionary = opts[i]
			var from: Vector2
			if p["kind"] == "start":
				from = (r["header"] as Rect2).get_center() + Vector2(0, HEADER.y / 2.0)
			else:
				var orect: Rect2 = r["options"][i]
				from = orect.position + Vector2(orect.size.x / 2.0, orect.size.y)
			for t: String in o["targets"]:
				if not _rects.has(t):
					continue
				var hr: Rect2 = _rects[t]["header"]
				var taken: bool = o["chosen"] and p["visited"] and points[t]["visited"]
				_edge(from, hr.position + Vector2(hr.size.x / 2.0, 0), UiTheme.ACCENT if taken else dim, 3.0 if taken else 1.5)
	# Boxes.
	for p: Dictionary in _graph["points"]:
		var r: Dictionary = _rects[p["id"]]
		var header: Rect2 = r["header"]
		var visited: bool = p["visited"]
		var head_col := Color(0.16, 0.17, 0.19) if visited else Color(0.1, 0.1, 0.11)
		draw_rect(header, head_col)
		if p.get("major", false) and visited:
			draw_rect(header, UiTheme.ACCENT, false, 2.0)
		var label: String
		match str(p["kind"]):
			"start":
				label = Localization.t(str(p["label"]))
			"end":
				label = Localization.t("flow.end")
			"qte":
				label = Localization.t("flow.qte") + ": " + Localization.t(str(p["label"])) if visited else "?"
			_:
				label = Localization.t(str(p["label"])) if visited and str(p["label"]) != "" else ("..." if visited else "?")
		_text(header, label, UiTheme.TEXT if visited else UiTheme.TEXT_DIM)
		var opts: Array = p["options"]
		for i in (r["options"] as Array).size():
			var o: Dictionary = opts[i]
			var orect: Rect2 = r["options"][i]
			if o["chosen"]:
				draw_rect(orect, UiTheme.ACCENT.darkened(0.35))
				draw_rect(orect, UiTheme.ACCENT, false, 2.0)
				_text(orect, Localization.t(str(o["text"])), Color.WHITE)
			elif visited:
				draw_rect(orect, Color(0.12, 0.12, 0.13))
				_text(orect, Localization.t(str(o["text"])), UiTheme.TEXT_DIM)
			else:
				draw_rect(orect, Color(0.08, 0.08, 0.09))
				draw_rect(orect, dim, false, 1.0)
				_text(orect, "?", UiTheme.TEXT_DIM)


## Share of decision outcomes that were taken (0..100).
static func explored_percent(graph: Dictionary) -> int:
	var total := 0
	var taken := 0
	for p: Dictionary in graph.get("points", []):
		if p["kind"] in ["choice", "qte"]:
			for o: Dictionary in p["options"]:
				total += 1
				if o["chosen"]:
					taken += 1
	return int(round(100.0 * taken / total)) if total > 0 else 0
