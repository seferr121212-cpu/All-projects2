class_name MusicGenerator
extends RefCounted
## Procedural calm music: a soft pad under a sparse plucked melody
## (Karplus-Strong, a bağlama/ud-like string), with a small reverb.
## Pure maths, so it can run on a worker thread.

const MIX_RATE: int = 22050

## style -> {scale (semitones from root), root Hz, progression (scale degrees)}
const STYLES: Dictionary = {
	"blacksea": {"root": 110.0, "scale": [0, 2, 3, 5, 7, 8, 10], "progression": [0, 5, 3, 4]},
	"aegean": {"root": 146.83, "scale": [0, 2, 4, 5, 7, 9, 10], "progression": [0, 3, 6, 4]},
}
## mood -> {seconds, note gap range, rest chance, brightness, bass pulse}
const MOODS: Dictionary = {
	"day": {"seconds": 28.0, "gap": [0.55, 1.2], "rest": 0.3, "octave": 2, "bass": false, "pad": 0.32},
	"night": {"seconds": 30.0, "gap": [0.9, 1.8], "rest": 0.45, "octave": 1, "bass": false, "pad": 0.38},
	"drive": {"seconds": 26.0, "gap": [0.4, 0.8], "rest": 0.2, "octave": 2, "bass": true, "pad": 0.25},
}


static func generate(style: String, mood: String, seed_value: int) -> AudioStreamWAV:
	var st: Dictionary = STYLES.get(style, STYLES["blacksea"])
	var md: Dictionary = MOODS.get(mood, MOODS["day"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n: int = int(float(md.seconds) * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var chord_len: int = n / (st.progression as Array).size()
	_add_pad(buf, st, md, chord_len)
	_add_melody(buf, st, md, rng, chord_len)
	if md.bass:
		_add_bass(buf, st, chord_len)
	_reverb(buf)
	_warm(buf)
	_fade_edges(buf, int(1.5 * MIX_RATE))
	return _to_stream(buf)


static func _freq(st: Dictionary, degree: int, octave: int) -> float:
	var scale: Array = st.scale
	var o: int = octave + floori(float(degree) / scale.size())
	var semis: int = int(scale[posmod(degree, scale.size())]) + 12 * o
	return float(st.root) * pow(2.0, semis / 12.0)


## Slow-breathing triads: soft sines with a gentle second harmonic.
static func _add_pad(buf: PackedFloat32Array, st: Dictionary, md: Dictionary, chord_len: int) -> void:
	var prog: Array = st.progression
	var amp: float = float(md.pad) * 0.22
	for ci: int in prog.size():
		var start: int = ci * chord_len
		for voice: int in 3:
			var f: float = _freq(st, int(prog[ci]) + voice * 2, 0)
			var inc: float = TAU * f / MIX_RATE
			var ph: float = 0.0
			var length: int = mini(chord_len + MIX_RATE, buf.size() - start)
			for i: int in length:
				var k: float = float(i) / length
				var env: float = smoothstep(0.0, 0.25, k) * (1.0 - smoothstep(0.75, 1.0, k))
				ph += inc
				buf[start + i] += (sin(ph) + 0.25 * sin(ph * 2.0)) * env * amp


## Sparse plucked notes walking the scale near the current chord.
static func _add_melody(buf: PackedFloat32Array, st: Dictionary, md: Dictionary, rng: RandomNumberGenerator, chord_len: int) -> void:
	var prog: Array = st.progression
	var t: int = int(1.0 * MIX_RATE)
	var degree: int = int(prog[0]) + 4
	var gap: Array = md.gap
	while t < buf.size() - MIX_RATE:
		var chord_root: int = int(prog[mini(t / chord_len, prog.size() - 1)])
		if rng.randf() > float(md.rest):
			# Small steps, drawn back towards chord tones.
			degree += rng.randi_range(-2, 2)
			degree = clampi(degree, chord_root, chord_root + 9)
			_pluck(buf, t, _freq(st, degree, int(md.octave)), rng.randf_range(0.35, 0.55), rng)
		t += int(rng.randf_range(float(gap[0]), float(gap[1])) * MIX_RATE)


## Karplus-Strong plucked string.
static func _pluck(buf: PackedFloat32Array, start: int, freq: float, amp: float, rng: RandomNumberGenerator) -> void:
	var period: int = maxi(int(MIX_RATE / freq), 2)
	var line := PackedFloat32Array()
	line.resize(period)
	# Pre-filtered excitation: a soft finger/plectrum, not a bright click.
	var lp: float = 0.0
	for i: int in period:
		lp += 0.3 * (rng.randf_range(-1.0, 1.0) - lp)
		line[i] = lp * 2.5
	var length: int = mini(int(2.2 * MIX_RATE), buf.size() - start)
	var idx: int = 0
	for i: int in length:
		var nxt: int = (idx + 1) % period
		var v: float = line[idx]
		line[idx] = (v + line[nxt]) * 0.4975
		buf[start + i] += v * amp
		idx = nxt


static func _add_bass(buf: PackedFloat32Array, st: Dictionary, chord_len: int) -> void:
	var prog: Array = st.progression
	var beat: int = int(0.5 * MIX_RATE)
	var t: int = 0
	while t < buf.size():
		var f: float = _freq(st, int(prog[mini(t / chord_len, prog.size() - 1)]), -1)
		var length: int = mini(beat, buf.size() - t)
		var inc: float = TAU * f / MIX_RATE
		for i: int in length:
			var k: float = float(i) / beat
			buf[t + i] += sin(inc * i) * exp(-k * 5.0) * 0.18
		t += beat


## Two feedback combs + an all-pass: just enough space to soften the pluck.
static func _reverb(buf: PackedFloat32Array) -> void:
	var dry := buf.duplicate()
	for spec: Array in [[1557, 0.6], [2053, 0.55]]:
		var d: int = spec[0]
		var g: float = spec[1]
		var line := PackedFloat32Array()
		line.resize(d)
		var idx: int = 0
		for i: int in buf.size():
			var y: float = line[idx]
			line[idx] = dry[i] + y * g
			buf[i] += y * 0.22
			idx = (idx + 1) % d


## Gentle master low-pass (two one-pole stages, ~2 kHz) for a warm tone.
static func _warm(buf: PackedFloat32Array) -> void:
	var a: float = 0.45
	var y1: float = 0.0
	var y2: float = 0.0
	for i: int in buf.size():
		y1 += a * (buf[i] - y1)
		y2 += a * (y1 - y2)
		buf[i] = y2


static func _fade_edges(buf: PackedFloat32Array, fade: int) -> void:
	for i: int in mini(fade, buf.size()):
		var k: float = float(i) / fade
		buf[i] *= k
		buf[buf.size() - 1 - i] *= k


static func _to_stream(data: PackedFloat32Array) -> AudioStreamWAV:
	var peak: float = 0.0001
	for s: float in data:
		peak = maxf(peak, absf(s))
	var gain: float = 0.8 / peak
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i: int in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i] * gain, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = bytes
	return stream
