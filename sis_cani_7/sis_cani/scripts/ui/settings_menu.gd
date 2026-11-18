class_name SettingsMenu
extends Control
## Ayarlar: dil, seslendirme dili, altyazı, ses seviyeleri.

signal closed


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var box := UIKit.frame(self, Loc.t("UI_SETTINGS"), Vector2(1280, 960), true)
	var s: Dictionary = GameState.settings
	box.add_child(_row(Loc.t("UI_LANGUAGE"), UIKit.button(Loc.t("UI_LANG_NAME"), _toggle_lang)))
	var vname := "Türkçe" if s["voice_lang"] == "tr" else "English"
	box.add_child(_row(Loc.t("UI_VOICE_LANG"), UIKit.button(vname, _toggle_voice)))
	var subs := Loc.t("UI_ON") if bool(s["subtitles"]) else Loc.t("UI_OFF")
	box.add_child(_row(Loc.t("UI_SUBTITLES"), UIKit.button(subs, _toggle_subs)))
	var fsn := Loc.t("UI_ON") if bool(s.get("fullscreen", false)) else Loc.t("UI_OFF")
	box.add_child(_row(Loc.t("UI_FULLSCREEN"), UIKit.button(fsn, _toggle_fullscreen)))
	var wins := ["1280×720", "1600×900", "1920×1080"]
	box.add_child(_row(Loc.t("UI_WINDOW"), UIKit.button(wins[clampi(int(s.get("window", 1)), 0, 2)], _cycle_window)))
	var shk := Loc.t("UI_ON") if bool(s.get("shake", true)) else Loc.t("UI_OFF")
	box.add_child(_row(Loc.t("UI_SHAKE"), UIKit.button(shk, _toggle_shake)))
	var sizes := ["UI_SIZE_S", "UI_SIZE_M", "UI_SIZE_L"]
	box.add_child(_row(Loc.t("UI_SUB_SIZE"), UIKit.button(Loc.t(sizes[clampi(int(s.get("sub_size", 1)), 0, 2)]), _cycle_sub)))
	box.add_child(_row(Loc.t("UI_VOLUME_MASTER"), UIKit.slider(float(s.get("master", 1.0)), func(v): _vol("master", v))))
	var diffs := ["UI_DIFF_0", "UI_DIFF_1", "UI_DIFF_2"]
	box.add_child(_row(Loc.t("UI_DIFFICULTY"), UIKit.button(Loc.t(diffs[clampi(int(s.get("difficulty", 1)), 0, 2)]), _cycle_diff)))
	box.add_child(_row(Loc.t("UI_TIMER"), UIKit.button(_onoff(s.get("timer", false)), func(): _toggle("timer", false))))
	box.add_child(_row(Loc.t("UI_CAPTIONS"), UIKit.button(_onoff(s.get("captions", true)), func(): _toggle("captions", true))))
	box.add_child(_row(Loc.t("UI_VSYNC"), UIKit.button(_onoff(s.get("vsync", true)), func(): _toggle("vsync", true))))
	var fps := int(s.get("max_fps", 0))
	box.add_child(_row(Loc.t("UI_MAXFPS"), UIKit.button(Loc.t("UI_UNLIMITED") if fps == 0 else str(fps), _cycle_fps)))
	box.add_child(_row(Loc.t("UI_KEYS"), UIKit.button("→", func(): add_child(KeysMenu.new()))))
	var fx := Loc.t("UI_ON") if bool(s.get("postfx", true)) else Loc.t("UI_OFF")
	box.add_child(_row(Loc.t("UI_POSTFX"), UIKit.button(fx, _toggle_fx)))
	box.add_child(_row(Loc.t("UI_VOLUME_MUSIC"), UIKit.slider(float(s["music"]), func(v): _vol("music", v))))
	box.add_child(_row(Loc.t("UI_VOLUME_SFX"), UIKit.slider(float(s["sfx"]), func(v): _vol("sfx", v))))
	box.add_child(_row(Loc.t("UI_VOLUME_VOICE"), UIKit.slider(float(s["voice"]), func(v): _vol("voice", v))))
	var back := UIKit.button(Loc.t("UI_BACK"), _close)
	box.add_child(back)
	back.grab_focus.call_deferred()


func _toggle_lang() -> void:
	GameState.settings["lang"] = "en" if GameState.settings["lang"] == "tr" else "tr"
	_apply()


func _toggle_voice() -> void:
	GameState.settings["voice_lang"] = "en" if GameState.settings["voice_lang"] == "tr" else "tr"
	_apply()


func _toggle_subs() -> void:
	GameState.settings["subtitles"] = not bool(GameState.settings["subtitles"])
	_apply()


func _onoff(v) -> String:
	return Loc.t("UI_ON") if bool(v) else Loc.t("UI_OFF")


func _toggle(key: String, default: bool) -> void:
	GameState.settings[key] = not bool(GameState.settings.get(key, default))
	_apply()


func _cycle_diff() -> void:
	GameState.settings["difficulty"] = (int(GameState.settings.get("difficulty", 1)) + 1) % 3
	_apply()


func _cycle_fps() -> void:
	var opts := [0, 30, 60, 120, 144]
	var i := opts.find(int(GameState.settings.get("max_fps", 0)))
	GameState.settings["max_fps"] = opts[(i + 1) % opts.size()]
	_apply()


func _cycle_window() -> void:
	GameState.settings["window"] = (int(GameState.settings.get("window", 1)) + 1) % 3
	_apply()


func _toggle_fullscreen() -> void:
	GameState.settings["fullscreen"] = not bool(GameState.settings.get("fullscreen", false))
	_apply()


func _toggle_shake() -> void:
	GameState.settings["shake"] = not bool(GameState.settings.get("shake", true))
	_apply()


func _cycle_sub() -> void:
	GameState.settings["sub_size"] = (int(GameState.settings.get("sub_size", 1)) + 1) % 3
	_apply()


func _toggle_fx() -> void:
	GameState.settings["postfx"] = not bool(GameState.settings.get("postfx", true))
	if GameState.level and GameState.level.postfx:
		GameState.level.postfx.visible = bool(GameState.settings["postfx"])
	_apply()


func _close() -> void:
	closed.emit()
	queue_free()


func _row(title: String, ctrl: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	h.custom_minimum_size = Vector2(0, 54)
	var l := UIKit.label(title, 28)
	l.custom_minimum_size = Vector2(560, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	if ctrl is Button:
		ctrl.add_theme_font_size_override("font_size", 30)
		ctrl.custom_minimum_size = Vector2(300, 48)
	ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ctrl)
	return h


func _vol(key: String, v: float) -> void:
	GameState.settings[key] = v
	GameState.save_settings()
	AudioManager.apply_volumes()


func _apply() -> void:
	GameState.save_settings()
	GameState.apply_settings()
	_build.call_deferred()
