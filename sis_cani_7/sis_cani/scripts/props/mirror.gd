class_name Mirror
extends Interactable
## Döner ayna. Yükseltilmiş lamba huzmesini yansıtır. [E] ile 45° döner.
## Açı: -45 = "/" (sağdan geleni yukarı, aşağıdan geleni sağa çevirir), 45 = "\".

var angle_deg := 0.0
var rotatable := true
var length := 120.0
var stand_height := 60.0
var _glass: Line2D
var _frame: Line2D


func _ready() -> void:
	super()
	prompt = "INT_MIRROR"
	radius = 90.0
	add_to_group("mirror")
	if stand_height > 0.0:
		var st := Art.sprite("props/mirror_stand.png")
		st.position.y += stand_height
		add_child(st)
	else:
		var chain := Line2D.new()
		chain.points = PackedVector2Array([Vector2(0, -400), Vector2(0, -20)])
		chain.width = 3.0
		chain.default_color = Color(0.2, 0.2, 0.22)
		add_child(chain)
	_glass = Line2D.new()
	_glass.z_index = 1
	_glass.width = 7.0
	_glass.default_color = Color(0.75, 0.85, 0.95)
	_glass.begin_cap_mode = Line2D.LINE_CAP_BOX
	_glass.end_cap_mode = Line2D.LINE_CAP_BOX
	var frame := Line2D.new()
	frame.width = 11.0
	frame.default_color = Color(0.16, 0.13, 0.1)
	_frame = frame
	add_child(frame)
	add_child(_glass)
	_update_visual()


func can_interact(p) -> bool:
	return rotatable and super(p)


func interact(p) -> void:
	angle_deg = fmod(angle_deg + 45.0, 180.0)
	AudioManager.play_sfx("click")
	AudioManager.play_at("creak", global_position, -8.0, randf_range(0.9, 1.1))
	_update_visual()
	super(p)


func _update_visual() -> void:
	var d := Vector2.RIGHT.rotated(deg_to_rad(angle_deg)) * length * 0.5
	_glass.points = PackedVector2Array([-d, d])
	_frame.points = PackedVector2Array([-d * 1.05, d * 1.05])


func get_segment() -> Array:
	var d := Vector2.RIGHT.rotated(deg_to_rad(angle_deg)) * length * 0.5
	return [global_position - d, global_position + d]
