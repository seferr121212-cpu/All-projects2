class_name PhotoSubject
extends Node3D
## Marks something worth photographing. The scorer finds these through the
## "photo_subject" group, so subjects can live anywhere in a region scene.

enum Category { LANDSCAPE, ANIMAL, PERSON, STRUCTURE, MOMENT }

const CATEGORY_KEYS: Array[String] = [
	"CATEGORY_LANDSCAPE", "CATEGORY_ANIMAL", "CATEGORY_PERSON", "CATEGORY_STRUCTURE", "CATEGORY_MOMENT",
]

@export var subject_id: StringName = &""
@export var name_key: String = ""
@export var category: Category = Category.LANDSCAPE
## World-space size, used to judge how big the subject appears in frame.
@export var radius: float = 2.0
## How rewarding this subject is (rarer/more beautiful = higher).
@export_range(0.0, 1.0) var value: float = 0.6
## Place the point on the terrain surface the first time it is needed.
@export var snap_to_ground: bool = false
@export var ground_offset: float = 0.0
## Collider belonging to the subject itself; hitting it doesn't count as occlusion.
@export var own_body: CollisionObject3D

var _snapped: bool = false


func _ready() -> void:
	add_to_group(&"photo_subject")


func get_focus_point() -> Vector3:
	if snap_to_ground and not _snapped and GameState.current_region:
		var p: Vector3 = global_position
		global_position = Vector3(p.x, GameState.current_region.get_ground_height(p.x, p.z) + ground_offset, p.z)
		_snapped = true
	return global_position
