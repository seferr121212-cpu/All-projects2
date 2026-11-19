class_name CamperInterior
extends Node3D
## The camper's living space. It is built at the van's real position (a bit
## roomier than the outside, the van body is hidden while inside), so the
## windows look out on the actual landscape, weather and time of day.

signal exit_requested
signal sleep_requested
signal map_requested
signal journal_requested

const WIDTH: float = 2.6
const LENGTH: float = 5.0
const HEIGHT: float = 2.2
## Floor height above the van's origin so uneven ground never pokes through.
const FLOOR_OFFSET: float = 0.75

var spawn_point := Vector3(0.25, 0.0, 0.85)
var _comfort_nodes: Array[Node3D] = []
var _lamp: OmniLight3D
var _string_lights: Array[Node3D] = []
var _kettle_audio: AudioStreamPlayer3D


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_build_shell()
	_build_furniture()
	GameState.upgrades_changed.connect(_apply_comfort)
	_apply_comfort()


## Moves the room onto the van (upright, facing the van's heading) and shows it.
func open_at(camper: Node3D) -> void:
	var yaw: float = camper.global_rotation.y
	global_transform = Transform3D(Basis(Vector3.UP, yaw), camper.global_position + Vector3(0, FLOOR_OFFSET, 0))
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


func close() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func get_spawn_global() -> Vector3:
	return global_transform * spawn_point


func _process(_delta: float) -> void:
	var night: float = TimeManager.get_night_factor()
	_lamp.light_energy = lerpf(0.35, 1.3, night)
	for s: Node3D in _string_lights:
		s.visible = s.get_meta(&"unlocked", false) and (night > 0.2 or WeatherManager.current.cloud_coverage > 0.8)


# --- Shell -----------------------------------------------------------------

func _build_shell() -> void:
	var b := LowPolyMeshes.Builder.new(90)
	var wood := Color(0.62, 0.45, 0.3)
	var panel := Color(0.93, 0.88, 0.78)
	var hw: float = WIDTH * 0.5
	var hl: float = LENGTH * 0.5
	# Floor planks.
	for i: int in 9:
		var x: float = -hw + (i + 0.5) * WIDTH / 9.0
		b.add(_box(Vector3(WIDTH / 9.0 - 0.01, 0.06, LENGTH)), _at(Vector3(x, -0.03, 0)), wood.darkened(0.04 * (i % 3)))
	b.add(_box(Vector3(WIDTH + 0.2, 0.08, LENGTH + 0.2)), _at(Vector3(0, HEIGHT + 0.04, 0)), panel.lightened(0.05))
	# Walls with openings: [u_from, u_to, v_from, v_to] along each wall.
	_wall(b, Vector3(-hw, 0, 0), Vector3.FORWARD, LENGTH, [[-0.6, 0.6, 1.0, 1.7]], panel)                 # left: kitchen window
	_wall(b, Vector3(hw, 0, 0), Vector3.FORWARD, LENGTH, [[0.6, 1.6, 1.0, 1.65], [-1.4, -0.6, 0.0, 1.95]], panel)  # right: desk window + door
	_wall(b, Vector3(0, 0, hl), Vector3.RIGHT, WIDTH, [[-0.7, 0.7, 1.15, 1.7]], panel)                   # rear: over the bed
	_wall(b, Vector3(0, 0, -hl), Vector3.RIGHT, WIDTH, [[-1.0, 1.0, 1.15, 1.85]], panel)                 # front: windscreen
	var mesh := MeshInstance3D.new()
	mesh.mesh = b.commit(LowPolyMeshes.vertex_color_material(0.8))
	add_child(mesh)
	# Collision: four walls + floor (door gap left open is fine; the door is an interactable).
	var body := StaticBody3D.new()
	add_child(body)
	for spec: Array in [
		[Vector3(WIDTH, 0.1, LENGTH), Vector3(0, -0.05, 0)],
		[Vector3(0.1, HEIGHT, LENGTH), Vector3(-hw - 0.05, HEIGHT * 0.5, 0)],
		[Vector3(0.1, HEIGHT, LENGTH), Vector3(hw + 0.05, HEIGHT * 0.5, 0)],
		[Vector3(WIDTH, HEIGHT, 0.1), Vector3(0, HEIGHT * 0.5, hl + 0.05)],
		[Vector3(WIDTH, HEIGHT, 0.1), Vector3(0, HEIGHT * 0.5, -hl - 0.05)],
		[Vector3(WIDTH, 0.1, LENGTH), Vector3(0, HEIGHT + 0.05, 0)],
	]:
		var shape := BoxShape3D.new()
		shape.size = spec[0]
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position = spec[1]
		body.add_child(col)
	# Door panel + exit.
	var door := MeshInstance3D.new()
	door.mesh = LowPolyMeshes.Builder.new(91).add(_box(Vector3(0.05, 1.95, 0.8)), _at(Vector3(0, 0.975, 0)), Color(0.22, 0.52, 0.52)) \
			.add(_box(Vector3(0.07, 0.06, 0.18)), _at(Vector3(-0.02, 1.0, -0.28)), Color(0.8, 0.8, 0.82)) \
			.commit(LowPolyMeshes.vertex_color_material(0.6))
	door.position = Vector3(hw - 0.02, 0, 1.0)
	add_child(door)
	_interactable("UI_GO_OUTSIDE", Vector3(hw - 0.3, 1.0, 1.0), func() -> void: exit_requested.emit())
	# Lighting: warm ceiling lamp.
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.78, 0.52)
	_lamp.omni_range = 5.5
	_lamp.shadow_enabled = true
	_lamp.position = Vector3(0, HEIGHT - 0.25, 0.0)
	add_child(_lamp)
	var shade := MeshInstance3D.new()
	shade.mesh = LowPolyMeshes.Builder.new(92).add(LowPolyMeshes._cone(0.22, 0.08, 0.18, 8), _at(Vector3.ZERO), Color(0.95, 0.85, 0.6)).commit(_glow_material(Color(1.0, 0.8, 0.5), 1.5))
	shade.position = Vector3(0, HEIGHT - 0.12, 0.0)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shade)


## Builds a wall plane centred at `origin`, running along `along`, with
## rectangular openings [u0, u1, v0, v1] (u along the wall, v height).
func _wall(b: LowPolyMeshes.Builder, origin: Vector3, along: Vector3, length: float, holes: Array, color: Color) -> void:
	var cuts: Array[float] = [-length * 0.5, length * 0.5]
	for h: Array in holes:
		cuts.append(h[0])
		cuts.append(h[1])
	cuts.sort()
	var thick := Vector3(0.08, 0, 0) if absf(along.z) > 0.5 else Vector3(0, 0, 0.08)
	for i: int in cuts.size() - 1:
		var u0: float = cuts[i]
		var u1: float = cuts[i + 1]
		if u1 - u0 < 0.01:
			continue
		var mid: float = (u0 + u1) * 0.5
		var spans: Array = [[0.0, HEIGHT]]
		for h: Array in holes:
			if mid > h[0] and mid < h[1]:
				spans = [[0.0, h[2]], [h[3], HEIGHT]]
		for span: Array in spans:
			var v0: float = span[0]
			var v1: float = span[1]
			if v1 - v0 < 0.01:
				continue
			var size: Vector3 = thick + along.abs() * (u1 - u0) + Vector3(0, v1 - v0, 0)
			var pos: Vector3 = origin + along * mid + Vector3(0, (v0 + v1) * 0.5, 0)
			b.add(_box(size), _at(pos), color, 0.0, 0.02)
	# Window frames.
	for h: Array in holes:
		if h[2] > 0.05:
			var frame_c := Color(0.55, 0.4, 0.28)
			b.add(_box(thick * 1.6 + along.abs() * (h[1] - h[0] + 0.08) + Vector3(0, 0.05, 0)), _at(origin + along * (h[0] + h[1]) * 0.5 + Vector3(0, h[2], 0)), frame_c)


# --- Furniture -------------------------------------------------------------

func _build_furniture() -> void:
	var hw: float = WIDTH * 0.5
	var b := LowPolyMeshes.Builder.new(93)
	var wood := Color(0.55, 0.38, 0.24)
	# Bed across the rear.
	b.add(_box(Vector3(WIDTH - 0.1, 0.45, 1.3)), _at(Vector3(0, 0.225, 1.8)), wood)
	b.add(_box(Vector3(WIDTH - 0.2, 0.2, 1.2)), _at(Vector3(0, 0.55, 1.8)), Color(0.95, 0.93, 0.88))
	b.add(_box(Vector3(WIDTH - 0.6, 0.08, 1.0)), _at(Vector3(0.2, 0.67, 1.7)), Color(0.75, 0.25, 0.2), 0.01, 0.06)
	b.add(_box(Vector3(0.7, 0.16, 0.4)), _at(Vector3(-0.75, 0.73, 2.15)), Color(0.98, 0.97, 0.93))
	# Kitchen counter on the left: sink, two-burner stove, kettle (çaydanlık), glasses.
	b.add(_box(Vector3(0.6, 0.9, 1.6)), _at(Vector3(-hw + 0.3, 0.45, 0.0)), Color(0.78, 0.72, 0.62))
	b.add(_box(Vector3(0.62, 0.05, 1.64)), _at(Vector3(-hw + 0.3, 0.92, 0.0)), wood.lightened(0.1))
	b.add(_box(Vector3(0.4, 0.04, 0.4)), _at(Vector3(-hw + 0.32, 0.95, 0.45)), Color(0.75, 0.76, 0.78))
	for z: float in [-0.25, -0.6]:
		b.add(LowPolyMeshes._cone(0.1, 0.1, 0.03, 8), _at(Vector3(-hw + 0.32, 0.96, z)), Color(0.15, 0.15, 0.16))
	b.add(LowPolyMeshes._cone(0.11, 0.09, 0.16, 8), _at(Vector3(-hw + 0.32, 1.05, -0.25)), Color(0.82, 0.82, 0.85))
	b.add(LowPolyMeshes._cone(0.08, 0.06, 0.12, 8), _at(Vector3(-hw + 0.32, 1.19, -0.25)), Color(0.86, 0.86, 0.88))
	for z: float in [0.0, 0.12]:
		b.add(LowPolyMeshes._cone(0.025, 0.03, 0.08, 6), _at(Vector3(-hw + 0.45, 0.98, z)), Color(0.7, 0.25, 0.12))
	# Shelf with books above the counter.
	b.add(_box(Vector3(0.3, 0.04, 1.4)), _at(Vector3(-hw + 0.17, 1.8, 0.0)), wood)
	for i: int in 7:
		b.add(_box(Vector3(0.2, 0.22 + (i % 3) * 0.03, 0.06)), _at(Vector3(-hw + 0.17, 1.93, -0.55 + i * 0.09)), Color.from_hsv(fmod(i * 0.17, 1.0), 0.5, 0.7))
	# Dinette at the front: map table + bench.
	b.add(_box(Vector3(1.4, 0.05, 0.8)), _at(Vector3(0.0, 0.75, -1.6)), wood.lightened(0.08))
	b.add(_box(Vector3(0.1, 0.72, 0.1)), _at(Vector3(0.0, 0.37, -1.6)), wood)
	b.add(_box(Vector3(1.0, 0.012, 0.6)), _at(Vector3(0.0, 0.783, -1.6), 0.15), Color(0.93, 0.87, 0.7))
	b.add(_box(Vector3(0.3, 0.014, 0.2)), _at(Vector3(0.15, 0.786, -1.65), 0.15), Color(0.45, 0.65, 0.4))
	b.add(_box(Vector3(WIDTH - 0.2, 0.45, 0.45)), _at(Vector3(0, 0.225, -2.22)), Color(0.35, 0.45, 0.55))
	# Writing desk on the right with the journal.
	b.add(_box(Vector3(0.55, 0.05, 1.0)), _at(Vector3(hw - 0.28, 0.75, -0.9)), wood.lightened(0.05))
	b.add(_box(Vector3(0.5, 0.7, 0.06)), _at(Vector3(hw - 0.28, 0.37, -0.42)), wood)
	b.add(_box(Vector3(0.32, 0.03, 0.24)), _at(Vector3(hw - 0.3, 0.79, -0.95), 0.2), Color(0.45, 0.25, 0.15))
	b.add(_box(Vector3(0.28, 0.005, 0.2)), _at(Vector3(hw - 0.3, 0.806, -0.95), 0.2), Color(0.97, 0.95, 0.88))
	var mesh := MeshInstance3D.new()
	mesh.mesh = b.commit(LowPolyMeshes.vertex_color_material(0.8))
	add_child(mesh)
	var body := StaticBody3D.new()
	add_child(body)
	for spec: Array in [
		[Vector3(WIDTH, 0.6, 1.3), Vector3(0, 0.3, 1.8)],
		[Vector3(0.6, 0.95, 1.6), Vector3(-hw + 0.3, 0.47, 0.0)],
		[Vector3(1.4, 0.8, 0.8), Vector3(0, 0.4, -1.6)],
		[Vector3(0.55, 0.8, 1.0), Vector3(hw - 0.28, 0.4, -0.9)],
	]:
		var shape := BoxShape3D.new()
		shape.size = spec[0]
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position = spec[1]
		body.add_child(col)
	# Desk lamp.
	var desk_lamp := OmniLight3D.new()
	desk_lamp.light_color = Color(1.0, 0.75, 0.45)
	desk_lamp.omni_range = 2.0
	desk_lamp.light_energy = 0.6
	desk_lamp.position = Vector3(hw - 0.35, 1.2, -1.25)
	add_child(desk_lamp)

	_interactable("UI_SLEEP", Vector3(0, 0.8, 1.4), func() -> void: sleep_requested.emit())
	_interactable("UI_MAP", Vector3(0, 0.95, -1.45), func() -> void: map_requested.emit())
	_interactable("UI_JOURNAL_OPEN", Vector3(hw - 0.35, 0.95, -0.95), func() -> void: journal_requested.emit())
	_kettle_audio = AudioStreamPlayer3D.new()
	_kettle_audio.stream = ProceduralAudio.kettle()
	_kettle_audio.bus = AudioManager.BUS_SFX
	_kettle_audio.position = Vector3(-hw + 0.32, 1.1, -0.25)
	add_child(_kettle_audio)
	_interactable("UI_BREW_TEA", Vector3(-hw + 0.45, 1.05, -0.25), _brew_tea)
	_build_comfort()


## Comfort upgrade items: rug and plants (level 1), string lights and cushions (level 2).
func _build_comfort() -> void:
	var hw: float = WIDTH * 0.5
	var l1 := LowPolyMeshes.Builder.new(94)
	l1.add(_box(Vector3(1.0, 0.012, 1.8)), _at(Vector3(0.2, 0.006, -0.1)), Color(0.72, 0.2, 0.18))
	l1.add(_box(Vector3(0.8, 0.014, 1.6)), _at(Vector3(0.2, 0.008, -0.1)), Color(0.9, 0.7, 0.35))
	l1.add(_box(Vector3(0.5, 0.016, 1.3)), _at(Vector3(0.2, 0.01, -0.1)), Color(0.25, 0.35, 0.55))
	for p: Vector3 in [Vector3(-hw + 0.2, 0.94, 0.62), Vector3(hw - 0.15, 0.8, -1.3)]:
		l1.add(LowPolyMeshes._cone(0.08, 0.06, 0.14, 6), _at(p + Vector3(0, 0.07, 0)), Color(0.75, 0.4, 0.25))
		l1.add(LowPolyMeshes._sphere(0.12, 0.22, 6, 3), _at(p + Vector3(0, 0.22, 0)), Color(0.25, 0.5, 0.2), 0.04, 0.1)
	var n1 := MeshInstance3D.new()
	n1.mesh = l1.commit(LowPolyMeshes.vertex_color_material(0.85))
	n1.set_meta(&"level", 1)
	add_child(n1)
	_comfort_nodes.append(n1)
	var l2 := LowPolyMeshes.Builder.new(95)
	for i: int in 3:
		l2.add(_box(Vector3(0.4, 0.15, 0.35)), _at(Vector3(-0.8 + i * 0.8, 0.53, -2.2)), [Color(0.9, 0.6, 0.2), Color(0.3, 0.55, 0.5), Color(0.75, 0.3, 0.35)][i])
	var n2 := MeshInstance3D.new()
	n2.mesh = l2.commit(LowPolyMeshes.vertex_color_material(0.85))
	n2.set_meta(&"level", 2)
	add_child(n2)
	_comfort_nodes.append(n2)
	# String lights zig-zagging along the ceiling edge.
	var bulbs := Node3D.new()
	bulbs.set_meta(&"level", 2)
	var glow: Material = _glow_material(Color(1.0, 0.8, 0.45), 3.0)
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.025
	bulb_mesh.height = 0.05
	bulb_mesh.material = glow
	for side: float in [-1.0, 1.0]:
		for i: int in 14:
			var z: float = -2.3 + i * 0.35
			var bulb := MeshInstance3D.new()
			bulb.mesh = bulb_mesh
			bulb.position = Vector3(side * (hw - 0.08), HEIGHT - 0.12 - 0.06 * absf(sin(i * 1.3)), z)
			bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bulbs.add_child(bulb)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.75, 0.45)
	fill.omni_range = 4.0
	fill.light_energy = 0.5
	fill.position = Vector3(0, HEIGHT - 0.3, -0.5)
	bulbs.add_child(fill)
	add_child(bulbs)
	_comfort_nodes.append(bulbs)
	_string_lights.append(bulbs)


func _apply_comfort() -> void:
	var level: int = GameState.get_upgrade_level("comfort")
	for n: Node3D in _comfort_nodes:
		n.set_meta(&"unlocked", int(n.get_meta(&"level")) <= level)
		n.visible = n.get_meta(&"unlocked")
	for s: Node3D in _string_lights:
		s.visible = s.get_meta(&"unlocked", false)


func _brew_tea() -> void:
	_kettle_audio.play()
	TimeManager.advance_hours(0.25)
	GameState.notify(tr(&"UI_TEA_BREWED"))


func _interactable(prompt: String, pos: Vector3, action: Callable) -> void:
	var it := Interactable.new()
	it.prompt_key = prompt
	it.distance = 1.6
	it.position = pos
	it.interacted.connect(func(_by: Node3D) -> void: action.call())
	add_child(it)


func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func _box(size: Vector3) -> BoxMesh:
	return LowPolyMeshes._box(size)


static func _at(pos: Vector3, rot_y: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y), pos)
