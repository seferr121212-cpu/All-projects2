extends Node3D
## Cheap per-location animation: flickering lights (fluorescent buzz, fire)
## and wobbling fire sheets. One node per location, a handful of entries.

var _flicker: Array = []  # [{light, base, mode, seed}]
var _fires: Array = []  # [{node, base}]
var _time := 0.0


func add_flicker(light: Light3D, mode: String) -> void:
	_flicker.append({"light": light, "base": light.light_energy, "mode": mode, "seed": float(_flicker.size()) * 1.7})


func add_fire(node: Node3D) -> void:
	_fires.append({"node": node, "base": node.scale})


func has_work() -> bool:
	return not (_flicker.is_empty() and _fires.is_empty())


func _process(delta: float) -> void:
	_time += delta
	for f: Dictionary in _flicker:
		var light: Light3D = f["light"]
		var t: float = _time + float(f["seed"])
		var k := 1.0
		if f["mode"] == "fire":
			k = 0.75 + 0.15 * sin(t * 9.0) + 0.1 * sin(t * 23.0 + 1.3)
		else:
			# Tired fluorescent tube: steady with rare short dips.
			k = 0.25 if fmod(t, 7.3) < 0.08 or fmod(t + 0.4, 11.1) < 0.05 else 1.0
		light.light_energy = float(f["base"]) * k
	for f: Dictionary in _fires:
		var node: Node3D = f["node"]
		var base: Vector3 = f["base"]
		var t := _time * 6.0 + node.position.x
		node.scale = Vector3(base.x * (1.0 + 0.05 * sin(t * 1.3)), base.y * (0.85 + 0.15 * sin(t) * sin(t * 0.7 + 2.0)), base.z)
