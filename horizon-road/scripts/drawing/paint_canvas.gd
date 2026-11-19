class_name PaintCanvas
extends Control
## Painting surface: strokes go into a transparent RGBA image layered over a
## paper colour and an optional faint reference. Stamps are pre-rendered
## brush images blended in C++ (blend_rect), so painting stays smooth.

signal changed

const PAPER := Color(0.97, 0.95, 0.9)
const MAX_UNDO: int = 15

@export var canvas_size := Vector2i(960, 540)

var brush_radius: float = 6.0
var brush_color: Color = Color(0.2, 0.3, 0.5)
## 1 = opaque pencil, ~0.25 = watercolour wash.
var brush_opacity: float = 1.0
var brush_softness: float = 0.15
var erasing: bool = false
var strokes: int = 0
var colors_used: Dictionary = {}

var image: Image
var _texture: ImageTexture
var _stroke_view := TextureRect.new()
var _reference_view := TextureRect.new()
var _paper := ColorRect.new()
var _undo: Array[Image] = []
var _painting: bool = false
var _last: Vector2 = Vector2.ZERO
var _stamp_cache: Dictionary = {}
var _dirty: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(canvas_size)
	_paper.color = PAPER
	for c: Control in [_paper, _reference_view, _stroke_view]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
	_reference_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reference_view.stretch_mode = TextureRect.STRETCH_SCALE
	_stroke_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stroke_view.stretch_mode = TextureRect.STRETCH_SCALE
	clear()


func clear() -> void:
	if image:
		_push_undo()
	image = Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_texture = ImageTexture.create_from_image(image)
	_stroke_view.texture = _texture
	strokes = 0
	colors_used.clear()
	changed.emit()


func set_reference(tex: Texture2D, opacity: float) -> void:
	_reference_view.texture = tex
	_reference_view.modulate.a = opacity
	_reference_view.visible = opacity > 0.01 and tex != null


func undo() -> void:
	if _undo.is_empty():
		return
	image = _undo.pop_back()
	_texture.update(image)
	strokes = maxi(strokes - 1, 0)
	changed.emit()


func can_undo() -> bool:
	return not _undo.is_empty()


## Paper + strokes flattened into one RGB image (what gets saved).
func compose() -> Image:
	var out := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	out.fill(PAPER)
	out.blend_rect(image, Rect2i(Vector2i.ZERO, canvas_size), Vector2i.ZERO)
	out.convert(Image.FORMAT_RGB8)
	return out


## Fraction of the paper that has paint on it (sampled).
func coverage() -> float:
	var hits: int = 0
	var total: int = 0
	for y: int in range(0, canvas_size.y, 10):
		for x: int in range(0, canvas_size.x, 10):
			total += 1
			if image.get_pixel(x, y).a > 0.1:
				hits += 1
	return float(hits) / total


# --- Painting --------------------------------------------------------------

func begin_stroke(p: Vector2) -> void:
	_push_undo()
	_painting = true
	_last = p
	strokes += 1
	if not erasing:
		colors_used[brush_color.to_html(false)] = true
	dab(p)


func continue_stroke(p: Vector2) -> void:
	if not _painting:
		return
	# Fill the gap between mouse samples so fast strokes stay continuous.
	var dist: float = _last.distance_to(p)
	var step: float = maxf(brush_radius * 0.35, 1.0)
	var n: int = int(dist / step)
	for i: int in range(1, n + 1):
		dab(_last.lerp(p, float(i) / maxf(n, 1)))
	if n == 0:
		dab(p)
	_last = p


func end_stroke() -> void:
	_painting = false
	changed.emit()


## One brush dab at canvas pixel position p.
func dab(p: Vector2) -> void:
	var r: int = int(ceil(brush_radius))
	var origin := Vector2i(roundi(p.x) - r, roundi(p.y) - r)
	if erasing:
		_erase_circle(Vector2i(roundi(p.x), roundi(p.y)), r)
	else:
		var stamp: Image = _stamp(r)
		image.blend_rect(stamp, Rect2i(Vector2i.ZERO, stamp.get_size()), origin)
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_texture.update(image)
		_dirty = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin_stroke(_to_canvas(event.position))
		else:
			end_stroke()
		accept_event()
	elif event is InputEventMouseMotion and _painting:
		continue_stroke(_to_canvas(event.position))
		accept_event()


func _to_canvas(local: Vector2) -> Vector2:
	return local / size * Vector2(canvas_size)


func _stamp(r: int) -> Image:
	var key: String = "%d|%s|%.2f|%.2f" % [r, brush_color.to_html(), brush_opacity, brush_softness]
	if _stamp_cache.has(key):
		return _stamp_cache[key]
	var d: int = r * 2 + 1
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in d:
		for x: int in d:
			var dist: float = Vector2(x - r, y - r).length() / maxf(brush_radius, 0.5)
			if dist <= 1.0:
				var a: float = 1.0 - smoothstep(1.0 - brush_softness, 1.0, dist)
				var c: Color = brush_color
				c.a = a * brush_opacity
				img.set_pixel(x, y, c)
	if _stamp_cache.size() > 64:
		_stamp_cache.clear()
	_stamp_cache[key] = img
	return img


func _erase_circle(c: Vector2i, r: int) -> void:
	for y: int in range(maxi(c.y - r, 0), mini(c.y + r + 1, canvas_size.y)):
		for x: int in range(maxi(c.x - r, 0), mini(c.x + r + 1, canvas_size.x)):
			if Vector2(x - c.x, y - c.y).length() <= r:
				image.set_pixel(x, y, Color(0, 0, 0, 0))


func _push_undo() -> void:
	_undo.append(image.duplicate())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
