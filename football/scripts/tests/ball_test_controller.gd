extends Node3D
## Top fiziği test sahnesi: klavyeyle farklı güç/açı/spin ile vuruş yapılır.

const PD = PitchDimensions
const HELP := "Space: vur | ↑↓ güç | ←→ yön | PgUp/PgDn yükseklik | Q/E yan falso | Z/X üst/alt falso\n1: yer pası  2: sert şut  3: falsolu frikik  4: lob | R: sıfırla | Sağ tık: kamera"

@export var kick_origin := Vector3(25.0, PD.BALL_RADIUS, 0.0)

var power := 25.0 # m/s
var yaw_deg := 0.0 # 0 = +X kalesine doğru, pozitif = sola (-Z)
var elev_deg := 10.0
var side_spin := 0.0 # rad/s (dikey eksen)
var top_spin := 0.0 # rad/s (+ üst falso, - alt falso)

var _label: Label
var _last_event := "-"
var _reset_timer := -1.0

@onready var ball: Ball = $Ball
@onready var events: MatchEvents = $MatchEvents


func _ready() -> void:
	var layer := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(12, 12)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_label)
	add_child(layer)
	events.event_detected.connect(_on_event)
	_reset_ball()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	match k.keycode:
		KEY_SPACE: _kick()
		KEY_UP: power = clampf(power + 1.0, 5.0, 35.0)
		KEY_DOWN: power = clampf(power - 1.0, 5.0, 35.0)
		KEY_LEFT: yaw_deg = clampf(yaw_deg + 1.0, -60.0, 60.0)
		KEY_RIGHT: yaw_deg = clampf(yaw_deg - 1.0, -60.0, 60.0)
		KEY_PAGEUP: elev_deg = clampf(elev_deg + 1.0, 0.0, 60.0)
		KEY_PAGEDOWN: elev_deg = clampf(elev_deg - 1.0, 0.0, 60.0)
		KEY_Q: side_spin = clampf(side_spin - 5.0, -80.0, 80.0)
		KEY_E: side_spin = clampf(side_spin + 5.0, -80.0, 80.0)
		KEY_Z: top_spin = clampf(top_spin - 5.0, -60.0, 60.0)
		KEY_X: top_spin = clampf(top_spin + 5.0, -60.0, 60.0)
		KEY_1: _preset(15.0, 0.0, 0.0, 0.0, 0.0)
		KEY_2: _preset(30.0, 0.0, 6.0, 0.0, 10.0)
		KEY_3: _preset(25.0, 8.0, 15.0, -50.0, 0.0)
		KEY_4: _preset(17.0, 0.0, 50.0, 0.0, -25.0)
		KEY_R: _reset_ball()


func _preset(p: float, y: float, e: float, s: float, t: float) -> void:
	power = p
	yaw_deg = y
	elev_deg = e
	side_spin = s
	top_spin = t
	_reset_ball()


func _kick() -> void:
	var yaw := deg_to_rad(yaw_deg)
	var el := deg_to_rad(elev_deg)
	var dir_h := Vector3(cos(yaw), 0.0, -sin(yaw))
	var dir := dir_h * cos(el) + Vector3.UP * sin(el)
	# Üst falso ekseni: top ileri yuvarlanır gibi döner (Magnus aşağı iter)
	var top_axis := Vector3.UP.cross(dir_h).normalized()
	var spin := Vector3.UP * side_spin + top_axis * top_spin
	events.restart_play()
	ball.kick(dir * power, spin, MatchEvents.HOME)


func _reset_ball() -> void:
	ball.reset_to(kick_origin)
	events.restart_play()
	_reset_timer = -1.0


func _on_event(ev: Dictionary) -> void:
	_last_event = MatchEvents.describe(ev)
	print("Olay: ", _last_event, " @ ", ev.position)
	_reset_timer = 2.5


func _process(delta: float) -> void:
	if _reset_timer > 0.0:
		_reset_timer -= delta
		if _reset_timer <= 0.0:
			_reset_ball()
	_label.text = "%s\n\nGüç: %.0f m/s  Yön: %.0f°  Yükseklik: %.0f°  Yan falso: %.0f  Üst falso: %.0f\nHız: %.1f m/s  Spin: %.1f rad/s  Yükseklik: %.2f m  %s\nSon olay: %s" % [
		HELP, power, yaw_deg, elev_deg, side_spin, top_spin,
		ball.linear_velocity.length(), ball.angular_velocity.length(), ball.global_position.y,
		"[FİLEDE]" if ball.is_in_net() else "", _last_event]
