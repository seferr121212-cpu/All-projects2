extends Node
## In-game clock. Owns time of day, sun position and the day phases so that
## lighting, audio, NPC schedules and UI all agree on "what time it is".

signal hour_changed(hour: int)
signal phase_changed(phase: DayPhase)
signal day_changed(day: int)

enum DayPhase { NIGHT, DAWN, MORNING, NOON, GOLDEN_HOUR, DUSK }

const HOURS_PER_DAY: float = 24.0
const PHASE_KEYS: Array[String] = [
	"PHASE_NIGHT", "PHASE_DAWN", "PHASE_MORNING", "PHASE_NOON", "PHASE_GOLDEN_HOUR", "PHASE_DUSK"
]

## Real minutes for one full in-game day.
@export var day_length_minutes: float = 14.0
@export var sunrise_hour: float = 6.0
@export var sunset_hour: float = 20.0
## Highest sun elevation at noon, in degrees.
@export var max_sun_elevation_deg: float = 62.0

var time_of_day: float = 7.0
var day: int = 1
## Debug multiplier on top of the normal rate.
var time_scale: float = 1.0
var paused: bool = false

var _last_hour: int = -1
var _last_phase: DayPhase = DayPhase.NIGHT


func _ready() -> void:
	_last_hour = int(time_of_day)
	_last_phase = get_phase()


func _process(delta: float) -> void:
	if paused:
		return
	advance_hours(delta * hours_per_second())


func hours_per_second() -> float:
	return HOURS_PER_DAY / (day_length_minutes * 60.0) * time_scale


func advance_hours(hours: float) -> void:
	time_of_day += hours
	while time_of_day >= HOURS_PER_DAY:
		time_of_day -= HOURS_PER_DAY
		day += 1
		day_changed.emit(day)
	_emit_changes()


func set_time(hour: float) -> void:
	time_of_day = fposmod(hour, HOURS_PER_DAY)
	_emit_changes()


func get_phase(hour: float = time_of_day) -> DayPhase:
	if hour < sunrise_hour - 1.0:
		return DayPhase.NIGHT
	if hour < sunrise_hour + 1.5:
		return DayPhase.DAWN
	if hour < 11.0:
		return DayPhase.MORNING
	if hour < sunset_hour - 2.5:
		return DayPhase.NOON
	if hour < sunset_hour + 0.25:
		return DayPhase.GOLDEN_HOUR
	if hour < sunset_hour + 1.25:
		return DayPhase.DUSK
	return DayPhase.NIGHT


func get_phase_key() -> String:
	return PHASE_KEYS[get_phase()]


func get_clock_string() -> String:
	var total_minutes: int = int(time_of_day * 60.0)
	return "%02d:%02d" % [total_minutes / 60, total_minutes % 60]


## Sine of the sun elevation: >0 above horizon, <0 below.
func get_sun_height(hour: float = time_of_day) -> float:
	return get_sun_direction(hour).y


## Unit vector pointing from the ground towards the sun.
## The sun rises in the east (+X), passes south (+Z) and sets in the west (-X).
func get_sun_direction(hour: float = time_of_day) -> Vector3:
	var day_span: float = sunset_hour - sunrise_hour
	# t runs 0..1 over daylight and continues below the horizon at night.
	var t: float = (hour - sunrise_hour) / day_span
	if hour < sunrise_hour:
		t = (hour + HOURS_PER_DAY - sunrise_hour) / day_span
	var max_elev: float = deg_to_rad(max_sun_elevation_deg)
	var elevation: float = sin(t * PI) * max_elev
	var azimuth: float = t * PI
	if t > 1.0:
		# Night arc: dip below the horizon and come back round to the east.
		var night_t: float = (t - 1.0) / ((HOURS_PER_DAY - day_span) / day_span)
		elevation = -sin(night_t * PI) * deg_to_rad(40.0)
		azimuth = PI + night_t * PI
	var horizontal := Vector3(cos(azimuth), 0.0, sin(azimuth) * 0.6).normalized()
	return (horizontal * cos(elevation) + Vector3.UP * sin(elevation)).normalized()


## 0 during the day, 1 at full night. Used for window lights, headlights, stars.
func get_night_factor(hour: float = time_of_day) -> float:
	return 1.0 - smoothstep(-0.10, 0.06, get_sun_height(hour))


func to_dict() -> Dictionary:
	return {"time_of_day": time_of_day, "day": day, "day_length_minutes": day_length_minutes}


func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	day_length_minutes = float(data.get("day_length_minutes", day_length_minutes))
	set_time(float(data.get("time_of_day", 7.0)))


func _emit_changes() -> void:
	var hour: int = int(time_of_day)
	if hour != _last_hour:
		_last_hour = hour
		hour_changed.emit(hour)
	var phase: DayPhase = get_phase()
	if phase != _last_phase:
		_last_phase = phase
		phase_changed.emit(phase)
