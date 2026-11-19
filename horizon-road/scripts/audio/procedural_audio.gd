class_name ProceduralAudio
extends RefCounted
## Synthesised placeholder sounds (wind, rain, birds, crickets, thunder, engine).
## Used because no CC0 packs are available yet; each stream can later be
## swapped for a recorded file without touching the systems that play it.

const MIX_RATE: int = 22050


static func wind(seconds: float = 8.0, seed_value: int = 1) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var n: int = int(seconds * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown: float = 0.0
	var lp: float = 0.0
	for i: int in n:
		brown = (brown + rng.randf_range(-1.0, 1.0) * 0.02) / 1.02
		# Slow gust envelope, integer cycles so the loop stays seamless.
		var phase: float = float(i) / n * TAU
		var gust: float = 0.55 + 0.3 * sin(phase * 2.0) + 0.15 * sin(phase * 5.0 + 1.3)
		var cutoff: float = 0.02 + 0.05 * gust
		lp += cutoff * (brown * 9.0 - lp)
		out[i] = lp * gust
	return _to_stream(_loop_crossfade(out, 2048), true)


static func rain(seconds: float = 6.0, seed_value: int = 2) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var n: int = int(seconds * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var hp_prev_in: float = 0.0
	var hp: float = 0.0
	var lp: float = 0.0
	var drop_env: float = 0.0
	for i: int in n:
		var white: float = rng.randf_range(-1.0, 1.0)
		# High-passed hiss = distant rain on leaves.
		hp = 0.92 * (hp + white - hp_prev_in)
		hp_prev_in = white
		lp += 0.35 * (hp - lp)
		if rng.randf() < 0.0035:
			drop_env = rng.randf_range(0.3, 1.0)
		drop_env *= 0.985
		out[i] = lp * 0.32 + white * drop_env * 0.25
	return _to_stream(_loop_crossfade(out, 2048), true)


static func crickets(seconds: float = 4.0, seed_value: int = 3) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var n: int = int(seconds * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var voices: Array[Dictionary] = []
	for v: int in 3:
		voices.append({
			"freq": rng.randf_range(4200.0, 5200.0),
			"rate": float(rng.randi_range(2, 4)),  # chirp groups per second
			"offset": rng.randf(),
			"gain": rng.randf_range(0.12, 0.25),
		})
	for i: int in n:
		var t: float = float(i) / MIX_RATE
		var s: float = 0.0
		for voice: Dictionary in voices:
			var group: float = fposmod(t * voice.rate + voice.offset, 1.0)
			# Each chirp group: 3 fast pulses, then silence.
			var pulse: float = 0.0
			if group < 0.3:
				pulse = maxf(0.0, sin(group / 0.3 * 3.0 * PI))
			s += sin(TAU * voice.freq * t) * pulse * voice.gain
		out[i] = s
	return _to_stream(_loop_crossfade(out, 512), true)


static func bird_chirp(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var notes: int = rng.randi_range(2, 6)
	var samples := PackedFloat32Array()
	var base: float = rng.randf_range(2200.0, 3600.0)
	for note: int in notes:
		var dur: float = rng.randf_range(0.05, 0.16)
		var n: int = int(dur * MIX_RATE)
		var f0: float = base * rng.randf_range(0.8, 1.25)
		var f1: float = f0 * rng.randf_range(0.7, 1.5)
		var phase: float = 0.0
		for i: int in n:
			var k: float = float(i) / n
			var f: float = lerpf(f0, f1, k) + sin(k * TAU * 3.0) * 120.0
			phase += TAU * f / MIX_RATE
			var env: float = sin(k * PI)
			samples.append((sin(phase) + 0.25 * sin(phase * 2.0)) * env * 0.5)
		var gap: int = int(rng.randf_range(0.03, 0.12) * MIX_RATE)
		for i: int in gap:
			samples.append(0.0)
	return _to_stream(samples, false)


static func thunder(seed_value: int = 4) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var n: int = int(5.0 * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown: float = 0.0
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / n
		brown = (brown + rng.randf_range(-1.0, 1.0) * 0.05) / 1.01
		lp += 0.04 * (brown - lp)
		var env: float = minf(t * 40.0, 1.0) * pow(1.0 - t, 2.2)
		# Rolling rumble: a few slow amplitude bumps.
		env *= 0.6 + 0.4 * sin(t * 23.0 + sin(t * 7.0) * 2.0)
		out[i] = lp * env * 6.0
	return _to_stream(out, false)


## One-second loop of a low four-cylinder idle; pitch_scale raises the revs.
static func engine() -> AudioStreamWAV:
	var rng := _rng(5)
	var n: int = MIX_RATE
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var fundamental: float = 32.0  # integer Hz keeps the 1 s loop seamless
	for i: int in n:
		var t: float = float(i) / MIX_RATE
		var p: float = fposmod(t * fundamental, 1.0)
		var firing: float = exp(-p * 9.0)  # sharp combustion pulse
		var body: float = sin(TAU * fundamental * 2.0 * t) * 0.35 + sin(TAU * fundamental * 3.0 * t) * 0.15
		var raw: float = firing * 0.9 + body + rng.randf_range(-0.12, 0.12)
		lp += 0.18 * (raw - lp)
		out[i] = lp * 0.55
	return _to_stream(out, true)


## Mechanical shutter: two short clicks (curtain open/close).
static func shutter() -> AudioStreamWAV:
	var rng := _rng(6)
	var out := PackedFloat32Array()
	for click: int in 2:
		var n: int = int(0.018 * MIX_RATE)
		for i: int in n:
			var env: float = exp(-float(i) / n * 6.0)
			out.append((rng.randf_range(-1.0, 1.0) * 0.6 + sin(i * 0.9) * 0.4) * env)
		for i: int in int(0.055 * MIX_RATE):
			out.append(0.0)
	return _to_stream(out, false)


## Net splash: short burst of filtered noise with a slosh.
static func splash() -> AudioStreamWAV:
	var rng := _rng(10)
	var n: int = int(0.5 * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var k: float = float(i) / n
		lp += (0.35 - k * 0.25) * (rng.randf_range(-1.0, 1.0) - lp)
		out[i] = lp * pow(1.0 - k, 2.0) * (0.6 + 0.4 * sin(k * 40.0))
	return _to_stream(out, false)


## Kettle coming to the boil: rising hiss with a soft whistle at the end.
static func kettle() -> AudioStreamWAV:
	var rng := _rng(9)
	var n: int = int(2.2 * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var phase: float = 0.0
	for i: int in n:
		var k: float = float(i) / n
		lp += 0.2 * (rng.randf_range(-1.0, 1.0) - lp)
		phase += TAU * (1800.0 + 300.0 * k) / MIX_RATE
		var whistle: float = sin(phase) * smoothstep(0.6, 0.85, k) * 0.35
		out[i] = (lp * (0.2 + k * 0.6) + whistle) * (1.0 - smoothstep(0.92, 1.0, k))
	return _to_stream(out, false)


## Leaves being snapped off a bush: soft filtered crackle.
static func rustle() -> AudioStreamWAV:
	var rng := _rng(8)
	var n: int = int(0.35 * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var hp: float = 0.0
	var prev: float = 0.0
	for i: int in n:
		var k: float = float(i) / n
		var white: float = rng.randf_range(-1.0, 1.0)
		hp = 0.85 * (hp + white - prev)
		prev = white
		var crackle: float = 1.0 if rng.randf() < 0.02 else 0.3
		out[i] = hp * crackle * sin(k * PI) * (1.0 - k * 0.5)
	return _to_stream(out, false)


## Short soft voice blip for dialogue typing; pitch varies per speaker and call.
static func blip(seed_value: int = 1) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var n: int = int(0.07 * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var f: float = rng.randf_range(210.0, 300.0)
	var phase: float = 0.0
	var lp: float = 0.0
	for i: int in n:
		var k: float = float(i) / n
		phase += f * (1.0 + 0.2 * (0.5 - k)) / MIX_RATE
		var saw: float = fposmod(phase, 1.0) * 2.0 - 1.0
		lp += 0.28 * (saw - lp)
		out[i] = lp * sin(k * PI) * 0.8
	return _to_stream(out, false)


## One footstep on soft ground (grass / sand): a low thump plus a short rustle.
static func footstep(seed_value: int = 1) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var n: int = int(0.16 * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var k: float = float(i) / n
		var white: float = rng.randf_range(-1.0, 1.0)
		lp += 0.18 * (white - lp)
		var thump: float = sin(k * 0.04 * MIX_RATE * (1.0 - 0.6 * k)) * exp(-k * 9.0)
		out[i] = (lp * 1.4 + thump) * exp(-k * 7.0)
	return _to_stream(out, false)


## Distant cow moo: a low voice with a formant-like sweep.
static func moo(seed_value: int = 7) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var n: int = int(1.4 * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var lp: float = 0.0
	var f0: float = rng.randf_range(95.0, 125.0)
	for i: int in n:
		var k: float = float(i) / n
		var f: float = f0 * (1.0 + 0.25 * sin(k * PI)) * (1.0 - 0.15 * k)
		phase += f / MIX_RATE
		var saw: float = fposmod(phase, 1.0) * 2.0 - 1.0
		var cutoff: float = 0.05 + 0.12 * sin(k * PI)
		lp += cutoff * (saw - lp)
		out[i] = lp * minf(k * 8.0, 1.0) * pow(1.0 - k, 0.6)
	return _to_stream(out, false)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Blends the tail into the head so a noise loop has no click.
static func _loop_crossfade(data: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n: int = data.size() - fade
	var out := data.slice(0, n)
	for i: int in fade:
		var k: float = float(i) / fade
		out[i] = data[i] * k + data[n + i] * (1.0 - k)
	return out


static func _to_stream(data: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var peak: float = 0.0001
	for s: float in data:
		peak = maxf(peak, absf(s))
	var gain: float = 0.9 / peak
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i: int in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i] * gain, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = data.size()
	return stream
