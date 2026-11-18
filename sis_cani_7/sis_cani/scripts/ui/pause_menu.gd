class_name PauseMenu
extends Control
## Duraklatma menüsü.

var _main


func setup(main) -> PauseMenu:
	_main = main
	return self


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var blur := ColorRect.new()
	blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shaders/blur.gdshader")
	blur.material = bm
	add_child(blur)
	var box := UIKit.frame(self, Loc.t("UI_PAUSED"), Vector2(760, 640), false, 0.45)
	var r := UIKit.button(Loc.t("UI_RESUME"), close)
	box.add_child(r)
	box.add_child(UIKit.button(Loc.t("UI_LAST_BRAZIER"), _last_brazier))
	box.add_child(UIKit.button(Loc.t("UI_JOURNAL"), func(): add_child(Journal.new())))
	box.add_child(UIKit.button(Loc.t("UI_SETTINGS"), func(): add_child(SettingsMenu.new())))
	box.add_child(UIKit.button(Loc.t("UI_MAIN_MENU"), _to_menu))
	r.grab_focus.call_deferred()


func _last_brazier() -> void:
	close()
	if GameState.player:
		GameState.player.caught()


func _to_menu() -> void:
	get_tree().paused = false
	queue_free()
	_main.show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	get_tree().paused = false
	queue_free()
