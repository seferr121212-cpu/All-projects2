extends Node
## Central weather state. Picks weather from the region's weighted list,
## blends smoothly in game time and publishes shader globals (wetness, wind,
## snow). Visual/audio systems read `current` every frame.

signal weather_changed(weather_id: StringName)

const PROFILE_PATHS: Array[String] = [
	"res://data/weather/clear.tres",
	"res://data/weather/partly_cloudy.tres",
	"res://data/weather/fog.tres",
	"res://data/weather/rain.tres",
	"res://data/weather/storm.tres",
	"res://data/weather/snow.tres",
]
## Ground gets wet much faster than it dries.
const WETTING_RATE_PER_HOUR: float = 1.2
const DRYING_RATE_PER_HOUR: float = 0.25

var profiles: Dictionary[StringName, WeatherProfile] = {}
## Blended live values. Never assign; read only.
var current: WeatherProfile = WeatherProfile.new()
var target_id: StringName = &"clear"
var auto_change: bool = true
var wetness: float = 0.0

var _from: WeatherProfile = WeatherProfile.new()
var _blend_t: float = 1.0
var _blend_hours: float = 1.0
var _hours_until_change: float = 4.0
var _weights: Dictionary[StringName, float] = {&"clear": 1.0}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for path: String in PROFILE_PATHS:
		var profile: WeatherProfile = load(path)
		profiles[profile.id] = profile
	current.copy_from(profiles[&"clear"])
	_from.copy_from(current)


func _process(delta: float) -> void:
	var hours: float = delta * TimeManager.hours_per_second()
	if TimeManager.paused:
		# Keep blends moving when time is frozen (debug/photo) so changes stay visible.
		hours = delta / 60.0
	_update_blend(hours)
	_update_wetness(hours)
	if auto_change and not TimeManager.paused:
		_hours_until_change -= hours
		if _hours_until_change <= 0.0:
			set_weather(_pick_weighted(), _rng.randf_range(0.6, 1.2))
	_publish_globals()


## Called by a region on load: which weathers can appear there and how often.
func configure_for_region(weights: Dictionary, start_weather: StringName = &"") -> void:
	_weights.clear()
	for key: Variant in weights:
		var id := StringName(key)
		if profiles.has(id):
			_weights[id] = float(weights[key])
	if _weights.is_empty():
		_weights[&"clear"] = 1.0
	set_weather(start_weather if start_weather != &"" else _pick_weighted(), 0.0)


func set_weather(id: StringName, transition_hours: float = 0.75) -> void:
	if not profiles.has(id):
		push_warning("Unknown weather '%s'" % id)
		return
	_from.copy_from(current)
	target_id = id
	_blend_hours = maxf(transition_hours, 0.0001)
	_blend_t = 0.0 if transition_hours > 0.0 else 1.0
	_hours_until_change = _rng.randf_range(2.5, 6.0)
	if transition_hours <= 0.0:
		current.copy_from(profiles[id])
		wetness = current.wetness
	current.id = id
	current.name_key = profiles[id].name_key
	weather_changed.emit(id)


func get_weather_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for path: String in PROFILE_PATHS:
		ids.append(StringName(path.get_file().get_basename()))
	return ids


func to_dict() -> Dictionary:
	return {"weather": String(target_id), "wetness": wetness, "auto": auto_change}


func from_dict(data: Dictionary) -> void:
	auto_change = bool(data.get("auto", true))
	set_weather(StringName(data.get("weather", "clear")), 0.0)
	wetness = float(data.get("wetness", wetness))


func _update_blend(hours: float) -> void:
	if _blend_t >= 1.0:
		return
	_blend_t = minf(_blend_t + hours / _blend_hours, 1.0)
	var eased: float = smoothstep(0.0, 1.0, _blend_t)
	current.blend_from(_from, profiles[target_id], eased)


func _update_wetness(hours: float) -> void:
	var rate: float = WETTING_RATE_PER_HOUR if current.wetness > wetness else DRYING_RATE_PER_HOUR
	wetness = move_toward(wetness, current.wetness, rate * hours)


func _publish_globals() -> void:
	RenderingServer.global_shader_parameter_set(&"wetness", wetness)
	RenderingServer.global_shader_parameter_set(&"wind_strength", current.wind)
	RenderingServer.global_shader_parameter_set(&"snow_cover", current.snow)


func _pick_weighted() -> StringName:
	var total: float = 0.0
	for w: float in _weights.values():
		total += w
	var roll: float = _rng.randf() * total
	for id: StringName in _weights:
		roll -= _weights[id]
		if roll <= 0.0:
			return id
	return _weights.keys()[0]
