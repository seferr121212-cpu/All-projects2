extends "res://tests/test_case.gd"
## Gol / taç / korner / aut karar testleri (saf fonksiyon).

const PD = preload("res://scripts/match/pitch_dimensions.gd")
const E = preload("res://scripts/match/match_events.gd").EventType
const R = 0.11


func _cls(pos: Vector3, last: int) -> Dictionary:
	return MatchEvents.classify(pos, R, last)


func test_ball_on_line_is_not_goal() -> void:
	var ev := _cls(Vector3(PD.HALF_LENGTH + 0.05, 0.5, 0.0), MatchEvents.HOME)
	check(ev.type == E.NONE, "Çizgi üstündeki top gol sayılmamalı")


func test_ball_fully_over_line_is_goal() -> void:
	var ev := _cls(Vector3(PD.HALF_LENGTH + R + 0.01, 0.5, 0.0), MatchEvents.HOME)
	check(ev.type == E.GOAL, "Tamamen geçen top gol olmalı")
	check(ev.team == MatchEvents.HOME, "+X kalesine gol ev sahibinin")


func test_left_goal_for_away() -> void:
	var ev := _cls(Vector3(-PD.HALF_LENGTH - 0.2, 1.0, 1.0), MatchEvents.AWAY)
	check(ev.type == E.GOAL and ev.team == MatchEvents.AWAY, "-X kalesine gol deplasmanın")


func test_over_crossbar_is_goal_kick() -> void:
	var ev := _cls(Vector3(PD.HALF_LENGTH + 0.2, 3.0, 0.0), MatchEvents.HOME)
	check(ev.type == E.GOAL_KICK and ev.team == MatchEvents.AWAY, "Üstten çıkan top aut olmalı")


func test_wide_of_post_is_goal_kick() -> void:
	var ev := _cls(Vector3(PD.HALF_LENGTH + 0.2, 0.5, 3.8), MatchEvents.HOME)
	check(ev.type == E.GOAL_KICK, "Direğin dışından çıkan top aut olmalı")


func test_defender_last_touch_is_corner() -> void:
	var ev := _cls(Vector3(PD.HALF_LENGTH + 0.2, 0.2, 10.0), MatchEvents.AWAY)
	check(ev.type == E.CORNER and ev.team == MatchEvents.HOME, "Savunmacı son dokunduysa korner")


func test_throw_in() -> void:
	var ev := _cls(Vector3(0.0, R, PD.HALF_WIDTH + R + 0.01), MatchEvents.HOME)
	check(ev.type == E.THROW_IN and ev.team == MatchEvents.AWAY, "Yan çizgiden çıkış taç, rakibin")
	var inside := _cls(Vector3(0.0, R, PD.HALF_WIDTH + 0.05), MatchEvents.HOME)
	check(inside.type == E.NONE, "Kısmen çizgi üstündeki top oyunda")
