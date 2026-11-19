extends Control
## Hosts a chapter: the 3D grey-box world (WorldView), location card,
## subtitles / choices, exploration HUD, QTE overlay, journal, chapter
## flowchart and pause. 2D UI is drawn on top of the 3D view.

const UiTheme = preload("res://ui/ui_theme.gd")
const DialogueUI = preload("res://ui/dialogue_ui.gd")
const ChapterSummary = preload("res://ui/chapter_summary.gd")
const PauseMenu = preload("res://ui/pause_menu.gd")
const ExploreHud = preload("res://ui/explore_hud.gd")
const QteUI = preload("res://ui/qte_ui.gd")
const JournalMenu = preload("res://ui/journal_menu.gd")
const EndingScreen = preload("res://ui/ending_screen.gd")
const Credits = preload("res://ui/credits.gd")
const WorldView = preload("res://scenes/world/world_view.gd")
const MENU_SCENE := "res://ui/main_menu.tscn"
## next_chapter value of the last story chapter: resolve the ending, then play its epilogue.
const ENDING_LINK := "@ending"
const BENCHMARK_STEP_SEC := 0.35
const BENCHMARK_EXPLORE_SEC := 2.0
const BENCHMARK_LOOPS := 2

var _world: WorldView
var _bg: ColorRect
var _location: Label
var _dialogue: DialogueUI
var _hud: ExploreHud
var _qte: QteUI
var _journal: JournalMenu
var _summary: ChapterSummary
var _pause: PauseMenu
var _ending_screen: EndingScreen
var _credits: Credits
var _save_icon: Label
var _bench_timer := 0.0
var _bench_loops_left := BENCHMARK_LOOPS
var _bench_choice := 0
var _next_chapter := ""
## Set when this session resolved the ending (true if it was unlocked for the first time).
var _ending_new := false


func _ready() -> void:
	theme = UiTheme.build()
	# Let clicks fall through to _unhandled_input (mouse = advance).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world = WorldView.new()
	add_child(_world)
	_bg = ColorRect.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.color = UiTheme.BG
	UiTheme.full_rect(_bg)
	add_child(_bg)
	_location = UiTheme.make_label("", UiTheme.FONT_HEADING, UiTheme.TEXT)
	_location.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_location.add_theme_color_override("font_outline_color", Color.BLACK)
	_location.add_theme_constant_override("outline_size", 10)
	_location.position = Vector2(120, 100)
	_location.modulate.a = 0.0
	add_child(_location)
	_hud = ExploreHud.new()
	_hud.world = _world
	add_child(_hud)
	_dialogue = DialogueUI.new()
	add_child(_dialogue)
	_qte = QteUI.new()
	add_child(_qte)
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
	_ending_screen = EndingScreen.new()
	add_child(_ending_screen)
	_ending_screen.continued.connect(_on_ending_continued)
	_credits = Credits.new()
	add_child(_credits)
	_credits.finished.connect(_go_to_menu)
	_journal = JournalMenu.new()
	add_child(_journal)
	_pause = PauseMenu.new()
	add_child(_pause)
	_pause.quit_to_menu.connect(_go_to_menu)

	_world.focus_item_changed.connect(_hud.set_focus)
	DialogueRunner.location_changed.connect(_on_location)
	DialogueRunner.line_shown.connect(_on_line)
	DialogueRunner.choice_shown.connect(_on_choice)
	DialogueRunner.explore_started.connect(_on_explore)
	DialogueRunner.item_examined.connect(_on_item_examined)
	DialogueRunner.qte_started.connect(_on_qte)
	DialogueRunner.chapter_finished.connect(_on_chapter_finished)
	SaveSystem.saved.connect(_on_saved)
	InputRouter.gamepad_disconnected.connect(_on_gamepad_disconnected)

	var chapter_id := GameState.current_chapter
	if chapter_id == "":
		chapter_id = SaveSystem.first_chapter_id()
	# Resuming mid-chapter: rebuild the location we were in before running.
	var loc: Dictionary = GameState.location
	if GameState.current_node != "" and str(loc.get("scene", "")) != "":
		_build_world(str(loc["scene"]), str(loc.get("spawn", "default")))
	if not DialogueRunner.start(chapter_id, GameState.current_node):
		_go_to_menu()


func _exit_tree() -> void:
	DialogueRunner.stop()


func _process(delta: float) -> void:
	GameState.play_time_sec += delta
	if PerfMonitor.benchmark:
		_benchmark_step(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _summary.visible or _ending_screen.visible or _credits.visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_pause.open()
	elif event.is_action_pressed("journal") and DialogueRunner.waiting != DialogueRunner.Wait.CHOICE \
			and DialogueRunner.waiting != DialogueRunner.Wait.QTE:
		get_viewport().set_input_as_handled()
		_journal.open()


func _build_world(scene_id: String, spawn: String) -> void:
	if scene_id == "":
		_world.unload()
		_bg.visible = true
		return
	var ok := _world.load_location(scene_id, spawn, str(GameState.location.get("player", "kemal")))
	_bg.visible = not ok


func _on_location(location_key: String, scene_id: String, spawn: String) -> void:
	_build_world(scene_id, spawn)
	if location_key == "":
		return
	_location.text = Localization.t(location_key)
	var tw := create_tween()
	tw.tween_property(_location, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.5)
	tw.tween_property(_location, "modulate:a", 0.0, 1.0)


func _on_line(speaker: String, _text_key: String) -> void:
	_world.set_exploring(false)
	_hud.hide_explore()
	_world.on_line(speaker)


func _on_choice(_node: Dictionary, _options: Array, _time: float) -> void:
	_world.set_exploring(false)
	_hud.hide_explore()


func _on_explore(node: Dictionary, items: Array) -> void:
	_dialogue.hide_all()
	_world.set_exploring(true, items)
	_hud.show_explore(str(node.get("objective", "")))


func _on_item_examined(_item_id: String, journal_key: String) -> void:
	_hud.show_note(journal_key)


func _on_qte(_node: Dictionary, _params: Dictionary) -> void:
	_world.set_exploring(false)
	_hud.hide_explore()
	_dialogue.hide_all()


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


func _on_chapter_finished(chapter_id: String, next_chapter: String) -> void:
	_dialogue.hide_all()
	_hud.hide_explore()
	_world.set_exploring(false)
	_next_chapter = next_chapter
	if PerfMonitor.benchmark:
		return
	if next_chapter == ENDING_LINK:
		var ending := DecisionManager.resolve_and_unlock_ending()
		_ending_new = bool(ending.get("new", false))
		_next_chapter = str(ending.get("epilogue", ""))
		_summary.show_summary(DialogueRunner.chapter, false, ending)
	elif SaveSystem.is_epilogue(chapter_id):
		_show_ending_screen()
	else:
		_summary.show_summary(DialogueRunner.chapter, next_chapter == "")


func _show_ending_screen() -> void:
	_world.unload()
	_bg.visible = true
	var id := str(GameState.get_flag("ending", ""))
	SaveSystem.unlock_ending(id)  # e.g. resumed from a save made inside the epilogue
	SaveSystem.autosave()
	_ending_screen.show_ending(DecisionManager.ending_details(id), _ending_new)


func _on_ending_continued() -> void:
	_credits.start()


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
## (every 4th choice times out), orbit the camera during exploration and
## visit every item, alternate QTE results.
func _benchmark_step(delta: float) -> void:
	_bench_timer += delta
	var waiting: int = DialogueRunner.waiting
	if waiting == DialogueRunner.Wait.EXPLORE:
		if _world.rig:
			_world.rig.yaw += delta * 0.8
		if _bench_timer < BENCHMARK_EXPLORE_SEC:
			return
		_bench_timer = 0.0
		var items := DialogueRunner.explore_items()
		var pick: Dictionary = {}
		for it: Dictionary in items:
			if not it["found"] and not it.has("next"):
				pick = it
				break
		if pick.is_empty():
			for it: Dictionary in items:
				if it.has("next"):
					pick = it
		DialogueRunner.interact(str(pick.get("id", "")))
		return
	if _bench_timer < BENCHMARK_STEP_SEC:
		return
	_bench_timer = 0.0
	if waiting == DialogueRunner.Wait.ADVANCE:
		DialogueRunner.advance()
	elif waiting == DialogueRunner.Wait.CHOICE:
		_bench_choice += 1
		if _bench_choice % 4 != 0:
			var opts := DialogueRunner.current_options()
			DialogueRunner.choose(str(opts[_bench_choice % opts.size()]["id"]))
	elif waiting == DialogueRunner.Wait.QTE:
		DialogueRunner.force_qte_result(_bench_choice % 2 == 0)
	elif waiting == DialogueRunner.Wait.FINISHED:
		_bench_loops_left -= 1
		if _bench_loops_left <= 0:
			PerfMonitor.write_report()
			get_tree().quit()
		else:
			GameState.reset()
			DialogueRunner.start(SaveSystem.first_chapter_id())
