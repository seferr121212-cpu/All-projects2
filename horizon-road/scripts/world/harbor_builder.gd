class_name HarborBuilder
extends Node3D
## Little fishing harbour: stone pier into the bay, moored boats bobbing on
## the swell, a boat pulled up on the sand, nets, café tables and a lamp.

@export var pier_length: float = 46.0
@export var pier_width: float = 4.0
## x, z, yaw degrees for moored boats (local to this node, sea is +Z).
@export var boat_spots: Array[Vector3] = [Vector3(-4.5, 18, 8), Vector3(4.6, 26, -6), Vector3(-4.8, 34, 4), Vector3(5.0, 40, 12)]

var _boats: Array[Node3D] = []
var _rest_y: Array[float] = []


func _ready() -> void:
	var pier := MeshInstance3D.new()
	pier.mesh = LowPolyMeshes.pier(pier_length, pier_width)
	pier.rotation.y = PI
	pier.position.y = 0.6
	add_child(pier)
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(pier_width, 2.0, pier_length)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.0, pier_length * 0.5)
	body.add_child(col)
	add_child(body)
	var hulls: Array[Color] = [Color(0.2, 0.45, 0.75), Color(0.8, 0.25, 0.2), Color(0.25, 0.6, 0.45), Color(0.95, 0.75, 0.25)]
	for i: int in boat_spots.size():
		var spot: Vector3 = boat_spots[i]
		var boat := MeshInstance3D.new()
		boat.mesh = LowPolyMeshes.boat(200 + i, hulls[i % hulls.size()])
		boat.position = Vector3(spot.x, -0.25, spot.y)
		boat.rotation.y = deg_to_rad(spot.z)
		add_child(boat)
		_boats.append(boat)
		_rest_y.append(boat.position.y)
	# A boat hauled up on the sand and nets drying beside it.
	var beached := MeshInstance3D.new()
	beached.mesh = LowPolyMeshes.boat(250, Color(0.85, 0.85, 0.82))
	beached.position = Vector3(-14, 0.15, -6)
	beached.rotation = Vector3(0.0, deg_to_rad(70), deg_to_rad(8))
	add_child(beached)
	for p: Vector3 in [Vector3(-9, 0.3, -9), Vector3(6, 1.0, 4), Vector3(-1.2, 1.0, 30)]:
		var nets := MeshInstance3D.new()
		nets.mesh = LowPolyMeshes.net_pile()
		nets.position = p
		add_child(nets)
	# Harbour lamp at the pier head, lit at night.
	var post := MeshInstance3D.new()
	post.mesh = LowPolyMeshes.Builder.new(260).add(LowPolyMeshes._box(Vector3(0.15, 3.2, 0.15)), Transform3D(Basis(), Vector3(0, 1.6, 0)), Color(0.2, 0.2, 0.22)) \
			.add(LowPolyMeshes._box(Vector3(0.4, 0.4, 0.4)), Transform3D(Basis(), Vector3(0, 3.3, 0)), Color(1.0, 0.9, 0.6)).commit(LowPolyMeshes.vertex_color_material(0.4))
	post.position = Vector3(pier_width * 0.5 - 0.4, 1.0, pier_length - 1.0)
	add_child(post)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.75, 0.45)
	lamp.omni_range = 12.0
	lamp.position = post.position + Vector3(0, 3.3, 0)
	lamp.set_meta(&"night_light", true)
	add_child(lamp)
	var subject := PhotoSubject.new()
	subject.subject_id = &"SUBJ_HARBOR"
	subject.name_key = "SUBJ_HARBOR"
	subject.category = PhotoSubject.Category.STRUCTURE
	subject.radius = 18.0
	subject.value = 0.8
	subject.position = Vector3(0, 2.0, pier_length * 0.5)
	add_child(subject)
	var boats_subject := PhotoSubject.new()
	boats_subject.subject_id = &"SUBJ_FISHING_BOATS"
	boats_subject.name_key = "SUBJ_FISHING_BOATS"
	boats_subject.category = PhotoSubject.Category.STRUCTURE
	boats_subject.radius = 6.0
	boats_subject.value = 0.85
	boats_subject.position = Vector3(0, 1.0, 28)
	add_child(boats_subject)
	_snap.call_deferred()


func _snap() -> void:
	# The pier sits at sea level, not on the slope.
	global_position.y = GameState.current_region.terrain.water_level if GameState.current_region else 0.0


func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() * 0.001
	var swell: float = 0.5 + WeatherManager.current.wind
	for i: int in _boats.size():
		var b: Node3D = _boats[i]
		b.position.y = _rest_y[i] + sin(t * 1.1 + i * 1.7) * 0.08 * swell
		b.rotation.z = sin(t * 0.9 + i) * 0.04 * swell
		b.rotation.x = sin(t * 0.7 + i * 2.0) * 0.025 * swell
	var night: float = TimeManager.get_night_factor()
	for c: Node in get_children():
		if c is OmniLight3D and c.has_meta(&"night_light"):
			(c as OmniLight3D).light_energy = night * 2.0
			(c as OmniLight3D).visible = night > 0.05
