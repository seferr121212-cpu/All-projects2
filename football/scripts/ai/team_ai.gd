class_name TeamAI
extends Node
## Takım AI: faz (Hücum/Savunma/Geçiş) ve rol dağıtımı zamanlanmış tick ile (10 Hz).
## Roller: owner, press, cover, mark, chase, support, formation. Kaleci GoalkeeperAI ile.
## İnsan takımında kontrol edilen oyuncu AI'dan muaftır.

const TICK := 0.1
const PD = preload("res://scripts/match/pitch_dimensions.gd")

var team: Team
var opponent: Team
var possession: Possession
var difficulty: AIDifficulty
var formation: Formation
var phase := Formation.Phase.TRANSITION
var ais := {} # FootballPlayer -> PlayerAI
var enabled := true

var _accum := 0.0
## Tick fazı (0..TICK): iki takımın hesaplaması aynı kareye düşmesin
var tick_offset := 0.0
## Markaj için rakibin formasyon noktasına en fazla uzaklığı (m)
var mark_radius := 15.0


func setup(p_team: Team, p_opponent: Team, p_possession: Possession, p_difficulty: AIDifficulty, p_formation: Formation) -> void:
	team = p_team
	opponent = p_opponent
	possession = p_possession
	difficulty = p_difficulty
	formation = p_formation
	ais.clear()
	_accum = tick_offset
	for i in team.players.size():
		var p := team.players[i]
		var ai: PlayerAI = GoalkeeperAI.new() if p.is_goalkeeper else PlayerAI.new()
		ai.setup(p, self, formation.slots[i] if i < formation.slots.size() else Vector2.ZERO)
		ai.position_role = formation.roles[i] if i < formation.roles.size() else "MID"
		ais[p] = ai
		p.accuracy_bonus = difficulty.accuracy_bonus
		if not p.pass_made.is_connected(_on_pass_made):
			p.pass_made.connect(_on_pass_made)


func is_ai(p: FootballPlayer) -> bool:
	return not (team.human and p == team.controlled)


func _physics_process(delta: float) -> void:
	if not enabled or team == null:
		return
	_accum += delta
	_time += delta
	if _accum >= TICK:
		_accum = fmod(_accum, TICK)
		tick()
	for p in team.players:
		if is_ai(p):
			ais[p].frame_update(delta)


func opponent_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in opponent.players:
		out.append(p.global_position)
	return out


func opponent_goalkeeper() -> FootballPlayer:
	for p in opponent.players:
		if p.is_goalkeeper:
			return p
	return null


## Rakibin sondan ikinci oyuncusunun hücum yönündeki konumu (basit ofsayt çizgisi).
func offside_line_x() -> float:
	var xs: Array[float] = []
	for p in opponent.players:
		xs.append(p.global_position.x * team.players[0].attack_sign())
	xs.sort()
	return xs[xs.size() - 2] if xs.size() >= 2 else PD.HALF_LENGTH


func tick() -> void:
	var ball := possession.ball
	var owner := possession.owner_player
	if owner != null and owner.team_id == team.team_id:
		phase = Formation.Phase.ATTACK
	elif owner != null:
		phase = Formation.Phase.DEFENSE
	else:
		phase = Formation.Phase.TRANSITION

	var field: Array[FootballPlayer] = []
	var gk: FootballPlayer = null
	for p in team.players:
		if p.is_goalkeeper:
			gk = p
		elif is_ai(p):
			field.append(p)
	_update_defensive_line()
	# Pas alıcısı: top sahipsizken karşılamaya koşar, diğer rollerden çıkarılır
	var receiver: FootballPlayer = null
	_active_receiver = null
	if _receiver != null and _time < _receiver_until and possession.owner_player == null and is_ai(_receiver) and _receiver in field:
		receiver = _receiver
		field.erase(receiver)
		ais[receiver].think({"role": "receive"})
		_active_receiver = receiver
	elif possession.owner_player != null:
		_receiver = null
	var bp := ball.global_position
	field.sort_custom(func(a: FootballPlayer, b: FootballPlayer) -> bool:
		return a.global_position.distance_squared_to(bp) < b.global_position.distance_squared_to(bp))
	var human_nearest := team.human and team.controlled != null and (field.is_empty() or team.controlled.global_position.distance_squared_to(bp) < field[0].global_position.distance_squared_to(bp))

	match phase:
		Formation.Phase.ATTACK:
			_assign_attack(field, owner)
		Formation.Phase.DEFENSE:
			_assign_defense(field, owner, human_nearest)
		_:
			_assign_transition(field, human_nearest)
	if gk != null:
		ais[gk].think({"role": "gk", "gk_rush": _gk_should_rush(gk)})


func _formation_point(p: FootballPlayer) -> Vector3:
	var t := Formation.target_for(ais[p].slot, possession.ball.global_position, p.attack_sign(), phase)
	if ais[p].position_role == "DEF" and _defensive_line != INF:
		t.x = _defensive_line * p.attack_sign()
	return t


## Savunma hattı: savunmacıların formasyon hedeflerinin ortalaması (hücum yönünde x).
## Savunmacılar aynı hizada durur, böylece ofsayt çizgisi tutarlı olur.
var _defensive_line := INF

## Pas sonrası alıcı: top yoldayken topu karşılamaya koşar
var _receiver: FootballPlayer
var _receiver_until := 0.0
var _time := 0.0
var _active_receiver: FootballPlayer


func _update_defensive_line() -> void:
	var sum := 0.0
	var n := 0
	for p in team.players:
		if ais.has(p) and ais[p].position_role == "DEF" and not p.is_goalkeeper:
			sum += Formation.target_for(ais[p].slot, possession.ball.global_position, p.attack_sign(), phase).x * p.attack_sign()
			n += 1
	_defensive_line = sum / n if n >= 2 else INF


func _assign_attack(field: Array[FootballPlayer], owner: FootballPlayer) -> void:
	var line := offside_line_x()
	var opp := opponent_positions()
	for p in field:
		if p == owner:
			ais[p].think({"role": "owner"})
			continue
		var base := _formation_point(p)
		var point := _find_space(base, owner, opp)
		# Ofsayta düşmemek için çizginin gerisinde kal (top daha ilerideyse topa kadar)
		var s := p.attack_sign()
		var limit := maxf(line, possession.ball.global_position.x * s) - 0.5
		if point.x * s > limit:
			point.x = limit * s
		ais[p].think({"role": "support", "point": point})


## Boşa kaçma: slot çevresindeki adaylardan rakiplerden en uzak ve pas yolu açık olanı.
func _find_space(base: Vector3, owner: FootballPlayer, opp: Array[Vector3]) -> Vector3:
	var s := team.players[0].attack_sign()
	var offsets := [Vector3.ZERO, Vector3(5 * s, 0, 0), Vector3(0, 0, 5), Vector3(0, 0, -5), Vector3(4 * s, 0, 4), Vector3(4 * s, 0, -4)]
	var best := base
	var best_score := -INF
	for o in offsets:
		var c: Vector3 = base + o
		c.x = clampf(c.x, -PD.HALF_LENGTH + 2.0, PD.HALF_LENGTH - 2.0)
		c.z = clampf(c.z, -PD.HALF_WIDTH + 2.0, PD.HALF_WIDTH - 2.0)
		var nearest := 10.0
		var lane := 0.0
		for q in opp:
			nearest = minf(nearest, PlayerActions.horizontal(q - c).length())
			if owner != null:
				lane += PassTargeting.lane_block(owner.global_position, c, q)
		var score: float = nearest - lane * 4.0 - (o as Vector3).length() * 0.15
		if score > best_score:
			best_score = score
			best = c
	return best


func _assign_defense(field: Array[FootballPlayer], owner: FootballPlayer, human_nearest: bool) -> void:
	var roles := ["cover"] if human_nearest else ["press", "cover"]
	var marked := {owner: true}
	var own_goal := Vector3(-team.players[0].attack_sign() * PD.HALF_LENGTH, 0.0, 0.0)
	for i in field.size():
		var p := field[i]
		var role: String = roles[i] if i < roles.size() else "mark"
		match role:
			"press":
				ais[p].think({"role": "press"})
			"cover":
				var bp := possession.ball.global_position
				ais[p].think({"role": "cover", "point": bp.lerp(own_goal, 0.35)})
			_:
				var target_opp := _nearest_unmarked(_formation_point(p), marked)
				if target_opp == null:
					ais[p].think({"role": "formation", "point": _formation_point(p)})
				else:
					marked[target_opp] = true
					var mp := target_opp.global_position + PlayerActions.horizontal(own_goal - target_opp.global_position).normalized() * 1.5
					ais[p].think({"role": "mark", "point": mp, "opponent": target_opp})


func _nearest_unmarked(from: Vector3, marked: Dictionary) -> FootballPlayer:
	var best: FootballPlayer = null
	var best_d := mark_radius
	for o in opponent.players:
		if o.is_goalkeeper or marked.has(o):
			continue
		var d := PlayerActions.horizontal(o.global_position - from).length()
		if d < best_d:
			best_d = d
			best = o
	return best


func _assign_transition(field: Array[FootballPlayer], human_nearest: bool) -> void:
	var ball := possession.ball
	var predicted := ball.global_position + PlayerActions.horizontal(ball.linear_velocity) * 0.4
	predicted.x = clampf(predicted.x, -PD.HALF_LENGTH, PD.HALF_LENGTH)
	predicted.z = clampf(predicted.z, -PD.HALF_WIDTH, PD.HALF_WIDTH)
	predicted.y = 0.0
	for i in field.size():
		var p := field[i]
		if i == 0 and not human_nearest and _active_receiver == null:
			ais[p].think({"role": "chase", "point": predicted})
		else:
			ais[p].think({"role": "formation", "point": _formation_point(p)})


func _on_pass_made(target: FootballPlayer) -> void:
	if target != null and target.team_id == team.team_id:
		_receiver = target
		_receiver_until = _time + 3.0


## Kaleci ceza sahasındaki sahipsiz topa, en yakın oyuncuysa çıkar.
func _gk_should_rush(gk: FootballPlayer) -> bool:
	if possession.owner_player != null:
		return false
	var bp := possession.ball.global_position
	var s := -gk.attack_sign()
	if bp.x * s < PD.HALF_LENGTH - PD.PENALTY_AREA_DEPTH or absf(bp.z) > PD.PENALTY_AREA_WIDTH * 0.5:
		return false
	var d_gk := gk.global_position.distance_squared_to(bp)
	for p in team.players + opponent.players:
		if p != gk and p.global_position.distance_squared_to(bp) < d_gk:
			return false
	return true
