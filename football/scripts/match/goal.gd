extends Node3D
## Kale: direkler ve üst direk (çarpışmalı, sekmeli), file (yumuşak, enerji emen)
## ve topu içeride hızla yavaşlatan file alanı (Area3D).
## Yerel eksen: orijin kale çizgisinin ortası, +X kalenin arkasına doğru.

signal ball_entered_net(side: int)

const PD = preload("res://scripts/match/pitch_dimensions.gd")

## +1: sağ kale (x = +52.5), -1: sol kale (x = -52.5)
@export var side := 1
@export var net_damping := 6.0
@export var frame_color := Color(0.97, 0.97, 0.97)


func _ready() -> void:
	position = Vector3(side * PD.HALF_LENGTH, 0.0, 0.0)
	rotation = Vector3(0.0, 0.0 if side > 0 else PI, 0.0)
	_build_frame()
	_build_net()
	_build_net_area()


func _build_frame() -> void:
	var r := PD.POST_RADIUS
	var body := StaticBody3D.new()
	body.name = "Frame"
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.2 # top malzemesiyle toplanır -> direkten belirgin sekme
	pm.friction = 0.3
	body.physics_material_override = pm
	add_child(body)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = frame_color
	var post_h := PD.GOAL_HEIGHT + 2.0 * r
	var z_post := PD.GOAL_WIDTH * 0.5 + r
	for zs in [-1.0, 1.0]:
		_add_cylinder(body, mat, Vector3(-r, post_h * 0.5, zs * z_post), post_h, Vector3.ZERO)
	var bar_len := PD.GOAL_WIDTH + 4.0 * r
	_add_cylinder(body, mat, Vector3(-r, PD.GOAL_HEIGHT + r, 0.0), bar_len, Vector3(PI * 0.5, 0.0, 0.0))


func _add_cylinder(body: StaticBody3D, mat: Material, pos: Vector3, h: float, rot: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = PD.POST_RADIUS
	shape.height = h
	cs.shape = shape
	cs.position = pos
	cs.rotation = rot
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = PD.POST_RADIUS
	mesh.bottom_radius = PD.POST_RADIUS
	mesh.height = h
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	body.add_child(mi)


func _build_net() -> void:
	var body := StaticBody3D.new()
	body.name = "Net"
	var pm := PhysicsMaterial.new()
	pm.absorbent = true # sekmeyi azaltır
	pm.bounce = 0.5
	pm.friction = 1.0
	body.physics_material_override = pm
	add_child(body)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var t := 0.1
	var d := PD.GOAL_DEPTH
	var h := PD.GOAL_HEIGHT
	var w := PD.GOAL_WIDTH + 4.0 * PD.POST_RADIUS
	_add_box(body, mat, Vector3(d + t * 0.5, h * 0.5, 0.0), Vector3(t, h, w)) # arka
	_add_box(body, mat, Vector3(d * 0.5 + 0.06, h + t * 0.5, 0.0), Vector3(d, t, w)) # tavan
	for zs in [-1.0, 1.0]:
		_add_box(body, mat, Vector3(d * 0.5, h * 0.5, zs * (w * 0.5 + t * 0.5)), Vector3(d, h, t)) # yanlar


func _add_box(body: StaticBody3D, mat: Material, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)


func _build_net_area() -> void:
	var area := Area3D.new()
	area.name = "NetArea"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var start := PD.BALL_RADIUS
	box.size = Vector3(PD.GOAL_DEPTH - start, PD.GOAL_HEIGHT, PD.GOAL_WIDTH)
	cs.shape = box
	cs.position = Vector3(start + box.size.x * 0.5, PD.GOAL_HEIGHT * 0.5, 0.0)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_in_net"):
		body.set_in_net(true, net_damping)
		ball_entered_net.emit(side)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("set_in_net"):
		body.set_in_net(false, net_damping)
