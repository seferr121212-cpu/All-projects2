class_name Foreground
extends CanvasLayer
## Oyuncunun ÖNÜNDE kayan silüet katmanı + sürüklenen sis. Derinlik hissi verir.

const FRONT := {"c1": "fg/c1_front.png", "c2": "fg/c2_front.png", "c3": "fg/c3_front.png"}

var _front: Sprite2D
var _fog: Sprite2D
var _base_cam := Vector2.INF
var _t := 0.0


func _init() -> void:
	layer = 4


func setup(key: String) -> void:
	_fog = _make("fg/fog_drift.png")
	_fog.modulate = Color(1, 1, 1, 0.55)
	_front = _make(str(FRONT.get(key, FRONT["c1"])))


func _make(path: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex(path)
	s.centered = false
	s.scale = Vector2(2, 2)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, 960, 540)
	add_child(s)
	return s


func _process(delta: float) -> void:
	if _front == null:
		return
	_t += delta
	var ct := get_viewport().get_canvas_transform()
	var cam := ct.affine_inverse() * Vector2.ZERO
	if _base_cam == Vector2.INF:
		_base_cam = cam
	_front.region_rect = Rect2(cam.x * 1.35 / 2.0, 0, 960, 540)
	_front.position.y = clampf(-(cam.y - _base_cam.y) * 0.25, -180.0, 180.0)
	_fog.region_rect = Rect2(cam.x * 0.9 / 2.0 + _t * 9.0, 0, 960, 540)
