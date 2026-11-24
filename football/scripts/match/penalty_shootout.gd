extends Node3D
## Penaltı atışları modu. human_team: atış yaparken nişan + basılı tutmalı şut,
## kalede uzanma yönü (vuruş anında sol/sağ). -1: AI'ya karşı AI.

signal finished(winner: int)

enum State { SETUP, WAIT_KICK, BALL_LIVE, RESULT, FINISHED }

const PD = preload("res://scripts/match/pitch_dimensions.gd")
const PlayerScene = preload("res://scenes/player.tscn")

@export var human_team := 0
@export var home_team_id := "kuzey"
@export var away_team_id := "liman"
@export var difficulty_level := "medium"
@export var ai_kick_delay := 1.2
@export var result_pause := 1.5
@export var use_game_config := true

var rules := ShootoutRules.new()
var state := State.SETUP
var teams_data: Array[TeamData] = []
var kickers := [[], []] # takım -> sıralı PlayerStats (şut değerine göre)
var kicker_bodies: Array[FootballPlayer] = []
var keeper_bodies: Array[FootballPlayer] = []
var possession: Possession
var difficulty: AIDifficulty
var kicker: FootballPlayer
var keeper: FootballPlayer
var pause_menu: CanvasLayer

var _timer := 0.0
var _live_time := 0.0
var _save_rolled := false
var _dove := false
var _kick_seen := -1.0
var _rng := RandomNumberGenerator.new()
var _hud_score: Label
var _hud_prompt: Label
var _hud_banner: Label
var _banner_time := 0.0

@onready var ball: Ball = $Ball
@onready var events: MatchEvents = $MatchEvents


func _ready() -> void:
	_rng.randomize()
	_apply_game_config()
	difficulty = AIDifficulty.load_level(difficulty_level)
	teams_data = [TeamData.load_team(home_team_id), TeamData.load_team(away_team_id)]
	possession = Possession.new()
	possession.ball = ball
	add_child(possession)
	for t in 2:
		var squad: Array[PlayerStats] = teams_data[t].players.duplicate()
		var field := squad.filter(func(s: PlayerStats) -> bool: return s.position != "GK")
		field.sort_custom(func(a: PlayerStats, b: PlayerStats) -> bool: return a.shooting > b.shooting)
		kickers[t] = field
		var gk_stats: PlayerStats = squad.filter(func(s: PlayerStats) -> bool: return s.position == "GK").front() if squad.any(func(s: PlayerStats) -> bool: return s.position == "GK") else PlayerStats.new()
		kicker_bodies.append(_spawn(t, field[0], false))
		keeper_bodies.append(_spawn(t, gk_stats, true))
	events.event_detected.connect(_on_event)
	ball.kicked.connect(_on_kicked)
	_build_hud()
	var cam: Camera3D = $Camera
	# Vurucunun sağ arkasından, top ve kale birlikte görünsün
	cam.global_position = Vector3(PD.HALF_LENGTH - PD.PENALTY_SPOT_DISTANCE - 7.5, 3.6, 2.6)
	cam.look_at(Vector3(PD.HALF_LENGTH, 1.0, 0.0))
	pause_menu = preload("res://scripts/ui/pause_menu.gd").new()
	add_child(pause_menu)
	_setup_kick()


func _apply_game_config() -> void:
	var game := get_node_or_null("/root/Game")
	if not use_game_config or game == null or game.match_config.is_empty():
		return
	var c: Dictionary = game.match_config
	home_team_id = c.get("home", home_team_id)
	away_team_id = c.get("away", away_team_id)
	human_team = int(c.get("human_team", human_team))
	difficulty_level = c.get("difficulty", difficulty_level)


func _spawn(team: int, stats: PlayerStats, gk: bool) -> FootballPlayer:
	var p: FootballPlayer = PlayerScene.instantiate()
	p.stats = stats
	p.is_goalkeeper = gk
	p.team_id = team
	add_child(p)
	# Penaltıda oyuncular birbirine çarpmaz (yer değiştirirken itişme olmasın)
	p.collision_mask = 1
	p.attack_direction = 1.0 # herkes +X kalesine atar
	var color := teams_data[team].goalkeeper_color if gk else teams_data[team].color
	if team == 1 and not gk and TeamData.kits_clash(teams_data[0].color, teams_data[1].color):
		color = teams_data[1].away_color
	p.visual.set_team_color(color)
	possession.register_player(p)
	p.locked = true
	_park(p)
	return p


func _park(p: FootballPlayer) -> void:
	var z := -6.0 + p.team_id * 3.0 + (1.5 if p.is_goalkeeper else 0.0)
	p.teleport(Vector3(0.0, 0.0, z), Vector3.RIGHT)


# --- Atış döngüsü ------------------------------------------------------------------

func _setup_kick() -> void:
	var t := rules.next_team()
	for p in kicker_bodies + keeper_bodies:
		_park(p)
		p.locked = true
	kicker = kicker_bodies[t]
	keeper = keeper_bodies[1 - t]
	var order: Array = kickers[t]
	kicker.stats = order[rules.kicks_taken(t) % order.size()]
	var spot := Vector3(PD.HALF_LENGTH - PD.PENALTY_SPOT_DISTANCE, PD.BALL_RADIUS, 0.0)
	ball.reset_to(spot)
	# Vurucu topun sol arkasında (koşu açısı); kamera sağdan topu görür
	kicker.teleport(Vector3(spot.x - 0.75, 0.0, -0.7), Vector3(0.75, 0.0, 0.7))
	keeper.teleport(Vector3(PD.HALF_LENGTH - 0.3, 0.0, 0.0), Vector3.LEFT)
	keeper.locked = false
	keeper.move_input = Vector3.ZERO
	keeper.has_look_target = true
	keeper.look_target = spot
	possession.take(kicker)
	events.ball_in_play = false
	_save_rolled = false
	_dove = false
	_kick_seen = -1.0
	_live_time = 0.0
	_timer = ai_kick_delay
	state = State.WAIT_KICK
	_update_hud()


func _physics_process(delta: float) -> void:
	_banner_time -= delta
	if _hud_banner:
		_hud_banner.modulate.a = clampf(_banner_time, 0.0, 1.0)
	match state:
		State.WAIT_KICK:
			_update_wait(delta)
		State.BALL_LIVE:
			_update_live(delta)
		State.RESULT:
			_timer -= delta
			if _timer <= 0.0:
				if rules.is_decided():
					_finish()
				else:
					_setup_kick()


func _update_wait(delta: float) -> void:
	if kicker.team_id == human_team:
		var aim := Input.get_axis("move_left", "move_right")
		if possession.owner_player != kicker and ball.global_position.distance_to(kicker.global_position) < 1.5:
			possession.take(kicker)
		if Input.is_action_just_pressed("shoot"):
			kicker.start_shot_charge()
		elif kicker.shot_charge >= 0.0 and not Input.is_action_pressed("shoot"):
			kicker.release_shot(aim)
		return
	_timer -= delta
	if _timer <= 0.0:
		var zs := [-2.9, -1.6, 0.0, 1.6, 2.9]
		var z: float = zs[_rng.randi_range(0, zs.size() - 1)]
		# Top henüz noktaya ışınlanmadıysa vuruş olmaz: kısa süre sonra tekrar dene
		if not possession.owner_player == kicker:
			possession.take(kicker)
		_timer = 999.0 if kicker.shoot_at(Vector3(PD.HALF_LENGTH, 0.0, z), _rng.randf_range(0.55, 0.8)) else 0.2


func _on_kicked(_team: int, is_dribble: bool) -> void:
	if is_dribble or state != State.WAIT_KICK:
		return
	state = State.BALL_LIVE
	events.restart_play()
	# Kaleci: insan ise vuruş anındaki yön tuşu, AI ise bazen tahmin (erken uzanma)
	if keeper.team_id == human_team:
		var dir := Input.get_axis("move_left", "move_right")
		if absf(dir) > 0.3:
			keeper.dive(Vector3(0, 0, signf(dir) * 6.0), 0.8)
			_dove = true
	elif _rng.randf() < 0.3:
		keeper.dive(Vector3(0, 0, (1.0 if _rng.randf() < 0.5 else -1.0) * 6.0), 0.8)
		_dove = true


func _update_live(delta: float) -> void:
	_live_time += delta
	var v := ball.linear_velocity
	# AI kaleci: tepki süresinden sonra topun kale çizgisini geçeceği yere uzanır
	if not _dove and keeper.team_id != human_team and _live_time >= difficulty.gk_reaction and v.x > 3.0:
		var t := (keeper.global_position.x - ball.global_position.x) / v.x
		var cross_z := ball.global_position.z + v.z * maxf(t, 0.0)
		var lateral := cross_z - keeper.global_position.z
		if absf(lateral) > 0.6:
			keeper.dive(Vector3(0, 0, signf(lateral) * minf(absf(lateral) / maxf(t, 0.2), 6.5)), 0.8)
		_dove = true
	_check_save()
	if _live_time > 4.0 or (_live_time > 0.8 and v.length() < 0.5) or (v.x < -1.0 and _live_time > 0.6):
		_resolve(false)


func _check_save() -> void:
	if _save_rolled or ball.global_position.x > PD.HALF_LENGTH:
		return
	var diving := keeper.state == FootballPlayer.State.DIVE
	var hands := keeper.global_position + Vector3.UP * (0.5 if diving else 1.0)
	if ball.global_position.distance_to(hands) > (1.7 if diving else 1.1):
		return
	_save_rolled = true
	var skill := keeper.stats.goalkeeping + (difficulty.gk_skill_bonus if keeper.team_id != human_team else 0)
	var p_save := clampf(skill / 100.0 * 1.25 - ball.linear_velocity.length() / 45.0, 0.15, 0.95)
	if _rng.randf() < p_save:
		var out := Vector3(-maxf(ball.linear_velocity.x * 0.3, 3.0), 2.0, _rng.randf_range(-4.0, 4.0))
		ball.kick(out, Vector3.ZERO, keeper.team_id, false, keeper)
		_show(tr("MSG_SAVED"), Color(0.7, 0.9, 1.0))


func _on_event(ev: Dictionary) -> void:
	if state != State.BALL_LIVE:
		return
	_resolve(ev.type == MatchEvents.EventType.GOAL)


func _resolve(scored: bool) -> void:
	if state != State.BALL_LIVE:
		return
	events.ball_in_play = false
	rules.record(kicker.team_id, scored)
	if scored:
		_show(tr("MSG_GOAL") % teams_data[kicker.team_id].short_name, Color(1, 0.85, 0.2))
	elif _banner_time <= 0.0:
		_show(tr("MSG_MISSED"), Color.WHITE)
	state = State.RESULT
	_timer = result_pause
	_update_hud()


func _finish() -> void:
	state = State.FINISHED
	var w := rules.winner()
	var text := tr("MSG_WINNER") % teams_data[w].display_name
	_show(text, Color(1, 0.85, 0.2))
	_update_hud()
	finished.emit(w)
	if human_team >= 0 or get_node_or_null("/root/Game") != null:
		await get_tree().create_timer(2.0).timeout
		if is_inside_tree():
			pause_menu.show_result("%s  %d - %d  %s" % [teams_data[0].short_name, rules.goals(0), rules.goals(1), teams_data[1].short_name])


# --- HUD ------------------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud_score = Label.new()
	_hud_score.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hud_score.position = Vector2(-400, 16)
	_hud_score.custom_minimum_size = Vector2(800, 0)
	_hud_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_score.add_theme_font_size_override("font_size", 26)
	_hud_score.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_score.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud_score)
	_hud_banner = Label.new()
	_hud_banner.set_anchors_preset(Control.PRESET_CENTER)
	_hud_banner.position = Vector2(-400, -140)
	_hud_banner.custom_minimum_size = Vector2(800, 0)
	_hud_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_banner.add_theme_font_size_override("font_size", 48)
	_hud_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_banner.add_theme_constant_override("outline_size", 8)
	layer.add_child(_hud_banner)
	_hud_prompt = Label.new()
	_hud_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hud_prompt.position = Vector2(-450, -90)
	_hud_prompt.custom_minimum_size = Vector2(900, 0)
	_hud_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_prompt.add_theme_font_size_override("font_size", 22)
	_hud_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_prompt.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud_prompt)


static func dots(list: Array) -> String:
	var s := ""
	for k in list:
		s += "● " if k else "✕ "
	return s.strip_edges()


func _update_hud() -> void:
	var round_text := tr("PEN_SUDDEN_DEATH") if rules.kicks_taken(0) >= ShootoutRules.ROUNDS and rules.kicks_taken(1) >= ShootoutRules.ROUNDS else tr("PEN_ROUND") % (maxi(rules.kicks_taken(0), rules.kicks_taken(1)) + (0 if rules.next_team() == 1 else 1))
	var lines := ["%s  %d - %d  %s" % [teams_data[0].short_name, rules.goals(0), rules.goals(1), teams_data[1].short_name]]
	if rules.kicks_taken(0) + rules.kicks_taken(1) > 0:
		lines.append("%s   |   %s" % [dots(rules.kicks[0]), dots(rules.kicks[1])])
	if state != State.FINISHED:
		lines.append(round_text)
	_hud_score.text = "\n".join(lines)
	var prompt := ""
	if state == State.WAIT_KICK and kicker.team_id == human_team:
		prompt = tr("PEN_YOUR_SHOT")
	elif state == State.WAIT_KICK and keeper.team_id == human_team:
		prompt = tr("PEN_YOUR_SAVE")
	_hud_prompt.text = prompt


func _show(text: String, color: Color) -> void:
	_hud_banner.text = text
	_hud_banner.modulate = color
	_banner_time = 2.0
