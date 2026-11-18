class_name VillageBuilder
extends Node3D
## Places a small cluster of highland houses (yayla evleri) and hay stacks at
## hand-picked spots, snapped to the terrain. Windows glow at night through
## the `night_lights` shader global; a few houses also get a warm porch light.

const WINDOW_SHADER: Shader = preload("res://assets/shaders/window.gdshader")

@export var terrain_path: NodePath
## x, z, rotation (degrees)
@export var house_spots: Array[Vector3] = [
	Vector3(-118, -88, 35), Vector3(-100, -104, 50), Vector3(-128, -112, 20),
	Vector3(-108, -72, 65), Vector3(-86, -96, 10), Vector3(-160, -40, 80),
]
@export var hay_spots: Array[Vector2] = [
	Vector2(-92, -80), Vector2(-96, -78), Vector2(-120, -128), Vector2(-150, -55),
]

var _porch_lights: Array[OmniLight3D] = []


func _ready() -> void:
	var terrain := get_node(terrain_path) as HighlandTerrain
	var window_mat := ShaderMaterial.new()
	window_mat.shader = WINDOW_SHADER
	var woods: Array[Color] = [Color(0.55, 0.38, 0.24), Color(0.48, 0.32, 0.2), Color(0.62, 0.45, 0.3)]
	var roofs: Array[Color] = [Color(0.55, 0.2, 0.17), Color(0.36, 0.4, 0.44), Color(0.3, 0.42, 0.36)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i: int in house_spots.size():
		var spot: Vector3 = house_spots[i]
		var meshes: Dictionary = LowPolyMeshes.yayla_house(i, woods[i % woods.size()], roofs[i % roofs.size()])
		var house := StaticBody3D.new()
		house.name = "House%d" % i
		add_child(house)
		# Sit on the lowest corner so the stone base never floats.
		var lowest: float = INF
		for corner: Vector2 in [Vector2(-3, -4), Vector2(3, -4), Vector2(-3, 4), Vector2(3, 4)]:
			var c: Vector2 = corner.rotated(-deg_to_rad(spot.z))
			lowest = minf(lowest, terrain.height_at(spot.x + c.x, spot.y + c.y))
		house.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(spot.z)), Vector3(spot.x, lowest - 0.6, spot.y))
		var body := MeshInstance3D.new()
		body.mesh = meshes["body"]
		house.add_child(body)
		var windows := MeshInstance3D.new()
		windows.mesh = meshes["windows"]
		windows.material_override = window_mat
		windows.set_instance_shader_parameter(&"lit", 1.0 if rng.randf() < 0.75 else 0.0)
		house.add_child(windows)
		var shape := BoxShape3D.new()
		shape.size = Vector3(6.4, 5.5, 7.9)
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position = Vector3(0, 2.6, 0)
		house.add_child(col)
		if i % 2 == 0:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.72, 0.42)
			lamp.omni_range = 9.0
			lamp.light_energy = 0.0
			lamp.shadow_enabled = false
			lamp.position = Vector3(1.4, 2.6, 4.6)
			house.add_child(lamp)
			_porch_lights.append(lamp)
	var hay: Mesh = LowPolyMeshes.hay_stack()
	for p: Vector2 in hay_spots:
		var mi := MeshInstance3D.new()
		mi.mesh = hay
		add_child(mi)
		mi.global_position = Vector3(p.x, terrain.height_at(p.x, p.y) - 0.2, p.y)
		mi.rotation.y = rng.randf() * TAU


func _process(_delta: float) -> void:
	var night: float = TimeManager.get_night_factor()
	for lamp: OmniLight3D in _porch_lights:
		lamp.light_energy = night * 1.6
		lamp.visible = night > 0.01
