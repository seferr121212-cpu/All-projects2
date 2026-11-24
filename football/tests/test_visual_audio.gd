extends "res://tests/test_case.gd"
## Faz 8: oyuncu modeli ve animasyonlar, stadyum/seyirci/gece, çim shader'ı, ses sentezi, spiker.

const PlayerScene = preload("res://scenes/player.tscn")
const PD = preload("res://scripts/match/pitch_dimensions.gd")


func test_player_model_parts_and_animations() -> void:
	var p: FootballPlayer = PlayerScene.instantiate()
	add_child(p)
	var v = p.visual
	var meshes := v.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() >= 20, "İnsan figürü en az 20 parça (%d)" % meshes.size())
	for a in ["idle", "jog", "sprint", "kick", "slide", "dive_l", "dive_r", "stumble"]:
		check(v.anim_player.has_animation(a), "Animasyon var: %s" % a)
	v.set_number(10)
	check(v._number_label.text == "10", "Sırt numarası")
	for i in 10:
		v.set_locomotion(9.0)
	check(float(v.anim_tree.get("parameters/loco/bs/blend_position")) > 0.8, "Sprintte koşu harmanı yüksek")
	for i in 3:
		await get_tree().process_frame
	check(v.current_animation() == &"loco", "Başlangıç: koşu/duruş durumu (%s)" % v.current_animation())
	v.play_kick()
	await get_tree().process_frame
	check(v.current_animation() == &"kick", "Vuruş animasyonu (%s)" % v.current_animation())
	v.set_pose(FootballPlayer.State.DIVE, 1.0)
	await get_tree().process_frame
	check(v.current_animation() == &"dive_r", "Sağa uzanma (%s)" % v.current_animation())
	v.set_pose(FootballPlayer.State.NORMAL)
	await get_tree().process_frame
	check(v.current_animation() == &"loco", "Normale dönüş")
	await clear_children()


func test_kick_triggers_animation_in_game() -> void:
	var g := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(100, 1, 100)
	cs.shape = b
	cs.position.y = -0.5
	g.add_child(cs)
	add_child(g)
	var ball: Ball = preload("res://scenes/ball.tscn").instantiate()
	add_child(ball)
	var pos := Possession.new()
	pos.ball = ball
	add_child(pos)
	var p: FootballPlayer = PlayerScene.instantiate()
	add_child(p)
	pos.register_player(p)
	ball.reset_to(Vector3(0.6, 0.11, 0))
	await step_physics(10)
	check(p.shoot_at(Vector3(PD.HALF_LENGTH, 0, 0), 0.7), "Şut çekilmeli")
	await get_tree().process_frame
	await get_tree().process_frame # animasyon ağacı bir kare sonra günceller
	check(p.visual.current_animation() == &"kick", "Şut çekince vuruş animasyonu oynamalı")
	await clear_children()


func test_stadium_day_and_night() -> void:
	var day = preload("res://scripts/match/stadium_builder.gd").new()
	add_child(day)
	check(day.crowd_count() > 3000, "Kalabalık seyirci (%d)" % day.crowd_count())
	check(day.floodlights.is_empty(), "Gündüz ışık kulesi yok")
	var night = preload("res://scripts/match/stadium_builder.gd").new()
	night.night = true
	add_child(night)
	check(night.floodlights.size() == 4, "Gece 4 ışık kulesi")
	night.set_excitement(0.8)
	check(is_equal_approx(float(night.crowd_material.get_shader_parameter("excitement")), 0.8), "Seyirci heyecanı shader'a iletilmeli")
	await clear_children()


func test_grass_uses_shader() -> void:
	var s = preload("res://scenes/stadium.tscn").instantiate()
	add_child(s)
	var grass: MeshInstance3D = s.get_node("Grass")
	var mat = (grass.mesh as PlaneMesh).material
	check(mat is ShaderMaterial and (mat as ShaderMaterial).shader.code.contains("stripe"), "Çim shader'ı (şeritli)")
	await clear_children()


func _peak(w: AudioStreamWAV) -> float:
	var m := 0.0
	for i in range(0, w.data.size(), 2):
		m = maxf(m, absf(w.data.decode_s16(i) / 32767.0))
	return m


func test_audio_synthesis() -> void:
	for name in ["kick", "whistle_short", "whistle_long", "post", "net", "crowd", "cheer"]:
		var w := AudioSynth.get_stream(name)
		check(w != null and w.data.size() > 1000, "Ses üretilmeli: %s" % name)
		var pk := _peak(w)
		check(pk > 0.1 and pk <= 1.0, "%s sessiz/kırpık olmamalı (tepe %.2f)" % [name, pk])
	check(AudioSynth.get_stream("crowd").loop_mode == AudioStreamWAV.LOOP_FORWARD, "Seyirci sesi döngülü")
	check(is_equal_approx(AudioSynth.get_stream("whistle_long").get_length(), 1.1), "Uzun düdük 1.1 sn")
	check(AudioSynth.get_stream("kick") == AudioSynth.get_stream("kick"), "Önbellek")


func test_crowd_excitement_near_goal() -> void:
	var center := MatchAudio.target_excitement(Vector3.ZERO, 0.0)
	var box := MatchAudio.target_excitement(Vector3(PD.HALF_LENGTH - 8.0, 0, 0), 0.0)
	var goal := MatchAudio.target_excitement(Vector3.ZERO, 1.0)
	check(box > center + 0.3, "Ceza sahasında heyecan artmalı (%.2f > %.2f)" % [box, center])
	check(goal >= 0.99, "Golde heyecan tavan")


func test_commentator_queue() -> void:
	var c := Commentator.new()
	add_child(c)
	check(c.lines.has("goal") and c.lines.has("foul"), "Spiker verisi yüklenmeli")
	var heard: Array[String] = []
	c.line.connect(func(ev: String, _t: String) -> void: heard.append(ev))
	c.say("foul")
	c.say("shot")
	c.say("goal")
	check(c.queue_events()[0] == "goal", "Gol en yüksek öncelik")
	check(not c.say("goal"), "Aynı olay bekleme süresinde reddedilir")
	c.advance(0.1)
	check(heard == ["goal"], "İlk okunan gol (%s)" % str(heard))
	c.advance(2.0)
	c.advance(2.0)
	check(heard.size() == 3, "Kuyruk sırayla okunur (%s)" % str(heard))
	await clear_children()


func test_match_audio_whistles_on_stop() -> void:
	var m = preload("res://scenes/match.tscn").instantiate()
	m.human_team = -1
	m.replay_enabled = false
	add_child(m)
	for i in 600:
		if m.flow.state == MatchFlow.MatchState.PLAYING:
			break
		await get_tree().physics_frame
	check(m.audio != null and m.audio._crowd.playing, "Seyirci sesi çalmalı")
	m.flow._on_out_event({"type": MatchEvents.EventType.THROW_IN, "team": 1, "position": Vector3(5, 0.11, 35), "side": 1})
	await step_physics(2)
	check(m.audio._whistle.playing, "Ölü topta düdük çalmalı")
	await clear_children()
