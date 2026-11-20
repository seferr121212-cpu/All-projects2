extends RefCounted
## Shared materials for the stylised low-poly look. Detail textures are
## generated at runtime from FastNoiseLite (own work, no image files, no
## import step): 512 px greyscale, mipmapped, sampled with world triplanar
## mapping and tinted by vertex colour. Everything is cached for the session.

const TEX_SIZE := 512
## material id -> [noise type, frequency, octaves, stretch (rows), contrast, world scale]
const SURFACES := {
	"concrete": [FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.018, 5, 0, 0.55, 0.35],
	"metal": [FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.03, 3, 24, 0.35, 0.6],
	"paint": [FastNoiseLite.TYPE_CELLULAR, 0.02, 2, 0, 0.18, 0.5],
	"wood": [FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, 3, 10, 0.5, 0.9],
	"fabric": [FastNoiseLite.TYPE_VALUE, 0.25, 2, 0, 0.3, 1.6],
	"plaster": [FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 4, 0, 0.22, 0.25],
}
const MATERIAL_IDS := ["concrete", "metal", "paint", "wood", "fabric", "plaster", "plain", "glow", "skin"]

static var _textures: Dictionary = {}
static var _materials: Dictionary = {}
static var _sprite: Texture2D


static func detail_texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var s: Array = SURFACES[id]
	var noise := FastNoiseLite.new()
	noise.noise_type = int(s[0])
	noise.frequency = float(s[1])
	noise.fractal_octaves = int(s[2])
	noise.seed = id.hash() & 0xffff
	var rows := int(s[3])
	var img: Image
	if rows > 0:
		# Streaks (brushed metal, wood grain): a thin strip stretched vertically.
		img = noise.get_seamless_image(TEX_SIZE, rows)
		img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_BILINEAR)
	else:
		img = noise.get_seamless_image(TEX_SIZE, TEX_SIZE)
	img.convert(Image.FORMAT_RGB8)
	# Map noise [0..1] to a narrow band near white so it only modulates the tint.
	# Mean ~0.88, half-amplitude 0.3 * strength: contrast around 0.5, then scale.
	var brightness := 0.88 / 0.5
	var amplitude := float(s[4]) * 0.3
	img.adjust_bcs(1.0, 2.0 * amplitude / brightness, 1.0)
	img.adjust_bcs(brightness, 1.0, 1.0)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[id] = tex
	return tex


## Vertex-coloured material. "glow" is unshaded (emissive look without a
## glow pass), "plain"/"skin" have no texture.
static func material(id: String) -> Material:
	if _materials.has(id):
		return _materials[id]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.metallic_specular = 0.2
	if id == "glow":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elif id == "metal":
		m.metallic_specular = 0.45
		m.roughness = 0.6
	if SURFACES.has(id):
		m.albedo_texture = detail_texture(id)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		var sc := float(SURFACES[id][5])
		m.uv1_scale = Vector3(sc, sc, sc)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_materials[id] = m
	return m


## Soft round sprite for halos, particles and light shafts (generated, cached).
static func soft_sprite() -> Texture2D:
	if _sprite == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_sprite = t
	return _sprite


## Additive, unshaded, vertex-coloured, depth-tested but not depth-written.
static func additive_material(billboard: bool) -> StandardMaterial3D:
	var key := "add_b" if billboard else "add"
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_sprite() if billboard else null
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
	_materials[key] = m
	return m


## Alpha-blended billboard (smoke, mist).
static func smoke_material() -> StandardMaterial3D:
	if _materials.has("smoke"):
		return _materials["smoke"]
	var m := additive_material(true).duplicate() as StandardMaterial3D
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_materials["smoke"] = m
	return m


static func clear_cache() -> void:
	_textures.clear()
	_materials.clear()
	_sprite = null
