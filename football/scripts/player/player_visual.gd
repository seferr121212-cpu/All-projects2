extends Node3D
## Oyuncu görseli: kodla üretilen low-poly insan figürü + eklem iskeleti (Node3D hiyerarşisi),
## prosedürel animasyonlar ve AnimationTree (duruş/koşu/sprint harmanı + aksiyonlar).
## İleri yön -Z. Gerçek bir model gelince bu sahne değiştirilir; arayüz aynı kalır:
## set_team_color, set_kit, set_number, set_indicator, set_pose, set_locomotion, play_kick.

const SKIN_TONES := [Color("#f1c8a5"), Color("#e0ac80"), Color("#c68a5e"), Color("#9c6a45"), Color("#6f4a30"), Color("#4a3022")]
const HAIR_COLORS := [Color("#1c1611"), Color("#3b2a1c"), Color("#6b4a2b"), Color("#a7773f"), Color("#d6b46a"), Color("#2a2a2a")]

var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var indicator: Node3D

var _mats := {}
var _number_label: Label3D
var _current_pose := 0
var _speed_smooth := 0.0


func _ready() -> void:
	_build_materials()
	_build_body()
	_build_indicator()
	_build_animations()
	set_appearance(0)


# --- Malzemeler ve görünüm -------------------------------------------------------------

func _build_materials() -> void:
	for key in ["jersey", "shorts", "socks", "skin", "hair", "boots", "gloves"]:
		var m := StandardMaterial3D.new()
		m.roughness = 0.75 if key != "boots" else 0.4
		_mats[key] = m
	_mats.boots.albedo_color = Color("#151515")
	set_kit(Color(0.8, 0.1, 0.1))


## Forma, şort ve tozluk renkleri. Şort, forma rengine göre koyu ya da beyaz seçilir.
func set_kit(jersey: Color, shorts := Color(-1, 0, 0), socks := Color(-1, 0, 0)) -> void:
	_mats.jersey.albedo_color = jersey
	if shorts.r < 0.0:
		shorts = Color(0.1, 0.1, 0.12) if jersey.get_luminance() > 0.45 else Color(0.94, 0.94, 0.94)
	if socks.r < 0.0:
		socks = jersey
	_mats.shorts.albedo_color = shorts
	_mats.socks.albedo_color = socks
	_mats.gloves.albedo_color = jersey.darkened(0.3)
	if _number_label:
		_number_label.modulate = Color.WHITE if jersey.get_luminance() < 0.6 else Color(0.08, 0.08, 0.1)
		_number_label.outline_modulate = Color(0, 0, 0, 0.6) if jersey.get_luminance() < 0.6 else Color(1, 1, 1, 0.5)


## Eski arayüz: tek renk -> forma seti.
func set_team_color(color: Color) -> void:
	set_kit(color)


func set_number(n: int) -> void:
	if _number_label:
		_number_label.text = str(n)
	set_appearance(n)


## Ten ve saç rengi oyuncuya göre (numaradan türetilmiş, kalıcı).
func set_appearance(seed_value: int) -> void:
	var h := hash(seed_value * 7919 + 13)
	_mats.skin.albedo_color = SKIN_TONES[absi(h) % SKIN_TONES.size()]
	_mats.hair.albedo_color = HAIR_COLORS[absi(h / 7) % HAIR_COLORS.size()]


func set_indicator(on: bool) -> void:
	if indicator:
		indicator.visible = on


# --- Gövde -----------------------------------------------------------------------------

func _joint(parent: Node3D, name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat_key: String, scale_v := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale_v
	mi.rotation = rot
	mi.material_override = _mats[mat_key]
	parent.add_child(mi)
	return mi


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 3
	return c


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 12
	c.rings = 1
	return c


static func _sphere(r: float, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0.0 else h
	s.radial_segments = 12
	s.rings = 6
	return s


func _build_body() -> void:
	var rig := _joint(self, "Rig", Vector3.ZERO)
	var hips := _joint(rig, "Hips", Vector3(0, 0.95, 0))
	# Şort
	_part(hips, _cyl(0.17, 0.2, 0.26), Vector3(0, -0.09, 0), "shorts", Vector3(1, 1, 0.72))
	var spine := _joint(hips, "Spine", Vector3(0, 0.05, 0))
	# Gövde (forma): omuzlara doğru genişleyen, önden arkaya basık
	_part(spine, _cyl(0.22, 0.17, 0.52), Vector3(0, 0.22, 0), "jersey", Vector3(1, 1, 0.62))
	var chest := _joint(spine, "Chest", Vector3(0, 0.27, 0))
	_part(chest, _sphere(0.1), Vector3(-0.17, 0.2, 0), "jersey", Vector3(1, 0.8, 1)) # omuz yuvarlakları
	_part(chest, _sphere(0.1), Vector3(0.17, 0.2, 0), "jersey", Vector3(1, 0.8, 1))
	# Sırt numarası (+Z = arka)
	_number_label = Label3D.new()
	_number_label.text = "0"
	_number_label.font_size = 72
	_number_label.pixel_size = 0.0028
	_number_label.outline_size = 10
	_number_label.position = Vector3(0, 0.03, 0.142)
	_number_label.double_sided = false
	chest.add_child(_number_label)
	var neck := _joint(chest, "Neck", Vector3(0, 0.27, 0))
	_part(neck, _cyl(0.05, 0.058, 0.1), Vector3(0, 0.03, 0), "skin")
	var head := _joint(neck, "Head", Vector3(0, 0.09, 0))
	_part(head, _sphere(0.112, 0.25), Vector3(0, 0.11, 0), "skin")
	_part(head, _sphere(0.118), Vector3(0, 0.16, 0.012), "hair", Vector3(1, 0.62, 1.02)) # saç
	_part(head, _sphere(0.028), Vector3(0, 0.1, -0.11), "skin") # burun
	for side in [-1.0, 1.0]:
		_part(head, _sphere(0.03), Vector3(side * 0.11, 0.11, 0), "skin", Vector3(0.5, 1, 0.8)) # kulak
		_build_arm(chest, side)
		_build_leg(hips, side)


func _build_arm(chest: Node3D, side: float) -> void:
	var s := "L" if side < 0.0 else "R"
	var shoulder := _joint(chest, "Shoulder" + s, Vector3(side * 0.235, 0.19, 0))
	_part(shoulder, _cyl(0.068, 0.06, 0.16), Vector3(0, -0.06, 0), "jersey") # kısa kol
	_part(shoulder, _capsule(0.048, 0.3), Vector3(0, -0.14, 0), "skin")
	var elbow := _joint(shoulder, "Elbow" + s, Vector3(0, -0.29, 0))
	_part(elbow, _capsule(0.043, 0.28), Vector3(0, -0.13, 0), "skin")
	_part(elbow, _sphere(0.05), Vector3(0, -0.29, 0), "skin", Vector3(0.8, 1.1, 0.6)) # el


func _build_leg(hips: Node3D, side: float) -> void:
	var s := "L" if side < 0.0 else "R"
	var hip := _joint(hips, "Hip" + s, Vector3(side * 0.1, -0.03, 0))
	_part(hip, _capsule(0.08, 0.46), Vector3(0, -0.22, 0), "skin")
	var knee := _joint(hip, "Knee" + s, Vector3(0, -0.44, 0))
	_part(knee, _capsule(0.062, 0.44), Vector3(0, -0.2, 0), "socks")
	var ankle := _joint(knee, "Ankle" + s, Vector3(0, -0.42, 0))
	var boot := BoxMesh.new()
	boot.size = Vector3(0.1, 0.08, 0.27)
	_part(ankle, boot, Vector3(0, -0.02, -0.06), "boots")


func _build_indicator() -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.9, 0.1)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = m
	mi.mesh = torus
	mi.position.y = 0.03
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	indicator = mi


# --- Animasyonlar ---------------------------------------------------------------------

## keys: { "Rig/Hips/HipL": [[t, Vector3(derece)], ...] }, pos: { yol: [[t, Vector3], ...] }
static func make_anim(length: float, loop: bool, keys: Dictionary, pos := {}) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for path in keys:
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath(path))
		for k in keys[path]:
			var e: Vector3 = k[1]
			a.rotation_track_insert_key(t, k[0], Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z))))
	for path in pos:
		var t := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(t, NodePath(path))
		for k in pos[path]:
			a.position_track_insert_key(t, k[0], k[1])
	return a


const H := "Rig/Hips"
const SP := "Rig/Hips/Spine"
const SHL := "Rig/Hips/Spine/Chest/ShoulderL"
const SHR := "Rig/Hips/Spine/Chest/ShoulderR"
const ELL := "Rig/Hips/Spine/Chest/ShoulderL/ElbowL"
const ELR := "Rig/Hips/Spine/Chest/ShoulderR/ElbowR"
const HPL := "Rig/Hips/HipL"
const HPR := "Rig/Hips/HipR"
const KNL := "Rig/Hips/HipL/KneeL"
const KNR := "Rig/Hips/HipR/KneeR"
const RIG := "Rig"


## Koşu döngüsü (0.6 sn). amp: bacak salınımı (derece), lean: öne eğilme.
static func _run_cycle(amp: float, lean: float, bob: float) -> Animation:
	var a := amp
	var t := [0.0, 0.15, 0.3, 0.45, 0.6]
	var swing := func(sign: float) -> Array:
		return [[t[0], Vector3(sign * a, 0, 0)], [t[1], Vector3(0, 0, 0)], [t[2], Vector3(-sign * a * 0.8, 0, 0)], [t[3], Vector3(0, 0, 0)], [t[4], Vector3(sign * a, 0, 0)]]
	var knee_l := [[t[0], Vector3(-12, 0, 0)], [t[1], Vector3(-30, 0, 0)], [t[2], Vector3(-a * 1.8, 0, 0)], [t[3], Vector3(-a, 0, 0)], [t[4], Vector3(-12, 0, 0)]]
	var knee_r := [[t[0], Vector3(-a * 1.8, 0, 0)], [t[1], Vector3(-a, 0, 0)], [t[2], Vector3(-12, 0, 0)], [t[3], Vector3(-30, 0, 0)], [t[4], Vector3(-a * 1.8, 0, 0)]]
	var arm := func(sign: float, z: float) -> Array:
		return [[t[0], Vector3(sign * a * 0.8, 0, z)], [t[2], Vector3(-sign * a * 0.8, 0, z)], [t[4], Vector3(sign * a * 0.8, 0, z)]]
	return make_anim(0.6, true, {
		HPL: swing.call(1.0), HPR: swing.call(-1.0), KNL: knee_l, KNR: knee_r,
		SHL: arm.call(-1.0, -8.0), SHR: arm.call(1.0, 8.0),
		ELL: [[0.0, Vector3(75, 0, 0)]], ELR: [[0.0, Vector3(75, 0, 0)]],
		SP: [[0.0, Vector3(-lean, 0, 0)], [0.15, Vector3(-lean - 2, 4, 0)], [0.3, Vector3(-lean, 0, 0)], [0.45, Vector3(-lean - 2, -4, 0)], [0.6, Vector3(-lean, 0, 0)]],
	}, {H: [[0.0, Vector3(0, 0.95 - bob, 0)], [0.15, Vector3(0, 0.95, 0)], [0.3, Vector3(0, 0.95 - bob, 0)], [0.45, Vector3(0, 0.95, 0)], [0.6, Vector3(0, 0.95 - bob, 0)]]})


static func build_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle", make_anim(0.6, true, {
		SP: [[0.0, Vector3(-2, 0, 0)], [0.3, Vector3(0, 0, 0)], [0.6, Vector3(-2, 0, 0)]],
		SHL: [[0.0, Vector3(0, 0, -7)]], SHR: [[0.0, Vector3(0, 0, 7)]],
		ELL: [[0.0, Vector3(15, 0, 0)]], ELR: [[0.0, Vector3(15, 0, 0)]],
		HPL: [[0.0, Vector3(4, 0, -3)]], HPR: [[0.0, Vector3(-2, 0, 3)]],
		KNL: [[0.0, Vector3(-8, 0, 0)]], KNR: [[0.0, Vector3(-6, 0, 0)]],
	}, {H: [[0.0, Vector3(0, 0.94, 0)], [0.3, Vector3(0, 0.945, 0)], [0.6, Vector3(0, 0.94, 0)]]}))
	lib.add_animation(&"jog", _run_cycle(30.0, 6.0, 0.03))
	lib.add_animation(&"sprint", _run_cycle(48.0, 14.0, 0.05))
	lib.add_animation(&"kick", make_anim(0.45, false, {
		HPR: [[0.0, Vector3(0, 0, 0)], [0.15, Vector3(-45, 0, 0)], [0.26, Vector3(75, 0, 0)], [0.45, Vector3(20, 0, 0)]],
		KNR: [[0.0, Vector3(-10, 0, 0)], [0.15, Vector3(-95, 0, 0)], [0.26, Vector3(-5, 0, 0)], [0.45, Vector3(-20, 0, 0)]],
		HPL: [[0.0, Vector3(0, 0, 0)], [0.26, Vector3(-12, 0, 0)], [0.45, Vector3(0, 0, 0)]],
		KNL: [[0.0, Vector3(-10, 0, 0)], [0.26, Vector3(-25, 0, 0)], [0.45, Vector3(-10, 0, 0)]],
		SP: [[0.0, Vector3(-4, 0, 0)], [0.15, Vector3(-8, -10, 0)], [0.26, Vector3(6, 12, 0)], [0.45, Vector3(0, 0, 0)]],
		SHL: [[0.0, Vector3(0, 0, -10)], [0.26, Vector3(20, 0, -45)], [0.45, Vector3(0, 0, -10)]],
		SHR: [[0.0, Vector3(0, 0, 10)], [0.26, Vector3(-30, 0, 25)], [0.45, Vector3(0, 0, 10)]],
	}))
	lib.add_animation(&"slide", make_anim(0.4, false, {
		H: [[0.0, Vector3(0, 0, 0)], [0.15, Vector3(30, 0, 0)]],
		HPL: [[0.0, Vector3(0, 0, 0)], [0.15, Vector3(62, 0, 0)]], # kayan bacak yerde, ileri uzanır
		HPR: [[0.0, Vector3(0, 0, 0)], [0.15, Vector3(40, 0, 0)]],
		KNR: [[0.0, Vector3(0, 0, 0)], [0.15, Vector3(-75, 0, 0)]],
		SP: [[0.0, Vector3(0, 0, 0)], [0.15, Vector3(15, 0, 0)]],
		SHL: [[0.0, Vector3(0, 0, 0)], [0.15, Vector3(10, 0, -60)]],
		SHR: [[0.0, Vector3(0, 0, 0)], [0.15, Vector3(-20, 0, 35)]],
	}, {H: [[0.0, Vector3(0, 0.95, 0)], [0.15, Vector3(0, 0.45, 0.25)]]}))
	for side in [-1.0, 1.0]:
		lib.add_animation(&"dive_l" if side < 0.0 else &"dive_r", make_anim(0.5, false, {
			RIG: [[0.0, Vector3(0, 0, 0)], [0.18, Vector3(0, 0, -side * 78)]],
			SHL: [[0.0, Vector3(0, 0, -10)], [0.15, Vector3(0, 0, -168)]],
			SHR: [[0.0, Vector3(0, 0, 10)], [0.15, Vector3(0, 0, 168)]],
			ELL: [[0.0, Vector3(10, 0, 0)]], ELR: [[0.0, Vector3(10, 0, 0)]],
			HPL: [[0.0, Vector3(0, 0, 0)], [0.18, Vector3(10, 0, side * 10)]],
			HPR: [[0.0, Vector3(0, 0, 0)], [0.18, Vector3(-10, 0, side * 10)]],
			KNL: [[0.18, Vector3(-30, 0, 0)]], KNR: [[0.18, Vector3(-15, 0, 0)]],
		}, {RIG: [[0.0, Vector3.ZERO], [0.18, Vector3(side * 0.55, 0.45, 0)]]}))
	lib.add_animation(&"stumble", make_anim(0.5, false, {
		SP: [[0.0, Vector3(0, 0, 0)], [0.15, Vector3(-28, 6, 0)], [0.5, Vector3(-18, 0, 0)]],
		SHL: [[0.0, Vector3(0, 0, -10)], [0.15, Vector3(-25, 0, -50)]],
		SHR: [[0.0, Vector3(0, 0, 10)], [0.15, Vector3(-15, 0, 55)]],
		HPL: [[0.15, Vector3(25, 0, 0)]], KNL: [[0.15, Vector3(-40, 0, 0)]],
		HPR: [[0.15, Vector3(-15, 0, 0)]], KNR: [[0.15, Vector3(-25, 0, 0)]],
	}, {H: [[0.0, Vector3(0, 0.95, 0)], [0.15, Vector3(0, 0.84, 0)]]}))
	return lib


func _build_animations() -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	add_child(anim_player)
	anim_player.add_animation_library(&"", build_library())

	var sm := AnimationNodeStateMachine.new()
	var loco := AnimationNodeBlendTree.new()
	var bs := AnimationNodeBlendSpace1D.new()
	for pair in [[&"idle", 0.0], [&"jog", 0.5], [&"sprint", 1.0]]:
		var n := AnimationNodeAnimation.new()
		n.animation = pair[0]
		bs.add_blend_point(n, pair[1], -1, pair[0])
	bs.min_space = 0.0
	bs.max_space = 1.0
	var ts := AnimationNodeTimeScale.new()
	loco.add_node(&"bs", bs)
	loco.add_node(&"ts", ts)
	loco.connect_node(&"ts", 0, &"bs")
	loco.connect_node(&"output", 0, &"ts")
	sm.add_node(&"loco", loco)
	for action in [&"kick", &"slide", &"dive_l", &"dive_r", &"stumble"]:
		var n := AnimationNodeAnimation.new()
		n.animation = action
		sm.add_node(action, n)
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition(&"Start", &"loco", start)
	# Vuruş bitince koşuya döner
	var back := AnimationNodeStateMachineTransition.new()
	back.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	back.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	back.xfade_time = 0.12
	sm.add_transition(&"kick", &"loco", back)

	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	anim_tree.tree_root = sm
	add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)
	anim_tree.active = true
	playback = anim_tree.get("parameters/playback")


## Hareket hızına göre duruş/koşu/sprint harmanı ve adım hızı.
func set_locomotion(speed: float) -> void:
	if anim_tree == null:
		return
	_speed_smooth = lerpf(_speed_smooth, speed, 0.25)
	var s := _speed_smooth
	var blend := s / 5.0 * 0.5 if s < 5.0 else 0.5 + clampf((s - 5.0) / 4.0, 0.0, 1.0) * 0.5
	anim_tree.set(&"parameters/loco/bs/blend_position", clampf(blend, 0.0, 1.0))
	anim_tree.set(&"parameters/loco/ts/scale", clampf(s / 6.0, 0.6, 1.5) if s > 0.5 else 1.0)


func play_kick() -> void:
	if playback and _current_pose == 0:
		playback.start(&"kick", true)


## Oyuncu durumuna göre poz (FootballPlayer.State). side: uzanma yönü (-1 sol, +1 sağ).
func set_pose(state: int, side := 0.0) -> void:
	_current_pose = state
	if playback == null:
		return
	match state:
		FootballPlayer.State.SLIDING:
			playback.start(&"slide", true)
		FootballPlayer.State.DIVE:
			playback.start(&"dive_r" if side > 0.0 else &"dive_l", true)
		FootballPlayer.State.STUMBLE:
			playback.start(&"stumble", true)
		_:
			playback.start(&"loco", true)


func current_animation() -> StringName:
	return playback.get_current_node() if playback else &""
