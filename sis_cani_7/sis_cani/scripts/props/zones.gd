class_name Zone
extends Area2D
## Alan: "kill" (karanlık su, uçurum) ya da "trigger" (bir kez çalışan olay).

var mode := "trigger"
var id := ""
var once := true
var callback: Callable = Callable()
var size := Vector2(100, 200)
var _fired := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = size / 2.0
	add_child(cs)
	body_entered.connect(_on_body)


func _on_body(b) -> void:
	if not b is Kerem:
		return
	if mode == "kill":
		b.caught()
		return
	if once and _fired:
		return
	_fired = true
	if id != "":
		GameState.set_flag("trg_" + id)
	if callback.is_valid():
		callback.call()


func rearm() -> void:
	_fired = false
	if id != "":
		GameState.flags.erase("trg_" + id)
