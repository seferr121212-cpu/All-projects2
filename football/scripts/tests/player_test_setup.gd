extends Node3D
## Oyuncu kontrol test sahnesi: 3'e 3, AI yok (kontrolsüz oyuncular durur).
## Top dışarı çıkınca ortaya döner.

const PlayerScene = preload("res://scenes/player.tscn")

var possession: Possession
var home: Team
var away: Team

@onready var ball: Ball = $Ball
@onready var events: MatchEvents = $MatchEvents
@onready var camera: Camera3D = $Camera


func _ready() -> void:
	possession = Possession.new()
	possession.name = "Possession"
	possession.ball = ball
	add_child(possession)
	home = _make_team(0, "Kırmızılar", Color(0.85, 0.15, 0.15), true)
	away = _make_team(1, "Maviler", Color(0.15, 0.35, 0.9), false)
	_spawn(home, [Vector3(-3, 0, 0), Vector3(-12, 0, -12), Vector3(-12, 0, 12)], ["Kaptan", "Sol Kanat", "Sağ Kanat"])
	_spawn(away, [Vector3(10, 0, 0), Vector3(18, 0, -8), Vector3(18, 0, 8)], ["Stoper", "Bek 1", "Bek 2"])
	home.set_controlled(home.players[0])

	var input := HumanInputController.new()
	input.name = "HumanInput"
	input.team = home
	input.camera = camera
	add_child(input)

	var hud: CanvasLayer = preload("res://scripts/ui/player_hud.gd").new()
	hud.team = home
	add_child(hud)

	# Yan görünüm: +X sağda, ileri tuşu -Z
	camera.yaw = 0.0
	camera.pitch = -0.6
	camera.distance = 26.0
	events.event_detected.connect(_on_event)
	ball.reset_to(Vector3(0, PitchDimensions.BALL_RADIUS, 0))


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


func _spawn(team: Team, positions: Array, names: Array) -> void:
	for i in positions.size():
		var p: FootballPlayer = PlayerScene.instantiate()
		p.stats = PlayerStats.new()
		p.stats.player_name = names[i]
		p.stats.number = i + 1 + team.team_id * 10
		add_child(p)
		p.global_position = positions[i]
		p.facing = Vector3(1.0 if team.team_id == 0 else -1.0, 0.0, 0.0)
		team.add_player(p)


func _on_event(ev: Dictionary) -> void:
	print("Olay: ", MatchEvents.describe(ev))
	await get_tree().create_timer(1.5).timeout
	ball.reset_to(Vector3(0, PitchDimensions.BALL_RADIUS, 0))
	events.restart_play()
