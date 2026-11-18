class_name WeatherProfile
extends Resource
## One weather condition. WeatherManager blends between two of these, so every
## field must be meaningful when linearly interpolated.

@export var id: StringName = &"clear"
@export var name_key: String = "WEATHER_CLEAR"

@export_group("Sky")
@export_range(0.0, 1.0) var cloud_coverage: float = 0.15
@export_range(0.0, 1.0) var cloud_darkness: float = 0.0
## Multiplier on direct sunlight (overcast skies flatten the light).
@export_range(0.0, 1.0) var sun_strength: float = 1.0
## Multiplier on final colour saturation (grey days look muted).
@export_range(0.0, 1.5) var saturation: float = 1.0

@export_group("Fog")
## Added on top of the region's base distance fog.
@export_range(0.0, 0.05, 0.0001) var fog_density: float = 0.0
@export_range(0.0, 0.1, 0.0005) var volumetric_fog_density: float = 0.004
## Strength of low mist banks in valleys (0..1).
@export_range(0.0, 1.0) var mist: float = 0.15

@export_group("Precipitation & wind")
@export_range(0.0, 1.0) var rain: float = 0.0
@export_range(0.0, 1.0) var snow: float = 0.0
@export_range(0.0, 1.0) var wind: float = 0.25
## Ground wetness this weather drives towards.
@export_range(0.0, 1.0) var wetness: float = 0.0
@export_range(0.0, 1.0) var lightning: float = 0.0

@export_group("Ambience")
@export_range(0.0, 1.0) var birds: float = 1.0


const BLENDED_FIELDS: Array[StringName] = [
	&"cloud_coverage", &"cloud_darkness", &"sun_strength", &"saturation",
	&"fog_density", &"volumetric_fog_density", &"mist",
	&"rain", &"snow", &"wind", &"wetness", &"lightning", &"birds",
]


## Writes lerp(a, b, t) into this profile's numeric fields.
func blend_from(a: WeatherProfile, b: WeatherProfile, t: float) -> void:
	for field: StringName in BLENDED_FIELDS:
		set(field, lerpf(a.get(field), b.get(field), t))


func copy_from(other: WeatherProfile) -> void:
	blend_from(other, other, 0.0)
	id = other.id
	name_key = other.name_key
