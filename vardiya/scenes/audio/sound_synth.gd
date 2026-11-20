extends RefCounted
## Procedural placeholder audio (own work, no files): UI cues, ambience loops
## and slow mood pads, rendered into 16-bit mono AudioStreamWAV. Short cues
## are rendered on demand; loops are rendered on a worker thread by AudioBus.
## Every recipe is deterministic (fixed seeds) so a build always sounds the same.

const CUE_RATE := 22050
const AMB_RATE := 22050
const MUSIC_RATE := 11025
const AMB_SEC := 6.0
const MUSIC_SEC := 16.0
const LOOP_FADE_SEC := 0.5

const CUES := ["ui/move", "ui/select", "ui/back", "ui/choice_open", "ui/tick", "ui/decision", "ui/silence",
	"ui/qte_hit", "ui/qte_fail", "ui/journal"]
const AMBIENCES := ["factory", "factory_night", "harbor", "room", "fluorescent", "crowd", "fire", "outdoor"]
const MUSIC := ["calm", "tense", "sad", "warm", "night"]

## Chord voicings (Hz) per mood; each chord lasts MUSIC_SEC / chords.size().
const CHORDS := {
	"calm": [[110.0, 164.81, 246.94, 261.63], [87.31, 130.81, 220.0, 261.63]],
	"tense": [[73.42, 110.0, 155.56], [73.42, 103.83, 155.56], [69.3, 110.0, 146.83], [73.42, 116.54, 155.56]],
	"sad": [[87.31, 174.61, 220.0, 329.63], [82.41, 164.81, 196.0, 293.66]],
	"warm": [[130.81, 196.0, 261.63, 329.63], [123.47, 196.0, 246.94, 293.66], [110.0, 164.81, 261.63, 329.63],
		[87.31, 174.61, 220.0, 261.63]],
	"night": [[98.0, 146.83, 233.08], [92.5, 138.59, 220.0]],
}
## Sparse melody notes per mood: [time_sec, Hz].
const NOTES := {
	"calm": [[2.0, 493.88], [6.5, 440.0], [10.0, 523.25], [13.5, 392.0]],
	"tense": [[3.0, 311.13], [11.0, 293.66]],
	"sad": [[1.5, 440.0], [4.0, 392.0], [9.5, 349.23], [12.0, 329.63]],
	"warm": [[1.0, 523.25], [5.0, 587.33], [9.0, 659.25], [13.0, 523.25]],
	"night": [[4.0, 466.16], [12.5, 440.0]],
}


static func to_wav(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## Crossfades the extra tail (`fade` samples beyond `length`) into the head so the loop has no seam.
static func _seal_loop(s: PackedFloat32Array, length: int, fade: int) -> PackedFloat32Array:
	for i in fade:
		var k := float(i) / fade
		s[i] = s[i] * k + s[length + i] * (1.0 - k)
	s.resize(length)
	return s


static func _normalize(s: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in s:
		m = maxf(m, absf(v))
	var g := peak / m
	for i in s.size():
		s[i] *= g
	return s


# --- UI cues -------------------------------------------------------------------

static func cue(cue_name: String) -> AudioStreamWAV:
	var rate := CUE_RATE
	var rng := RandomNumberGenerator.new()
	rng.seed = cue_name.hash()
	var dur := 0.12
	var partials: Array = []  # [freq_start, freq_end, amp, decay]
	var noise := 0.0
	var attack := 0.004
	match cue_name:
		"ui/move":
			dur = 0.05
			partials = [[880.0, 900.0, 0.5, 60.0]]
		"ui/select":
			dur = 0.14
			partials = [[660.0, 660.0, 0.45, 25.0], [990.0, 990.0, 0.3, 30.0]]
		"ui/back":
			dur = 0.12
			partials = [[520.0, 390.0, 0.5, 25.0]]
		"ui/choice_open":
			dur = 0.45
			attack = 0.12
			partials = [[220.0, 220.0, 0.4, 5.0], [330.0, 330.0, 0.25, 6.0], [440.0, 442.0, 0.1, 8.0]]
		"ui/tick":
			dur = 0.04
			partials = [[1250.0, 1150.0, 0.5, 120.0]]
		"ui/decision":
			dur = 0.9
			partials = [[440.0, 440.0, 0.35, 4.0], [660.0, 660.0, 0.2, 5.0], [1320.0, 1320.0, 0.08, 9.0]]
		"ui/silence":
			dur = 1.0
			attack = 0.2
			partials = [[110.0, 98.0, 0.35, 2.5]]
			noise = 0.05
		"ui/qte_hit":
			dur = 0.1
			partials = [[1000.0, 1000.0, 0.4, 40.0], [2000.0, 2000.0, 0.15, 50.0]]
		"ui/qte_fail":
			dur = 0.45
			partials = [[150.0, 90.0, 0.5, 6.0], [225.0, 135.0, 0.2, 7.0]]
			noise = 0.08
		"ui/journal":
			dur = 0.28
			noise = 0.35
		_:
			return null
	var n := int(dur * rate)
	var s := PackedFloat32Array()
	s.resize(n)
	var phases := []
	phases.resize(partials.size())
	phases.fill(0.0)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var env := minf(1.0, t / attack) * minf(1.0, (dur - t) / 0.01)
		var v := 0.0
		for p in partials.size():
			var pr: Array = partials[p]
			var f := lerpf(float(pr[0]), float(pr[1]), t / dur)
			phases[p] = float(phases[p]) + TAU * f / rate
			v += sin(float(phases[p])) * float(pr[2]) * exp(-t * float(pr[3]))
		if noise > 0.0:
			lp += 0.25 * (rng.randf_range(-1.0, 1.0) - lp)
			var shape := sin(PI * t / dur) if cue_name == "ui/journal" else exp(-t * 3.0)
			v += lp * noise * shape * (1.0 + 0.6 * sin(t * 90.0))
		s[i] = v * env
	return to_wav(s, rate, false)


# --- Ambience loops --------------------------------------------------------------

static func ambience(id: String) -> AudioStreamWAV:
	var rate := AMB_RATE
	var length := int(AMB_SEC * rate)
	var fade := int(LOOP_FADE_SEC * rate)
	var n := length + fade
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = id.hash()
	var brown := 0.0
	var lp := 0.0
	var lp2 := 0.0
	var event_env := 0.0
	var next_event := rng.randf_range(0.2, 0.8)
	for i in n:
		var t := float(i) / rate
		var w := rng.randf_range(-1.0, 1.0)
		brown = (brown + 0.02 * w) / 1.02
		lp += 0.08 * (w - lp)
		var v := 0.0
		match id:
			"factory", "factory_night":
				var night := id == "factory_night"
				v = sin(TAU * 50.0 * t) * 0.12 + sin(TAU * 100.0 * t) * 0.05 + brown * (2.0 if night else 3.0)
				# Machine cycle: soft thump every 1.5 s (day only), distant creaks at night.
				var cyc := fmod(t, 1.5)
				if not night:
					v += sin(TAU * 55.0 * t) * exp(-cyc * 12.0) * 0.35
				else:
					v += sin(TAU * (310.0 + 20.0 * sin(t * 3.0)) * t) * exp(-fmod(t + 2.0, 3.0) * 4.0) * 0.03
			"harbor":
				var gust := 0.55 + 0.45 * sin(TAU * t / AMB_SEC) * sin(TAU * 2.0 * t / AMB_SEC + 1.0)
				lp2 += 0.02 * (w - lp2)
				v = brown * 3.0 * gust + lp2 * 0.6
				if t >= next_event:
					event_env = 1.0
					next_event = t + rng.randf_range(0.6, 1.6)
				event_env *= 0.9993
				v += lp * event_env * 0.35  # water lapping against the quay
			"room":
				v = brown * 1.2
				var tick := fmod(t, 1.0)
				v += sin(TAU * 2400.0 * t) * exp(-tick * 400.0) * 0.12
			"fluorescent":
				v = brown * 1.0 + sin(TAU * 120.0 * t) * 0.05 + sin(TAU * 240.0 * t) * 0.025 + sin(TAU * 360.0 * t) * 0.012
			"crowd":
				lp2 += 0.05 * (w - lp2)
				var murmur := 0.0
				for k in 4:
					murmur += maxf(0.0, sin(TAU * (2.3 + k * 0.9) * t + k * 1.7)) * (0.6 + 0.4 * sin(t * (0.7 + k * 0.3)))
				v = lp2 * murmur * 0.9 + brown * 1.5
			"fire":
				v = brown * 4.0 + lp * 0.2
				if t >= next_event:
					event_env = rng.randf_range(0.4, 1.0)
					next_event = t + rng.randf_range(0.03, 0.35)
				event_env *= 0.985
				v += w * event_env * 0.5
			_:  # outdoor: light wind + distant traffic rumble
				var gust := 0.6 + 0.4 * sin(TAU * t / AMB_SEC + 0.5)
				v = brown * 2.5 * gust + sin(TAU * 41.0 * t) * 0.04
		s[i] = v
	s = _seal_loop(s, length, fade)
	return to_wav(_normalize(s, 0.5), rate, true)


# --- Music pads -------------------------------------------------------------------

static func music(id: String) -> AudioStreamWAV:
	var rate := MUSIC_RATE
	var n := int(MUSIC_SEC * rate)
	var s := PackedFloat32Array()
	s.resize(n)
	var chords: Array = CHORDS.get(id, CHORDS["calm"])
	var seg := MUSIC_SEC / chords.size()
	# Each chord sounds for 2 segments under a Hann window, overlapping its
	# neighbours by half: the windows sum to 1, and the loop wraps seamlessly.
	var win_len := int(2.0 * seg * rate)
	for c in chords.size():
		var first := int((c - 0.5) * seg * rate)
		var chord: Array = chords[c]
		for f: float in chord:
			var w1 := TAU * f / rate
			var w2 := w1 * 1.003
			for k in win_len:
				var j := first + k  # unwrapped: the phase stays continuous across the loop point
				var win := 0.5 - 0.5 * cos(TAU * k / win_len)
				s[posmod(j, n)] += (sin(w1 * j) + 0.5 * sin(w2 * j + 1.0)) * win * 0.12
	for note: Array in NOTES.get(id, []):
		var t0 := float(note[0])
		var f := float(note[1])
		for k in int(3.0 * rate):
			var t := float(k) / rate
			var pluck := (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * exp(-t * 1.6) * minf(1.0, t / 0.01)
			s[posmod(int(t0 * rate) + k, n)] += pluck * 0.14
	# Slow tremolo for movement; period divides the loop length.
	for i in n:
		s[i] *= 0.85 + 0.15 * sin(TAU * float(i) / rate / 4.0)
	return to_wav(_normalize(s, 0.45), rate, true)
