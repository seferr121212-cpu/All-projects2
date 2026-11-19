class_name DevCli
extends Node
## Command-line hooks for automated checks (screenshots, drive tests, FPS).
## Only active when user args are passed after `--`, e.g.
##   godot -- --hour=18.5 --weather=fog --shot=/tmp/a.png
## Options: --hour --weather --shot --wait (frames) --camyaw --campitch
##          --camdist --cockpit --drive (seconds of throttle) --steer
##          --bench (seconds) --walk (exit van, walk forward N seconds)
##          --camper=x,z,heading --probe --locale --stay
##          --photo --aim --thirds --fov --aperture --filter --ev --shoot=N --journal[=collection] --detail

var _args: Dictionary = {}
var _frames: int = 0


static func is_requested() -> bool:
	return not OS.get_cmdline_user_args().is_empty()


func _ready() -> void:
	for raw: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = raw.trim_prefix("--").split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	print("[DevCli] args: ", _args)
	await get_tree().process_frame
	await get_tree().process_frame
	await _apply_world_settings()
	if _args.has("drive"):
		await _drive_test(float(_args["drive"]), float(_args.get("steer", "0")))
	if _args.has("walk"):
		await _walk_test(float(_args["walk"]))
	_apply_camera()
	if _args.has("photo"):
		await _photo_test()
	if _args.has("journal"):
		var journal := get_tree().current_scene.find_child("Journal", true, false) as Journal
		var photo_mode := get_tree().current_scene.find_child("PhotoMode", true, false) as PhotoMode
		photo_mode.exit()
		journal.open()
		if _args.has("detail") and not GameState.album.entries.is_empty():
			journal._show_detail(GameState.album.entries[GameState.album.entries.size() - 1])
		elif _args["journal"] == "collection":
			journal._tabs.current_tab = 1
	if _args.has("probe"):
		await _probe()
	if _args.has("bench"):
		await _bench(float(_args["bench"]))
	var wait: int = int(_args.get("wait", "30"))
	for i: int in wait:
		await get_tree().process_frame
	if _args.has("shot"):
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var err: Error = img.save_png(_args["shot"])
		print("[DevCli] screenshot %s -> %s" % [_args["shot"], error_string(err)])
	if not _args.has("stay"):
		get_tree().quit()


func _apply_world_settings() -> void:
	if _args.has("hour"):
		TimeManager.set_time(float(_args["hour"]))
		TimeManager.paused = true
	if _args.has("weather"):
		WeatherManager.auto_change = false
		WeatherManager.set_weather(StringName(_args["weather"]), 0.0)
	if _args.has("locale"):
		Localization.set_locale(_args["locale"])
	if _args.has("camper"):
		# --camper=x,z,heading_degrees
		var v: PackedFloat64Array = _args["camper"].split_floats(",")
		var camper := get_tree().current_scene.find_child("Camper", true, false) as CamperController
		var y: float = GameState.current_region.get_ground_height(v[0], v[1]) + 0.5
		camper.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(v[2])), Vector3(v[0], y, v[1]))
		var cam := get_tree().current_scene.find_child("FollowCamera", true, false) as FollowCamera
		cam.set_target(camper, true)
		for i: int in 10:
			await get_tree().physics_frame


func _apply_camera() -> void:
	var cam := get_tree().current_scene.find_child("FollowCamera", true, false) as FollowCamera
	if cam == null:
		return
	if _args.has("cockpit"):
		cam.toggle_mode()
	if _args.has("camyaw"):
		cam.yaw = cam.target.global_rotation.y + deg_to_rad(float(_args["camyaw"]))
		cam._idle_time = 0.0
	if _args.has("campitch"):
		cam.pitch = deg_to_rad(float(_args["campitch"]))
	if _args.has("camdist"):
		cam.vehicle_distance = float(_args["camdist"])
		cam.walker_distance = float(_args["camdist"])


func _drive_test(seconds: float, steer: float) -> void:
	var camper := get_tree().current_scene.find_child("Camper", true, false) as CamperController
	var start: Vector3 = camper.global_position
	Input.action_press(&"accelerate")
	if steer != 0.0:
		Input.action_press(&"steer_left" if steer > 0.0 else &"steer_right", absf(steer))
	var t: float = 0.0
	var max_kmh: float = 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		max_kmh = maxf(max_kmh, camper.get_speed_kmh())
	Input.action_release(&"accelerate")
	Input.action_release(&"steer_left")
	Input.action_release(&"steer_right")
	print("[DevCli] drive: %.1fs travelled %.1f m, max %.1f km/h, on_floor=%s, surface=%s, y=%.2f ground=%.2f" % [
		seconds, start.distance_to(camper.global_position), max_kmh, camper.is_on_floor(),
		HighlandTerrain.Surface.keys()[camper.surface], camper.global_position.y,
		GameState.current_region.get_ground_height(camper.global_position.x, camper.global_position.z)])


func _walk_test(seconds: float) -> void:
	var camper := get_tree().current_scene.find_child("Camper", true, false) as CamperController
	for i: int in 90:
		await get_tree().physics_frame
		if camper.is_stopped():
			break
	_press_once(&"interact")
	await get_tree().physics_frame
	print("[DevCli] exit vehicle -> mode=%s" % GameState.PlayerMode.keys()[GameState.player_mode])
	var walker := get_tree().current_scene.find_child("Walker", true, false) as WalkerController
	var start: Vector3 = walker.global_position
	Input.action_press(&"move_forward")
	var t: float = 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release(&"move_forward")
	print("[DevCli] walk: travelled %.1f m, on_floor=%s" % [start.distance_to(walker.global_position), walker.is_on_floor()])


func _probe() -> void:
	for i: int in 10:
		await get_tree().process_frame
	var cam := get_tree().current_scene.find_child("FollowCamera", true, false) as FollowCamera
	var arm: SpringArm3D = cam.get_node(^"SpringArm3D")
	print("[DevCli] probe: pivot=%s target=%s hit_len=%.2f/%.2f cam=%s" % [cam.global_position, cam.target.global_position, arm.get_hit_length(), arm.spring_length, cam.camera.global_position])
	var query := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + cam.global_basis.z * 9.0)
	var hit: Dictionary = cam.get_world_3d().direct_space_state.intersect_ray(query)
	print("[DevCli] probe ray: ", hit.get("collider"), " ", hit.get("position"))
	var camper := get_tree().current_scene.find_child("Camper", true, false) as CamperController
	print("[DevCli] probe camper: headlights=%s night=%.2f surface=%s" % [camper.headlights_on, TimeManager.get_night_factor(), HighlandTerrain.Surface.keys()[camper.surface]])


## --photo [--aim=SUBJECT_ID|x,y,z] [--fov] [--aperture=i] [--filter=i] [--ev] [--shoot=N]
func _photo_test() -> void:
	var photo := get_tree().current_scene.find_child("PhotoMode", true, false) as PhotoMode
	photo.enter()
	await get_tree().process_frame
	var cam: Camera3D = photo._camera
	if _args.has("aim"):
		var target := Vector3.ZERO
		var aim: String = _args["aim"]
		if aim.begins_with("SUBJ_"):
			for n: Node in get_tree().get_nodes_in_group(&"photo_subject"):
				if String((n as PhotoSubject).subject_id) == aim:
					target = (n as PhotoSubject).get_focus_point()
					break
		else:
			var v: PackedFloat64Array = aim.split_floats(",")
			target = Vector3(v[0], v[1], v[2])
		var dir: Vector3 = (target - cam.global_position).normalized()
		photo._yaw = atan2(-dir.x, -dir.z)
		photo._pitch = asin(clampf(dir.y, -1.0, 1.0))
		# Nudge so the subject lands near a thirds point instead of dead centre.
		if _args.has("thirds"):
			photo._yaw += deg_to_rad(photo.fov * 0.16 * (16.0 / 9.0))
	if _args.has("fov"):
		photo.fov = float(_args["fov"])
	if _args.has("aperture"):
		photo.aperture_index = int(_args["aperture"])
	if _args.has("filter"):
		photo.filter_index = int(_args["filter"])
	if _args.has("ev"):
		photo.exposure_ev = float(_args["ev"])
	for i: int in 20:
		await get_tree().process_frame
	for n: int in int(_args.get("shoot", "0")):
		await photo.shoot()
		var e: Dictionary = photo.last_entry
		var ids: Array = (e.subject_list as Array).map(func(x: Dictionary) -> String: return x.id)
		print("[DevCli] photo: score=%d stars=%d subjects=%s new=%s breakdown=%s feedback=%s value=%d file=%s" % [
			e.score, e.stars, ids, e.new_subjects, e.breakdown, e.feedback, e.value, e.path])
		for i: int in 5:
			await get_tree().process_frame
	print("[DevCli] album entries=%d discovered=%d" % [GameState.album.entries.size(), GameState.album.discovered.size()])


func _press_once(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _bench(seconds: float) -> void:
	var frames: int = 0
	var start: int = Time.get_ticks_usec()
	while (Time.get_ticks_usec() - start) < seconds * 1_000_000.0:
		await get_tree().process_frame
		frames += 1
	var elapsed: float = (Time.get_ticks_usec() - start) / 1_000_000.0
	print("[DevCli] bench: %d frames in %.2fs = %.1f FPS" % [frames, elapsed, frames / elapsed])
