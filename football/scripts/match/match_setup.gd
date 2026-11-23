extends Node3D
## Maç sahnesi kurulumu: takımlar, AI, hakem, maç akışı, kameralar, tekrar kaydı, HUD.
## human_team: 0 = ev sahibini siz kontrol edersiniz, 1 = deplasman, -1 = AI'ya karşı AI.

const PlayerScene = preload("res://scenes/player.tscn")

@export var human_team := 0
@export var formation_id := "5v5_2-1-1"
@export var difficulty_level := ""
@export var half_minutes_override := 0.0 # >0 ise settings.json yerine (testler için)
@export var replay_enabled := true

var possession: Possession
var home: Team
var away: Team
var home_ai: TeamAI
var away_ai: TeamAI
var formation: Formation
var referee: Referee
var flow: MatchFlow
var director: CameraDirector
var recorder: ReplayRecorder
var shots := 0
var score: Array:
	get:
		return flow.score if flow else [0, 0]

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

	var input: HumanInputController = null
	if human_team >= 0:
		var t := home if human_team == 0 else away
		input = HumanInputController.new()
		input.name = "HumanInput"
		input.team = t
		add_child(input)
		var hud: CanvasLayer = preload("res://scripts/ui/player_hud.gd").new()
		hud.team = t
		add_child(hud)
	_setup_cameras(input)

	referee = Referee.new()
	referee.name = "Referee"
	add_child(referee)
	var both: Array[Team] = [home, away]
	referee.setup(ball, possession, both)

	flow = MatchFlow.new()
	flow.name = "MatchFlow"
	flow.ball = ball
	flow.possession = possession
	flow.events = events
	flow.referee = referee
	flow.teams.assign([home, away])
	flow.team_ais.assign([home_ai, away_ai])
	flow.director = director
	flow.recorder = recorder
	flow.load_settings()
	if half_minutes_override > 0.0:
		flow.half_seconds = half_minutes_override * 60.0
	flow.replay_enabled = replay_enabled
	add_child(flow)

	var match_hud: CanvasLayer = preload("res://scripts/ui/match_hud.gd").new()
	match_hud.flow = flow
	add_child(match_hud)
	flow.start()


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


func _setup_cameras(input: HumanInputController) -> void:
	director = CameraDirector.new()
	director.name = "CameraDirector"
	add_child(director)
	var replay := ReplayCamera.new()
	replay.name = "ReplayCamera"
	add_child(replay)
	director.replay_camera = replay
	if input:
		director.camera_changed.connect(func(cam: Camera3D) -> void: input.camera = cam)
	if camera:
		director.add_camera(camera)
	if input:
		var behind := BehindPlayerCamera.new()
		behind.name = "BehindCamera"
		behind.team = input.team
		add_child(behind)
		director.add_camera(behind)
		input.camera = director.active_camera()
	recorder = ReplayRecorder.new()
	recorder.name = "ReplayRecorder"
	add_child(recorder)
	recorder.track(ball)
	for p in home.players + away.players:
		recorder.track(p)
