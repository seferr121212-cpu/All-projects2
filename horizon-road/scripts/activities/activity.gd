class_name Activity
extends Node3D
## Base for short, relaxed jobs (1-3 minutes, no failure). Started and
## finished from dialogue actions; HUD shows `get_status_text()` while active.

signal started
signal finished(payment: int)

@export var activity_id: StringName = &""

var active: bool = false


func _ready() -> void:
	add_to_group(&"activity")


func begin() -> void:
	active = true
	started.emit()


## Ends the activity and returns the payment (already added to the wallet).
func complete() -> int:
	active = false
	finished.emit(0)
	return 0


func get_status_text() -> String:
	return ""
