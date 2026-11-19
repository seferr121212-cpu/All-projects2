class_name GrazingHerd
extends Node3D
## A few cows wandering slowly around a pasture: walk, stop, graze, moo.
## Each cow carries a PhotoSubject so it can be photographed.

@export var cow_count: int = 5
@export var pasture_radius: float = 35.0
@export var walk_speed: float = 0.55
@export var herd_seed: int = 3
## "cow" (highland pasture) or "cat" (harbour).
@export var animal: String = "cow"

var _cows: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _moo_streams: Array[AudioStreamWAV] = []


func _ready() -> void:
	_rng.seed = herd_seed
	var coats: Array[Color] = [Color(0.45, 0.3, 0.2), Color(0.55, 0.4, 0.28), Color(0.35, 0.24, 0.17), Color(0.62, 0.5, 0.38)]
	if animal == "cat":
		coats = [Color(0.9, 0.55, 0.25), Color(0.55, 0.55, 0.55), Color(0.15, 0.15, 0.15), Color(0.95, 0.92, 0.88)]
	for i: int in 2:
		_moo_streams.append(ProceduralAudio.moo(30 + i))
	for i: int in cow_count:
		var cow := Node3D.new()
		cow.name = "Cow%d" % i
		var mesh := MeshInstance3D.new()
		mesh.mesh = LowPolyMeshes.cat(i, coats[i % coats.size()]) if animal == "cat" else LowPolyMeshes.cow(i, coats[i % coats.size()])
		cow.add_child(mesh)
		var subject := PhotoSubject.new()
		subject.subject_id = &"SUBJ_CAT" if animal == "cat" else &"SUBJ_COW"
		subject.name_key = String(subject.subject_id)
		subject.category = PhotoSubject.Category.ANIMAL
		subject.radius = 0.35 if animal == "cat" else 1.0
		subject.value = 0.85
		subject.position = Vector3(0, 0.3 if animal == "cat" else 1.0, 0)
		cow.add_child(subject)
		var voice := AudioStreamPlayer3D.new()
		voice.bus = AudioManager.BUS_AMBIENCE
		voice.unit_size = 14.0
		voice.position = Vector3(0, 1.2, -1.0)
		cow.add_child(voice)
		add_child(cow)
		var start := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * pasture_radius * 0.6
		_cows.append({"node": cow, "pos": start, "target": start, "wait": _rng.randf_range(0.0, 6.0),
			"heading": _rng.randf() * TAU, "voice": voice, "moo_in": _rng.randf_range(8.0, 40.0), "mesh": mesh})


## A wander target on dry land within the pasture.
func _pick_target(region: Region) -> Vector2:
	for attempt: int in 8:
		var t := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * pasture_radius
		var w: Vector3 = global_position + Vector3(t.x, 0.0, t.y)
		if not region.terrain.is_water(w.x, w.z):
			return t
	return Vector2.ZERO


func _process(delta: float) -> void:
	var region: Region = GameState.current_region
	if region == null:
		return
	for c: Dictionary in _cows:
		var pos: Vector2 = c.pos
		if c.wait > 0.0:
			c.wait -= delta
			# Grazing: head-down nod.
			(c.mesh as Node3D).rotation.x = lerpf((c.mesh as Node3D).rotation.x, -0.08 + sin(Time.get_ticks_msec() * 0.002 + pos.x) * 0.03, 2.0 * delta)
			if c.wait <= 0.0:
				c.target = _pick_target(region)
		else:
			var to: Vector2 = (c.target as Vector2) - pos
			if to.length() < 0.5:
				c.wait = _rng.randf_range(4.0, 14.0)
			else:
				var desired: float = atan2(-to.x, -to.y)
				c.heading = lerp_angle(c.heading, desired, 1.5 * delta)
				pos += Vector2(-sin(c.heading), -cos(c.heading)) * walk_speed * delta
				c.pos = pos
				(c.mesh as Node3D).rotation.x = lerpf((c.mesh as Node3D).rotation.x, 0.0, 3.0 * delta)
		var world := global_position + Vector3(pos.x, 0.0, pos.y)
		var node := c.node as Node3D
		node.global_position = Vector3(world.x, region.get_ground_height(world.x, world.z) - 0.05, world.z)
		node.rotation.y = c.heading
		c.moo_in -= delta
		if c.moo_in <= 0.0 and animal == "cow":
			c.moo_in = _rng.randf_range(25.0, 70.0)
			var voice := c.voice as AudioStreamPlayer3D
			voice.stream = _moo_streams[_rng.randi() % _moo_streams.size()]
			voice.pitch_scale = _rng.randf_range(0.85, 1.1)
			voice.play()
