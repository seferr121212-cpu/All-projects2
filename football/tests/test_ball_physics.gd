extends "res://tests/test_case.gd"
## Top fiziği testleri: aerodinamik formüller + gerçek simülasyon.

const BallScene = preload("res://scenes/ball.tscn")


func _make_world() -> Ball:
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	cs.shape = box
	cs.position.y = -0.5
	ground.add_child(cs)
	add_child(ground)
	var ball: Ball = BallScene.instantiate()
	add_child(ball)
	ball.global_position = Vector3(0, 0.11, 0)
	return ball


func test_mass_is_realistic() -> void:
	var ball: Ball = BallScene.instantiate()
	add_child(ball)
	check_near(ball.mass, 0.43, 0.001, "Top kütlesi")
	ball.free()


func test_drag_opposes_velocity() -> void:
	var p := BallPhysicsParams.new()
	var f := Ball.compute_aero_force(Vector3(25, 0, 0), Vector3.ZERO, p)
	check(f.x < 0.0, "Hava direnci hıza ters olmalı")
	var expected := 0.5 * 1.2 * 0.25 * PI * 0.11 * 0.11 * 625.0
	check_near(f.length(), expected, 0.01, "Hava direnci büyüklüğü")


func test_magnus_directions() -> void:
	var p := BallPhysicsParams.new()
	var v := Vector3(20, 0, 0)
	var side := Ball.compute_aero_force(v, Vector3(0, 30, 0), p)
	check(side.z < 0.0, "+Y spin, +X giden topu -Z'ye saptırmalı")
	var top := Ball.compute_aero_force(v, Vector3(0, 0, -30), p)
	check(top.y < 0.0, "Üst falso topu aşağı itmeli")
	var back := Ball.compute_aero_force(v, Vector3(0, 0, 30), p)
	check(back.y > 0.0, "Alt falso topu yukarı itmeli")


func test_drag_slows_flight() -> void:
	var ball := _make_world()
	await step_physics(2)
	ball.kick(Vector3(20, 6, 0), Vector3.ZERO)
	await step_physics(60)
	var vh := Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
	check(vh < 19.8 and vh > 15.0, "0.5 sn sonra yatay hız 15-19.8 arası olmalı (%.2f)" % vh)
	await clear_children()


func test_spin_curves_flight() -> void:
	var ball := _make_world()
	await step_physics(2)
	ball.kick(Vector3(20, 6, 0), Vector3(0, 40, 0))
	await step_physics(120)
	check(ball.global_position.z < -0.5, "Falsolu top yana sapmalı (z=%.2f)" % ball.global_position.z)
	await clear_children()


func test_rolling_ball_stops() -> void:
	var ball := _make_world()
	await step_physics(10)
	ball.kick(Vector3(10, 0, 0), Vector3.ZERO)
	await step_physics(120 * 9)
	var d := ball.global_position.x
	check(ball.linear_velocity.length() < 0.2, "Yerde yuvarlanan top durmalı (%.2f m/s)" % ball.linear_velocity.length())
	check(d > 15.0 and d < 45.0, "10 m/s yer pası 15-45 m gitmeli (%.1f m)" % d)
	await clear_children()
