class_name Possession
extends Node
## Topa sahip olma: topa yakın ve kontrol edilebilir hızdaki oyuncu sahiplenir.
## Pas/şut (dribble olmayan vuruş) sahipliği bırakır; vuran kısa süre tekrar alamaz.

signal owner_changed(new_owner: FootballPlayer, old_owner: FootballPlayer)

const CONTROL_RADIUS := 1.1
const KEEP_RADIUS := 3.0
const MAX_CONTROL_HEIGHT := 0.8
const BASE_CONTROL_SPEED := 9.0

@export var ball_path: NodePath

var ball: Ball
var owner_player: FootballPlayer
## Son sahiplik bırakma nedeni (hata ayıklama/istatistik): kick, distance, height, forced
var last_release_reason := ""
var _no_retake := {} # FootballPlayer -> kalan süre
var _players: Array[FootballPlayer] = [] # kayıtlı oyuncular (her karede grup taraması yapılmaz)


func _ready() -> void:
	if ball == null and not ball_path.is_empty():
		ball = get_node_or_null(ball_path) as Ball
	if ball:
		ball.kicked.connect(_on_ball_kicked)


func register_player(p: FootballPlayer) -> void:
	p.ball = ball
	p.possession = self
	if not p in _players:
		_players.append(p)


func unregister_player(p: FootballPlayer) -> void:
	_players.erase(p)
	_no_retake.erase(p)
	if owner_player == p:
		_set_owner(null)


func all_players() -> Array[FootballPlayer]:
	return _players


func players_of_team(team_id: int, exclude: FootballPlayer = null) -> Array[FootballPlayer]:
	var out: Array[FootballPlayer] = []
	for p in all_players():
		if p.team_id == team_id and p != exclude:
			out.append(p)
	return out


## Sahipliği doğrudan verir (ör. kaleci topu tuttu).
func take(p: FootballPlayer) -> void:
	_set_owner(p)


func force_release(p: FootballPlayer, no_retake_time: float) -> void:
	if owner_player == p:
		last_release_reason = "forced"
		_set_owner(null)
	_no_retake[p] = no_retake_time


func _physics_process(delta: float) -> void:
	for p in _no_retake.keys():
		_no_retake[p] -= delta
		if _no_retake[p] <= 0.0:
			_no_retake.erase(p)
	if ball == null:
		return
	if owner_player != null:
		if _dist(owner_player) > KEEP_RADIUS or ball.global_position.y > 1.5:
			last_release_reason = "distance" if _dist(owner_player) > KEEP_RADIUS else "height"
			_set_owner(null)
		else:
			return
	var best: FootballPlayer = null
	var best_d := CONTROL_RADIUS
	for p in all_players():
		if (p.state != FootballPlayer.State.NORMAL and p.state != FootballPlayer.State.SKILL) or _no_retake.has(p):
			continue
		var d := _dist(p)
		# Kontrol topun hızına bağlı (karşıdan koşarak karşılamak da mümkün olmalı)
		var ball_speed := ball.linear_velocity.length()
		var max_speed := BASE_CONTROL_SPEED * (1.0 + 0.6 * PlayerStats.ratio(p.stats.dribbling))
		if d < best_d and ball.global_position.y < MAX_CONTROL_HEIGHT and ball_speed < max_speed:
			best = p
			best_d = d
	if best != null:
		_set_owner(best)
		# İlk kontrol: top yastıklanır, oyuncunun hızının altında kalır
		var v := PlayerActions.horizontal(best.velocity) * 0.6
		ball.kick(v, Vector3.ZERO, best.team_id, true)


func _dist(p: FootballPlayer) -> float:
	return PlayerActions.horizontal(ball.global_position - p.global_position).length()


func _set_owner(p: FootballPlayer) -> void:
	if p == owner_player:
		return
	var old := owner_player
	owner_player = p
	owner_changed.emit(p, old)


func _on_ball_kicked(_team: int, is_dribble: bool) -> void:
	if not is_dribble and owner_player != null:
		_no_retake[owner_player] = 0.35
		last_release_reason = "kick"
		_set_owner(null)
