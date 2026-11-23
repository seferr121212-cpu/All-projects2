class_name OffsideRule
extends RefCounted
## Ofsayt pozisyonu (Kural 11, sadeleştirilmiş ama doğru):
## Oyuncu rakip yarı sahadaysa VE toptan VE sondan ikinci rakipten (kaleci dahil)
## rakip kale çizgisine daha yakınsa ofsayt pozisyonundadır. Aynı hizada olmak ofsayt değildir.
## Taç, korner ve aut atışından doğrudan ofsayt olmaz (hakem bunu ayrıca uygular).


## attack_sign: hücumcunun hücum yönü. defenders: rakip takımın TÜM oyuncuları (kaleci dahil).
static func is_offside_position(attacker: Vector3, attack_sign: float, ball: Vector3, defenders: Array[Vector3]) -> bool:
	var ax := attacker.x * attack_sign
	if ax <= 0.0: # kendi yarı sahası (orta çizgi dahil)
		return false
	if ax <= ball.x * attack_sign: # topla aynı hizada veya gerisinde
		return false
	return ax > second_last_defender_x(attack_sign, defenders)


## Sondan ikinci rakibin hücum yönündeki konumu (rakip yoksa kale çizgisi).
static func second_last_defender_x(attack_sign: float, defenders: Array[Vector3]) -> float:
	var xs: Array[float] = []
	for d in defenders:
		xs.append(d.x * attack_sign)
	xs.sort()
	if xs.size() >= 2:
		return xs[xs.size() - 2]
	return PitchDimensions.HALF_LENGTH
