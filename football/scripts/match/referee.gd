class_name Referee
extends Node
## Hakem: ofsayt takibi, faul değerlendirmesi, kartlar.
## Ofsayt: pas anında ofsayt pozisyonundaki arkadaşlar kaydedilir; biri topu alırsa ofsayt çalınır.
## Rakip topu kontrol ederse kayıt silinir (kaleci kurtarışı/çelmesi silmez).

signal offside_called(offender: FootballPlayer, position: Vector3)
signal foul_called(offender: FootballPlayer, victim: FootballPlayer, position: Vector3, card: int)
signal player_sent_off(player: FootballPlayer)

enum Card { NONE, YELLOW, RED }

const PD = preload("res://scripts/match/pitch_dimensions.gd")

var ball: Ball
var possession: Possession
var teams: Array[Team] = []
var enabled := true
## Bir sonraki vuruş taç/korner/aut ise ofsayt uygulanmaz
var next_kick_exempt := false

var yellow_cards := {} # FootballPlayer -> sayı
var _candidates: Array[FootballPlayer] = []
var _candidate_team := -1
var _rng := RandomNumberGenerator.new()


func setup(p_ball: Ball, p_possession: Possession, p_teams: Array[Team]) -> void:
	ball = p_ball
	possession = p_possession
	teams = p_teams
	_rng.randomize()
	ball.kicked.connect(_on_ball_kicked)
	possession.owner_changed.connect(_on_owner_changed)
	for t in teams:
		for p in t.players:
			p.foul_committed.connect(_on_foul.bind(p))


func clear_offside() -> void:
	_candidates.clear()
	_candidate_team = -1


func _on_ball_kicked(team_id: int, is_dribble: bool) -> void:
	if is_dribble or not enabled:
		return
	var kicker := ball.last_kicker as FootballPlayer
	if next_kick_exempt:
		next_kick_exempt = false
		clear_offside()
		return
	if kicker == null:
		return
	# Rakip kalecinin kurtarışı/çelmesi kaydı silmez
	if kicker.team_id != _candidate_team and kicker.is_goalkeeper and _candidate_team >= 0:
		return
	clear_offside()
	_candidate_team = team_id
	var defenders := _positions(teams[1 - team_id].players)
	for p in teams[team_id].players:
		if p != kicker and OffsideRule.is_offside_position(p.global_position, p.attack_sign(), ball.global_position, defenders):
			_candidates.append(p)


func _on_owner_changed(new_owner: FootballPlayer, _old: FootballPlayer) -> void:
	if new_owner == null or not enabled:
		return
	if new_owner.team_id != _candidate_team:
		clear_offside()
		return
	if new_owner in _candidates:
		var pos := new_owner.global_position
		clear_offside()
		offside_called.emit(new_owner, pos)


func _on_foul(victim: FootballPlayer, offender: FootballPlayer) -> void:
	if not enabled:
		return
	var from_behind := offender.facing.dot(victim.facing) > 0.5
	var speed := PlayerActions.horizontal(offender.velocity).length() + 3.0 # kayma başlangıç hızı
	var defenders: Array[Vector3] = []
	for d in teams[offender.team_id].players:
		if d != offender and not d.is_goalkeeper:
			defenders.append(d.global_position)
	var dogso := is_dogso(victim.global_position, victim.attack_sign(), defenders)
	var in_box := in_penalty_area(victim.global_position, victim.attack_sign())
	var card := decide_card(from_behind, speed, dogso, in_box, _rng.randf(), _rng.randf())
	card = _apply_card(offender, card)
	foul_called.emit(offender, victim, victim.global_position, card)


## Sarı kart birikimi: ikinci sarı kırmızıya döner. Kesin kartı döndürür.
func _apply_card(p: FootballPlayer, card: int) -> int:
	if card == Card.YELLOW:
		yellow_cards[p] = yellow_cards.get(p, 0) + 1
		if yellow_cards[p] >= 2:
			card = Card.RED
	if card == Card.RED:
		player_sent_off.emit(p)
	return card


## Kart kararı (saf fonksiyon). r1, r2: 0..1 rastgele değerler.
static func decide_card(from_behind: bool, speed: float, dogso: bool, in_box: bool, r1: float, r2: float) -> int:
	if dogso and not in_box:
		return Card.RED # bariz gol fırsatını faulle engelleme
	if dogso:
		return Card.YELLOW # ceza sahasında topa oynama girişimi: penaltı + sarı
	if from_behind and speed > 8.5 and r2 < 0.2:
		return Card.RED # tehlikeli, arkadan sert müdahale
	var p_yellow := 0.15 + (0.35 if from_behind else 0.0) + clampf((speed - 5.0) / 10.0, 0.0, 0.3)
	return Card.YELLOW if r1 < p_yellow else Card.NONE


## Bariz gol fırsatı: kaleye yakın, merkezi ve önünde (kaleci hariç) savunmacı yok.
static func is_dogso(victim_pos: Vector3, attack_sign: float, defenders_no_gk: Array[Vector3]) -> bool:
	var goal_x := attack_sign * PD.HALF_LENGTH
	if absf(goal_x - victim_pos.x) > 25.0 or absf(victim_pos.z) > 12.0:
		return false
	for d in defenders_no_gk:
		if (d.x - victim_pos.x) * attack_sign > 0.0 and absf(d.z - victim_pos.z) < 8.0:
			return false
	return true


## Pozisyon, attack_sign yönündeki (hücum edilen) ceza sahasının içinde mi?
static func in_penalty_area(pos: Vector3, attack_sign: float) -> bool:
	return pos.x * attack_sign > PD.HALF_LENGTH - PD.PENALTY_AREA_DEPTH and absf(pos.z) < PD.PENALTY_AREA_WIDTH * 0.5 and absf(pos.x) <= PD.HALF_LENGTH


static func _positions(players: Array[FootballPlayer]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in players:
		out.append(p.global_position)
	return out
