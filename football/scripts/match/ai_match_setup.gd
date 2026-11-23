extends Node3D
## 5v5 AI test maçı. human_team: 0 = ev sahibini siz kontrol edersiniz, -1 = AI'ya karşı AI.
## Gol/aut olunca top ortaya, oyuncular diziliş konumlarına döner (kurallar Faz 5'te).

signal goal_scored(team_id: int)

const PlayerScene = preload("res://scenes/player.tscn")

@export var human_team := 0
@export var formation_id := "5v5_2-1-1"
@export var difficulty_level := ""

var possession: Possession
var home: Team
var away: Team
var home_ai: TeamAI
var away_ai: TeamAI
var formation: Formation
var score := [0, 0]
var shots := 0

@onready var ball: Ball = $Ball
@onready var events: MatchEvents = $MatchEvents
@onready var camera: Camera3D = get_node_or_null("Camera")


func _ready() -> void:
	formation = Formation.load_formation(formation_id)
	var level := difficulty_level if difficulty_level != "" else AIDifficulty.default_level()
	var difficulty := AIDifficulty.load_level(level)
	possession = Possession.new()
	possession.name = "Possession"
	possession.ball = ball
	add_child(possession)
	home = _make_team(0, "Kırmızılar", Color(0.85, 0.15, 0.15), human_team == 0)
	away = _make_team(1, "Maviler", Color(0.15, 0.35, 0.9), human_team == 1)
	_spawn(home)
	_spawn(away)
	home_ai = _make_ai(home, away, difficulty)
	away_ai = _make_ai(away, home, difficulty)
	if human_team >= 0:
		var t := home if human_team == 0 else away
		var input := HumanInputController.new()
		input.team = t
		input.camera = camera
		add_child(input)
		var hud: CanvasLayer = preload("res://scripts/ui/player_hud.gd").new()
		hud.team = t
		add_child(hud)
	events.event_detected.connect(_on_event)
	reset_positions()


func _make_team(id: int, team_name: String, color: Color, human: bool) -> Team:
	var t := Team.new()
	t.name = team_name
	t.team_id = id
	t.team_name = team_name
	t.color = color
	t.human = human
	t.possession = possession
	add_child(t)
	return t


func _make_ai(t: Team, opp: Team, difficulty: AIDifficulty) -> TeamAI:
	var ai := TeamAI.new()
	ai.name = t.team_name + "AI"
	add_child(ai)
	ai.setup(t, opp, possession, difficulty, formation)
	return ai


func _spawn(t: Team) -> void:
	for i in formation.slots.size():
		var p: FootballPlayer = PlayerScene.instantiate()
		p.stats = PlayerStats.new()
		p.stats.number = i + 1
		p.stats.player_name = "%s %d" % [formation.roles[i], i + 1]
		p.is_goalkeeper = formation.roles[i] == "GK"
		if p.is_goalkeeper:
			p.stats.goalkeeping = 75
		add_child(p)
		p.shot_taken.connect(func(_pw: float) -> void: shots += 1)
		t.add_player(p)


## Oyuncuları başlama konumlarına, topu ortaya alır.
func reset_positions() -> void:
	for t in [home, away]:
		for i in t.players.size():
			var p: FootballPlayer = t.players[i]
			p.global_position = Formation.kickoff_position(formation.slots[i], p.attack_sign())
			p.velocity = Vector3.ZERO
			p.facing = Vector3(p.attack_sign(), 0.0, 0.0)
			p.holding_ball = false
			p.state = FootballPlayer.State.NORMAL
	ball.reset_to(Vector3(0, PitchDimensions.BALL_RADIUS, 0))
	events.restart_play()


func _on_event(ev: Dictionary) -> void:
	if ev.type == MatchEvents.EventType.GOAL:
		score[ev.team] += 1
		goal_scored.emit(ev.team)
	print("Olay: %s | Skor %d - %d" % [MatchEvents.describe(ev), score[0], score[1]])
	await get_tree().create_timer(1.0).timeout
	reset_positions()
