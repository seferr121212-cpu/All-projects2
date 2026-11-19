class_name Region
extends Node3D
## Root of a region scene. Registers itself with GameState, applies the
## region's weather odds and season, places the camper (start spot or the
## road gate when arriving from another region) and answers terrain queries.

signal region_ready

const GATE_RADIUS: float = 14.0

@export var definition: RegionDefinition
@export var terrain_path: NodePath
@export var camper_path: NodePath

var terrain: HighlandTerrain


func _ready() -> void:
	terrain = get_node(terrain_path) as HighlandTerrain
	GameState.register_region(self)
	var arriving: bool = GameState.arrival_pending
	if definition:
		AudioManager.region_bird_density = definition.bird_density
		AudioManager.set_music_style(definition.music_style)
		if not GameState.journey_started:
			TimeManager.set_time(definition.start_hour)
		apply_season()
		WeatherManager.configure_for_region(definition.weights_for(TimeManager.get_season()),
				definition.start_weather if not arriving else &"")
	TimeManager.season_changed.connect(func(_s: int) -> void:
		apply_season()
		WeatherManager.configure_for_region(definition.weights_for(TimeManager.get_season()), &""))
	var camper := get_node_or_null(camper_path) as Node3D
	if camper:
		var spawn: Transform3D = terrain.gate_transform if arriving else terrain.spawn_transform
		spawn.origin.y = terrain.height_at(spawn.origin.x, spawn.origin.z) + 0.3
		camper.global_transform = spawn
	_build_gate_sign()
	GameState.journey_started = true
	GameState.arrival_pending = false
	region_ready.emit()
	if arriving:
		GameState.notify(tr(&"TRAVEL_ARRIVED") % tr(StringName(definition.name_key)))
		SaveManager.autosave.call_deferred()
	elif SaveManager.has_pending() or DevCli.is_requested() or GameState.title_done:
		SaveManager.continue_if_possible.call_deferred()
	else:
		# First boot: the title screen decides between continue and a new journey.
		GameState.title_done = true
		GameState.show_title.call_deferred()


func apply_season() -> void:
	var s: int = TimeManager.get_season()
	WeatherManager.season_tint = definition.tint_for(s)
	WeatherManager.ground_snow = definition.snow_for(s)


func get_surface_at(world_pos: Vector3) -> HighlandTerrain.Surface:
	var s: HighlandTerrain.Surface = terrain.surface_at(world_pos.x, world_pos.z)
	# Lying snow makes every unpaved surface snowy.
	if WeatherManager.ground_snow > 0.5 and s != HighlandTerrain.Surface.ROAD:
		return HighlandTerrain.Surface.SNOW
	return s


func get_ground_height(x: float, z: float) -> float:
	return terrain.height_at(x, z)


func is_near_gate(pos: Vector3) -> bool:
	return Vector2(pos.x, pos.z).distance_to(Vector2(terrain.viewpoint_position.x, terrain.viewpoint_position.z)) < GATE_RADIUS


## Road sign at the gate pointing to the other regions.
func _build_gate_sign() -> void:
	var gate: Transform3D = terrain.gate_transform
	var side: Vector3 = gate.basis.x * 4.5
	var pos: Vector3 = gate.origin + side
	pos.y = terrain.height_at(pos.x, pos.z)
	var sign := Node3D.new()
	sign.name = "GateSign"
	add_child(sign)
	sign.global_transform = Transform3D(gate.basis, pos)
	var mesh := MeshInstance3D.new()
	mesh.mesh = LowPolyMeshes.Builder.new(300) \
			.add(LowPolyMeshes._box(Vector3(0.12, 2.6, 0.12)), Transform3D(Basis(), Vector3(0, 1.3, 0)), Color(0.4, 0.3, 0.2)) \
			.add(LowPolyMeshes._box(Vector3(2.6, 0.7, 0.08)), Transform3D(Basis(), Vector3(0.6, 2.3, 0)), Color(0.95, 0.85, 0.3)) \
			.commit(LowPolyMeshes.vertex_color_material(0.7))
	sign.add_child(mesh)
	var text := Label3D.new()
	var names: PackedStringArray = []
	for id: StringName in GameState.REGIONS:
		if id != definition.id:
			names.append(tr(StringName(GameState.get_region_def(id).name_key)))
	text.text = "→ " + ", ".join(names)
	text.font_size = 40
	text.pixel_size = 0.008
	text.modulate = Color(0.15, 0.12, 0.1)
	text.outline_size = 0
	text.position = Vector3(0.6, 2.3, -0.05)
	text.rotation.y = PI
	sign.add_child(text)
