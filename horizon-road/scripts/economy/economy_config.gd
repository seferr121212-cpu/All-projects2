class_name EconomyConfig
extends Resource
## Every money and relationship number in one place, so balance can be
## tuned without touching code.

@export_group("Start")
@export var starting_money: int = 50

@export_group("Relationships")
## Points needed for each level: Stranger, Acquaintance, Friend, Close friend.
@export var level_thresholds: PackedInt32Array = PackedInt32Array([0, 20, 50, 100])
@export var level_keys: PackedStringArray = PackedStringArray(["REL_STRANGER", "REL_ACQUAINTANCE", "REL_FRIEND", "REL_CLOSE_FRIEND"])
@export var points_first_meeting: int = 5
@export var points_job_done: int = 12
@export var points_photo_shown: int = 4
@export var points_photo_sold_interest: int = 8

@export_group("Tea harvest")
@export var tea_target_bunches: int = 15
@export var tea_pay_per_bunch: int = 4
@export var tea_completion_bonus: int = 20
@export var tea_golden_bonus: int = 6

@export_group("Photo sales")
## Multiplier on a photo's value when it matches what the buyer loves.
@export var photo_interest_multiplier: float = 1.0
@export var photo_other_multiplier: float = 0.5
## Extra price per relationship level above stranger (friends pay better).
@export var photo_friend_bonus_per_level: float = 0.1
@export var photo_sales_per_day: int = 1

@export_group("Fuel & upgrades")
@export var base_tank_capacity: float = 45.0
## Litres per kilometre at full throttle on the road.
@export var fuel_per_km: float = 2.0
@export var fuel_price_per_liter: float = 1.5
## Top speed fraction when the tank is empty (no penalty, just slow).
@export var empty_tank_speed: float = 0.35
## Upgrade discount per relationship level with the seller.
@export var friend_discount_per_level: float = 0.05

@export_group("Rest")
@export var wake_hour: float = 7.0
@export var nap_hours: float = 3.0
## Seconds between automatic saves while playing.
@export var autosave_interval: float = 240.0

@export_group("Net haul")
@export var net_pulls: int = 12
## fish id -> [price, weight]
@export var fish_table: Dictionary = {
	"FISH_ISTAVRIT": [4, 40], "FISH_BARBUN": [7, 25], "FISH_CIPURA": [9, 18],
	"FISH_LEVREK": [10, 14], "FISH_LAGOS": [25, 3],
}
@export var net_fish_min: int = 4
@export var net_fish_max: int = 8
@export var net_completion_bonus: int = 15
