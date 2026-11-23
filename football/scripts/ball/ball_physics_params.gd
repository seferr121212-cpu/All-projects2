class_name BallPhysicsParams
extends Resource
## Top fiziği parametreleri (editörden veya .tres dosyasından ayarlanabilir).

@export var mass := 0.43 # kg (FIFA: 410-450 g)
@export var radius := 0.11 # m
@export var air_density := 1.2 # kg/m³
@export var drag_coefficient := 0.25 # Cd
## Magnus çarpanı: F = 0.5·ρ·A·r·k·(ω × v)
@export var magnus_coefficient := 1.0
## Magnus kuvvetinin üst sınırı (kaldırma katsayısı Cl olarak)
@export var max_lift_coefficient := 0.35
@export var spin_decay := 0.15 # havada spin sönümü (1/s)
## Yerde yuvarlanma direnç katsayısı (çim). Yavaşlama = k·g
@export var rolling_resistance := 0.17
