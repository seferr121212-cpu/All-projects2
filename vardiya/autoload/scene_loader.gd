extends Node
## Asynchronous scene changes via ResourceLoader threaded loading, with a
## minimal loading overlay so the main thread never stalls on SATA SSD reads.

signal load_progress(ratio: float)
signal scene_ready(path: String)

var last_load_ms := 0
var _pending := ""
var _overlay: CanvasLayer
var _label: Label
var _started_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	_overlay.visible = false
	add_child(_overlay)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.06, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)
	_label = Label.new()
	_label.text = "ui.loading"
	_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_label.offset_left = -420.0
	_label.offset_top = -110.0
	_label.offset_right = -60.0
	_label.offset_bottom = -60.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 32)
	_overlay.add_child(_label)
	set_process(false)


func change_scene(path: String) -> void:
	if _pending != "":
		return
	var err := ResourceLoader.load_threaded_request(path, "PackedScene", true)
	if err != OK:
		push_error("SceneLoader: cannot request %s (%d)" % [path, err])
		return
	_pending = path
	_started_ms = Time.get_ticks_msec()
	_overlay.visible = true
	set_process(true)


func _process(_delta: float) -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_pending, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not progress.is_empty():
				load_progress.emit(float(progress[0]))
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(_pending) as PackedScene
			var path := _pending
			_pending = ""
			set_process(false)
			get_tree().paused = false
			get_tree().change_scene_to_packed(packed)
			last_load_ms = Time.get_ticks_msec() - _started_ms
			_overlay.visible = false
			scene_ready.emit(path)
		_:
			push_error("SceneLoader: failed to load %s" % _pending)
			_pending = ""
			_overlay.visible = false
			set_process(false)
