extends Node
## Ana sahne yöneticisi: menü, bölüm geçişleri, kararma, başlık kartları,
## duraklatma/günlük, sonlar ve jenerik.

var level = null
var hud: HUD
var _menu_layer: CanvasLayer
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _card: Label
var _menu: Control = null
var _busy := false
var _in_intro := false
var _intro_skip := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.main = self
	hud = HUD.new()
	add_child(hud)
	GameState.hud = hud
	hud.visible = false
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 30
	add_child(_menu_layer)
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 40
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)
	_card = Label.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_theme_font_size_override("font_size", 48)
	_card.add_theme_color_override("font_color", Color(0.92, 0.9, 0.86))
	_card.modulate.a = 0.0
	_fade_layer.add_child(_card)
	GameState.log_event("start v%s" % str(ProjectSettings.get_setting("application/config/version", "1.0")))
	# eski kayıtlar: oyunu bitirmiş oyuncu yeni bölüm dahil her şeyi açık bulsun
	var ach: Array = GameState.settings.get("achievements", [])
	if "BELL" in ach or "SILENCE" in ach:
		GameState.settings["unlocked"] = maxi(int(GameState.settings.get("unlocked", 1)), 5)
	_boot()


## Açılış: stüdyo logosu → (ilk seferde dil seçimi) → başlık introsu → ana menü.
func _boot() -> void:
	_fade.color.a = 0.0
	var intro := IntroSequence.new()
	add_child(intro)
	await intro.studio_splash()
	if not bool(GameState.settings.get("lang_chosen", false)):
		_fade.color.a = 1.0
		intro.set_process_input(false)
		_first_lang()
		while not bool(GameState.settings.get("lang_chosen", false)):
			await get_tree().process_frame
		_fade.color.a = 0.0
		intro.set_process_input(true)
	await intro.title_intro()
	intro.queue_free()
	_fade.color.a = 1.0
	show_main_menu()


## İlk açılışta dil seçimi.
func _first_lang() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(root)
	var box := UIKit.frame(root, Loc.t("UI_FIRST_LANG"), Vector2(700, 380))
	var tr := UIKit.button("Türkçe", _choose_lang.bind("tr", root))
	tr.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tr)
	var en := UIKit.button("English", _choose_lang.bind("en", root))
	en.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(en)
	tr.grab_focus.call_deferred()
	fade_in(0.6)


func _choose_lang(code: String, root: Control) -> void:
	GameState.settings["lang"] = code
	GameState.settings["voice_lang"] = code
	GameState.settings["lang_chosen"] = true
	GameState.save_settings()
	root.queue_free()


# ------------------------------------------------------------------ fade / cards
func fade_out(t := 0.8) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, t)
	await tw.finished


func fade_in(t := 0.8) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, t)
	await tw.finished


func show_card(text: String, secs := 2.5) -> void:
	_card.text = text
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.8)
	tw.tween_interval(secs)
	tw.tween_property(_card, "modulate:a", 0.0, 0.8)
	await tw.finished


## Siyah ekranda satırları oynat (pröloğ, epilog, İstanbul sahnesi).
func black_lines(keys: Array) -> void:
	_fade.color.a = 1.0
	await Dialogue.play(keys, true)


# ------------------------------------------------------------------ menus
func _clear_level() -> void:
	Dialogue.stop_all()
	GameState.input_locked = 0
	if level and is_instance_valid(level):
		level.queue_free()
	level = null
	GameState.level = null
	GameState.player = null
	LightSystem.clear()


func _set_menu(m: Control) -> void:
	if _menu and is_instance_valid(_menu):
		_menu.queue_free()
	_menu = m
	if m:
		_menu_layer.add_child(m)


func show_main_menu() -> void:
	get_tree().paused = false
	_clear_level()
	hud.visible = false
	AudioManager.stop_music()
	AudioManager.play_theme("menu", 2.0, true)
	_set_menu(MainMenu.new().setup(self))
	fade_in(1.0)


func _unhandled_input(event: InputEvent) -> void:
	if _in_intro and event.is_action_pressed("pause"):
		_intro_skip = true
		Dialogue.stop_all()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("screenshot"):
		_screenshot()
		return
	if event.is_action_pressed("smoke_test") and OS.is_debug_build() and not _busy:
		smoke_test()
		return
	if level != null and event.is_action_pressed("photo") and not get_tree().paused:
		hud.set_photo_mode(not hud.photo_mode)
		Dialogue._layer.visible = not hud.photo_mode
		return
	if level == null or _busy or GameState.input_locked > 0:
		return
	if _menu and is_instance_valid(_menu):
		return
	if get_tree().paused:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		get_tree().paused = true
		_menu_layer.add_child(PauseMenu.new().setup(self))
	elif event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		get_tree().paused = true
		_menu_layer.add_child(Journal.new())


# ------------------------------------------------------------------ game flow
func start_new_game() -> void:
	GameState.new_game()
	start_chapter(0, false, true)


func continue_game() -> void:
	if GameState.load_game():
		start_chapter(GameState.chapter, true)


func start_chapter_select(n: int) -> void:
	GameState.prepare_chapter_select(n)
	start_chapter(n, false)


func _make_level(n: int) -> Node:
	match n:
		0:
			return PrologueLevel.new()
		4:
			return InterludeLevel.new()
		5:
			return ChapterFive.new()
		1:
			return ChapterOne.new()
		2:
			return ChapterTwo.new()
		_:
			return ChapterThree.new()


func start_chapter(n: int, from_checkpoint: bool, prologue := false) -> void:
	if _busy:
		return
	_busy = true
	await fade_out(0.8)
	_set_menu(null)
	_clear_level()
	hud.visible = false
	GameState.begin_chapter(n, from_checkpoint)
	if prologue:
		await play_intro()
	if not from_checkpoint:
		match n:
			0:
				await show_panel("story/intro_2.png", Loc.t("CH0_TITLE"), 0.0, ["INTRO_02"])
			4:
				await show_panel("story/intro_3.png", Loc.t("CHI_TITLE"), 2.6)
			_:
				# bölüm kartında rastgele bir oynanış ipucu
				var tip := Loc.t("TIP_%d" % randi_range(1, 8))
				await show_panel("story/ch%d.png" % n, Loc.t("CH%d_TITLE" % n) + "\n\n" + tip, 3.4)
	level = _make_level(n)
	add_child(level)
	level.start(from_checkpoint)
	hud.visible = true
	GameState.save_game()
	_busy = false
	await fade_in(1.2)
	if from_checkpoint:
		var ok := str(GameState.get_flag_value("objective", ""))
		if ok != "":
			hud.hint(Loc.t("UI_RECAP") + ": " + Loc.t(ok), 5.0)


func chapter_complete(n: int) -> void:
	GameState.input_locked += 1
	if not GameState.ran_dry_this_chapter and n in [1, 2, 3, 5]:
		GameState.unlock("NO_DARK")
	if GameState.stat_caught == 0 and n in [1, 2, 3, 4, 5]:
		GameState.unlock("GHOST")
	if n == 0:
		GameState.unlock("PROLOGUE")
	GameState.log_event("chapter_complete %d time=%d caught=%d" % [n, int(GameState.stat_time), GameState.stat_caught])
	var nxt: int = {0: 1, 1: 2, 2: 4, 4: 5, 5: 3}.get(n, -1)
	var unlocked := int(GameState.settings.get("unlocked", 1))
	var unl: int = {0: 1, 1: 2, 2: 3, 4: 4, 5: 5}.get(n, unlocked)
	GameState.settings["unlocked"] = maxi(unlocked, unl)
	GameState.save_settings()
	if n == 0:
		await fade_out(1.0)
		await black_lines(["CE_0"])
		await _prologue_after()
	elif n in [1, 2, 5]:
		await _stats_card()
		await black_lines(["CE_%d" % n])
	elif n == 4:
		await fade_out(1.0)
		await black_lines(["CE_4"])
	if nxt >= 0:
		GameState.has_checkpoint = false
		GameState.chapter = nxt
		GameState.save_game()
		start_chapter(nxt, false)


## Pröloğ bitince: kahvehane, sabah, İstanbul, mektup panelleri.
func _prologue_after() -> void:
	_busy = true
	hud.visible = false
	await fade_out(1.2)
	_clear_level()
	_in_intro = true
	_intro_skip = false
	for pn in [[3, ["INTRO_03"]], [4, ["INTRO_04"]], [5, ["INTRO_05"]], [6, ["INTRO_06", "C1_000", "C1_001", "C1_002"]]]:
		if _intro_skip:
			break
		await show_panel("story/intro_%d.png" % int(pn[0]), "", 0.0, pn[1])
	_in_intro = false
	_busy = false


## Bölüm sonu özeti.
func _stats_card() -> void:
	var t := int(GameState.stat_time)
	var lines := [
		Loc.t("UI_STATS"),
		"",
		"%s: %02d:%02d" % [Loc.t("UI_STAT_TIME"), t / 60, t % 60],
		"%s: %d / 12" % [Loc.t("UI_STAT_PAGES"), GameState.pages.size()],
		"%s: %d / 6" % [Loc.t("UI_STAT_LETTERS"), GameState.letters.size()],
		"%s: %d" % [Loc.t("UI_STAT_BRAZIERS"), GameState.stat_braziers],
		"%s: %d" % [Loc.t("UI_STAT_CAUGHT"), GameState.stat_caught],
	]
	await fade_out(0.8)
	_card.add_theme_font_size_override("font_size", 40)
	await show_card("\n".join(PackedStringArray(lines)), 4.0)
	_card.add_theme_font_size_override("font_size", 48)


# ------------------------------------------------------------------ endings
func ending_escape() -> void:
	# Son B: Kerem Yusuf'u sırtında tekneye taşır (oynanabilir kaçış)
	_busy = true
	await fade_out(1.2)
	_clear_level()
	level = EndingEscape.new()
	add_child(level)
	level.start(false)
	_busy = false
	await fade_in(1.2)


func finish_ending(kind: String) -> void:
	_busy = true
	hud.visible = false
	await fade_out(1.6)
	_clear_level()
	if GameState.stat_caught == 0:
		GameState.unlock("GHOST")
	if int(GameState.settings.get("difficulty", 1)) >= 2:
		GameState.unlock("KEEPER")
	GameState.log_event("ending %s" % kind)
	if kind == "A":
		GameState.unlock("BELL")
		# menüde fener artık yanıyor
		GameState.settings["lit"] = true
		GameState.save_settings()
		AudioManager.play_sfx("bell_big", -6.0)
		await show_panel("story/end_a.png", Loc.t("EA_007"), 4.0)
		await show_card(Loc.t("ENDING_A"), 2.5)
	else:
		GameState.unlock("SILENCE")
		await show_panel("story/end_b.png", Loc.t("EB_004"), 0.5, ["EB_005", "EB_006"])
		AudioManager.play_sfx("whisper", -2.0)
		await black_lines(["EB_007"])
		await show_card(Loc.t("ENDING_B"), 2.5)
	await _credits()
	if kind == "A" and GameState.pages.size() >= 12:
		await show_card(Loc.t("EP_000"), 2.5)
		await black_lines(["EP_001", "EP_002", "EP_003", "EP_004"])
		if GameState.letters.size() >= 6:
			await black_lines(["EP_005"])
		AudioManager.play_sfx("bell_big")
		await get_tree().create_timer(5.0).timeout
	_busy = false
	show_main_menu()


func _credits() -> void:
	await show_panel("story/intro_1.png", "SİS ÇANI / FOG BELL", 2.5)
	await show_panel("story/ch1.png", Loc.t("CREDITS_1"), 2.5)
	await show_panel("story/ch2.png", Loc.t("CREDITS_2"), 2.0)
	await show_panel("story/ch3.png", Loc.t("CREDITS_THANKS"), 3.0)
	await show_panel("story/intro_3.png", Loc.t("CR_MEM"), 5.0)


## Tam ekran pixel art panel katmanı (bölüm kartı, son, jenerik).
func _panel_layer() -> Array:
	var layer := CanvasLayer.new()
	layer.layer = 42
	add_child(layer)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0)
	layer.add_child(bg)
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.pivot_offset = Vector2(960, 540)
	tr.modulate.a = 0.0
	layer.add_child(tr)
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.offset_bottom = -120
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 56)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 3)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	lbl.modulate.a = 0.0
	layer.add_child(lbl)
	return [layer, tr, lbl]


## Bir paneli metinle göster: yavaş yakınlaşma + yazı.
func show_panel(tex_path: String, text: String, secs: float, lines: Array = []) -> void:
	var parts := _panel_layer()
	var layer: CanvasLayer = parts[0]
	var tr: TextureRect = parts[1]
	var lbl: Label = parts[2]
	tr.texture = Art.tex(tex_path)
	lbl.text = text
	var tw := create_tween()
	tw.tween_property(tr, "modulate:a", 1.0, 1.0)
	tw.parallel().tween_property(lbl, "modulate:a", 1.0, 1.4).set_delay(0.4)
	var zoom := create_tween()
	zoom.tween_property(tr, "scale", Vector2(1.06, 1.06), secs + 4.0)
	await tw.finished
	if lines.is_empty():
		await get_tree().create_timer(secs).timeout
	else:
		await Dialogue.play(lines, true)
	var out := create_tween()
	out.tween_property(tr, "modulate:a", 0.0, 0.9)
	out.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
	await out.finished
	zoom.kill()
	layer.queue_free()


## Resimli açılış: 6 pixel art panel + anlatım + son mektup.
func play_intro() -> void:
	_in_intro = true
	_intro_skip = false
	var layer := CanvasLayer.new()
	layer.layer = 42
	add_child(layer)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0)
	layer.add_child(bg)
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.pivot_offset = Vector2(960, 540)
	layer.add_child(tr)
	var hint := Label.new()
	hint.text = "Esc: " + Loc.t("UI_SKIP").replace("[E] ", "")
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	hint.position = Vector2(1720, 30)
	layer.add_child(hint)
	_fade.color.a = 0.0
	var panels := [[1, ["INTRO_01"]]]
	for pn in panels:
		if _intro_skip:
			break
		tr.texture = Art.tex("story/intro_%d.png" % int(pn[0]))
		tr.modulate.a = 0.0
		tr.scale = Vector2.ONE
		var tw := create_tween()
		tw.tween_property(tr, "modulate:a", 1.0, 0.9)
		var zoom := create_tween()
		zoom.tween_property(tr, "scale", Vector2(1.07, 1.07), 14.0)
		await Dialogue.play(pn[1], true)
		zoom.kill()
		var out := create_tween()
		out.tween_property(tr, "modulate:a", 0.0, 0.7)
		await out.finished
	_fade.color.a = 1.0
	layer.queue_free()
	_in_intro = false


func _screenshot() -> void:
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var img := get_viewport().get_texture().get_image()
	var path := "user://screenshots/sis_cani_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	img.save_png(path)
	if hud:
		hud.toast(Loc.t("UI_SCREENSHOT"))


func open_radio(on_done: Callable) -> void:
	var r := RadioMinigame.new()
	r.done.connect(func(): on_done.call())
	hud.add_child(r)


# ------------------------------------------------------------------ QA
## F9 (yalnızca hata ayıklama derlemesi): tüm seviyeleri sırayla yükler ve
## user://smoke_test.txt dosyasına sonuç yazar. Bir seviyede betik hatası olursa
## dosya o satırda kalır; hangi seviyenin bozuk olduğu böylece görülür.
func smoke_test() -> void:
	_busy = true
	var out := FileAccess.open("user://smoke_test.txt", FileAccess.WRITE)
	out.store_line("SİS ÇANI smoke test  %s" % Time.get_datetime_string_from_system())
	_set_menu(null)
	hud.visible = true
	var saved_settings := GameState.settings.duplicate(true)
	for n in [0, 1, 2, 4, 5, 3, 99]:
		out.store_line("level %d: loading" % n)
		out.flush()
		_clear_level()
		GameState.prepare_chapter_select(maxi(n, 1) if n != 99 else 3)
		GameState.begin_chapter(n if n != 99 else 3, false)
		if n == 99:
			level = EndingEscape.new()
		else:
			level = _make_level(n)
		add_child(level)
		level.start(false)
		_fade.color.a = 0.0
		await get_tree().create_timer(2.5).timeout
		var echo_n := get_tree().get_nodes_in_group("echo").size()
		var inter_n := get_tree().get_nodes_in_group("interactable").size()
		var p = GameState.player
		var alive: bool = p != null and is_instance_valid(p)
		out.store_line("level %d: OK  echoes=%d interactables=%d player=%s fps=%d" % [n, echo_n, inter_n, str(alive), Engine.get_frames_per_second()])
		out.flush()
	out.store_line("DONE")
	out.close()
	GameState.settings = saved_settings
	GameState.log_event("smoke test finished")
	_busy = false
	show_main_menu()
	hud.toast("Smoke test: user://smoke_test.txt")