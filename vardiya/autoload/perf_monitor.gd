extends Node
## Frame-time instrumentation. F3 toggles an overlay. Command-line options
## (after "--"):  --perf-log=<path>   write a JSON report on exit
##                --benchmark         auto-play the test chapter, then quit
## The report holds avg / p95 / p99 / max frame time, memory and draw calls.

signal quality_lowered(step: String)

const SAMPLE_COUNT := 1800  # ~60 s at 30 FPS
## Quality governor: when gameplay averages slower than GOV_LIMIT_MS over a
## window, step down once (effects off, then 3D resolution 85 %, then 70 %).
## Never steps back up by itself; the player can in Settings.
const GOV_WINDOW_SEC := 5.0
const GOV_LIMIT_MS := 38.0
const GOV_WARMUP_SEC := 4.0
const RENDER_SCALES := [1.0, 0.85, 0.7]

var benchmark := false
## Number of automatic step-downs this session (for the report).
var governor_steps := 0
var log_path := ""
var _samples := PackedFloat32Array()
var _index := 0
var _filled := false
var _overlay: CanvasLayer
var _label: Label
var _accum := 0.0
var _peak_static_mem := 0
var _total_frames := 0
var _gameplay := false
var _warmup := 0.0
var _gov_sum := 0.0
var _gov_frames := 0


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
	_govern(delta)
	if _overlay.visible and _accum >= 0.5:
		_accum = 0.0
		var r := report()
		_label.text = "%d fps | avg %.2f ms | p99 %.2f ms | max %.2f ms | mem %d MB | vram %d MB | draws %d" % [
			r["fps"], r["avg_ms"], r["p99_ms"], r["max_ms"], r["static_mem_mb"], r["video_mem_mb"], r["draw_calls"]]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_perf"):
		_overlay.visible = not _overlay.visible


## Story player: true while a 3D location is on screen. Restarts the warm-up
## so loading hitches never count.
func set_gameplay(on: bool) -> void:
	_gameplay = on
	_warmup = GOV_WARMUP_SEC
	_gov_sum = 0.0
	_gov_frames = 0


func governor_enabled() -> bool:
	return _gameplay and not benchmark and bool(SaveSystem.settings.get("auto_quality", true)) and not get_tree().paused


func _govern(delta: float) -> void:
	if not governor_enabled():
		return
	if _warmup > 0.0:
		_warmup -= delta
		return
	_gov_sum += delta
	_gov_frames += 1
	if _gov_sum < GOV_WINDOW_SEC:
		return
	var avg_ms := _gov_sum / _gov_frames * 1000.0
	_gov_sum = 0.0
	_gov_frames = 0
	if avg_ms > GOV_LIMIT_MS:
		step_down()


## One step down the quality ladder. Returns the step taken ("" = already at the bottom).
func step_down() -> String:
	var step := ""
	if str(SaveSystem.settings.get("visual_quality", "high")) == "high":
		SaveSystem.set_setting("visual_quality", "low")
		step = "effects"
	else:
		var scale := float(SaveSystem.settings.get("render_scale", 1.0))
		for s: float in RENDER_SCALES:
			if s < scale - 0.01:
				SaveSystem.set_setting("render_scale", s)
				step = "resolution"
				break
	if step != "":
		governor_steps += 1
		_warmup = GOV_WARMUP_SEC
		quality_lowered.emit(step)
	return step


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
		"render_scale": get_tree().root.scaling_3d_scale,
		"visual_quality": str(SaveSystem.settings.get("visual_quality", "high")),
		"governor_steps": governor_steps,
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
