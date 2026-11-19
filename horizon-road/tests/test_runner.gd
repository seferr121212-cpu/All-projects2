extends Node
## Headless logic tests. Run:
##   godot --headless --path . res://tests/test_runner.tscn
## Exits with code 1 if any check fails.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_test_time()
	_test_weather()
	_test_save_roundtrip()
	_test_money()
	_test_translations()
	_test_photo_scoring()
	_test_album()
	_test_dialogue_data()
	_test_dialogue_flow()
	_test_relationships()
	_test_upgrades_and_fuel()
	_test_rest()
	_test_full_save()
	print("[tests] %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("[tests] FAIL: ", label)


func _test_time() -> void:
	var days_seen: Array[int] = []
	var on_day := func(d: int) -> void: days_seen.append(d)
	TimeManager.day_changed.connect(on_day)
	TimeManager.paused = true
	TimeManager.day = 1
	TimeManager.set_time(23.5)
	TimeManager.advance_hours(1.0)
	_check(is_equal_approx(TimeManager.time_of_day, 0.5), "time wraps past midnight")
	_check(TimeManager.day == 2 and days_seen == [2], "day_changed emitted once")
	TimeManager.day_changed.disconnect(on_day)
	TimeManager.set_time(13.0)
	_check(TimeManager.get_sun_height() > 0.7, "sun high at 13:00")
	TimeManager.set_time(2.0)
	_check(TimeManager.get_sun_height() < -0.2, "sun below horizon at 02:00")
	_check(TimeManager.get_night_factor() > 0.99, "night factor at 02:00")
	_check(TimeManager.get_phase(19.0) == TimeManager.DayPhase.GOLDEN_HOUR, "19:00 is golden hour")
	# Sun direction must be continuous through the whole day (no light jumps).
	var prev: Vector3 = TimeManager.get_sun_direction(0.0)
	var max_step: float = 0.0
	for i: int in range(1, 24 * 20 + 1):
		var d: Vector3 = TimeManager.get_sun_direction(i / 20.0)
		max_step = maxf(max_step, prev.angle_to(d))
		prev = d
	_check(max_step < deg_to_rad(5.0), "sun path continuous (max step %.2f deg)" % rad_to_deg(max_step))
	TimeManager.day_length_minutes = 14.0
	TimeManager.time_scale = 1.0
	_check(is_equal_approx(TimeManager.hours_per_second() * 14.0 * 60.0, 24.0), "day length 14 min")


func _test_weather() -> void:
	_check(WeatherManager.profiles.size() == 6, "6 weather profiles loaded")
	WeatherManager.set_weather(&"rain", 0.0)
	_check(is_equal_approx(WeatherManager.current.rain, WeatherManager.profiles[&"rain"].rain), "instant weather switch")
	WeatherManager.set_weather(&"clear", 1.0)
	WeatherManager._update_blend(0.5)
	var mid: float = WeatherManager.current.rain
	_check(mid > 0.05 and mid < WeatherManager.profiles[&"rain"].rain, "weather blends gradually (rain=%.2f)" % mid)
	WeatherManager._update_blend(1.0)
	_check(is_zero_approx(WeatherManager.current.rain), "blend completes")
	WeatherManager.configure_for_region({&"fog": 1.0}, &"")
	_check(WeatherManager.target_id == &"fog", "region weights respected")
	WeatherManager.configure_for_region({&"not_a_weather": 1.0}, &"")
	_check(WeatherManager.target_id == &"clear", "unknown weathers fall back to clear")


func _test_save_roundtrip() -> void:
	GameState.money = 345
	TimeManager.set_time(17.25)
	TimeManager.day = 4
	WeatherManager.set_weather(&"partly_cloudy", 0.0)
	_check(SaveManager.save_game("test_slot"), "save succeeds")
	GameState.money = 0
	TimeManager.set_time(3.0)
	TimeManager.day = 1
	WeatherManager.set_weather(&"storm", 0.0)
	_check(SaveManager.load_game("test_slot"), "load succeeds")
	_check(GameState.money == 345, "money restored")
	_check(is_equal_approx(TimeManager.time_of_day, 17.25) and TimeManager.day == 4, "time restored")
	_check(WeatherManager.target_id == &"partly_cloudy", "weather restored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/test_slot.json"))


func _test_money() -> void:
	GameState.money = 10
	_check(not GameState.spend_money(20), "cannot overspend")
	_check(GameState.spend_money(10) and GameState.money == 0, "spend exact amount")


func _test_translations() -> void:
	TranslationServer.set_locale("tr")
	_check(tr(&"WEATHER_FOG") == "Sis", "TR translation")
	TranslationServer.set_locale("en")
	_check(tr(&"WEATHER_FOG") == "Fog", "EN translation")


func _test_photo_scoring() -> void:
	var config := PhotoConfig.new()
	var size: Vector2 = get_viewport().get_visible_rect().size
	_check(size.x > 0 and size.y > 0, "viewport has a size for projection")
	var cam := Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.global_transform = Transform3D(Basis(), Vector3(5000, 50, 5000))
	var subject := PhotoSubject.new()
	subject.subject_id = &"TEST_SUBJECT"
	subject.name_key = "SUBJ_COW"
	subject.category = PhotoSubject.Category.ANIMAL
	subject.radius = 3.0
	subject.value = 0.8
	add_child(subject)
	# Subject straight ahead, centred.
	subject.global_position = Vector3(5000, 50, 4980)
	var centred: Dictionary = PhotoScorer.evaluate(cam, 20.0, 0.0, config)
	_check(not (centred.main as Dictionary).is_empty() and centred.main.id == &"TEST_SUBJECT", "subject in frame is detected")
	# Same subject moved onto a thirds intersection.
	var half_h: float = tan(deg_to_rad(30.0)) * 20.0
	var half_w: float = half_h * size.x / size.y
	subject.global_position = Vector3(5000 - half_w / 3.0, 50 + half_h / 3.0, 4980)
	var thirds: Dictionary = PhotoScorer.evaluate(cam, 20.0, 0.0, config)
	_check(thirds.composition > centred.composition + 0.2, "thirds placement beats centre (%.2f vs %.2f)" % [thirds.composition, centred.composition])
	# Behind the camera: not seen.
	subject.global_position = Vector3(5000, 50, 5020)
	var behind: Dictionary = PhotoScorer.evaluate(cam, 20.0, 0.0, config)
	_check((behind.main as Dictionary).is_empty(), "subject behind camera ignored")
	# Out of focus with a wide aperture.
	subject.global_position = Vector3(5000, 50, 4980)
	var soft: Dictionary = PhotoScorer.evaluate(cam, 120.0, 0.2, config)
	_check(soft.focus < 0.5, "wide aperture focused far away -> soft subject")
	_check(PhotoScorer.final_score(soft, 1.0, config) >= config.min_score, "score never below minimum")
	var dark := Image.create(64, 36, false, Image.FORMAT_RGB8)
	dark.fill(Color(0.02, 0.02, 0.02))
	_check(PhotoScorer.rate_exposure(dark).feedback == "PHOTO_FB_TOO_DARK", "dark image flagged")
	subject.queue_free()
	cam.queue_free()


func _test_album() -> void:
	var album := PhotoAlbum.new()
	album.load_index()
	var before: int = album.entries.size()
	var img := Image.create(640, 360, false, Image.FORMAT_RGB8)
	img.fill(Color(0.4, 0.5, 0.6))
	var entry: Dictionary = album.add_photo(img, {"score": 50, "subject_list": [{"id": "TEST_ALBUM_SUBJECT", "name_key": "SUBJ_COW", "category": 1}]})
	_check(FileAccess.file_exists(entry.path) and FileAccess.file_exists(entry.thumb), "photo and thumbnail written")
	var reloaded := PhotoAlbum.new()
	reloaded.load_index()
	_check(reloaded.entries.size() == before + 1, "album index persists")
	_check(reloaded.is_discovered(&"TEST_ALBUM_SUBJECT"), "discovery persists")
	reloaded.remove_photo(reloaded.entries[reloaded.entries.size() - 1])
	reloaded.discovered.erase("TEST_ALBUM_SUBJECT")
	reloaded.save_index()
	_check(not FileAccess.file_exists(entry.path), "photo removed")


func _test_dialogue_data() -> void:
	for path: String in ["res://data/npcs/fadime.json"]:
		var data: Dictionary = DialogueRunner.load_data(path)
		_check(not data.is_empty(), "%s parses" % path)
		var nodes: Dictionary = data.nodes
		var bad_refs: Array = []
		var keys: Array = [data.name_key, data.role_key, data.note_key]
		for id: String in nodes:
			var n: Dictionary = nodes[id]
			if n.has("text"):
				keys.append(n.text)
			for ref: String in _refs(n):
				if not nodes.has(ref):
					bad_refs.append("%s->%s" % [id, ref])
			for c: Dictionary in n.get("choices", []):
				keys.append(c.text)
		for target: String in (data.photo_reactions as Dictionary).values():
			if not nodes.has(target):
				bad_refs.append("photo_reactions->" + target)
		_check(bad_refs.is_empty(), "%s: all node references exist %s" % [path.get_file(), bad_refs])
		var missing: Array = []
		for locale: String in ["tr", "en"]:
			TranslationServer.set_locale(locale)
			for key: String in keys:
				if TranslationServer.translate(key) == key:
					missing.append("%s:%s" % [locale, key])
		_check(missing.is_empty(), "%s: every line translated in TR+EN %s" % [path.get_file(), missing])
	TranslationServer.set_locale("en")


func _refs(n: Dictionary) -> Array:
	var out: Array = []
	if n.has("next"):
		out.append(n.next)
	for b: Dictionary in n.get("branches", []):
		out.append(b.next)
	for c: Dictionary in n.get("choices", []):
		if c.has("next"):
			out.append(c.next)
	return out


func _test_dialogue_flow() -> void:
	GameState.flags = {}
	GameState.relationships = {}
	GameState.people = {}
	GameState.player_name = ""
	var data: Dictionary = DialogueRunner.load_data("res://data/npcs/fadime.json")
	var runner := DialogueRunner.new(data, self)
	var lines: Array[String] = []
	var asked_name: Array[bool] = [false]
	var choice_log: Array = []
	runner.line_shown.connect(func(t: String) -> void: lines.append(t))
	runner.name_requested.connect(func(_t: String) -> void: asked_name[0] = true)
	runner.choices_shown.connect(func(c: Array[Dictionary]) -> void: choice_log.append(c.map(func(x: Dictionary) -> String: return x.text)))
	runner.start()
	_check(runner.current_id == "intro", "first meeting starts with intro")
	runner.advance()
	_check(asked_name[0], "intro asks the player's name")
	_check(GameState.has_flag("fadime.met") and GameState.people.has("fadime"), "meeting registers the person")
	TranslationServer.set_locale("tr")
	runner.submit_name("  Deniz  ")
	_check(GameState.player_name == "Deniz", "name trimmed and stored")
	_check(lines[lines.size() - 1].contains("Deniz"), "NPC addresses player by name")
	runner.advance()
	_check(runner.current_id == "hub", "reaches hub")
	runner.advance()  # hub line read -> choices appear
	_check(not choice_log.is_empty(), "hub offers choices")
	var offered: Array = choice_log[choice_log.size() - 1] if not choice_log.is_empty() else []
	_check(not "FADIME_CH_TIP" in offered, "tips locked for strangers")
	GameState.add_relationship(&"fadime", 60)
	var again := DialogueRunner.new(data, self)
	again.start()
	_check(again.current_id == "greet_friend", "friends get a warmer greeting")
	# Photo pricing: loved subject pays more than other subjects.
	var loved: Dictionary = {"value": 40, "subject_list": [{"id": "SUBJ_TEA_GARDEN"}]}
	var other: Dictionary = {"value": 40, "subject_list": [{"id": "SUBJ_HIGHLAND_LAKE"}]}
	_check(again.photo_price(loved) > again.photo_price(other), "loved photos sell for more")
	GameState.set_counter("fadime.photo_sale_day", TimeManager.day)
	GameState.set_counter("fadime.photo_sales", 1)
	again.choose_photo(other)
	_check(again.current_id == "photo_limit", "one photo sale per day")
	TranslationServer.set_locale("en")


func _test_relationships() -> void:
	GameState.relationships = {}
	_check(GameState.get_relationship_level(&"x") == 0, "stranger by default")
	GameState.add_relationship(&"x", 20)
	_check(GameState.get_relationship_level(&"x") == 1, "acquaintance at 20")
	GameState.add_relationship(&"x", 80)
	_check(GameState.get_relationship_level(&"x") == 3, "close friend at 100")
	GameState.add_relationship(&"x", -500)
	_check(GameState.get_relationship(&"x") == 0, "points never negative")


func _test_upgrades_and_fuel() -> void:
	GameState.upgrades = {}
	GameState.relationships = {}
	GameState.money = 1000
	_check(UpgradeCatalog.all().size() >= 6, "upgrade catalog loads")
	var price: int = GameState.upgrade_price("engine")
	_check(price == int(UpgradeCatalog.find("engine").levels[0].price), "first engine level price")
	_check(GameState.buy_upgrade("engine") and GameState.get_upgrade_level("engine") == 1, "buy engine level 1")
	_check(GameState.upgrade_effect("engine", "speed_mult", 1.0) > 1.0, "engine raises top speed")
	_check(GameState.money == 1000 - price, "upgrade charged")
	GameState.add_relationship(&"recep", 60)
	var friend_price: int = GameState.upgrade_price("engine", &"recep")
	_check(friend_price < GameState.upgrade_price("engine"), "friend discount applies")
	GameState.buy_upgrade("engine")
	_check(GameState.upgrade_price("engine") == -1 and not GameState.buy_upgrade("engine"), "maxed upgrade can't be bought")
	GameState.money = 0
	_check(not GameState.buy_upgrade("tyres"), "can't buy without money")
	GameState.buy_upgrade("lens")
	GameState.money = 500
	GameState.buy_upgrade("lens")
	_check(GameState.lens_level == 1, "lens upgrade sets lens level")
	var base_cap: float = GameState.get_tank_capacity()
	GameState.buy_upgrade("fuel_tank")
	_check(GameState.get_tank_capacity() > base_cap, "bigger tank")
	GameState.fuel = 10.0
	GameState.use_fuel(25.0)
	_check(GameState.fuel == 0.0, "fuel never negative")
	GameState.money = 30
	var liters: float = GameState.refuel()
	_check(liters == floorf(30.0 / GameState.ECONOMY.fuel_price_per_liter) and GameState.money >= 0, "refuel limited by wallet (%.0f l)" % liters)
	GameState.money = 1000
	GameState.refuel()
	_check(is_equal_approx(GameState.fuel, GameState.get_tank_capacity()), "refuel fills the tank")


func _test_rest() -> void:
	_check(is_equal_approx(RestMenu.hours_until(22.0, 7.0), 9.0), "22:00 -> 07:00 is 9 h")
	_check(is_equal_approx(RestMenu.hours_until(5.0, 7.0), 2.0), "05:00 -> 07:00 is 2 h")
	_check(is_equal_approx(RestMenu.hours_until(7.0, 7.0), 24.0), "07:00 -> next 07:00")
	TimeManager.day = 3
	TimeManager.set_time(23.0)
	RestMenu.apply_rest(RestMenu.hours_until(23.0, 7.0))
	_check(TimeManager.day == 4 and is_equal_approx(TimeManager.time_of_day, 7.0), "sleeping overnight wakes next day at 07:00")
	_check(SaveManager.has_save(SaveManager.AUTOSAVE_SLOT), "resting autosaves")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/autosave.json"))


func _test_full_save() -> void:
	var participant := _SaveProbe.new()
	add_child(participant)
	participant.value = 42
	GameState.upgrades = {"tyres": 1}
	GameState.fuel = 12.5
	_check(SaveManager.save_game("full_test"), "full save")
	participant.value = 0
	GameState.upgrades = {}
	GameState.fuel = 0.0
	SaveManager.load_game("full_test")
	_check(participant.value == 42, "scene participants restored")
	_check(GameState.get_upgrade_level("tyres") == 1 and is_equal_approx(GameState.fuel, 12.5), "upgrades and fuel restored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/full_test.json"))
	participant.queue_free()


class _SaveProbe extends Node:
	var value: int = 0

	func _ready() -> void:
		add_to_group(&"save_participant")

	func save_key() -> String:
		return "probe"

	func to_save() -> Dictionary:
		return {"value": value}

	func from_save(data: Dictionary) -> void:
		value = int(data.value)
