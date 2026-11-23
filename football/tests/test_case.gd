extends Node
## Basit test temel sınıfı. test_* metotları otomatik çalıştırılır.

var failures: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func check_near(a: float, b: float, tol: float, msg: String) -> void:
	check(absf(a - b) <= tol, "%s (beklenen %.4f, gelen %.4f)" % [msg, b, a])


func step_physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func clear_children() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().physics_frame
