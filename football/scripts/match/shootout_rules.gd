class_name ShootoutRules
extends RefCounted
## Penaltı atışları kuralları: takımlar sırayla 5'er atış; matematiksel olarak kesinleşince
## erken biter; 5'er atış sonunda eşitse ani ölüm (eşit sayıda atış sonrası fark olunca biter).

const ROUNDS := 5

var kicks := [[], []] # takım -> [true/false, ...]
var first_team := 0


func next_team() -> int:
	return first_team if kicks[first_team].size() == kicks[1 - first_team].size() else 1 - first_team


func record(team: int, scored: bool) -> void:
	kicks[team].append(scored)


func goals(team: int) -> int:
	return kicks[team].count(true)


func kicks_taken(team: int) -> int:
	return kicks[team].size()


func is_sudden_death() -> bool:
	return kicks[0].size() >= ROUNDS and kicks[1].size() >= ROUNDS and not (kicks[0].size() == ROUNDS and kicks[1].size() == ROUNDS and is_decided())


func is_decided() -> bool:
	var a := goals(0)
	var b := goals(1)
	var ka: int = kicks[0].size()
	var kb: int = kicks[1].size()
	if ka <= ROUNDS and kb <= ROUNDS:
		# Kalan atışların hepsi gol olsa bile yetişemiyorsa biter
		if a + (ROUNDS - ka) < b or b + (ROUNDS - kb) < a:
			return true
		if ka == ROUNDS and kb == ROUNDS:
			return a != b
		return false
	return ka == kb and a != b


func winner() -> int:
	if not is_decided():
		return -1
	return 0 if goals(0) > goals(1) else 1
