class_name TravelController
extends Node
## Switches control between the camper and the traveller on foot, and hands
## the camera to whichever is active. Also owns mouse capture.

const ENTER_DISTANCE: float = 4.0

@export var camper_path: NodePath
@export var walker_path: NodePath
@export var camera_path: NodePath

var camper: CamperController
var walker: WalkerController
var follow_camera: FollowCamera


func _ready() -> void:
	camper = get_node(camper_path)
	walker = get_node(walker_path)
	follow_camera = get_node(camera_path)
	_set_walker_present(false)
	# Region positions the camper in its own _ready, which runs after ours.
	(owner as Region).region_ready.connect(_enter_vehicle, CONNECT_ONE_SHOT)
	if not DevCli.is_requested():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_gameplay():
		return
	if event.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not DevCli.is_requested():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"interact"):
		if GameState.player_mode == GameState.PlayerMode.DRIVING:
			if camper.is_stopped():
				_exit_vehicle()
		elif can_enter_vehicle():
			_enter_vehicle()


func _process(_delta: float) -> void:
	walker.camera_yaw = follow_camera.yaw


## Re-enables whichever body the player controls (after photo mode / journal).
func restore_control() -> void:
	camper.active = GameState.player_mode == GameState.PlayerMode.DRIVING
	walker.active = GameState.player_mode == GameState.PlayerMode.ON_FOOT


func suspend_control() -> void:
	camper.active = false
	walker.active = false


## The body the player currently controls.
func get_controlled_body() -> Node3D:
	return camper if GameState.player_mode == GameState.PlayerMode.DRIVING else walker


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
	camper.active = true
	follow_camera.set_target(camper, true)
	GameState.player_mode = GameState.PlayerMode.DRIVING


func _set_walker_present(present: bool) -> void:
	walker.visible = present
	walker.active = present
	walker.process_mode = Node.PROCESS_MODE_INHERIT if present else Node.PROCESS_MODE_DISABLED
