class_name MatchFlow
extends Node
## Maç akışı (durum makinesi): başlama vuruşu, oyun, ölü top, duran toplar, gol kutlaması,
## tekrar, devre arası, maç sonu. Süre ayarlanabilir (gerçek dakika/devre); ekranda 0'-90'.

signal state_changed(state: int)
signal message(text: String, color: Color)
signal score_changed(home: int, away: int)
signal match_finished(score: Array)

enum MatchState { KICKOFF, PLAYING, STOPPED, SET_PIECE, CELEBRATION, REPLAY, HALF_TIME, FULL_TIME }
enum Restart { KICKOFF, THROW_IN, CORNER, GOAL_KICK, FREE_KICK, INDIRECT_FREE_KICK, PENALTY }

const PD = preload("res://scripts/match/pitch_dimensions.gd")
const SETUP_TIME := 1.2 # dizilişten sonra vuruşa kadar bekleme
const STOP_DELAY := 1.0 # düdükten sonra diziliş
const CELEBRATION_TIME := 2.0
const HALF_TIME_PAUSE := 3.0
const WALL_DISTANCE := 9.15

var ball: Ball
var possession: Possession
var events: MatchEvents
var referee: Referee
var teams: Array[Team] = []
var team_ais: Array[TeamAI] = []
var director: CameraDirector
var recorder: ReplayRecorder

var half_seconds := 300.0
var replay_seconds := 5.0
var replay_enabled := true
var state := MatchState.KICKOFF
var half := 1
var clock := 0.0
var score := [0, 0]
var first_kickoff_team := 0
var restart_type := Restart.KICKOFF
var restart_team := 0
var restart_spot := Vector3.ZERO
var taker: FootballPlayer

var _timer := 0.0
var _replay_t := 0.0
var _replay_end := 0.0
var _rng := RandomNumberGenerator.new()


func start() -> void:
	_rng.randomize()
	events.event_detected.connect(_on_out_event)
	ball.kicked.connect(_on_kicked)
	referee.offside_called.connect(_on_offside)
	referee.foul_called.connect(_on_foul)
	referee.player_sent_off.connect(_on_sent_off)
	_begin_restart(Restart.KICKOFF, first_kickoff_team, Vector3(0, PD.BALL_RADIUS, 0))


## Ayarlardan devre süresi (gerçek dakika, 2-10) ve tekrar süresi.
func load_settings() -> void:
	var f := FileAccess.open("res://data/settings.json", FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	half_seconds = clampf(float(data.get("half_length_minutes", 5)), 2.0, 10.0) * 60.0
	replay_seconds = float(data.get("replay_seconds", 5))


func game_minute() -> int:
	return mini(int(clock / half_seconds * 45.0), 45) + (45 if half == 2 else 0)


func _set_state(s: MatchState) -> void:
	state = s
	state_changed.emit(s)


# --- Ana döngü ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state in [MatchState.PLAYING, MatchState.KICKOFF, MatchState.SET_PIECE, MatchState.STOPPED]:
		clock += delta
	match state:
		MatchState.PLAYING:
			if clock >= half_seconds:
				_end_half()
		MatchState.STOPPED:
			_timer -= delta
			if _timer <= 0.0:
				_arrange_restart()
		MatchState.KICKOFF, MatchState.SET_PIECE:
			_timer -= delta
			if _timer <= 0.0 and _ai_takes():
				if not _ai_take():
					_timer = 0.3 # tekrar dene
				else:
					_timer = 999.0
		MatchState.CELEBRATION:
			_timer -= delta
			if _timer < CELEBRATION_TIME - 0.5 and recorder:
				recorder.recording = false # top filede: kaydı durdur
			if _timer <= 0.0:
				if replay_enabled and recorder and recorder.frame_count() > 2:
					_start_replay()
				else:
					_after_goal()
		MatchState.REPLAY:
			_update_replay(delta)
		MatchState.HALF_TIME:
			_timer -= delta
			if _timer <= 0.0:
				_start_second_half()


# --- Olaylar -------------------------------------------------------------------

func _on_out_event(ev: Dictionary) -> void:
	if state != MatchState.PLAYING:
		return
	var pos: Vector3 = ev.position
	var sx := signf(pos.x) if pos.x != 0.0 else 1.0
	var sz := signf(pos.z) if pos.z != 0.0 else 1.0
	match ev.type:
		MatchEvents.EventType.GOAL:
			score[ev.team] += 1
			score_changed.emit(score[0], score[1])
			message.emit("GOL! %s" % teams[ev.team].team_name, Color(1, 0.85, 0.2))
			_set_ai(false)
			_set_state(MatchState.CELEBRATION)
			_timer = CELEBRATION_TIME
			restart_team = 1 - ev.team
		MatchEvents.EventType.THROW_IN:
			_stop(Restart.THROW_IN, ev.team, Vector3(clampf(pos.x, -PD.HALF_LENGTH + 1.0, PD.HALF_LENGTH - 1.0), PD.BALL_RADIUS, sz * (PD.HALF_WIDTH - 0.3)), "TAÇ")
		MatchEvents.EventType.CORNER:
			_stop(Restart.CORNER, ev.team, Vector3(sx * (PD.HALF_LENGTH - 0.5), PD.BALL_RADIUS, sz * (PD.HALF_WIDTH - 0.5)), "KORNER")
		MatchEvents.EventType.GOAL_KICK:
			_stop(Restart.GOAL_KICK, ev.team, Vector3(sx * (PD.HALF_LENGTH - PD.GOAL_AREA_DEPTH), PD.BALL_RADIUS, 0.0), "AUT")


func _on_offside(offender: FootballPlayer, pos: Vector3) -> void:
	if state != MatchState.PLAYING:
		return
	_stop(Restart.INDIRECT_FREE_KICK, 1 - offender.team_id, _clamp_field(pos), "OFSAYT")


func _on_foul(offender: FootballPlayer, victim: FootballPlayer, pos: Vector3, card: int) -> void:
	if state != MatchState.PLAYING:
		return
	match card:
		Referee.Card.YELLOW:
			message.emit("SARI KART: %s" % offender.stats.player_name, Color(1, 0.9, 0.1))
		Referee.Card.RED:
			message.emit("KIRMIZI KART: %s" % offender.stats.player_name, Color(1, 0.2, 0.2))
	if Referee.in_penalty_area(pos, victim.attack_sign()):
		_stop(Restart.PENALTY, victim.team_id, Vector3(victim.attack_sign() * (PD.HALF_LENGTH - PD.PENALTY_SPOT_DISTANCE), PD.BALL_RADIUS, 0.0), "PENALTI")
	else:
		_stop(Restart.FREE_KICK, victim.team_id, _clamp_field(pos), "FAUL")


func _on_kicked(_team: int, is_dribble: bool) -> void:
	if is_dribble:
		return
	if state == MatchState.SET_PIECE or state == MatchState.KICKOFF:
		_resume_play()


## Kırmızı kart: oyuncu oyundan çıkar. Kaleci atılırsa en geri saha oyuncusu kaleye geçer.
func _on_sent_off(p: FootballPlayer) -> void:
	var team := teams[p.team_id]
	var ai := team_ais[p.team_id]
	team.remove_player(p)
	ai.ais.erase(p)
	possession.unregister_player(p)
	p.remove_from_group("players")
	p.visible = false
	p.collision_layer = 0
	p.collision_mask = 0
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Vector3(0, -50, 0)
	if p.is_goalkeeper and not team.players.is_empty():
		var own_goal_x := -team.attack_direction * PD.HALF_LENGTH
		var best := team.players[0]
		for q in team.players:
			if absf(q.global_position.x - own_goal_x) < absf(best.global_position.x - own_goal_x):
				best = q
		best.is_goalkeeper = true
		if best.visual and best.visual.has_method("set_team_color"):
			best.visual.set_team_color(team.goalkeeper_color)
		var gk_ai := GoalkeeperAI.new()
		gk_ai.setup(best, ai, ai.ais[best].slot)
		ai.ais[best] = gk_ai
		if team.controlled == best:
			team.set_controlled(team.closest_to_ball())


func _stop(type: Restart, team_id: int, spot: Vector3, text: String) -> void:
	restart_type = type
	restart_team = team_id
	restart_spot = spot
	events.ball_in_play = false
	_set_ai(false)
	_set_state(MatchState.STOPPED)
	_timer = STOP_DELAY
	message.emit(text, Color.WHITE)


func _begin_restart(type: Restart, team_id: int, spot: Vector3) -> void:
	restart_type = type
	restart_team = team_id
	restart_spot = spot
	_arrange_restart()


func _resume_play() -> void:
	_set_lock(false)
	for t in teams:
		t.lock_switch = false
	_set_ai(true)
	events.restart_play()
	_set_state(MatchState.PLAYING)


# --- Duran top dizilişi -------------------------------------------------------

func _arrange_restart() -> void:
	_wall.clear()
	events.ball_in_play = false
	referee.clear_offside()
	referee.next_kick_exempt = restart_type in [Restart.THROW_IN, Restart.CORNER, Restart.GOAL_KICK]
	ball.reset_to(restart_spot)
	var att := teams[restart_team]
	var def := teams[1 - restart_team]
	taker = _choose_taker(att)
	var s := att.attack_direction
	var kick_dir := _kick_direction(s)
	# Genel diziliş: formasyon hedefleri (hücum eden takım ATTACK, diğeri DEFENSE)
	for t in teams:
		var phase := Formation.Phase.ATTACK if t == att else Formation.Phase.DEFENSE
		for p in t.players:
			var pos: Vector3
			if restart_type == Restart.KICKOFF:
				pos = Formation.kickoff_position(team_ais[t.team_id].ais[p].slot, t.attack_direction)
			elif p.is_goalkeeper:
				pos = GoalkeeperAI.position_for(restart_spot, -t.attack_direction)
			else:
				pos = Formation.target_for(team_ais[t.team_id].ais[p].slot, restart_spot, t.attack_direction, phase)
			p.teleport(_clamp_field(pos), restart_spot - pos)
	if restart_type == Restart.PENALTY:
		_arrange_penalty(att, def, s)
	elif restart_type == Restart.FREE_KICK or restart_type == Restart.INDIRECT_FREE_KICK:
		_build_wall(def, s)
	# Mesafe kuralları
	var opp_dist := 3.0 if restart_type == Restart.THROW_IN else WALL_DISTANCE + 0.3
	if restart_type == Restart.KICKOFF:
		opp_dist = PD.CENTER_CIRCLE_RADIUS + 0.3
	for p in def.players:
		if not (p in _wall):
			_push_away(p, restart_spot, opp_dist, def.attack_direction, restart_type == Restart.KICKOFF)
	for p in att.players:
		if p != taker:
			_push_away(p, restart_spot, 4.0, att.attack_direction, restart_type == Restart.KICKOFF)
	if restart_type == Restart.GOAL_KICK:
		for p in def.players: # rakipler ceza sahası dışında
			var gx := -s * PD.HALF_LENGTH
			if Referee.in_penalty_area(p.global_position, -s):
				p.teleport(Vector3(gx + s * (PD.PENALTY_AREA_DEPTH + 1.5), 0.0, p.global_position.z), restart_spot - p.global_position)
	# Vurucu topun arkasında
	taker.teleport(restart_spot - kick_dir * 0.7 - Vector3(0, restart_spot.y, 0), kick_dir)
	possession.take(taker)
	_set_ai(false)
	_set_lock(true)
	for t in teams:
		t.lock_switch = true
		for p in t.players:
			p.has_look_target = true
			p.look_target = restart_spot
	if att.human and not taker.is_goalkeeper:
		att.set_controlled(taker)
	_set_state(MatchState.KICKOFF if restart_type == Restart.KICKOFF else MatchState.SET_PIECE)
	_timer = SETUP_TIME


var _wall: Array[FootballPlayer] = []


func _build_wall(def: Team, s: float) -> void:
	_wall.clear()
	var goal := Vector3(s * PD.HALF_LENGTH, 0.0, 0.0)
	var to_goal := PlayerActions.horizontal(goal - restart_spot)
	if to_goal.length() > 35.0:
		return
	var dir := to_goal.normalized()
	var center := restart_spot + dir * WALL_DISTANCE
	var perp := dir.cross(Vector3.UP)
	var field := def.players.filter(func(p: FootballPlayer) -> bool: return not p.is_goalkeeper)
	field.sort_custom(func(a: FootballPlayer, b: FootballPlayer) -> bool:
		return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	var n := mini(3 if to_goal.length() < 25.0 else 2, field.size() - 1)
	for i in n:
		var p: FootballPlayer = field[i]
		var off := (float(i) - (n - 1) * 0.5) * 0.75
		p.teleport(Vector3(center.x, 0.0, center.z) + perp * off, -dir)
		_wall.append(p)


func _arrange_penalty(att: Team, def: Team, s: float) -> void:
	_wall.clear()
	var box_edge := PD.HALF_LENGTH - PD.PENALTY_AREA_DEPTH - 1.0
	for t in [att, def]:
		for p in t.players:
			if p == taker:
				continue
			if p.is_goalkeeper and t == def:
				p.teleport(Vector3(s * (PD.HALF_LENGTH - 0.2), 0.0, 0.0), Vector3(-s, 0, 0))
				continue
			if p.is_goalkeeper:
				continue
			var pos: Vector3 = p.global_position
			if pos.x * s > box_edge:
				pos.x = s * box_edge
			p.teleport(pos, restart_spot - pos)


func _push_away(p: FootballPlayer, spot: Vector3, min_dist: float, attack_dir: float, own_half: bool) -> void:
	var d := PlayerActions.horizontal(p.global_position - spot)
	if d.length() >= min_dist:
		return
	var dir := d.normalized() if d.length() > 0.1 else Vector3(-attack_dir, 0.0, 0.0)
	var pos := Vector3(spot.x, 0.0, spot.z) + dir * min_dist
	if own_half and pos.x * attack_dir > -0.5:
		pos.x = -attack_dir * 0.5
	p.teleport(_clamp_field(pos), spot - pos)


func _clamp_field(pos: Vector3) -> Vector3:
	return Vector3(clampf(pos.x, -PD.HALF_LENGTH + 0.5, PD.HALF_LENGTH - 0.5), pos.y, clampf(pos.z, -PD.HALF_WIDTH + 0.5, PD.HALF_WIDTH - 0.5))


func _kick_direction(s: float) -> Vector3:
	match restart_type:
		Restart.THROW_IN:
			return Vector3(0.0, 0.0, -signf(restart_spot.z))
		Restart.CORNER:
			return Vector3(-signf(restart_spot.x), 0.0, -signf(restart_spot.z)).normalized()
	return Vector3(s, 0.0, 0.0)


func _choose_taker(att: Team) -> FootballPlayer:
	if restart_type == Restart.GOAL_KICK:
		for p in att.players:
			if p.is_goalkeeper:
				return p
	var best: FootballPlayer = null
	var best_score := INF
	for p in att.players:
		if p.is_goalkeeper:
			continue
		var sc := PlayerActions.horizontal(p.global_position - restart_spot).length()
		if restart_type == Restart.KICKOFF:
			sc = -team_ais[att.team_id].ais[p].slot.x # en ileri oyuncu
		if sc < best_score:
			best_score = sc
			best = p
	return best if best else att.players[0]


func _ai_takes() -> bool:
	return taker != null and (not teams[restart_team].human or taker.is_goalkeeper)


## AI duran top kararı. Vuruş yapıldıysa true.
func _ai_take() -> bool:
	var s := taker.attack_sign()
	var goal := Vector3(s * PD.HALF_LENGTH, 0.0, 0.0)
	var opp := team_ais[restart_team].opponent_positions()
	var corner_z := (PD.GOAL_WIDTH * 0.5 - 0.6) * (1.0 if _rng.randf() < 0.5 else -1.0)
	match restart_type:
		Restart.PENALTY:
			return taker.shoot_at(Vector3(goal.x, 0.0, corner_z), _rng.randf_range(0.6, 0.8))
		Restart.FREE_KICK:
			var d := PlayerActions.horizontal(goal - restart_spot).length()
			if d < 28.0 and absf(restart_spot.z) < 15.0:
				return taker.shoot_at(Vector3(goal.x, 0.0, corner_z), 0.75)
		Restart.CORNER:
			var spot := Vector3(s * (PD.HALF_LENGTH - _rng.randf_range(6.0, 11.0)), 0.0, _rng.randf_range(-4.0, 4.0))
			return taker.clear_to(spot, 25.0)
	# Pas: en uygun arkadaş, yoksa ileri uzun vuruş
	var best: FootballPlayer = null
	var best_u := -INF
	for m in teams[restart_team].players:
		if m == taker or m.is_goalkeeper:
			continue
		var u := PlayerAI.pass_utility(taker.global_position, m.global_position, s, opp)
		if restart_type == Restart.KICKOFF:
			u = -PlayerActions.horizontal(m.global_position - taker.global_position).length()
		if u > best_u:
			best_u = u
			best = m
	if best != null and best_u > -INF:
		var dist := PlayerActions.horizontal(best.global_position - taker.global_position).length()
		return taker.pass_to(best, PassTargeting.Kind.LOB if dist > 22.0 else PassTargeting.Kind.SHORT)
	return taker.clear_to(Vector3(s * 15.0, 0.0, _rng.randf_range(-15.0, 15.0)))


# --- Devre / maç sonu -----------------------------------------------------------

func _end_half() -> void:
	_set_ai(false)
	_set_lock(true)
	events.ball_in_play = false
	if half == 1:
		message.emit("DEVRE ARASI", Color.WHITE)
		_set_state(MatchState.HALF_TIME)
		_timer = HALF_TIME_PAUSE
	else:
		message.emit("MAÇ SONU  %d - %d" % [score[0], score[1]], Color.WHITE)
		_set_state(MatchState.FULL_TIME)
		match_finished.emit(score)


func _start_second_half() -> void:
	half = 2
	clock = 0.0
	# Taraf değiştir
	for t in teams:
		t.set_attack_direction(-t.attack_direction)
	events.home_attack_sign = teams[0].attack_direction
	message.emit("2. YARI", Color.WHITE)
	_begin_restart(Restart.KICKOFF, 1 - first_kickoff_team, Vector3(0, PD.BALL_RADIUS, 0))


# --- Tekrar -------------------------------------------------------------------

func _start_replay() -> void:
	_set_state(MatchState.REPLAY)
	_replay_end = recorder.end_time()
	_replay_t = maxf(recorder.start_time(), _replay_end - replay_seconds)
	ball.freeze = true
	for n in recorder.tracked:
		if n is FootballPlayer:
			n.set_physics_process(false)
	if director:
		director.begin_replay()
	message.emit("TEKRAR", Color(0.8, 0.9, 1.0))


func _update_replay(delta: float) -> void:
	_replay_t += delta
	var frames := recorder.sample(_replay_t)
	for i in mini(frames.size(), recorder.tracked.size()):
		var n := recorder.tracked[i]
		if is_instance_valid(n) and n.visible:
			n.global_transform = frames[i]
	if director and director.replay_camera and not frames.is_empty():
		director.replay_camera.focus = frames[0].origin
	var skip := Input.is_action_just_pressed("pass_short") or Input.is_action_just_pressed("ui_cancel")
	if _replay_t >= _replay_end or skip:
		_end_replay()


func _end_replay() -> void:
	ball.freeze = false
	for n in recorder.tracked:
		if n is FootballPlayer:
			n.set_physics_process(true)
	if director:
		director.end_replay()
	_after_goal()


func _after_goal() -> void:
	if recorder:
		recorder.clear()
		recorder.recording = true
	_begin_restart(Restart.KICKOFF, restart_team, Vector3(0, PD.BALL_RADIUS, 0))


# --- Yardımcılar ----------------------------------------------------------------

func _set_ai(on: bool) -> void:
	for ai in team_ais:
		ai.enabled = on
	if not on:
		for t in teams:
			for p in t.players:
				p.move_input = Vector3.ZERO
				p.sprint_input = false


func _set_lock(on: bool) -> void:
	for t in teams:
		for p in t.players:
			p.locked = on
