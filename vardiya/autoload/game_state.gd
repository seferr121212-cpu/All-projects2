extends Node
## Single source of truth for the story state: character life status,
## directional trust (-5..+5), mood, story flags, counters and the
## ordered decision history. Everything here is (de)serializable.

signal state_changed

const CHARACTERS: PackedStringArray = ["kemal", "defne", "riza"]
const STATUS_ALIVE := "alive"
const STATUS_DEAD := "dead"
const STATUS_MISSING := "missing"
const STATUSES: PackedStringArray = [STATUS_ALIVE, STATUS_DEAD, STATUS_MISSING]
const MOODS: PackedStringArray = ["calm", "anxious", "angry", "hopeful", "broken", "guilty"]
const DEFAULT_MOOD := "calm"
const TRUST_MIN := -5
const TRUST_MAX := 5
const FLAGS_PATH := "res://data/story_flags.json"

## id -> {"status": String, "mood": String, "trust": {other_id: int}}
var characters: Dictionary = {}
var flags: Dictionary = {}
var counters: Dictionary = {}
## Ordered list of {"id", "option", "chapter", "timed_out"}
var decisions: Array = []
var journal: Array = []
var current_chapter := ""
var current_node := ""
var play_time_sec := 0.0

var _flag_defaults: Dictionary = {}


func _ready() -> void:
	_flag_defaults = _load_flag_defaults()
	reset()


func _load_flag_defaults() -> Dictionary:
	var f := FileAccess.open(FLAGS_PATH, FileAccess.READ)
	if f == null:
		push_error("GameState: missing %s" % FLAGS_PATH)
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var out := {}
	for key: String in data:
		if not key.begins_with("_"):
			out[key] = data[key]["default"] if typeof(data[key]) == TYPE_DICTIONARY else data[key]
	return out


func flag_names() -> Array:
	return _flag_defaults.keys()


func reset() -> void:
	characters.clear()
	for id in CHARACTERS:
		var trust := {}
		for other in CHARACTERS:
			if other != id:
				trust[other] = 0
		characters[id] = {"status": STATUS_ALIVE, "mood": DEFAULT_MOOD, "trust": trust}
	flags = _flag_defaults.duplicate(true)
	counters.clear()
	decisions.clear()
	journal.clear()
	current_chapter = ""
	current_node = ""
	play_time_sec = 0.0
	state_changed.emit()


# --- Characters -------------------------------------------------------------

func get_status(id: String) -> String:
	return characters.get(id, {}).get("status", STATUS_ALIVE)


func set_status(id: String, status: String) -> void:
	if not characters.has(id) or not status in STATUSES:
		push_error("GameState: bad status %s/%s" % [id, status])
		return
	characters[id]["status"] = status
	state_changed.emit()


func is_alive(id: String) -> bool:
	return get_status(id) == STATUS_ALIVE


func alive_count() -> int:
	var n := 0
	for id in CHARACTERS:
		if is_alive(id):
			n += 1
	return n


func dead_count() -> int:
	var n := 0
	for id in CHARACTERS:
		if get_status(id) == STATUS_DEAD:
			n += 1
	return n


func get_mood(id: String) -> String:
	return characters.get(id, {}).get("mood", DEFAULT_MOOD)


func set_mood(id: String, mood: String) -> void:
	if not characters.has(id) or not mood in MOODS:
		push_error("GameState: bad mood %s/%s" % [id, mood])
		return
	characters[id]["mood"] = mood
	state_changed.emit()


## How much `from_id` trusts `to_id`.
func get_trust(from_id: String, to_id: String) -> int:
	return int(characters.get(from_id, {}).get("trust", {}).get(to_id, 0))


func add_trust(from_id: String, to_id: String, delta: int) -> void:
	if not characters.has(from_id) or not characters[from_id]["trust"].has(to_id):
		push_error("GameState: bad trust pair %s->%s" % [from_id, to_id])
		return
	characters[from_id]["trust"][to_id] = clampi(get_trust(from_id, to_id) + delta, TRUST_MIN, TRUST_MAX)
	state_changed.emit()


## Mean directional trust between characters that are both alive.
func average_trust() -> float:
	var total := 0
	var n := 0
	for a in CHARACTERS:
		for b in CHARACTERS:
			if a != b and is_alive(a) and is_alive(b):
				total += get_trust(a, b)
				n += 1
	return float(total) / n if n > 0 else 0.0


# --- Flags, counters, decisions --------------------------------------------

func get_flag(key: String, default_value: Variant = null) -> Variant:
	return flags.get(key, default_value)


func set_flag(key: String, value: Variant) -> void:
	if not _flag_defaults.has(key):
		push_warning("GameState: undeclared flag '%s'" % key)
	flags[key] = value
	state_changed.emit()


func get_counter(key: String) -> int:
	return int(counters.get(key, 0))


func add_counter(key: String, delta: int) -> void:
	counters[key] = get_counter(key) + delta
	state_changed.emit()


func record_decision(id: String, option: String, chapter: String, timed_out: bool) -> void:
	decisions.append({"id": id, "option": option, "chapter": chapter, "timed_out": timed_out})
	state_changed.emit()


## Last option chosen for a decision id, or "" if never made.
func get_decision(id: String) -> String:
	for i in range(decisions.size() - 1, -1, -1):
		if decisions[i]["id"] == id:
			return decisions[i]["option"]
	return ""


func add_journal(key: String) -> void:
	if not key in journal:
		journal.append(key)
		state_changed.emit()


# --- Serialization ----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"characters": characters.duplicate(true),
		"flags": flags.duplicate(true),
		"counters": counters.duplicate(true),
		"decisions": decisions.duplicate(true),
		"journal": journal.duplicate(),
		"current_chapter": current_chapter,
		"current_node": current_node,
		"play_time_sec": play_time_sec,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	for id: String in d.get("characters", {}):
		if characters.has(id):
			var src: Dictionary = d["characters"][id]
			characters[id]["status"] = str(src.get("status", STATUS_ALIVE))
			characters[id]["mood"] = str(src.get("mood", DEFAULT_MOOD))
			for other: String in src.get("trust", {}):
				if characters[id]["trust"].has(other):
					characters[id]["trust"][other] = clampi(int(src["trust"][other]), TRUST_MIN, TRUST_MAX)
	for key: String in d.get("flags", {}):
		flags[key] = d["flags"][key]
	for key: String in d.get("counters", {}):
		counters[key] = int(d["counters"][key])
	for entry: Dictionary in d.get("decisions", []):
		decisions.append({
			"id": str(entry.get("id", "")),
			"option": str(entry.get("option", "")),
			"chapter": str(entry.get("chapter", "")),
			"timed_out": bool(entry.get("timed_out", false)),
		})
	for key in d.get("journal", []):
		journal.append(str(key))
	current_chapter = str(d.get("current_chapter", ""))
	current_node = str(d.get("current_node", ""))
	play_time_sec = float(d.get("play_time_sec", 0.0))
	state_changed.emit()
