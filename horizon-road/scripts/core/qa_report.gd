class_name QaReport
extends Node
## Collects frame-time statistics while playing and writes a small plain-text
## report (user://qa_report.txt) the player can send back: hardware, renderer,
## FPS percentiles, spikes, draw calls and where in the world they were measured.
## Written on demand (F3 panel button) and when the game quits.

const PATH: String = "user://qa_report.txt"
const MAX_SAMPLES: int = 36000  # ~10 minutes at 60 fps

var _frames := PackedFloat32Array()
var _spikes: int = 0
var _worst_ms: float = 0.0
var _draw_calls_max: int = 0
var _objects_max: int = 0
var _regions: Dictionary = {}
var _notes: Array[String] = []


func _process(delta: float) -> void:
	if delta <= 0.0 or not GameState.journey_started:
		return
	var ms: float = delta * 1000.0
	if _frames.size() < MAX_SAMPLES:
		_frames.append(ms)
	if ms > 50.0:
		_spikes += 1
	_worst_ms = maxf(_worst_ms, ms)
	_draw_calls_max = maxi(_draw_calls_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	_objects_max = maxi(_objects_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	var r: String = String(GameState.current_region_id)
	if r != "":
		_regions[r] = float(_regions.get(r, 0.0)) + delta


func note(text: String) -> void:
	_notes.append("[day %d %s] %s" % [TimeManager.day, TimeManager.get_clock_string(), text])


## Percentile of the collected frame times in ms (p in 0..1).
func percentile(p: float) -> float:
	if _frames.is_empty():
		return 0.0
	var sorted: PackedFloat32Array = _frames.duplicate()
	sorted.sort()
	return sorted[clampi(int(p * (sorted.size() - 1)), 0, sorted.size() - 1)]


## Percentile over the most recent ~5 seconds (cheap enough to show every frame).
func recent_percentile(p: float) -> float:
	if _frames.is_empty():
		return 0.0
	var recent: PackedFloat32Array = _frames.slice(maxi(_frames.size() - 300, 0))
	recent.sort()
	return recent[clampi(int(p * (recent.size() - 1)), 0, recent.size() - 1)]


func summary() -> String:
	var avg: float = 0.0
	for f: float in _frames:
		avg += f
	avg = avg / maxf(_frames.size(), 1)
	var lines: PackedStringArray = []
	lines.append("Horizon Road QA report")
	lines.append("version: %s" % ProjectSettings.get_setting("application/config/version", "?"))
	lines.append("godot: %s" % Engine.get_version_info().string)
	lines.append("os: %s %s" % [OS.get_name(), OS.get_version()])
	lines.append("cpu: %s (%d threads)" % [OS.get_processor_name(), OS.get_processor_count()])
	lines.append("gpu: %s" % RenderingServer.get_video_adapter_name())
	lines.append("renderer: %s / %s" % [RenderingServer.get_video_adapter_api_version(), ProjectSettings.get_setting("rendering/renderer/rendering_method", "?")])
	lines.append("window: %s  scale: %s" % [DisplayServer.window_get_size(), get_viewport().scaling_3d_scale])
	lines.append("frames: %d  avg: %.1f ms (%.0f fps)  p50: %.1f  p95: %.1f  p99: %.1f  worst: %.0f ms  spikes>50ms: %d" % [
		_frames.size(), avg, 1000.0 / maxf(avg, 0.001), percentile(0.5), percentile(0.95), percentile(0.99), _worst_ms, _spikes])
	lines.append("draw calls max: %d  objects max: %d  static mem: %.0f MB" % [_draw_calls_max, _objects_max, OS.get_static_memory_usage() / 1048576.0])
	var where: PackedStringArray = []
	for r: String in _regions:
		where.append("%s %.0fs" % [r, _regions[r]])
	lines.append("time per region: %s" % ", ".join(where))
	lines.append("day %d  money %d  quests done %d/%d" % [TimeManager.day, GameState.money, _quests_done(), QuestLog.load_quests().size()])
	for n: String in _notes:
		lines.append(n)
	return "\n".join(lines)


func _quests_done() -> int:
	var n: int = 0
	for q: Dictionary in QuestLog.load_quests():
		if QuestLog.is_done(q):
			n += 1
	return n


func write() -> String:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(summary() + "\n")
	return ProjectSettings.globalize_path(PATH)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _frames.is_empty():
		write()
