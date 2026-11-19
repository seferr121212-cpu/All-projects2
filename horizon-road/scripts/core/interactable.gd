class_name Interactable
extends Node3D
## Something the player can use on foot with [E]. TravelController picks the
## nearest enabled one in range and shows its prompt in the HUD.

signal interacted(by: Node3D)

@export var prompt_key: String = "UI_TALK"
@export var distance: float = 2.6
@export var enabled: bool = true


func _ready() -> void:
	add_to_group(&"interactable")


func can_interact(from: Vector3) -> bool:
	return enabled and is_visible_in_tree() and from.distance_to(global_position) <= distance
