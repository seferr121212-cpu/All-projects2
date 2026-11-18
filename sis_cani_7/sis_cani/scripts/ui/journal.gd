class_name Journal
extends Control
## Günlük: bulunan sayfalar ve bantlar.

var _text: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dim_bg(0.97))
	var title := UIKit.label(Loc.t("UI_JOURNAL") + "  (%d/12)" % GameState.pages.size(), 54, Color(1.0, 0.75, 0.45))
	title.position = Vector2(160, 90)
	add_child(title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(160, 190)
	scroll.size = Vector2(520, 820)
	add_child(scroll)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	var paper := ColorRect.new()
	paper.position = Vector2(720, 150)
	paper.size = Vector2(1080, 800)
	paper.color = Color(0.84, 0.79, 0.68)
	paper.rotation = deg_to_rad(-0.8)
	add_child(paper)
	var edge := ColorRect.new()
	edge.position = Vector2(0, 0)
	edge.size = Vector2(1080, 6)
	edge.color = Color(0.6, 0.52, 0.4)
	paper.add_child(edge)
	for i in 18:
		var ln := ColorRect.new()
		ln.position = Vector2(40, 90 + i * 38)
		ln.size = Vector2(1000, 2)
		ln.color = Color(0.55, 0.62, 0.7, 0.35)
		paper.add_child(ln)
	_text = UIKit.label("", 32, Color(0.16, 0.13, 0.12))
	var italic = load("res://fonts/Lora-Italic.ttf")
	if italic:
		_text.add_theme_font_override("font", italic)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.position = Vector2(60, 50)
	_text.size = Vector2(960, 700)
	_text.add_theme_constant_override("line_spacing", 8)
	paper.add_child(_text)
	var first: Button = null
	_section(list, Loc.t("UI_PAGES"))
	for i in range(1, 13):
		var id := "P%02d" % i
		if id in GameState.pages:
			var b := UIKit.button(Loc.t("UI_PAGE") + " %d" % i, func(): _text.text = Loc.t(id))
			b.add_theme_font_size_override("font_size", 28)
			list.add_child(b)
			if first == null:
				first = b
	_section(list, Loc.t("UI_LETTERS"))
	for i in range(1, 7):
		var lid := "L%02d" % i
		if lid in GameState.letters:
			var b3 := UIKit.button(Loc.t("UI_LETTER") + " %d" % i, func(): _text.text = Loc.t(lid))
			b3.add_theme_font_size_override("font_size", 28)
			list.add_child(b3)
			if first == null:
				first = b3
	_section(list, Loc.t("UI_BESTIARY"))
	for kind in ["CRAWLER", "MIMIC", "WATCHER", "WHISPER", "GREAT"]:
		var k: String = kind
		var known: bool = k in GameState.seen
		var b4 := UIKit.button(Loc.t("BEST_" + k) if known else "???", func(): _text.text = (Loc.t("BEST_" + k) + "\n\n" + Loc.t("BEST_" + k + "_D")) if known else Loc.t("UI_UNKNOWN"))
		b4.add_theme_font_size_override("font_size", 28)
		list.add_child(b4)
	_section(list, Loc.t("UI_TAPES"))
	var tape_keys := {"H01": ["C2_031", "C2_032"], "H02": ["C2_040", "C2_041"], "H03": ["C2_050", "C2_051"]}
	for t in ["H01", "H02", "H03"]:
		if t in GameState.tapes:
			var keys: Array = tape_keys[t]
			var b2 := UIKit.button(Loc.t("UI_TAPE") + " " + t, func(): _text.text = Loc.t(keys[0]) + "\n\n" + Loc.t(keys[1]))
			b2.add_theme_font_size_override("font_size", 28)
			list.add_child(b2)
			if first == null:
				first = b2
	if first == null:
		_text.text = Loc.t("UI_JOURNAL_EMPTY")
	else:
		first.grab_focus.call_deferred()
		first.pressed.emit()
	var hint := UIKit.label(Loc.t("UI_CLOSE"), 22, Color(1, 1, 1, 0.5))
	hint.position = Vector2(160, 1000)
	add_child(hint)


func _section(list: VBoxContainer, title: String) -> void:
	var l := UIKit.label(title, 24, Color(1.0, 0.72, 0.42, 0.8))
	list.add_child(l)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if get_parent() is PauseMenu:
			queue_free()
		else:
			get_tree().paused = false
			queue_free()
