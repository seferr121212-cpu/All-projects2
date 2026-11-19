class_name Activity
extends Node3D
## Base for short, relaxed jobs (1-3 minutes, no failure). Started and
## finished from dialogue actions; HUD shows `get_status_text()` while active.

static var ECONOMY: EconomyConfig = load("res://data/economy/economy_config.tres")

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


## Leaving the region mid-job: stop quietly (no pay, flags cleared).
func cancel() -> void:
	if not active:
		return
	active = false
	for f: String in GameState.flags.keys():
		if f.ends_with(".harvesting") or f.ends_with(".harvest_full") or f.ends_with(".hauling") or f.ends_with(".net_full"):
			GameState.set_flag(f, false)


func get_status_text() -> String:
	return ""
