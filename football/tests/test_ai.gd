extends "res://tests/test_case.gd"
## AI testleri: kaleci konumu, formasyon kayması, karar verme, AI maçı.

const PD = preload("res://scripts/match/pitch_dimensions.gd")
const AIMatchScene = preload("res://scenes/match.tscn")


func _v(list: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.assign(list)
	return out


func test_goalkeeper_positions_between_ball_and_goal() -> void:
	var p := GoalkeeperAI.position_for(Vector3(38, 0, 10), 1.0) # +X kalesini savunan
	check(p.x < PD.HALF_LENGTH - 0.7 and p.x > PD.HALF_LENGTH - 4.5, "Kaleci kale önünde (x=%.2f)" % p.x)
	check(p.z > 0.0 and p.z < PD.GOAL_WIDTH * 0.5, "Kaleci topun tarafına kaymalı (z=%.2f)" % p.z)
	var far := GoalkeeperAI.position_for(Vector3(-30, 0, 0), 1.0)
	check(PD.HALF_LENGTH - far.x >= 3.9, "Top uzaktayken öne çıkmalı")


func test_formation_shifts_with_ball() -> void:
	var slot := Vector2(-0.55, 0.35)
	var back := Formation.target_for(slot, Vector3(-30, 0, 0), 1.0, Formation.Phase.TRANSITION)
	var fwd := Formation.target_for(slot, Vector3(30, 0, 0), 1.0, Formation.Phase.TRANSITION)
	check(fwd.x > back.x + 10.0, "Top ilerleyince savunma öne kaymalı")
	var att := Formation.target_for(slot, Vector3.ZERO, 1.0, Formation.Phase.ATTACK)
	var def := Formation.target_for(slot, Vector3.ZERO, 1.0, Formation.Phase.DEFENSE)
	check(att.x > def.x and absf(att.z) > absf(def.z), "Hücumda öne ve geniş, savunmada geri ve dar")
	var away := Formation.target_for(slot, Vector3.ZERO, -1.0, Formation.Phase.TRANSITION)
	check(away.x > 0.0, "Deplasman aynalanmalı")


func test_formation_loads_from_json() -> void:
	var f := Formation.load_formation("5v5_2-1-1")
	check(f.slots.size() == 5 and f.roles[0] == "GK", "5'li diziliş yüklenmeli")


func test_shoots_when_open_near_goal() -> void:
	var rng := RandomNumberGenerator.new()
	var c := PlayerAI.choose_action(Vector3(42, 0, 0), 1.0, _v([Vector3(20, 0, 10)]), _v([Vector3(51, 0, 0)]), 0.0, rng)
	check(c.type == PlayerAI.Action.SHOOT, "Boş ceza sahasında şut seçilmeli (%d)" % c.type)


func test_passes_when_pressed_and_mate_open() -> void:
	var rng := RandomNumberGenerator.new()
	var opps := _v([Vector3(1.2, 0, 0), Vector3(3, 0, 1), Vector3(52, 0, 0)])
	var c := PlayerAI.choose_action(Vector3.ZERO, 1.0, _v([Vector3(10, 0, 12)]), opps, 0.0, rng)
	check(c.type == PlayerAI.Action.PASS, "Baskı altında açık arkadaşa pas (%d)" % c.type)


func test_difficulty_levels_load() -> void:
	var easy := AIDifficulty.load_level("easy")
	var hard := AIDifficulty.load_level("hard")
	check(easy.reaction_time > hard.reaction_time, "Kolay daha yavaş tepki vermeli")
	check(easy.decision_noise > hard.decision_noise, "Kolay daha gürültülü karar vermeli")


func test_ai_vs_ai_match_runs() -> void:
	var m = AIMatchScene.instantiate()
	m.human_team = -1
	m.replay_enabled = false
	m.half_minutes_override = 10.0
	add_child(m)
	var start := Time.get_ticks_msec()
	var touches := [0]
	m.ball.kicked.connect(func(_t: int, _d: bool) -> void: touches[0] += 1)
	await step_physics(120 * 60) # 60 sn oyun
	var elapsed := (Time.get_ticks_msec() - start) / 1000.0
	print("       60 sn AI maçı: skor %d-%d, şut %d, dokunuş %d, gerçek süre %.1f sn" % [m.score[0], m.score[1], m.shots, touches[0], elapsed])
	check(touches[0] > 50, "Top oynanmalı")
	check(m.shots >= 1, "En az bir şut çekilmeli")
	await clear_children()
