extends Control
## Exploration HUD: objective, interaction prompt above the focused item,
## "added to journal" toast and the journal button hint.

const UiTheme = preload("res://ui/ui_theme.gd")
const WorldView = preload("res://scenes/world/world_view.gd")

var world: WorldView
var _objective_box: VBoxContainer
var _objective: Label
var _prompt: Label
var _toast: Label
var _journal_hint: Label
var _objective_key := ""
var _focus: Dictionary = {}


func _ready() -> void:
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_box = VBoxContainer.new()
	_objective_box.position = Vector2(80, 70)
	add_child(_objective_box)
	_objective_box.add_child(UiTheme.make_label("hud.objective", UiTheme.FONT_SMALL, UiTheme.ACCENT))
	_objective = UiTheme.make_label("", UiTheme.FONT_BODY)
	_objective.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_objective_box.add_child(_objective)
	_prompt = UiTheme.make_label("", UiTheme.FONT_BODY)
	_prompt.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 8)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(700, 50)
	add_child(_prompt)
	_toast = UiTheme.make_label("", UiTheme.FONT_SMALL, UiTheme.ACCENT)
	_toast.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_toast.position = Vector2(80, 190)
	_toast.modulate.a = 0.0
	add_child(_toast)
	_journal_hint = UiTheme.make_label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	_journal_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_journal_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_journal_hint.offset_left = -600
	_journal_hint.offset_right = -60
	_journal_hint.offset_top = -80
	_journal_hint.offset_bottom = -40
	_journal_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_journal_hint)
	Localization.locale_changed.connect(_on_locale_changed)
	InputRouter.device_changed.connect(_on_device_changed)
	hide_explore()


func _on_locale_changed(_locale: String) -> void:
	_refresh_text()


func _on_device_changed(_pad: bool) -> void:
	_refresh_text()


func show_explore(objective_key: String) -> void:
	_objective_key = objective_key
	_objective_box.visible = objective_key != ""
	_journal_hint.visible = true
	_refresh_text()
	set_process(true)


func hide_explore() -> void:
	_objective_box.visible = false
	_journal_hint.visible = false
	_prompt.visible = false
	set_process(false)


func set_focus(item: Dictionary) -> void:
	_focus = item
	_refresh_text()


func _refresh_text() -> void:
	_objective.text = Localization.t(_objective_key) if _objective_key != "" else ""
	_journal_hint.text = Localization.t("hud.journal_hint", {"button": InputRouter.prompt("journal")})
	if not _focus.is_empty():
		var label := Localization.t(str(_focus.get("label", "")))
		var mark := "  *" if not bool(_focus.get("found", false)) else ""
		_prompt.text = "%s  %s%s" % [InputRouter.prompt("interact"), label, mark]


func show_note(journal_key: String) -> void:
	if journal_key == "":
		return
	_toast.text = Localization.t("hud.journal_added", {"note": Localization.t(journal_key)})
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _process(_delta: float) -> void:
	var pos: Variant = world.focused_screen_pos() if world and not _focus.is_empty() else null
	_prompt.visible = pos != null
	if pos != null:
		_prompt.position = (pos as Vector2) - Vector2(_prompt.size.x / 2.0, _prompt.size.y)
