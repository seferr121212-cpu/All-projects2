class_name QuestLog
extends Node
## Road quests from data/quests/quests.json. Watches flags, counters, photo
## discoveries, finished jobs and region arrivals; pays the reward once.

const PATH: String = "res://data/quests/quests.json"

static var quests: Array = []


static func load_quests() -> Array:
	if quests.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				quests = (parsed as Dictionary).get("quests", [])
	return quests


static func is_done(q: Dictionary) -> bool:
	return GameState.has_flag("quest.%s" % q.id)


## Progress as [current, needed].
static func progress(q: Dictionary) -> Vector2i:
	match String(q.type):
		"photo":
			return Vector2i(1 if GameState.album.is_discovered(StringName(q.target)) else 0, 1)
		"job":
			return Vector2i(mini(GameState.get_counter("job." + String(q.target)), int(q.n)), int(q.n))
		"flag":
			return Vector2i(1 if GameState.has_flag(String(q.target)) else 0, 1)
		"counter":
			return Vector2i(mini(GameState.get_counter(String(q.target)), int(q.n)), int(q.n))
		"visited":
			var have: int = 0
			for r: Variant in q.targets:
				if GameState.has_flag("visited.%s" % r):
					have += 1
			return Vector2i(have, (q.targets as Array).size())
	return Vector2i(0, 1)


func _ready() -> void:
	load_quests()
	GameState.flags_changed.connect(check)
	GameState.region_changed.connect(_on_region)
	GameState.album.subject_discovered.connect(func(_id: StringName) -> void: check())
	get_tree().node_added.connect(_on_node_added)
	SaveManager.game_loaded.connect(func(_slot: String) -> void: _sync())


func _on_region(id: StringName) -> void:
	if not GameState.has_flag("visited.%s" % id):
		GameState.set_flag("visited.%s" % id)


func _on_node_added(node: Node) -> void:
	if node is Activity:
		(node as Activity).finished.connect(_on_job.bind(node))


func _on_job(pay: int, node: Node) -> void:
	if pay <= 0:
		return
	GameState.set_counter("job." + String(node.name), GameState.get_counter("job." + String(node.name)) + 1)
	GameState.set_counter("jobs.total", GameState.get_counter("jobs.total") + 1)
	check()


var _queued: bool = false


## Batches the many flag/counter changes of one frame into a single check.
func check() -> void:
	if not _queued:
		_queued = true
		_run.call_deferred()


## After loading a save, anything already satisfied counts as done (no reward).
func _sync() -> void:
	for q: Dictionary in quests:
		var p: Vector2i = progress(q)
		if not is_done(q) and p.x >= p.y:
			GameState.flags["quest.%s" % q.id] = true
	_queued = false


func _run() -> void:
	if not _queued:
		return
	_queued = false
	for q: Dictionary in quests:
		if is_done(q):
			continue
		var p: Vector2i = progress(q)
		if p.x >= p.y:
			GameState.flags["quest.%s" % q.id] = true
			GameState.add_money(int(q.reward))
			if q.id == "map_pieces":
				GameState.notify(tr(&"STORY_FINALE"))
			GameState.notify(tr(&"QUEST_DONE") % [tr(StringName("QUEST_%s" % String(q.id).to_upper())), int(q.reward)])
