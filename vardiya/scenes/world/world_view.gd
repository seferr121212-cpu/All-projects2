extends Node3D
## Owns the current grey-box location: builds it, spawns the player and
## actors, finds the nearest available exploration item and forwards
## "interact" to DialogueRunner. Frames speakers during dialogue.

signal focus_item_changed(item: Dictionary)

const LocationBuilder = preload("res://scenes/world/location_builder.gd")
const PlayerController = preload("res://scenes/world/player_controller.gd")
const CameraRig = preload("res://scenes/world/camera_rig.gd")
const FACING_DOT := 0.1

var location_id := ""
## Ambience bed id of the loaded location (after variants), "" if none.
var ambience := ""
var player: PlayerController
var rig: CameraRig
var actors: Dictionary = {}
var points: Dictionary = {}
var exploring := false
var focused: Dictionary = {}
var _items: Array = []
var _content: Node3D


func load_location(scene_id: String, spawn: String, player_id: String) -> bool:
	var data := LocationBuilder.load_data(scene_id)
	if data.is_empty():
		return false
	unload()
	location_id = scene_id
	_content = Node3D.new()
	_content.name = "Location_" + scene_id
	add_child(_content)
	var built := LocationBuilder.build(_content, data)
	actors = built["actors"]
	ambience = str(built.get("ambience", ""))
	points = built["points"]
	var spawns: Dictionary = built["spawns"]
	var xf: Transform3D = spawns.get(spawn, spawns.get("default", Transform3D.IDENTITY))
	player = PlayerController.new()
	player.setup(player_id, LocationBuilder.make_body(player_id))
	_content.add_child(player)
	player.global_position = xf.origin
	player.visual.rotation.y = xf.basis.get_euler().y
	var cam: Dictionary = built["camera"]
	rig = CameraRig.new()
	_content.add_child(rig)
	rig.setup(player, float(cam.get("distance", 3.4)), xf.basis.get_euler().y + PI)
	player.camera_pivot = rig
	return true


## Turns the "high" extras off in the location on screen right now (the
## quality governor stepped down); the next location is built "low" anyway.
func apply_low_quality() -> void:
	if _content == null:
		return
	_lower(_content)


func _lower(node: Node) -> void:
	for c in node.get_children():
		if c is CPUParticles3D:
			(c as CPUParticles3D).emitting = false
			(c as CPUParticles3D).visible = false
		elif c is DirectionalLight3D:
			(c as DirectionalLight3D).shadow_enabled = false
		elif c is CanvasLayer or str(c.name).begins_with("Halo") or str(c.name).begins_with("Shaft"):
			c.set("visible", false)
		elif c is Node3D and not c is MeshInstance3D:
			_lower(c)


func unload() -> void:
	if _content:
		remove_child(_content)
		_content.queue_free()
	_content = null
	player = null
	rig = null
	ambience = ""
	actors = {}
	points = {}
	_set_focus({})


func set_exploring(on: bool, items: Array = []) -> void:
	exploring = on
	_items = items
	if player:
		player.enabled = on
	if on and rig:
		rig.release()
	if not on:
		_set_focus({})


## World position of an exploration item (a location point or an actor).
func item_position(item: Dictionary) -> Variant:
	if item.has("actor") and actors.has(str(item["actor"])):
		return (actors[str(item["actor"])] as Node3D).global_position
	var p: Dictionary = points.get(str(item.get("point", item["id"])), {})
	return p.get("pos", null)


func item_radius(item: Dictionary) -> float:
	var p: Dictionary = points.get(str(item.get("point", item["id"])), {})
	return float(p.get("radius", 1.6))


func _physics_process(_delta: float) -> void:
	if not exploring or player == null:
		return
	var best := {}
	var best_score := INF
	var here := player.global_position
	for item: Dictionary in _items:
		var pos: Variant = item_position(item)
		if pos == null:
			continue
		var to: Vector3 = (pos as Vector3) - here
		to.y = 0
		var dist := to.length()
		if dist > item_radius(item):
			continue
		var facing_dot := player.facing().dot(to.normalized()) if dist > 0.05 else 1.0
		if facing_dot < FACING_DOT:
			continue
		var score := dist - facing_dot
		if score < best_score:
			best_score = score
			best = item
	if best.get("id", "") != focused.get("id", ""):
		_set_focus(best)


func _set_focus(item: Dictionary) -> void:
	focused = item
	focus_item_changed.emit(item)


## Screen position for the HUD prompt above the focused item.
func focused_screen_pos() -> Variant:
	if focused.is_empty() or rig == null:
		return null
	var pos: Variant = item_position(focused)
	if pos == null:
		return null
	var world_pos: Vector3 = (pos as Vector3) + Vector3.UP * 1.9
	var cam := rig.camera()
	if cam.is_position_behind(world_pos):
		return null
	return cam.unproject_position(world_pos)


func _unhandled_input(event: InputEvent) -> void:
	if exploring and not focused.is_empty() and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		var item := focused
		var pos: Variant = item_position(item)
		if pos != null and item.has("actor"):
			player.face(pos)
		DialogueRunner.interact(str(item["id"]))


## Frame the speaker during dialogue; narrator / unknown speakers keep the view.
func on_line(speaker: String) -> void:
	if rig == null or player == null:
		return
	var player_id := str(GameState.location.get("player", ""))
	_gesture(speaker, player_id)
	if actors.has(speaker):
		var spk: Node3D = actors[speaker]
		player.face(spk.global_position)
		rig.focus(player.global_position, spk.global_position)
	elif speaker == player_id:
		var other := _nearest_actor()
		if other:
			rig.focus(other.global_position, player.global_position)


## Speaking body nods / gestures (stage 6 animation).
func _gesture(speaker: String, player_id: String) -> void:
	var body: Node3D = null
	if actors.has(speaker):
		body = actors[speaker]
	elif speaker == player_id and player:
		body = player.visual
	if body and body.has_method("talk"):
		body.call("talk")


func _nearest_actor() -> Node3D:
	var best: Node3D = null
	var best_d := 6.0
	for id: String in actors:
		var a: Node3D = actors[id]
		var d := a.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best
