class_name PassTargeting
extends RefCounted
## Pas hedefi seçimi: bakılan yöne açı + mesafe + pas yolunun rakiplerce kapalı olması puanlanır.

enum Kind { SHORT, THROUGH, LOB }

const MAX_ANGLE_DEG := 70.0
const IDEAL_DISTANCE := {Kind.SHORT: 14.0, Kind.THROUGH: 22.0, Kind.LOB: 30.0}
const LANE_WIDTH := 1.6


## En iyi takım arkadaşının indeksini döndürür, uygun yoksa -1.
static func pick(from: Vector3, aim: Vector3, mates: Array[Vector3], opponents: Array[Vector3], kind: Kind) -> int:
	var aim_h := Vector3(aim.x, 0.0, aim.z).normalized()
	if aim_h == Vector3.ZERO:
		return -1
	var best := -1
	var best_score := -INF
	for i in mates.size():
		var s := score(from, aim_h, mates[i], opponents, kind)
		if s > best_score:
			best_score = s
			best = i
	return best if best_score > -INF else -1


static func score(from: Vector3, aim_h: Vector3, mate: Vector3, opponents: Array[Vector3], kind: Kind) -> float:
	var to := Vector3(mate.x - from.x, 0.0, mate.z - from.z)
	var dist := to.length()
	if dist < 2.0:
		return -INF
	var angle := rad_to_deg(aim_h.angle_to(to))
	if angle > MAX_ANGLE_DEG:
		return -INF
	var ideal: float = IDEAL_DISTANCE[kind]
	var s := cos(deg_to_rad(angle)) * 2.0 - absf(dist - ideal) / ideal * 0.6
	var lane_factor := 0.3 if kind == Kind.LOB else 1.0
	for o in opponents:
		s -= lane_block(from, mate, o) * 1.5 * lane_factor
	return s


## Rakip pas yoluna ne kadar yakın (0: uzak, 1: tam yolda).
static func lane_block(from: Vector3, to: Vector3, opp: Vector3) -> float:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var p := Vector2(opp.x, opp.z)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	if t <= 0.02 or t >= 0.98:
		return 0.0
	var d := p.distance_to(a + ab * t)
	return clampf(1.0 - d / LANE_WIDTH, 0.0, 1.0)
