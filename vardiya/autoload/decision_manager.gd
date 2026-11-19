extends Node
## Evaluates data-driven conditions, applies effects, records decisions,
## builds the end-of-chapter flowchart data and resolves the ending.
##
## Condition leaf: {"<subject>": arg, "<op>": value}
##   subjects: flag, counter, decision, status, mood, trust ([a, b]),
##             avg_trust, alive_count, dead_count, found (exploration item)
##   ops: eq, ne, gt, gte, lt, lte, in   (none -> truthiness)
## Combinators: {"all": [...]}, {"any": [...]}, {"not": {...}}; [] = all.
##
## Effects: set_flag, add_counter, trust, trust_mutual, status, mood, journal
## Each effect may carry its own "if" condition.

signal decision_made(decision_id: String, option_id: String, timed_out: bool)

const ENDINGS_PATH := "res://data/endings.json"
const SUBJECTS: PackedStringArray = [
	"flag", "counter", "decision", "status", "mood", "trust",
	"avg_trust", "alive_count", "dead_count", "found",
]
## Node types shown as boxes in the flowchart.
const FLOW_POINTS: PackedStringArray = ["choice", "qte"]
const OPS: PackedStringArray = ["eq", "ne", "gt", "gte", "lt", "lte", "in"]

## Ending rules sorted by priority, and ending_id -> {title, description}.
var endings: Array = []
var ending_info: Dictionary = {}


func _ready() -> void:
	endings = _load_endings()


func _load_endings() -> Array:
	var f := FileAccess.open(ENDINGS_PATH, FileAccess.READ)
	if f == null:
		push_error("DecisionManager: missing %s" % ENDINGS_PATH)
		return []
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("endings"):
		push_error("DecisionManager: invalid endings file")
		return []
	ending_info = data.get("ending_info", {})
	var list: Array = data["endings"]
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("priority", 0)) < int(b.get("priority", 0)))
	return list


# --- Conditions -------------------------------------------------------------

func evaluate(cond: Variant) -> bool:
	if cond == null:
		return true
	if typeof(cond) == TYPE_ARRAY:
		for c: Variant in cond:
			if not evaluate(c):
				return false
		return true
	if typeof(cond) != TYPE_DICTIONARY:
		push_error("DecisionManager: condition must be a dictionary: %s" % str(cond))
		return false
	var d: Dictionary = cond
	if d.is_empty():
		return true
	if d.has("all"):
		return evaluate(d["all"])
	if d.has("any"):
		for c: Variant in d["any"]:
			if evaluate(c):
				return true
		return false
	if d.has("not"):
		return not evaluate(d["not"])
	for subject in SUBJECTS:
		if d.has(subject):
			return _compare(_subject_value(subject, d[subject]), d)
	push_error("DecisionManager: unknown condition %s" % str(d))
	return false


func _subject_value(subject: String, arg: Variant) -> Variant:
	match subject:
		"flag":
			return GameState.get_flag(str(arg))
		"counter":
			return GameState.get_counter(str(arg))
		"decision":
			return GameState.get_decision(str(arg))
		"status":
			return GameState.get_status(str(arg))
		"mood":
			return GameState.get_mood(str(arg))
		"trust":
			return GameState.get_trust(str(arg[0]), str(arg[1]))
		"avg_trust":
			return GameState.average_trust()
		"alive_count":
			return GameState.alive_count()
		"dead_count":
			return GameState.dead_count()
		"found":
			return GameState.has_found(str(arg))
	return null


func _compare(value: Variant, d: Dictionary) -> bool:
	var any_op := false
	for op in OPS:
		if not d.has(op):
			continue
		any_op = true
		var target: Variant = d[op]
		var ok := true
		match op:
			"eq":
				ok = _equal(value, target)
			"ne":
				ok = not _equal(value, target)
			"gt":
				ok = _is_num(value) and _is_num(target) and float(value) > float(target)
			"gte":
				ok = _is_num(value) and _is_num(target) and float(value) >= float(target)
			"lt":
				ok = _is_num(value) and _is_num(target) and float(value) < float(target)
			"lte":
				ok = _is_num(value) and _is_num(target) and float(value) <= float(target)
			"in":
				ok = false
				for t: Variant in target:
					if _equal(value, t):
						ok = true
						break
		if not ok:
			return false
	if not any_op:
		return _truthy(value)
	return true


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## JSON numbers arrive as floats; compare numbers numerically.
func _equal(a: Variant, b: Variant) -> bool:
	var num := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in num and typeof(b) in num:
		return is_equal_approx(float(a), float(b))
	if typeof(a) != typeof(b):
		return false
	return a == b


func _truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return float(v) != 0.0
		TYPE_STRING, TYPE_STRING_NAME:
			return str(v) != ""
	return true


# --- Effects ----------------------------------------------------------------

func apply_effects(effects: Variant) -> void:
	if effects == null:
		return
	for e: Dictionary in effects:
		if e.has("if") and not evaluate(e["if"]):
			continue
		if e.has("set_flag"):
			GameState.set_flag(str(e["set_flag"]), e.get("value", true))
		elif e.has("add_counter"):
			GameState.add_counter(str(e["add_counter"]), int(e.get("delta", 1)))
		elif e.has("trust"):
			GameState.add_trust(str(e["trust"][0]), str(e["trust"][1]), int(e.get("delta", 0)))
		elif e.has("trust_mutual"):
			var pair: Array = e["trust_mutual"]
			GameState.add_trust(str(pair[0]), str(pair[1]), int(e.get("delta", 0)))
			GameState.add_trust(str(pair[1]), str(pair[0]), int(e.get("delta", 0)))
		elif e.has("status"):
			GameState.set_status(str(e["status"]), str(e.get("value", GameState.STATUS_ALIVE)))
		elif e.has("mood"):
			GameState.set_mood(str(e["mood"]), str(e.get("value", GameState.DEFAULT_MOOD)))
		elif e.has("journal"):
			GameState.add_journal(str(e["journal"]))
		else:
			push_error("DecisionManager: unknown effect %s" % str(e))


## Record a choice and apply its effects. Called by DialogueRunner.
func commit(decision_id: String, option: Dictionary, chapter_id: String, timed_out: bool) -> void:
	GameState.record_decision(decision_id, str(option.get("id", "")), chapter_id, timed_out)
	apply_effects(option.get("effects", []))
	decision_made.emit(decision_id, str(option.get("id", "")), timed_out)


# --- Flowchart / summary ------------------------------------------------------

## Breadth-first list of choice nodes in a chapter with what was taken / missed.
## Returns [{node, decision_id, prompt, major, visited, timed_out,
##           options: [{id, text, chosen}]}]
func build_chapter_summary(chapter: Dictionary) -> Array:
	var nodes: Dictionary = chapter.get("nodes", {})
	var order: Array = []
	var seen := {}
	var queue: Array = [str(chapter.get("start", ""))]
	while not queue.is_empty():
		var id: String = queue.pop_front()
		if seen.has(id) or not nodes.has(id):
			continue
		seen[id] = true
		var n: Dictionary = nodes[id]
		if n.get("type", "") == "choice":
			order.append(id)
		for nxt in _next_ids(n):
			queue.append(nxt)
	var out: Array = []
	var chapter_id: String = chapter.get("id", "")
	for id: String in order:
		var n: Dictionary = nodes[id]
		var did: String = n.get("decision_id", id)
		var entry := _decision_entry(did, chapter_id)
		var opts: Array = []
		for o: Dictionary in n.get("options", []):
			opts.append({"id": o["id"], "text": o.get("text", ""), "chosen": not entry.is_empty() and entry["option"] == o["id"]})
		var timeout: Dictionary = n.get("timeout", {})
		if not timeout.is_empty():
			opts.append({"id": timeout.get("id", "silence"), "text": timeout.get("text", "dialogue.silence"),
				"chosen": not entry.is_empty() and entry["timed_out"]})
		out.append({
			"node": id, "decision_id": did, "prompt": n.get("prompt", ""), "major": n.get("major", false),
			"visited": not entry.is_empty(), "timed_out": not entry.is_empty() and entry["timed_out"], "options": opts,
		})
	return out


func _decision_entry(decision_id: String, chapter_id: String) -> Dictionary:
	for i in range(GameState.decisions.size() - 1, -1, -1):
		var d: Dictionary = GameState.decisions[i]
		if d["id"] == decision_id and (chapter_id == "" or d["chapter"] == chapter_id):
			return d
	return {}


static func _next_ids(n: Dictionary) -> Array:
	var out: Array = []
	if n.has("next") and n["next"] != null:
		out.append(str(n["next"]))
	for o: Dictionary in n.get("options", []):
		if o.has("next"):
			out.append(str(o["next"]))
	if n.has("timeout") and n["timeout"].has("next"):
		out.append(str(n["timeout"]["next"]))
	for c: Dictionary in n.get("cases", []):
		out.append(str(c["next"]))
	if n.has("else"):
		out.append(str(n["else"]))
	for item: Dictionary in n.get("items", []):
		if item.has("next"):
			out.append(str(item["next"]))
	for key in ["success", "fail"]:
		if n.has(key) and n[key].has("next"):
			out.append(str(n[key]["next"]))
	return out


## Outcome branches of a flowchart point: [{id, text, next}].
static func point_options(n: Dictionary) -> Array:
	var out: Array = []
	if n.get("type", "") == "qte":
		out.append({"id": "success", "text": "flow.qte_success", "next": str(n["success"]["next"])})
		out.append({"id": "fail", "text": "flow.qte_fail", "next": str(n["fail"]["next"])})
		return out
	for o: Dictionary in n.get("options", []):
		out.append({"id": str(o["id"]), "text": str(o.get("text", "")), "next": str(o["next"])})
	var timeout: Dictionary = n.get("timeout", {})
	if not timeout.is_empty():
		out.append({"id": str(timeout.get("id", "silence")), "text": str(timeout.get("text", "dialogue.silence")),
			"next": str(timeout["next"])})
	return out


## Graph of decision points for the end-of-chapter flowchart.
## Points: start, every choice / qte node, every end node. Each option edge
## follows plain nodes until it reaches the next point(s).
## Returns {"points": [{id, kind, label, major, layer, visited,
##           options: [{id, text, chosen, targets: [point ids]}]}], "layers": int}
func build_flowchart(chapter: Dictionary) -> Dictionary:
	var nodes: Dictionary = chapter.get("nodes", {})
	var chapter_id: String = chapter.get("id", "")
	var start: String = chapter.get("start", "")
	var points: Dictionary = {"__start": {"id": "__start", "kind": "start", "label": str(chapter.get("title", "")),
		"major": false, "visited": true, "options": [{"id": "start", "text": "", "chosen": true,
		"targets": _point_targets(nodes, start)}]}}
	for id: String in nodes:
		var n: Dictionary = nodes[id]
		var t: String = n.get("type", "")
		if t in FLOW_POINTS:
			var did: String = n.get("decision_id", id)
			var entry := _decision_entry(did, chapter_id)
			var opts: Array = []
			for o: Dictionary in point_options(n):
				opts.append({"id": o["id"], "text": o["text"], "targets": _point_targets(nodes, o["next"]),
					"chosen": not entry.is_empty() and entry["option"] == o["id"]})
			points[id] = {"id": id, "kind": t, "label": str(n.get("prompt", "")), "major": bool(n.get("major", false)),
				"visited": GameState.was_visited(chapter_id, id), "options": opts}
		elif t == "end":
			points[id] = {"id": id, "kind": "end", "label": "flow.end", "major": false,
				"visited": GameState.was_visited(chapter_id, id), "options": []}
	# Longest-path layering from the start (bounded, tolerates cycles).
	var layer := {"__start": 0}
	for _i in points.size():
		var changed := false
		for pid: String in points:
			if not layer.has(pid):
				continue
			for o: Dictionary in points[pid]["options"]:
				for t: String in o["targets"]:
					if points.has(t) and int(layer.get(t, -1)) < int(layer[pid]) + 1:
						layer[t] = int(layer[pid]) + 1
						changed = true
		if not changed:
			break
	var out: Array = []
	var max_layer := 0
	for pid: String in points:
		var p: Dictionary = points[pid]
		p["layer"] = int(layer.get(pid, 0))
		max_layer = maxi(max_layer, p["layer"])
		out.append(p)
	return {"points": out, "layers": max_layer + 1}


func _point_targets(nodes: Dictionary, from_id: String) -> Array:
	var targets: Array = []
	var seen := {}
	var stack: Array = [from_id]
	while not stack.is_empty():
		var id: String = stack.pop_back()
		if seen.has(id) or not nodes.has(id):
			continue
		seen[id] = true
		var n: Dictionary = nodes[id]
		var t: String = n.get("type", "")
		if t in FLOW_POINTS or t == "end":
			if not id in targets:
				targets.append(id)
			continue
		for nxt in _next_ids(n):
			stack.append(nxt)
	return targets


# --- Endings -----------------------------------------------------------------

## First rule (by priority) whose condition holds, otherwise the fallback rule.
## Returns {"rule", "ending", "title", "description"}.
func resolve_ending() -> Dictionary:
	var chosen := {}
	var fallback := {}
	for e: Dictionary in endings:
		if e.get("fallback", false):
			fallback = e
		elif evaluate(e.get("condition", {})):
			chosen = e
			break
	if chosen.is_empty():
		chosen = fallback
	if chosen.is_empty():
		return {}
	var info: Dictionary = ending_info.get(chosen["ending"], {})
	return {"rule": chosen["id"], "ending": chosen["ending"],
		"title": info.get("title", ""), "description": info.get("description", "")}
