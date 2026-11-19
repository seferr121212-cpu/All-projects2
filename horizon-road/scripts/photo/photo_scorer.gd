class_name PhotoScorer
extends RefCounted
## Judges a photo from the camera's point of view: which subjects are in
## frame and unblocked, how well the main one is placed (rule of thirds,
## horizon), whether it's in focus, and whether a special moment is captured.
## Exposure is judged afterwards from the real pixels (see `rate_exposure`).
## Rewarding rather than strict: there is always a minimum score.

const MOMENT_IDS: Array[StringName] = [
	&"MOMENT_SUNRISE", &"MOMENT_SUNSET", &"MOMENT_MIST", &"MOMENT_STARRY_NIGHT",
	&"MOMENT_LIGHTNING", &"MOMENT_RAIN", &"MOMENT_FIRST_SNOW",
]
const THIRDS: Array[Vector2] = [
	Vector2(1.0 / 3.0, 1.0 / 3.0), Vector2(2.0 / 3.0, 1.0 / 3.0),
	Vector2(1.0 / 3.0, 2.0 / 3.0), Vector2(2.0 / 3.0, 2.0 / 3.0),
]


## Returns a Dictionary with keys: subjects (Array of {id, name_key, category,
## screen, size, distance, weight}), main, content, composition, focus,
## moments, feedback (Array[String] translation keys).
static func evaluate(camera: Camera3D, focus_distance: float, blur: float, config: PhotoConfig) -> Dictionary:
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	var seen: Array[Dictionary] = []
	for node: Node in camera.get_tree().get_nodes_in_group(&"photo_subject"):
		var subject := node as PhotoSubject
		if subject == null or not subject.is_visible_in_tree():
			continue
		var info: Dictionary = _inspect(camera, subject, size, config)
		if not info.is_empty():
			seen.append(info)
	seen.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.weight > b.weight)

	var result: Dictionary = {
		"subjects": seen, "main": {}, "content": 0.15, "composition": 0.5,
		"focus": 1.0, "moments": detect_moments(camera), "feedback": [],
	}
	var horizon: float = _horizon_thirds(camera, size)
	if seen.is_empty():
		result.composition = 0.35 + 0.5 * horizon
		return result

	var main: Dictionary = seen[0]
	result.main = main
	# Distinct extra subjects add a little richness, capped.
	var extra_ids: Dictionary = {}
	for i: int in range(1, seen.size()):
		extra_ids[seen[i].id] = true
	result.content = clampf(main.weight + 0.08 * mini(extra_ids.size(), 3), 0.0, 1.0)

	var thirds: float = _thirds_score(main.screen)
	if main.category == PhotoSubject.Category.LANDSCAPE:
		thirds = maxf(thirds, horizon * 0.9)
	result.composition = thirds

	if blur > 0.01:
		var in_focus: bool = absf(main.distance - focus_distance) < maxf(focus_distance * 0.35, 2.0)
		result.focus = 1.0 if in_focus or main.distance > 80.0 and focus_distance > 60.0 else 0.35
	var feedback: Array[String] = []
	if thirds > 0.75:
		feedback.append("PHOTO_FB_GREAT_COMPOSITION")
	if result.focus < 0.5:
		feedback.append("PHOTO_FB_OUT_OF_FOCUS")
	if main.size < config.ideal_size_min * 0.5 and main.category != PhotoSubject.Category.LANDSCAPE:
		feedback.append("PHOTO_FB_TOO_SMALL")
	result.feedback = feedback
	return result


## Combines evaluation with the exposure rating (0..1) into the final score.
static func final_score(eval: Dictionary, exposure: float, config: PhotoConfig) -> int:
	var base: float = config.weight_content * eval.content \
			+ config.weight_composition * eval.composition \
			+ config.weight_focus * eval.focus \
			+ config.weight_exposure * exposure
	var bonus: float = config.moment_bonus * mini((eval.moments as Array).size(), 2)
	return clampi(roundi(base * 100.0 + bonus), config.min_score, 100)


static func stars(score: int, config: PhotoConfig) -> int:
	if score >= config.three_star_score:
		return 3
	return 2 if score >= config.two_star_score else 1


## Judges brightness of the captured image: well-exposed photos sit mid-range.
## Returns {rating: 0..1, mean: luminance, feedback: key or ""}.
static func rate_exposure(image: Image) -> Dictionary:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var total: float = 0.0
	var count: int = 0
	for gy: int in 18:
		for gx: int in 32:
			var c: Color = image.get_pixel(int((gx + 0.5) / 32.0 * w), int((gy + 0.5) / 18.0 * h))
			total += c.get_luminance()
			count += 1
	var mean: float = total / count
	var rating: float = 1.0
	var feedback: String = ""
	if mean < 0.14:
		rating = clampf(mean / 0.14, 0.2, 1.0)
		feedback = "PHOTO_FB_TOO_DARK"
	elif mean > 0.78:
		rating = clampf(1.0 - (mean - 0.78) / 0.22, 0.2, 1.0)
		feedback = "PHOTO_FB_TOO_BRIGHT"
	return {"rating": rating, "mean": mean, "feedback": feedback}


static func detect_moments(camera: Camera3D) -> Array[StringName]:
	var moments: Array[StringName] = []
	var w: WeatherProfile = WeatherManager.current
	var hour: float = TimeManager.time_of_day
	var forward: Vector3 = -camera.global_basis.z
	var sun_dir: Vector3 = TimeManager.get_sun_direction()
	var sun_in_view: bool = forward.angle_to(sun_dir) < deg_to_rad(camera.fov * 0.6) and sun_dir.y > -0.06
	if sun_in_view and hour < 9.0 and w.cloud_coverage < 0.8:
		moments.append(&"MOMENT_SUNRISE")
	elif sun_in_view and hour > 17.0 and w.cloud_coverage < 0.8:
		moments.append(&"MOMENT_SUNSET")
	if w.mist > 0.6 or (hour > 4.5 and hour < 8.5 and w.mist > 0.3):
		moments.append(&"MOMENT_MIST")
	if TimeManager.get_night_factor() > 0.8 and w.cloud_coverage < 0.45 and forward.y > 0.15:
		moments.append(&"MOMENT_STARRY_NIGHT")
	for atmo: Node in camera.get_tree().get_nodes_in_group(&"atmosphere"):
		if (atmo as AtmosphereController).get_flash() > 0.15:
			moments.append(&"MOMENT_LIGHTNING")
	if w.rain > 0.5:
		moments.append(&"MOMENT_RAIN")
	if w.snow > 0.5:
		moments.append(&"MOMENT_FIRST_SNOW")
	return moments


static func _inspect(camera: Camera3D, subject: PhotoSubject, size: Vector2, config: PhotoConfig) -> Dictionary:
	var point: Vector3 = subject.get_focus_point()
	if camera.is_position_behind(point):
		return {}
	var screen: Vector2 = camera.unproject_position(point) / size
	# Allow a subject partly outside the frame if its body reaches in.
	var distance: float = camera.global_position.distance_to(point)
	var angular: float = atan2(subject.radius, distance)
	var frac: float = angular / deg_to_rad(camera.fov * 0.5)
	var margin: float = clampf(frac * 0.5, 0.0, 0.3)
	if screen.x < -margin or screen.x > 1.0 + margin or screen.y < -margin or screen.y > 1.0 + margin:
		return {}
	if _occluded(camera, subject, point, distance):
		return {}
	var on_screen: float = 1.0 - clampf(maxf(absf(screen.x - 0.5), absf(screen.y - 0.5)) * 2.0 - 1.0, 0.0, 1.0)
	var size_factor: float = 1.0
	if frac < config.ideal_size_min:
		size_factor = lerpf(0.25, 1.0, frac / config.ideal_size_min)
	elif frac > config.ideal_size_max:
		size_factor = lerpf(1.0, 0.75, clampf((frac - config.ideal_size_max) / 0.6, 0.0, 1.0))
	return {
		"id": subject.subject_id,
		"name_key": subject.name_key,
		"category": subject.category,
		"screen": screen,
		"size": frac,
		"distance": distance,
		"weight": subject.value * size_factor * on_screen,
	}


static func _occluded(camera: Camera3D, subject: PhotoSubject, point: Vector3, distance: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, point)
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	if subject.own_body and hit.collider == subject.own_body:
		return false
	return camera.global_position.distance_to(hit.position) < distance - subject.radius


## 1 when the main subject sits on a thirds intersection, ~0.3 dead centre.
static func _thirds_score(screen: Vector2) -> float:
	var best: float = INF
	for p: Vector2 in THIRDS:
		best = minf(best, screen.distance_to(p))
	var lines: float = minf(minf(absf(screen.x - 1.0 / 3.0), absf(screen.x - 2.0 / 3.0)),
			minf(absf(screen.y - 1.0 / 3.0), absf(screen.y - 2.0 / 3.0)))
	var on_point: float = 1.0 - clampf(best / 0.22, 0.0, 1.0)
	var on_line: float = 1.0 - clampf(lines / 0.12, 0.0, 1.0)
	return clampf(maxf(on_point, on_line * 0.7) * 0.75 + 0.25, 0.0, 1.0)


## How close the horizon line is to a third of the frame (landscape rule).
static func _horizon_thirds(camera: Camera3D, size: Vector2) -> float:
	var flat_forward := Vector3(-camera.global_basis.z.x, 0.0, -camera.global_basis.z.z)
	if flat_forward.length() < 0.1:
		return 0.0
	var far_point: Vector3 = camera.global_position + flat_forward.normalized() * 5000.0
	if camera.is_position_behind(far_point):
		return 0.0
	var y: float = camera.unproject_position(far_point).y / size.y
	if y < 0.0 or y > 1.0:
		return 0.0
	var d: float = minf(absf(y - 1.0 / 3.0), absf(y - 2.0 / 3.0))
	return 1.0 - clampf(d / 0.15, 0.0, 1.0)
