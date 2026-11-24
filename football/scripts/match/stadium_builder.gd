extends Node3D
## Stadyum: dört tribün (basamaklı), çatı ve arka duvar, reklam panoları, seyirci (MultiMesh)
## ve gece modunda ışık kuleleri. Görsel amaçlıdır, çarpışma yoktur.

const PD = preload("res://scripts/match/pitch_dimensions.gd")
const CROWD_SHADER := preload("res://assets/shaders/crowd.gdshader")

@export var rows := 14
@export var row_depth := 0.85
@export var row_rise := 0.45
@export var side_gap := 9.0 # yan çizgiden tribüne mesafe
@export var end_gap := 8.0 # kale çizgisinden tribüne mesafe
@export var crowd_density := 0.75 # 0..1 doluluk
@export var home_color := Color("#c62828")
@export var away_color := Color("#1565c0")
@export var night := false

var crowd: MultiMeshInstance3D
var crowd_material: ShaderMaterial
var floodlights: Array[SpotLight3D] = []

var _rng := RandomNumberGenerator.new()
var _crowd_xforms: Array[Transform3D] = []
var _crowd_colors: Array[Color] = []
var _st: SurfaceTool


func _ready() -> void:
	_rng.seed = 2026
	var game := get_node_or_null("/root/Game")
	if game != null and not game.match_config.is_empty():
		night = bool(game.match_config.get("night", night))
		var home := TeamData.load_team(game.match_config.get("home", "kuzey"))
		var away := TeamData.load_team(game.match_config.get("away", "liman"))
		if home.display_name != "":
			home_color = home.color
		if away.display_name != "":
			away_color = away.color
	build()


func build() -> void:
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hl := PD.HALF_LENGTH
	var hw := PD.HALF_WIDTH
	# Yan tribünler (uzun kenarlar) ve kale arkası tribünler
	# Kamera tarafı (+Z) ana tribün: alçak ve çatısız, yayın kamerası üstünden görür
	_stand(Vector3(0, 0, hw + side_gap), Vector3(0, 0, 1), Vector3(1, 0, 0), PD.LENGTH + 12.0, 0, 9, false)
	_stand(Vector3(0, 0, -hw - side_gap), Vector3(0, 0, -1), Vector3(1, 0, 0), PD.LENGTH + 12.0, 1)
	_stand(Vector3(hl + end_gap, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), PD.WIDTH + 10.0, 2)
	_stand(Vector3(-hl - end_gap, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), PD.WIDTH + 10.0, 3)
	_st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Stands"
	mi.mesh = _st.commit()
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.52, 0.53, 0.56)
	concrete.roughness = 0.95
	concrete.cull_mode = BaseMaterial3D.CULL_DISABLED # yüz yönünden bağımsız görünsün
	mi.material_override = concrete
	add_child(mi)
	_build_boards()
	_build_crowd()
	if night:
		_build_floodlights()


## Basamaklı tribün: origin = ön kenarın ortası, out = sahadan dışarı yönü, along = uzunluk yönü.
func _stand(origin: Vector3, out: Vector3, along: Vector3, length: float, side_index: int, row_count := -1, roof := true) -> void:
	var n_rows := rows if row_count < 0 else row_count
	var half := length * 0.5
	var front_h := 1.2
	_box(origin + Vector3.UP * front_h * 0.5, out, along, Vector3(length, front_h, 0.3)) # ön duvar
	for i in n_rows:
		var d0 := i * row_depth
		var h := front_h + i * row_rise
		# Basamak: rıht (dikey) + basamak yüzü (yatay)
		_quad(origin + out * d0 + Vector3.UP * (h - row_rise) - along * half, origin + out * d0 + Vector3.UP * (h - row_rise) + along * half,
			origin + out * d0 + Vector3.UP * h + along * half, origin + out * d0 + Vector3.UP * h - along * half)
		_quad(origin + out * d0 + Vector3.UP * h - along * half, origin + out * d0 + Vector3.UP * h + along * half,
			origin + out * (d0 + row_depth) + Vector3.UP * h + along * half, origin + out * (d0 + row_depth) + Vector3.UP * h - along * half)
		_add_crowd_row(origin + out * (d0 + row_depth * 0.55) + Vector3.UP * h, out, along, length, side_index)
	var depth := n_rows * row_depth
	var top := front_h + n_rows * row_rise
	if not roof:
		_box(origin + out * (depth + 0.3) + Vector3.UP * (top + 1.0) * 0.5, out, along, Vector3(length, top + 1.0, 0.6)) # alçak arka duvar
		return
	_box(origin + out * (depth + 0.3) + Vector3.UP * (top + 5.0) * 0.5, out, along, Vector3(length, top + 5.0, 0.6)) # arka duvar
	_box(origin + out * (depth * 0.5 + 0.5) + Vector3.UP * (top + 5.0), out, along, Vector3(length + 2.0, 0.4, depth + 3.0)) # çatı
	for k in 7: # çatı kolonları
		var s := -half + length * (k / 6.0)
		_box(origin + out * (depth * 0.5) + along * s + Vector3.UP * (top + 5.0) * 0.5, out, along, Vector3(0.35, top + 5.0, 0.35))


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, c, b, a, d, c]:
		_st.add_vertex(v)


## Yönlendirilmiş kutu: size = (along, yükseklik, out) boyutları.
func _box(center: Vector3, out: Vector3, along: Vector3, size: Vector3) -> void:
	var ax := along * size.x * 0.5
	var ay := Vector3.UP * size.y * 0.5
	var az := out * size.z * 0.5
	var c := [center - ax - ay - az, center + ax - ay - az, center + ax + ay - az, center - ax + ay - az,
		center - ax - ay + az, center + ax - ay + az, center + ax + ay + az, center - ax + ay + az]
	for f in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		_quad(c[f[0]], c[f[1]], c[f[2]], c[f[3]])


func _add_crowd_row(center: Vector3, out: Vector3, along: Vector3, length: float, side_index: int) -> void:
	var spacing := 0.62
	var n := int(length / spacing)
	var basis := Basis.looking_at(-out, Vector3.UP) # sahaya bakar
	for i in n:
		if _rng.randf() > crowd_density:
			continue
		var s := -length * 0.5 + (i + 0.5) * spacing + _rng.randf_range(-0.1, 0.1)
		var pos := center + along * s + Vector3.UP * (0.55 + _rng.randf_range(-0.05, 0.08))
		var sc := _rng.randf_range(0.9, 1.1)
		_crowd_xforms.append(Transform3D(basis.scaled(Vector3(sc, sc, sc)), pos))
		_crowd_colors.append(_crowd_color(side_index))


## Ev sahibi tarafı (2: +X kale arkası hariç) ağırlıklı ev rengi; deplasman kale arkası ağırlıklı deplasman.
func _crowd_color(side_index: int) -> Color:
	var r := _rng.randf()
	var home_share := 0.55 if side_index < 2 else (0.15 if side_index == 2 else 0.75)
	if r < home_share:
		return home_color.lerp(Color.WHITE, _rng.randf_range(0.0, 0.25))
	if r < home_share + 0.3:
		return away_color.lerp(Color.WHITE, _rng.randf_range(0.0, 0.25))
	var neutral := [Color(0.9, 0.9, 0.9), Color(0.15, 0.15, 0.17), Color(0.4, 0.42, 0.45), Color(0.55, 0.45, 0.35), Color(0.25, 0.3, 0.45)]
	return neutral[_rng.randi_range(0, neutral.size() - 1)]


func _build_crowd() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var body := CapsuleMesh.new()
	body.radius = 0.22
	body.height = 1.0
	body.radial_segments = 6
	body.rings = 1
	mm.mesh = body
	mm.instance_count = _crowd_xforms.size()
	for i in _crowd_xforms.size():
		mm.set_instance_transform(i, _crowd_xforms[i])
		mm.set_instance_color(i, _crowd_colors[i])
	crowd = MultiMeshInstance3D.new()
	crowd.name = "Crowd"
	crowd.multimesh = mm
	crowd_material = ShaderMaterial.new()
	crowd_material.shader = CROWD_SHADER
	crowd.material_override = crowd_material
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowd)


## Seyirci heyecanı (0..1): sallanma ve zıplama.
func set_excitement(x: float) -> void:
	if crowd_material:
		crowd_material.set_shader_parameter(&"excitement", clampf(x, 0.0, 1.0))


func crowd_count() -> int:
	return _crowd_xforms.size()


func _build_boards() -> void:
	var mat_a := StandardMaterial3D.new()
	mat_a.albedo_color = Color(0.08, 0.1, 0.12)
	mat_a.emission_enabled = true
	mat_a.emission = Color(0.1, 0.55, 0.3)
	mat_a.emission_energy_multiplier = 0.8 if night else 0.35
	var mat_b := mat_a.duplicate()
	mat_b.emission = Color(0.15, 0.35, 0.75)
	var hl := PD.HALF_LENGTH
	var hw := PD.HALF_WIDTH
	var segs := []
	for k in 10: # yan çizgi boyunca
		var x := -hl + 1.0 + k * (PD.LENGTH - 2.0) / 10.0 + (PD.LENGTH - 2.0) / 20.0
		segs.append([Vector3(x, 0.5, hw + 4.0), Vector3(10.0, 1.0, 0.1)])
		segs.append([Vector3(x, 0.5, -hw - 4.0), Vector3(10.0, 1.0, 0.1)])
	for zs in [-1.0, 1.0]: # kale arkası (kale önü boş)
		for xs in [-1.0, 1.0]:
			segs.append([Vector3(xs * (hl + 3.5), 0.5, zs * 20.0), Vector3(0.1, 1.0, 26.0)])
	for i in segs.size():
		var b := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = segs[i][1]
		b.mesh = m
		b.position = segs[i][0]
		b.material_override = mat_a if i % 2 == 0 else mat_b
		add_child(b)


func _build_floodlights() -> void:
	var hl := PD.HALF_LENGTH + end_gap + 6.0
	var hw := PD.HALF_WIDTH + side_gap + 6.0
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.35, 0.36, 0.38)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color.WHITE
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.97, 0.9)
	lamp_mat.emission_energy_multiplier = 6.0
	for xs in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			var base := Vector3(xs * hl, 0, zs * hw)
			var pole := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.5
			cyl.bottom_radius = 0.8
			cyl.height = 38.0
			pole.mesh = cyl
			pole.material_override = pole_mat
			pole.position = base + Vector3.UP * 19.0
			add_child(pole)
			var head := MeshInstance3D.new()
			var panel := BoxMesh.new()
			panel.size = Vector3(6.0, 4.0, 0.6)
			head.mesh = panel
			head.material_override = lamp_mat
			add_child(head)
			head.position = base + Vector3.UP * 39.0
			head.look_at(Vector3(0, 0, 0), Vector3.UP)
			var spot := SpotLight3D.new()
			spot.light_color = Color(1.0, 0.97, 0.92)
			spot.light_energy = 9.0
			spot.spot_range = 160.0
			spot.spot_angle = 42.0
			spot.spot_attenuation = 0.6
			spot.shadow_enabled = false
			add_child(spot)
			spot.position = base + Vector3.UP * 38.0
			spot.look_at(Vector3(-xs * 8.0, 0, -zs * 6.0), Vector3.UP)
			floodlights.append(spot)
