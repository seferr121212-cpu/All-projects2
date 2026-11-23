class_name FootballPlayer
extends CharacterBody3D
## Futbolcu: hareket (ivme, dönüş sınırı, sprint/stamina), top sürme ve aksiyonlar.
## Girdi dışarıdan verilir (insan kontrolcüsü veya ileride AI): move_input, sprint_input, do_*().

signal pass_made(target: FootballPlayer)
signal shot_taken(power: float)
signal tackle_made(victim: FootballPlayer, won_ball: bool)
signal foul_committed(victim: FootballPlayer)

enum State { NORMAL, SLIDING, STUMBLE, SKILL }

const GRAVITY := 9.81
const TURN_RATE_SLOW := 14.0 # rad/s, dururken
const TURN_RATE_FAST := 4.5 # rad/s, tam sprintte
const DECELERATION := 16.0
const KICK_REACH := 1.5
const TOUCH_REACH := 1.1
const SHOT_CHARGE_TIME := 1.0

@export var stats: PlayerStats
@export var team_id := 0

var ball: Ball
var possession: Possession
var move_input := Vector3.ZERO # dünya uzayında yön, uzunluk 0..1
var sprint_input := false
var facing := Vector3.RIGHT
var stamina := 100.0
var state := State.NORMAL
var shot_charge := -1.0 # >= 0 iken şut gücü doluyor
var is_sprinting := false

var _state_timer := 0.0
var _touch_cooldown := 0.0
var _skill_cooldown := 0.0
var _challenge_cooldown := 0.0
var _slide_resolved := false
var _rng := RandomNumberGenerator.new()

@onready var visual: Node3D = get_node_or_null("Visual")


func _ready() -> void:
	if stats == null:
		stats = PlayerStats.new()
	stamina = stats.max_stamina
	add_to_group("players")
	_rng.randomize()
	_apply_facing()


func attack_sign() -> float:
	return 1.0 if team_id == 0 else -1.0


func has_ball() -> bool:
	return possession != null and possession.owner_player == self


func set_controlled(value: bool) -> void:
	if visual and visual.has_method("set_indicator"):
		visual.set_indicator(value)


func _physics_process(delta: float) -> void:
	_state_timer -= delta
	_touch_cooldown -= delta
	_skill_cooldown -= delta
	_challenge_cooldown -= delta
	match state:
		State.NORMAL:
			_update_movement(delta)
		State.SLIDING:
			_update_slide(delta)
		State.STUMBLE:
			_damp_horizontal(6.0, delta)
			if _state_timer <= 0.0:
				_set_state(State.NORMAL)
		State.SKILL:
			if _state_timer <= 0.0:
				_set_state(State.NORMAL)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_update_stamina(delta)
	if shot_charge >= 0.0:
		shot_charge = minf(1.0, shot_charge + delta / SHOT_CHARGE_TIME)
	if has_ball() and state != State.SLIDING and state != State.STUMBLE:
		_dribble()
	_apply_facing()


# --- Hareket -------------------------------------------------------------

func _update_movement(delta: float) -> void:
	var input := Vector3(move_input.x, 0.0, move_input.z).limit_length(1.0)
	var input_len := input.length()
	is_sprinting = sprint_input and stamina > 1.0 and input_len > 0.3
	var max_speed := stats.run_speed()
	if is_sprinting:
		# Stamina azaldıkça sprint hızı düşer
		var fatigue := clampf(stamina / 30.0, 0.0, 1.0)
		max_speed = lerpf(stats.run_speed(), stats.sprint_speed(), fatigue)
	if has_ball():
		max_speed *= lerpf(0.85, 0.95, PlayerStats.ratio(stats.dribbling))
	if shot_charge >= 0.0:
		max_speed *= 0.6

	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var desired := Vector3.ZERO
	if input_len > 0.1:
		var dir := input / input_len
		var speed_ratio := clampf(hv.length() / stats.sprint_speed(), 0.0, 1.0)
		var turn_rate := lerpf(TURN_RATE_SLOW, TURN_RATE_FAST, speed_ratio)
		if has_ball():
			turn_rate *= lerpf(0.7, 0.95, PlayerStats.ratio(stats.dribbling))
		facing = rotate_towards(facing, dir, turn_rate * delta)
		# Hareket bakış yönünde; keskin dönüşte yavaşlar (ani 180° dönüş yok)
		desired = facing * input_len * max_speed * clampf(facing.dot(dir), 0.3, 1.0)
	var rate := stats.acceleration() if desired.length() > hv.length() else DECELERATION
	hv = hv.move_toward(desired, rate * delta)
	velocity.x = hv.x
	velocity.z = hv.z


func _damp_horizontal(k: float, delta: float) -> void:
	var f := exp(-k * delta)
	velocity.x *= f
	velocity.z *= f


func _update_stamina(delta: float) -> void:
	if is_sprinting and state == State.NORMAL:
		stamina -= 9.0 * (1.3 - PlayerStats.ratio(stats.physical) * 0.6) * delta
	else:
		var moving := Vector3(velocity.x, 0.0, velocity.z).length() > 1.0
		stamina += (3.0 if moving else 6.0) * delta
	stamina = clampf(stamina, 0.0, stats.max_stamina)


static func rotate_towards(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	var angle := from.signed_angle_to(to, Vector3.UP)
	return from.rotated(Vector3.UP, clampf(angle, -max_angle, max_angle)).normalized()


func _apply_facing() -> void:
	if facing.length_squared() > 0.001:
		global_basis = Basis.looking_at(facing, Vector3.UP)


func _set_state(s: State) -> void:
	state = s
	if visual and visual.has_method("set_pose"):
		visual.set_pose(s)


# --- Top sürme -----------------------------------------------------------

func _dribble() -> void:
	if _touch_cooldown > 0.0 or ball == null or ball.global_position.y > 0.5:
		return
	if _ball_distance() > TOUCH_REACH:
		return
	var res := Dribble.compute_touch(global_position, velocity, facing, ball.global_position, stats.dribbling)
	if res.need:
		ball.kick(res.velocity, Vector3.ZERO, team_id, true)
		_touch_cooldown = Dribble.touch_cooldown(stats.dribbling)


func _ball_distance() -> float:
	if ball == null:
		return INF
	return PlayerActions.horizontal(ball.global_position - global_position).length()


func _can_kick() -> bool:
	return has_ball() and state != State.STUMBLE and _ball_distance() <= KICK_REACH


# --- Aksiyonlar ----------------------------------------------------------

func do_pass(kind: PassTargeting.Kind) -> void:
	if not _can_kick():
		return
	var aim := move_input if move_input.length() > 0.2 else facing
	var mates := possession.players_of_team(team_id, self)
	var opps := possession.players_of_team(1 - team_id)
	var idx := PassTargeting.pick(global_position, aim, _positions(mates), _positions(opps), kind)
	var target: FootballPlayer = mates[idx] if idx >= 0 else null
	var point: Vector3
	if target == null:
		var dist := 14.0 if kind == PassTargeting.Kind.SHORT else 25.0
		point = global_position + PlayerActions.horizontal(aim).normalized() * dist
	elif kind == PassTargeting.Kind.SHORT:
		point = target.global_position
	else:
		var extra := Vector3(attack_sign() * (4.0 if kind == PassTargeting.Kind.THROUGH else 1.5), 0.0, 0.0)
		point = PlayerActions.lead_target(global_position, target.global_position, target.velocity, 15.0, extra)
	var v: Vector3
	if kind == PassTargeting.Kind.LOB:
		v = PlayerActions.lob_velocity(ball.global_position, point, 35.0)
	else:
		v = PlayerActions.ground_pass_velocity(ball.global_position, point, 5.0 if kind == PassTargeting.Kind.THROUGH else 4.0)
	v = PlayerActions.apply_error(v, stats.passing, 0.3, _rng)
	var spin := Vector3.ZERO
	if kind == PassTargeting.Kind.LOB:
		spin = Vector3.UP.cross(PlayerActions.horizontal(v).normalized()) * -15.0 # hafif alt falso
	ball.kick(v, spin, team_id)
	pass_made.emit(target)


func start_shot_charge() -> void:
	if has_ball() and shot_charge < 0.0:
		shot_charge = 0.0


func cancel_shot() -> void:
	shot_charge = -1.0


## aim_lateral: -1..1 (kale ağzında sol/sağ nişan).
func release_shot(aim_lateral: float) -> void:
	if shot_charge < 0.0:
		return
	var power := shot_charge
	shot_charge = -1.0
	if not _can_kick():
		return
	var target := Vector3(attack_sign() * PitchDimensions.HALF_LENGTH, 0.0, clampf(aim_lateral, -1.0, 1.0) * (PitchDimensions.GOAL_WIDTH * 0.5 - 0.5))
	var v := PlayerActions.shot_velocity(ball.global_position, target, power, stats.shooting)
	v = PlayerActions.apply_error(v, stats.shooting, power, _rng)
	ball.kick(v, Vector3.ZERO, team_id)
	shot_taken.emit(power)


func slide_tackle() -> void:
	if state != State.NORMAL or has_ball():
		return
	var speed := maxf(PlayerActions.horizontal(velocity).length() + 3.0, 7.0)
	velocity = facing * speed
	_slide_resolved = false
	_state_timer = 0.7
	_set_state(State.SLIDING)


func _update_slide(delta: float) -> void:
	_damp_horizontal(1.2, delta) # ~3.3 m kayma
	if not _slide_resolved and ball != null and possession != null:
		var victim := possession.owner_player
		var to_ball := PlayerActions.horizontal(ball.global_position - global_position)
		var ball_hit := to_ball.length() < 1.2 and to_ball.normalized().dot(facing) > -0.2 and ball.global_position.y < 0.5
		var victim_hit := false
		if victim != null and victim.team_id != team_id:
			victim_hit = PlayerActions.horizontal(victim.global_position - global_position).length() < 1.0
		if ball_hit:
			# Önce topa temas: temiz müdahale
			_slide_resolved = true
			var side := facing.cross(Vector3.UP) * _rng.randf_range(-2.0, 2.0)
			ball.kick(facing * 7.0 + side, Vector3.ZERO, team_id)
			if victim != null and victim.team_id != team_id:
				victim.stumble(0.6)
			tackle_made.emit(victim, true)
		elif victim_hit:
			# Önce oyuncuya temas: faul (Faz 5'te hakem değerlendirecek)
			_slide_resolved = true
			victim.stumble(1.0)
			foul_committed.emit(victim)
	if _state_timer <= 0.0:
		_state_timer = 0.45
		_set_state(State.STUMBLE) # yerden kalkma


func shoulder_challenge() -> void:
	if state != State.NORMAL or _challenge_cooldown > 0.0 or possession == null:
		return
	var opp := possession.owner_player
	if opp == null or opp.team_id == team_id:
		return
	if PlayerActions.horizontal(opp.global_position - global_position).length() > 1.4:
		return
	_challenge_cooldown = 0.8
	var p_win := clampf(0.5 + (stats.physical - opp.stats.physical) / 150.0 + (stats.defending - opp.stats.dribbling) / 300.0, 0.15, 0.85)
	var push := PlayerActions.horizontal(opp.global_position - global_position).normalized()
	if _rng.randf() < p_win:
		opp.velocity += push * 3.0
		opp.stumble(0.35)
		tackle_made.emit(opp, true)
	else:
		velocity -= push * 2.0
		stumble(0.35)


func skill_move() -> void:
	if not has_ball() or state != State.NORMAL or _skill_cooldown > 0.0:
		return
	var right := facing.cross(Vector3.UP).normalized()
	var lateral := move_input.dot(right)
	var side := right * (signf(lateral) if absf(lateral) > 0.2 else (1.0 if _rng.randf() < 0.5 else -1.0))
	var hspeed := PlayerActions.horizontal(velocity).length()
	ball.kick(side * 3.5 + facing * hspeed * 0.7, Vector3.ZERO, team_id, true)
	velocity = side * 4.5 + facing * hspeed * 0.5
	_skill_cooldown = 1.2
	_touch_cooldown = 0.3
	_state_timer = 0.3
	_set_state(State.SKILL)


func stumble(duration: float) -> void:
	shot_charge = -1.0
	_state_timer = duration
	_set_state(State.STUMBLE)
	if has_ball():
		possession.force_release(self, duration + 0.2)


static func _positions(players: Array[FootballPlayer]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in players:
		out.append(p.global_position)
	return out
