class_name MiniGameActivity
extends Activity
## A sit-down job done in a small panel: walk to the work spot, press E, play
## a short skill game (no failure; the score only changes the pay), then
## report back to the NPC. Flags: "<npc>.<id>.on" while the job is open,
## "<npc>.<id>.done" once the game is finished. Subclasses override the
## _game_* hooks.

@export var npc_id: StringName = &""
@export var prompt_key: String = "ACT_START_WORK"
@export var title_key: String = ""
@export var help_key: String = ""
@export var base_pay: int = 30
@export var spot_offset: Vector3 = Vector3(0, 1.0, 0)
@export var snap_to_ground: bool = true

var score: float = 0.0
var playing: bool = false
var _spot := Interactable.new()
var _ui: CanvasLayer
var canvas: Control
var hint: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	add_to_group(&"save_participant")
	_rng.randomize()
	_spot.prompt_key = prompt_key
	_spot.distance = 3.0
	_spot.enabled = false
	_spot.position = spot_offset
	_spot.interacted.connect(func(_by: Node3D) -> void: open_game())
	add_child(_spot)
	_build_ui()
	if snap_to_ground:
		_snap.call_deferred()


func _snap() -> void:
	if GameState.current_region:
		global_position.y = GameState.current_region.get_ground_height(global_position.x, global_position.z)


func flag_on() -> String:
	return "%s.%s.on" % [npc_id, activity_id]


func flag_done() -> String:
	return "%s.%s.done" % [npc_id, activity_id]


func begin() -> void:
	if active:
		return
	super.begin()
	score = 0.0
	GameState.set_flag(flag_on())
	GameState.set_flag(flag_done(), false)
	_spot.enabled = true
	if not SaveManager.is_loading:
		GameState.notify(tr(StringName(title_key)) + " — " + tr(&"ACT_GO_TO_SPOT"))


func complete() -> int:
	var done: bool = GameState.has_flag(flag_done())
	var pay: int = roundi(base_pay * (0.6 + score * 0.8)) if done else 0
	if pay > 0:
		GameState.add_money(pay)
		GameState.add_relationship(npc_id, ECONOMY.points_job_done)
	var key: String = "%s.%s.count" % [npc_id, activity_id]
	GameState.set_counter(key, GameState.get_counter(key) + 1)
	_clear_flags()
	active = false
	finished.emit(pay)
	return pay


func cancel() -> void:
	if not active:
		return
	if playing:
		close_game()
	_clear_flags()
	active = false


func _clear_flags() -> void:
	GameState.set_flag(flag_on(), false)
	GameState.set_flag(flag_done(), false)
	_spot.enabled = false


func get_status_text() -> String:
	if not active:
		return ""
	if GameState.has_flag(flag_done()):
		return tr(&"ACT_REPORT_BACK")
	return tr(StringName(title_key))


func open_game() -> void:
	if not active or playing or GameState.has_flag(flag_done()) or not GameState.is_gameplay():
		return
	playing = true
	GameState.set_context(GameState.Context.MENU)
	var travel := get_tree().get_first_node_in_group(&"travel") as TravelController
	if travel:
		travel.suspend_control()
	hint.text = tr(StringName(help_key))
	_game_start()
	_ui.visible = true


func close_game() -> void:
	playing = false
	_ui.visible = false
	GameState.set_context(GameState.Context.GAMEPLAY)
	var travel := get_tree().get_first_node_in_group(&"travel") as TravelController
	if travel:
		travel.restore_control()


## Called by subclasses when the game is over; score 0..1.
func finish_game(result: float) -> void:
	score = clampf(result, 0.0, 1.0)
	GameState.set_flag(flag_done())
	close_game()
	GameState.notify(tr(&"ACT_JOB_FINISHED") % roundi(score * 100.0))
	_on_finished()


func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event.is_action_pressed(&"pause"):
		close_game()
		get_viewport().set_input_as_handled()
		return
	if _game_input(event):
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if playing:
		_game_process(delta)
		canvas.queue_redraw()


## True for "the main button" on keyboard, mouse and gamepad.
static func is_press(event: InputEvent) -> bool:
	return event.is_action_pressed(&"interact") or event.is_action_pressed(&"handbrake") or event.is_action_pressed(&"ui_accept") \
			or (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)


static func is_release(event: InputEvent) -> bool:
	return event.is_action_released(&"interact") or event.is_action_released(&"handbrake") or event.is_action_released(&"ui_accept") \
			or (event is InputEventMouseButton and not event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)


# --- Hooks ---------------------------------------------------------------

func _game_start() -> void:
	pass


func _game_input(_event: InputEvent) -> bool:
	return false


func _game_process(_delta: float) -> void:
	pass


func _game_draw(_c: Control) -> void:
	pass


## Extra world feedback after a finished game (e.g. a pot appears).
func _on_finished() -> void:
	pass


# --- Save ----------------------------------------------------------------

func save_key() -> String:
	return String(activity_id)


func to_save() -> Dictionary:
	return {"active": active, "done": GameState.has_flag(flag_done()), "score": score}


func from_save(data: Dictionary) -> void:
	active = false
	_spot.enabled = false
	if data.get("active", false):
		begin()
		score = float(data.get("score", 0.0))
		if data.get("done", false):
			GameState.set_flag(flag_done())
			_on_finished()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 14
	_ui.visible = false
	add_child(_ui)
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.97, 0.94, 0.88, 0.96)
	st.set_corner_radius_all(12)
	st.set_content_margin_all(18)
	st.shadow_color = Color(0, 0, 0, 0.25)
	st.shadow_size = 10
	panel.add_theme_stylebox_override(&"panel", st)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -270
	panel.offset_bottom = 250
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	var title := Label.new()
	title.text = title_key
	title.add_theme_font_size_override(&"font_size", 24)
	title.add_theme_color_override(&"font_color", Color(0.45, 0.25, 0.15))
	col.add_child(title)
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(720, 380)
	canvas.clip_contents = true
	canvas.draw.connect(func() -> void: _game_draw(canvas))
	col.add_child(canvas)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override(&"font_color", Color(0.3, 0.25, 0.2))
	col.add_child(hint)
	panel.add_child(col)
	_ui.add_child(panel)
