class_name PlayerAI
extends RefCounted
## Bireysel saha oyuncusu AI'sı. TeamAI zamanlanmış tick'te (10 Hz) think() çağırır ve rol verir;
## her karede frame_update() hedefe yönelme (steering) yapar.
## Topla: şut / pas / sürme seçenekleri fayda puanıyla karşılaştırılır.

enum Action { SHOOT, PASS, DRIBBLE }

const PD = preload("res://scripts/match/pitch_dimensions.gd")

var player: FootballPlayer
var team_ai: TeamAI
var slot := Vector2.ZERO
var target := Vector3.ZERO
var sprint := false
var speed_scale := 1.0
var role := ""

var _decision_timer := 0.0
var _dribble_dir := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func setup(p: FootballPlayer, ai: TeamAI, formation_slot: Vector2) -> void:
	player = p
	team_ai = ai
	slot = formation_slot
	target = p.global_position
	_rng.randomize()


# --- Kare bazlı --------------------------------------------------------------

func frame_update(delta: float) -> void:
	_decision_timer -= delta
	steer()


func steer() -> void:
	var ball := team_ai.possession.ball
	player.has_look_target = true
	player.look_target = ball.global_position
	if player.has_ball() and _dribble_dir != Vector3.ZERO:
		player.move_input = _dribble_dir
		player.sprint_input = sprint
		return
	var to := PlayerActions.horizontal(target - player.global_position)
	var d := to.length()
	if d < 0.4:
		player.move_input = Vector3.ZERO
		player.sprint_input = false
	else:
		player.move_input = to / d * clampf(d / 1.5, 0.25, 1.0) * speed_scale
		player.sprint_input = sprint and d > 3.0 and player.stamina > 20.0


# --- Tick bazlı (TeamAI'dan) ---------------------------------------------------

## ctx: {"role": String, "point": Vector3, "opponent": FootballPlayer}
func think(ctx: Dictionary) -> void:
	if _decision_timer > 0.0:
		return
	_decision_timer = team_ai.difficulty.reaction_time
	role = ctx.role
	sprint = false
	speed_scale = 1.0
	if role != "owner":
		_dribble_dir = Vector3.ZERO
	match role:
		"owner":
			_decide_with_ball()
		"press":
			_press()
		"chase":
			target = ctx.point
			sprint = true
		_:
			target = ctx.point
			sprint = PlayerActions.horizontal(target - player.global_position).length() > 8.0


func _press() -> void:
	var opp := team_ai.possession.owner_player
	if opp == null:
		return
	var own_goal := Vector3(-player.attack_sign() * PD.HALF_LENGTH, 0.0, 0.0)
	# Rakip ile kendi kalemiz arasında dur
	target = opp.global_position + PlayerActions.horizontal(own_goal - opp.global_position).normalized() * 0.8
	var intensity := team_ai.difficulty.press_intensity
	sprint = intensity >= 0.75
	speed_scale = lerpf(0.7, 1.0, intensity)
	var d := PlayerActions.horizontal(opp.global_position - player.global_position).length()
	var chance := team_ai.difficulty.tackle_chance
	if d < 1.4 and _rng.randf() < chance:
		player.shoulder_challenge()
	elif d > 1.2 and d < 2.8 and _rng.randf() < chance * 0.4:
		var to_ball := PlayerActions.horizontal(team_ai.possession.ball.global_position - player.global_position).normalized()
		if player.facing.dot(to_ball) > 0.8:
			player.slide_tackle()


func _decide_with_ball() -> void:
	var mates := team_ai.team.players.filter(func(m: FootballPlayer) -> bool: return m != player and not m.is_goalkeeper)
	var mate_pos: Array[Vector3] = []
	for m in mates:
		mate_pos.append(m.global_position)
	var opp_pos := team_ai.opponent_positions()
	var choice := choose_action(player.global_position, player.attack_sign(), mate_pos, opp_pos, team_ai.difficulty.decision_noise, _rng)
	match choice.type:
		Action.SHOOT:
			_dribble_dir = Vector3.ZERO
			var gk := team_ai.opponent_goalkeeper()
			var side := -signf(gk.global_position.z) if gk and absf(gk.global_position.z) > 0.3 else (1.0 if _rng.randf() < 0.5 else -1.0)
			var aim := Vector3(player.attack_sign() * PD.HALF_LENGTH, 0.0, side * (PD.GOAL_WIDTH * 0.5 - _rng.randf_range(0.5, 1.2)))
			player.shoot_at(aim, _rng.randf_range(0.55, 0.85))
		Action.PASS:
			_dribble_dir = Vector3.ZERO
			var mate: FootballPlayer = mates[choice.index]
			player.pass_to(mate, _pass_kind(mate, opp_pos))
		Action.DRIBBLE:
			_dribble_dir = dribble_direction(player.global_position, player.attack_sign(), opp_pos)
			sprint = choice.space > 6.0 and player.stamina > 30.0


func _pass_kind(mate: FootballPlayer, opps: Array[Vector3]) -> PassTargeting.Kind:
	var from := player.global_position
	var lane := 0.0
	for o in opps:
		lane += PassTargeting.lane_block(from, mate.global_position, o)
	var d := PlayerActions.horizontal(mate.global_position - from).length()
	if lane > 0.4 and d > 15.0:
		return PassTargeting.Kind.LOB
	var progress := (mate.global_position.x - from.x) * player.attack_sign()
	if progress > 6.0 and _rng.randf() < 0.4:
		return PassTargeting.Kind.THROUGH
	return PassTargeting.Kind.SHORT


# --- Fayda fonksiyonları (saf, test edilebilir) ---------------------------------

static func choose_action(from: Vector3, attack_sign: float, mates: Array[Vector3], opps: Array[Vector3], noise: float, rng: RandomNumberGenerator) -> Dictionary:
	var drib := dribble_utility(from, attack_sign, opps)
	var best := {"type": Action.DRIBBLE, "index": -1, "utility": drib.utility + rng.randf_range(-noise, noise), "space": drib.space}
	var shoot := shoot_utility(from, attack_sign, opps) + rng.randf_range(-noise, noise)
	if shoot > best.utility:
		best = {"type": Action.SHOOT, "index": -1, "utility": shoot, "space": drib.space}
	for i in mates.size():
		var u := pass_utility(from, mates[i], attack_sign, opps) + rng.randf_range(-noise, noise)
		if u > best.utility:
			best = {"type": Action.PASS, "index": i, "utility": u, "space": drib.space}
	return best


static func shoot_utility(from: Vector3, attack_sign: float, opps: Array[Vector3]) -> float:
	var goal := Vector3(attack_sign * PD.HALF_LENGTH, 0.0, 0.0)
	var d := PlayerActions.horizontal(goal - from).length()
	if d > 30.0:
		return -INF
	var u := 1.8 - d / 16.0 - maxf(0.0, absf(from.z) - 8.0) / 20.0
	for o in opps:
		if absf(o.x - goal.x) > 6.0: # kaleciyi sayma
			u -= PassTargeting.lane_block(from, goal, o) * 0.5
	return u


static func pass_utility(from: Vector3, mate: Vector3, attack_sign: float, opps: Array[Vector3]) -> float:
	var d := PlayerActions.horizontal(mate - from).length()
	if d < 4.0 or d > 35.0:
		return -INF
	var progress := (mate.x - from.x) * attack_sign / 20.0
	var nearest := 99.0
	var lane := 0.0
	for o in opps:
		nearest = minf(nearest, PlayerActions.horizontal(o - mate).length())
		lane += PassTargeting.lane_block(from, mate, o)
	return 0.3 + progress * 0.5 + clampf(nearest / 8.0, 0.0, 1.0) * 0.4 - lane * 0.9


static func dribble_utility(from: Vector3, attack_sign: float, opps: Array[Vector3]) -> Dictionary:
	var fwd := Vector3(attack_sign, 0.0, 0.0)
	var space := 12.0
	var pressure := 0.0
	for o in opps:
		var to := PlayerActions.horizontal(o - from)
		var dd := to.length()
		if dd < 2.0:
			pressure += (2.0 - dd) / 2.0 * 0.4
		if dd > 0.01 and to.normalized().dot(fwd) > 0.7:
			space = minf(space, dd)
	# Kaleye çok yaklaşınca sürmek yerine bitirmek daha değerli
	var goal_d := absf(attack_sign * PD.HALF_LENGTH - from.x)
	var near_goal := maxf(0.0, 22.0 - goal_d) * 0.03
	return {"utility": 0.3 + clampf(space / 10.0, 0.0, 1.0) * 0.5 - pressure - near_goal, "space": space}


## Kaleye doğru, yakın rakiplerden kaçan sürme yönü.
static func dribble_direction(from: Vector3, attack_sign: float, opps: Array[Vector3]) -> Vector3:
	var goal := Vector3(attack_sign * PD.HALF_LENGTH, 0.0, 0.0)
	var dir := PlayerActions.horizontal(goal - from).normalized()
	for o in opps:
		var away := PlayerActions.horizontal(from - o)
		var dd := away.length()
		if dd < 5.0 and dd > 0.01:
			dir += away / dd * (5.0 - dd) / 5.0 * 1.2
	# Saha içinde kal
	if absf(from.z) > PD.HALF_WIDTH - 4.0:
		dir.z -= signf(from.z) * 0.8
	return dir.normalized()
