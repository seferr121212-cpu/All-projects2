extends Control
## Ending card shown after the epilogue: ending title + description, each
## playable character's fate, play stats and gallery progress.
## Any confirm (advance / ui_accept / mouse) continues to the credits.

signal continued

const UiTheme = preload("res://ui/ui_theme.gd")
const MIN_SHOW_SEC := 1.2

var _header: Label
var _title: Label
var _desc: Label
var _fates: VBoxContainer
var _stats: Label
var _unlocked: Label
var _new: Label
var _hint: Label
var _shown_for := 0.0


func _ready() -> void:
	UiTheme.full_rect(self)
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.03, 1.0)
	UiTheme.full_rect(bg)
	add_child(bg)
	var margin := MarginContainer.new()
	UiTheme.full_rect(margin)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 220)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 110)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	margin.add_child(box)
	_header = UiTheme.make_label("endscreen.header", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	box.add_child(_header)
	_title = _dyn_label(UiTheme.FONT_TITLE, UiTheme.ACCENT)
	box.add_child(_title)
	_desc = _dyn_label(UiTheme.FONT_BODY, UiTheme.TEXT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(1200, 0)
	box.add_child(_desc)
	box.add_child(UiTheme.make_label("endscreen.fates", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM))
	_fates = VBoxContainer.new()
	box.add_child(_fates)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	_stats = _dyn_label(UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	box.add_child(_stats)
	var row := HBoxContainer.new()
	box.add_child(row)
	_unlocked = _dyn_label(UiTheme.FONT_SMALL, UiTheme.TEXT)
	row.add_child(_unlocked)
	_new = UiTheme.make_label("endscreen.new", UiTheme.FONT_SMALL, UiTheme.ACCENT)
	row.add_child(_new)
	_hint = _dyn_label(UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	box.add_child(_hint)


func _dyn_label(size: int, color: Color) -> Label:
	var l := UiTheme.make_label("", size, color)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return l


## ending: DecisionManager.ending_details(); is_new: first time this ending was reached.
func show_ending(ending: Dictionary, is_new: bool) -> void:
	_title.text = Localization.t(str(ending.get("title", "")))
	_desc.text = Localization.t(str(ending.get("description", "")))
	for c in _fates.get_children():
		_fates.remove_child(c)
		c.queue_free()
	for who: String in GameState.CHARACTERS:
		var l := _dyn_label(UiTheme.FONT_BODY, UiTheme.speaker_color(who))
		l.text = "%s  —  %s" % [Localization.t("char." + who), Localization.t("status." + GameState.get_status(who))]
		_fates.add_child(l)
	_stats.text = Localization.t("endscreen.stats", {
		"decisions": GameState.decisions.size(),
		"silences": GameState.get_counter("silence"),
		"time": format_time(GameState.play_time_sec)})
	_unlocked.text = Localization.t("endscreen.unlocked", {
		"n": SaveSystem.unlocked_endings().size(), "total": DecisionManager.ending_ids().size()})
	_new.visible = is_new
	_hint.text = Localization.t("endscreen.continue", {"button": InputRouter.prompt("advance")})
	_shown_for = 0.0
	modulate.a = 0.0
	visible = true
	create_tween().tween_property(self, "modulate:a", 1.0, 1.2)


static func format_time(sec: float) -> String:
	var total := int(sec)
	@warning_ignore("integer_division")
	return "%d:%02d" % [total / 3600, (total / 60) % 60]


func _process(delta: float) -> void:
	if visible:
		_shown_for += delta


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if _shown_for < MIN_SHOW_SEC:
		return  # don't skip the card with the button press that finished the epilogue
	if event.is_action_pressed("advance") or event.is_action_pressed("ui_accept") or event.is_action_pressed("pause"):
		visible = false
		continued.emit()
