extends Control
## Headless engine tests. Run:
##   godot --headless --path . res://tests/test_runner.tscn
## Exit code 0 = all passed. Uses a separate save directory.

const EndingsGallery = preload("res://ui/endings_gallery.gd")
const Credits = preload("res://ui/credits.gd")
const LocationBuilder = preload("res://scenes/world/location_builder.gd")
const ArtKit = preload("res://scenes/world/art_kit.gd")
const SoundSynth = preload("res://scenes/audio/sound_synth.gd")
const LOCATION_IDS := ["factory_locker", "factory_floor", "factory_night", "factory_gate", "port_yard",
	"family_home", "police_room"]

var _failures: Array[String] = []
var _passed := 0


func _ready() -> void:
	SaveSystem.save_dir = "user://test_saves/"
	SaveSystem.profile_path = "user://test_saves/profile.json"
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
		"test_story_index_and_majors", "test_fire_depends_on_earlier_choices", "test_rescue_options_depend_on_exam",
		"test_pov_skips_dead_character", "test_all_dead_aftermath", "test_death_visible_later",
		"test_inform_sets_informer_to_pov", "test_chapter1_links_to_chapter2",
		"test_ending_link_and_unlock", "test_profile_survives_slots", "test_epilogue_keeps_snapshots",
		"test_every_epilogue_completes", "test_epilogue_varies_by_fate", "test_betrayal_epilogue_pov",
		"test_gallery_rows", "test_credits_data",
		"test_art_locations_within_budget", "test_art_textures", "test_art_variants", "test_art_character_body",
		"test_art_low_quality", "test_art_fire_props",
		"test_audio_synth_cues", "test_audio_synth_loops", "test_audio_ids_in_data", "test_quality_governor_ladder",
		"test_chapter_card_text",
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
	if FileAccess.file_exists(SaveSystem.profile_path):
		DirAccess.remove_absolute(SaveSystem.profile_path)
	SaveSystem.load_profile()


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
	check(GameState.current_node == "r01_truth", "resume node stored")
	DialogueRunner.start(GameState.current_chapter, GameState.current_node)
	check(DialogueRunner.current_node_id == "r01_truth", "resume at saved node")
	# The autosave is written as the choice is taken, before the next node is marked
	# visited; once resumed at that node the state matches the one before the save.
	check(JSON.stringify(GameState.to_dict()) == before, "loaded state equals saved state")


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


## Advances lines and takes the first option of the untimed stage-8 side-story
## choices (ids starting with "s8"): they only set side flags, so the tests
## written for the core path can step over them.
func _run_until_blocking() -> void:
	var guard := 0
	while guard < 2000:
		guard += 1
		if DialogueRunner.waiting == DialogueRunner.Wait.ADVANCE:
			DialogueRunner.advance()
		elif DialogueRunner.waiting == DialogueRunner.Wait.CHOICE and DialogueRunner.current_node_id.begins_with("s8"):
			DialogueRunner.choose(str(DialogueRunner.current_options()[0]["id"]))
		else:
			break


func test_explore_locked_and_exit() -> void:
	DialogueRunner.start("ch01_last_check")
	_run_until_blocking()
	check(DialogueRunner.waiting == DialogueRunner.Wait.EXPLORE, "ch01 starts in exploration")
	check(GameState.location.get("scene") == "factory_locker", "location stored")
	check(DialogueRunner.explore_items().size() == 6, "six locker-room items")
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
	for id in ["factory_locker", "factory_floor"]:
		var root := Node3D.new()
		add_child(root)
		GameState.location = {"player": "kemal"}
		var built := LocationBuilder.build(root, LocationBuilder.load_data(id))
		check(not (built["spawns"] as Dictionary).is_empty(), id + " has spawns")
		check(root.get_child_count() > 6, id + " built geometry")
		root.queue_free()


# --- Stage 4: chapters 2-8, cross-chapter consequences ----------------------------

func _collect_lines(callable_to_run: Callable) -> Array:
	var shown := []
	var cb := func(_s: String, key: String) -> void: shown.append(key)
	DialogueRunner.line_shown.connect(cb)
	callable_to_run.call()
	DialogueRunner.line_shown.disconnect(cb)
	return shown


func test_story_index_and_majors() -> void:
	check(SaveSystem.chapter_order.size() == 8, "eight story chapters")
	check(SaveSystem.first_chapter_id() == "ch01_last_check", "new game starts at chapter 1")
	for c: Dictionary in SaveSystem.chapter_order:
		var data := DialogueRunner.load_chapter_data(str(c["id"]))
		var majors := 0
		for n: Dictionary in data["nodes"].values():
			if n.get("type", "") == "choice" and n.get("major", false):
				majors += 1
		check(majors >= 2, str(c["id"]) + " has 2+ major decisions")


func test_fire_depends_on_earlier_choices() -> void:
	DialogueRunner.start("ch05_night_shift")
	check(GameState.get_flag("fire_started") == false, "no hidden fault, no delivered cargo: no fire")
	check(DialogueRunner.current_node_id == "s8a_01", "night shift starts (at home, stage 8 opening)")
	GameState.reset()
	GameState.set_flag("fault_hidden", true)
	DialogueRunner.start("ch05_night_shift")
	check(GameState.get_flag("fire_started") == true, "hidden fault from chapter 1 starts the fire")
	_run_until_blocking()
	check(DialogueRunner.waiting == DialogueRunner.Wait.EXPLORE and DialogueRunner.current_node_id == "fx", "fire exploration")


func test_rescue_options_depend_on_exam() -> void:
	GameState.set_flag("cargo_delivered", true)
	DialogueRunner.start("ch05_night_shift")
	_run_until_blocking()
	DialogueRunner.interact("ch05_go")
	var ids := []
	for o: Dictionary in DialogueRunner.current_options():
		ids.append(o["id"])
	check(ids == ["save_defne", "save_selim"], "Defne inside: save Defne or Selim")
	GameState.reset()
	GameState.set_flag("cargo_delivered", true)
	GameState.set_flag("defne_chose_exam", true)
	DialogueRunner.start("ch05_night_shift")
	_run_until_blocking()
	DialogueRunner.interact("ch05_go")
	ids = []
	for o: Dictionary in DialogueRunner.current_options():
		ids.append(o["id"])
	check(ids == ["save_selim", "go_out"], "Defne at the exam: Selim or get out")
	DialogueRunner.force_timeout()
	check(GameState.get_status("kemal") == "dead", "hesitating costs Kemal his life")


func test_pov_skips_dead_character() -> void:
	GameState.set_status("riza", "dead")
	DialogueRunner.start("ch06_informant")
	check(GameState.get_flag("pov") == "defne", "Rıza dead: chapter 6 seen through Defne")
	check(GameState.location.get("player") == "defne", "Defne is in control")
	GameState.reset()
	GameState.set_status("defne", "dead")
	DialogueRunner.start("ch08_last_shift")
	_run_until_blocking()
	check(GameState.get_flag("pov") == "kemal", "Defne dead: chapter 8 seen through Kemal")


func test_all_dead_aftermath() -> void:
	for c in GameState.CHARACTERS:
		GameState.set_status(c, "dead")
	var shown := _collect_lines(func() -> void:
		DialogueRunner.start("ch06_informant")
		_run_until_blocking())
	check("ch06.a01" in shown, "the story continues without anyone to control")
	check(DialogueRunner.waiting == DialogueRunner.Wait.FINISHED, "chapter 6 completes with nobody alive")
	check(DecisionManager.resolve_ending()["ending"] == "bitter_reckoning", "all dead -> Bitter Reckoning")


func test_death_visible_later() -> void:
	GameState.set_status("kemal", "dead")
	GameState.set_flag("selim_dead", true)
	var shown := _collect_lines(func() -> void:
		DialogueRunner.start("ch07_reckoning")
		_run_until_blocking())
	check("ch07.dl_k" in shown, "Kemal's death is mentioned in chapter 7")
	check("ch07.rc1" in shown, "Selim's death is mentioned in chapter 7")
	check(GameState.location.get("player") == "defne", "Defne leads chapter 7")


func test_inform_sets_informer_to_pov() -> void:
	DialogueRunner.start("ch06_informant")
	_run_until_blocking()
	DialogueRunner.interact("ch06_komiser")
	_run_until_blocking()
	check(DialogueRunner.choose("inform"), "inform option available")
	check(GameState.get_flag("informer") == "riza", "Rıza (POV) is the informer")
	var k_trust := GameState.get_trust("kemal", "riza")
	check(k_trust == -3 and GameState.get_trust("defne", "riza") == -3, "others lose trust in the informer")
	check(GameState.get_trust("riza", "kemal") == 0, "informer's own trust unchanged")
	check(DecisionManager.resolve_ending()["ending"] == "betrayal", "informing -> Betrayal ending")


func test_chapter1_links_to_chapter2() -> void:
	var data := DialogueRunner.load_chapter_data("ch01_last_check")
	check(data["nodes"]["end"]["next_chapter"] == "ch02_strike", "chapter 1 continues to chapter 2")
	GameState.set_flag("selim_warned", true)
	var shown := _collect_lines(func() -> void:
		DialogueRunner.start("ch02_strike")
		_run_until_blocking())
	check("ch02.l03" in shown, "warning Selim in chapter 1 changes chapter 2")


# --- Stage 5: endings, epilogues, gallery, credits ---------------------------

func _trust_all(delta: int) -> void:
	for a in GameState.CHARACTERS:
		for b in GameState.CHARACTERS:
			if a != b:
				GameState.add_trust(a, b, delta)


## Plays the current chapter to its end: advance lines, take the exit item of
## every exploration, pick the first option of every choice, pass every QTE.
func _play_to_end(first_option: bool = true) -> void:
	var guard := 0
	while DialogueRunner.waiting != DialogueRunner.Wait.FINISHED and guard < 5000:
		guard += 1
		var w: int = DialogueRunner.waiting
		if w == DialogueRunner.Wait.ADVANCE:
			DialogueRunner.advance()
		elif w == DialogueRunner.Wait.EXPLORE:
			for it: Dictionary in DialogueRunner.explore_items():
				if it.has("next"):
					DialogueRunner.interact(str(it["id"]))
					break
		elif w == DialogueRunner.Wait.CHOICE:
			var opts := DialogueRunner.current_options()
			DialogueRunner.choose(str(opts[0 if first_option else opts.size() - 1]["id"]))
		elif w == DialogueRunner.Wait.QTE:
			DialogueRunner.force_qte_result(true)
		else:
			break


func _setup_ending(id: String) -> void:
	if id == "solidarity":
		_trust_all(3)
	elif id == "bitter_reckoning":
		GameState.set_status("riza", "dead")
	elif id == "betrayal":
		GameState.set_flag("informer", "defne")
	elif id == "secret":
		GameState.set_flag("final_silence", true)
		GameState.add_counter("silence", 6)


func test_ending_link_and_unlock() -> void:
	var ch8 := DialogueRunner.load_chapter_data("ch08_last_shift")
	check(ch8["nodes"]["end"]["next_chapter"] == "@ending", "chapter 8 ends with @ending")
	_trust_all(3)
	var ending := DecisionManager.resolve_and_unlock_ending()
	check(ending["ending"] == "solidarity", "high trust resolves to solidarity")
	check(ending["epilogue"] == "ep01_solidarity", "solidarity plays its own epilogue")
	check(GameState.get_flag("ending") == "solidarity", "ending stored in the story flags")
	check(ending["new"] == true, "first time: newly unlocked")
	check(DecisionManager.resolve_and_unlock_ending()["new"] == false, "second time: not new")
	for id: String in DecisionManager.ending_ids():
		var d := DecisionManager.ending_details(id)
		check(SaveSystem.is_epilogue(str(d["epilogue"])), "ending %s has a listed epilogue" % id)
		check(not Localization.t(str(d["hint"])).begins_with("["), "ending %s has a gallery hint" % id)


func test_profile_survives_slots() -> void:
	SaveSystem.new_game(0)
	SaveSystem.unlock_ending("betrayal")
	SaveSystem.delete_slot(0)
	SaveSystem.load_profile()
	check(SaveSystem.is_ending_unlocked("betrayal"), "unlocked ending survives deleting the slot")
	check(not SaveSystem.is_ending_unlocked("secret"), "other endings stay locked")
	SaveSystem.new_game(1)
	check(SaveSystem.is_ending_unlocked("betrayal"), "unlocked ending survives a new game")


func test_epilogue_keeps_snapshots() -> void:
	SaveSystem.new_game(0)
	SaveSystem.begin_chapter("ch02_strike")
	SaveSystem.begin_chapter("ep02_separation")
	check(SaveSystem.chapter_snapshots.has("ch01_last_check") and SaveSystem.chapter_snapshots.has("ch02_strike"),
		"starting an epilogue keeps every story snapshot")
	check(SaveSystem.chapter_info("ep02_separation").get("title", "") == "ep02.title", "epilogue has slot-menu info")
	SaveSystem.begin_chapter("ch02_strike")
	check(not SaveSystem.chapter_snapshots.has("ep02_separation"), "replaying a story chapter drops the epilogue snapshot")


func test_every_epilogue_completes() -> void:
	for id: String in ["solidarity", "separation", "bitter_reckoning", "betrayal", "secret"]:
		for first: bool in [true, false]:
			GameState.reset()
			_setup_ending(id)
			var ending := DecisionManager.resolve_and_unlock_ending()
			check(ending["ending"] == id, "setup reaches " + id)
			check(DialogueRunner.start(str(ending["epilogue"])), "epilogue starts: " + id)
			check(GameState.is_alive(str(GameState.location.get("player", ""))) or GameState.location.get("scene", "") == "",
				"epilogue camera follows a living character: " + id)
			_play_to_end(first)
			check(DialogueRunner.waiting == DialogueRunner.Wait.FINISHED, "epilogue finishes: %s (%s)" % [id, first])


func test_epilogue_varies_by_fate() -> void:
	GameState.set_status("kemal", "dead")
	GameState.set_status("riza", "missing")
	var shown := _collect_lines(func() -> void:
		DialogueRunner.start("ep03_bitter")
		_run_until_blocking())
	check("ep03.f_kemal_v1" in shown, "bitter epilogue: Kemal's death line")
	check("ep03.f_defne" in shown, "bitter epilogue: Defne's survivor line")
	check("ep03.f_riza_v2" in shown, "bitter epilogue: Rıza missing line")
	check(GameState.location.get("player") == "defne", "Defne leads the bitter epilogue")
	GameState.reset()
	for c in GameState.CHARACTERS:
		GameState.set_status(c, "dead")
	shown = _collect_lines(func() -> void:
		DialogueRunner.start("ep03_bitter")
		_run_until_blocking())
	check("ep03.n01" in shown or "ep03.n01_v1" in shown, "nobody alive: Nevin closes the story")
	check(DialogueRunner.waiting == DialogueRunner.Wait.FINISHED, "all-dead epilogue completes")


func test_betrayal_epilogue_pov() -> void:
	GameState.set_flag("informer", "kemal")
	DialogueRunner.start("ep04_betrayal")
	check(GameState.location.get("player") == "kemal", "the informer leads the betrayal epilogue")
	GameState.reset()
	GameState.set_flag("informer", "kemal")
	GameState.set_status("kemal", "missing")
	var shown := _collect_lines(func() -> void:
		DialogueRunner.start("ep04_betrayal")
		_run_until_blocking())
	check("ep04.n01" in shown, "informer gone: narrated card instead of a scene")


func test_gallery_rows() -> void:
	_cleanup_saves()  # earlier tests unlock endings in the shared test profile
	SaveSystem.unlock_ending("separation")
	var gallery := EndingsGallery.new()
	var rows := gallery.rows()
	gallery.free()
	check(rows.size() == 5, "gallery lists five endings")
	for r: Dictionary in rows:
		if r["id"] == "separation":
			check(r["unlocked"] and r["title"] == Localization.t("ending.separation.title"), "unlocked ending shows its title")
		else:
			check(not r["unlocked"] and r["title"] == Localization.t("gallery.locked"), "locked ending hidden: " + str(r["id"]))


func test_credits_data() -> void:
	var sections := Credits.load_sections()
	check(sections.size() >= 5, "credits loaded")
	check(Credits.display_name("credits.thanks_name") == Localization.t("credits.thanks_name"), "credit keys are translated")
	check(Credits.display_name("NexDrive Game Studio") == "NexDrive Game Studio", "proper names are kept")


# --- Stage 6: art pass ------------------------------------------------------------

func _build_location(id: String) -> Array:
	var root := Node3D.new()
	add_child(root)
	GameState.location = {"player": "kemal"}
	var built := LocationBuilder.build(root, LocationBuilder.load_data(id))
	return [root, built]


func _count(node: Node, type_name: String) -> int:
	var n := 1 if node.is_class(type_name) else 0
	for c in node.get_children():
		n += _count(c, type_name)
	return n


func test_art_locations_within_budget() -> void:
	SaveSystem.settings["visual_quality"] = "high"
	for id: String in LOCATION_IDS:
		var r := _build_location(id)
		var root: Node3D = r[0]
		var stats: Dictionary = r[1]["stats"]
		check(int(stats["meshes"]) >= 3 and int(stats["meshes"]) <= 10, id + " merged into 3-10 material batches")
		check(int(stats["vertices"]) < 80000, id + " vertex budget (%d)" % int(stats["vertices"]))
		check(int(stats["lights"]) <= 4, id + " omni light budget")
		# Static geometry + effects, excluding character bodies (5 meshes each).
		var meshes := _count(root, "MeshInstance3D") - 5 * (r[1]["actors"] as Dictionary).size()
		check(meshes <= 24, id + " draw-call budget (%d mesh instances)" % meshes)
		check(_count(root, "DirectionalLight3D") <= 1, id + " one sun")
		root.free()


func test_art_textures() -> void:
	for id: String in ArtKit.SURFACES:
		var tex := ArtKit.detail_texture(id)
		check(tex.get_width() == ArtKit.TEX_SIZE and tex.get_height() == ArtKit.TEX_SIZE, id + " texture is 512 px")
	var first := ArtKit.detail_texture("concrete")
	var second := ArtKit.detail_texture("concrete")
	check(first == second, "textures are cached")
	var glow := ArtKit.material("glow") as StandardMaterial3D
	check(glow.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "glow material is unshaded")
	var concrete := ArtKit.material("concrete") as StandardMaterial3D
	check(concrete.uv1_triplanar and concrete.albedo_texture != null, "concrete uses triplanar detail")


func test_art_variants() -> void:
	var raw := LocationBuilder.load_data("factory_floor")
	check(str(LocationBuilder.resolve_variants(raw)["background"]) == str(raw["background"]), "no variant by default")
	GameState.set_flag("ending", "solidarity")
	check(str(LocationBuilder.resolve_variants(raw)["background"]) == "#1b1f24", "solidarity epilogue lighting")
	var home := LocationBuilder.load_data("family_home")
	GameState.set_flag("ending", "secret")
	var lit: Array = LocationBuilder.resolve_variants(home)["lights"]
	check(lit.size() == 1 and str(lit[0].get("flicker", "")) == "fire", "secret ending: candle light only")
	GameState.set_flag("ending", "")


func test_art_character_body() -> void:
	for id: String in LocationBuilder.characters():
		var body := LocationBuilder.make_body(id)
		add_child(body)
		check(_count(body, "MeshInstance3D") == 5, id + " body has 5 meshes")
		body.call("set_motion", 2.3)
		body.call("_process", 0.25)
		var moved := false
		for c in body.get_children():
			if not c is MeshInstance3D and absf((c as Node3D).rotation.x) > 0.01:
				moved = true
		check(moved, id + " limbs swing when walking")
		body.call("talk")
		body.call("set_motion", 0.0)
		body.call("_process", 0.5)
		body.free()


func test_art_low_quality() -> void:
	SaveSystem.settings["visual_quality"] = "low"
	GameState.set_flag("fire_started", true)
	var r := _build_location("factory_night")
	var root: Node3D = r[0]
	check(_count(root, "CPUParticles3D") == 0, "low quality: no particles")
	check(_count(root, "CanvasLayer") == 0, "low quality: no vignette")
	var shadows := false
	for c in root.get_children():
		if c is DirectionalLight3D and (c as DirectionalLight3D).shadow_enabled:
			shadows = true
	check(not shadows, "low quality: no realtime shadow")
	root.free()
	SaveSystem.settings["visual_quality"] = "high"


func test_art_fire_props() -> void:
	SaveSystem.settings["visual_quality"] = "high"
	var r := _build_location("factory_night")
	var root: Node3D = r[0]
	var before := 0
	for c in root.get_children():
		if str(c.name).contains("Fire"):
			before += 1
	check(before == 0, "no fire before fire_started")
	root.free()
	GameState.set_flag("fire_started", true)
	r = _build_location("factory_night")
	root = r[0]
	var fires := 0
	for c in root.get_children():
		if str(c.name).contains("Fire"):
			fires += 1
	check(fires == 2, "two fire sheets when fire_started")
	check(root.find_child("Ambience", false, false) != null, "fire is animated")
	check(_count(root, "CPUParticles3D") == 4, "embers + smoke per fire")
	root.free()


# --- Stage 7: audio, performance guard, chapter cards -----------------------------------

func test_audio_synth_cues() -> void:
	for cue_name: String in SoundSynth.CUES:
		var wav := SoundSynth.cue(cue_name)
		check(wav != null and wav.data.size() > 200, cue_name + " renders")
		check(wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED, cue_name + " is a one-shot")
		check(wav != null and wav.get_length() < 1.2, cue_name + " is short")
	check(SoundSynth.cue("ui/unknown") == null, "unknown cue -> null")


func test_audio_synth_loops() -> void:
	var amb := SoundSynth.ambience("room")
	check(amb.loop_mode == AudioStreamWAV.LOOP_FORWARD, "ambience loops")
	check(absf(amb.get_length() - SoundSynth.AMB_SEC) < 0.05, "ambience loop length")
	var music := SoundSynth.music("calm")
	check(music.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music loops")
	check(absf(music.get_length() - SoundSynth.MUSIC_SEC) < 0.05, "music loop length")
	# Seamless: first and last samples are close (no click at the loop point).
	var first := music.data.decode_s16(0)
	var last := music.data.decode_s16(music.data.size() - 2)
	check(absi(first - last) < 2500, "music loop point has no jump (%d vs %d)" % [first, last])


func test_audio_ids_in_data() -> void:
	for id: String in LOCATION_IDS:
		var amb := str(LocationBuilder.load_data(id).get("ambience", ""))
		check(amb in SoundSynth.AMBIENCES, id + " ambience '%s' is synthesisable" % amb)
	for c: Dictionary in SaveSystem.chapter_order + SaveSystem.epilogues:
		check(str(c.get("music", "")) in SoundSynth.MUSIC, str(c["id"]) + " music is synthesisable")


func test_quality_governor_ladder() -> void:
	var saved := SaveSystem.settings.duplicate()
	SaveSystem.settings["visual_quality"] = "high"
	SaveSystem.settings["render_scale"] = 1.0
	check(PerfMonitor.step_down() == "effects", "governor: effects first")
	check(str(SaveSystem.settings["visual_quality"]) == "low", "governor: quality low")
	check(PerfMonitor.step_down() == "resolution", "governor: then resolution")
	check(is_equal_approx(get_tree().root.scaling_3d_scale, 0.85), "render scale applied (85 %)")
	PerfMonitor.step_down()
	check(PerfMonitor.step_down() == "", "governor: stops at the bottom")
	check(is_equal_approx(float(SaveSystem.settings["render_scale"]), 0.7), "bottom is 70 %")
	for k: String in saved:
		SaveSystem.set_setting(k, saved[k])


func test_chapter_card_text() -> void:
	check(Localization.t("card.chapter", {"n": 3}) == "Bölüm 3", "chapter card TR")
	Localization.set_locale("en")
	check(Localization.t("card.chapter", {"n": 3}) == "Chapter 3", "chapter card EN")
	Localization.set_locale("tr")
	for c: Dictionary in SaveSystem.chapter_order:
		check(not Localization.t(str(c["title"])).begins_with("["), str(c["id"]) + " has a title")
