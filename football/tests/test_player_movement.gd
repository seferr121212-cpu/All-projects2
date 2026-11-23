extends "res://tests/test_case.gd"
## Oyuncu hareketi, top sürme ve vuruş testleri (gerçek fizik).

const PlayerScene = preload("res://scenes/player.tscn")
const BallScene = preload("res://scenes/ball.tscn")


func _ground() -> void:
	var g := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(400, 1, 400)
	cs.shape = b
	cs.position.y = -0.5
	g.add_child(cs)
	add_child(g)


func _player(pos: Vector3) -> FootballPlayer:
	var p: FootballPlayer = PlayerScene.instantiate()
	add_child(p)
	p.global_position = pos
	return p


func _hspeed(p: FootballPlayer) -> float:
	return PlayerActions.horizontal(p.velocity).length()


func test_run_reaches_run_speed() -> void:
	_ground()
	var p := _player(Vector3.ZERO)
	p.move_input = Vector3.RIGHT
	await step_physics(240)
	check_near(_hspeed(p), p.stats.run_speed(), 0.15, "Koşu hızı")
	await clear_children()


func test_sprint_faster_and_drains_stamina() -> void:
	_ground()
	var p := _player(Vector3.ZERO)
	p.move_input = Vector3.RIGHT
	p.sprint_input = true
	await step_physics(240)
	check(_hspeed(p) > p.stats.run_speed() + 1.0, "Sprint koşudan hızlı olmalı (%.2f)" % _hspeed(p))
	check(p.stamina < p.stats.max_stamina - 10.0, "Sprint staminayı düşürmeli (%.1f)" % p.stamina)
	await clear_children()


func test_no_instant_reverse() -> void:
	_ground()
	var p := _player(Vector3.ZERO)
	p.move_input = Vector3.RIGHT
	p.sprint_input = true
	await step_physics(240)
	p.move_input = Vector3.LEFT
	await step_physics(12) # 0.1 sn
	check(p.velocity.x > 2.0, "Sprintte 0.1 sn'de geri dönülmemeli (vx=%.2f)" % p.velocity.x)
	await step_physics(240)
	check(p.velocity.x < -3.0, "2 sn sonra ters yöne koşmalı (vx=%.2f)" % p.velocity.x)
	await clear_children()


func _setup_with_ball() -> Array:
	_ground()
	var ball: Ball = BallScene.instantiate()
	add_child(ball)
	var pos := Possession.new()
	pos.ball = ball
	add_child(pos)
	var p := _player(Vector3.ZERO)
	pos.register_player(p)
	ball.reset_to(Vector3(0.6, 0.11, 0))
	return [p, ball, pos]


func test_dribble_keeps_ball_with_small_touches() -> void:
	var s := await _setup_with_ball()
	var p: FootballPlayer = s[0]
	var ball: Ball = s[1]
	var pos: Possession = s[2]
	var touches := [0]
	ball.kicked.connect(func(_t: int, d: bool) -> void: touches[0] += 1 if d else 0)
	await step_physics(10)
	check(pos.owner_player == p, "Oyuncu topu almalı")
	p.move_input = Vector3.RIGHT
	var max_gap := 0.0
	for i in 36:
		await step_physics(10)
		max_gap = maxf(max_gap, PlayerActions.horizontal(ball.global_position - p.global_position).length())
	check(pos.owner_player == p, "3 sn sürüşte top kaybedilmemeli")
	check(max_gap < 2.0 and max_gap > 0.4, "Top ayakta yapışık olmamalı ama uzaklaşmamalı (maks %.2f m)" % max_gap)
	check(touches[0] >= 5, "Küçük dokunuşlar olmalı (%d)" % touches[0])
	check(p.global_position.x > 12.0, "Oyuncu ilerlemeli (%.1f)" % p.global_position.x)
	await clear_children()


func test_short_pass_reaches_target() -> void:
	var s := await _setup_with_ball()
	var p: FootballPlayer = s[0]
	var ball: Ball = s[1]
	var pos: Possession = s[2]
	var mate := _player(Vector3(15, 0, 0))
	pos.register_player(mate)
	await step_physics(10)
	p.do_pass(PassTargeting.Kind.SHORT)
	check(pos.owner_player == null, "Pastan sonra sahiplik bırakılmalı")
	await step_physics(360)
	check(pos.owner_player == mate, "Pas arkadaşa ulaşmalı (top x=%.1f)" % ball.global_position.x)
	await clear_children()


func test_shot_goes_toward_goal() -> void:
	var s := await _setup_with_ball()
	var p: FootballPlayer = s[0]
	var ball: Ball = s[1]
	await step_physics(10)
	p.start_shot_charge()
	await step_physics(84) # ~0.7 güç
	p.release_shot(0.0)
	var v := ball.linear_velocity
	check(v.x > 18.0, "Şut hızlı ve kaleye doğru olmalı (vx=%.1f)" % v.x)
	check(v.y > 0.5 and v.y < 6.0, "Şut makul yükseklikte (vy=%.1f)" % v.y)
	await clear_children()


func test_slide_tackle_wins_ball() -> void:
	var s := await _setup_with_ball()
	var p: FootballPlayer = s[0]
	var pos: Possession = s[2]
	var defender := _player(Vector3(4, 0, 0))
	defender.team_id = 1
	defender.facing = Vector3.LEFT
	pos.register_player(defender)
	await step_physics(10)
	check(pos.owner_player == p, "Hücumcu topa sahip")
	defender.slide_tackle()
	await step_physics(60)
	check(pos.owner_player != p, "Kayarak müdahale topu almalı")
	check(p.state == FootballPlayer.State.STUMBLE or p.state == FootballPlayer.State.NORMAL, "Hücumcu sendelemeli")
	await clear_children()
