class_name PlayerStats
extends Resource
## Oyuncu istatistikleri (1-99). İleride players.json'dan doldurulacak.

@export var player_name := "Oyuncu"
@export var number := 0
@export_range(1, 99) var pace := 70
@export_range(1, 99) var shooting := 70
@export_range(1, 99) var passing := 70
@export_range(1, 99) var dribbling := 70
@export_range(1, 99) var defending := 70
@export_range(1, 99) var physical := 70
@export_range(1, 99) var goalkeeping := 20
@export var max_stamina := 100.0


func run_speed() -> float:
	return 5.0 + pace * 0.02 # 70 -> 6.4 m/s


func sprint_speed() -> float:
	return 6.8 + pace * 0.03 # 70 -> 8.9 m/s, 99 -> 9.77 m/s


func acceleration() -> float:
	return 9.0 + pace * 0.06 # m/s²


static func ratio(value: int) -> float:
	return clampf(value / 100.0, 0.0, 1.0)
