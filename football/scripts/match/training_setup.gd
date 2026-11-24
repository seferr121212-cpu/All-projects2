extends Node3D
## Antrenman: rakipsiz serbest oyun, yalnızca AI kaleci. reset_ball (T) topu ayağa getirir.
## Top dışarı çıkınca ya da gol olunca top kısa süre sonra oyuncunun önüne döner.

const PD = preload("res://scripts/match/pitch_dimensions.gd")
const PlayerScene = preload("res://scenes/player.tscn")

@export var team_id := "kuzey"
@export var opponent_id := "liman"
@export var difficulty_level := "medium"
@export var use_game_config := true

var possession: Possession
var me: Team
var keeper_team: Team
var keeper_ai: TeamAI
var player: FootballPlayer
var shots := 0
var goals := 0
var pause_menu: CanvasLayer
var _stats_label: Label

@onready var ball: Ball = $Ball
@onready var events: MatchEvents = $MatchEvents
@onready var camera: Camera3D = $Camera


func _ready() -> void:
	var game := get_node_or_null("/root/Game")
	if use_game_config and game != null and not game.match_config.is_empty():
		team_id = game.match_config.get("home", team_id)
		opponent_id = game.match_config.get("away", opponent_id)
		difficulty_level = game.match_config.get("difficulty", difficulty_level)
	var my_data := TeamData.load_team(team_id)
	var opp_data := TeamData.load_team(opponent_id)
	possession = Possession.new()
	possession.ball = ball
	add_child(possession)
	me = _team(0, my_data, true)
	keeper_team = _team(1, opp_data, false)
	# En iyi şutçu forvet
	var field := my_data.players.filter(func(s: PlayerStats) -> bool: return s.position != "GK")
	field.sort_custom(func(a: PlayerStats, b: PlayerStats) -> bool: return a.shooting > b.shooting)
	player = _spawn(me, field[0], false, Vector3(25, 0, 0))
	var gk_stats := PlayerStats.new()
	for s in opp_data.players:
		if s.position == "GK":
			gk_stats = s
	_spawn(keeper_team, gk_stats, true, Vector3(PD.HALF_LENGTH - 1.0, 0, 0))
	keeper_ai = TeamAI.new()
	add_child(keeper_ai)
	keeper_ai.setup(keeper_team, me, possession, AIDifficulty.load_level(difficulty_level), Formation.load_formation("5v5_2-1-1"))
	me.set_controlled(player)
	player.shot_taken.connect(func(_p: float) -> void: shots += 1)

	var input := HumanInputController.new()
	input.team = me
	input.camera = camera
	add_child(input)
	var hud: CanvasLayer = preload("res://scripts/ui/player_hud.gd").new()
	hud.team = me
	add_child(hud)
	_build_stats_hud()
	pause_menu = preload("res://scripts/ui/pause_menu.gd").new()
	add_child(pause_menu)
	events.event_detected.connect(_on_event)
	reset_ball()


func _team(id: int, data: TeamData, human: bool) -> Team:
	var t := Team.new()
	t.team_id = id
	t.name = data.short_name
	t.team_name = data.display_name
	t.color = data.color if id == 0 or not TeamData.kits_clash(data.color, me.color) else data.away_color
	t.goalkeeper_color = data.goalkeeper_color
	t.human = human
	t.possession = possession
	add_child(t)
	return t


func _spawn(t: Team, stats: PlayerStats, gk: bool, pos: Vector3) -> FootballPlayer:
	var p: FootballPlayer = PlayerScene.instantiate()
	p.stats = stats
	p.is_goalkeeper = gk
	add_child(p)
	t.add_player(p)
	p.teleport(pos, Vector3(t.attack_direction, 0, 0))
	return p


## Topu oyuncunun önüne getirir.
func reset_ball() -> void:
	var pos := player.global_position + player.facing * 0.8
	ball.reset_to(Vector3(clampf(pos.x, -PD.HALF_LENGTH + 1, PD.HALF_LENGTH - 2), PD.BALL_RADIUS, clampf(pos.z, -PD.HALF_WIDTH + 1, PD.HALF_WIDTH - 1)))
	events.restart_play()


func _on_event(ev: Dictionary) -> void:
	if ev.type == MatchEvents.EventType.GOAL and ev.team == 0:
		goals += 1
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree():
		reset_ball()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reset_ball"):
		reset_ball()
	_stats_label.text = tr("TRAIN_TITLE") + "  ·  " + (tr("TRAIN_STATS") % [shots, goals]) + "\n" + tr("TRAIN_HINT")


func _build_stats_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_stats_label = Label.new()
	_stats_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_stats_label.position = Vector2(-400, 14)
	_stats_label.custom_minimum_size = Vector2(800, 0)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 22)
	_stats_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_stats_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_stats_label)
