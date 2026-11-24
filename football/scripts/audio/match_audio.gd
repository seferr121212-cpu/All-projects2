class_name MatchAudio
extends Node
## Maç sesleri: top vuruşu (güce göre), düdük (duran top / devre / maç sonu), direk ve file,
## seyirci uğultusu (topun kaleye yakınlığı ve gol anında yükselen heyecan) + spiker olayları.

const PD = preload("res://scripts/match/pitch_dimensions.gd")

var ball: Ball
var flow: MatchFlow
var stadium: Node
var commentator: Commentator
var excitement := 0.2

var _kick: AudioStreamPlayer3D
var _impact: AudioStreamPlayer3D
var _whistle: AudioStreamPlayer
var _crowd: AudioStreamPlayer
var _cheer: AudioStreamPlayer
var _boost := 0.0
var _impact_cooldown := 0.0
var _prev_state := -1


func setup(p_ball: Ball, p_flow: MatchFlow = null, p_stadium: Node = null) -> void:
	ball = p_ball
	flow = p_flow
	stadium = p_stadium
	SettingsStore.ensure_audio_buses()
	_kick = _player3d("SFX")
	_impact = _player3d("SFX")
	_whistle = _player("SFX")
	_crowd = _player("Crowd")
	_cheer = _player("Crowd")
	_crowd.stream = AudioSynth.get_stream("crowd")
	_crowd.volume_db = -14.0
	_crowd.play()
	commentator = Commentator.new()
	commentator.name = "Commentator"
	add_child(commentator)
	ball.kicked.connect(_on_kicked)
	ball.body_entered.connect(_on_ball_contact)
	if flow:
		flow.state_changed.connect(_on_state)
		flow.score_changed.connect(func(_h: int, _a: int) -> void: goal())
		flow.referee.offside_called.connect(func(_o, _p) -> void: commentator.say("offside"))
		flow.referee.foul_called.connect(func(_o, _v, _p, card: int) -> void: commentator.say("card" if card != Referee.Card.NONE else "foul"))


func _player3d(bus: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = bus
	p.unit_size = 25.0
	p.max_polyphony = 4
	add_child(p)
	return p


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _on_kicked(_team: int, is_dribble: bool) -> void:
	var speed := ball.linear_velocity.length()
	_kick.global_position = ball.global_position
	_kick.stream = AudioSynth.get_stream("kick")
	# Dokunuşlar kısık, sert vuruşlar yüksek
	var strength := clampf(speed / 30.0, 0.08 if is_dribble else 0.25, 1.0)
	_kick.volume_db = linear_to_db(strength)
	_kick.pitch_scale = 1.15 - strength * 0.25
	_kick.play()
	if not is_dribble and speed > 18.0 and _near_goal_factor(ball.global_position) > 0.4:
		commentator.say("shot")


func _on_ball_contact(body: Node) -> void:
	if _impact_cooldown > 0.0:
		return
	var kind := ""
	if body.name == "Frame":
		kind = "post"
	elif body.name == "Net":
		kind = "net"
	if kind == "":
		return
	_impact_cooldown = 0.2
	_impact.global_position = ball.global_position
	_impact.stream = AudioSynth.get_stream(kind)
	_impact.volume_db = linear_to_db(clampf(ball.linear_velocity.length() / 20.0, 0.2, 1.0))
	_impact.play()
	if kind == "post":
		commentator.say("post")
		_boost = maxf(_boost, 0.5)


func whistle(long := false, times := 1) -> void:
	_whistle.stream = AudioSynth.get_stream("whistle_long" if long else "whistle_short")
	_whistle.play()
	for i in times - 1:
		await get_tree().create_timer(_whistle.stream.get_length() + 0.25).timeout
		if is_inside_tree():
			_whistle.play()


func goal() -> void:
	_cheer.stream = AudioSynth.get_stream("cheer")
	_cheer.play()
	_boost = 1.0
	commentator.say("goal")


func _on_state(s: int) -> void:
	match s:
		MatchFlow.MatchState.STOPPED:
			whistle()
		MatchFlow.MatchState.HALF_TIME:
			whistle(true, 2)
			commentator.say("half_time")
		MatchFlow.MatchState.FULL_TIME:
			whistle(true, 3)
			commentator.say("full_time")
		MatchFlow.MatchState.PLAYING:
			if _prev_state == MatchFlow.MatchState.KICKOFF:
				whistle()
				commentator.say("kickoff")
	_prev_state = s


## Topun en yakın kaleye yakınlığı (0: orta saha, 1: kale ağzı).
static func _near_goal_factor(pos: Vector3) -> float:
	return clampf(1.0 - (PD.HALF_LENGTH - absf(pos.x)) / 40.0, 0.0, 1.0)


## Hedef heyecan: taban + kaleye yakınlık + olay kabarması.
static func target_excitement(ball_pos: Vector3, boost: float) -> float:
	return clampf(0.2 + 0.5 * _near_goal_factor(ball_pos) * (1.0 - clampf(absf(ball_pos.z) / 40.0, 0.0, 0.6)) + boost, 0.0, 1.0)


func _process(delta: float) -> void:
	if ball == null:
		return
	_impact_cooldown -= delta
	_boost = maxf(0.0, _boost - delta * 0.2)
	var target := target_excitement(ball.global_position, _boost)
	excitement = lerpf(excitement, target, 1.0 - exp(-1.5 * delta))
	_crowd.volume_db = lerpf(-16.0, -3.0, excitement)
	_crowd.pitch_scale = 0.95 + excitement * 0.12
	if stadium and stadium.has_method("set_excitement"):
		stadium.set_excitement(excitement)
