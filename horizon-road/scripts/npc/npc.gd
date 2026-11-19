class_name Npc
extends Node3D
## A local the player can talk to. Dialogue, interests and identity come
## from data/npcs/<id>.json; this node only handles presence (schedule,
## idle motion, facing the player) and hands conversations to DialogueUI.

@export var npc_id: StringName = &"fadime"
@export var dialogue_path: String = "res://data/npcs/fadime.json"
@export var subject_id: StringName = &"SUBJ_NPC_FADIME"
## Hours when the NPC is out at this spot.
@export var present_from: float = 6.0
@export var present_until: float = 21.0
@export var snap_to_ground: bool = true
## Which body to build: "villager_woman" or "villager_man".
@export var model: String = "villager_woman"

var data: Dictionary
var talking: bool = false
var talk_target: Node3D

@onready var _visual: Node3D = $Visual
var _interact := Interactable.new()
var _body := StaticBody3D.new()
var _rest_yaw: float = 0.0


func _ready() -> void:
	add_to_group(&"npc")
	data = DialogueRunner.load_data(dialogue_path)
	var mi := MeshInstance3D.new()
	mi.mesh = LowPolyMeshes.villager_man() if model == "villager_man" else LowPolyMeshes.villager_woman()
	_visual.add_child(mi)
	_interact.prompt_key = "UI_TALK"
	_interact.position = Vector3(0, 1.0, 0)
	_interact.interacted.connect(_on_interacted)
	add_child(_interact)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.6
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.8, 0)
	_body.add_child(col)
	add_child(_body)
	var subject := PhotoSubject.new()
	subject.subject_id = subject_id
	subject.name_key = String(subject_id)
	subject.category = PhotoSubject.Category.PERSON
	subject.radius = 0.9
	subject.value = 0.9
	subject.own_body = _body
	subject.position = Vector3(0, 1.1, 0)
	add_child(subject)
	_rest_yaw = rotation.y
	_snap.call_deferred()


func get_display_name() -> String:
	return tr(StringName(data.get("name_key", "")))


func _snap() -> void:
	if snap_to_ground and GameState.current_region:
		var p: Vector3 = global_position
		global_position.y = GameState.current_region.get_ground_height(p.x, p.z)


func _on_interacted(by: Node3D) -> void:
	var ui := get_tree().get_first_node_in_group(&"dialogue_ui") as DialogueUI
	if ui:
		talk_target = by
		ui.start(self)


func _process(delta: float) -> void:
	var hour: float = TimeManager.time_of_day
	var present: bool = hour >= present_from and hour < present_until
	visible = present or talking
	_interact.enabled = visible
	_body.process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED
	var target_yaw: float = _rest_yaw
	if talking and is_instance_valid(talk_target):
		var to: Vector3 = talk_target.global_position - global_position
		target_yaw = atan2(-to.x, -to.z)
		_visual.rotation.x = lerpf(_visual.rotation.x, 0.0, 6.0 * delta)
	else:
		# Idle: lean into the tea now and then, like picking.
		var t: float = Time.get_ticks_msec() * 0.001
		_visual.rotation.x = lerpf(_visual.rotation.x, -0.18 * maxf(sin(t * 0.7), 0.0), 3.0 * delta)
	rotation.y = lerp_angle(rotation.y, target_yaw, 4.0 * delta)
