class_name GoalkeeperAI
extends PlayerAI
## Kaleci AI: açıyı kapatacak pozisyon, şuta (tepki gecikmeli) uzanma,
## top tutma veya çelme, tuttuktan sonra degaj/pas.

var _hold_timer := 0.0
var _shot_seen := -1.0
var _time := 0.0
var _catch_cooldown := 0.0
var _rush := false


func defend_sign() -> float:
	return -player.attack_sign()


func frame_update(delta: float) -> void:
	_time += delta
	_decision_timer -= delta
	_catch_cooldown -= delta
	if player.holding_ball:
		_update_hold(delta)
		return
	if player.state == FootballPlayer.State.NORMAL:
		_check_shot()
	_check_catch()
	if player.has_ball() and not player.holding_ball:
		_distribute() # ayağındaki topu uzaklaştır
		return
	steer()


func think(ctx: Dictionary) -> void:
	if player.holding_ball:
		return
	var ball := team_ai.possession.ball
	_rush = ctx.get("gk_rush", false)
	sprint = _rush
	if _rush:
		target = ball.global_position
	elif not _diving_target_set():
		target = position_for(ball.global_position, defend_sign())


var _step_target_until := 0.0


func _diving_target_set() -> bool:
	return _time < _step_target_until


## Topla kale ortası arasındaki doğru üzerinde, mesafeye göre öne çıkan konum.
static func position_for(ball_pos: Vector3, goal_sign: float) -> Vector3:
	var goal := Vector3(goal_sign * PD.HALF_LENGTH, 0.0, 0.0)
	var to_ball := PlayerActions.horizontal(ball_pos - goal)
	var d := to_ball.length()
	var dir := to_ball / d if d > 0.1 else Vector3(-goal_sign, 0.0, 0.0)
	if dir.x * -goal_sign < 0.2: # top kale çizgisinin gerisinde/çok yan
		dir = Vector3(-goal_sign * 0.2, 0.0, signf(dir.z) * 0.98).normalized()
	var depth := clampf(d / 6.0, 0.8, 4.0)
	var p := goal + dir * depth
	p.z = clampf(p.z, -(PD.GOAL_WIDTH * 0.5 - 0.3), PD.GOAL_WIDTH * 0.5 - 0.3)
	var inward := maxf(absf(goal.x - p.x), 0.8)
	p.x = goal.x - goal_sign * inward
	return p


func _in_own_area(pos: Vector3) -> bool:
	var s := defend_sign()
	return pos.x * s > PD.HALF_LENGTH - PD.PENALTY_AREA_DEPTH and pos.x * s < PD.HALF_LENGTH + 0.5 and absf(pos.z) < PD.PENALTY_AREA_WIDTH * 0.5


func _check_shot() -> void:
	var ball := team_ai.possession.ball
	var v := ball.linear_velocity
	var s := defend_sign()
	var threatening := v.x * s > 8.0 and team_ai.possession.owner_player == null and absf(ball.global_position.x) > PD.HALF_LENGTH - 35.0 and ball.global_position.x * s > 0.0
	if not threatening:
		_shot_seen = -1.0
		return
	if _shot_seen < 0.0:
		_shot_seen = _time
	if _time - _shot_seen < team_ai.difficulty.gk_reaction:
		return
	var gk := player.global_position
	var t := (gk.x - ball.global_position.x) / v.x
	if t < 0.0 or t > 1.2:
		return
	var cross_z := ball.global_position.z + v.z * t
	if absf(cross_z) > PD.GOAL_WIDTH * 0.5 + 1.0:
		return
	var lateral := cross_z - gk.z
	if absf(lateral) > 0.9 and t < 0.7:
		var speed := minf(absf(lateral) / maxf(t, 0.25), 6.5)
		player.dive(Vector3(0.0, 0.0, signf(lateral) * speed), 0.7)
	else:
		target = Vector3(gk.x, 0.0, cross_z)
		_step_target_until = _time + 0.5


func _check_catch() -> void:
	if _catch_cooldown > 0.0:
		return
	var ball := team_ai.possession.ball
	var bp := ball.global_position
	if not _in_own_area(bp) or bp.y > 2.7:
		return
	var owner := team_ai.possession.owner_player
	if owner != null and owner.team_id == player.team_id:
		return
	var diving := player.state == FootballPlayer.State.DIVE
	if player.state != FootballPlayer.State.NORMAL and not diving:
		return
	var hands := player.global_position + Vector3.UP * (0.5 if diving else 1.0)
	var reach := 1.7 if diving else 1.1
	if bp.distance_to(hands) > reach:
		return
	_catch_cooldown = 0.5
	var speed := ball.linear_velocity.length()
	var skill := player.stats.goalkeeping + team_ai.difficulty.gk_skill_bonus
	var p_catch := clampf(skill / 100.0 * 1.25 - speed / 45.0, 0.15, 0.97)
	if _rng.randf() < p_catch:
		player.holding_ball = true
		team_ai.possession.take(player)
		ball.hold(_hold_point())
		_hold_timer = _rng.randf_range(1.0, 2.0)
	else:
		# Çelme: topu kaleden uzağa, yana sektir
		var out := Vector3(-defend_sign() * maxf(absf(ball.linear_velocity.x) * 0.3, 3.0), 2.5, ball.linear_velocity.z * 0.4 + _rng.randf_range(-3.0, 3.0))
		ball.kick(out, Vector3.ZERO, player.team_id, false, player)


func _hold_point() -> Vector3:
	return player.global_position + player.facing * 0.4 + Vector3.UP * 1.0


func _update_hold(delta: float) -> void:
	var ball := team_ai.possession.ball
	ball.hold(_hold_point())
	player.move_input = Vector3.ZERO
	player.sprint_input = false
	player.has_look_target = true
	player.look_target = Vector3(player.attack_sign() * 20.0, 0.0, 0.0)
	_hold_timer -= delta
	if _hold_timer <= 0.0:
		_distribute()


## Degaj: açık arkadaşa pas, yoksa ileri uzun vuruş.
func _distribute() -> void:
	var opp_pos := team_ai.opponent_positions()
	var best: FootballPlayer = null
	var best_u := 0.45
	for m in team_ai.team.players:
		if m == player:
			continue
		var u := PlayerAI.pass_utility(player.global_position, m.global_position, player.attack_sign(), opp_pos)
		if u > best_u:
			best_u = u
			best = m
	var ok := false
	if best != null:
		var d := PlayerActions.horizontal(best.global_position - player.global_position).length()
		ok = player.pass_to(best, PassTargeting.Kind.SHORT if d < 20.0 else PassTargeting.Kind.LOB)
	if not ok:
		var point := Vector3(player.attack_sign() * _rng.randf_range(0.0, 15.0), 0.0, _rng.randf_range(-15.0, 15.0))
		ok = player.clear_to(point)
	if not ok and player.holding_ball:
		player.holding_ball = false
		team_ai.possession.ball.release_hold()
	_catch_cooldown = 1.0
