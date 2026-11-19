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
	_test_drawing()
	_test_regions_and_seasons()
	_test_net_haul()
	_test_new_regions()
	_test_minigames()
	_test_herding()
	_test_cafe()
	_test_asset_overrides()
	_test_quests()
	_test_story()
	_test_translation_coverage()
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
	for path: String in ["res://data/npcs/fadime.json", "res://data/npcs/recep.json", "res://data/npcs/hasan.json", "res://data/npcs/zeynep.json", "res://data/npcs/ferhat.json", "res://data/npcs/ayse.json", "res://data/npcs/murat.json", "res://data/npcs/selim.json", "res://data/npcs/leyla.json"]:
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
		var reaction_targets: Array = (data.photo_reactions as Dictionary).values() + (data.get("drawing_reactions", {}) as Dictionary).values()
		for target: String in reaction_targets:
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


func _test_drawing() -> void:
	var canvas := PaintCanvas.new()
	add_child(canvas)
	_check(canvas.coverage() == 0.0, "new canvas is empty")
	canvas.brush_color = Color(0.8, 0.2, 0.2)
	canvas.brush_radius = 12.0
	canvas.begin_stroke(Vector2(100, 100))
	canvas.continue_stroke(Vector2(700, 300))
	canvas.end_stroke()
	var px: Color = canvas.image.get_pixel(400, 200)
	_check(px.a > 0.9 and px.r > 0.7, "stroke paints along its path (%s)" % px)
	_check(canvas.coverage() > 0.0 and canvas.strokes == 1, "coverage and stroke count update")
	var composed: Image = canvas.compose()
	var paper_px: Color = composed.get_pixel(5, 5)
	var paper_ok: bool = absf(paper_px.r - PaintCanvas.PAPER.r) < 0.01 and absf(paper_px.b - PaintCanvas.PAPER.b) < 0.01
	_check(paper_ok and composed.get_pixel(400, 200).r > 0.7, "compose = paper + paint (%s)" % paper_px)
	canvas.erasing = true
	canvas.begin_stroke(Vector2(400, 200))
	canvas.end_stroke()
	_check(canvas.image.get_pixel(400, 200).a == 0.0, "eraser clears paint")
	canvas.undo()
	_check(canvas.image.get_pixel(400, 200).a > 0.9, "undo restores the erased paint")
	_check(DrawingBook.value_for(0.6, 5, true) > DrawingBook.value_for(0.1, 1, false), "more effort, more value")
	var book := DrawingBook.new()
	book.load_index()
	var before: int = book.entries.size()
	var entry: Dictionary = book.add_drawing(composed, {"value": 20, "subject_list": [{"id": "SUBJ_TEA_GARDEN", "name_key": "SUBJ_TEA_GARDEN", "category": 0}]})
	var again := DrawingBook.new()
	again.load_index()
	_check(again.entries.size() == before + 1 and again.entries[again.entries.size() - 1].kind == "drawing", "sketchbook persists")
	# Selling a drawing uses the NPC's drawing reactions.
	GameState.relationships = {}
	GameState.counters = {}
	var runner := DialogueRunner.new(DialogueRunner.load_data("res://data/npcs/fadime.json"), self)
	runner.choose_photo(entry)
	_check(runner.current_id == "drawing_love", "drawings get their own reactions")
	var money: int = GameState.money
	runner.advance()  # reaction line read -> sell / keep choices
	runner.choose(0)
	_check(GameState.money > money and "fadime" in entry.sold_to, "drawing sold to Fadime")
	again.remove_drawing(again.entries[again.entries.size() - 1])
	canvas.queue_free()


func _test_regions_and_seasons() -> void:
	TimeManager.forced_season = -1
	TimeManager.days_per_season = 7
	TimeManager.day = 1
	_check(TimeManager.get_season() == RegionDefinition.Season.SUMMER, "journey starts in summer")
	TimeManager.day = 8
	_check(TimeManager.get_season() == RegionDefinition.Season.AUTUMN, "autumn after a week")
	TimeManager.day = 15
	_check(TimeManager.get_season() == RegionDefinition.Season.WINTER, "then winter")
	TimeManager.day = 29
	_check(TimeManager.get_season() == RegionDefinition.Season.SUMMER, "the year wraps around")
	TimeManager.day = 1
	var bs: RegionDefinition = GameState.get_region_def(&"blacksea_highland")
	var eg: RegionDefinition = GameState.get_region_def(&"aegean_village")
	_check(bs != null and eg != null and ResourceLoader.exists(eg.scene_path), "both regions defined with scenes")
	_check(bs.snow_for(RegionDefinition.Season.WINTER) > 0.5 and eg.snow_for(RegionDefinition.Season.WINTER) == 0.0, "snowy highland winters, mild Aegean ones")
	_check(bs.weights_for(RegionDefinition.Season.WINTER).has("snow"), "winter weather includes snow in the highland")
	var hours: float = GameState.travel_hours(&"blacksea_highland", &"aegean_village")
	_check(hours > 8.0 and hours < 20.0 and is_equal_approx(hours, GameState.travel_hours(&"aegean_village", &"blacksea_highland")), "travel time sensible and symmetric (%.1f h)" % hours)
	var coast := CoastalTerrain.new()
	coast.size = 240.0
	coast.cell = 6.0
	coast.road_loop = PackedVector2Array([Vector2(-60, -40), Vector2(0, -60), Vector2(60, -40), Vector2(40, -90), Vector2(-40, -90)])
	coast.road_spurs = [PackedVector2Array([Vector2(0, -60), Vector2(0, -100)])]
	add_child(coast)
	_check(coast.is_water(0, 110) and not coast.is_water(0, -100), "sea to the south, land to the north")
	_check(coast.surface_at(0, coast.coast_z(0) - 8.0) == HighlandTerrain.Surface.SAND, "beach is sand")
	coast.queue_free()


func _test_net_haul() -> void:
	var net := NetHaulActivity.new()
	add_child(net)
	GameState.flags = {}
	GameState.relationships = {}
	net.begin()
	_check(net.active and GameState.has_flag("hasan.hauling"), "net haul starts")
	net._zone_center = 0.5
	net._zone_width = 0.2
	_check(net.pull_strength(0.5) == 1.0 and net.pull_strength(0.9) < 1.0 and net.pull_strength(0.9) > 0.0, "timing matters but never fails")
	net.hauling = true
	var pulls: int = 0
	while net.hauling and pulls < 100:
		net._marker = 0.95  # always mistimed
		net.pull()
		pulls += 1
	_check(not net.hauling and GameState.has_flag("hasan.net_full") and pulls > 12, "even clumsy hauling finishes (%d pulls)" % pulls)
	_check(net.catch.size() >= GameState.ECONOMY.net_fish_min, "the net brings up fish")
	var money: int = GameState.money
	var pay: int = net.complete()
	_check(pay > 0 and GameState.money == money + pay and not GameState.has_flag("hasan.hauling"), "catch paid, flags cleared")
	net.queue_free()


## Every translation-key-looking string in code, data and scenes must exist in both languages.
func _test_translation_coverage() -> void:
	var re := RegEx.new()
	# Last char not "_": "PREFIX_" fragments are concatenated in code, not keys.
	re.compile("\"([A-Z][A-Z0-9]*_[A-Z0-9_]*[A-Z0-9])\"")
	var keys: Dictionary = {}
	var files: Array[String] = []
	_collect_files("res://", files)
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		for m: RegExMatch in re.search_all(text):
			keys[m.get_string(1)] = path
	var missing: Array[String] = []
	for locale: String in ["tr", "en"]:
		TranslationServer.set_locale(locale)
		for key: String in keys:
			if TranslationServer.translate(key) == key:
				missing.append("%s:%s (%s)" % [locale, key, String(keys[key]).get_file()])
	TranslationServer.set_locale("en")
	_check(keys.size() > 200, "found translation keys in the project (%d)" % keys.size())
	_check(missing.is_empty(), "all keys translated in TR+EN %s" % [missing])


func _collect_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f: String in dir.get_files():
		if f.get_extension() in ["gd", "json", "tscn"] and not f.begins_with("test_runner"):
			out.append(dir_path.path_join(f))
	for d: String in dir.get_directories():
		if not d.begins_with("."):
			_collect_files(dir_path.path_join(d), out)


func _test_new_regions() -> void:
	for id: StringName in [&"cappadocia", &"eastern_plateau"]:
		var def: RegionDefinition = GameState.get_region_def(id)
		_check(def != null and ResourceLoader.exists(def.scene_path), "%s defined with a scene" % id)
	var h1: float = GameState.travel_hours(&"aegean_village", &"cappadocia")
	var h2: float = GameState.travel_hours(&"cappadocia", &"eastern_plateau")
	_check(h1 > 5.0 and h2 > 5.0 and GameState.travel_hours(&"aegean_village", &"eastern_plateau") > h1, "inland travel times grow eastward (%.1f, %.1f h)" % [h1, h2])
	var cap := CappadociaTerrain.new()
	cap.cell = 12.0
	add_child(cap)
	_check(cap._mesa(0.0, cap.stream_z(0.0)) == 0.0, "the stream valley stays open")
	_check(cap.distance_to_road(cap.road_loop[0].x, cap.road_loop[0].y) <= cap.cell and cap._mesa(cap.road_loop[0].x, cap.road_loop[0].y) < 0.05, "no mesas on the road (%.1f, %.2f)" % [cap.distance_to_road(cap.road_loop[0].x, cap.road_loop[0].y), cap._mesa(cap.road_loop[0].x, cap.road_loop[0].y)])
	cap.queue_free()
	var music: AudioStreamWAV = MusicGenerator.generate("anatolia", "day", 1)
	_check(music.data.size() > 100000, "Anatolian music style generates")


func _test_minigames() -> void:
	GameState.flags = {}
	var pottery := PotteryActivity.new()
	add_child(pottery)
	pottery.begin()
	_check(GameState.has_flag("zeynep.pottery.on"), "pottery job opens")
	pottery._game_start()
	pottery.height = 1.0
	pottery.wobble = 0.0
	var good: float = pottery.shape_score()
	pottery.wobble = 0.8
	pottery.height = 0.5
	var poor: float = pottery.shape_score()
	_check(good > 0.9 and poor < good and poor > 0.0, "pot score rewards height and steadiness (%.2f vs %.2f)" % [good, poor])
	pottery.speed = 0.6
	_check(pottery.in_band(), "wheel speed band")
	pottery.finish_game(good)
	var money: int = GameState.money
	var pay: int = pottery.complete()
	_check(pay > GameState.ECONOMY.pottery_pay and GameState.money == money + pay and not GameState.has_flag("zeynep.pottery.on"), "good pot pays above base, flags cleared")
	pottery.queue_free()
	var brew := TeaBrewingActivity.new()
	add_child(brew)
	brew.begin()
	brew._game_start()
	brew.temp = 99.0
	brew._game_input(_press())
	brew.steep = 0.72
	brew._game_input(_press())
	brew.brew = 0.4
	brew.fill = 0.4
	brew._next_pour()
	brew.fill = 0.9
	brew._next_pour()
	_check(GameState.has_flag("fadime.tea_brew.done") and brew.score > 0.95, "perfect brew scores top (%.2f)" % brew.score)
	brew.complete()
	brew.queue_free()
	var repair := EngineRepairActivity.new()
	add_child(repair)
	repair.begin()
	repair._game_start()
	for r: int in 3:
		for b: int in repair.sequence.duplicate():
			repair.press_bolt(b)
	_check(GameState.has_flag("recep.engine_repair.done") and is_equal_approx(repair.score, 1.0), "repeating the bolt order finishes the repair")
	repair.complete()
	repair.queue_free()
	var mend := NetMendingActivity.new()
	add_child(mend)
	mend.begin()
	mend._game_start()
	mend.holes[Vector2i(2, 2)] = 0.0
	mend.opened = 1
	mend.mend(Vector2i(2, 2))
	_check(mend.holes.is_empty() and mend.mended > 0.9, "tying a fresh hole mends it fully")
	mend.cancel()
	_check(not mend.active and not GameState.has_flag("hasan.net_mend.on"), "leaving mid-job clears it quietly")
	mend.queue_free()


func _press() -> InputEvent:
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	return ev


func _test_herding() -> void:
	GameState.flags = {}
	var herd := SheepHerdingActivity.new()
	add_child(herd)
	herd.begin()
	_check(herd.sheep.size() == herd.sheep_count and herd.penned_count() == 0, "flock spawns outside the pen")
	# A sheep may only cross the wall through the gap (-Z side by default).
	var pc := Vector2(herd.pen_center().x, herd.pen_center().z)
	var s: Dictionary = herd.sheep[0]
	var through_wall: Vector2 = herd._respect_walls(pc + Vector2(0, 8.0), pc + Vector2(0, 6.5), pc, s)
	var through_gap: Vector2 = herd._respect_walls(pc + Vector2(0, -8.0), pc + Vector2(0, -6.5), pc, s)
	_check(through_wall.distance_to(pc) > 7.0 and through_gap.distance_to(pc) < 7.0, "the pen wall holds; the gap lets sheep in")
	herd.complete()
	_check(not herd.active and herd.sheep.is_empty(), "herding ends cleanly")
	herd.queue_free()


func _test_cafe() -> void:
	var cafe := TravellingCafe.new()
	add_child(cafe)
	GameState.current_region_id = &"cappadocia"
	_check(cafe.region_menu().has("CAFE_AYRAN") and not cafe.region_menu().has("CAFE_LEMONADE"), "café menu follows the region")
	GameState.upgrades["cafe_kit"] = 2
	_check(cafe.session_size() == GameState.ECONOMY.cafe_customers + 3, "level 2 kit brings more customers")
	cafe.open = true
	var node := Node3D.new()
	add_child(node)
	cafe.customers.append({"node": node, "bubble": Label3D.new(), "order": "CAFE_AYRAN", "state": "wait", "target": Vector3.ZERO, "from": Vector3.ZERO, "wait": 0.0})
	var money: int = GameState.money
	_check(cafe.serve("CAFE_TEA") == 0 and GameState.money == money, "a wrong order costs nothing and can be retried")
	var gain: int = cafe.serve("CAFE_AYRAN")
	_check(gain > 0 and GameState.money == money + gain and cafe.served == 1, "a quick right order earns price + tip - cost (%d)" % gain)
	GameState.upgrades.erase("cafe_kit")
	cafe.open = false
	cafe.queue_free()


## A .glb dropped in (here written to user://) replaces the procedural mesh.
func _test_story() -> void:
	var money0: int = GameState.money
	var pieces0: int = GameState.get_counter("story.pieces")
	for npc: String in ["ayse", "murat", "selim", "leyla"]:
		GameState.set_flag("%s.met" % npc)
		GameState.relationships[npc] = 0
		for i: int in 3:
			GameState.set_flag("story.%s%d" % [npc, i + 1], false)
		GameState.set_flag("piece." + npc, false)
		var runner := DialogueRunner.new(DialogueRunner.load_data("res://data/npcs/%s.json" % npc), self)
		var chosen: Array[Array] = []
		runner.choices_shown.connect(func(c: Array[Dictionary]) -> void: chosen.append(c.map(func(x: Dictionary) -> String: return x.text)))
		for chapter: int in 3:
			GameState.relationships[npc] = [0, 10, 30][chapter]
			runner.start()
			var guard: int = 0
			while runner.current_id != "hub" and guard < 20:
				runner.advance()
				guard += 1
			# The chapter choice only appears once the friendship level allows it.
			runner.advance()
			var labels: Array = chosen[chosen.size() - 1]
			var key: String = "%s_CH_S%d" % [npc.to_upper(), chapter + 1]
			_check(not (key in labels) or chapter == 0, "%s chapter %d hidden below its level" % [npc, chapter + 1])
			GameState.relationships[npc] = [25, 60, 120][chapter]
			runner.start()
			guard = 0
			while runner.current_id != "hub" and guard < 20:
				runner.advance()
				guard += 1
			runner.advance()
			labels = chosen[chosen.size() - 1]
			var idx: int = labels.find(key)
			_check(idx >= 0, "%s chapter %d offered at its level" % [npc, chapter + 1])
			if idx < 0:
				break
			runner.choose(idx)
			guard = 0
			while runner.current_id != "hub" and runner.current_id != "" and guard < 20:
				runner.advance()
				if runner.current_id.begins_with("s%d" % (chapter + 1)) and runner.current_id.length() == 2:
					runner.choose(0)
				guard += 1
		_check(GameState.has_flag("story.%s3" % npc) and GameState.has_flag("piece." + npc), "%s story completes with a map piece" % npc)
	_check(GameState.get_counter("story.pieces") == pieces0 + 4, "four map pieces collected")
	_check(GameState.money > money0, "story chapters give gifts")
	GameState.counters.erase("story.pieces")
	GameState.counters.erase("story.chapters")
	for npc: String in ["ayse", "murat", "selim", "leyla"]:
		GameState.relationships.erase(npc)
		GameState.flags.erase("%s.met" % npc)
		GameState.flags.erase("piece." + npc)
		for i: int in 3:
			GameState.flags.erase("story.%s%d" % [npc, i + 1])
	GameState.money = money0


func _test_quests() -> void:
	var qs: Array = QuestLog.load_quests()
	_check(qs.size() >= 10, "quests load from data")
	var q: Dictionary = {}
	for x: Dictionary in qs:
		if x.id == "barista":
			q = x
	var log := GameState.get_node_or_null("QuestLog") as QuestLog
	if log == null:
		for c: Node in GameState.get_children():
			if c is QuestLog:
				log = c
	_check(log != null, "quest log runs under GameState")
	var others: Array[String] = []
	for x: Dictionary in qs:
		if x.id != "barista" and not QuestLog.is_done(x):
			others.append("quest.%s" % x.id)
			GameState.flags["quest.%s" % x.id] = true
	var money0: int = GameState.money
	GameState.set_flag("quest.barista", false)
	GameState.set_counter("cafe.served", 9)
	_check(not QuestLog.is_done(q), "quest open below target")
	GameState.set_counter("cafe.served", 10)
	log._run()
	_check(QuestLog.is_done(q) and GameState.money == money0 + int(q.reward), "quest completes once and pays reward")
	GameState.set_counter("cafe.served", 11)
	log._run()
	_check(GameState.money == money0 + int(q.reward), "quest reward not paid twice")
	GameState.counters.erase("cafe.served")
	GameState.flags.erase("quest.barista")
	for f: String in others:
		GameState.flags.erase(f)
	GameState.money = money0


func _test_asset_overrides() -> void:
	var fallback: Array[Mesh] = [LowPolyMeshes.rock(4)]
	AssetLibrary.clear_cache()
	_check(AssetLibrary.meshes("no_such_key", fallback)[0] == fallback[0], "missing model pack falls back to procedural mesh")
	var scene := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = LowPolyMeshes.broadleaf()
	mi.position = Vector3(0, 0, 0)
	scene.add_child(mi)
	mi.owner = scene
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_scene(scene, state)
	var path: String = "user://test_model.glb"
	var err: Error = doc.write_to_filesystem(state, path)
	scene.free()
	var mesh: ArrayMesh = AssetLibrary.load_model(path, 2.0)
	_check(err == OK and mesh != null and mesh.get_surface_count() > 0, "a dropped-in .glb loads at runtime")
	_check(mesh != null and mesh.get_aabb().size.y > LowPolyMeshes.broadleaf().get_aabb().size.y * 1.9, "model scale applies")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
