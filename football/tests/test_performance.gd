extends "res://tests/test_case.gd"
## Performans: 22 oyuncu + top, AI'ya karşı AI. Fizik+AI kare süresi ölçülür.
## Not: headless modda çizim (render) süresi ölçülmez; yalnızca simülasyon maliyeti.

const BUDGET_AVG_MS := 4.0 # 60 FPS = 16.6 ms; 120 Hz fizikte görüntü karesi başına 2 adım -> 8 ms, render'a pay kalır
const BUDGET_P99_MS := 10.0


func test_eleven_a_side_frame_time() -> void:
	var m = preload("res://scenes/match.tscn").instantiate()
	m.human_team = -1
	m.replay_enabled = false
	add_child(m)
	await step_physics(120 * 3) # ısınma + başlama vuruşu
	# --fixed-fps ile headless'ta kareler bekleme olmadan art arda çalışır:
	# iki fizik karesi arasındaki duvar saati süresi = o karenin tüm CPU maliyeti (render hariç)
	var samples: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in 120 * 20: # 20 sn oyun
		await get_tree().physics_frame
		var now := Time.get_ticks_usec()
		samples.append((now - last) / 1000.0)
		last = now
	samples.sort()
	var avg := 0.0
	for s in samples:
		avg += s
	avg /= samples.size()
	var p99 := samples[int(samples.size() * 0.99)]
	print("       11v11 fizik+AI kare süresi: ort %.2f ms, p99 %.2f ms, maks %.2f ms (120 Hz fizik, 60 FPS'de kare başına 2 fizik adımı)" % [avg, p99, samples[-1]])
	check(avg < BUDGET_AVG_MS, "Ortalama kare süresi bütçede (%.2f ms)" % avg)
	check(p99 < BUDGET_P99_MS, "p99 kare süresi bütçede (%.2f ms)" % p99)
	await clear_children()
