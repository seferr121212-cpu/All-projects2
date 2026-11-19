class_name AtmosphereController
extends Node
## Owns the WorldEnvironment, sun, moon and sky material. Every frame it
## combines the region palette (time-of-day colours) with the live weather
## blend, so light, sky, fog, clouds and grading always change together.

const SKY_SHADER: Shader = preload("res://assets/shaders/sky.gdshader")

@export var world_environment_path: NodePath
@export var sun_path: NodePath
@export var moon_path: NodePath
@export var palette: RegionPalette
@export var sun_max_energy: float = 2.4
@export var moon_energy: float = 0.32

var environment: Environment
var sky_material := ShaderMaterial.new()
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _flash: float = 0.0
var _next_flash_in: float = 6.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"atmosphere")
	_rng.randomize()
	_sun = get_node(sun_path)
	_moon = get_node(moon_path)
	var world_env := get_node(world_environment_path) as WorldEnvironment
	environment = _create_environment()
	world_env.environment = environment
	_configure_lights()
	_update(0.0)


func _process(delta: float) -> void:
	_update(delta)


## Current lightning flash strength (0..1); photo mode uses it for "moments".
func get_flash() -> float:
	return _flash


func _create_environment() -> Environment:
	var cloud_tex := NoiseTexture2D.new()
	cloud_tex.width = 512
	cloud_tex.height = 512
	cloud_tex.seamless = true
	cloud_tex.generate_mipmaps = true
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.008
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.55
	cloud_tex.noise = noise
	sky_material.shader = SKY_SHADER
	sky_material.set_shader_parameter(&"cloud_noise", cloud_tex)

	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_white = 6.0
	env.tonemap_exposure = 1.0

	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.ssao_light_affect = 0.15

	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.35
	env.fog_height = 4.0
	env.fog_height_density = 0.0015

	env.volumetric_fog_enabled = true
	env.volumetric_fog_anisotropy = 0.65
	env.volumetric_fog_length = 160.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.6
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_enabled = true

	env.adjustment_enabled = true
	return env


func _configure_lights() -> void:
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.directional_shadow_max_distance = 220.0
	_sun.directional_shadow_blend_splits = true
	_sun.shadow_blur = 1.4
	_sun.light_angular_distance = 0.8
	_sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_moon.shadow_enabled = true
	_moon.directional_shadow_max_distance = 120.0
	_moon.light_color = Color(0.62, 0.72, 1.0)
	_moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY


func _update(delta: float) -> void:
	if palette == null:
		return
	var hour: float = TimeManager.time_of_day
	var t: float = hour / 24.0
	var w: WeatherProfile = WeatherManager.current
	var sun_dir: Vector3 = TimeManager.get_sun_direction()
	var night: float = TimeManager.get_night_factor()
	var day: float = 1.0 - night
	var overcast: float = clampf(w.cloud_coverage * 1.1 - 0.15, 0.0, 1.0)

	var sun_col: Color = palette.sun_color.sample(t)
	var zenith: Color = palette.sky_zenith.sample(t)
	var horizon: Color = palette.sky_horizon.sample(t)
	var fog_col: Color = palette.fog_color.sample(t)
	# Overcast skies collapse towards a soft grey of the same brightness.
	var grey_z := Color(zenith.get_luminance(), zenith.get_luminance(), zenith.get_luminance()) * 1.15
	var grey_h := Color(horizon.get_luminance(), horizon.get_luminance(), horizon.get_luminance()) * 0.95
	zenith = zenith.lerp(grey_z * Color(0.92, 0.96, 1.0), overcast * 0.85).darkened(w.cloud_darkness * 0.45)
	horizon = horizon.lerp(grey_h, overcast * 0.7).darkened(w.cloud_darkness * 0.35)
	fog_col = fog_col.lerp(Color(grey_h.r, grey_h.g * 1.02, grey_h.b * 1.05), overcast * 0.6).darkened(w.cloud_darkness * 0.3)
	# Distant land should dissolve into the horizon sky, especially in fog.
	var fogginess: float = clampf(w.fog_density * 90.0, 0.0, 1.0)
	fog_col = fog_col.lerp(horizon, 0.35 + 0.5 * fogginess)

	_update_lightning(delta, w)

	# Sun
	var sun_height: float = sun_dir.y
	var sun_up: float = smoothstep(-0.04, 0.14, sun_height)
	_sun.visible = sun_height > -0.08
	_point_light(_sun, sun_dir)
	_sun.light_color = sun_col
	var low_sun_boost: float = 1.0 + (1.0 - smoothstep(0.05, 0.4, sun_height)) * 0.25
	_sun.light_energy = sun_max_energy * sun_up * lerpf(1.0, w.sun_strength, overcast) * low_sun_boost
	_sun.shadow_opacity = lerpf(1.0, 0.45, overcast)

	# Moon (roughly opposite the sun, tilted south)
	var moon_dir: Vector3 = (-sun_dir + Vector3(0, 0.35, 0.3)).normalized()
	_moon.visible = night > 0.05
	_point_light(_moon, moon_dir)
	_moon.light_energy = moon_energy * night * lerpf(1.0, 0.35, overcast) + _flash * 2.5
	_moon.light_color = Color(0.62, 0.72, 1.0).lerp(Color(0.85, 0.88, 1.0), _flash)

	# Sky
	sky_material.set_shader_parameter(&"zenith_color", zenith)
	sky_material.set_shader_parameter(&"horizon_color", horizon)
	sky_material.set_shader_parameter(&"ground_color", palette.ground_color.lerp(horizon, 0.35) * lerpf(1.0, 0.25, night))
	sky_material.set_shader_parameter(&"sun_direction", sun_dir)
	sky_material.set_shader_parameter(&"sun_color", sun_col)
	sky_material.set_shader_parameter(&"sun_visibility", 1.0 - overcast * 0.85)
	sky_material.set_shader_parameter(&"moon_direction", moon_dir)
	sky_material.set_shader_parameter(&"night", night)
	sky_material.set_shader_parameter(&"cloud_coverage", w.cloud_coverage)
	sky_material.set_shader_parameter(&"cloud_darkness", w.cloud_darkness)
	var daylight: float = maxf(day, 0.06)
	var cloud_lit: Color = Color(1.0, 1.0, 1.0).lerp(sun_col, 0.55 * (1.0 - smoothstep(0.1, 0.45, sun_height))) * daylight
	cloud_lit = cloud_lit.lerp(Color(0.7, 0.72, 0.76) * daylight, overcast * 0.5)
	sky_material.set_shader_parameter(&"cloud_lit_color", cloud_lit)
	sky_material.set_shader_parameter(&"cloud_shadow_color", zenith.lerp(horizon, 0.5).darkened(0.25) * lerpf(1.0, 0.6, w.cloud_darkness))
	sky_material.set_shader_parameter(&"cloud_speed", 0.002 + w.wind * 0.008)
	sky_material.set_shader_parameter(&"lightning_flash", _flash)

	# Ambient & fog
	environment.ambient_light_energy = lerpf(1.0, 3.2, night) * lerpf(1.0, 1.15, overcast)
	environment.ambient_light_sky_contribution = lerpf(1.0, 0.55, night)
	environment.ambient_light_color = palette.night_ambient
	environment.fog_light_color = fog_col
	environment.fog_density = palette.base_fog_density + w.fog_density
	# Thick fog should swallow the sky too, not just the ground.
	environment.fog_sky_affect = clampf(0.3 + w.fog_density * 60.0, 0.0, 1.0)
	environment.fog_sun_scatter = palette.fog_sun_scatter * (1.0 - overcast) * sun_up
	environment.volumetric_fog_density = w.volumetric_fog_density
	# Volumetric fog darkens far terrain; apply it to the sky too in thick fog so they match.
	environment.volumetric_fog_sky_affect = fogginess
	environment.volumetric_fog_albedo = fog_col.lerp(Color.WHITE, 0.5 * day)
	environment.volumetric_fog_emission = palette.night_ambient * 0.004 * night

	# Grading: lush when sunny, muted on grey days, a touch brighter at night for readability.
	environment.adjustment_saturation = palette.saturation * w.saturation * lerpf(1.0, 0.8, night)
	environment.adjustment_contrast = palette.contrast
	environment.tonemap_exposure = lerpf(1.0, 1.35, night) * lerpf(1.0, 1.12, overcast)

	RenderingServer.global_shader_parameter_set(&"night_lights", smoothstep(0.25, 0.8, night))


func _update_lightning(delta: float, w: WeatherProfile) -> void:
	_flash = maxf(_flash - delta * 6.0, 0.0)
	if w.lightning < 0.3:
		return
	_next_flash_in -= delta
	if _next_flash_in <= 0.0:
		_next_flash_in = _rng.randf_range(5.0, 18.0) / w.lightning
		_flash = _rng.randf_range(0.6, 1.0)
		AudioManager.play_thunder(_rng.randf_range(0.6, 3.5))


func _point_light(light: DirectionalLight3D, towards_light: Vector3) -> void:
	# Directional lights shine along their local -Z.
	var forward: Vector3 = -towards_light
	var up: Vector3 = Vector3.UP if absf(forward.y) < 0.99 else Vector3.FORWARD
	light.global_transform.basis = Basis.looking_at(forward, up)
