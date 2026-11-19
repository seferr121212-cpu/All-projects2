extends Node
## Walks a chapter graph loaded from data/chapters/<id>.json.
## Blocking nodes: line (waits for advance()), choice (waits for choose()
## or the timer), end. Other nodes run instantly: branch, effect,
## checkpoint, location.
##
## Silence is a choice: when the timer runs out the node's "timeout"
## option is committed like any other option.

signal line_shown(speaker: String, text_key: String)
signal choice_shown(node: Dictionary, options: Array, time_limit: float)
signal choice_resolved(option_id: String, timed_out: bool)
signal location_changed(location_key: String)
signal checkpoint_reached
signal chapter_finished(chapter_id: String, next_chapter: String)

enum Wait { NONE, ADVANCE, CHOICE, FINISHED }

const CHAPTER_DIR := "res://data/chapters/"
const DEFAULT_CHOICE_TIME := 8.0
const MAX_AUTO_STEPS := 1000


var chapter: Dictionary = {}
var waiting: Wait = Wait.NONE
var current_node_id := ""
var choice_time_left := 0.0
var choice_time_total := 0.0
var _current_options: Array = []


func _ready() -> void:
	set_process(false)


func load_chapter_data(chapter_id: String) -> Dictionary:
	var path := CHAPTER_DIR + chapter_id + ".json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DialogueRunner: missing chapter %s" % path)
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("DialogueRunner: invalid chapter JSON %s" % path)
		return {}
	return data


## Start (or resume) a chapter. Empty from_node = chapter start.
func start(chapter_id: String, from_node: String = "") -> bool:
	chapter = load_chapter_data(chapter_id)
	if chapter.is_empty():
		return false
	GameState.current_chapter = chapter_id
	_goto(from_node if from_node != "" else str(chapter.get("start", "")))
	return true


func stop() -> void:
	waiting = Wait.NONE
	set_process(false)
	chapter = {}


func get_node_data(id: String) -> Dictionary:
	return chapter.get("nodes", {}).get(id, {})


func _goto(node_id: String) -> void:
	var steps := 0
	while steps < MAX_AUTO_STEPS:
		steps += 1
		var n := get_node_data(node_id)
		if n.is_empty():
			push_error("DialogueRunner: missing node '%s' in %s" % [node_id, chapter.get("id", "?")])
			_finish("")
			return
		current_node_id = node_id
		GameState.current_node = node_id
		match str(n.get("type", "")):
			"line":
				if n.has("if") and not DecisionManager.evaluate(n["if"]):
					node_id = str(n["next"])
					continue
				_show_line(n)
				return
			"choice":
				_show_choice(n)
				return
			"branch":
				node_id = _resolve_branch(n)
			"effect":
				DecisionManager.apply_effects(n.get("effects", []))
				node_id = str(n["next"])
			"checkpoint":
				GameState.current_node = str(n["next"])
				SaveSystem.autosave()
				checkpoint_reached.emit()
				node_id = str(n["next"])
			"location":
				location_changed.emit(str(n.get("location", "")))
				node_id = str(n["next"])
			"end":
				_finish(str(n.get("next_chapter", "")) if n.get("next_chapter") != null else "")
				return
			_:
				push_error("DialogueRunner: unknown node type '%s'" % n.get("type", ""))
				_finish("")
				return
	push_error("DialogueRunner: too many automatic steps, loop near '%s'" % node_id)


func _show_line(n: Dictionary) -> void:
	var speaker: String = n.get("speaker", "narrator")
	var text: String = n.get("text", "")
	for v: Dictionary in n.get("variants", []):
		if DecisionManager.evaluate(v.get("if", {})):
			speaker = v.get("speaker", speaker)
			text = v.get("text", text)
			break
	waiting = Wait.ADVANCE
	line_shown.emit(speaker, text)


func advance() -> void:
	if waiting != Wait.ADVANCE:
		return
	waiting = Wait.NONE
	_goto(str(get_node_data(current_node_id)["next"]))


func _show_choice(n: Dictionary) -> void:
	_current_options = []
	for o: Dictionary in n.get("options", []):
		if not o.has("if") or DecisionManager.evaluate(o["if"]):
			_current_options.append(o)
	var base: float = float(n.get("timer", DEFAULT_CHOICE_TIME))
	var scale: float = float(SaveSystem.settings.get("choice_timer_scale", 1.0))
	choice_time_total = base * scale if base > 0.0 else 0.0
	choice_time_left = choice_time_total
	waiting = Wait.CHOICE
	set_process(choice_time_total > 0.0)
	choice_shown.emit(n, _current_options, choice_time_total)


func _process(delta: float) -> void:
	if waiting != Wait.CHOICE:
		set_process(false)
		return
	choice_time_left -= delta
	if choice_time_left <= 0.0:
		force_timeout()


## Commit the timeout ("silence") option of the current choice.
func force_timeout() -> void:
	if waiting != Wait.CHOICE:
		return
	var n := get_node_data(current_node_id)
	var timeout: Dictionary = n.get("timeout", {})
	if timeout.is_empty():
		# Untimed fallback: first available option.
		choose(str(_current_options[0]["id"]))
		return
	_commit(n, timeout, true)


func choose(option_id: String) -> bool:
	if waiting != Wait.CHOICE:
		return false
	for o: Dictionary in _current_options:
		if o["id"] == option_id:
			_commit(get_node_data(current_node_id), o, false)
			return true
	return false


func current_options() -> Array:
	return _current_options


func _commit(n: Dictionary, option: Dictionary, timed_out: bool) -> void:
	waiting = Wait.NONE
	set_process(false)
	var opt := option.duplicate()
	if timed_out and not opt.has("id"):
		opt["id"] = "silence"
	if timed_out:
		GameState.add_counter("silence", 1)
	DecisionManager.commit(str(n.get("decision_id", current_node_id)), opt, str(chapter.get("id", "")), timed_out)
	choice_resolved.emit(str(opt["id"]), timed_out)
	var next_id := str(opt["next"])
	if n.get("major", false):
		GameState.current_node = next_id
		SaveSystem.autosave()
	_goto(next_id)


func _resolve_branch(n: Dictionary) -> String:
	for c: Dictionary in n.get("cases", []):
		if DecisionManager.evaluate(c.get("if", {})):
			return str(c["next"])
	return str(n["else"])


func _finish(next_chapter: String) -> void:
	waiting = Wait.FINISHED
	set_process(false)
	chapter_finished.emit(str(chapter.get("id", "")), next_chapter)
