extends "res://tests/test_case.gd"
## Faz 7: çeviriler, ayarlar, tuş atama, penaltı kuralları, ekranlar ve modlar.

const SCREENS := ["res://scenes/ui/main_menu.tscn", "res://scenes/ui/team_select.tscn", "res://scenes/ui/settings_menu.tscn"]


func test_translation_csv_complete() -> void:
	var f := FileAccess.open("res://assets/translations/strings.csv", FileAccess.READ)
	var header := f.get_csv_line()
	check(header[0] == "keys" and "tr" in header and "en" in header, "CSV başlığı: keys,tr,en")
	var n := 0
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 3 or row[0] == "":
			continue
		n += 1
		check(row[1].strip_edges() != "" and row[2].strip_edges() != "", "%s iki dilde de dolu olmalı" % row[0])
	check(n >= 80, "Yeterli anahtar (%d)" % n)


func test_translation_switches_language() -> void:
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("tr")
	var tr_text := tr("MENU_QUICK_MATCH")
	TranslationServer.set_locale("en")
	var en_text := tr("MENU_QUICK_MATCH")
	TranslationServer.set_locale(before)
	check(tr_text == "Hızlı Maç" and en_text == "Quick Match", "Dil değişimi: '%s' / '%s'" % [tr_text, en_text])


func test_all_ui_keys_exist() -> void:
	# Koddaki tr("...") anahtarlarının hepsi CSV'de olmalı
	var keys := {}
	var f := FileAccess.open("res://assets/translations/strings.csv", FileAccess.READ)
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() > 0:
			keys[row[0]] = true
	var re := RegEx.create_from_string("tr\\(\"([A-Z_a-z]+)\"\\)")
	for dir in ["res://scripts/ui/", "res://scripts/match/"]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir + file)
			for m in re.search_all(src):
				check(keys.has(m.get_string(1)), "%s: eksik çeviri anahtarı %s" % [file, m.get_string(1)])
	for a in SettingsStore.REBINDABLE:
		check(keys.has("ACTION_" + a), "Aksiyon adı çevirisi: %s" % a)


func test_settings_roundtrip() -> void:
	var path := "user://test_settings.json"
	var s := SettingsStore.new()
	s.data.graphics.shadows = 0
	s.data.audio.master = 0.3
	s.data.language = "en"
	check(s.save_to(path) == OK, "Kaydedilmeli")
	var s2 := SettingsStore.new()
	s2.load_from(path)
	check(int(s2.data.graphics.shadows) == 0 and is_equal_approx(float(s2.data.audio.master), 0.3) and s2.data.language == "en", "Ayarlar geri yüklenmeli")
	check(s2.data.graphics.has("vsync"), "Eksik anahtarlar varsayılanla doldurulmalı")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_rebinding_applies_to_input_map() -> void:
	var s := SettingsStore.new()
	s.capture_default_bindings()
	var k := InputEventKey.new()
	k.physical_keycode = KEY_J
	s.set_binding("pass_short", k)
	var keys := InputMap.action_get_events("pass_short").filter(func(e: InputEvent) -> bool: return e is InputEventKey)
	check(keys.size() == 1 and keys[0].physical_keycode == KEY_J, "Klavye ataması değişmeli")
	var pads := InputMap.action_get_events("pass_short").filter(func(e: InputEvent) -> bool: return e is InputEventJoypadButton)
	check(pads.size() == 1, "Gamepad ataması korunmalı")
	# Kaydet/yükle sonrası aynı atama uygulanmalı
	var s2 := SettingsStore.new()
	s2.data.bindings = JSON.parse_string(JSON.stringify(s.data.bindings))
	s.reset_bindings()
	check(InputMap.action_get_events("pass_short").filter(func(e: InputEvent) -> bool: return e is InputEventKey)[0].physical_keycode == KEY_SPACE, "Varsayılana dönmeli")
	s2.apply_bindings()
	check(InputMap.action_get_events("pass_short").filter(func(e: InputEvent) -> bool: return e is InputEventKey)[0].physical_keycode == KEY_J, "Kayıtlı atama uygulanmalı")
	s.reset_bindings()


func test_event_serialization() -> void:
	var j := InputEventJoypadMotion.new()
	j.axis = JOY_AXIS_TRIGGER_RIGHT
	j.axis_value = 1.0
	var back := SettingsStore.dict_to_event(SettingsStore.event_to_dict(j))
	check(back is InputEventJoypadMotion and back.axis == JOY_AXIS_TRIGGER_RIGHT and back.axis_value > 0.0, "Eksen olayı korunmalı")
	check(SettingsStore.event_kind(j) == "gamepad", "Tür gamepad")


func test_shootout_rules() -> void:
	var r := ShootoutRules.new()
	for i in 3:
		r.record(0, true)
		r.record(1, false)
	check(r.is_decided() and r.winner() == 0, "3-0 sonrası (kalan 2 atış yetmez) seri biter")
	var r2 := ShootoutRules.new()
	for i in 5:
		r2.record(0, true)
		r2.record(1, true)
	check(not r2.is_decided(), "5-5 eşitlikte ani ölüme geçilir")
	r2.record(0, true)
	check(not r2.is_decided() and r2.next_team() == 1, "Ani ölümde eşit atış sayısına kadar devam")
	r2.record(1, false)
	check(r2.is_decided() and r2.winner() == 0, "Ani ölümde fark oluşunca biter")
	var r3 := ShootoutRules.new()
	for i in 4:
		r3.record(0, true)
		r3.record(1, true)
	r3.record(0, false)
	check(not r3.is_decided(), "4-4, A kaçırdı: B'nin son atışı bekleniyor")
	r3.record(1, true)
	check(r3.is_decided() and r3.winner() == 1, "B son atışla kazanır")


func test_screens_open() -> void:
	for path in SCREENS:
		var s: Control = load(path).instantiate()
		add_child(s)
		await get_tree().process_frame
		check(s.get_child_count() > 0, "%s içerik oluşturmalı" % path)
		s.queue_free()
		await get_tree().process_frame


func test_team_select_builds_config() -> void:
	var s: Control = load("res://scenes/ui/team_select.tscn").instantiate()
	add_child(s)
	await get_tree().process_frame
	var c: Dictionary = s.config()
	check(c.home in TeamData.team_ids() and c.away in TeamData.team_ids(), "Takım kimlikleri geçerli")
	check(float(c.half_minutes) >= 2.0 and float(c.half_minutes) <= 10.0, "Devre süresi 2-10")
	check(c.difficulty in ["easy", "medium", "hard"], "Zorluk geçerli")
	s.queue_free()


func test_pause_menu_pauses_tree() -> void:
	var m = preload("res://scenes/match.tscn").instantiate()
	m.human_team = -1
	m.replay_enabled = false
	add_child(m)
	await step_physics(5)
	m.pause_menu.open()
	check(get_tree().paused, "Duraklatma oyunu durdurmalı")
	var clock: float = m.flow.clock
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_equal_approx(m.flow.clock, clock), "Duraklatılmışken süre ilerlememeli")
	m.pause_menu.close()
	check(not get_tree().paused, "Devam oyunu sürdürmeli")
	await clear_children()


func test_penalty_shootout_ai_completes() -> void:
	var p = preload("res://scenes/penalty_shootout.tscn").instantiate()
	p.human_team = -1
	p.ai_kick_delay = 0.3
	p.result_pause = 0.3
	add_child(p)
	var done := [-1]
	p.finished.connect(func(w: int) -> void: done[0] = w)
	for i in 120 * 120:
		await get_tree().physics_frame
		if done[0] >= 0:
			break
	var r: ShootoutRules = p.rules
	print("       Penaltılar: %d - %d (%d+%d atış)" % [r.goals(0), r.goals(1), r.kicks_taken(0), r.kicks_taken(1)])
	check(done[0] >= 0, "Penaltı serisi bitmeli")
	check(r.goals(0) + r.goals(1) > 0, "En az bir gol olmalı")
	check(absi(r.kicks_taken(0) - r.kicks_taken(1)) <= 1, "Atışlar sırayla")
	await clear_children()


func test_training_mode_runs() -> void:
	var t = preload("res://scenes/training.tscn").instantiate()
	add_child(t)
	await step_physics(30)
	check(t.me.players.size() == 1 and t.keeper_team.players.size() == 1, "Antrenmanda 1 oyuncu + kaleci")
	check(t.possession.owner_player == t.player, "Top oyuncunun ayağında")
	t.player.start_shot_charge()
	await step_physics(80)
	t.player.release_shot(0.0)
	await step_physics(240)
	check(t.shots == 1, "Şut sayılmalı")
	await clear_children()
