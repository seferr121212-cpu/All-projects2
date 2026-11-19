extends Control
## Title screen: continue, new game (slot), load / chapter replay, settings,
## quick language toggle (tab_next / R / RB), quit.

const UiTheme = preload("res://ui/ui_theme.gd")
const SlotMenu = preload("res://ui/slot_menu.gd")
const SettingsMenu = preload("res://ui/settings_menu.gd")
const STORY_SCENE := "res://scenes/story_player.tscn"

var _menu: VBoxContainer
var _continue: Button
var _new_game: Button
var _load: Button
var _slots: SlotMenu
var _settings: SettingsMenu
var _lang_hint: Label


func _ready() -> void:
	theme = UiTheme.build()
	get_tree().paused = false
	DialogueRunner.stop()
	_build()
	_refresh()
	if PerfMonitor.benchmark:
		_start_benchmark.call_deferred()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	UiTheme.full_rect(bg)
	add_child(bg)

	var margin := MarginContainer.new()
	UiTheme.full_rect(margin)
	margin.add_theme_constant_override("margin_left", 160)
	margin.add_theme_constant_override("margin_top", 140)
	margin.add_theme_constant_override("margin_right", 160)
	margin.add_theme_constant_override("margin_bottom", 100)
	add_child(margin)

	var row := HBoxContainer.new()
	margin.add_child(row)
	_menu = VBoxContainer.new()
	_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_menu)

	_menu.add_child(UiTheme.make_label("game.title", UiTheme.FONT_TITLE, UiTheme.ACCENT))
	_menu.add_child(UiTheme.make_label("game.tagline", UiTheme.FONT_BODY, UiTheme.TEXT_DIM))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 60)
	_menu.add_child(spacer)

	_continue = UiTheme.make_button("menu.continue")
	_continue.pressed.connect(_on_continue)
	_new_game = UiTheme.make_button("menu.new_game")
	_new_game.pressed.connect(_open_slots.bind("new"))
	_load = UiTheme.make_button("menu.load")
	_load.pressed.connect(_open_slots.bind("load"))
	var settings := UiTheme.make_button("menu.settings")
	settings.pressed.connect(_open_settings)
	var quit := UiTheme.make_button("menu.quit")
	quit.pressed.connect(func() -> void: get_tree().quit())
	for b in [_continue, _new_game, _load, settings, quit]:
		_menu.add_child(b)

	_lang_hint = UiTheme.make_label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	_lang_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_lang_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_lang_hint.offset_left = 160
	_lang_hint.offset_top = -80
	_lang_hint.offset_bottom = -40
	_lang_hint.offset_right = 1200
	add_child(_lang_hint)

	var holder := CenterContainer.new()
	UiTheme.full_rect(holder)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_slots = SlotMenu.new()
	_slots.visible = false
	holder.add_child(_slots)
	_slots.closed.connect(_back_to_menu)
	_slots.start_new.connect(_on_start_new)
	_slots.continue_slot.connect(_on_continue_slot)
	_slots.replay_chapter.connect(_on_replay)
	_settings = SettingsMenu.new()
	_settings.visible = false
	holder.add_child(_settings)
	_settings.closed.connect(_back_to_menu)

	Localization.locale_changed.connect(_on_locale_changed)
	InputRouter.device_changed.connect(_on_device_changed)


func _on_locale_changed(_locale: String) -> void:
	_refresh_hint()


func _on_device_changed(_pad: bool) -> void:
	_refresh_hint()
	if get_viewport().gui_get_focus_owner() == null and _menu.visible:
		_focus_menu()


func _refresh() -> void:
	var has_any := SaveSystem.any_save()
	_continue.visible = has_any
	_load.disabled = not has_any
	var buttons: Array = []
	for c in _menu.get_children():
		if c is Button:
			buttons.append(c)
	UiTheme.chain_focus(buttons)
	_refresh_hint()
	_focus_menu()


func _refresh_hint() -> void:
	_lang_hint.text = Localization.t("menu.language_hint", {"button": InputRouter.prompt("tab_next"),
		"language": Localization.t("lang." + Localization.next_locale())})


func _focus_menu() -> void:
	_menu.visible = true
	(_continue if _continue.visible else _new_game).grab_focus()


func _back_to_menu() -> void:
	_refresh()


func _open_slots(mode: String) -> void:
	AudioBus.play("ui/select")
	_menu.visible = false
	_slots.open(mode)


func _open_settings() -> void:
	AudioBus.play("ui/select")
	_menu.visible = false
	_settings.open()


func _on_continue() -> void:
	_on_continue_slot(SaveSystem.latest_slot())


func _on_start_new(slot: int) -> void:
	SaveSystem.new_game(slot)
	SceneLoader.change_scene(STORY_SCENE)


func _on_continue_slot(slot: int) -> void:
	if SaveSystem.load_slot(slot):
		SceneLoader.change_scene(STORY_SCENE)


func _on_replay(slot: int, chapter_id: String) -> void:
	if SaveSystem.restart_chapter(slot, chapter_id):
		SceneLoader.change_scene(STORY_SCENE)


func _start_benchmark() -> void:
	# No slot is active: the benchmark never writes save files.
	GameState.reset()
	SaveSystem.active_slot = -1
	GameState.current_chapter = SaveSystem.first_chapter_id()
	SceneLoader.change_scene(STORY_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if _menu.visible and event.is_action_pressed("tab_next"):
		get_viewport().set_input_as_handled()
		SaveSystem.set_setting("locale", Localization.next_locale())
