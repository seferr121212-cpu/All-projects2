extends Node
## Frame-time instrumentation. F3 toggles an overlay. Command-line options
## (after "--"):  --perf-log=<path>   write a JSON report on exit
##                --benchmark         auto-play the test chapter, then quit
## The report holds avg / p95 / p99 / max frame time, memory and draw calls.

const SAMPLE_COUNT := 1800  # ~60 s at 30 FPS

var benchmark := false
var log_path := ""
var _samples := PackedFloat32Array()
var _index := 0
var _filled := false
var _overlay: CanvasLayer
var _label: Label
var _accum := 0.0
var _peak_static_mem := 0
var _total_frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_samples.resize(SAMPLE_COUNT)
	for arg in OS.get_cmdline_user_args():
		if arg == "--benchmark":
			benchmark = true
		elif arg.begins_with("--perf-log="):
			log_path = arg.get_slice("=", 1)
	if benchmark and log_path == "":
		log_path = "user://perf_report.json"
	_overlay = CanvasLayer.new()
	_overlay.layer = 120
	_overlay.visible = benchmark
	add_child(_overlay)
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_overlay.add_child(_label)


func _process(delta: float) -> void:
	_samples[_index] = delta * 1000.0
	_index = (_index + 1) % SAMPLE_COUNT
	if _index == 0:
		_filled = true
	_total_frames += 1
	_peak_static_mem = maxi(_peak_static_mem, int(OS.get_static_memory_usage()))
	_accum += delta
	if _overlay.visible and _accum >= 0.5:
		_accum = 0.0
		var r := report()
		_label.text = "%d fps | avg %.2f ms | p99 %.2f ms | max %.2f ms | mem %d MB | vram %d MB | draws %d" % [
			r["fps"], r["avg_ms"], r["p99_ms"], r["max_ms"], r["static_mem_mb"], r["video_mem_mb"], r["draw_calls"]]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_perf"):
		_overlay.visible = not _overlay.visible


func report() -> Dictionary:
	var n := SAMPLE_COUNT if _filled else _index
	var arr: Array = []
	for i in n:
		arr.append(_samples[i])
	arr.sort()
	var total := 0.0
	for v: float in arr:
		total += v
	var pick := func(q: float) -> float: return arr[mini(int(q * n), n - 1)] if n > 0 else 0.0
	return {
		"frames_sampled": n,
		"fps": int(Performance.get_monitor(Performance.TIME_FPS)),
		"avg_ms": total / n if n > 0 else 0.0,
		"p95_ms": pick.call(0.95),
		"p99_ms": pick.call(0.99),
		"max_ms": arr[n - 1] if n > 0 else 0.0,
		"static_mem_mb": int(OS.get_static_memory_usage() / 1048576),
		"peak_static_mem_mb": int(_peak_static_mem / 1048576),
		"video_mem_mb": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"last_scene_load_ms": SceneLoader.last_load_ms,
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"adapter": RenderingServer.get_video_adapter_name(),
		"resolution": str(get_viewport().get_visible_rect().size),
	}


func write_report() -> void:
	if log_path == "":
		return
	var f := FileAccess.open(log_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report(), "\t"))
		print("PerfMonitor: report written to ", ProjectSettings.globalize_path(log_path))
	print(JSON.stringify(report()))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if log_path != "" and not benchmark:
			write_report()
