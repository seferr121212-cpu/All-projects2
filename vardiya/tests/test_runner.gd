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
