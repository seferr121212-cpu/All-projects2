class_name AIDifficulty
extends Resource
## Zorluk parametreleri: tepki süresi ve karar kalitesi. data/settings.json'dan yüklenir.

const SETTINGS_PATH := "res://data/settings.json"

@export var level_name := "medium"
@export var reaction_time := 0.25 # s: kararlar arası en kısa süre
@export var decision_noise := 0.18 # fayda puanlarına eklenen rastgelelik
@export var accuracy_bonus := 0 # pas/şut becerisine eklenir
@export var press_intensity := 0.75 # 0..1: pres yapan oyuncunun hızı/ısrarı
@export var tackle_chance := 0.3 # her karar anında müdahale denemesi olasılığı
@export var gk_reaction := 0.2 # s: kalecinin şuta tepki gecikmesi
@export var gk_skill_bonus := 0


static func load_level(level: String) -> AIDifficulty:
	var d := AIDifficulty.new()
	d.level_name = level
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return d
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("difficulty_levels"):
		return d
	var levels: Dictionary = data.difficulty_levels
	if not levels.has(level):
		push_warning("Bilinmeyen zorluk: %s" % level)
		return d
	for key in levels[level]:
		d.set(key, levels[level][key])
	return d


static func default_level() -> String:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f:
		var data = JSON.parse_string(f.get_as_text())
		if typeof(data) == TYPE_DICTIONARY and data.has("difficulty"):
			return data.difficulty
	return "medium"
