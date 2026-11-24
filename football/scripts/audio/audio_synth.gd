class_name AudioSynth
extends RefCounted
## Kodla üretilen sesler (lisans/indirme gerekmez): top vuruşu, düdük, direk, file,
## seyirci uğultusu (döngü) ve gol coşkusu. Sonuçlar önbelleğe alınır.

const RATE := 22050

static var _cache := {}


static func to_stream(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func get_stream(name: String) -> AudioStreamWAV:
	if not _cache.has(name):
		match name:
			"kick": _cache[name] = to_stream(kick())
			"whistle_short": _cache[name] = to_stream(whistle(0.35))
			"whistle_long": _cache[name] = to_stream(whistle(1.1))
			"post": _cache[name] = to_stream(post())
			"net": _cache[name] = to_stream(net())
			"crowd": _cache[name] = to_stream(crowd_loop(4.0), true)
			"cheer": _cache[name] = to_stream(cheer(3.5))
	return _cache.get(name)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## Top vuruşu: frekansı düşen sinüs gövdesi + kısa gürültü "tık".
static func kick() -> PackedFloat32Array:
	var n := int(RATE * 0.25)
	var out := PackedFloat32Array()
	out.resize(n)
	var r := _rng(1)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 55.0 + 110.0 * exp(-t * 30.0)
		phase += TAU * f / RATE
		var body := sin(phase) * exp(-t * 16.0)
		var click := r.randf_range(-1.0, 1.0) * exp(-t * 260.0) * 0.6
		out[i] = (body + click) * 0.9
	return out


## Hakem düdüğü: ~2.9 kHz ton, bilye titreşimi (hızlı frekans ve genlik modülasyonu), hafif hava gürültüsü.
static func whistle(duration: float) -> PackedFloat32Array:
	var n := int(RATE * duration)
	var out := PackedFloat32Array()
	out.resize(n)
	var r := _rng(2)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var trill := sin(TAU * 32.0 * t)
		var f := 2900.0 + 140.0 * trill
		phase += TAU * f / RATE
		var env := minf(1.0, t / 0.02) * minf(1.0, (duration - t) / 0.06)
		var am := 0.75 + 0.25 * trill
		out[i] = (sin(phase) * am + r.randf_range(-1.0, 1.0) * 0.06) * env * 0.45
	return out


## Direk: uyumsuz kısmi tonların sönümlü toplamı (metalik "tıng").
static func post() -> PackedFloat32Array:
	var n := int(RATE * 0.7)
	var out := PackedFloat32Array()
	out.resize(n)
	var partials := [[523.0, 1.0, 5.0], [1347.0, 0.6, 7.0], [2213.0, 0.4, 9.0], [3109.0, 0.25, 12.0]]
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for p in partials:
			s += sin(TAU * p[0] * t) * p[1] * exp(-t * p[2])
		out[i] = s * 0.35 * minf(1.0, t / 0.002)
	return out


## File: yumuşak, alçak geçiren filtreden geçmiş gürültü patlaması.
static func net() -> PackedFloat32Array:
	var n := int(RATE * 0.45)
	var out := PackedFloat32Array()
	out.resize(n)
	var r := _rng(3)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (r.randf_range(-1.0, 1.0) - lp) * 0.15
		out[i] = lp * exp(-t * 7.0) * 1.6
	return out


## Seyirci uğultusu: süzülmüş (kahverengi/pembe) gürültü + yavaş dalgalanma; uçları dikişsiz döngü.
static func crowd_loop(seconds: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var raw := PackedFloat32Array()
	raw.resize(n)
	var r := _rng(4)
	var a := 0.0
	var b := 0.0
	var c := 0.0
	for i in n:
		var w := r.randf_range(-1.0, 1.0)
		a += (w - a) * 0.02
		b += (w - b) * 0.08
		c += (w - c) * 0.3
		var t := float(i) / RATE
		var swell := 0.8 + 0.12 * sin(TAU * 0.31 * t) + 0.08 * sin(TAU * 0.77 * t + 1.3)
		raw[i] = (a * 2.2 + b * 0.9 + c * 0.25) * swell
	# Dikişsiz döngü: son 0.5 sn'yi başa karıştır
	var xf := int(RATE * 0.5)
	var out := PackedFloat32Array()
	out.resize(n - xf)
	for i in n - xf:
		var v := raw[i]
		if i < xf:
			var k := float(i) / xf
			v = raw[i] * k + raw[n - xf + i] * (1.0 - k)
		out[i] = v * 0.8
	return out


## Gol coşkusu: açılan filtreyle yükselen, sonra sönen gürültü kabarması.
static func cheer(seconds: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var r := _rng(5)
	var lp := 0.0
	var hp_prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var cutoff := 0.05 + 0.25 * minf(1.0, t / 0.4)
		var w := r.randf_range(-1.0, 1.0)
		lp += (w - lp) * cutoff
		var hp := lp - hp_prev * 0.97
		hp_prev = lp
		var env := minf(1.0, t / 0.35) * exp(-maxf(0.0, t - 1.2) * 1.2)
		var voices := 1.0 + 0.15 * sin(TAU * (3.0 + sin(t)) * t)
		out[i] = hp * env * voices * 1.8
	return out
