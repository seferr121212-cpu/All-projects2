extends Node3D
## Stylised low-poly character: head/torso in one mesh, arms and legs as
## separate pivoted meshes so the body can walk, breathe and gesture without
## a skeleton. Five draw calls per character, one shared vertex-colour
## material. Look comes from data/characters.json ("look").

const MeshBatch = preload("res://scenes/world/mesh_batch.gd")
const ArtKit = preload("res://scenes/world/art_kit.gd")
const HAIR_STYLES := ["short", "cap", "ponytail", "bun", "long", "bald"]
const WALK_REF_SPEED := 2.3
const TALK_SEC := 1.4

var character_id := ""
var move_speed := 0.0
var _phase := 0.0
var _time := 0.0
var _talk := 0.0
var _torso: MeshInstance3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _hip_y := 0.9


static func default_look(body_color: String) -> Dictionary:
	return {"top": body_color, "pants": "#33383f", "skin": "#c99a76", "hair": "#2a2420", "hair_style": "short",
		"shoes": "#1c1c1e", "height": 1.0, "build": 1.0}


static func _c(look: Dictionary, key: String) -> Color:
	return Color.html(str(look.get(key, "#808080")))


## info: characters.json entry ({"body", "look"}).
func setup(id: String, info: Dictionary) -> void:
	character_id = id
	name = id
	var look := default_look(str(info.get("body", "#666666")))
	look.merge(info.get("look", {}), true)
	_time = float(hash(id) % 1000) / 160.0  # desync idles
	var hgt := float(look["height"])
	var bld := float(look["build"])
	var top := _c(look, "top")
	var pants := _c(look, "pants")
	var skin := _c(look, "skin")
	var hair := _c(look, "hair")
	var shoes := _c(look, "shoes")
	_hip_y = 0.9 * hgt
	var leg_len := _hip_y - 0.06
	var torso_len := 0.56 * hgt
	var shoulder_y := _hip_y + torso_len - 0.06
	var half_w := 0.2 * bld

	var tb := MeshBatch.new()
	tb.ao = false
	# Hips, chest (slightly wider), collar.
	tb.add_box(Transform3D(Basis(), Vector3(0, _hip_y + 0.08, 0)), Vector3(half_w * 1.9, 0.2, 0.24 * bld), pants)
	tb.add_box(Transform3D(Basis(), Vector3(0, _hip_y + 0.18 + torso_len * 0.38, 0)),
		Vector3(half_w * 2.0, torso_len * 0.76, 0.26 * bld), top)
	if bool(look.get("coat", false)):
		tb.add_box(Transform3D(Basis(), Vector3(0, _hip_y - 0.12, 0)), Vector3(half_w * 2.05, 0.42, 0.27 * bld), top.darkened(0.08))
	if bool(look.get("overalls", false)):
		tb.add_box(Transform3D(Basis(), Vector3(0, _hip_y + 0.3, 0.135 * bld)), Vector3(half_w * 1.2, 0.3, 0.01), pants)
	if bool(look.get("bag", false)):
		tb.add_box(Transform3D(Basis(), Vector3(0, _hip_y + 0.3, -0.18 * bld)), Vector3(0.28, 0.34, 0.12), top.darkened(0.45))
	var neck_y := shoulder_y + 0.08
	tb.add_prism(Transform3D(Basis(), Vector3(0, neck_y, 0)), 0.05, 0.1, skin, 6)
	var head_y := neck_y + 0.17
	tb.add_prism(Transform3D(Basis(), Vector3(0, head_y, 0)), 0.115, 0.25, skin, 7)
	tb.add_box(Transform3D(Basis(), Vector3(0, head_y - 0.01, 0.12)), Vector3(0.04, 0.06, 0.04), skin.darkened(0.1))
	for sx in [-1, 1]:
		tb.add_box(Transform3D(Basis(), Vector3(sx * 0.045, head_y + 0.03, 0.112)), Vector3(0.03, 0.025, 0.01), Color(0.08, 0.07, 0.07))
	if bool(look.get("mustache", false)):
		tb.add_box(Transform3D(Basis(), Vector3(0, head_y - 0.05, 0.115)), Vector3(0.09, 0.025, 0.02), hair.darkened(0.2))
	if bool(look.get("beard", false)):
		tb.add_box(Transform3D(Basis(), Vector3(0, head_y - 0.08, 0.06)), Vector3(0.2, 0.08, 0.12), hair.darkened(0.15))
	if bool(look.get("glasses", false)):
		tb.add_box(Transform3D(Basis(), Vector3(0, head_y + 0.03, 0.12)), Vector3(0.18, 0.04, 0.015), Color(0.15, 0.15, 0.16))
	_add_hair(tb, str(look.get("hair_style", "short")), head_y, hair, _c(look, "cap") if look.has("cap") else top.darkened(0.2))
	_torso = MeshInstance3D.new()
	_torso.name = "Torso"
	_torso.mesh = tb.commit()
	_torso.material_override = ArtKit.material("skin")
	add_child(_torso)

	for sx in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(sx * half_w * 0.5, _hip_y, 0)
		var lb := MeshBatch.new()
		lb.ao = false
		lb.add_box(Transform3D(Basis(), Vector3(0, -leg_len * 0.5, 0)), Vector3(0.15 * bld, leg_len, 0.17 * bld), pants)
		lb.add_box(Transform3D(Basis(), Vector3(0, -leg_len + 0.03, 0.04)), Vector3(0.15 * bld, 0.08, 0.26), shoes)
		leg.add_child(_limb_mesh(lb))
		add_child(leg)
		_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(sx * (half_w + 0.06), shoulder_y, 0)
		var ab := MeshBatch.new()
		ab.ao = false
		var arm_len := 0.58 * hgt
		ab.add_box(Transform3D(Basis(), Vector3(0, -arm_len * 0.45, 0)), Vector3(0.11 * bld, arm_len * 0.9, 0.12 * bld),
			top.darkened(0.06))
		ab.add_box(Transform3D(Basis(), Vector3(0, -arm_len * 0.95, 0.01)), Vector3(0.08, 0.1, 0.09), skin)
		arm.add_child(_limb_mesh(ab))
		arm.rotation.z = sx * 0.06
		add_child(arm)
		_arms.append(arm)


func _limb_mesh(b: MeshBatch) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.material_override = ArtKit.material("skin")
	return mi


static func _add_hair(tb: MeshBatch, style: String, head_y: float, hair: Color, cap: Color) -> void:
	var top := head_y + 0.125
	match style:
		"bald":
			tb.add_prism(Transform3D(Basis(), Vector3(0, head_y - 0.02, -0.02)), 0.12, 0.08, hair, 7)
		"cap":
			tb.add_prism(Transform3D(Basis(), Vector3(0, top + 0.02, 0)), 0.125, 0.07, cap, 7)
			tb.add_box(Transform3D(Basis(), Vector3(0, top - 0.005, 0.15)), Vector3(0.18, 0.02, 0.12), cap.darkened(0.15))
			tb.add_prism(Transform3D(Basis(), Vector3(0, head_y - 0.03, -0.015)), 0.118, 0.07, hair, 7)
		_:
			tb.add_prism(Transform3D(Basis(), Vector3(0, top, -0.01)), 0.125, 0.06, hair, 7)
			tb.add_box(Transform3D(Basis(), Vector3(0, head_y + 0.02, -0.08)), Vector3(0.22, 0.16, 0.08), hair)
			if style == "ponytail":
				tb.add_box(Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, head_y - 0.04, -0.15)), Vector3(0.07, 0.24, 0.07), hair)
			elif style == "bun":
				tb.add_prism(Transform3D(Basis(), Vector3(0, top + 0.02, -0.08)), 0.06, 0.08, hair, 6)
			elif style == "long":
				tb.add_box(Transform3D(Basis(), Vector3(0, head_y - 0.1, -0.08)), Vector3(0.24, 0.3, 0.07), hair)


## Horizontal speed in m/s (the player controller feeds this every frame).
func set_motion(speed: float) -> void:
	move_speed = speed


## Short "speaking" gesture: a nod and a small hand movement.
func talk() -> void:
	_talk = TALK_SEC


func _process(delta: float) -> void:
	_time += delta
	var walk := clampf(move_speed / WALK_REF_SPEED, 0.0, 1.0)
	_phase += delta * (2.0 + 6.5 * walk)
	var swing := sin(_phase) * 0.55 * walk
	if _legs.size() == 2:
		_legs[0].rotation.x = swing
		_legs[1].rotation.x = -swing
		_arms[0].rotation.x = -swing * 0.8
		_arms[1].rotation.x = swing * 0.8
	var breathe := sin(_time * 1.7) * 0.012 * (1.0 - walk)
	if _torso:
		_torso.position.y = absf(sin(_phase)) * 0.035 * walk
		_torso.scale = Vector3(1.0 + breathe * 0.5, 1.0 + breathe, 1.0 + breathe * 0.5)
		_torso.rotation.y = sin(_time * 0.4) * 0.03 * (1.0 - walk)
	if _talk > 0.0:
		_talk = maxf(0.0, _talk - delta)
		var k := sin((1.0 - _talk / TALK_SEC) * PI)
		if _torso:
			_torso.rotation.x = sin(_time * 7.0) * 0.015 * k
		if _arms.size() == 2:
			_arms[1].rotation.x = -0.45 * k + sin(_time * 5.0) * 0.08 * k
	elif _torso and walk < 0.01:
		_torso.rotation.x = 0.0
