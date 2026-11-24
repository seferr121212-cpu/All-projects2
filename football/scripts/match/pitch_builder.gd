extends Node3D
## Saha zemini, çizgiler, zemin çarpışması ve temel ışığı kodla üretir.
## Ölçüler PitchDimensions'tan gelir; AI/ofsayt aynı sabitleri kullanır.

const PD = preload("res://scripts/match/pitch_dimensions.gd")
const LINE_Y := 0.01 # z-fighting önlemek için çizgiler zeminin hafif üstünde

@export var grass_color := Color(0.18, 0.45, 0.16)
@export var line_color := Color(0.95, 0.95, 0.95)
@export var build_lighting := true

var _st: SurfaceTool


func _ready() -> void:
	_build_ground()
	_build_lines()
	if build_lighting:
		_build_lighting()


func _build_ground() -> void:
	var margin := 30.0
	var body := StaticBody3D.new()
	body.name = "Ground"
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.0 # sekme topun malzemesinden gelir
	body.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(PD.LENGTH + margin, 1.0, PD.WIDTH + margin)
	cs.shape = box
	cs.position.y = -0.5
	body.add_child(cs)
	add_child(body)

	var grass := MeshInstance3D.new()
	grass.name = "Grass"
	var plane := PlaneMesh.new()
	plane.size = Vector2(PD.LENGTH + margin, PD.WIDTH + margin)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = grass_color
	mat.roughness = 0.95
	plane.material = mat
	grass.mesh = plane
	add_child(grass)


func _build_lines() -> void:
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st.set_normal(Vector3.UP)
	var hl := PD.HALF_LENGTH
	var hw := PD.HALF_WIDTH
	var lw := PD.LINE_WIDTH
	# Kenar ve kale çizgileri
	_rect(-hl, -hw, hl, -hw + lw)
	_rect(-hl, hw - lw, hl, hw)
	_rect(-hl, -hw, -hl + lw, hw)
	_rect(hl - lw, -hw, hl, hw)
	# Orta çizgi, orta yuvarlak, başlama noktası
	_rect(-lw * 0.5, -hw, lw * 0.5, hw)
	_ring(Vector2.ZERO, PD.CENTER_CIRCLE_RADIUS - lw, PD.CENTER_CIRCLE_RADIUS, 0.0, TAU)
	_ring(Vector2.ZERO, 0.0, 0.15, 0.0, TAU)
	for s in [-1.0, 1.0]:
		_build_half(s)

	var mi := MeshInstance3D.new()
	mi.name = "Lines"
	mi.mesh = _st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = line_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Bir yarı sahanın ceza sahası, kale alanı, penaltı noktası/yayı ve kornerleri.
func _build_half(s: float) -> void:
	var hl := PD.HALF_LENGTH
	var hw := PD.HALF_WIDTH
	var lw := PD.LINE_WIDTH
	_box_outline(s, PD.PENALTY_AREA_DEPTH, PD.PENALTY_AREA_WIDTH * 0.5)
	_box_outline(s, PD.GOAL_AREA_DEPTH, PD.GOAL_AREA_WIDTH * 0.5)
	var spot := Vector2(s * (hl - PD.PENALTY_SPOT_DISTANCE), 0.0)
	_ring(spot, 0.0, 0.15, 0.0, TAU)
	# Penaltı yayı: yalnızca ceza sahası dışında kalan kısım
	var r := PD.CENTER_CIRCLE_RADIUS
	var half_span := acos((PD.PENALTY_AREA_DEPTH - PD.PENALTY_SPOT_DISTANCE) / r)
	var base := PI if s > 0.0 else 0.0
	_ring(spot, r - lw, r, base - half_span, base + half_span)
	# Korner yayları (saha içine bakan çeyrek daire)
	for zs in [-1.0, 1.0]:
		var c := Vector2(s * hl, zs * hw)
		var a := atan2(-zs, -s)
		_ring(c, PD.CORNER_ARC_RADIUS - lw, PD.CORNER_ARC_RADIUS, a - PI * 0.25, a + PI * 0.25, 12)


## Kale çizgisinden içeri 'depth' derinliğinde, z yönünde ±half_w genişliğinde çerçeve.
func _box_outline(s: float, depth: float, half_w: float) -> void:
	var lw := PD.LINE_WIDTH
	var xg := s * PD.HALF_LENGTH
	var xi := s * (PD.HALF_LENGTH - depth)
	_rect(minf(xg, xi), half_w - lw, maxf(xg, xi), half_w)
	_rect(minf(xg, xi), -half_w, maxf(xg, xi), -half_w + lw)
	_rect(minf(xi, xi + s * lw), -half_w, maxf(xi, xi + s * lw), half_w)


func _rect(x0: float, z0: float, x1: float, z1: float) -> void:
	_quad(Vector3(x0, LINE_Y, z0), Vector3(x1, LINE_Y, z0), Vector3(x1, LINE_Y, z1), Vector3(x0, LINE_Y, z1))


## Halka parçası (r_in=0 ise dolu daire dilimi). Açı: x=cos, z=sin.
func _ring(c: Vector2, r_in: float, r_out: float, a0: float, a1: float, seg := 64) -> void:
	for i in seg:
		var t0 := lerpf(a0, a1, float(i) / seg)
		var t1 := lerpf(a0, a1, float(i + 1) / seg)
		var d0 := Vector3(cos(t0), 0.0, sin(t0))
		var d1 := Vector3(cos(t1), 0.0, sin(t1))
		var cc := Vector3(c.x, LINE_Y, c.y)
		_quad(cc + d0 * r_in, cc + d0 * r_out, cc + d1 * r_out, cc + d1 * r_in)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		_st.add_vertex(v)


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(30.0), 0.0)
	var game := get_node_or_null("/root/Game")
	sun.shadow_enabled = game == null or game.settings.shadows_enabled()
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
