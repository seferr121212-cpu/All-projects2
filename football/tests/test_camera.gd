extends "res://tests/test_case.gd"
## Kamera sınırları ve tekrar kaydı testleri.

const PD = preload("res://scripts/match/pitch_dimensions.gd")


func test_focus_clamped_to_pitch() -> void:
	var f := BroadcastCamera.compute_focus(Vector3(80, 0, 60), Vector3.ZERO)
	check(f.x <= PD.HALF_LENGTH and f.z <= PD.HALF_WIDTH, "Odak saha içinde kalmalı (%s)" % f)


func test_position_stays_on_stand_line() -> void:
	var cam := BroadcastCamera.new()
	add_child(cam)
	var pos := cam.compute_position(Vector3(PD.HALF_LENGTH, 0, 0))
	check(pos.x <= PD.HALF_LENGTH - 15.0 + 0.001, "Kamera kale arkasına taşmamalı (x=%.1f)" % pos.x)
	check(pos.z > PD.HALF_WIDTH, "Kamera tribün tarafında olmalı")
	cam.free()


func test_camera_follows_ball() -> void:
	var cam := BroadcastCamera.new()
	var target := Node3D.new()
	add_child(target)
	cam.target = target
	add_child(cam)
	target.global_position = Vector3(30, 0, 0)
	for i in 240:
		cam._process(1.0 / 60.0)
	check(cam.global_position.x > 20.0, "Kamera topu x'te izlemeli (x=%.1f)" % cam.global_position.x)
	var fwd := -cam.global_basis.z
	check(fwd.y < -0.2, "Kamera aşağı bakmalı")
	await clear_children()


func test_recorder_ring_buffer() -> void:
	var rec := ReplayRecorder.new()
	rec.record_hz = 10.0
	rec.duration = 2.0
	add_child(rec)
	rec.recording = false
	var n := Node3D.new()
	add_child(n)
	rec.track(n)
	for i in 50: # 5 sn, 10 Hz
		n.global_position = Vector3(i * 0.1, 0, 0)
		rec.advance(0.1)
	check(rec.frame_count() == rec.capacity(), "Tampon kapasitede kalmalı (%d)" % rec.frame_count())
	check(rec.end_time() - rec.start_time() < 2.0, "Yalnızca son 2 sn tutulmalı")


func test_recorder_interpolates() -> void:
	var rec := ReplayRecorder.new()
	rec.recording = false
	add_child(rec)
	var n := Node3D.new()
	add_child(n)
	rec.track(n)
	n.global_position = Vector3.ZERO
	rec.advance(1.0 / 30.0)
	n.global_position = Vector3(10, 0, 0)
	rec.advance(1.0 / 30.0)
	var mid := (rec.start_time() + rec.end_time()) * 0.5
	var t: Array[Transform3D] = rec.sample(mid)
	check(t.size() == 1, "Bir düğüm örneklenmeli")
	check_near(t[0].origin.x, 5.0, 0.01, "Ara değer")
	await clear_children()
