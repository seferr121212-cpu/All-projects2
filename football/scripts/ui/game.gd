extends Node
## Oyun geneli (autoload "Game"): ayarlar, tema, mod ve maç yapılandırması, sahne geçişleri.

enum Mode { QUICK_MATCH, PENALTIES, TRAINING }

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const TEAM_SELECT := "res://scenes/ui/team_select.tscn"
const SETTINGS := "res://scenes/ui/settings_menu.tscn"
const SCENES := {
	Mode.QUICK_MATCH: "res://scenes/match.tscn",
	Mode.PENALTIES: "res://scenes/penalty_shootout.tscn",
	Mode.TRAINING: "res://scenes/training.tscn",
}

var settings := SettingsStore.new()
var mode := Mode.QUICK_MATCH
## Menülerden seçilen maç ayarları. Boşsa sahneler kendi varsayılanlarını kullanır.
var match_config := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings.capture_default_bindings()
	settings.load_from()
	settings.apply(get_tree())
	get_tree().root.theme = UITheme.build()


func default_config() -> Dictionary:
	return {
		"home": "kuzey", "away": "liman", "formation": "", "human_team": 0,
		"half_minutes": 5.0, "difficulty": AIDifficulty.default_level(), "replay": true, "night": false,
	}


func open_team_select(m: Mode) -> void:
	mode = m
	get_tree().change_scene_to_file(TEAM_SELECT)


func start(m: Mode, config: Dictionary) -> void:
	mode = m
	match_config = config
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENES[m])


func restart() -> void:
	start(mode, match_config)


func go_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)


func open_settings() -> void:
	get_tree().change_scene_to_file(SETTINGS)
