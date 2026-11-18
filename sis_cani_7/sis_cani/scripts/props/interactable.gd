class_name Interactable
extends Node2D
## Etkileşim noktası tabanı. Kerem yaklaşınca HUD'da istem gösterilir, [E] ile kullanılır.

signal used(player)

var prompt := "INT_LOOK"
var hold_time := 0.0
var radius := 80.0
var enabled := true
var once := false
var on_use: Callable = Callable()
var condition: Callable = Callable()


func _ready() -> void:
	add_to_group("interactable")


func can_interact(_p) -> bool:
	if not enabled:
		return false
	if condition.is_valid():
		return bool(condition.call())
	return true


func interact(p) -> void:
	if once:
		enabled = false
	used.emit(p)
	if on_use.is_valid():
		on_use.call()


func prompt_text() -> String:
	return Loc.t(prompt)


func add_poly(points, color: Color, z := 0) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array(points)
	poly.color = color
	poly.z_index = z
	add_child(poly)
	return poly
