extends Control
## Subtitles + timed choice diamond. Choice slots map to the gamepad face
## buttons / D-pad (top Y, right B, bottom A, left X), keys 1-4 / arrow keys,
## and mouse clicks. A shrinking bar shows the remaining time; when it runs
## out the runner commits the chapter's "silence" option.

const UiTheme = preload("res://ui/ui_theme.gd")
const CHOICE_ACTIONS: PackedStringArray = ["choice_1", "choice_2", "choice_3", "choice_4"]
## Diamond slot positions relative to the choice centre (top, right, bottom, left).
const SLOT_OFFSETS := [Vector2(0, -130), Vector2(380, 0), Vector2(0, 130), Vector2(-380, 0)]
## Which diamond slots are used for 2, 3 and 4 options.
const SLOT_LAYOUT := {1: [2], 2: [3, 1], 3: [3, 0, 1], 4: [0, 1, 2, 3]}
const INPUT_GRACE_SEC := 0.25
const CHAR_REVEAL_SEC := 0.012

var _subtitle: PanelContainer
var _speaker: Label
var _text: Label
var _advance_hint: Label
var _choice_root: Control
var _prompt: Label
var _major: Label
var _timer_bg: ColorRect
var _timer_bar: ColorRect
var _silence_hint: Label
var _toast: Label
var _slots: Array[Button] = []
var _slot_option: Array = [null, null, null, null]

var _line_speaker := ""
var _line_key := ""
var _choice_node: Dictionary = {}
var _choice_shown_at := 0.0
var _reveal_tween: Tween
var _mode := ""  # "", "line", "choice"


func _ready() -> void:
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_subtitle()
	_build_choices()
	_toast = UiTheme.make_label("", UiTheme.FONT_BODY, UiTheme.TEXT_DIM)
	_toast.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -700
	_toast.offset_right = 700
	_toast.offset_top = 80
	_toast.offset_bottom = 130
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	add_child(_toast)
	DialogueRunner.line_shown.connect(_on_line)
	DialogueRunner.choice_shown.connect(_on_choice)
	DialogueRunner.choice_resolved.connect(_on_choice_resolved)
	Localization.locale_changed.connect(_on_locale_changed)
	InputRouter.device_changed.connect(_on_device_changed)
	SaveSystem.settings_changed.connect(_apply_text_scale)
	_apply_text_scale()
	hide_all()


func _on_locale_changed(_locale: String) -> void:
	_retranslate()


func _on_device_changed(_pad: bool) -> void:
	_retranslate()


func _build_subtitle() -> void:
	_subtitle = PanelContainer.new()
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.offset_left = -760
	_subtitle.offset_right = 760
	_subtitle.offset_top = -280
	_subtitle.offset_bottom = -60
	_subtitle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_subtitle)
	var box := VBoxContainer.new()
	_subtitle.add_child(box)
	_speaker = UiTheme.make_label("", UiTheme.FONT_BODY)
	_speaker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_speaker)
	_text = UiTheme.make_label("")
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_text)
	_advance_hint = UiTheme.make_label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	_advance_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_advance_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_advance_hint)


func _build_choices() -> void:
	_choice_root = Control.new()
	_choice_root.set_anchors_preset(Control.PRESET_CENTER)
	_choice_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_choice_root)
	_prompt = UiTheme.make_label("", UiTheme.FONT_HEADING)
	_prompt.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-700, -330)
	_prompt.size = Vector2(1400, 60)
	_choice_root.add_child(_prompt)
	_major = UiTheme.make_label("dialogue.major", UiTheme.FONT_SMALL, UiTheme.ACCENT)
	_major.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_major.position = Vector2(-700, -380)
	_major.size = Vector2(1400, 40)
	_choice_root.add_child(_major)
	for i in 4:
		var b := Button.new()
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.focus_mode = Control.FOCUS_NONE  # selected directly by slot buttons
		b.custom_minimum_size = Vector2(560, 72)
		b.size = Vector2(560, 72)
		b.position = SLOT_OFFSETS[i] - b.size / 2.0
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(_pick_slot.bind(i))
		_choice_root.add_child(b)
		_slots.append(b)
	_timer_bg = ColorRect.new()
	_timer_bg.color = Color(1, 1, 1, 0.12)
	_timer_bg.position = Vector2(-500, 220)
	_timer_bg.size = Vector2(1000, 8)
	_choice_root.add_child(_timer_bg)
	_timer_bar = ColorRect.new()
	_timer_bar.color = UiTheme.ACCENT
	_timer_bar.position = _timer_bg.position
	_timer_bar.size = _timer_bg.size
	_choice_root.add_child(_timer_bar)
	_silence_hint = UiTheme.make_label("dialogue.silence_hint", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	_silence_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_silence_hint.position = Vector2(-700, 240)
	_silence_hint.size = Vector2(1400, 40)
	_choice_root.add_child(_silence_hint)


func _apply_text_scale() -> void:
	var s := float(SaveSystem.settings.get("subtitle_scale", 1.0))
	_text.add_theme_font_size_override("font_size", int(UiTheme.FONT_BODY * s))
	_speaker.add_theme_font_size_override("font_size", int(UiTheme.FONT_BODY * s))
	for b in _slots:
		b.add_theme_font_size_override("font_size", int(UiTheme.FONT_BODY * s))


func hide_all() -> void:
	_mode = ""
	_subtitle.visible = false
	_choice_root.visible = false
	set_process(false)


# --- Lines -----------------------------------------------------------------

func _on_line(speaker: String, text_key: String) -> void:
	_mode = "line"
	_line_speaker = speaker
	_line_key = text_key
	_choice_root.visible = false
	_subtitle.visible = true
	_retranslate()
	_text.visible_ratio = 0.0
	if _reveal_tween:
		_reveal_tween.kill()
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(_text, "visible_ratio", 1.0, clampf(_text.text.length() * CHAR_REVEAL_SEC, 0.15, 1.2))


func _retranslate() -> void:
	if _line_key != "":
		var is_narrator := _line_speaker == "narrator"
		_speaker.visible = not is_narrator
		_speaker.text = Localization.t("char." + _line_speaker)
		_speaker.add_theme_color_override("font_color", UiTheme.speaker_color(_line_speaker))
		_text.text = Localization.t(_line_key)
		_text.add_theme_color_override("font_color", UiTheme.TEXT_DIM if is_narrator else UiTheme.TEXT)
	_advance_hint.text = Localization.t("dialogue.advance", {"button": InputRouter.prompt("advance")})
	if _mode == "choice":
		_fill_choice_texts()


# --- Choices ---------------------------------------------------------------

func _on_choice(node: Dictionary, options: Array, time_limit: float) -> void:
	_mode = "choice"
	_choice_node = node
	_choice_shown_at = Time.get_ticks_msec() / 1000.0
	_slot_option = [null, null, null, null]
	var layout: Array = SLOT_LAYOUT.get(clampi(options.size(), 1, 4), [0, 1, 2, 3])
	for i in mini(options.size(), 4):
		_slot_option[layout[i]] = options[i]
	_choice_root.visible = true
	_major.visible = bool(node.get("major", false))
	var timed := time_limit > 0.0
	_timer_bg.visible = timed
	_timer_bar.visible = timed
	_silence_hint.visible = timed and node.has("timeout")
	_fill_choice_texts()
	set_process(timed)


func _fill_choice_texts() -> void:
	_prompt.text = Localization.t(str(_choice_node.get("prompt", ""))) if _choice_node.has("prompt") else ""
	for i in 4:
		var opt: Variant = _slot_option[i]
		_slots[i].visible = opt != null
		if opt != null:
			_slots[i].text = "%s   %s" % [InputRouter.prompt(CHOICE_ACTIONS[i]), Localization.t(str(opt.get("text", "")))]


func _process(_delta: float) -> void:
	if _mode != "choice" or DialogueRunner.choice_time_total <= 0.0:
		return
	var ratio := clampf(DialogueRunner.choice_time_left / DialogueRunner.choice_time_total, 0.0, 1.0)
	_timer_bar.size.x = _timer_bg.size.x * ratio
	_timer_bar.position.x = _timer_bg.position.x + (_timer_bg.size.x - _timer_bar.size.x) / 2.0
	_timer_bar.color = UiTheme.ACCENT.lerp(Color(0.9, 0.25, 0.2), 1.0 - ratio)


func _pick_slot(slot: int) -> void:
	if _mode != "choice" or _slot_option[slot] == null:
		return
	AudioBus.play("ui/select")
	DialogueRunner.choose(str(_slot_option[slot]["id"]))


func _on_choice_resolved(_option_id: String, timed_out: bool) -> void:
	_choice_root.visible = false
	set_process(false)
	if _mode == "choice":
		_mode = ""
	if timed_out:
		show_toast("dialogue.silence_result")


func show_toast(key: String) -> void:
	_toast.text = Localization.t(key)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _unhandled_input(event: InputEvent) -> void:
	if _mode == "choice":
		if Time.get_ticks_msec() / 1000.0 - _choice_shown_at < INPUT_GRACE_SEC:
			return
		for i in 4:
			if event.is_action_pressed(CHOICE_ACTIONS[i]) and _slot_option[i] != null:
				get_viewport().set_input_as_handled()
				_pick_slot(i)
				return
	elif _mode == "line" and event.is_action_pressed("advance"):
		get_viewport().set_input_as_handled()
		if _text.visible_ratio < 1.0:
			if _reveal_tween:
				_reveal_tween.kill()
			_text.visible_ratio = 1.0
		else:
			_mode = ""
			DialogueRunner.advance()
