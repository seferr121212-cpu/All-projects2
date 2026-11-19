extends Control
## Hosts a chapter: background, location card, subtitles/choices, chapter
## summary and pause. Stage 2 is 2D only; stage 3 swaps the background for
## grey-box 3D locations loaded per "location" node.

const UiTheme = preload("res://ui/ui_theme.gd")
const DialogueUI = preload("res://ui/dialogue_ui.gd")
const ChapterSummary = preload("res://ui/chapter_summary.gd")
const PauseMenu = preload("res://ui/pause_menu.gd")
const MENU_SCENE := "res://ui/main_menu.tscn"
const BENCHMARK_STEP_SEC := 0.35
const BENCHMARK_LOOPS := 3

var _location: Label
var _dialogue: DialogueUI
var _summary: ChapterSummary
var _pause: PauseMenu
var _save_icon: Label
var _bench_timer := 0.0
var _bench_loops_left := BENCHMARK_LOOPS
var _bench_choice := 0
var _next_chapter := ""


func _ready() -> void:
	theme = UiTheme.build()
	# Let clicks fall through to _unhandled_input (mouse = advance).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = UiTheme.BG
	UiTheme.full_rect(bg)
	add_child(bg)
	_location = UiTheme.make_label("", UiTheme.FONT_HEADING, UiTheme.TEXT_DIM)
	_location.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_location.position = Vector2(120, 100)
	_location.modulate.a = 0.0
	add_child(_location)
	_dialogue = DialogueUI.new()
	add_child(_dialogue)
	_save_icon = UiTheme.make_label("ui.autosaving", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	_save_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_save_icon.offset_left = -400
	_save_icon.offset_right = -60
	_save_icon.offset_top = 50
	_save_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_save_icon.modulate.a = 0.0
	add_child(_save_icon)
	_summary = ChapterSummary.new()
	add_child(_summary)
	_summary.continued.connect(_on_summary_continued)
	_pause = PauseMenu.new()
	add_child(_pause)
	_pause.quit_to_menu.connect(_go_to_menu)

	DialogueRunner.location_changed.connect(_on_location)
	DialogueRunner.chapter_finished.connect(_on_chapter_finished)
	SaveSystem.saved.connect(_on_saved)
	InputRouter.gamepad_disconnected.connect(_on_gamepad_disconnected)

	var chapter_id := GameState.current_chapter
	if chapter_id == "":
		chapter_id = SaveSystem.first_chapter_id()
	if not DialogueRunner.start(chapter_id, GameState.current_node):
		_go_to_menu()


func _exit_tree() -> void:
	DialogueRunner.stop()


func _process(delta: float) -> void:
	GameState.play_time_sec += delta
	if PerfMonitor.benchmark:
		_benchmark_step(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _summary.visible:
		get_viewport().set_input_as_handled()
		_pause.open()


func _on_location(location_key: String) -> void:
	_location.text = Localization.t(location_key)
	var tw := create_tween()
	tw.tween_property(_location, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.5)
	tw.tween_property(_location, "modulate:a", 0.0, 1.0)


func _on_saved(_slot: int) -> void:
	_flash_save_icon()


func _on_gamepad_disconnected() -> void:
	if not _pause.visible:
		_pause.open("pause.controller_lost")


func _flash_save_icon() -> void:
	var tw := create_tween()
	tw.tween_property(_save_icon, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.0)
	tw.tween_property(_save_icon, "modulate:a", 0.0, 0.4)


func _on_chapter_finished(_chapter_id: String, next_chapter: String) -> void:
	_dialogue.hide_all()
	_next_chapter = next_chapter
	if PerfMonitor.benchmark:
		return
	_summary.show_summary(DialogueRunner.chapter, next_chapter == "")


func _on_summary_continued() -> void:
	if _next_chapter != "":
		SaveSystem.begin_chapter(_next_chapter)
		DialogueRunner.start(_next_chapter)
	else:
		_go_to_menu()


func _go_to_menu() -> void:
	DialogueRunner.stop()
	get_tree().paused = false
	SceneLoader.change_scene(MENU_SCENE)


## Auto-play for frame-time measurement: advance lines, rotate choices
## (every few choices let the timer run out to exercise silence).
func _benchmark_step(delta: float) -> void:
	_bench_timer += delta
	if _bench_timer < BENCHMARK_STEP_SEC:
		return
	_bench_timer = 0.0
	var waiting: int = DialogueRunner.waiting
	if waiting == DialogueRunner.Wait.ADVANCE:
		DialogueRunner.advance()
	elif waiting == DialogueRunner.Wait.CHOICE:
		_bench_choice += 1
		if _bench_choice % 4 != 0:
			var opts := DialogueRunner.current_options()
			DialogueRunner.choose(str(opts[_bench_choice % opts.size()]["id"]))
	elif waiting == DialogueRunner.Wait.FINISHED:
		_bench_loops_left -= 1
		if _bench_loops_left <= 0:
			PerfMonitor.write_report()
			get_tree().quit()
		else:
			GameState.reset()
			DialogueRunner.start(SaveSystem.first_chapter_id())
