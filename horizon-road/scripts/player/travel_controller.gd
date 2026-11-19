class_name TravelController
extends Node
## Switches control between the camper and the traveller on foot, and hands
## the camera to whichever is active. Also owns mouse capture.

const ENTER_DISTANCE: float = 4.0

@export var camper_path: NodePath
@export var walker_path: NodePath
@export var camera_path: NodePath
@export var interior_path: NodePath
@export var rest_menu_path: NodePath
@export var map_path: NodePath
@export var journal_path: NodePath

var camper: CamperController
var walker: WalkerController
var follow_camera: FollowCamera
var interior: CamperInterior
var _side_door := Interactable.new()


func _ready() -> void:
	add_to_group(&"save_participant")
	add_to_group(&"travel")
	camper = get_node(camper_path)
	walker = get_node(walker_path)
	follow_camera = get_node(camera_path)
	interior = get_node_or_null(interior_path)
	_set_walker_present(false)
	# The camper's sliding side door leads into the living space.
	_side_door.prompt_key = "UI_ENTER_CAMPER"
	_side_door.distance = 2.2
	_side_door.position = Vector3(1.2, 1.0, 0.4)
	_side_door.interacted.connect(func(_by: Node3D) -> void: enter_interior())
	camper.add_child(_side_door)
	if interior:
		interior.exit_requested.connect(exit_interior)
		interior.sleep_requested.connect(func() -> void: (get_node(rest_menu_path) as RestMenu).open())
		interior.map_requested.connect(func() -> void: (get_node(map_path) as MapPanel).open())
		interior.journal_requested.connect(func() -> void: (get_node(journal_path) as Journal).open())
	# Region positions the camper in its own _ready, which runs after ours.
	(owner as Region).region_ready.connect(_enter_vehicle, CONNECT_ONE_SHOT)
	if not DevCli.is_requested():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_gameplay():
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not DevCli.is_requested():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		if GameState.player_mode == GameState.PlayerMode.DRIVING:
			if camper.is_stopped():
				_exit_vehicle()
			return
		var target: Interactable = get_focused_interactable()
		if target:
			target.interacted.emit(walker)
		elif GameState.player_mode == GameState.PlayerMode.ON_FOOT and can_enter_vehicle():
			_enter_vehicle()


func _process(_delta: float) -> void:
	var near_door: bool = GameState.player_mode == GameState.PlayerMode.ON_FOOT and walker.global_position.distance_to(camper.global_transform * Vector3(1.2, 0.0, -0.2)) < 3.0
	camper.door_target = 1.0 if near_door or GameState.player_mode == GameState.PlayerMode.INTERIOR else 0.0
	walker.camera_yaw = follow_camera.yaw


## Re-enables whichever body the player controls (after photo mode / journal).
func restore_control() -> void:
	camper.active = GameState.player_mode == GameState.PlayerMode.DRIVING
	walker.active = GameState.player_mode != GameState.PlayerMode.DRIVING


func suspend_control() -> void:
	camper.active = false
	walker.active = false


## The body the player currently controls.
func get_controlled_body() -> Node3D:
	return camper if GameState.player_mode == GameState.PlayerMode.DRIVING else walker


func enter_interior() -> void:
	if interior == null:
		return
	interior.open_at(camper)
	camper.get_node(^"Visual").visible = false
	camper.get_node(^"Collision").disabled = true
	_side_door.enabled = false
	walker.global_position = interior.get_spawn_global()
	walker.velocity = Vector3.ZERO
	walker.get_node(^"Visual").visible = false
	follow_camera.set_target(walker, false)
	follow_camera.set_first_person(true)
	# Look towards the front of the van: dinette, map table and windscreen.
	follow_camera.yaw = camper.global_rotation.y
	GameState.player_mode = GameState.PlayerMode.INTERIOR


func exit_interior() -> void:
	interior.close()
	camper.get_node(^"Visual").visible = true
	camper.get_node(^"Collision").disabled = false
	_side_door.enabled = true
	var pos: Vector3 = camper.global_transform * Vector3(2.0, 0.0, 0.4)
	var region: Region = GameState.current_region
	if region:
		pos.y = region.get_ground_height(pos.x, pos.z) + 0.1
	walker.global_position = pos
	walker.velocity = Vector3.ZERO
	walker.get_node(^"Visual").visible = true
	follow_camera.set_first_person(false)
	follow_camera.yaw = camper.global_rotation.y - PI * 0.5
	GameState.player_mode = GameState.PlayerMode.ON_FOOT


# --- Save --------------------------------------------------------------------

func save_key() -> String:
	return "travel"


func to_save() -> Dictionary:
	return {"camper": camper.to_save()}


## Loading always resumes behind the wheel, wherever the camper was parked.
func from_save(data: Dictionary) -> void:
	if GameState.player_mode == GameState.PlayerMode.INTERIOR:
		exit_interior()
	camper.from_save(data.get("camper", {}))
	_enter_vehicle()


## Nearest usable Interactable around the walker (on foot only), or null.
func get_focused_interactable() -> Interactable:
	if GameState.player_mode == GameState.PlayerMode.DRIVING:
		return null
	var best: Interactable = null
	var best_d: float = INF
	var from: Vector3 = walker.global_position + Vector3(0, 0.9, 0)
	for node: Node in get_tree().get_nodes_in_group(&"interactable"):
		var it := node as Interactable
		if it and it.can_interact(from):
			var d: float = from.distance_to(it.global_position)
			if d < best_d:
				best_d = d
				best = it
	return best


func can_enter_vehicle() -> bool:
	return walker.global_position.distance_to(camper.global_position) < ENTER_DISTANCE


func _exit_vehicle() -> void:
	# Step out on the driver's (left) side, onto the ground.
	var side: Vector3 = -camper.global_basis.x * 1.9 + camper.global_basis.z * 0.9
	var pos: Vector3 = camper.global_position + side
	var region: Region = GameState.current_region
	if region:
		pos.y = region.get_ground_height(pos.x, pos.z) + 0.1
	walker.global_position = pos
	walker.velocity = Vector3.ZERO
	_set_walker_present(true)
	camper.active = false
	follow_camera.set_target(walker, false)
	follow_camera.yaw = camper.global_rotation.y
	GameState.player_mode = GameState.PlayerMode.ON_FOOT


func _enter_vehicle() -> void:
	_set_walker_present(false)
	follow_camera.set_first_person(false)
	camper.active = true
	follow_camera.set_target(camper, true)
	GameState.player_mode = GameState.PlayerMode.DRIVING


func _set_walker_present(present: bool) -> void:
	walker.visible = present
	walker.active = present
	walker.process_mode = Node.PROCESS_MODE_INHERIT if present else Node.PROCESS_MODE_DISABLED
