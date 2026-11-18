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
