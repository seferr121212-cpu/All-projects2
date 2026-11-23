class_name Formation
extends RefCounted
## Diziliş: normalize slotlar (x: -1 kendi kale çizgisi .. +1 rakip kale çizgisi, z: -1..1 genişlik).
## Hedef pozisyon topun konumuna ve takım fazına göre kayar.

const PD = preload("res://scripts/match/pitch_dimensions.gd")
const PATH := "res://data/formations.json"

enum Phase { ATTACK, DEFENSE, TRANSITION }

var id := ""
var display_name := ""
var roles: Array[String] = []
var slots: Array[Vector2] = []


static func load_formation(formation_id: String) -> Formation:
	var f := Formation.new()
	f.id = formation_id
	var file := FileAccess.open(PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text()) if file else null
	if typeof(data) != TYPE_DICTIONARY or not data.has(formation_id):
		push_error("Formasyon bulunamadı: %s" % formation_id)
		return f
	f.display_name = data[formation_id].name
	for s in data[formation_id].slots:
		f.roles.append(s.role)
		f.slots.append(Vector2(s.x, s.z))
	return f


## Normalize koordinatı dünya koordinatına çevirir (deplasman takımı aynalanır).
static func to_world(n: Vector2, attack_sign: float) -> Vector3:
	return Vector3(n.x * PD.HALF_LENGTH * attack_sign, 0.0, n.y * PD.HALF_WIDTH * attack_sign)


static func to_norm(world: Vector3, attack_sign: float) -> Vector2:
	return Vector2(world.x * attack_sign / PD.HALF_LENGTH, world.z * attack_sign / PD.HALF_WIDTH)


## Başlama vuruşu konumu: kendi yarı sahada.
static func kickoff_position(slot: Vector2, attack_sign: float) -> Vector3:
	return to_world(Vector2(minf(slot.x, -0.04), slot.y), attack_sign)


## Faz ve top konumuna göre slotun hedef dünya konumu.
static func target_for(slot: Vector2, ball_pos: Vector3, attack_sign: float, phase: Phase) -> Vector3:
	var b := to_norm(ball_pos, attack_sign)
	var push := 0.0
	var width := 1.0
	match phase:
		Phase.ATTACK:
			push = 0.18
			width = 1.15
		Phase.DEFENSE:
			push = -0.12
			width = 0.8
	var nx := clampf(slot.x + b.x * 0.45 + push, -0.92, 0.88)
	var nz := clampf(slot.y * width + b.y * 0.3, -0.95, 0.95)
	return to_world(Vector2(nx, nz), attack_sign)
