class_name BalloonFlight
extends Node3D
## Dawn hot-air balloons over Kapadokya. They inflate on the launch field
## around sunrise, rise and drift with the wind, then land mid-morning.
## Grounded in rain, storms and strong wind.

const PALETTES: Array = [
	[Color(0.85, 0.2, 0.18), Color(0.98, 0.85, 0.3)], [Color(0.2, 0.45, 0.8), Color(0.95, 0.95, 0.9)],
	[Color(0.9, 0.5, 0.15), Color(0.6, 0.15, 0.35)], [Color(0.25, 0.6, 0.4), Color(0.95, 0.85, 0.5)],
	[Color(0.95, 0.75, 0.2), Color(0.85, 0.3, 0.25), Color(0.2, 0.35, 0.65)], [Color(0.55, 0.25, 0.6), Color(0.95, 0.6, 0.65)],
]

@export var terrain_path: NodePath
@export var launch_center: Vector2 = Vector2(100, -10)
@export var count: int = 16
@export var launch_hour: float = 5.4
@export var land_hour: float = 9.6

var _balloons: Array[Dictionary] = []
var _terrain: HighlandTerrain
var _subject := PhotoSubject.new()
var _flames: Array[OmniLight3D] = []


func _ready() -> void:
	_terrain = get_node(terrain_path) as HighlandTerrain
	var rng := RandomNumberGenerator.new()
	rng.seed = 1923
	for i: int in count:
		var cols: Array[Color] = []
		for c: Color in PALETTES[i % PALETTES.size()]:
			cols.append(c)
		var node := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = AnatoliaMeshes.balloon(600 + i, cols)
		# Keep the envelopes vivid against the hazy dawn sky.
		var mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
		if mat:
			mat.disable_fog = true
			mat.emission_enabled = true
			mat.emission = Color(0.12, 0.08, 0.05)
		mi.scale = Vector3.ONE * 1.3
		node.add_child(mi)
		var flame := OmniLight3D.new()
		flame.light_color = Color(1.0, 0.6, 0.25)
		flame.omni_range = 7.0
		flame.position = Vector3(0, 3.4, 0)
		flame.shadow_enabled = false
		node.add_child(flame)
		_flames.append(flame)
		add_child(node)
		var start := launch_center + Vector2(rng.randf_range(-70, 70), rng.randf_range(-50, 50))
		_balloons.append({
			"node": node, "start": start, "delay": rng.randf_range(0.0, 0.7),
			"ceiling": rng.randf_range(70.0, 190.0), "drift": rng.randf_range(0.7, 1.3),
			"phase": rng.randf() * TAU, "flame": flame,
		})
	_subject.subject_id = &"SUBJ_BALLOONS"
	_subject.name_key = "SUBJ_BALLOONS"
	_subject.category = PhotoSubject.Category.MOMENT
	_subject.radius = 60.0
	_subject.value = 1.0
	add_child(_subject)
	_update()


func _process(_delta: float) -> void:
	_update()


## Flying weather: no rain/snow, light wind.
func can_fly() -> bool:
	var w: WeatherProfile = WeatherManager.current
	return w.rain < 0.2 and w.snow < 0.2 and w.wind < 0.6 and w.fog_density < 0.006


func _update() -> void:
	var hour: float = TimeManager.time_of_day
	var span: float = land_hour - launch_hour
	var flying: bool = can_fly() and hour > launch_hour - 0.3 and hour < land_hour + 0.3
	_subject.visible = flying
	if flying:
		_subject.add_to_group(&"photo_subject")
	elif _subject.is_in_group(&"photo_subject"):
		_subject.remove_from_group(&"photo_subject")
	var wind_dir := Vector2(0.8, -0.6).normalized()
	var centre := Vector3.ZERO
	var shown: int = 0
	var t_now: float = Time.get_ticks_msec() * 0.001
	for b: Dictionary in _balloons:
		var node: Node3D = b.node
		var k: float = (hour - launch_hour - float(b.delay) * 0.6) / span
		node.visible = flying and k > -0.05 and k < 1.05
		if not node.visible:
			continue
		var kc: float = clampf(k, 0.0, 1.0)
		# Rise fast, cruise, then sink to land.
		var alt: float = float(b.ceiling) * smoothstep(0.0, 0.25, kc) * (1.0 - smoothstep(0.8, 1.0, kc))
		alt += sin(t_now * 0.2 + float(b.phase)) * 3.0 * smoothstep(0.1, 0.3, kc)
		var p: Vector2 = Vector2(b.start) + wind_dir * kc * 420.0 * float(b.drift)
		p = p.clamp(Vector2(-330, -330), Vector2(330, 330))
		var ground: float = _terrain.height_at(p.x, p.y)
		# Inflating on the ground: scale the envelope up before lift-off.
		var inflate: float = clampf((k + 0.05) / 0.06, 0.2, 1.0)
		node.global_position = Vector3(p.x, ground + alt, p.y)
		node.scale = Vector3(1.0, inflate, 1.0)
		node.rotation.y = float(b.phase) + t_now * 0.03
		var flame: OmniLight3D = b.flame
		var burn: float = maxf(sin(t_now * 0.9 + float(b.phase) * 3.0), 0.0)
		flame.light_energy = (2.5 + TimeManager.get_night_factor() * 4.0) * pow(burn, 6.0)
		centre += node.global_position + Vector3(0, 8, 0)
		shown += 1
	if shown > 0:
		_subject.global_position = centre / shown
