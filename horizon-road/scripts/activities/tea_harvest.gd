class_name TeaHarvestActivity
extends Activity
## Tea picking for Fadime: fresh light-green shoots appear on bushes in the
## tea rows; walk up and pick them with [E]. A few golden shoots pay extra.
## No timer, no failure: hand over whatever you have whenever you like.

static var ECONOMY: EconomyConfig = load("res://data/economy/economy_config.tres")

@export var vegetation_path: NodePath
@export var npc_id: StringName = &"fadime"
@export var shoot_count: int = 22
@export var golden_count: int = 3

var picked: int = 0
var golden_picked: int = 0
var _shoots: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _rustle: AudioStreamPlayer3D
var _plain_mesh: Mesh
var _golden_mesh: Mesh


func _ready() -> void:
	super._ready()
	activity_id = &"tea_harvest"
	_rng.randomize()
	_plain_mesh = LowPolyMeshes.tea_shoot(false)
	_golden_mesh = LowPolyMeshes.tea_shoot(true)
	_rustle = AudioStreamPlayer3D.new()
	_rustle.stream = ProceduralAudio.rustle()
	_rustle.bus = AudioManager.BUS_SFX
	add_child(_rustle)


func begin() -> void:
	if active:
		return
	super.begin()
	picked = 0
	golden_picked = 0
	GameState.set_flag("%s.harvesting" % npc_id)
	GameState.set_flag("%s.harvest_full" % npc_id, false)
	_spawn_shoots()
	GameState.notify(tr(&"ACT_TEA_STARTED"))


func complete() -> int:
	var full: bool = picked >= ECONOMY.tea_target_bunches
	var pay: int = picked * ECONOMY.tea_pay_per_bunch + golden_picked * ECONOMY.tea_golden_bonus
	if full:
		pay += ECONOMY.tea_completion_bonus
	if pay > 0:
		GameState.add_money(pay)
	if picked > 0:
		GameState.add_relationship(npc_id, ECONOMY.points_job_done if full else ECONOMY.points_job_done / 2)
		GameState.set_counter("%s.harvests" % npc_id, GameState.get_counter("%s.harvests" % npc_id) + 1)
	GameState.set_flag("%s.harvesting" % npc_id, false)
	GameState.set_flag("%s.harvest_full" % npc_id, false)
	_clear_shoots()
	active = false
	finished.emit(pay)
	return pay


func get_status_text() -> String:
	if not active:
		return ""
	if picked >= ECONOMY.tea_target_bunches:
		return tr(&"ACT_TEA_FULL")
	return tr(&"ACT_TEA_PROGRESS") % [picked, ECONOMY.tea_target_bunches]


func pick(shoot: Node3D) -> void:
	if not active or not is_instance_valid(shoot):
		return
	var golden: bool = shoot.get_meta(&"golden", false)
	picked += 1
	if golden:
		golden_picked += 1
		GameState.notify(tr(&"ACT_TEA_GOLDEN"))
	_rustle.global_position = shoot.global_position
	_rustle.pitch_scale = _rng.randf_range(0.9, 1.15)
	_rustle.play()
	_burst(shoot.global_position, golden)
	_shoots.erase(shoot)
	shoot.queue_free()
	if picked == ECONOMY.tea_target_bunches:
		GameState.set_flag("%s.harvest_full" % npc_id)
		GameState.notify(tr(&"ACT_TEA_FULL"))
	if _shoots.is_empty() and active:
		# Endless but calm: new shoots sprout if the player keeps going.
		_spawn_shoots()


func _process(_delta: float) -> void:
	# Gentle bob so shoots catch the eye among the dark rows.
	var t: float = Time.get_ticks_msec() * 0.003
	for s: Node3D in _shoots:
		s.get_child(0).position.y = 0.08 + sin(t + s.position.x) * 0.04


func _spawn_shoots() -> void:
	var vegetation := get_node(vegetation_path) as VegetationScatter
	var spots: PackedVector3Array = vegetation.tea_positions
	if spots.is_empty():
		push_warning("No tea bushes to harvest")
		return
	var used: Dictionary = {}
	for i: int in shoot_count:
		var idx: int = _rng.randi() % spots.size()
		var tries: int = 0
		while used.has(idx) and tries < 20:
			idx = _rng.randi() % spots.size()
			tries += 1
		used[idx] = true
		var golden: bool = i < golden_count
		var shoot := Node3D.new()
		shoot.set_meta(&"golden", golden)
		var mi := MeshInstance3D.new()
		mi.mesh = _golden_mesh if golden else _plain_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3.ONE * 1.8
		shoot.add_child(mi)
		shoot.add_child(_make_glint(golden))
		var interact := Interactable.new()
		interact.prompt_key = "ACT_PICK_TEA"
		interact.distance = 1.9
		interact.interacted.connect(func(_by: Node3D) -> void: pick(shoot))
		shoot.add_child(interact)
		add_child(shoot)
		shoot.global_position = spots[idx]
		_shoots.append(shoot)


## A few motes drifting up from each shoot so they can be spotted across the rows.
func _make_glint(golden: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 4
	p.lifetime = 1.6
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.5
	p.gravity = Vector3.ZERO
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.3, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.35, 0.9) if golden else Color(0.8, 1.0, 0.55, 0.85)
	mesh.material = mat
	p.mesh = mesh
	p.position = Vector3(0, 0.2, 0)
	return p


func _clear_shoots() -> void:
	for s: Node3D in _shoots:
		s.queue_free()
	_shoots.clear()


func _burst(at: Vector3, golden: bool) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.8
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -4.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.06, 0.04)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.95, 0.8, 0.3) if golden else Color(0.5, 0.8, 0.3)
	mesh.material = mat
	p.mesh = mesh
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
