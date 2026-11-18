class_name Art
extends RefCounted
## Sprite yardımcıları. Tüm pixel art res://art/ altında (tools/art/*.py ile üretilir).
## Oyun dünyasında 1 sanat pikseli = 2 dünya pikseli (SCALE).

const SCALE := 2.0
const LIGHT_MASK_WORLD := 1
const LIGHT_MASK_PLAYER := 2

static var _cache: Dictionary = {}
static var _ccache: Dictionary = {}
static var _light_tex: Texture2D = null
static var _cone_tex: Texture2D = null
## Normal haritaları açık mı (ayarlardan kapatılabilir)
static var use_normals := true


static func tex(path: String) -> Texture2D:
	var full := "res://art/" + path
	if _cache.has(full):
		return _cache[full]
	var t: Texture2D = null
	if ResourceLoader.exists(full):
		t = load(full)
	_cache[full] = t
	return t


## Varsa normal haritasıyla birlikte (gerçek 2D ışık için) doku.
static func ctex(path: String) -> Texture2D:
	var diffuse := tex(path)
	if diffuse == null or not use_normals:
		return diffuse
	var full := "res://art/" + path
	if _ccache.has(full):
		return _ccache[full]
	var npath := path.substr(0, path.length() - 4) + "_n.png"
	var nt := tex(npath)
	if nt == null:
		_ccache[full] = diffuse
		return diffuse
	var ct := CanvasTexture.new()
	ct.diffuse_texture = diffuse
	ct.normal_texture = nt
	ct.texture_repeat = CanvasItem.TEXTURE_REPEAT_PARENT_NODE
	_ccache[full] = ct
	return ct


## Yumuşak dairesel ışık dokusu.
static func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.35, Color(0.75, 0.75, 0.75, 1))
		g.set_color(g.get_point_count() - 1, Color(0, 0, 0, 1))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		_light_tex = t
	return _light_tex


## Koni (yükseltilmiş lamba) ışık dokusu: sağa bakan.
static func cone_texture() -> Texture2D:
	if _cone_tex == null:
		var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		for y in 256:
			for x in 256:
				var dx := float(x - 128)
				var dy := float(y - 128)
				var d := sqrt(dx * dx + dy * dy) / 128.0
				var v := 0.0
				if dx > 0.0 and d < 1.0:
					var ang := absf(atan2(dy, dx))
					v = (1.0 - d) * clampf(1.0 - (ang - 0.22) / 0.2, 0.0, 1.0)
				img.set_pixel(x, y, Color(v, v, v, 1.0))
		_cone_tex = ImageTexture.create_from_image(img)
	return _cone_tex


## Gerçek 2D ışık (normal haritaları ve gölgelerle çalışır).
static func light(radius: float, color: Color, energy := 1.0, shadows := false) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.texture_scale = radius / 128.0
	l.color = color
	l.energy = energy
	l.height = 60.0
	# 1: dünya, 2: oyuncu. Sabit ışıklar ikisini de aydınlatır; oyuncunun kendi lambası
	# yalnız dünyayı aydınlatır (oyuncuyu ayrı, yumuşak bir "key" ışığı aydınlatır).
	l.range_item_cull_mask = LIGHT_MASK_WORLD | LIGHT_MASK_PLAYER
	l.shadow_enabled = shadows and use_normals
	if l.shadow_enabled:
		l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		l.shadow_filter_smooth = 3.0
		l.shadow_color = Color(0, 0, 0, 0.85)
	return l


## Alt-ortası düğüm konumunda duran sprite.
static func sprite(path: String, flip := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = ctex(path)
	s.centered = false
	s.scale = Vector2(SCALE, SCALE)
	s.flip_h = flip
	if s.texture:
		var sz := s.texture.get_size()
		s.position = Vector2(-sz.x * SCALE / 2.0, -sz.y * SCALE)
	return s


## Ortalanmış sprite.
static func sprite_c(path: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = ctex(path)
	s.scale = Vector2(SCALE, SCALE)
	return s


## rows: { "anim": [satır, kare_sayısı, fps, döngü] }
static func frames(path: String, fw: int, fh: int, rows: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var t := ctex(path)
	for anim in rows.keys():
		var r: Array = rows[anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(r[2]))
		sf.set_animation_loop(anim, bool(r[3]))
		for i in int(r[1]):
			var a := AtlasTexture.new()
			a.atlas = t
			a.region = Rect2(i * fw, int(r[0]) * fh, fw, fh)
			sf.add_frame(anim, a)
	return sf


## Alt-ortası düğümde duran animasyonlu sprite.
static func animated(path: String, fw: int, fh: int, rows: Dictionary, start := "") -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(path, fw, fh, rows)
	s.centered = false
	s.scale = Vector2(SCALE, SCALE)
	s.position = Vector2(-fw * SCALE / 2.0, -fh * SCALE)
	if start != "":
		s.play(start)
	return s


## Döşenen doku ile dikdörtgen (dünya pikseli cinsinden).
static func tiled_rect(path: String, w: float, h: float, tint := Color(1, 1, 1)) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
	p.texture = ctex(path)
	p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	p.texture_scale = Vector2(1.0 / SCALE, 1.0 / SCALE)
	p.color = tint
	return p


static var _sway: Shader = null


static func sway_material(amp := 1.6, hanging := false) -> ShaderMaterial:
	if _sway == null:
		_sway = load("res://shaders/sway.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _sway
	m.set_shader_parameter("amp", amp)
	m.set_shader_parameter("hanging", hanging)
	return m


static func glow_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m
