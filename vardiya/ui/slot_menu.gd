extends PanelContainer
## Save slot picker. Mode "new": pick a slot for a new game (confirm overwrite).
## Mode "load": pick a slot, then continue or replay from a chapter start.

signal closed
signal start_new(slot: int)
signal continue_slot(slot: int)
signal replay_chapter(slot: int, chapter_id: String)

const UiTheme = preload("res://ui/ui_theme.gd")
const ConfirmPanel = preload("res://ui/confirm_panel.gd")

var mode := "load"
var _box: VBoxContainer
var _title: Label
var _confirm: ConfirmPanel
var _selected_slot := -1
var _pending_action: Callable


func _ready() -> void:
	_box = VBoxContainer.new()
	add_child(_box)
	_confirm = ConfirmPanel.new()
	_confirm.answered.connect(_on_confirm)
	# The confirm overlay must cover the whole screen: parent it to the scene root.
	_attach_confirm.call_deferred()


func _attach_confirm() -> void:
	var root := get_tree().current_scene
	(root if root != null else get_parent()).add_child(_confirm)


func open(open_mode: String) -> void:
	mode = open_mode
	visible = true
	_show_slots()


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func _format_time(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d" % [s / 3600, (s / 60) % 60]


func _show_slots() -> void:
	_clear()
	_selected_slot = -1
	_box.add_child(UiTheme.make_label("slot.title_new" if mode == "new" else "slot.title_load", UiTheme.FONT_HEADING))
	var buttons: Array = []
	for i in SaveSystem.SLOT_COUNT:
		var meta := SaveSystem.read_meta(i)
		var b := UiTheme.make_button("", 1000)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var head := Localization.t("slot.label", {"n": i + 1})
		if meta.is_empty():
			b.text = "%s  -  %s" % [head, Localization.t("slot.empty")]
			b.disabled = mode == "load"
		else:
			var info: Dictionary = SaveSystem.chapter_info(str(meta["chapter"]))
			b.text = "%s  -  %s  -  %s" % [head, Localization.t(str(info.get("title", meta["chapter"]))),
				_format_time(float(meta["play_time_sec"]))]
		b.pressed.connect(_on_slot_pressed.bind(i, meta.is_empty()))
		_box.add_child(b)
		buttons.append(b)
	var back := UiTheme.make_button("menu.back", 1000)
	back.pressed.connect(_close)
	_box.add_child(back)
	buttons.append(back)
	UiTheme.chain_focus(buttons)
	for b: Button in buttons:
		if not b.disabled:
			b.grab_focus()
			break


func _on_slot_pressed(slot: int, empty: bool) -> void:
	AudioBus.play("ui/select")
	_selected_slot = slot
	if mode == "new":
		if empty:
			start_new.emit(slot)
		else:
			_pending_action = func() -> void: start_new.emit(slot)
			_confirm.ask("slot.overwrite_confirm")
	elif not empty:
		_show_slot_actions(slot)


func _show_slot_actions(slot: int) -> void:
	_clear()
	_box.add_child(UiTheme.make_label(Localization.t("slot.label", {"n": slot + 1}), UiTheme.FONT_HEADING))
	var buttons: Array = []
	var cont := UiTheme.make_button("slot.continue", 1000)
	cont.pressed.connect(func() -> void: continue_slot.emit(slot))
	buttons.append(cont)
	var meta := SaveSystem.read_meta(slot)
	_box.add_child(cont)
	_box.add_child(UiTheme.make_label("slot.chapters", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM))
	for c: Dictionary in SaveSystem.chapter_order:
		if not c["id"] in meta.get("chapters", []):
			continue
		var b := UiTheme.make_button(str(c["title"]), 1000)
		var cid: String = c["id"]
		b.pressed.connect(func() -> void:
			_pending_action = func() -> void: replay_chapter.emit(slot, cid)
			_confirm.ask("slot.replay_confirm"))
		_box.add_child(b)
		buttons.append(b)
	var del := UiTheme.make_button("slot.delete", 1000)
	del.pressed.connect(func() -> void:
		_pending_action = func() -> void:
			SaveSystem.delete_slot(slot)
			_show_slots()
		_confirm.ask("slot.delete_confirm"))
	_box.add_child(del)
	buttons.append(del)
	var back := UiTheme.make_button("menu.back", 1000)
	back.pressed.connect(_show_slots)
	_box.add_child(back)
	buttons.append(back)
	UiTheme.chain_focus(buttons)
	cont.grab_focus()


func _on_confirm(yes: bool) -> void:
	if yes and _pending_action.is_valid():
		_pending_action.call()
	elif visible:
		# Return focus into this panel.
		for c in _box.get_children():
			if c is Button and not (c as Button).disabled:
				(c as Button).grab_focus()
				break


func _close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _confirm.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _selected_slot >= 0 and mode == "load":
			_show_slots()
		else:
			_close()
