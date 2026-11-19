class_name UpgradeCatalog
extends RefCounted
## Read-only view of data/upgrades/upgrades.json. Each level lists the full
## effect values for that level (not deltas), so lookups are trivial.

const PATH: String = "res://data/upgrades/upgrades.json"

static var _cache: Array = []


static func all() -> Array:
	if _cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_cache = parsed.get("upgrades", [])
	return _cache


static func find(id: String) -> Dictionary:
	for u: Dictionary in all():
		if u.id == id:
			return u
	return {}


static func max_level(id: String) -> int:
	return (find(id).get("levels", []) as Array).size()


## Price of the next level, or -1 when maxed.
static func next_price(id: String, current_level: int) -> int:
	var levels: Array = find(id).get("levels", [])
	return int(levels[current_level].price) if current_level < levels.size() else -1


static func effect(id: String, level: int, key: String, default: float) -> float:
	if level <= 0:
		return default
	var levels: Array = find(id).get("levels", [])
	if levels.is_empty():
		return default
	return float(levels[mini(level, levels.size()) - 1].effects.get(key, default))
