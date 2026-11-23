extends "res://tests/test_case.gd"
## Entegrasyon: gerçek stadyumda gol algılama, file ve direk çarpışması.

const PD = preload("res://scripts/match/pitch_dimensions.gd")
const StadiumScene = preload("res://scenes/stadium.tscn")
const BallScene = preload("res://scenes/ball.tscn")

var _events: Array[Dictionary] = []


func _setup() -> Ball:
	_events.clear()
	var stadium := StadiumScene.instantiate()
	stadium.build_lighting = false
	add_child(stadium)
	var ball: Ball = BallScene.instantiate()
	add_child(ball)
	var me := MatchEvents.new()
	me.ball = ball
	me.event_detected.connect(func(ev: Dictionary) -> void: _events.append(ev))
	add_child(me)
	return ball


func test_shot_into_goal_is_detected_and_net_holds() -> void:
	var ball := _setup()
	ball.reset_to(Vector3(40, 0.11, 0))
	await step_physics(5)
	ball.kick(Vector3(25, 2.5, 0), Vector3.ZERO, MatchEvents.HOME)
	await step_physics(240)
	check(_events.size() == 1 and _events[0].type == MatchEvents.EventType.GOAL, "Gol algılanmalı")
	var x := ball.global_position.x
	check(x > PD.HALF_LENGTH and x < PD.HALF_LENGTH + PD.GOAL_DEPTH + 0.2, "Top filede kalmalı (x=%.2f)" % x)
	check(ball.linear_velocity.length() < 3.0, "File topu yavaşlatmalı (%.2f)" % ball.linear_velocity.length())
	await clear_children()


func test_post_bounces_ball_back() -> void:
	var ball := _setup()
	var post_z := PD.GOAL_WIDTH * 0.5 + PD.POST_RADIUS
	ball.reset_to(Vector3(47, 1.0, post_z))
	await step_physics(5)
	ball.kick(Vector3(20, 1.5, 0), Vector3.ZERO, MatchEvents.HOME)
	await step_physics(60)
	check(ball.linear_velocity.x < 0.0, "Direğe çarpan top geri sekmeli (vx=%.2f)" % ball.linear_velocity.x)
	check(_events.is_empty() or _events[0].type != MatchEvents.EventType.GOAL, "Direkten dönen top gol olmamalı")
	await clear_children()
