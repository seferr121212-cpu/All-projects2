class_name HumanInputController
extends Node
## Klavye+fare ve gamepad girdisini (Input Map) takımın kontrol ettiği oyuncuya aktarır.
## Hareket kameraya göredir. Şut tuşu basılı tutulunca güç dolar, bırakınca vurur.
## Gamepad'de B: topla şut, topsuz kayarak müdahale (bağlama göre).

@export var team_path: NodePath
@export var camera_path: NodePath

var team: Team
var camera: Camera3D


func _ready() -> void:
	if team == null and not team_path.is_empty():
		team = get_node_or_null(team_path) as Team
	if camera == null and not camera_path.is_empty():
		camera = get_node_or_null(camera_path) as Camera3D


func _physics_process(_delta: float) -> void:
	if team == null or team.controlled == null:
		return
	var p := team.controlled
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	p.move_input = camera_relative(raw)
	p.sprint_input = Input.is_action_pressed("sprint")

	if Input.is_action_just_pressed("pass_short"):
		p.do_pass(PassTargeting.Kind.SHORT)
	elif Input.is_action_just_pressed("pass_through"):
		p.do_pass(PassTargeting.Kind.THROUGH)
	elif Input.is_action_just_pressed("pass_lob"):
		p.do_pass(PassTargeting.Kind.LOB)

	if p.has_ball() or p.shot_charge >= 0.0:
		if Input.is_action_just_pressed("shoot"):
			p.start_shot_charge()
		elif p.shot_charge >= 0.0 and not Input.is_action_pressed("shoot"):
			p.release_shot(_aim_lateral(p))
	elif Input.is_action_just_pressed("tackle"):
		# Rakibin dibindeyse ayakta müdahale, değilse kayarak
		if not p.standing_tackle():
			p.slide_tackle()

	if Input.is_action_just_pressed("shoulder"):
		p.shoulder_challenge()
	if Input.is_action_just_pressed("skill"):
		p.skill_move()
	if Input.is_action_just_pressed("switch_player"):
		team.switch_manual()


## Şut nişanı: hareket yönünün kale çizgisine paralel bileşeni (dünya Z).
func _aim_lateral(p: FootballPlayer) -> float:
	return clampf(p.move_input.z, -1.0, 1.0)


func camera_relative(raw: Vector2) -> Vector3:
	if camera == null:
		return Vector3(raw.x, 0.0, raw.y)
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right = Vector3(right.x, 0.0, right.z).normalized()
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	return (right * raw.x - forward * raw.y).limit_length(1.0)
