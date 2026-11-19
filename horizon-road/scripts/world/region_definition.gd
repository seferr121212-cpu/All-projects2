class_name RegionDefinition
extends Resource
## Data describing a region: identity, scene, look, weather odds and how it
## changes through the seasons.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const SEASON_KEYS: Array[String] = ["SEASON_SPRING", "SEASON_SUMMER", "SEASON_AUTUMN", "SEASON_WINTER"]
const SEASON_IDS: Array[String] = ["spring", "summer", "autumn", "winter"]

@export var id: StringName = &""
@export var name_key: String = ""
@export_file("*.tscn") var scene_path: String = ""
## Road distance from the "centre of the map" in km; travel time derives from it.
@export var map_position: Vector2 = Vector2.ZERO
@export var season: Season = Season.SUMMER
@export var palette: RegionPalette
## weather id -> relative weight (summer / default)
@export var weather_weights: Dictionary = {&"clear": 1.0}
@export var start_weather: StringName = &"partly_cloudy"
@export var start_hour: float = 7.0
@export_range(0.0, 2.0) var bird_density: float = 1.0
## MusicGenerator style: "blacksea" or "aegean".
@export var music_style: String = "blacksea"
## season id ("autumn", "winter"...) -> {"tint": [r,g,b], "snow": 0..1, "weights": {...}}
@export var season_profiles: Dictionary = {}


func profile_for(s: Season) -> Dictionary:
	return season_profiles.get(SEASON_IDS[s], {})


func weights_for(s: Season) -> Dictionary:
	return profile_for(s).get("weights", weather_weights)


func tint_for(s: Season) -> Color:
	var t: Array = profile_for(s).get("tint", [1.0, 1.0, 1.0])
	return Color(t[0], t[1], t[2])


func snow_for(s: Season) -> float:
	return float(profile_for(s).get("snow", 0.0))
