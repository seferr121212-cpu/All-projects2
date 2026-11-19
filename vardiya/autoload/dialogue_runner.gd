extends Node
## Walks a chapter graph loaded from data/chapters/<id>.json.
## Blocking nodes: line (advance()), choice (choose() or timer),
## explore (interact() until an exit item), qte (qte_press / qte_set_holding
## or timer), end. Instant nodes: branch, effect, checkpoint, location.
##
## Silence is a choice: when the choice timer runs out the node's "timeout"
## option is committed like any other option. A failed QTE never ends the
## game; it takes the node's "fail" branch.

signal line_shown(speaker: String, text_key: String)
signal choice_shown(node: Dictionary, options: Array, time_limit: float)
signal choice_resolved(option_id: String, timed_out: bool)
signal location_changed(location_key: String, scene_id: String, spawn: String)
signal explore_started(node: Dictionary, items: Array)
signal item_examined(item_id: String, journal_key: String)
signal qte_started(node: Dictionary, params: Dictionary)
signal qte_finished(success: bool)
signal checkpoint_reached
signal chapter_finished(chapter_id: String, next_chapter: String)

enum Wait { NONE, ADVANCE, CHOICE, EXPLORE, QTE, FINISHED }

const CHAPTER_DIR := "res://data/chapters/"
const DEFAULT_CHOICE_TIME := 8.0
const MAX_AUTO_STEPS := 1000
const QTE_EASY_TIME_SCALE := 1.75
const QTE_EASY_COUNT_SCALE := 0.5
const QTE_DEFAULT_HOLD := 1.2

var chapter: Dictionary = {}
var waiting: Wait = Wait.NONE
var current_node_id := ""
var choice_time_left := 0.0
var choice_time_total := 0.0
var qte: Dictionary = {}  # active QTE params + progress
var _current_options: Array = []
var _inline: Array = []
var _in_inline := false
var _after_inline := ""


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
	_inline.clear()
	_in_inline = false
	GameState.current_chapter = chapter_id
	_goto(from_node if from_node != "" else str(chapter.get("start", "")))
	return true


func stop() -> void:
	waiting = Wait.NONE
	set_process(false)
	chapter = {}
	_inline.clear()
	_in_inline = false


func get_node_data(id: String) -> Dictionary:
	return chapter.get("nodes", {}).get(id, {})


func _goto(node_id: String) -> void:
	var steps := 0
	var chapter_id := str(chapter.get("id", ""))
	while steps < MAX_AUTO_STEPS:
		steps += 1
		var n := get_node_data(node_id)
		if n.is_empty():
			push_error("DialogueRunner: missing node '%s' in %s" % [node_id, chapter_id])
			_finish("")
			return
		current_node_id = node_id
		GameState.current_node = node_id
		GameState.mark_visited(chapter_id, node_id)
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
			"explore":
				_show_explore(n, true)
				return
			"qte":
				_show_qte(n)
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
				GameState.location = {
					"scene": str(n.get("scene", "")),
					"spawn": str(n.get("spawn", "default")),
					"player": str(n.get("player", "")),
				}
				location_changed.emit(str(n.get("location", "")), GameState.location["scene"], GameState.location["spawn"])
				node_id = str(n["next"])
			"end":
				_finish(str(n.get("next_chapter", "")) if n.get("next_chapter") != null else "")
				return
			_:
				push_error("DialogueRunner: unknown node type '%s'" % n.get("type", ""))
				_finish("")
				return
	push_error("DialogueRunner: too many automatic steps, loop near '%s'" % node_id)


# --- Lines -------------------------------------------------------------------

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
	if _in_inline:
		if not _inline.is_empty():
			_emit_inline()
			return
		_in_inline = false
		if _after_inline != "":
			_goto(_after_inline)
		else:
			_show_explore(get_node_data(current_node_id), false)
		return
	_goto(str(get_node_data(current_node_id)["next"]))


## Play a short list of {speaker, text} lines, then continue at `then`
## ("" = return to the current exploration).
func _play_inline(lines: Array, then: String) -> void:
	_inline = lines.duplicate()
	_after_inline = then
	_in_inline = true
	_emit_inline()


func _emit_inline() -> void:
	var l: Dictionary = _inline.pop_front()
	waiting = Wait.ADVANCE
	line_shown.emit(str(l.get("speaker", "narrator")), str(l.get("text", "")))


# --- Choices -----------------------------------------------------------------

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


## Commit the timeout ("silence") option of the current choice.
func force_timeout() -> void:
	if waiting != Wait.CHOICE:
		return
	var n := get_node_data(current_node_id)
	var timeout: Dictionary = n.get("timeout", {})
	if timeout.is_empty():
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


# --- Exploration -------------------------------------------------------------

## Items currently available (their "if" holds), each with a "found" flag.
func explore_items() -> Array:
	var out: Array = []
	for item: Dictionary in get_node_data(current_node_id).get("items", []):
		if item.has("if") and not DecisionManager.evaluate(item["if"]):
			continue
		var copy := item.duplicate()
		copy["found"] = GameState.has_found(str(item["id"]))
		out.append(copy)
	return out


func _show_explore(n: Dictionary, entering: bool) -> void:
	waiting = Wait.EXPLORE
	if entering and n.get("autosave", true):
		SaveSystem.autosave()
	explore_started.emit(n, explore_items())


## Examine an exploration item. Returns false if not available now.
func interact(item_id: String) -> bool:
	if waiting != Wait.EXPLORE:
		return false
	var item := {}
	for it: Dictionary in explore_items():
		if it["id"] == item_id:
			item = it
	if item.is_empty():
		return false
	waiting = Wait.NONE
	if item.has("requires") and not DecisionManager.evaluate(item["requires"]):
		var who := str(GameState.location.get("player", "narrator"))
		_play_inline([{"speaker": who, "text": str(item.get("locked_text", ""))}], "")
		return true
	var first_time := not GameState.has_found(item_id)
	GameState.add_found(item_id)
	if first_time:
		DecisionManager.apply_effects(item.get("effects", []))
		if item.has("journal"):
			GameState.add_journal(str(item["journal"]))
	item_examined.emit(item_id, str(item.get("journal", "")) if first_time else "")
	var then := str(item.get("next", ""))
	if then == "" and first_time:
		SaveSystem.autosave()
	var lines: Array = item.get("lines", [])
	if not first_time and item.has("repeat_lines"):
		lines = item["repeat_lines"]
	if not lines.is_empty():
		_play_inline(lines, then)
	elif then != "":
		_goto(then)
	else:
		_show_explore(get_node_data(current_node_id), false)
	return true


# --- QTE -----------------------------------------------------------------------

func _show_qte(n: Dictionary) -> void:
	var easy := bool(SaveSystem.settings.get("qte_easy", false))
	var hold_alt := bool(SaveSystem.settings.get("qte_hold_alternative", false))
	var mode: String = n.get("mode", "press")
	if mode == "mash" and hold_alt:
		mode = "hold"
	var time := float(n.get("time", 2.0)) * (QTE_EASY_TIME_SCALE if easy else 1.0)
	var count := int(n.get("count", 1))
	if easy:
		count = maxi(1, int(ceil(count * QTE_EASY_COUNT_SCALE)))
	qte = {
		"mode": mode, "time_total": time, "time_left": time, "count": count, "presses": 0,
		"hold_needed": float(n.get("hold_time", QTE_DEFAULT_HOLD)), "held": 0.0, "holding": false,
		"prompt": str(n.get("prompt", "")), "action": str(n.get("action", "qte_action")),
	}
	waiting = Wait.QTE
	set_process(true)
	qte_started.emit(n, qte)


func qte_press() -> void:
	if waiting != Wait.QTE:
		return
	match str(qte["mode"]):
		"press":
			_resolve_qte(true)
		"mash":
			qte["presses"] = int(qte["presses"]) + 1
			if int(qte["presses"]) >= int(qte["count"]):
				_resolve_qte(true)


func qte_set_holding(active: bool) -> void:
	if waiting == Wait.QTE:
		qte["holding"] = active


## Progress 0..1 toward success (for the UI).
func qte_progress() -> float:
	if qte.is_empty():
		return 0.0
	match str(qte["mode"]):
		"mash":
			return float(qte["presses"]) / maxf(1.0, float(qte["count"]))
		"hold":
			return float(qte["held"]) / maxf(0.01, float(qte["hold_needed"]))
	return 0.0


## Ends the QTE with a result (also used by tests).
func _resolve_qte(success: bool) -> void:
	if waiting != Wait.QTE:
		return
	waiting = Wait.NONE
	set_process(false)
	var n := get_node_data(current_node_id)
	var branch: Dictionary = n["success" if success else "fail"]
	var opt := {"id": "success" if success else "fail", "effects": branch.get("effects", [])}
	DecisionManager.commit(str(n.get("decision_id", current_node_id)), opt, str(chapter.get("id", "")), false)
	qte_finished.emit(success)
	var next_id := str(branch["next"])
	GameState.current_node = next_id
	SaveSystem.autosave()
	_goto(next_id)


func force_qte_result(success: bool) -> void:
	_resolve_qte(success)


# --- Timers ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if waiting == Wait.CHOICE:
		choice_time_left -= delta
		if choice_time_left <= 0.0:
			force_timeout()
	elif waiting == Wait.QTE:
		if str(qte["mode"]) == "hold" and bool(qte["holding"]):
			qte["held"] = float(qte["held"]) + delta
			if float(qte["held"]) >= float(qte["hold_needed"]):
				_resolve_qte(true)
				return
		qte["time_left"] = float(qte["time_left"]) - delta
		if float(qte["time_left"]) <= 0.0:
			_resolve_qte(false)
	else:
		set_process(false)


func _resolve_branch(n: Dictionary) -> String:
	for c: Dictionary in n.get("cases", []):
		if DecisionManager.evaluate(c.get("if", {})):
			return str(c["next"])
	return str(n["else"])


func _finish(next_chapter: String) -> void:
	waiting = Wait.FINISHED
	set_process(false)
	chapter_finished.emit(str(chapter.get("id", "")), next_chapter)
