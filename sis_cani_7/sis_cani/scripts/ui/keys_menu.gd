class_name KeysMenu
extends Control
## Tuş atama: bir eyleme tıkla, sonra yeni tuşa bas. Esc iptal.

var _listening := ""
var _buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _action_name(a: String) -> String:
	var names := {
		"move_left": ["Sola", "Left"], "move_right": ["Sağa", "Right"], "jump": ["Zıpla", "Jump"],
		"crouch": ["Eğil", "Crouch"], "run": ["Koş", "Run"], "interact": ["Etkileşim", "Interact"],
		"bell": ["El çanı", "Hand bell"], "red_glass": ["Kırmızı cam", "Red glass"], "journal": ["Günlük", "Journal"],
	}
	var pair: Array = names.get(a, [a, a])
	return str(pair[0 if Loc.lang == "tr" else 1])


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_buttons.clear()
	var box := UIKit.frame(self, Loc.t("UI_KEYS"), Vector2(1100, 900), true)
	for a in GameState.REBINDABLE:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 30)
		var l := UIKit.label(_action_name(a), 28)
		l.custom_minimum_size = Vector2(420, 0)
		h.add_child(l)
		var act: String = a
		var b := UIKit.button(OS.get_keycode_string(GameState.key_of(a)), func(): _listen(act))
		b.add_theme_font_size_override("font_size", 28)
		b.custom_minimum_size = Vector2(320, 46)
		h.add_child(b)
		_buttons[a] = b
		box.add_child(h)
	box.add_child(UIKit.button(Loc.t("UI_RESET_KEYS"), _reset))
	var back := UIKit.button(Loc.t("UI_BACK"), queue_free)
	box.add_child(back)
	back.grab_focus.call_deferred()


func _listen(a: String) -> void:
	_listening = a
	var b: Button = _buttons[a]
	b.text = Loc.t("UI_PRESS_KEY")


func _reset() -> void:
	GameState.reset_binds()
	_build.call_deferred()


func _input(event: InputEvent) -> void:
	if _listening == "":
		return
	var ke := event as InputEventKey
	if ke == null or not ke.pressed:
		return
	get_viewport().set_input_as_handled()
	var k: int = ke.physical_keycode
	if k != KEY_ESCAPE:
		GameState.set_bind(_listening, k)
	_listening = ""
	_build.call_deferred()
