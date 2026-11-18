class_name DarknessOverlay
extends CanvasLayer
## Ekranı karartan ve sis çizen katman. Işık verisini LightSystem'dan alır.

var rect: ColorRect
var mat: ShaderMaterial
var flash := 0.0
var extra_dark := 0.0
var _level
var _glows: Array = []


func _init() -> void:
	layer = 5


func setup(level) -> void:
	_level = level
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/darkness.gdshader")
	rect.material = mat
	add_child(rect)
	mat.set_shader_parameter("darkness", level.dark_value)
	mat.set_shader_parameter("fog_amount", level.fog_amount)


func _process(delta: float) -> void:
	if mat == null:
		return
	var vp := get_viewport()
	var ct := vp.get_canvas_transform()
	var sc := ct.get_scale().x
	var size := vp.get_visible_rect().size
	mat.set_shader_parameter("screen_size", size)
	mat.set_shader_parameter("cam_offset", -ct.origin)
	var arr := PackedVector4Array()
	for c in LightSystem.gather_circles():
		if arr.size() >= 32:
			break
		var v: Vector4 = c
		var sp := ct * Vector2(v.x, v.y)
		var rr := v.z * sc
		if sp.x < -rr or sp.y < -rr or sp.x > size.x + rr or sp.y > size.y + rr:
			continue
		arr.append(Vector4(sp.x, sp.y, v.z * sc, v.w))
	var n := arr.size()
	while arr.size() < 32:
		arr.append(Vector4.ZERO)
	_update_glows(ct)
	mat.set_shader_parameter("lights", arr)
	mat.set_shader_parameter("light_count", n)
	# koni + huzme
	var lamp = LightSystem.lamp
	var beams := PackedVector4Array()
	var cone := Vector4.ZERO
	var red := 0.0
	if lamp and is_instance_valid(lamp) and lamp.is_light_on():
		red = 1.0 if lamp.red else 0.0
		if lamp.mode == Lamp.Mode.RAISED:
			var o: Vector2 = ct * lamp.global_position
			cone = Vector4(o.x, o.y, Lamp.CONE_LEN * sc, Lamp.CONE_HALF)
			mat.set_shader_parameter("cone_dir", lamp.aim.normalized())
			var pts: PackedVector2Array = lamp.beam_points
			for i in range(pts.size() - 1):
				if beams.size() >= 8:
					break
				var a := ct * pts[i]
				var b := ct * pts[i + 1]
				beams.append(Vector4(a.x, a.y, b.x, b.y))
	var bn := beams.size()
	while beams.size() < 8:
		beams.append(Vector4.ZERO)
	mat.set_shader_parameter("beams", beams)
	mat.set_shader_parameter("beam_count", bn)
	mat.set_shader_parameter("cone", cone)
	mat.set_shader_parameter("red_mode", red)
	flash = move_toward(flash, 0.0, delta * 0.8)
	mat.set_shader_parameter("flash", flash)
	if _level:
		mat.set_shader_parameter("darkness", clampf(_level.dark_value + extra_dark, 0.0, 1.0))


## Işıkların üstüne eklenen sıcak parıltı (additive, karanlığın üstünde çizilir).
func _update_glows(_ct: Transform2D) -> void:
	if _level == null or _level.glow_layer == null:
		return
	var circles := LightSystem.gather_circles()
	var n := 0
	for c in circles:
		var v: Vector4 = c
		if v.w < 0.2:
			continue
		if n >= _glows.size():
			var s := Sprite2D.new()
			s.texture = Art.tex("fx/glow.png")
			s.material = Art.glow_material()
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			_level.glow_layer.add_child(s)
			_glows.append(s)
		var g: Sprite2D = _glows[n]
		g.visible = true
		g.global_position = Vector2(v.x, v.y)
		var sc := v.z / 64.0 * 0.9
		g.scale = Vector2(sc, sc)
		var lamp = LightSystem.lamp
		var red: bool = lamp != null and is_instance_valid(lamp) and bool(lamp.red)
		var col := Color(1.0, 0.25, 0.18) if red else Color(1.0, 0.62, 0.3)
		g.modulate = Color(col.r, col.g, col.b, 0.22 * v.w)
		n += 1
	for i in range(n, _glows.size()):
		(_glows[i] as Sprite2D).visible = false
