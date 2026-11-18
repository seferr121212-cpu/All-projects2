class_name RegionDefinition
extends Resource
## Data describing a region: identity, season, look and weather odds.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const SEASON_KEYS: Array[String] = ["SEASON_SPRING", "SEASON_SUMMER", "SEASON_AUTUMN", "SEASON_WINTER"]

@export var id: StringName = &""
@export var name_key: String = ""
@export var season: Season = Season.SUMMER
@export var palette: RegionPalette
## weather id -> relative weight
@export var weather_weights: Dictionary = {&"clear": 1.0}
@export var start_weather: StringName = &"partly_cloudy"
@export var start_hour: float = 7.0
@export_range(0.0, 2.0) var bird_density: float = 1.0
