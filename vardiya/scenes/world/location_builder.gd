extends RefCounted
## Builds a grey-box location from data/locations/<id>.json:
## floor + perimeter walls, box props, lights, spawn points, actor marks and
## interaction points. Low-poly, per-vertex shaded, one shadowed light.

const LOCATION_DIR := "res://data/locations/"
const CHARACTERS_PATH := "res://data/characters.json"

static var _materials: Dictionary = {}
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


static func material(c: Color, emissive: bool = false) -> StandardMaterial3D:
	var key := c.to_html() + ("e" if emissive else "")
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.roughness = 1.0
	m.metallic_specular = 0.1
	if emissive:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.5
	_materials[key] = m
	return m


static func box(parent: Node3D, pos: Vector3, size: Vector3, col: Color, collide: bool = true,
		rot_deg: float = 0.0, emissive: bool = false) -> Node3D:
	var root: Node3D
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		body.add_child(shape)
		root = body
	else:
		root = Node3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material(col, emissive)
	root.add_child(mi)
	root.position = pos
	root.rotation_degrees.y = rot_deg
	parent.add_child(root)
	return root


## Low-poly stand-in body for a character: capsule, head, facing marker.
static func make_body(character_id: String) -> Node3D:
	var info: Dictionary = characters().get(character_id, {})
	var body_col := color(info.get("body", "#666666"))
	var root := Node3D.new()
	root.name = character_id
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.45
	cap.radial_segments = 8
	cap.rings = 2
	torso.mesh = cap
	torso.position.y = 0.75
	torso.material_override = material(body_col)
	root.add_child(torso)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	sphere.radial_segments = 8
	sphere.rings = 4
	head.mesh = sphere
	head.position.y = 1.62
	head.material_override = material(Color(0.85, 0.72, 0.6))
	root.add_child(head)
	var nose := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(0.08, 0.06, 0.12)
	nose.mesh = nb
	nose.position = Vector3(0, 1.6, 0.17)
	nose.material_override = material(Color(0.75, 0.6, 0.5))
	root.add_child(nose)
	return root


## Builds everything into `world` and returns lookup tables:
## {"spawns": {id: Transform3D}, "actors": {id: Node3D}, "points": {id: {pos, radius}}, "camera": {...}}
static func build(world: Node3D, data: Dictionary) -> Dictionary:
	var result := {"spawns": {}, "actors": {}, "points": {}, "camera": data.get("camera", {})}
	var size := vec3(data.get("size"), Vector3(12, 4, 10))
	var wall_col := color(data.get("wall_color", "#3a3f45"))
	var floor_col := color(data.get("floor_color", "#2a2e33"))
	var t := 0.2
	box(world, Vector3(0, -t / 2.0, 0), Vector3(size.x, t, size.z), floor_col)
	box(world, Vector3(0, size.y / 2.0, -size.z / 2.0), Vector3(size.x, size.y, t), wall_col)
	box(world, Vector3(0, size.y / 2.0, size.z / 2.0), Vector3(size.x, size.y, t), wall_col)
	box(world, Vector3(-size.x / 2.0, size.y / 2.0, 0), Vector3(t, size.y, size.z), wall_col)
	box(world, Vector3(size.x / 2.0, size.y / 2.0, 0), Vector3(t, size.y, size.z), wall_col)
	for b: Dictionary in data.get("boxes", []):
		box(world, vec3(b.get("pos")), vec3(b.get("size"), Vector3.ONE), color(b.get("color", "#555555")),
			bool(b.get("collide", true)), float(b.get("rot", 0.0)), bool(b.get("emissive", false)))

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = color(data.get("background", "#0d0f11"))
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = color(data.get("ambient", "#5a6470"))
	e.ambient_light_energy = float(data.get("ambient_energy", 0.6))
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = bool(data.get("fog", false))
	e.fog_light_color = e.background_color
	e.fog_density = float(data.get("fog_density", 0.02))
	env.environment = e
	world.add_child(env)

	var sun_data: Dictionary = data.get("sun", {})
	if not sun_data.is_empty():
		var sun := DirectionalLight3D.new()
		var rot := vec3(sun_data.get("rot"), Vector3(-55, 35, 0))
		sun.rotation_degrees = rot
		sun.light_energy = float(sun_data.get("energy", 0.7))
		sun.light_color = color(sun_data.get("color", "#fff2dd"))
		sun.shadow_enabled = bool(sun_data.get("shadow", true))
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = float(sun_data.get("shadow_distance", 25.0))
		world.add_child(sun)
	for l: Dictionary in data.get("lights", []):
		var omni := OmniLight3D.new()
		omni.position = vec3(l.get("pos"))
		omni.omni_range = float(l.get("range", 6.0))
		omni.light_energy = float(l.get("energy", 1.0))
		omni.light_color = color(l.get("color", "#ffe6c0"))
		omni.shadow_enabled = false
		world.add_child(omni)

	for id: String in data.get("spawns", {}):
		var s: Dictionary = data["spawns"][id]
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(s.get("rot", 0.0)))), vec3(s.get("pos")))
		result["spawns"][id] = xf
	for a: Dictionary in data.get("actors", []):
		if a.has("if") and not DecisionManager.evaluate(a["if"]):
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
