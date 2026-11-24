extends Node3D
## Maç sahnesi kurulumu: takımlar, AI, hakem, maç akışı, kameralar, tekrar kaydı, HUD.
## human_team: 0 = ev sahibini siz kontrol edersiniz, 1 = deplasman, -1 = AI'ya karşı AI.

const PlayerScene = preload("res://scenes/player.tscn")

@export var human_team := 0
@export var home_team_id := "kuzey"
@export var away_team_id := "liman"
## Boşsa takımın teams.json'daki formasyonu kullanılır (ör. "5v5_2-1-1" ile 5'e 5)
@export var formation_override := ""
@export var difficulty_level := ""
@export var half_minutes_override := 0.0 # >0 ise settings.json yerine (testler için)
@export var replay_enabled := true
## Menüden gelen Game.match_config varsa onu kullan
@export var use_game_config := true

var pause_menu: CanvasLayer

var possession: Possession
var home: Team
var away: Team
var home_ai: TeamAI
var away_ai: TeamAI
var home_formation: Formation
var away_formation: Formation
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
	_apply_game_config()
	var home_data := TeamData.load_team(home_team_id)
	var away_data := TeamData.load_team(away_team_id)
	home_formation = Formation.load_formation(formation_override if formation_override != "" else home_data.formation_id)
	away_formation = Formation.load_formation(formation_override if formation_override != "" else away_data.formation_id)
	var level := difficulty_level if difficulty_level != "" else AIDifficulty.default_level()
	var difficulty := AIDifficulty.load_level(level)
	possession = Possession.new()
	possession.name = "Possession"
	possession.ball = ball
	add_child(possession)
	var away_color := away_data.away_color if TeamData.kits_clash(home_data.color, away_data.color) else away_data.color
	home = _make_team(0, home_data, home_data.color, human_team == 0)
	away = _make_team(1, away_data, away_color, human_team == 1)
	_spawn(home, home_data, home_formation)
	_spawn(away, away_data, away_formation)
	home_ai = _make_ai(home, away, difficulty, home_formation)
	away_ai = _make_ai(away, home, difficulty, away_formation)
	away_ai.tick_offset = TeamAI.TICK * 0.5 # iki takımın AI hesabı farklı karelere düşsün

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
	pause_menu = preload("res://scripts/ui/pause_menu.gd").new()
	pause_menu.can_pause = func() -> bool: return flow.state != MatchFlow.MatchState.REPLAY and flow.state != MatchFlow.MatchState.FULL_TIME
	add_child(pause_menu)
	flow.match_finished.connect(_on_match_finished)
	flow.start()


func _apply_game_config() -> void:
	var game := get_node_or_null("/root/Game")
	if not use_game_config or game == null or game.match_config.is_empty():
		return
	var c: Dictionary = game.match_config
	home_team_id = c.get("home", home_team_id)
	away_team_id = c.get("away", away_team_id)
	formation_override = c.get("formation", formation_override)
	human_team = int(c.get("human_team", human_team))
	half_minutes_override = float(c.get("half_minutes", half_minutes_override))
	difficulty_level = c.get("difficulty", difficulty_level)
	replay_enabled = bool(c.get("replay", replay_enabled))


func _on_match_finished(final: Array) -> void:
	await get_tree().create_timer(2.5).timeout
	if is_inside_tree():
		pause_menu.show_result("%s  %d - %d  %s" % [home.team_name, final[0], final[1], away.team_name])


func _make_team(id: int, data: TeamData, color: Color, human: bool) -> Team:
	var t := Team.new()
	t.name = data.short_name if data.short_name != "" else "Team%d" % id
	t.team_id = id
	t.team_name = data.display_name
	t.color = color
	t.goalkeeper_color = data.goalkeeper_color
	t.human = human
	t.possession = possession
	add_child(t)
	return t


func _make_ai(t: Team, opp: Team, difficulty: AIDifficulty, formation: Formation) -> TeamAI:
	var ai := TeamAI.new()
	ai.name = t.name + "AI"
	add_child(ai)
	ai.setup(t, opp, possession, difficulty, formation)
	if formation.slots.size() <= 5:
		ai.mark_radius = 25.0 # 5'e 5'te saha geniş, markaj daha uzaktan
	return ai


func _spawn(t: Team, data: TeamData, formation: Formation) -> void:
	var lineup := TeamData.assign_to_formation(data.players, formation.roles)
	for i in formation.slots.size():
		var p: FootballPlayer = PlayerScene.instantiate()
		p.stats = lineup[i]
		p.is_goalkeeper = formation.roles[i] == "GK"
		p.name = "%s_%d" % [t.name, p.stats.number]
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
