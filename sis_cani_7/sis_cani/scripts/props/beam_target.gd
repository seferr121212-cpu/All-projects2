class_name BeamTarget
extends Node2D
## Huzme hedefi. "lens": huzmeyi geçirir ve odaklar. "seal": balmumu mühür, odaklı huzmeyle 1.5 sn'de erir.

signal triggered

var kind := "lens"
var id := ""
var beam_radius := 30.0
var passes_beam := false
var focuses := false
var done := false
var _progress := 0.0
var _poly: Sprite2D


func _ready() -> void:
	if kind == "lens":
		passes_beam = true
		focuses = true
		var l := Art.sprite_c("props/lens.png")
		l.position = Vector2(0, 38)
		add_child(l)
		_poly = Art.sprite_c("props/seal.png")
		_poly.visible = false
	else:
		_poly = Art.sprite_c("props/seal.png")
	add_child(_poly)
	if id != "" and GameState.flag("bt_" + id):
		done = true
		if kind == "seal":
			_poly.visible = false
	if not (kind == "seal" and done):
		add_to_group("beam_target")


func beam_center() -> Vector2:
	return global_position


func beam_hit(focused: bool, delta: float, _red: bool) -> void:
	if kind != "seal" or done:
		return
	if focused:
		_progress += delta
		_poly.modulate = Color(1, 1, 1).lerp(Color(2.0, 1.4, 0.6), clampf(_progress / 1.5, 0.0, 1.0))
		if _progress >= 1.5:
			done = true
			if id != "":
				GameState.set_flag("bt_" + id)
			remove_from_group("beam_target")
			AudioManager.play_sfx("ignite", -2.0, 1.4)
			var tw := create_tween()
			tw.tween_property(_poly, "modulate:a", 0.0, 0.6)
			triggered.emit()
