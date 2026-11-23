class_name ReplayRecorder
extends Node
## Tekrar kaydı: izlenen düğümlerin (top, oyuncular) dönüşümlerini sabit hızda
## halka tamponda (ring buffer) tutar. sample(t) ile ara değerli kare döndürür.

@export var record_hz := 30.0
@export var duration := 10.0

var tracked: Array[Node3D] = []
var recording := true

var _times: Array[float] = []
var _frames: Array = [] # her eleman: Array[Transform3D]
var _time := 0.0
var _accum := 0.0


func track(node: Node3D) -> void:
	tracked.append(node)
	clear() # kare yapısı değişti


func clear() -> void:
	_times.clear()
	_frames.clear()


func capacity() -> int:
	return int(ceil(record_hz * duration))


func frame_count() -> int:
	return _frames.size()


func start_time() -> float:
	return _times[0] if not _times.is_empty() else 0.0


func end_time() -> float:
	return _times[-1] if not _times.is_empty() else 0.0


func _physics_process(delta: float) -> void:
	if recording:
		advance(delta)


## Zamanı ilerletir, gerekiyorsa kare kaydeder (testlerde elle çağrılabilir).
func advance(delta: float) -> void:
	_time += delta
	_accum += delta
	var step := 1.0 / record_hz
	if _accum >= step:
		_accum = fmod(_accum, step)
		record_frame()


func record_frame() -> void:
	var f: Array[Transform3D] = []
	for n in tracked:
		f.append(n.global_transform if is_instance_valid(n) else Transform3D.IDENTITY)
	_times.append(_time)
	_frames.append(f)
	while _frames.size() > capacity():
		_frames.pop_front()
		_times.pop_front()


## t anındaki dönüşümler (iki kare arası ara değer). t aralık dışındaysa uca kırpılır.
func sample(t: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	if _frames.is_empty():
		return out
	t = clampf(t, start_time(), end_time())
	var i := _times.bsearch(t)
	if i <= 0:
		out.assign(_frames[0])
		return out
	if i >= _times.size():
		out.assign(_frames[-1])
		return out
	var t0: float = _times[i - 1]
	var t1: float = _times[i]
	var w := 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
	var a: Array = _frames[i - 1]
	var b: Array = _frames[i]
	for k in a.size():
		out.append((a[k] as Transform3D).interpolate_with(b[k], w))
	return out
