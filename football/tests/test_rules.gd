extends "res://tests/test_case.gd"
## Faz 5 kuralları: ofsayt, kartlar, taraf değişimi, duran toplar, süre, tekrar.

const PD = preload("res://scripts/match/pitch_dimensions.gd")
const MatchScene = preload("res://scenes/match.tscn")
const PlayerScene = preload("res://scenes/player.tscn")
const BallScene = preload("res://scenes/ball.tscn")
const R = 0.11


func _v(list: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.assign(list)
	return out


# --- Ofsayt (saf) ---------------------------------------------------------------

func test_offside_ahead_of_second_last() -> void:
	var defs := _v([Vector3(50, 0, 0), Vector3(20, 0, 5)])
	check(OffsideRule.is_offside_position(Vector3(25, 0, 0), 1.0, Vector3(0, 0, 0), defs), "Sondan ikinci rakibin önünde: ofsayt")


func test_offside_level_is_onside() -> void:
	var defs := _v([Vector3(50, 0, 0), Vector3(20, 0, 5)])
	check(not OffsideRule.is_offside_position(Vector3(20, 0, -3), 1.0, Vector3(0, 0, 0), defs), "Aynı hizada: ofsayt değil")


func test_offside_own_half_is_onside() -> void:
	var defs := _v([Vector3(50, 0, 0), Vector3(-10, 0, 5)])
	check(not OffsideRule.is_offside_position(Vector3(-2, 0, 0), 1.0, Vector3(-20, 0, 0), defs), "Kendi yarı sahası: ofsayt değil")


func test_offside_behind_ball_is_onside() -> void:
	var defs := _v([Vector3(50, 0, 0), Vector3(20, 0, 5)])
	check(not OffsideRule.is_offside_position(Vector3(30, 0, 0), 1.0, Vector3(32, 0, 0), defs), "Topun gerisinde: ofsayt değil")


func test_offside_two_deeper_defenders_onside() -> void:
	var defs := _v([Vector3(50, 0, 0), Vector3(40, 0, 5), Vector3(20, 0, 0)])
	check(not OffsideRule.is_offside_position(Vector3(30, 0, 0), 1.0, Vector3(0, 0, 0), defs), "İki rakip daha geride: ofsayt değil")


func test_offside_mirrored_for_away() -> void:
	var defs := _v([Vector3(-50, 0, 0), Vector3(-20, 0, 5)])
	check(OffsideRule.is_offside_position(Vector3(-25, 0, 0), -1.0, Vector3(0, 0, 0), defs), "Deplasman yönünde ofsayt")


func test_offside_goalkeeper_out_counts() -> void:
	# Kaleci çıkmış: kale çizgisine en yakın iki rakip savunmacı + kaleci arasında sıralanır
	var defs := _v([Vector3(10, 0, 0), Vector3(30, 0, 0)])
	check(OffsideRule.is_offside_position(Vector3(35, 0, 0), 1.0, Vector3(0, 0, 0), defs), "Kaleci önde, sondan ikinci geride: ofsayt")


# --- Kart ve faul (saf) ---------------------------------------------------------------

func test_card_decisions() -> void:
	check(Referee.decide_card(false, 6.0, true, false, 0.9, 0.9) == Referee.Card.RED, "Ceza sahası dışı bariz gol fırsatı: kırmızı")
	check(Referee.decide_card(false, 6.0, true, true, 0.9, 0.9) == Referee.Card.YELLOW, "Ceza sahası içi bariz gol fırsatı: sarı")
	check(Referee.decide_card(false, 5.0, false, false, 0.9, 0.9) == Referee.Card.NONE, "Önden hafif müdahale: kart yok")
	check(Referee.decide_card(true, 6.0, false, false, 0.3, 0.9) == Referee.Card.YELLOW, "Arkadan müdahale: sarı")


func test_dogso_and_penalty_area() -> void:
	check(Referee.is_dogso(Vector3(35, 0, 0), 1.0, _v([Vector3(20, 0, 0)])), "Önünde savunmacı yok: bariz gol fırsatı")
	check(not Referee.is_dogso(Vector3(35, 0, 0), 1.0, _v([Vector3(45, 0, 2)])), "Önünde savunmacı var")
	check(Referee.in_penalty_area(Vector3(45, 0, 10), 1.0), "Ceza sahası içi")
	check(not Referee.in_penalty_area(Vector3(30, 0, 0), 1.0), "Ceza sahası dışı")


func test_events_respect_side_switch() -> void:
	var ev := MatchEvents.classify(Vector3(PD.HALF_LENGTH + 0.2, 1.0, 0.0), R, 0, -1.0)
	check(ev.type == MatchEvents.EventType.GOAL and ev.team == MatchEvents.AWAY, "Taraf değişince +X kalesine gol deplasmanın")


# --- Hakem entegrasyonu ---------------------------------------------------------

func _referee_world() -> Dictionary:
	var g := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(400, 1, 400)
	cs.shape = b
	cs.position.y = -0.5
	g.add_child(cs)
	add_child(g)
	var ball: Ball = BallScene.instantiate()
	add_child(ball)
	var pos := Possession.new()
	pos.ball = ball
	add_child(pos)
	var teams: Array[Team] = []
	for id in 2:
		var t := Team.new()
		t.team_id = id
		t.possession = pos
		add_child(t)
		teams.append(t)
	var ref := Referee.new()
	add_child(ref)
	return {"ball": ball, "pos": pos, "teams": teams, "ref": ref}


func _add(t: Team, at: Vector3, gk := false) -> FootballPlayer:
	var p: FootballPlayer = PlayerScene.instantiate()
	p.is_goalkeeper = gk
	add_child(p)
	p.global_position = at
	t.add_player(p)
	return p


func _offside_scenario(receiver_x: float) -> bool:
	var w := _referee_world()
	var teams: Array[Team] = w.teams
	var passer := _add(teams[0], Vector3(0, 0, 0))
	passer.stats.passing = 99 # isabetli pas: test hedefe odaklı
	var receiver := _add(teams[0], Vector3(receiver_x, 0, 3))
	_add(teams[1], Vector3(20, 0, -6))
	_add(teams[1], Vector3(50, 0, 0), true)
	w.ref.setup(w.ball, w.pos, teams)
	var called := [false]
	w.ref.offside_called.connect(func(_o: FootballPlayer, _p: Vector3) -> void: called[0] = true)
	w.ball.reset_to(Vector3(0.6, 0.11, 0))
	await step_physics(10)
	passer.pass_to(receiver, PassTargeting.Kind.SHORT)
	await step_physics(600)
	check(w.pos.owner_player == receiver or called[0], "Pas alıcıya ulaşmalı")
	await clear_children()
	return called[0]


func test_offside_called_on_receive() -> void:
	check(await _offside_scenario(28.0), "Ofsayttaki oyuncu topu alınca ofsayt çalınmalı")


func test_no_offside_when_onside() -> void:
	check(not await _offside_scenario(15.0), "Ofsayt olmayan alıcı için çalınmamalı")


func test_second_yellow_is_red() -> void:
	var w := _referee_world()
	var teams: Array[Team] = w.teams
	var p := _add(teams[0], Vector3.ZERO)
	w.ref.setup(w.ball, w.pos, teams)
	var sent := [false]
	w.ref.player_sent_off.connect(func(_p: FootballPlayer) -> void: sent[0] = true)
	check(w.ref._apply_card(p, Referee.Card.YELLOW) == Referee.Card.YELLOW, "İlk sarı")
	check(w.ref._apply_card(p, Referee.Card.YELLOW) == Referee.Card.RED and sent[0], "İkinci sarı kırmızıya döner")
	await clear_children()


# --- Maç akışı ------------------------------------------------------------------

func _match(half_minutes := 10.0, replay := false) -> Node:
	var m = MatchScene.instantiate()
	m.human_team = -1
	m.replay_enabled = replay
	m.half_minutes_override = half_minutes
	add_child(m)
	return m


func _wait_state(flow: MatchFlow, s: int, max_frames: int) -> bool:
	for i in max_frames:
		if flow.state == s:
			return true
		await get_tree().physics_frame
	return flow.state == s


func test_kickoff_then_play() -> void:
	var m := _match()
	var flow: MatchFlow = m.flow
	check(flow.state == MatchFlow.MatchState.KICKOFF, "Maç başlama vuruşuyla başlamalı")
	for t in flow.teams:
		for p in t.players:
			check(p.global_position.x * t.attack_direction <= 0.0, "Başlamada herkes kendi yarısında")
	check(await _wait_state(flow, MatchFlow.MatchState.PLAYING, 600), "AI başlama vuruşunu yapmalı")
	await clear_children()


func test_throw_in_restart() -> void:
	var m := _match()
	var flow: MatchFlow = m.flow
	await _wait_state(flow, MatchFlow.MatchState.PLAYING, 600)
	flow._on_out_event({"type": MatchEvents.EventType.THROW_IN, "team": 1, "position": Vector3(10, R, PD.HALF_WIDTH + 0.2), "side": 1})
	check(await _wait_state(flow, MatchFlow.MatchState.SET_PIECE, 300), "Taç dizilişi kurulmalı")
	check(m.possession.owner_player != null and m.possession.owner_player.team_id == 1, "Topu taç kazanan takım almalı")
	for p in flow.teams[0].players:
		check(PlayerActions.horizontal(p.global_position - flow.restart_spot).length() >= 2.9, "Rakip tacdan uzak durmalı")
	check(await _wait_state(flow, MatchFlow.MatchState.PLAYING, 600), "Taç atılıp oyun devam etmeli")
	await clear_children()


func test_free_kick_distance_and_wall() -> void:
	var m := _match()
	var flow: MatchFlow = m.flow
	await _wait_state(flow, MatchFlow.MatchState.PLAYING, 600)
	var victim: FootballPlayer = flow.teams[1].players[3]
	var offender: FootballPlayer = flow.teams[0].players[1]
	flow._on_foul(offender, victim, Vector3(-25, 0, 5), Referee.Card.NONE)
	check(flow.restart_type == MatchFlow.Restart.FREE_KICK, "Ceza sahası dışı faul: serbest vuruş")
	check(await _wait_state(flow, MatchFlow.MatchState.SET_PIECE, 300), "Serbest vuruş dizilişi")
	for p in flow.teams[0].players:
		check(PlayerActions.horizontal(p.global_position - flow.restart_spot).length() >= 9.0, "Rakipler 9.15 m uzakta (%.2f)" % PlayerActions.horizontal(p.global_position - flow.restart_spot).length())
	check(flow._wall.size() >= 2, "Baraj kurulmalı")
	await clear_children()


func test_foul_in_box_is_penalty() -> void:
	var m := _match()
	var flow: MatchFlow = m.flow
	await _wait_state(flow, MatchFlow.MatchState.PLAYING, 600)
	var victim: FootballPlayer = flow.teams[0].players[4]
	victim.global_position = Vector3(45, 0, 3)
	flow._on_foul(flow.teams[1].players[1], victim, victim.global_position, Referee.Card.NONE)
	check(flow.restart_type == MatchFlow.Restart.PENALTY and flow.restart_team == 0, "Ceza sahası içi faul: penaltı")
	check(absf(flow.restart_spot.x - (PD.HALF_LENGTH - PD.PENALTY_SPOT_DISTANCE)) < 0.01, "Top penaltı noktasında")
	await clear_children()


func test_goal_kickoff_by_conceding_team() -> void:
	var m := _match()
	var flow: MatchFlow = m.flow
	await _wait_state(flow, MatchFlow.MatchState.PLAYING, 600)
	flow._on_out_event({"type": MatchEvents.EventType.GOAL, "team": 0, "position": Vector3(53, 1, 0), "side": 1})
	check(flow.score[0] == 1, "Skor artmalı")
	check(await _wait_state(flow, MatchFlow.MatchState.KICKOFF, 600), "Gol sonrası başlama vuruşu")
	check(flow.restart_team == 1, "Golü yiyen takım başlamalı")
	await clear_children()


func test_replay_after_goal() -> void:
	var m := _match(10.0, true)
	var flow: MatchFlow = m.flow
	await _wait_state(flow, MatchFlow.MatchState.PLAYING, 600)
	await step_physics(240)
	flow._on_out_event({"type": MatchEvents.EventType.GOAL, "team": 1, "position": Vector3(-53, 1, 0), "side": -1})
	check(await _wait_state(flow, MatchFlow.MatchState.REPLAY, 400), "Gol sonrası tekrar başlamalı")
	check(m.ball.freeze, "Tekrarda top fizikten bağımsız")
	check(await _wait_state(flow, MatchFlow.MatchState.KICKOFF, 1200), "Tekrar bitince başlama vuruşu")
	check(not m.ball.freeze, "Tekrar sonrası top serbest")
	await clear_children()


func test_halves_and_side_switch() -> void:
	var m := _match(0.05) # 3 sn devre
	var flow: MatchFlow = m.flow
	check(await _wait_state(flow, MatchFlow.MatchState.HALF_TIME, 120 * 15), "Devre arası gelmeli")
	check(await _wait_state(flow, MatchFlow.MatchState.KICKOFF, 120 * 5), "2. yarı başlama vuruşu")
	check(flow.half == 2 and flow.teams[0].attack_direction == -1.0, "2. yarıda taraf değişmeli")
	check(m.events.home_attack_sign == -1.0, "Olay algılama da taraf değiştirmeli")
	check(flow.restart_team == 1, "2. yarıyı diğer takım başlatmalı")
	check(await _wait_state(flow, MatchFlow.MatchState.FULL_TIME, 120 * 15), "Maç bitmeli")
	check(flow.game_minute() == 90, "Süre 90' göstermeli (%d)" % flow.game_minute())
	await clear_children()
