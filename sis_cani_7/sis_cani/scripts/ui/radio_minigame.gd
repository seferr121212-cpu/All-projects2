class_name RadioMinigame
extends Control
## Telsiz tamiri: kadranı A/D ile çevir, sinyal en güçlüyken 1.2 sn tut.

signal done

var _dial := 0.1
var _target := 0.63
var _hold := 0.0
var _needle: ColorRect
var _bar: ProgressBar
var _t := 0.0
var _finished := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_target = randf_range(0.45, 0.85)
	add_child(UIKit.dim_bg(0.6))
	var panel := ColorRect.new()
	panel.color = Color(0.12, 0.1, 0.08, 0.95)
	panel.position = Vector2(560, 360)
	panel.size = Vector2(800, 340)
	add_child(panel)
	var title := UIKit.label(Loc.t("RADIO_TITLE"), 40, Color(1.0, 0.75, 0.45))
	title.position = Vector2(600, 380)
	add_child(title)
	var dial_bg := ColorRect.new()
	dial_bg.color = Color(0.85, 0.78, 0.6)
	dial_bg.position = Vector2(620, 480)
	dial_bg.size = Vector2(680, 60)
	add_child(dial_bg)
	for i in 21:
		var tick := ColorRect.new()
		tick.color = Color(0.2, 0.15, 0.1)
		tick.position = Vector2(620 + i * 34, 480)
		tick.size = Vector2(2, 20 if i % 5 else 34)
		add_child(tick)
	_needle = ColorRect.new()
	_needle.color = Color(0.7, 0.1, 0.05)
	_needle.size = Vector2(4, 70)
	add_child(_needle)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.position = Vector2(620, 570)
	_bar.size = Vector2(680, 18)
	_bar.max_value = 1.0
	add_child(_bar)
	var h := UIKit.label(Loc.t("RADIO_HINT"), 24)
	h.position = Vector2(620, 610)
	h.size = Vector2(700, 60)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(h)
	GameState.input_locked += 1


func _exit_tree() -> void:
	GameState.input_locked = maxi(0, GameState.input_locked - 1)


func _process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	var dir := Input.get_axis("move_left", "move_right")
	_dial = clampf(_dial + dir * 0.35 * delta, 0.0, 1.0)
	_needle.position = Vector2(620 + _dial * 680 - 2, 475)
	var strength := clampf(1.0 - absf(_dial - _target) * 6.0, 0.0, 1.0)
	_bar.value = strength
	if strength > 0.88:
		_hold += delta
		if _hold > 1.2:
			_finished = true
			AudioManager.play_sfx("pickup")
			done.emit()
			queue_free()
	else:
		_hold = 0.0
		if int(_t * 3.0) % 2 == 0 and randf() < 0.02:
			AudioManager.play_sfx("static", -20.0 + strength * 10.0)
