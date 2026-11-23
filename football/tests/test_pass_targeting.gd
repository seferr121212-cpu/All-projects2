extends "res://tests/test_case.gd"
## Pas hedefi seçimi testleri.

const K = preload("res://scripts/player/pass_targeting.gd").Kind


func _v(list: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.assign(list)
	return out


func test_picks_mate_in_aim_direction() -> void:
	var mates := _v([Vector3(12, 0, 0), Vector3(0, 0, 12), Vector3(-12, 0, 0)])
	check(PassTargeting.pick(Vector3.ZERO, Vector3.RIGHT, mates, _v([]), K.SHORT) == 0, "Sağa bakarken sağdaki seçilmeli")
	check(PassTargeting.pick(Vector3.ZERO, Vector3.BACK, mates, _v([]), K.SHORT) == 1, "+Z'ye bakarken +Z'deki seçilmeli")


func test_none_outside_cone() -> void:
	var mates := _v([Vector3(-12, 0, 0)])
	check(PassTargeting.pick(Vector3.ZERO, Vector3.RIGHT, mates, _v([]), K.SHORT) == -1, "Arkadaki arkadaş seçilmemeli")


func test_prefers_open_lane() -> void:
	var mates := _v([Vector3(14, 0, 2), Vector3(14, 0, -2)])
	var opps := _v([Vector3(7, 0, 1)])
	check(PassTargeting.pick(Vector3.ZERO, Vector3.RIGHT, mates, opps, K.SHORT) == 1, "Pas yolu açık olan seçilmeli")


func test_lane_block_values() -> void:
	check_near(PassTargeting.lane_block(Vector3.ZERO, Vector3(10, 0, 0), Vector3(5, 0, 0)), 1.0, 0.001, "Tam yoldaki rakip")
	check_near(PassTargeting.lane_block(Vector3.ZERO, Vector3(10, 0, 0), Vector3(5, 0, 5)), 0.0, 0.001, "Uzaktaki rakip")
