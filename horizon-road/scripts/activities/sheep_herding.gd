class_name SheepHerdingActivity
extends Activity
## Ferhat's job on the eastern plateau: the flock has spread over the
## pasture. Walk (or drive, slowly) behind the sheep to drive them through
## the gap into the stone pen. They flee from you and drift back together.
## Report back to Ferhat any time; more sheep penned, better pay.

const FLEE_WALK: float = 7.0
const FLEE_CAMPER: float = 13.0

@export var npc_id: StringName = &"ferhat"
@export var pen_offset: Vector3 = Vector3(0, 0, -14)
@export var pen_radius: float = 7.0
@export var sheep_count: int = 10
@export var field_radius: float = 55.0
## The pen gap faces this way (degrees, around Y; 0 = -Z, the pen mesh default).
@export var gap_degrees: float = 70.0

var sheep: Array[Dictionary] = []
var _sheep_mesh: Mesh
var _terrain: HighlandTerrain
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _bleat: AudioStreamPlayer3D


func _ready() -> void:
	super._ready()
	add_to_group(&"save_participant")
	activity_id = &"herding"
	_rng.randomize()
	_sheep_mesh = AnatoliaMeshes.sheep()
	var pen := StaticBody3D.new()
	add_child(pen)
	pen.position = pen_offset
	var mi := MeshInstance3D.new()
	mi.mesh = AnatoliaMeshes.stone_pen(pen_radius, gap_degrees)
	pen.add_child(mi)
	_bleat = AudioStreamPlayer3D.new()
	_bleat.stream = ProceduralAudio.moo()
	_bleat.pitch_scale = 2.4
	_bleat.bus = AudioManager.BUS_SFX
	_bleat.unit_size = 10.0
	add_child(_bleat)


func pen_center() -> Vector3:
	return global_position + pen_offset


func penned_count() -> int:
	var n: int = 0
	for s: Dictionary in sheep:
		if s.penned:
			n += 1
	return n


func begin() -> void:
	if active:
		return
	super.begin()
	_terrain = GameState.current_region.terrain if GameState.current_region else null
	GameState.set_flag("%s.herding" % npc_id)
	GameState.set_flag("%s.herd_done" % npc_id, false)
	_spawn_flock()
	if not SaveManager.is_loading:
		GameState.notify(tr(&"ACT_HERD_STARTED"))


func complete() -> int:
	var n: int = penned_count()
	var pay: int = roundi(float(ECONOMY.herding_pay) * n / maxf(sheep_count, 1))
	if n >= sheep_count:
		pay += ECONOMY.herding_bonus
	if pay > 0:
		GameState.add_money(pay)
		GameState.add_relationship(npc_id, ECONOMY.points_job_done if n >= sheep_count - 2 else ECONOMY.points_job_done / 2)
	GameState.set_counter("%s.herds" % npc_id, GameState.get_counter("%s.herds" % npc_id) + 1)
	_end()
	finished.emit(pay)
	return pay


func cancel() -> void:
	if active:
		_end()


func _end() -> void:
	active = false
	GameState.set_flag("%s.herding" % npc_id, false)
	GameState.set_flag("%s.herd_done" % npc_id, false)
	for s: Dictionary in sheep:
		(s.node as Node3D).queue_free()
	sheep.clear()


func get_status_text() -> String:
	if not active:
		return ""
	return tr(&"ACT_HERD_PROGRESS") % [penned_count(), sheep_count]


func _spawn_flock() -> void:
	for s: Dictionary in sheep:
		(s.node as Node3D).queue_free()
	sheep.clear()
	# Two or three loose groups spread across the pasture.
	var groups: Array[Vector2] = []
	for g: int in 3:
		var a: float = _rng.randf() * TAU
		groups.append(Vector2(cos(a), sin(a)) * _rng.randf_range(field_radius * 0.45, field_radius))
	for i: int in sheep_count:
		var c: Vector2 = groups[i % groups.size()] + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
		var node := Node3D.new()
		var body := CharacterRig.build("sheep", _sheep_mesh, i)
		body.walk_ref_speed = 0.6
		node.add_child(body)
		add_child(node)
		node.global_position = global_position + Vector3(c.x, 0, c.y)
		sheep.append({"node": node, "vel": Vector2.ZERO, "penned": false, "wander": _rng.randf() * TAU})
	_snap_all()


func _snap_all() -> void:
	for s: Dictionary in sheep:
		var n: Node3D = s.node
		n.global_position.y = _ground(n.global_position.x, n.global_position.z)


func _ground(x: float, z: float) -> float:
	return _terrain.height_at(x, z) if _terrain else global_position.y


func _threat() -> Array:
	var travel := get_tree().get_first_node_in_group(&"travel") as TravelController
	if travel == null:
		return []
	if GameState.player_mode == GameState.PlayerMode.DRIVING:
		return [travel.camper.global_position, FLEE_CAMPER]
	if GameState.player_mode == GameState.PlayerMode.ON_FOOT:
		return [travel.walker.global_position, FLEE_WALK]
	return []


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	var threat: Array = _threat()
	var pc: Vector3 = pen_center()
	var pc2 := Vector2(pc.x, pc.z)
	# Flock centre: sheep drift back towards their friends.
	var centre := Vector2.ZERO
	for s: Dictionary in sheep:
		centre += Vector2((s.node as Node3D).global_position.x, (s.node as Node3D).global_position.z)
	centre /= maxf(sheep.size(), 1)
	for s: Dictionary in sheep:
		var node: Node3D = s.node
		var p := Vector2(node.global_position.x, node.global_position.z)
		var vel: Vector2 = s.vel
		var desired := Vector2.ZERO
		if s.penned:
			s.wander = float(s.wander) + _rng.randf_range(-1.0, 1.0) * delta
			desired = Vector2(cos(s.wander), sin(s.wander)) * 0.3 + (pc2 - p) * 0.08
		else:
			s.wander = float(s.wander) + _rng.randf_range(-1.5, 1.5) * delta
			desired = Vector2(cos(s.wander), sin(s.wander)) * 0.35 + (centre - p).limit_length(1.0) * 0.25
			if not threat.is_empty():
				var tp := Vector2((threat[0] as Vector3).x, (threat[0] as Vector3).z)
				var d: float = p.distance_to(tp)
				if d < float(threat[1]):
					desired += (p - tp).normalized() * lerpf(3.4, 1.2, d / float(threat[1]))
		vel = vel.lerp(desired, clampf(delta * 3.0, 0.0, 1.0))
		var next: Vector2 = p + vel * delta
		next = _respect_walls(p, next, pc2, s)
		node.global_position = Vector3(next.x, _ground(next.x, next.y), next.y)
		if vel.length() > 0.15:
			node.rotation.y = lerp_angle(node.rotation.y, atan2(-vel.x, -vel.y), clampf(delta * 6.0, 0.0, 1.0))
		var rig := node.get_child(0) as CharacterRig
		rig.set_motion(vel.length())
		# A little hop while trotting.
		if not rig.is_animated():
			node.position.y += absf(sin(_t * 9.0 + float(s.wander))) * clampf(vel.length() * 0.05, 0.0, 0.12)
		s.vel = vel
		if not s.penned and next.distance_to(pc2) < pen_radius - 1.2:
			s.penned = true
			_bleat.global_position = node.global_position
			_bleat.play()
			if penned_count() >= sheep_count:
				GameState.set_flag("%s.herd_done" % npc_id)
				GameState.notify(tr(&"ACT_HERD_DONE"))


## Sheep only cross the pen wall through the gap; penned sheep stay in.
func _respect_walls(p: Vector2, next: Vector2, pc: Vector2, s: Dictionary) -> Vector2:
	var r_in: float = pen_radius - 0.7
	var r_out: float = pen_radius + 0.7
	var d0: float = p.distance_to(pc)
	var d1: float = next.distance_to(pc)
	var crossing: bool = (d0 >= r_out and d1 < r_out) or (d0 <= r_in and d1 > r_in) or (d1 > r_in and d1 < r_out and d0 > r_in and d0 < r_out)
	if not crossing:
		return next
	var gap_dir := Vector2(0, -1).rotated(-deg_to_rad(rotation_degrees.y))
	var to_next: Vector2 = (next - pc).normalized()
	var in_gap: bool = rad_to_deg(absf(gap_dir.angle_to(to_next))) < gap_degrees * 0.5
	if in_gap and not s.penned:
		return next
	# Slide along the wall.
	var radial: Vector2 = (next - pc).normalized()
	var move: Vector2 = next - p
	return p + (move - radial * move.dot(radial))


func save_key() -> String:
	return "herding"


func to_save() -> Dictionary:
	return {"active": active}


func from_save(data: Dictionary) -> void:
	if active:
		_end()
	if data.get("active", false):
		begin()
