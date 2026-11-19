extends Control
## Headless engine tests. Run:
##   godot --headless --path . res://tests/test_runner.tscn
## Exit code 0 = all passed. Uses a separate save directory.

var _failures: Array[String] = []
var _passed := 0


func _ready() -> void:
	SaveSystem.save_dir = "user://test_saves/"
	_cleanup_saves()
	for test in [
		"test_locale_parity", "test_locale_switch", "test_trust_clamp", "test_conditions",
		"test_effects", "test_state_roundtrip", "test_dialogue_full_path", "test_dialogue_timeout_silence",
		"test_conditional_option_hidden", "test_line_variant", "test_save_load_same_state",
		"test_restart_chapter_restores_snapshot", "test_save_migration", "test_endings_resolution",
		"test_chapter_summary", "test_input_actions",
		"test_explore_locked_and_exit", "test_explore_found_unlocks_option", "test_qte_press_and_fail",
		"test_qte_easy_and_hold_alternative", "test_flowchart_graph", "test_resume_inside_exploration",
		"test_chapter1_full_playthrough", "test_location_data_builds",
	]:
		GameState.reset()
		SaveSystem.active_slot = -1
		DialogueRunner.stop()
		call(test)
	_cleanup_saves()
	print("\n%d checks passed, %d failed" % [_passed, _failures.size()])
	for f in _failures:
		print("FAIL: ", f)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failures.append(label)


func _cleanup_saves() -> void:
	for i in SaveSystem.SLOT_COUNT:
		SaveSystem.delete_slot(i)


# --- Localization -----------------------------------------------------------

func test_locale_parity() -> void:
	var tr_keys := Localization.keys("tr")
	var en_keys := Localization.keys("en")
	check(tr_keys.size() > 50, "locale tr loaded")
	check(tr_keys.size() == en_keys.size(), "locale key counts match")
	for k in tr_keys:
		if not k in en_keys:
			check(false, "en missing " + k)


func test_locale_switch() -> void:
	Localization.set_locale("en")
	check(Localization.t("menu.new_game") == "New Game", "en text")
	check(tr("menu.new_game") == "New Game", "TranslationServer en")
	Localization.set_locale("tr")
	check(Localization.t("menu.new_game") == "Yeni Oyun", "tr text")
	check(Localization.t("slot.label", {"n": 2}) == "Yuva 2", "placeholder format")
	check(Localization.t("no.such.key").begins_with("["), "missing key marker")


# --- GameState / DecisionManager ---------------------------------------------

func test_trust_clamp() -> void:
	GameState.add_trust("kemal", "defne", 9)
	check(GameState.get_trust("kemal", "defne") == 5, "trust clamps at +5")
	GameState.add_trust("kemal", "defne", -20)
	check(GameState.get_trust("kemal", "defne") == -5, "trust clamps at -5")
	check(GameState.get_trust("defne", "kemal") == 0, "trust is directional")


func test_conditions() -> void:
	GameState.set_flag("informer", "riza")
	GameState.add_trust("kemal", "riza", 3)
	GameState.set_status("defne", "dead")
	var dm := DecisionManager
	check(dm.evaluate({"flag": "informer", "ne": ""}), "flag ne")
	check(dm.evaluate({"trust": ["kemal", "riza"], "gte": 3}), "trust gte")
	check(not dm.evaluate({"trust": ["kemal", "riza"], "gt": 3}), "trust gt")
	check(dm.evaluate({"alive_count": true, "eq": 2}), "alive_count")
	check(dm.evaluate({"dead_count": true, "eq": 1}), "dead_count")
	check(dm.evaluate({"status": "defne", "eq": "dead"}), "status")
	check(dm.evaluate({"any": [{"flag": "harm_done"}, {"status": "kemal", "eq": "alive"}]}), "any")
	check(not dm.evaluate({"not": {"flag": "informer", "in": ["riza", "kemal"]}}), "not/in")
	check(dm.evaluate([]), "empty list is true")
	check(dm.evaluate({}), "empty dict is true")


func test_effects() -> void:
	DecisionManager.apply_effects([
		{"set_flag": "strike_supported", "value": true},
		{"add_counter": "silence", "delta": 2},
		{"trust_mutual": ["defne", "riza"], "delta": 2},
		{"status": "riza", "value": "missing"},
		{"mood": "kemal", "value": "angry"},
		{"journal": "journal.ch00.automation"},
		{"if": {"flag": "fire_started"}, "set_flag": "harm_done", "value": true},
	])
	check(GameState.get_flag("strike_supported") == true, "set_flag")
	check(GameState.get_counter("silence") == 2, "add_counter")
	check(GameState.get_trust("riza", "defne") == 2 and GameState.get_trust("defne", "riza") == 2, "trust_mutual")
	check(GameState.get_status("riza") == "missing", "status effect")
	check(GameState.get_mood("kemal") == "angry", "mood effect")
	check("journal.ch00.automation" in GameState.journal, "journal effect")
	check(GameState.get_flag("harm_done") == false, "conditional effect skipped")


func test_state_roundtrip() -> void:
	GameState.add_trust("riza", "kemal", -3)
	GameState.set_flag("informer", "defne")
	GameState.record_decision("b0_x", "a", "ch00_test", false)
	GameState.set_status("kemal", "dead")
	var d := GameState.to_dict()
	var json_copy: Dictionary = JSON.parse_string(JSON.stringify(d))
	GameState.reset()
	GameState.from_dict(json_copy)
	check(JSON.stringify(GameState.to_dict()) == JSON.stringify(d), "state survives JSON roundtrip")


# --- DialogueRunner ------------------------------------------------------------

func _run_to_choice() -> void:
	var guard := 0
	while DialogueRunner.waiting == DialogueRunner.Wait.ADVANCE and guard < 100:
		DialogueRunner.advance()
		guard += 1


func test_dialogue_full_path() -> void:
	check(DialogueRunner.start("ch00_test"), "chapter loads")
	_run_to_choice()
	check(DialogueRunner.waiting == DialogueRunner.Wait.CHOICE, "reached first choice")
	check(DialogueRunner.current_options().size() == 3, "three options at c01")
	check(DialogueRunner.choose("truth"), "choose truth")
	_run_to_choice()
	check(DialogueRunner.current_node_id == "c02", "reached c02")
	check(DialogueRunner.current_options().size() == 4, "conditional 4th option visible after truth")
	DialogueRunner.choose("ride")
	_run_to_choice()
	check(DialogueRunner.waiting == DialogueRunner.Wait.FINISHED, "chapter finished")
	check(GameState.get_decision("b0_kahvalti") == "truth", "decision recorded")
	check(GameState.get_trust("riza", "kemal") == 1, "ride effect applied")
	check(GameState.get_flag("breakfast_truth") == true, "flag set")


func test_dialogue_timeout_silence() -> void:
	DialogueRunner.start("ch00_test")
	_run_to_choice()
	DialogueRunner.force_timeout()
	check(GameState.get_decision("b0_kahvalti") == "silence", "silence recorded as decision")
	check(GameState.decisions[-1]["timed_out"], "timed_out flag")
	check(GameState.get_counter("silence") == 1, "silence counter")
	check(GameState.get_trust("defne", "kemal") == -1, "silence effect")


func test_conditional_option_hidden() -> void:
	DialogueRunner.start("ch00_test")
	_run_to_choice()
	DialogueRunner.choose("deflect")
	_run_to_choice()
	check(DialogueRunner.current_options().size() == 3, "defne_ride hidden after deflect")
	check(not DialogueRunner.choose("defne_ride"), "hidden option cannot be chosen")


func test_line_variant() -> void:
	var shown := []
	var cb := func(_s: String, key: String) -> void: shown.append(key)
	DialogueRunner.line_shown.connect(cb)
	DialogueRunner.start("ch00_test")
	_run_to_choice()
	DialogueRunner.choose("deflect")
	_run_to_choice()
	DialogueRunner.line_shown.disconnect(cb)
	check("ch00.l07_angry" in shown, "angry variant line used")
	check(not "ch00.l07" in shown, "default line replaced")


# --- SaveSystem ------------------------------------------------------------------

func test_save_load_same_state() -> void:
	SaveSystem.new_game(1)
	SaveSystem.begin_chapter("ch00_test")
	DialogueRunner.start(GameState.current_chapter)
	_run_to_choice()
	DialogueRunner.choose("truth")  # major -> autosave
	var before := JSON.stringify(GameState.to_dict())
	check(SaveSystem.has_save(1), "slot written")
	GameState.reset()
	check(SaveSystem.load_slot(1), "slot loads")
	check(JSON.stringify(GameState.to_dict()) == before, "loaded state equals saved state")
	check(GameState.current_node == "r01_truth", "resume node stored")
	DialogueRunner.start(GameState.current_chapter, GameState.current_node)
	check(DialogueRunner.current_node_id == "r01_truth", "resume at saved node")


func test_restart_chapter_restores_snapshot() -> void:
	SaveSystem.new_game(2)
	SaveSystem.begin_chapter("ch00_test")
	DialogueRunner.start(GameState.current_chapter)
	_run_to_choice()
	DialogueRunner.choose("deflect")
	check(GameState.get_trust("defne", "kemal") == -1, "trust changed")
	check(SaveSystem.restart_chapter(2, "ch00_test"), "restart chapter")
	check(GameState.get_trust("defne", "kemal") == 0, "trust restored from chapter snapshot")
	check(GameState.decisions.is_empty(), "decisions restored")


func test_save_migration() -> void:
	var old := {"format_version": 0, "state": GameState.to_dict()}
	var m := SaveSystem.migrate(old)
	check(int(m["format_version"]) == SaveSystem.FORMAT_VERSION, "v0 migrated")
	check(m.has("chapter_snapshots"), "v0 gets snapshots")
	check(SaveSystem.migrate({"format_version": 999, "state": {}}).is_empty(), "future format refused")


# --- Endings / summary ------------------------------------------------------------

func test_endings_resolution() -> void:
	check(DecisionManager.resolve_ending()["ending"] == "separation", "fresh state -> separation")
	for id in GameState.CHARACTERS:
		GameState.set_status(id, "dead")
	GameState.set_flag("informer", "riza")
	check(DecisionManager.resolve_ending()["ending"] == "bitter_reckoning", "all dead beats betrayal")
	GameState.reset()
	GameState.set_flag("informer", "kemal")
	check(DecisionManager.resolve_ending()["ending"] == "betrayal", "informer -> betrayal")
	GameState.reset()
	for a in GameState.CHARACTERS:
		for b in GameState.CHARACTERS:
			if a != b:
				GameState.add_trust(a, b, 3)
	check(DecisionManager.resolve_ending()["ending"] == "solidarity", "high trust -> solidarity")
	GameState.set_status("riza", "dead")
	check(DecisionManager.resolve_ending()["ending"] == "solidarity", "two alive + trust still solidarity")
	GameState.reset()
	GameState.set_status("riza", "dead")
	check(DecisionManager.resolve_ending()["ending"] == "bitter_reckoning", "one death, low trust -> bitter")
	GameState.reset()
	GameState.set_flag("final_silence", true)
	GameState.add_counter("silence", 6)
	check(DecisionManager.resolve_ending()["ending"] == "secret", "secret ending")


func test_chapter_summary() -> void:
	DialogueRunner.start("ch00_test")
	_run_to_choice()
	DialogueRunner.force_timeout()
	var s := DecisionManager.build_chapter_summary(DialogueRunner.chapter)
	check(s.size() == 2, "two decision nodes in summary")
	check(s[0]["visited"] and s[0]["timed_out"], "first decision timed out")
	var silence_chosen := false
	for o: Dictionary in s[0]["options"]:
		if o["id"] == "silence":
			silence_chosen = o["chosen"]
	check(silence_chosen, "silence marked chosen")
	check(not s[1]["visited"], "second decision not yet visited")


func test_input_actions() -> void:
	for a in ["move_up", "interact", "advance", "choice_1", "choice_4", "pause", "journal", "qte_action"]:
		check(InputMap.has_action(a), "action " + a)
		var has_pad := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_pad = true
		check(has_pad, "gamepad binding for " + a)


# --- Stage 3: exploration, QTE, flowchart, chapter 1 ----------------------------

func _settings_reset() -> void:
	SaveSystem.settings["qte_easy"] = false
	SaveSystem.settings["qte_hold_alternative"] = false
	SaveSystem.settings["choice_timer_scale"] = 1.0


func _run_until_blocking() -> void:
	var guard := 0
	while DialogueRunner.waiting == DialogueRunner.Wait.ADVANCE and guard < 200:
		DialogueRunner.advance()
		guard += 1


func test_explore_locked_and_exit() -> void:
	DialogueRunner.start("ch01_last_check")
	_run_until_blocking()
	check(DialogueRunner.waiting == DialogueRunner.Wait.EXPLORE, "ch01 starts in exploration")
	check(GameState.location.get("scene") == "factory_locker", "location stored")
	check(DialogueRunner.explore_items().size() == 4, "four locker-room items")
	check(DialogueRunner.interact("ch01_locker_door"), "locked door interacts")
	check(DialogueRunner.waiting == DialogueRunner.Wait.ADVANCE, "locked door plays a line")
	DialogueRunner.advance()
	check(DialogueRunner.waiting == DialogueRunner.Wait.EXPLORE, "back to exploring after locked line")
	check(not GameState.has_found("ch01_locker_door"), "locked item not marked found")
	DialogueRunner.interact("ch01_own_locker")
	_run_until_blocking()
	check(GameState.has_found("ch01_own_locker"), "locker found")
	check("journal.ch01.photo" in GameState.journal, "journal note collected")
	check(not DialogueRunner.interact("no_such_item"), "unknown item refused")
	DialogueRunner.interact("ch01_locker_door")
	_run_until_blocking()
	check(GameState.location.get("scene") == "factory_floor", "moved to factory floor")
	check(DialogueRunner.current_node_id == "c00", "Nevin's greeting choice")


func _to_floor_explore() -> void:
	DialogueRunner.start("ch01_last_check")
	_run_until_blocking()
	DialogueRunner.interact("ch01_own_locker")
	_run_until_blocking()
	DialogueRunner.interact("ch01_locker_door")
	_run_until_blocking()
	DialogueRunner.choose("ok")
	_run_until_blocking()


func test_explore_found_unlocks_option() -> void:
	_to_floor_explore()
	check(DialogueRunner.current_node_id == "x02", "floor exploration")
	DialogueRunner.interact("ch01_work_order")
	_run_until_blocking()
	DialogueRunner.interact("ch01_selim")
	_run_until_blocking()
	check(DialogueRunner.current_options().size() == 2, "without the list only 2 options")
	GameState.reset()
	_to_floor_explore()
	for id in ["ch01_layoff_list", "ch01_work_order", "ch01_selim"]:
		DialogueRunner.interact(id)
		_run_until_blocking()
	check(DialogueRunner.current_options().size() == 4, "seeing the list unlocks warn + hint")
	check(DecisionManager.evaluate({"found": "ch01_layoff_list"}), "found condition")


func _to_qte() -> void:
	_to_floor_explore()
	for id in ["ch01_work_order", "ch01_selim"]:
		DialogueRunner.interact(id)
		_run_until_blocking()
	DialogueRunner.choose("joke")
	_run_until_blocking()


func test_qte_press_and_fail() -> void:
	_settings_reset()
	_to_qte()
	check(DialogueRunner.waiting == DialogueRunner.Wait.QTE, "reached QTE")
	DialogueRunner.qte_press()
	check(GameState.get_decision("b1_kol_qte") == "success", "press succeeds")
	check(not GameState.get_flag("kemal_injured"), "no injury on success")
	GameState.reset()
	_to_qte()
	DialogueRunner._process(5.0)
	check(GameState.get_decision("b1_kol_qte") == "fail", "timeout fails")
	check(GameState.get_flag("kemal_injured") == true, "fail branch effect")
	check(DialogueRunner.waiting == DialogueRunner.Wait.ADVANCE, "story continues after failed QTE")
	var shown := []
	var cb := func(_s: String, key: String) -> void: shown.append(key)
	DialogueRunner.line_shown.connect(cb)
	_run_until_blocking()
	DialogueRunner.line_shown.disconnect(cb)
	check("ch01.l09_injured" in shown, "injury changes later dialogue")


func test_qte_easy_and_hold_alternative() -> void:
	SaveSystem.settings["qte_easy"] = true
	SaveSystem.settings["qte_hold_alternative"] = true
	DialogueRunner.chapter = {"id": "t", "nodes": {
		"q": {"type": "qte", "mode": "mash", "count": 8, "time": 2.0, "hold_time": 1.0,
			"success": {"next": "e"}, "fail": {"next": "e"}},
		"e": {"type": "end"}}}
	DialogueRunner._goto("q")
	check(DialogueRunner.qte["mode"] == "hold", "mash becomes hold with accessibility option")
	check(is_equal_approx(float(DialogueRunner.qte["time_total"]), 3.5), "easy mode extends time")
	check(int(DialogueRunner.qte["count"]) == 4, "easy mode halves presses")
	DialogueRunner.qte_set_holding(true)
	DialogueRunner._process(0.6)
	check(DialogueRunner.waiting == DialogueRunner.Wait.QTE, "still holding")
	DialogueRunner._process(0.6)
	check(DialogueRunner.waiting == DialogueRunner.Wait.FINISHED, "hold completes QTE")
	_settings_reset()
	DialogueRunner._goto("q")
	for i in 8:
		DialogueRunner.qte_press()
	check(DialogueRunner.waiting == DialogueRunner.Wait.FINISHED, "mash completes after count")


func test_flowchart_graph() -> void:
	DialogueRunner.start("ch00_test")
	_run_to_choice()
	DialogueRunner.choose("truth")
	_run_to_choice()
	var g := DecisionManager.build_flowchart(DialogueRunner.chapter)
	var by_id := {}
	for p: Dictionary in g["points"]:
		by_id[p["id"]] = p
	check(by_id.has("__start") and by_id.has("c01") and by_id.has("c02") and by_id.has("end"), "flowchart points")
	check(int(by_id["c01"]["layer"]) == 1 and int(by_id["c02"]["layer"]) == 2, "flowchart layers")
	check(by_id["c01"]["visited"] and by_id["c02"]["visited"] and not by_id["end"]["visited"], "visited flags")
	var truth: Dictionary = by_id["c01"]["options"][0]
	check(truth["chosen"] and "c02" in truth["targets"], "chosen edge leads to c02")
	check((by_id["c01"]["options"] as Array).size() == 4, "options include silence")


func test_resume_inside_exploration() -> void:
	SaveSystem.new_game(0)
	DialogueRunner.start(GameState.current_chapter)
	_run_until_blocking()
	DialogueRunner.interact("ch01_notice_board")
	_run_until_blocking()
	check(SaveSystem.has_save(0), "autosaved in exploration")
	GameState.reset()
	SaveSystem.load_slot(0)
	check(GameState.current_node == "x01", "resume node is the exploration")
	check(GameState.has_found("ch01_notice_board"), "found item survives save")
	check(GameState.location.get("scene") == "factory_locker", "location survives save")
	DialogueRunner.start(GameState.current_chapter, GameState.current_node)
	check(DialogueRunner.waiting == DialogueRunner.Wait.EXPLORE, "resumed into exploration")


func test_chapter1_full_playthrough() -> void:
	_settings_reset()
	_to_floor_explore()
	for id in ["ch01_robot_panel", "ch01_layoff_list", "ch01_work_order", "ch01_selim"]:
		DialogueRunner.interact(id)
		_run_until_blocking()
	DialogueRunner.choose("warn")
	_run_until_blocking()
	DialogueRunner.qte_press()
	_run_until_blocking()
	check(DialogueRunner.current_options().size() == 4, "evidence option unlocked by the panel")
	DialogueRunner.choose("evidence")
	_run_until_blocking()
	check(DialogueRunner.waiting == DialogueRunner.Wait.FINISHED, "chapter 1 finished")
	check(GameState.get_flag("selim_warned") and GameState.get_flag("fault_evidence"), "major decision flags")
	var majors := 0
	for n: Dictionary in DialogueRunner.chapter["nodes"].values():
		if n.get("major", false):
			majors += 1
	check(majors >= 2, "chapter 1 has 2+ major decisions")


func test_location_data_builds() -> void:
	const LocationBuilder = preload("res://scenes/world/location_builder.gd")
	for id in ["factory_locker", "factory_floor"]:
		var root := Node3D.new()
		add_child(root)
		GameState.location = {"player": "kemal"}
		var built := LocationBuilder.build(root, LocationBuilder.load_data(id))
		check(not (built["spawns"] as Dictionary).is_empty(), id + " has spawns")
		check(root.get_child_count() > 6, id + " built geometry")
		root.queue_free()
