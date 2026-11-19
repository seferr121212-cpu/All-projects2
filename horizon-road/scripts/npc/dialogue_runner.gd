class_name DialogueRunner
extends RefCounted
## Walks a data-driven dialogue (data/npcs/<id>.json). UI-agnostic: it emits
## what to show and the UI calls back (advance / choose / submit_name /
## choose_photo). Conditions read GameState; actions change it.
##
## Node fields: text (translation key), next, choices[{text, next, if, actions}],
## branches[{if, next}] (silent redirect), type ("name_input"), actions[].
## Conditions: flag, not_flag, level_min, level_max, has_photos.
## Actions: meet, relationship:<n|first_meeting>, set_flag:x, clear_flag:x,
##          start_activity:id, complete_activity:id, open_photo_picker, sell_photo.

signal line_shown(text: String)
signal choices_shown(choices: Array[Dictionary])
signal name_requested(text: String)
signal photo_picker_requested
signal drawing_picker_requested
signal shop_requested
signal ended

static var ECONOMY: EconomyConfig = load("res://data/economy/economy_config.tres")

var data: Dictionary
var npc_id: StringName
var current_id: String = ""
## Values available to text as {name} placeholders.
var vars: Dictionary = {}
## Node used to reach the scene tree (activities live there).
var host: Node
var _pending_photo: Dictionary = {}
var _visible_choices: Array[Dictionary] = []


static func load_data(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Dialogue file unreadable: %s" % path)
		return {}
	return parsed


func _init(dialogue: Dictionary, host_node: Node) -> void:
	data = dialogue
	npc_id = StringName(data.get("id", ""))
	host = host_node
	vars["target"] = ECONOMY.tea_target_bunches


func start() -> void:
	_enter(data.get("start", "start"))


## Call after a plain line has been read.
func advance() -> void:
	var node: Dictionary = _node(current_id)
	if node.has("choices"):
		_show_choices(node)
	elif node.has("next"):
		_enter(node.next)
	else:
		_end()


func choose(index: int) -> void:
	if index < 0 or index >= _visible_choices.size():
		return
	var choice: Dictionary = _visible_choices[index]
	_apply_actions(choice.get("actions", []))
	if current_id == "":
		return  # an action ended or redirected the conversation
	if choice.has("next"):
		_enter(choice.next)
	elif not _opens_panel(choice.get("actions", [])):
		_end()


func _opens_panel(actions: Array) -> bool:
	for a: String in ["open_photo_picker", "open_drawing_picker", "open_shop"]:
		if a in actions:
			return true
	return false


func submit_name(player_name: String) -> void:
	var clean: String = player_name.strip_edges().left(20)
	if clean != "":
		GameState.player_name = clean
	advance()


## Player picked a photo to show. Decides the NPC's reaction.
func choose_photo(entry: Dictionary) -> void:
	var is_drawing: bool = entry.get("kind", "") == "drawing"
	var reactions: Dictionary = data.get("drawing_reactions" if is_drawing else "photo_reactions", data.get("photo_reactions", {}))
	_pending_photo = entry
	if String(npc_id) in entry.get("sold_to", []):
		_enter(reactions.get("already", "hub"))
		return
	var shown: Array = entry.get("shown_to", [])
	var loved: bool = _photo_matches_interests(entry)
	if not String(npc_id) in shown:
		shown.append(String(npc_id))
		entry["shown_to"] = shown
		GameState.add_relationship(npc_id, ECONOMY.points_photo_shown)
		_save_book(entry)
	if _sales_today() >= ECONOMY.photo_sales_per_day:
		_enter(reactions.get("limit", "hub"))
		return
	vars["amount"] = photo_price(entry)
	_enter(reactions.get("love" if loved else "nice", "hub"))


func cancel_photo() -> void:
	_enter("hub")


## Shop closed: continue with the NPC's "anything else?" line if it has one.
func close_shop() -> void:
	_enter("shop_closed" if data.nodes.has("shop_closed") else "hub")


func photo_price(entry: Dictionary) -> int:
	var mult: float = ECONOMY.photo_interest_multiplier if _photo_matches_interests(entry) else ECONOMY.photo_other_multiplier
	mult *= 1.0 + ECONOMY.photo_friend_bonus_per_level * GameState.get_relationship_level(npc_id)
	return maxi(roundi(float(entry.get("value", 10)) * mult), 1)


func format(key: String) -> String:
	var text: String = TranslationServer.translate(key)
	var values: Dictionary = vars.duplicate()
	values["player"] = GameState.get_display_name()
	return text.format(values)


func check(condition: Dictionary) -> bool:
	if condition.has("flag") and not GameState.has_flag(condition.flag):
		return false
	if condition.has("not_flag") and GameState.has_flag(condition.not_flag):
		return false
	var level: int = GameState.get_relationship_level(npc_id)
	if condition.has("level_min") and level < int(condition.level_min):
		return false
	if condition.has("level_max") and level > int(condition.level_max):
		return false
	if condition.has("has_photos") and GameState.album.entries.is_empty() == bool(condition.has_photos):
		return false
	if condition.has("player_named") and (GameState.player_name != "") != bool(condition.player_named):
		return false
	if condition.has("has_drawings") and GameState.drawings.entries.is_empty() == bool(condition.has_drawings):
		return false
	if condition.has("var_min"):
		for key: Variant in condition.var_min:
			if float(vars.get(key, 0)) < float(condition.var_min[key]):
				return false
	if condition.has("tank_full") and (GameState.fuel >= GameState.get_tank_capacity() - 0.5) != bool(condition.tank_full):
		return false
	return true


func _enter(id: String) -> void:
	if id == "" or id == "end" or not data.nodes.has(id):
		if id != "" and id != "end":
			push_warning("Dialogue '%s' has no node '%s'" % [npc_id, id])
		_end()
		return
	current_id = id
	var node: Dictionary = data.nodes[id]
	if node.has("branches"):
		for branch: Dictionary in node.branches:
			if check(branch.get("if", {})):
				_enter(branch.next)
				return
		_end()
		return
	_apply_actions(node.get("actions", []))
	if current_id != id:
		return
	if node.get("type", "") == "name_input":
		name_requested.emit(format(node.text))
	elif node.has("text"):
		line_shown.emit(format(node.text))
	else:
		advance()


func _show_choices(node: Dictionary) -> void:
	_visible_choices.clear()
	for c: Dictionary in node.choices:
		if check(c.get("if", {})):
			var shown: Dictionary = c.duplicate()
			shown["label"] = format(c.text)
			_visible_choices.append(shown)
	choices_shown.emit(_visible_choices)


func _apply_actions(actions: Array) -> void:
	for raw: Variant in actions:
		var parts: PackedStringArray = String(raw).split(":", true, 1)
		var arg: String = parts[1] if parts.size() > 1 else ""
		match parts[0]:
			"meet":
				GameState.set_flag("%s.met" % npc_id)
				GameState.register_person(npc_id, data.get("name_key", ""), data.get("role_key", ""), data.get("note_key", ""))
			"relationship":
				var points: int = ECONOMY.points_first_meeting if arg == "first_meeting" else int(arg)
				GameState.add_relationship(npc_id, points)
			"set_flag":
				GameState.set_flag(arg)
			"clear_flag":
				GameState.set_flag(arg, false)
			"start_activity":
				var activity: Activity = _find_activity(arg)
				if activity:
					activity.begin()
			"complete_activity":
				var activity: Activity = _find_activity(arg)
				if activity:
					vars["amount"] = activity.complete()
			"open_photo_picker":
				photo_picker_requested.emit()
			"open_drawing_picker":
				drawing_picker_requested.emit()
			"sell_photo":
				_sell_pending_photo()
			"open_shop":
				shop_requested.emit()
			"refuel":
				var before: int = GameState.money
				vars["amount"] = int(GameState.refuel())
				vars["price"] = before - GameState.money
			_:
				push_warning("Unknown dialogue action '%s'" % raw)


func _sell_pending_photo() -> void:
	if _pending_photo.is_empty():
		return
	var price: int = int(vars.get("amount", photo_price(_pending_photo)))
	GameState.add_money(price)
	var sold: Array = _pending_photo.get("sold_to", [])
	sold.append(String(npc_id))
	_pending_photo["sold_to"] = sold
	_save_book(_pending_photo)
	if _photo_matches_interests(_pending_photo):
		GameState.add_relationship(npc_id, ECONOMY.points_photo_sold_interest)
	GameState.set_counter("%s.photo_sale_day" % npc_id, TimeManager.day)
	GameState.set_counter("%s.photo_sales" % npc_id, _sales_today() + 1)
	_pending_photo = {}


func _save_book(entry: Dictionary) -> void:
	if entry.get("kind", "") == "drawing":
		GameState.drawings.save_index()
	else:
		GameState.album.save_index()


func _sales_today() -> int:
	if GameState.get_counter("%s.photo_sale_day" % npc_id) != TimeManager.day:
		return 0
	return GameState.get_counter("%s.photo_sales" % npc_id)


func _photo_matches_interests(entry: Dictionary) -> bool:
	var interests: Array = data.get("interests", [])
	for item: Dictionary in entry.get("subject_list", []):
		if String(item.get("id", "")) in interests:
			return true
	return false


func _find_activity(id: String) -> Activity:
	if host == null or not host.is_inside_tree():
		return null
	for node: Node in host.get_tree().get_nodes_in_group(&"activity"):
		if String((node as Activity).activity_id) == id:
			return node
	push_warning("Activity '%s' not found" % id)
	return null


func _node(id: String) -> Dictionary:
	return data.nodes.get(id, {})


func _end() -> void:
	current_id = ""
	ended.emit()
