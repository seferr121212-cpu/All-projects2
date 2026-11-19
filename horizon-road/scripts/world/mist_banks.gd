class_name MistBanks
extends Node3D
## Low volumetric mist lying in the valleys and over the lake -- the classic
## Black Sea highland morning. Density follows weather and is boosted around
## dawn, then burns off as the day warms.

@export var terrain_path: NodePath
## x, z, size_x, size_z
@export var banks: Array[Vector4] = [
	Vector4(25, -15, 150, 130), Vector4(-60, 60, 180, 140), Vector4(90, 80, 140, 160),
	Vector4(-20, -230, 300, 90), Vector4(240, 40, 100, 320), Vector4(-240, 0, 100, 300),
]
@export var thickness: float = 14.0
@export var max_density: float = 0.11

var _material := FogMaterial.new()
var _volumes: Array[FogVolume] = []
var _drift: float = 0.0


func _ready() -> void:
	var terrain := get_node(terrain_path) as HighlandTerrain
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	noise.fractal_octaves = 3
	var tex := NoiseTexture3D.new()
	tex.width = 48
	tex.height = 16
	tex.depth = 48
	tex.seamless = true
	tex.noise = noise
	_material.density_texture = tex
	_material.height_falloff = 0.6
	_material.edge_fade = 0.35
	_material.albedo = Color(0.92, 0.94, 0.96)
	for b: Vector4 in banks:
		var v := FogVolume.new()
		v.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		v.size = Vector3(b.z, thickness, b.w)
		v.material = _material
		add_child(v)
		var ground: float = terrain.height_at(b.x, b.y)
		v.global_position = Vector3(b.x, ground + thickness * 0.25, b.y)
		_volumes.append(v)


func _process(delta: float) -> void:
	var hour: float = TimeManager.time_of_day
	# Morning mist peaks just after dawn and fades by late morning.
	var morning: float = smoothstep(3.5, 6.5, hour) * (1.0 - smoothstep(8.0, 11.0, hour))
	var evening: float = smoothstep(19.5, 22.0, hour) * 0.5 + (1.0 - smoothstep(0.0, 3.5, hour)) * 0.5
	# Light weather leaves no midday mist; it only lingers in damp, foggy weather.
	var weather_mist: float = smoothstep(0.25, 1.0, WeatherManager.current.mist)
	var mist: float = clampf(weather_mist + morning * 0.6 + evening * 0.25, 0.0, 1.0)
	_material.density = mist * max_density
	# A little self-glow so mist reads as bright haze, not dark smoke, from above.
	var day: float = 1.0 - TimeManager.get_night_factor()
	_material.emission = Color(0.55, 0.58, 0.62) * (0.08 + 0.35 * day)
	_drift += delta * (0.3 + WeatherManager.current.wind)
	for i: int in _volumes.size():
		_volumes[i].rotation.y = sin(_drift * 0.01 + i) * 0.15
