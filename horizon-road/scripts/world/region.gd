class_name Region
extends Node3D
## Root of a region scene. Registers itself with GameState, applies the
## region's weather odds and start time, and answers terrain queries.

signal region_ready

@export var definition: RegionDefinition
@export var terrain_path: NodePath
@export var camper_path: NodePath

var terrain: HighlandTerrain


func _ready() -> void:
	terrain = get_node(terrain_path) as HighlandTerrain
	GameState.register_region(self)
	if definition:
		AudioManager.region_bird_density = definition.bird_density
		TimeManager.set_time(definition.start_hour)
		WeatherManager.configure_for_region(definition.weather_weights, definition.start_weather)
	var camper := get_node_or_null(camper_path) as Node3D
	if camper:
		var spawn: Transform3D = terrain.spawn_transform
		spawn.origin.y = terrain.height_at(spawn.origin.x, spawn.origin.z) + 0.3
		camper.global_transform = spawn
	region_ready.emit()
	SaveManager.continue_if_possible.call_deferred()


func get_surface_at(world_pos: Vector3) -> HighlandTerrain.Surface:
	return terrain.surface_at(world_pos.x, world_pos.z)


func get_ground_height(x: float, z: float) -> float:
	return terrain.height_at(x, z)
