class_name Team
extends Node
## Takım: oyuncu listesi ve insan kontrolündeki oyuncu (otomatik/elle değiştirme).

signal controlled_changed(player: FootballPlayer)

const AUTO_SWITCH_MARGIN := 4.0 # m: daha yakın arkadaş bu kadar öndeyse geç

@export var team_id := 0
@export var team_name := "Takım"
@export var color := Color(0.85, 0.15, 0.15)
@export var human := false
@export var goalkeeper_color := Color(0.95, 0.85, 0.1)

var players: Array[FootballPlayer] = []
var controlled: FootballPlayer
var possession: Possession

var _auto_cooldown := 0.0


func add_player(p: FootballPlayer) -> void:
	p.team_id = team_id
	players.append(p)
	if p.visual and p.visual.has_method("set_team_color"):
		p.visual.set_team_color(goalkeeper_color if p.is_goalkeeper else color)
	p.pass_made.connect(_on_pass_made)
	if possession:
		possession.register_player(p)


func set_controlled(p: FootballPlayer) -> void:
	if p == controlled:
		return
	if controlled:
		controlled.set_controlled(false)
		controlled.move_input = Vector3.ZERO
		controlled.sprint_input = false
		controlled.cancel_shot()
	controlled = p
	if p:
		p.set_controlled(true)
		p.has_look_target = false
	controlled_changed.emit(p)


## Topa en yakın oyuncu (exclude hariç).
func closest_to_ball(exclude: FootballPlayer = null) -> FootballPlayer:
	if possession == null or possession.ball == null:
		return null
	var bp := possession.ball.global_position
	var best: FootballPlayer = null
	var best_d := INF
	for p in players:
		if p == exclude or p.is_goalkeeper:
			continue
		var d := PlayerActions.horizontal(p.global_position - bp).length()
		if d < best_d:
			best_d = d
			best = p
	return best


func switch_manual() -> void:
	var p := closest_to_ball(controlled)
	if p:
		set_controlled(p)
		_auto_cooldown = 1.0


func _physics_process(delta: float) -> void:
	if not human or possession == null:
		return
	_auto_cooldown -= delta
	if controlled == null:
		set_controlled(closest_to_ball())
	var owner := possession.owner_player
	if owner != null and owner.team_id == team_id:
		if owner != controlled and not owner.is_goalkeeper:
			set_controlled(owner) # topu alan arkadaşa geç
		return
	if _auto_cooldown > 0.0 or controlled == null:
		return
	var nearest := closest_to_ball()
	if nearest == null or nearest == controlled:
		return
	var bp := possession.ball.global_position
	var d_cur := PlayerActions.horizontal(controlled.global_position - bp).length()
	var d_new := PlayerActions.horizontal(nearest.global_position - bp).length()
	if d_cur - d_new > AUTO_SWITCH_MARGIN:
		set_controlled(nearest)
		_auto_cooldown = 0.6


func _on_pass_made(target: FootballPlayer) -> void:
	if human and target != null and not target.is_goalkeeper:
		set_controlled(target)
		_auto_cooldown = 0.8
