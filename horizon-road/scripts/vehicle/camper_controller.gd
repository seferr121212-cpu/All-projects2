class_name CamperController
extends CharacterBody3D
## Arcade camper van on CharacterBody3D: predictable, can't flip, forgiving
## on slopes. The collider stays upright while the visual body tilts to the
## ground and leans with steering/braking, which sells weight without physics
## chaos.

signal headlights_toggled(on: bool)

## Per-surface handling: max speed multiplier, acceleration multiplier, grip.
const SURFACE_HANDLING: Dictionary = {
	HighlandTerrain.Surface.ROAD: Vector3(1.0, 1.0, 1.0),
	HighlandTerrain.Surface.GRASS: Vector3(0.72, 0.8, 0.82),
	HighlandTerrain.Surface.MUD: Vector3(0.5, 0.55, 0.55),
	HighlandTerrain.Surface.ROCK: Vector3(0.6, 0.7, 0.75),
	HighlandTerrain.Surface.SNOW: Vector3(0.55, 0.6, 0.5),
	HighlandTerrain.Surface.SAND: Vector3(0.6, 0.65, 0.7),
}
const GRAVITY: float = 22.0
const WHEEL_RADIUS: float = 0.42

@export var max_speed: float = 21.0
@export var max_reverse_speed: float = 6.0
@export var acceleration: float = 5.5
@export var brake_deceleration: float = 13.0
@export var coast_deceleration: float = 2.2
@export var steer_rate: float = 1.35
@export var visual_tilt_speed: float = 6.0

var speed: float = 0.0
var steer_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0
var handbrake: bool = false
var active: bool = true
var surface: HighlandTerrain.Surface = HighlandTerrain.Surface.ROAD
var headlights_on: bool = false
var headlights_manual: bool = false

@onready var _visual: Node3D = $Visual
@onready var _engine_audio: AudioStreamPlayer3D = $EngineAudio
@onready var _headlights: Array[SpotLight3D] = [$Visual/HeadlightL, $Visual/HeadlightR]
var _lens_material := StandardMaterial3D.new()
var _wheels: Array[Node3D] = []
## 0 closed .. 1 open; the travel controller sets the target when someone is at the door.
var door_target: float = 0.0
var _door_amount: float = 0.0
var _door: MeshInstance3D
var _body_mesh: MeshInstance3D
var _front_wheels: Array[Node3D] = []
var _lean := Vector2.ZERO


func _ready() -> void:
	floor_max_angle = deg_to_rad(42.0)
	floor_snap_length = 1.2
	floor_stop_on_slope = true
	_build_visual()
	_engine_audio.stream = ProceduralAudio.engine()
	_engine_audio.play()
	_set_headlights(false)


func _exit_tree() -> void:
	_engine_audio.stop()
	_engine_audio.stream = null


func _physics_process(delta: float) -> void:
	_read_input()
	_update_surface()
	var handling: Vector3 = _effective_handling()
	_update_speed(delta, handling)
	_update_steering(delta)

	var forward: Vector3 = -global_basis.z
	var desired: Vector3 = forward * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	# Low grip = the van's actual motion lags its heading (gentle mud slide).
	var grip: float = handling.z * (0.35 if handbrake else 1.0)
	horizontal = horizontal.lerp(desired, 1.0 - exp(-grip * 9.0 * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	velocity.y -= GRAVITY * delta
	move_and_slide()

	# After hitting something, trust the real motion instead of the wish.
	if get_slide_collision_count() > 0 and is_on_wall():
		speed = clampf(velocity.dot(forward), -max_reverse_speed, max_speed)
	_update_visual(delta)
	_update_audio()
	_update_headlights()
	_consume_fuel(delta)


func to_save() -> Dictionary:
	var t: Transform3D = global_transform
	return {"pos": [t.origin.x, t.origin.y, t.origin.z], "yaw": global_rotation.y}


func from_save(data: Dictionary) -> void:
	if not data.has("pos"):
		return
	var p: Array = data.pos
	global_transform = Transform3D(Basis(Vector3.UP, float(data.get("yaw", 0.0))), Vector3(p[0], p[1] + 0.3, p[2]))
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	speed = 0.0


func get_speed_kmh() -> float:
	return absf(speed) * 3.6


func is_stopped() -> bool:
	return absf(speed) < 1.0


func _read_input() -> void:
	if not active:
		throttle_input = 0.0
		brake_input = 0.0
		steer_input = 0.0
		handbrake = true
		return
	throttle_input = Input.get_action_strength(&"accelerate")
	brake_input = Input.get_action_strength(&"brake_reverse")
	steer_input = Input.get_axis(&"steer_right", &"steer_left")
	handbrake = Input.is_action_pressed(&"handbrake")
	if Input.is_action_just_pressed(&"headlights"):
		headlights_manual = true
		_set_headlights(not headlights_on)


func _update_surface() -> void:
	var region: Region = GameState.current_region
	if region:
		surface = region.get_surface_at(global_position)


## Surface handling with upgrades applied; an empty tank only slows the van.
func _effective_handling() -> Vector3:
	var h: Vector3 = SURFACE_HANDLING.get(surface, Vector3.ONE)
	if surface != HighlandTerrain.Surface.ROAD:
		h.x = minf(h.x + GameState.upgrade_effect("tyres", "offroad_speed", 0.0), 1.0)
		h.z = minf(h.z + GameState.upgrade_effect("tyres", "offroad_grip", 0.0), 1.0)
	h.x *= GameState.upgrade_effect("engine", "speed_mult", 1.0)
	h.y *= GameState.upgrade_effect("engine", "accel_mult", 1.0)
	if GameState.fuel <= 0.0:
		h.x *= GameState.ECONOMY.empty_tank_speed
	return h


func _consume_fuel(delta: float) -> void:
	if not active or absf(speed) < 0.3:
		return
	var km: float = absf(speed) * delta / 1000.0
	var load: float = 0.4 + 0.6 * throttle_input
	GameState.use_fuel(km * GameState.ECONOMY.fuel_per_km * load * GameState.upgrade_effect("engine", "fuel_use_mult", 1.0))


func _update_speed(delta: float, handling: Vector3) -> void:
	var top: float = max_speed * handling.x
	var accel: float = acceleration * handling.y
	if handbrake:
		speed = move_toward(speed, 0.0, brake_deceleration * 1.2 * delta)
	elif throttle_input > 0.05:
		if speed < -0.5:
			speed = move_toward(speed, 0.0, brake_deceleration * delta)
		else:
			# Acceleration tapers near top speed like a heavy van.
			var taper: float = 1.0 - clampf(speed / top, 0.0, 1.0) * 0.7
			speed = move_toward(speed, top * throttle_input, accel * taper * delta)
	elif brake_input > 0.05:
		if speed > 0.5:
			speed = move_toward(speed, 0.0, brake_deceleration * brake_input * delta)
		else:
			speed = move_toward(speed, -max_reverse_speed, accel * 0.6 * delta)
	else:
		speed = move_toward(speed, 0.0, coast_deceleration * delta)
	if speed > top:
		speed = move_toward(speed, top, coast_deceleration * 2.0 * delta)
	# Hills: slow down going up, roll a little going down.
	if is_on_floor():
		var slope: float = (-global_basis.z).dot(get_floor_normal())
		speed += slope * 5.0 * delta


func _update_steering(delta: float) -> void:
	var speed_factor: float = clampf(absf(speed) / 4.0, 0.0, 1.0)
	var high_speed_damp: float = 1.0 - 0.5 * clampf(absf(speed) / max_speed, 0.0, 1.0)
	var turn: float = steer_input * steer_rate * speed_factor * high_speed_damp * signf(speed)
	rotate_y(turn * delta)


func _update_door(delta: float) -> void:
	_door_amount = move_toward(_door_amount, door_target, delta * 1.6)
	if _door == null:
		return
	_door.visible = _door_amount > 0.02
	var t: float = smoothstep(0.0, 1.0, _door_amount)
	_door.position = Vector3(0.1 * clampf(t * 4.0, 0.0, 1.0), 0.0, 0.95 * smoothstep(0.2, 1.0, t))
	_body_mesh.set_instance_shader_parameter(&"door_open", _door_amount)


func _update_visual(delta: float) -> void:
	_update_door(delta)
	# Tilt body to the ground under the van, then add lean from motion.
	var region: Region = GameState.current_region
	var ground_normal: Vector3 = Vector3.UP
	if region:
		ground_normal = region.terrain.normal_at(global_position.x, global_position.z)
	var local_normal: Vector3 = global_basis.inverse() * ground_normal
	var target_pitch: float = atan2(-local_normal.z, local_normal.y)
	var target_roll: float = atan2(local_normal.x, local_normal.y)
	var accel_lean: float = (throttle_input - brake_input) * 0.025 * clampf(absf(speed) / 3.0, 0.0, 1.0)
	var steer_lean: float = -steer_input * clampf(absf(speed) / max_speed, 0.0, 1.0) * 0.05
	_lean = _lean.lerp(Vector2(target_pitch - accel_lean, -target_roll + steer_lean), 1.0 - exp(-visual_tilt_speed * delta))
	_visual.rotation = Vector3(-_lean.x, 0.0, _lean.y)
	# Small idle shake + road roughness off-road.
	var rough: float = 0.0 if surface == HighlandTerrain.Surface.ROAD else 0.012
	_visual.position.y = sin(Time.get_ticks_msec() * 0.05) * (0.004 + rough * clampf(absf(speed) / 8.0, 0.0, 1.0))

	var spin: float = speed / WHEEL_RADIUS * delta
	for w: Node3D in _wheels:
		w.get_child(0).rotate_x(-spin)
	for w: Node3D in _front_wheels:
		w.rotation.y = lerpf(w.rotation.y, steer_input * 0.45, 1.0 - exp(-10.0 * delta))


func _update_audio() -> void:
	var rev: float = clampf(absf(speed) / max_speed, 0.0, 1.0)
	_engine_audio.pitch_scale = 0.75 + rev * 1.1 + throttle_input * 0.12
	_engine_audio.volume_db = linear_to_db(0.25 + rev * 0.4 + throttle_input * 0.15) - 4.0


func _update_headlights() -> void:
	if headlights_manual:
		return
	var w: WeatherProfile = WeatherManager.current
	var want: bool = TimeManager.get_night_factor() > 0.35 or w.fog_density > 0.006 or w.rain > 0.6
	if want != headlights_on:
		_set_headlights(want)


func _set_headlights(on: bool) -> void:
	headlights_on = on
	var boost: float = GameState.upgrade_effect("lights", "headlight_mult", 1.0)
	for light: SpotLight3D in _headlights:
		light.visible = on
		light.light_energy = 14.0 * boost
		light.spot_range = 42.0 * boost
	_lens_material.emission_energy_multiplier = 4.0 if on else 0.0
	headlights_toggled.emit(on)


func _build_visual() -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = LowPolyMeshes.camper_body()
	_visual.add_child(body)
	for m: Mesh in AssetLibrary.meshes("camper_cabin", []):
		var cabin := MeshInstance3D.new()
		cabin.mesh = m
		cabin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(cabin)
	# Sliding door: a slab of the same paint, the shell cuts its doorway while open.
	var paint: Material = body.mesh.surface_get_material(body.mesh.get_surface_count() - 1)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 1.6, 1.34)
	var arrays: Array = bm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in verts.size():
		verts[i] += Vector3(0.975, 1.275, -0.2)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var door_mesh := ArrayMesh.new()
	door_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	door_mesh.surface_set_material(0, paint)
	_door = MeshInstance3D.new()
	_door.name = "SlidingDoor"
	_door.mesh = door_mesh
	_door.set_instance_shader_parameter(&"is_door", 1.0)
	_door.visible = false
	_visual.add_child(_door)
	_body_mesh = body
	# Glowing lenses so the lights read from outside, not just on the road.
	_lens_material.albedo_color = Color(1.0, 0.97, 0.88)
	_lens_material.emission_enabled = true
	_lens_material.emission = Color(1.0, 0.9, 0.7)
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.13
	lens_mesh.bottom_radius = 0.13
	lens_mesh.height = 0.04
	lens_mesh.radial_segments = 10
	lens_mesh.material = _lens_material
	for x: float in [-0.68, 0.68]:
		var lens := MeshInstance3D.new()
		lens.mesh = lens_mesh
		lens.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 1.05, -2.44))
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(lens)
	var wheel_mesh: Mesh = LowPolyMeshes.wheel()
	for x: float in [-0.88, 0.88]:
		for z: float in [-1.45, 1.5]:
			var pivot := Node3D.new()
			pivot.position = Vector3(x, WHEEL_RADIUS, z)
			var mi := MeshInstance3D.new()
			mi.mesh = wheel_mesh
			pivot.add_child(mi)
			_visual.add_child(pivot)
			_wheels.append(pivot)
			if z < 0.0:
				_front_wheels.append(pivot)
