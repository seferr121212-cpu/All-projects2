extends Control
## Credits roll from data/credits.json. Scrolls by itself; hold advance /
## stick down to speed up, pause / cancel to skip. Emits finished once.

signal finished

const UiTheme = preload("res://ui/ui_theme.gd")
const CREDITS_PATH := "res://data/credits.json"
const SCROLL_SPEED := 70.0
const FAST_MULT := 5.0

var _roll: VBoxContainer
var _skip: Label
var _running := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiTheme.full_rect(self)
	clip_contents = true
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.03, 1.0)
	UiTheme.full_rect(bg)
	add_child(bg)
	_roll = VBoxContainer.new()
	_roll.add_theme_constant_override("separation", 18)
	_roll.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_roll)
	_skip = UiTheme.make_label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	_skip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.offset_left = -600
	_skip.offset_right = -60
	_skip.offset_top = -80
	_skip.offset_bottom = -40
	_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_skip)


static func load_sections() -> Array:
	var f := FileAccess.open(CREDITS_PATH, FileAccess.READ)
	if f == null:
		return []
	var data: Variant = JSON.parse_string(f.get_as_text())
	return data.get("sections", []) if typeof(data) == TYPE_DICTIONARY else []


## Names that look like locale keys ("credits.*") are translated; others are proper names.
static func display_name(name: String) -> String:
	return Localization.t(name) if name.begins_with("credits.") else name


func _centered(text: String, size: int, color: Color) -> Label:
	var l := UiTheme.make_label("", size, color)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1400, 0)
	return l


func start() -> void:
	for c in _roll.get_children():
		_roll.remove_child(c)
		c.queue_free()
	_roll.add_child(_centered(Localization.t("game.title"), UiTheme.FONT_TITLE, UiTheme.ACCENT))
	_roll.add_child(_centered(Localization.t("credits.title"), UiTheme.FONT_HEADING, UiTheme.TEXT))
	for sec: Dictionary in load_sections():
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 40)
		_roll.add_child(gap)
		var role := str(sec.get("role", ""))
		if role != "":
			_roll.add_child(_centered(Localization.t(role), UiTheme.FONT_SMALL, UiTheme.TEXT_DIM))
		for n: Variant in sec.get("names", []):
			_roll.add_child(_centered(display_name(str(n)), UiTheme.FONT_BODY, UiTheme.TEXT))
	_skip.text = Localization.t("credits.skip", {"button": InputRouter.prompt("pause")})
	var vp := get_viewport_rect().size
	_roll.size = Vector2(vp.x, 0)
	_roll.position = Vector2(0, vp.y)
	visible = true
	_running = true


func _process(delta: float) -> void:
	if not _running:
		return
	var speed := SCROLL_SPEED
	if Input.is_action_pressed("advance") or Input.is_action_pressed("ui_down") or Input.is_action_pressed("camera_down"):
		speed *= FAST_MULT
	_roll.position.y -= speed * delta
	if _roll.position.y + _roll.size.y < 0.0:
		_finish()


func _finish() -> void:
	if not _running:
		return
	_running = false
	visible = false
	SaveSystem.mark_credits_seen()
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_finish()
