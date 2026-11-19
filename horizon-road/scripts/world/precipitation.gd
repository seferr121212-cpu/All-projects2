class_name Precipitation
extends Node3D
## Rain and snow particles that follow the active camera. Intensity comes
## from WeatherManager via `amount_ratio`, so changes fade rather than pop.

const RAIN_AMOUNT: int = 9000
const SNOW_AMOUNT: int = 5000

var _rain: GPUParticles3D
var _snow: GPUParticles3D


func _ready() -> void:
	_rain = _make_rain()
	_snow = _make_snow()
	add_child(_rain)
	add_child(_snow)


func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position
	var w: WeatherProfile = WeatherManager.current
	# Inside the camper you hear the rain on the roof but it doesn't fall indoors.
	var indoors: bool = GameState.player_mode == GameState.PlayerMode.INTERIOR
	_set_intensity(_rain, 0.0 if indoors else w.rain)
	_set_intensity(_snow, 0.0 if indoors else w.snow)
	var wind_push: float = w.wind * 6.0
	(_rain.process_material as ParticleProcessMaterial).gravity = Vector3(wind_push, -30.0, wind_push * 0.4)
	(_snow.process_material as ParticleProcessMaterial).gravity = Vector3(wind_push * 0.5, -1.2, wind_push * 0.2)


func _set_intensity(p: GPUParticles3D, value: float) -> void:
	p.amount_ratio = value
	p.emitting = value > 0.01


func _make_rain() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 1, 28)
	pm.direction = Vector3.DOWN
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 18.0
	pm.particle_flag_align_y = true
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.78, 0.82, 0.9, 0.22)
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.5
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 0.6
	mat.distance_fade_max_distance = 3.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.006, 0.38, 0.006)
	mesh.material = mat
	return _particles("Rain", pm, mesh, RAIN_AMOUNT, 1.3, Vector3(0, 16, 0))


func _make_snow() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(26, 1, 26)
	pm.direction = Vector3.DOWN
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.2
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.95, 0.97, 1.0, 0.85)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.07, 0.07)
	mesh.material = mat
	return _particles("Snow", pm, mesh, SNOW_AMOUNT, 9.0, Vector3(0, 12, 0))


func _particles(label: String, pm: ParticleProcessMaterial, mesh: Mesh, amount: int, life: float, offset: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = label
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.position = offset
	p.local_coords = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-32, -40, -32), Vector3(64, 50, 64))
	return p
