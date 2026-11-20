extends RefCounted
## Builds a location from data/locations/<id>.json (stage 6 art pass):
## - collision stays the authored boxes (floor, perimeter walls, props);
## - visuals are stylised low-poly props (PropKit) merged into one mesh per
##   material, triplanar runtime-noise textures (ArtKit) and baked fake AO /
##   contact shadows in vertex colours;
## - atmosphere: sky or flat background, fog, one shadowed sun, unshadowed
##   omni lights with optional halo / light shaft / flicker, CPU particles
##   and a vignette (the last three only on "high" visual quality);
## - "variants" override atmosphere keys when their condition holds
##   (epilogue lighting, time of day).

const LOCATION_DIR := "res://data/locations/"
const CHARACTERS_PATH := "res://data/characters.json"
const MeshBatch = preload("res://scenes/world/mesh_batch.gd")
const ArtKit = preload("res://scenes/world/art_kit.gd")
const PropKit = preload("res://scenes/world/prop_kit.gd")
const CharacterBody = preload("res://scenes/world/character_body.gd")
const Ambience = preload("res://scenes/world/ambience.gd")
const WALL_STYLES := ["plain", "factory", "home", "fence"]
const PARTICLE_TYPES := ["dust", "smoke", "embers", "mist", "steam"]
const VARIANT_KEYS := ["background", "sky", "ambient", "ambient_energy", "fog", "fog_density", "sun", "lights",
	"particles", "vignette", "floor_color", "wall_color", "window_color", "ambience"]
const WALL_T := 0.2

static var _characters: Dictionary = {}


static func load_data(location_id: String) -> Dictionary:
	var path := LOCATION_DIR + location_id + ".json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("LocationBuilder: missing %s" % path)
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	return data if typeof(data) == TYPE_DICTIONARY else {}


static func characters() -> Dictionary:
	if _characters.is_empty():
		var f := FileAccess.open(CHARACTERS_PATH, FileAccess.READ)
		if f != null:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if typeof(data) == TYPE_DICTIONARY:
				for group in ["playable", "npc"]:
					for id: String in data.get(group, {}):
						_characters[id] = data[group][id]
	return _characters


static func vec3(a: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if typeof(a) == TYPE_ARRAY and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


static func color(c: Variant, fallback: Color = Color(0.5, 0.5, 0.5)) -> Color:
	if typeof(c) == TYPE_STRING:
		return Color.html(str(c))
	if typeof(c) == TYPE_ARRAY:
		return Color(float(c[0]), float(c[1]), float(c[2]))
	return fallback


static func quality_high() -> bool:
	return str(SaveSystem.settings.get("visual_quality", "high")) == "high"


static func _active(entry: Dictionary) -> bool:
	return not entry.has("if") or DecisionManager.evaluate(entry["if"])


## Data with every matching variant's "set" applied (later variants win).
static func resolve_variants(data: Dictionary) -> Dictionary:
	var out := data.duplicate()
	for v: Dictionary in data.get("variants", []):
		if _active(v):
			var s: Dictionary = v.get("set", {})
			for k: String in s:
				out[k] = s[k]
	return out


static func collider(parent: Node3D, pos: Vector3, size: Vector3, rot_deg: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	body.position = pos
	body.rotation_degrees.y = rot_deg
	parent.add_child(body)
	return body


## Stylised low-poly character with idle / walk / talk animation.
static func make_body(character_id: String) -> Node3D:
	var body := CharacterBody.new()
	body.setup(character_id, characters().get(character_id, {}))
	return body


## Builds everything into `world` and returns lookup tables:
## {"spawns": {id: Transform3D}, "actors": {id: Node3D}, "points": {id: {pos, radius}}, "camera": {...},
##  "stats": {"meshes", "vertices", "lights", "particles"}}
static func build(world: Node3D, raw: Dictionary) -> Dictionary:
	var data := resolve_variants(raw)
	var high := quality_high()
	var result := {"spawns": {}, "actors": {}, "points": {}, "camera": data.get("camera", {}),
		"ambience": str(data.get("ambience", "")),
		"stats": {"meshes": 0, "vertices": 0, "lights": 0, "particles": 0}}
	var batches := {}
	var ambience := Ambience.new()
	ambience.name = "Ambience"
	var size := vec3(data.get("size"), Vector3(12, 4, 10))

	# Collision shell.
	collider(world, Vector3(0, -WALL_T / 2.0, 0), Vector3(size.x, WALL_T, size.z))
	var walls := [
		[Vector3(0, size.y / 2.0, -size.z / 2.0), Vector3(size.x, size.y, WALL_T), Vector3(0, 0, 1)],
		[Vector3(0, size.y / 2.0, size.z / 2.0), Vector3(size.x, size.y, WALL_T), Vector3(0, 0, -1)],
		[Vector3(-size.x / 2.0, size.y / 2.0, 0), Vector3(WALL_T, size.y, size.z), Vector3(1, 0, 0)],
		[Vector3(size.x / 2.0, size.y / 2.0, 0), Vector3(WALL_T, size.y, size.z), Vector3(-1, 0, 0)],
	]
	for w: Array in walls:
		collider(world, w[0], w[1])

	# Props: collision as authored, visuals from the kit.
	var occluders: Array = []
	var index := 0
	for b: Dictionary in data.get("boxes", []):
		index += 1
		if not _active(b):
			continue
		var pos := vec3(b.get("pos"))
		var bsize := vec3(b.get("size"), Vector3.ONE)
		var rot := float(b.get("rot", 0.0))
		var col := color(b.get("color", "#555555"))
		var emissive := bool(b.get("emissive", false))
		if bool(b.get("collide", true)):
			collider(world, pos, bsize, rot)
		if pos.y - bsize.y / 2.0 < 0.3 and bsize.y > 0.3:
			var ext := Vector2(bsize.x, bsize.z) if int(round(rot)) % 180 != 90 else Vector2(bsize.z, bsize.x)
			occluders.append(Rect2(Vector2(pos.x, pos.z) - ext / 2.0, ext))
		var kind := str(b.get("kind", "panel" if emissive else "block"))
		var mat := str(b.get("mat", "glow" if emissive and kind == "block" else PropKit.KINDS.get(kind, "paint")))
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(rot)), pos)
		if kind == "fire":
			_add_fire(world, ambience, xf, bsize, col, high, result)
			continue
		PropKit.build(kind, batches, xf, bsize, col, mat, index)

	# Floor with contact shadows, then walls in the location's style.
	var floor_batch := MeshBatch.new()
	floor_batch.add_floor(size.x, size.z, 0.5, color(data.get("floor_color", "#2a2e33")), occluders)
	batches["floor"] = floor_batch
	_build_walls(batches, walls, size, data)

	for id: String in batches:
		var bt: MeshBatch = batches[id]
		if bt.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Batch_" + id
		mi.mesh = bt.commit()
		var mat_id := str(data.get("floor_mat", "concrete")) if id == "floor" else id
		mi.material_override = ArtKit.material(mat_id)
		if id == "glow" or id == "floor":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)
		result["stats"]["meshes"] += 1
		result["stats"]["vertices"] += bt.vertex_count()

	_build_environment(world, data)
	_build_lights(world, data, ambience, high, result)
	if high:
		for p: Dictionary in data.get("particles", []):
			if _active(p):
				world.add_child(make_particles(str(p.get("type", "dust")), vec3(p.get("pos")), vec3(p.get("extent"), Vector3.ONE)))
				result["stats"]["particles"] += 1
		var vig := float(data.get("vignette", 0.35))
		if vig > 0.0:
			world.add_child(_vignette(vig))
	if ambience.has_work():
		world.add_child(ambience)
	else:
		ambience.free()

	for id: String in data.get("spawns", {}):
		var s: Dictionary = data["spawns"][id]
		var sxf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(s.get("rot", 0.0)))), vec3(s.get("pos")))
		result["spawns"][id] = sxf
	for a: Dictionary in data.get("actors", []):
		if not _active(a):
			continue
		var actor_id := str(a["id"])
		if actor_id == str(GameState.location.get("player", "")):
			continue
		if GameState.CHARACTERS.has(actor_id) and not GameState.is_alive(actor_id):
			continue
		var node := make_body(actor_id)
		node.position = vec3(a.get("pos"))
		node.rotation_degrees.y = float(a.get("rot", 0.0))
		world.add_child(node)
		result["actors"][actor_id] = node
	for id: String in data.get("points", {}):
		var p: Dictionary = data["points"][id]
		result["points"][id] = {"pos": vec3(p.get("pos")), "radius": float(p.get("radius", 1.4))}
	return result


static func _build_walls(batches: Dictionary, walls: Array, size: Vector3, data: Dictionary) -> void:
	var style := str(data.get("wall_style", "plain"))
	var wall_col := color(data.get("wall_color", "#3a3f45"))
	var mat := str(data.get("wall_mat", "metal" if style == "factory" else ("concrete" if style == "fence" else "plaster")))
	var bt := PropKit.batch(batches, mat)
	for w: Array in walls:
		var center: Vector3 = w[0]
		var wsize: Vector3 = w[1]
		var inward: Vector3 = w[2]
		var length := maxf(wsize.x, wsize.z)
		var along_x := wsize.x > wsize.z
		var face := center + inward * (WALL_T / 2.0)
		if style == "fence":
			var base_h := 0.6
			bt.add_box(Transform3D(Basis(), Vector3(center.x, base_h / 2.0, center.z)), _strip(along_x, length, base_h, WALL_T), wall_col)
			PropKit.build("fence", batches, Transform3D(Basis(), Vector3(center.x, base_h + 1.2, center.z)),
				_strip(along_x, length, 2.4, 0.06), wall_col.lightened(0.15), "metal")
			continue
		bt.add_box_tiled(Transform3D(Basis(), center), wsize, wall_col, 1.5)
		# Lower band: darker wainscot / skirting.
		var band_h := 1.2 if style == "factory" else (0.12 if style != "plain" else 0.1)
		var band_col := wall_col.darkened(0.3 if style == "factory" else 0.45)
		bt.add_box(Transform3D(Basis(), face + Vector3(0, band_h / 2.0 - center.y, 0) + inward * 0.02),
			_strip(along_x, length, band_h, 0.04), band_col)
		if style == "home":
			bt.add_box(Transform3D(Basis(), face + Vector3(0, size.y - 0.06 - center.y, 0) + inward * 0.02),
				_strip(along_x, length, 0.08, 0.05), wall_col.lightened(0.18))
		if style == "factory":
			var n := int(length / 4.0)
			for i in range(1, n):
				var t := -length / 2.0 + i * length / n
				var p := face + (Vector3(t, 0, 0) if along_x else Vector3(0, 0, t)) + inward * 0.15
				PropKit.build("beam", batches, Transform3D(Basis(Vector3.UP, 0.0 if along_x else PI / 2), p),
					Vector3(0.3, size.y, 0.3), Color(0.32, 0.35, 0.38), "metal")
			if length > 12.0:
				for i in n:
					var t := -length / 2.0 + (i + 0.5) * length / n
					var p := face + Vector3(0, size.y - 1.3 - center.y, 0) + (Vector3(t, 0, 0) if along_x else Vector3(0, 0, t))
					PropKit.build("window", batches, Transform3D(Basis(), p),
						Vector3(2.4, 0.9, 0.06) if along_x else Vector3(0.06, 0.9, 2.4),
						color(data.get("window_color", "#46536a")), "glow")


static func _strip(along_x: bool, length: float, height: float, depth: float) -> Vector3:
	return Vector3(length, height, depth) if along_x else Vector3(depth, height, length)


static func _build_environment(world: Node3D, data: Dictionary) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var bg := color(data.get("background", "#0d0f11"))
	e.background_color = bg
	e.background_mode = Environment.BG_COLOR
	var fog_col := bg
	var sky_data: Dictionary = data.get("sky", {})
	if not sky_data.is_empty():
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = color(sky_data.get("top", "#0a1020"))
		sm.sky_horizon_color = color(sky_data.get("horizon", "#2a3040"))
		sm.ground_horizon_color = sm.sky_horizon_color
		sm.ground_bottom_color = color(sky_data.get("ground", "#08090a"))
		sm.sky_curve = float(sky_data.get("curve", 0.12))
		sm.sun_angle_max = 8.0
		var sky := Sky.new()
		sky.sky_material = sm
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		e.sky = sky
		e.background_mode = Environment.BG_SKY
		fog_col = sm.sky_horizon_color
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = color(data.get("ambient", "#5a6470"))
	e.ambient_light_energy = float(data.get("ambient_energy", 0.6))
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = bool(data.get("fog", false))
	e.fog_light_color = fog_col
	e.fog_density = float(data.get("fog_density", 0.02))
	env.environment = e
	world.add_child(env)


static func _build_lights(world: Node3D, data: Dictionary, ambience: Ambience, high: bool, result: Dictionary) -> void:
	var sun_data: Dictionary = data.get("sun", {})
	if not sun_data.is_empty():
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = vec3(sun_data.get("rot"), Vector3(-55, 35, 0))
		sun.light_energy = float(sun_data.get("energy", 0.7))
		sun.light_color = color(sun_data.get("color", "#fff2dd"))
		sun.shadow_enabled = high and bool(sun_data.get("shadow", true))
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = float(sun_data.get("shadow_distance", 25.0))
		world.add_child(sun)
	for l: Dictionary in data.get("lights", []):
		if not _active(l):
			continue
		var omni := OmniLight3D.new()
		omni.position = vec3(l.get("pos"))
		omni.omni_range = float(l.get("range", 6.0))
		omni.light_energy = float(l.get("energy", 1.0))
		var lc := color(l.get("color", "#ffe6c0"))
		omni.light_color = lc
		omni.shadow_enabled = false
		world.add_child(omni)
		result["stats"]["lights"] += 1
		if l.has("flicker"):
			ambience.add_flicker(omni, str(l["flicker"]))
		if high and bool(l.get("halo", false)):
			world.add_child(_halo(omni.position, lc, float(l.get("halo_size", 0.9))))
		if high and bool(l.get("beam", false)):
			world.add_child(_shaft(omni.position, lc, omni.omni_range))


static func _halo(pos: Vector3, c: Color, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Halo"
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := ArtKit.additive_material(true).duplicate() as StandardMaterial3D
	m.albedo_color = Color(c.r, c.g, c.b, 0.55)
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Fake volumetric cone from a lamp down to the floor (additive, no lighting).
static func _shaft(pos: Vector3, c: Color, light_range: float) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var seg := 12
	var r0 := 0.12
	var r1 := clampf(light_range * 0.22, 0.6, 2.2)
	var top := Color(c.r, c.g, c.b, 0.16)
	var bot := Color(c.r, c.g, c.b, 0.0)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var t0 := Vector3(sin(a0) * r0, 0, cos(a0) * r0)
		var t1 := Vector3(sin(a1) * r0, 0, cos(a1) * r0)
		var b0 := Vector3(sin(a0) * r1, -pos.y, cos(a0) * r1)
		var b1 := Vector3(sin(a1) * r1, -pos.y, cos(a1) * r1)
		for p: Vector3 in [t0, b0, b1, t0, b1, t1]:
			verts.append(p)
			cols.append(top if p.y == 0.0 else bot)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Shaft"
	mi.mesh = mesh
	mi.material_override = ArtKit.additive_material(false)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _add_fire(world: Node3D, ambience: Ambience, xf: Transform3D, s: Vector3, col: Color, high: bool,
		result: Dictionary) -> void:
	var bt := MeshBatch.new()
	bt.ao = false
	# Three staggered flame sheets, brighter core; origin at the base so they scale upwards.
	for i in 3:
		var f := 1.0 - i * 0.22
		var c := col.lerp(Color(1, 0.9, 0.5), i * 0.35)
		bt.add_box(Transform3D(Basis(), Vector3((i - 1) * s.x * 0.18, s.y * f * 0.5, (i - 1) * 0.04)),
			Vector3(s.x * (1.0 - i * 0.25), s.y * f, maxf(0.05, s.z * 0.5)), c)
	var mi := MeshInstance3D.new()
	mi.name = "Fire"
	mi.mesh = bt.commit()
	mi.material_override = ArtKit.material("glow")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = xf.translated_local(Vector3(0, -s.y * 0.5, 0))
	world.add_child(mi)
	ambience.add_fire(mi)
	if high:
		var top := xf.origin + Vector3(0, s.y * 0.5, 0)
		var ext := Vector3(s.x * 0.5, 0.2, maxf(0.2, s.z * 0.5))
		world.add_child(make_particles("embers", top, ext))
		world.add_child(make_particles("smoke", top + Vector3(0, 0.4, 0), ext))
		result["stats"]["particles"] += 2


static func make_particles(type: String, pos: Vector3, extent: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Particles_" + type
	p.position = pos
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extent
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	p.mesh = q
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.25, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 0.8))
	p.color_ramp = ramp
	p.material_override = ArtKit.additive_material(true)
	p.direction = Vector3.UP
	p.gravity = Vector3.ZERO
	if type == "smoke" or type == "steam":
		p.amount = 16 if type == "smoke" else 12
		p.lifetime = 6.0 if type == "smoke" else 3.0
		p.material_override = ArtKit.smoke_material()
		p.color = Color(0.16, 0.15, 0.15, 0.45) if type == "smoke" else Color(0.85, 0.88, 0.9, 0.25)
		p.initial_velocity_min = 0.3
		p.initial_velocity_max = 0.7 if type == "smoke" else 1.2
		p.spread = 15.0
		p.gravity = Vector3(0.05, 0.12, 0)
		p.scale_amount_min = 0.8
		p.scale_amount_max = 1.8
		var grow := Curve.new()
		grow.add_point(Vector2(0, 0.4))
		grow.add_point(Vector2(1, 1.6))
		p.scale_amount_curve = grow
	elif type == "embers":
		p.amount = 24
		p.lifetime = 2.2
		p.color = Color(1.0, 0.55, 0.15, 1.0)
		p.initial_velocity_min = 0.8
		p.initial_velocity_max = 1.8
		p.spread = 25.0
		p.gravity = Vector3(0.1, 0.3, 0)
		p.scale_amount_min = 0.03
		p.scale_amount_max = 0.07
	elif type == "mist":
		p.amount = 8
		p.lifetime = 14.0
		p.material_override = ArtKit.smoke_material()
		p.color = Color(0.55, 0.62, 0.7, 0.12)
		p.initial_velocity_min = 0.05
		p.initial_velocity_max = 0.2
		p.direction = Vector3.RIGHT
		p.spread = 180.0
		p.flatness = 1.0
		p.scale_amount_min = 3.0
		p.scale_amount_max = 5.0
	else:  # dust motes drifting in lamp light
		p.amount = 28
		p.lifetime = 9.0
		p.color = Color(1.0, 0.95, 0.85, 0.35)
		p.initial_velocity_min = 0.02
		p.initial_velocity_max = 0.08
		p.spread = 180.0
		p.scale_amount_min = 0.025
		p.scale_amount_max = 0.05
	p.preprocess = p.lifetime
	return p


static func _vignette(strength: float) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = -1
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, strength))
	g.add_point(0.55, Color(0, 0, 0, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.05, 0.5)
	t.width = 128
	t.height = 128
	var rect := TextureRect.new()
	rect.texture = t
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	return layer
