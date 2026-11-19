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
	if _args.has("smoke"):
		await _smoke_test(float(_args["smoke"]))
	if _args.has("atdoor"):
		await _at_door()
	_apply_camera()
	if _args.has("photo"):
		await _photo_test()
	if _args.has("story"):
		await _story_test(_args.get("stop", ""))
	if _args.has("workshop"):
		await _workshop_test(_args.get("stop", ""))
	if _args.has("interior"):
		await _interior_test(_args.get("stop", ""))
	if _args.has("fishing"):
		await _fishing_test(_args.get("stop", ""))
	if _args.has("job"):
		await _job_test(_args["job"], _args.get("stop", ""))
	if _args.has("cafe"):
		await _cafe_test(_args.get("stop", ""))
	if _args.has("travel"):
		await _travel_test(_args["travel"])
	if _args.has("sketch"):
		await _sketch_test(_args.get("stop", ""))
	if _args.has("title"):
		GameState.show_title()
	if _args.has("pause"):
		var pm := get_tree().current_scene.find_child("PauseMenu", true, false) as PauseMenu
		pm.open()
		if _args.has("settings"):
			pm._panel.visible = false
			pm._settings.open()
			pm._settings._tabs.current_tab = int(_args["settings"])
	if _args.has("curtain"):
		var curtain := LoadingScreen.new()
		add_child(curtain)
		curtain.show_journey(&"blacksea_highland", &"aegean_village", GameState.travel_hours(&"blacksea_highland", &"aegean_village"), GameState.travel_km(&"blacksea_highland", &"aegean_village"))
	if _args.has("map"):
		(get_tree().current_scene.find_child("MapPanel", true, false) as MapPanel).open()
	if _args.has("journal") and not _args.has("sketch"):
		var journal := get_tree().current_scene.find_child("Journal", true, false) as Journal
		var photo_mode := get_tree().current_scene.find_child("PhotoMode", true, false) as PhotoMode
		photo_mode.exit()
		journal.open()
		if _args.has("detail") and not GameState.album.entries.is_empty():
			journal._show_detail(GameState.album.entries[GameState.album.entries.size() - 1])
		elif _args["journal"] == "collection":
			journal._tabs.current_tab = 1
		elif _args["journal"] == "quests":
			journal._tabs.current_tab = 4
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
	if _args.has("season"):
		TimeManager.force_season(["spring", "summer", "autumn", "winter"].find(_args["season"]))
	if _args.has("weather"):
		WeatherManager.auto_change = false
		WeatherManager.set_weather(StringName(_args["weather"]), 0.0)
	if _args.has("locale"):
		Localization.set_locale(_args["locale"])
	if _args.has("money"):
		GameState.money = int(_args["money"])
	if _args.has("upgrades"):
		for pair: String in _args["upgrades"].split(","):
			var kv: PackedStringArray = pair.split(":")
			GameState.upgrades[kv[0]] = int(kv[1])
		GameState.upgrades_changed.emit()
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
	print("[DevCli] probe scene=%s region=%s" % [get_tree().current_scene.name, GameState.current_region_id])
	print("[DevCli] probe state: day=%d time=%s money=%d fuel=%.1f upgrades=%s" % [TimeManager.day, TimeManager.get_clock_string(), GameState.money, GameState.fuel, GameState.upgrades])
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


## --story [--stop=intro|name|hub|harvest|deliver|photo] : plays the stage-3 loop.
func _story_test(stop: String) -> void:
	var scene: Node = get_tree().current_scene
	var travel := scene.find_child("TravelController", true, false) as TravelController
	var ui := scene.find_child("DialogueUI", true, false) as DialogueUI
	var fadime := scene.find_child("Fadime", true, false) as Npc
	var harvest := scene.find_child("TeaHarvest", true, false) as TeaHarvestActivity
	var camper := travel.camper
	# Park near the tea station and walk over.
	var region: Region = GameState.current_region
	var park := Vector3(24.0, 0.0, 149.0)
	camper.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(80)), Vector3(park.x, region.get_ground_height(park.x, park.z) + 0.5, park.z))
	for i: int in 20:
		await get_tree().physics_frame
	_press_once(&"interact")
	for i: int in 5:
		await get_tree().physics_frame
	_place_walker(travel, fadime.global_position + fadime.global_basis.z * -1.6)
	travel.follow_camera.yaw = fadime.global_rotation.y + PI * 0.75
	await get_tree().physics_frame
	var focus: Interactable = travel.get_focused_interactable()
	print("[DevCli] story: focused=%s prompt=%s" % [focus.get_parent().name if focus else "none", focus.prompt_key if focus else ""])
	_press_once(&"interact")
	await _settle()
	print("[DevCli] story: dialogue open=%s node=%s" % [ui.is_open(), ui.runner.current_id if ui.runner else ""])
	if stop == "intro":
		return
	await _advance(ui)                       # intro -> name input
	if stop == "name":
		ui._name_edit.text = "Deniz"
		return
	ui._name_edit.text = "Deniz"
	ui._submit_name()
	await _settle()
	print("[DevCli] story: player_name=%s rel=%d met=%s" % [GameState.player_name, GameState.get_relationship(&"fadime"), GameState.has_flag("fadime.met")])
	await _advance(ui)                       # intro_3 -> hub
	if stop == "hub":
		return
	await _choose(ui, "FADIME_CH_WORK")
	await _choose(ui, "CH_YES_GLADLY")
	print("[DevCli] story: harvest active=%s status='%s'" % [harvest.active, harvest.get_status_text()])
	await _advance(ui)                       # work_go -> end
	print("[DevCli] story: dialogue closed=%s context=%s" % [not ui.is_open(), GameState.Context.keys()[GameState.context]])
	var money_before: int = GameState.money
	var picks: int = 0
	while picks < GameState.ECONOMY.tea_target_bunches:
		var shoot: Node3D = harvest._shoots[0]
		_place_walker(travel, shoot.global_position + Vector3(0.9, -0.85, 0.4))
		await get_tree().physics_frame
		var target: Interactable = travel.get_focused_interactable()
		if target == null or target.get_parent() != shoot:
			print("[DevCli] story: WARNING focus mismatch at pick %d" % picks)
		_press_once(&"interact")
		await get_tree().physics_frame
		await get_tree().physics_frame
		picks += 1
		if stop == "harvest" and picks == 9 and not harvest._shoots.is_empty():
			shoot = harvest._shoots[0]
			travel.follow_camera.yaw = atan2(-(shoot.global_position.x - travel.walker.global_position.x), -(shoot.global_position.z - travel.walker.global_position.z)) + 0.3
			travel.follow_camera.pitch = -0.35
			return
	print("[DevCli] story: picked=%d golden=%d full_flag=%s status='%s'" % [harvest.picked, harvest.golden_picked, GameState.has_flag("fadime.harvest_full"), harvest.get_status_text()])
	_place_walker(travel, fadime.global_position + Vector3(0.5, 0, -1.6))
	await get_tree().physics_frame
	_press_once(&"interact")
	await _settle()
	print("[DevCli] story: deliver node=%s" % ui.runner.current_id)
	await _advance(ui)                       # deliver -> pay line
	print("[DevCli] story: paid=%d money=%d rel=%d level=%d" % [GameState.money - money_before, GameState.money, GameState.get_relationship(&"fadime"), GameState.get_relationship_level(&"fadime")])
	if stop == "deliver":
		return
	await _advance(ui)                       # pay -> hub
	if not GameState.album.entries.is_empty():
		await _choose(ui, "FADIME_CH_PHOTO")
		print("[DevCli] story: picker visible=%s photos=%d" % [ui._picker.visible, GameState.album.entries.size()])
		if stop == "picker":
			return
		# Prefer a photo Fadime loves and hasn't bought yet.
		var pick: Dictionary = GameState.album.entries[0]
		for e: Dictionary in GameState.album.entries:
			if "fadime" in e.get("sold_to", []):
				continue
			for item: Dictionary in e.get("subject_list", []):
				if item.id in ["SUBJ_TEA_GARDEN", "SUBJ_COW"]:
					pick = e
		ui._picker.visible = false
		ui.runner.choose_photo(pick)
		await _settle()
		print("[DevCli] story: photo reaction=%s amount=%s" % [ui.runner.current_id, ui.runner.vars.get("amount")])
		if stop == "photo":
			return
		var m: int = GameState.money
		await _choose(ui, "CH_SELL")
		print("[DevCli] story: sold for %d, rel=%d" % [GameState.money - m, GameState.get_relationship(&"fadime")])
		await _advance(ui)
	await _choose(ui, "CH_BYE")
	await _advance(ui)
	print("[DevCli] story: end money=%d rel=%d people=%s context=%s" % [GameState.money, GameState.get_relationship(&"fadime"), GameState.people.keys(), GameState.Context.keys()[GameState.context]])
	SaveManager.save_game("story_test")
	GameState.money = 0
	GameState.relationships = {}
	SaveManager.load_game("story_test")
	print("[DevCli] story: after reload money=%d rel=%d name=%s" % [GameState.money, GameState.get_relationship(&"fadime"), GameState.player_name])


## --workshop [--stop=hub|shop] : meet Recep, buy tyres, fill up.
func _workshop_test(stop: String) -> void:
	var scene: Node = get_tree().current_scene
	var travel := scene.find_child("TravelController", true, false) as TravelController
	var ui := scene.find_child("DialogueUI", true, false) as DialogueUI
	var recep := scene.find_child("Recep", true, false) as Npc
	var region: Region = GameState.current_region
	var park := Vector3(-134.0, 0.0, -44.0)
	travel.camper.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(10)), Vector3(park.x, region.get_ground_height(park.x, park.z) + 0.5, park.z))
	GameState.fuel = 6.0
	for i: int in 20:
		await get_tree().physics_frame
	_press_once(&"interact")
	for i: int in 5:
		await get_tree().physics_frame
	_place_walker(travel, recep.global_position + recep.global_basis.z * -1.7)
	await get_tree().physics_frame
	var focus: Interactable = travel.get_focused_interactable()
	print("[DevCli] workshop: focused=%s" % (focus.get_parent().name if focus else "none"))
	_press_once(&"interact")
	await _settle()
	await _advance(ui)                      # intro_1 -> intro_2
	await _advance(ui)                      # intro_2 -> hub line
	if stop == "hub":
		return
	await _choose(ui, "RECEP_CH_SHOP")
	print("[DevCli] workshop: shop visible=%s money=%d" % [ui._shop.visible, GameState.money])
	if stop == "shop":
		return
	var before: int = GameState.money
	var bought: bool = GameState.buy_upgrade("tyres", recep.npc_id)
	print("[DevCli] workshop: bought tyres=%s paid=%d level=%d" % [bought, before - GameState.money, GameState.get_upgrade_level("tyres")])
	ui._close_shop()
	await _settle()
	await _advance(ui)                      # shop_closed -> hub
	var fuel_before: float = GameState.fuel
	await _choose(ui, "RECEP_CH_FUEL")
	print("[DevCli] workshop: refuel node=%s fuel %.1f -> %.1f price=%s" % [ui.runner.current_id, fuel_before, GameState.fuel, ui.runner.vars.get("price")])
	await _advance(ui)
	await _choose(ui, "CH_BYE")
	await _advance(ui)
	print("[DevCli] workshop: done context=%s" % GameState.Context.keys()[GameState.context])


## --interior [--stop=inside|rest] : go inside, use bed/kettle, sleep till morning.
func _interior_test(stop: String) -> void:
	var scene: Node = get_tree().current_scene
	var travel := scene.find_child("TravelController", true, false) as TravelController
	for i: int in 120:
		await get_tree().physics_frame
		if i > 10 and travel.camper.is_stopped():
			break
	_press_once(&"interact")                # get out of the van
	for i: int in 5:
		await get_tree().physics_frame
	_place_walker(travel, travel.camper.global_transform * Vector3(1.9, 0, 0.4))
	await get_tree().physics_frame
	var door: Interactable = travel.get_focused_interactable()
	print("[DevCli] interior: door prompt=%s" % (door.prompt_key if door else "none"))
	if door:
		door.interacted.emit(travel.walker)
	for i: int in 5:
		await get_tree().physics_frame
	print("[DevCli] interior: mode=%s inside_floor=%.2f" % [GameState.PlayerMode.keys()[GameState.player_mode], travel.walker.global_position.y - travel.camper.global_position.y])
	var prompts: Array = []
	for node: Node in get_tree().get_nodes_in_group(&"interactable"):
		var it := node as Interactable
		if it.is_inside_tree() and travel.interior.is_ancestor_of(it):
			prompts.append(it.prompt_key)
	print("[DevCli] interior: interactables=%s" % [prompts])
	if _args.has("look"):
		travel.follow_camera.yaw = travel.camper.global_rotation.y + deg_to_rad(float(_args["look"]))
		travel.follow_camera.pitch = deg_to_rad(float(_args.get("lookpitch", "-12")))
	if stop == "inside":
		return
	var day: int = TimeManager.day
	RestMenu.apply_rest(RestMenu.hours_until(TimeManager.time_of_day, 7.0))
	print("[DevCli] interior: slept day %d -> %d at %s" % [day, TimeManager.day, TimeManager.get_clock_string()])
	if stop == "rest":
		(scene.find_child("RestMenu", true, false) as RestMenu).open()
		return
	travel.exit_interior()
	await get_tree().physics_frame
	print("[DevCli] interior: back outside mode=%s" % GameState.PlayerMode.keys()[GameState.player_mode])


## --sketch [--stop=draw] [--tool=watercolor] : paints the view with real strokes, then saves.
func _sketch_test(stop: String) -> void:
	var sketch := get_tree().current_scene.find_child("SketchMode", true, false) as SketchMode
	for i: int in 60:
		await get_tree().physics_frame
	await sketch.open()
	var c: PaintCanvas = sketch.canvas
	if stop == "open":
		sketch.reference_index = 2
		sketch._apply_reference()
		sketch._select_tool("watercolor")
		c.brush_color = Color(0.45, 0.65, 0.9)
		c.brush_radius = 30.0
		c.begin_stroke(Vector2(40, 60))
		c.continue_stroke(Vector2(500, 70))
		c.end_stroke()
		return
	if _args.has("tool"):
		sketch._select_tool(_args["tool"])
	var stroke := func(color: Color, radius: float, points: Array) -> void:
		c.brush_color = color
		c.brush_radius = radius
		c.begin_stroke(points[0])
		for p: Vector2 in points.slice(1):
			c.continue_stroke(p)
		c.end_stroke()
	# Sky in broad horizontal washes, lighter towards the horizon.
	for row: int in 8:
		var y: float = 20 + row * 26
		stroke.call(Color(0.45, 0.65, 0.9).lerp(Color(0.95, 0.85, 0.7), row / 8.0), 18.0, [Vector2(0, y), Vector2(960, y + 6)])
	stroke.call(Color(1.0, 0.85, 0.35), 34.0, [Vector2(720, 90), Vector2(722, 92)])
	# Mountain ridge.
	stroke.call(Color(0.45, 0.48, 0.55), 10.0, [Vector2(0, 250), Vector2(140, 150), Vector2(260, 230), Vector2(400, 120), Vector2(560, 240), Vector2(700, 170), Vector2(830, 230), Vector2(960, 160)])
	for row: int in 4:
		var y: float = 230 + row * 18
		stroke.call(Color(0.42, 0.46, 0.52), 14.0, [Vector2(0, y + 30), Vector2(960, y)])
	# Meadow and forest band.
	for row: int in 9:
		var y: float = 300 + row * 28
		stroke.call(Color(0.35, 0.62, 0.28).lerp(Color(0.5, 0.7, 0.3), row / 9.0), 20.0, [Vector2(0, y), Vector2(960, y - 8)])
	for i: int in 14:
		var x: float = 30 + i * 68
		stroke.call(Color(0.14, 0.34, 0.18), 7.0, [Vector2(x, 330), Vector2(x - 14, 300), Vector2(x, 262), Vector2(x + 14, 300), Vector2(x, 330)])
	# Winding road and the camper.
	stroke.call(Color(0.62, 0.48, 0.32), 16.0, [Vector2(480, 540), Vector2(430, 470), Vector2(520, 410), Vector2(470, 350)])
	stroke.call(Color(0.25, 0.55, 0.55), 12.0, [Vector2(560, 430), Vector2(640, 430)])
	stroke.call(Color(0.95, 0.92, 0.82), 9.0, [Vector2(562, 412), Vector2(636, 412)])
	stroke.call(Color(0.15, 0.15, 0.18), 5.0, [Vector2(575, 446), Vector2(576, 447)])
	stroke.call(Color(0.15, 0.15, 0.18), 5.0, [Vector2(624, 446), Vector2(625, 447)])
	print("[DevCli] sketch: strokes=%d colours=%d coverage=%.2f subjects=%s" % [c.strokes, c.colors_used.size(), c.coverage(), sketch._subjects.map(func(x: Dictionary) -> String: return x.id)])
	if stop == "draw":
		return
	var entry: Dictionary = sketch.save_drawing()
	print("[DevCli] sketch: saved value=%d file=%s book=%d" % [entry.value, entry.path, GameState.drawings.entries.size()])
	if _args.has("journal"):
		for i: int in 3:
			await get_tree().process_frame
		var journal := get_tree().current_scene.find_child("Journal", true, false) as Journal
		journal.open()
		journal._tabs.current_tab = 2
		if _args.has("detail"):
			journal._show_detail(entry)


## --fishing [--stop=haul|caught] : meet Hasan Reis, haul a net, deliver the catch.
func _fishing_test(stop: String) -> void:
	var scene: Node = get_tree().current_scene
	var travel := scene.find_child("TravelController", true, false) as TravelController
	var ui := scene.find_child("DialogueUI", true, false) as DialogueUI
	var hasan := scene.find_child("Hasan", true, false) as Npc
	var net := scene.find_child("NetHaul", true, false) as NetHaulActivity
	for i: int in 60:
		await get_tree().physics_frame
		if i > 10 and travel.camper.is_stopped():
			break
	_press_once(&"interact")
	for i: int in 5:
		await get_tree().physics_frame
	_place_walker(travel, hasan.global_position + hasan.global_basis.z * -1.7)
	await get_tree().physics_frame
	var focus: Interactable = travel.get_focused_interactable()
	print("[DevCli] fishing: focused=%s" % (focus.get_parent().name if focus else "none"))
	if focus:
		focus.interacted.emit(travel.walker)
	await _settle()
	print("[DevCli] fishing: node=%s" % ui.runner.current_id)
	while ui.runner.current_id != "hub" and ui.runner.current_id != "":
		if ui._name_row.visible:
			ui._name_edit.text = "Deniz"
			ui._submit_name()
			await _settle()
		else:
			await _advance(ui)
	await _choose(ui, "HASAN_CH_WORK")
	await _choose(ui, "CH_YES_GLADLY")
	await _advance(ui)
	print("[DevCli] fishing: net active=%s status='%s'" % [net.active, net.get_status_text()])
	# Walk to the pier head and haul.
	var head: Vector3 = net.global_position + Vector3(0, 1.0, -1.0)
	travel.walker.global_position = head
	travel.walker.velocity = Vector3.ZERO
	travel.follow_camera.yaw = 0.0
	travel.follow_camera.pitch = -0.25
	for i: int in 3:
		await get_tree().physics_frame
	var spot: Interactable = travel.get_focused_interactable()
	print("[DevCli] fishing: pier spot prompt=%s" % (spot.prompt_key if spot else "none"))
	if spot:
		spot.interacted.emit(travel.walker)
	var pulls: int = 0
	while net.hauling and pulls < 40:
		# Alternate a perfect pull and a mistimed one, like a real player would.
		net._marker = net._zone_center if pulls % 3 != 2 else fposmod(net._zone_center + 0.5, 1.0)
		net.pull()
		pulls += 1
		await get_tree().process_frame
		if stop == "haul" and pulls == 6:
			return
	print("[DevCli] fishing: pulls=%d catch=%s status='%s'" % [pulls, net.catch, net.get_status_text()])
	if stop == "caught":
		travel.walker.global_position = head + Vector3(1.2, 0, -3.5)
		travel.follow_camera.yaw = PI * 0.15
		return
	_place_walker(travel, hasan.global_position + hasan.global_basis.z * -1.7)
	var money: int = GameState.money
	(travel.get_focused_interactable()).interacted.emit(travel.walker)
	await _settle()
	await _advance(ui)
	print("[DevCli] fishing: delivered pay=%d rel=%d" % [GameState.money - money, GameState.get_relationship(&"hasan")])
	await _advance(ui)
	await _choose(ui, "CH_BYE")
	await _advance(ui)


## --travel=<region_id> : drive to the gate, open the map and travel.
func _travel_test(region_id: String) -> void:
	var scene: Node = get_tree().current_scene
	var travel := scene.find_child("TravelController", true, false) as TravelController
	var region: Region = GameState.current_region
	var gate: Transform3D = region.terrain.gate_transform
	travel.camper.global_transform = Transform3D(gate.basis, Vector3(gate.origin.x, region.get_ground_height(gate.origin.x, gate.origin.z) + 0.5, gate.origin.z))
	for i: int in 30:
		await get_tree().physics_frame
	var map := scene.find_child("MapPanel", true, false) as MapPanel
	print("[DevCli] travel: near_gate=%s can_travel=%s from=%s day=%d %s fuel=%.1f" % [region.is_near_gate(travel.camper.global_position), map.can_travel(), GameState.current_region_id, TimeManager.day, TimeManager.get_clock_string(), GameState.fuel])
	await GameState.travel_to(StringName(region_id))
	for i: int in 30:
		await get_tree().process_frame
	var cam_travel := get_tree().current_scene.find_child("TravelController", true, false) as TravelController
	print("[DevCli] travel: arrived region=%s scene=%s day=%d %s fuel=%.1f camper=%s near_gate=%s" % [GameState.current_region_id, get_tree().current_scene.name, TimeManager.day, TimeManager.get_clock_string(), GameState.fuel, cam_travel.camper.global_position.snapped(Vector3.ONE), GameState.current_region.is_near_gate(cam_travel.camper.global_position)])


## --job=<NpcNode>:<ActivityNode>:<choice key> [--stop=game]: talk the NPC
## into a job, walk to it, play (auto-finish at 80%), report back, get paid.
func _job_test(spec: String, stop: String) -> void:
	var parts: PackedStringArray = spec.split(":")
	var scene: Node = get_tree().current_scene
	var travel := scene.find_child("TravelController", true, false) as TravelController
	var ui := scene.find_child("DialogueUI", true, false) as DialogueUI
	var npc := scene.find_child(parts[0], true, false) as Npc
	var act := scene.find_child(parts[1], true, false) as Activity
	if parts[2].ends_with("WORK2"):
		GameState.add_relationship(npc.npc_id, 40)  # second jobs open with friendship
	for i: int in 60:
		await get_tree().physics_frame
		if i > 10 and travel.camper.is_stopped():
			break
	_press_once(&"interact")
	for i: int in 5:
		await get_tree().physics_frame
	_place_walker(travel, npc.global_position + npc.global_basis.z * -1.7)
	await get_tree().physics_frame
	var focus: Interactable = travel.get_focused_interactable()
	if focus:
		focus.interacted.emit(travel.walker)
	await _settle()
	while ui.runner.current_id != "hub" and ui.runner.current_id != "":
		if ui._name_row.visible:
			ui._name_edit.text = "Deniz"
			ui._submit_name()
			await _settle()
		else:
			await _advance(ui)
	await _choose(ui, parts[2])
	await _choose(ui, "CH_YES_GLADLY")
	while ui.runner.current_id != "":
		await _advance(ui)
	print("[DevCli] job: started=%s status=%s" % [act.active, act.get_status_text()])
	if act is SheepHerdingActivity:
		var herd := act as SheepHerdingActivity
		_place_walker(travel, herd.global_position + Vector3(0, 0, 30))
		for i: int in 120:
			await get_tree().physics_frame
		if stop == "game":
			return
		for sh: Dictionary in herd.sheep:
			(sh.node as Node3D).global_position = herd.pen_center() + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		for i: int in 5:
			await get_tree().process_frame
		print("[DevCli] job: penned=%d done=%s" % [herd.penned_count(), GameState.has_flag("ferhat.herd_done")])
	else:
		var game := act as MiniGameActivity
		_place_walker(travel, game.global_position + game.global_basis.z * 1.6)
		await get_tree().physics_frame
		var spot: Interactable = travel.get_focused_interactable()
		print("[DevCli] job: spot=%s" % (spot.prompt_key if spot else "none"))
		if spot:
			spot.interacted.emit(travel.walker)
		for i: int in 90:
			await get_tree().process_frame
		if stop == "game":
			return
		game.finish_game(0.8)
		await _settle()
	var money_before: int = GameState.money
	_place_walker(travel, npc.global_position + npc.global_basis.z * -1.7)
	await get_tree().physics_frame
	focus = travel.get_focused_interactable()
	if focus:
		focus.interacted.emit(travel.walker)
	await _settle()
	for i: int in 3:
		if ui.runner.current_id == "hub" or ui.runner.current_id == "":
			break
		await _advance(ui)
	print("[DevCli] job: paid=%d active=%s node=%s" % [GameState.money - money_before, act.active, ui.runner.current_id])
	if stop == "paid":
		return
	ui._close()


## --cafe [--stop=menu]: buy the kit, open the café behind the camper, serve.
func _cafe_test(stop: String) -> void:
	var scene: Node = get_tree().current_scene
	var travel := scene.find_child("TravelController", true, false) as TravelController
	GameState.upgrades["cafe_kit"] = 1
	for i: int in 60:
		await get_tree().physics_frame
		if i > 10 and travel.camper.is_stopped():
			break
	_press_once(&"interact")
	for i: int in 10:
		await get_tree().physics_frame
	var cafe := get_tree().get_first_node_in_group(&"cafe") as TravellingCafe
	print("[DevCli] cafe: can_open=%s" % cafe.can_open())
	cafe.open_cafe()
	cafe._spawn_t = 0.0
	var money_before: int = GameState.money
	for i: int in 2400:
		await get_tree().physics_frame
		if cafe._waiting_customer() != null:
			break
	var c: Variant = cafe._waiting_customer()
	print("[DevCli] cafe: waiting=%s order=%s" % [c != null, c.order if c else ""])
	_place_walker(travel, cafe._counter.global_position + cafe.global_basis.z * 1.3)
	await get_tree().physics_frame
	if stop == "menu":
		cafe.open_menu()
		return
	if c:
		var wrong: int = cafe.serve("CAFE_SIMIT" if c.order != "CAFE_SIMIT" else "CAFE_TEA")
		var right: int = cafe.serve(c.order)
		print("[DevCli] cafe: wrong=%d right=%d" % [wrong, right])
	for i: int in 30:
		await get_tree().process_frame
	print("[DevCli] cafe: served=%d earned=%d money+%d" % [cafe.served, cafe.earned, GameState.money - money_before])


## --smoke[=seconds] : drive, walk, talk to every NPC, enter the camper; prints
## frame-time stats and a pass/fail line. Run once per region.
func _smoke_test(seconds: float) -> void:
	var scene: Node = get_tree().current_scene
	var travel := scene.find_child("TravelController", true, false) as TravelController
	var ui := scene.find_child("DialogueUI", true, false) as DialogueUI
	var problems: Array[String] = []
	var t0: int = Time.get_ticks_msec()
	await _drive_test(maxf(seconds, 2.0), 0.0)
	for i: int in 600:
		await get_tree().physics_frame
		if travel.camper.is_stopped():
			break
	_press_once(&"interact")
	for i: int in 10:
		await get_tree().physics_frame
	if GameState.player_mode != GameState.PlayerMode.ON_FOOT:
		problems.append("could not leave the camper")
	var npcs: Array[Node] = get_tree().get_nodes_in_group(&"npc")
	for node: Node in npcs:
		var npc := node as Npc
		TimeManager.set_time(12.0)
		await get_tree().process_frame
		_place_walker(travel, npc.global_position + npc.global_basis.z * -1.6)
		ui.start(npc)
		await _settle()
		var guard: int = 0
		while ui.visible and guard < 12:
			await _advance(ui)
			guard += 1
		if ui.visible:
			ui._close()
		print("[smoke] npc %s talked ok (%d steps)" % [npc.npc_id, guard])
	_place_walker(travel, travel.camper.global_transform * Vector3(1.9, 0, 0.4))
	await get_tree().physics_frame
	var door: Interactable = travel.get_focused_interactable()
	if door == null:
		problems.append("no door prompt next to the camper")
	else:
		door.interacted.emit(travel.walker)
		for i: int in 10:
			await get_tree().physics_frame
		if GameState.player_mode != GameState.PlayerMode.INTERIOR:
			problems.append("interior did not open")
		else:
			travel.exit_interior()
	for i: int in 60:
		await get_tree().process_frame
	var qa: QaReport = GameState.qa
	print("[smoke] region=%s npcs=%d frames=%d p50=%.1fms p95=%.1fms worst=%.0fms wall=%.1fs" % [
		GameState.current_region_id, npcs.size(), qa._frames.size(), qa.percentile(0.5), qa.percentile(0.95), qa._worst_ms, (Time.get_ticks_msec() - t0) / 1000.0])
	print("[smoke] %s" % ("PASS" if problems.is_empty() else "FAIL: " + "; ".join(problems)))
	get_tree().quit()


## --atdoor : step out and stand by the sliding door (it opens).
func _at_door() -> void:
	var travel := get_tree().current_scene.find_child("TravelController", true, false) as TravelController
	for i: int in 30:
		await get_tree().physics_frame
	_press_once(&"interact")
	for i: int in 5:
		await get_tree().physics_frame
	_place_walker(travel, travel.camper.global_transform * Vector3(2.6, 0, 1.6))
	for i: int in 90:
		await get_tree().physics_frame


func _place_walker(travel: TravelController, pos: Vector3) -> void:
	var y: float = GameState.current_region.get_ground_height(pos.x, pos.z) + 0.05
	travel.walker.global_position = Vector3(pos.x, y, pos.z)
	travel.walker.velocity = Vector3.ZERO


func _settle() -> void:
	for i: int in 3:
		await get_tree().process_frame


## Finish typing and continue past the current line.
func _advance(ui: DialogueUI) -> void:
	ui._typing = false
	ui._text.visible_ratio = 1.0
	ui._waiting_advance = false
	ui.runner.advance()
	await _settle()


func _choose(ui: DialogueUI, key: String) -> void:
	if ui._typing:
		ui._typing = false
		ui._after_typing()
	for i: int in ui.runner._visible_choices.size():
		if ui.runner._visible_choices[i].text == key:
			ui._pick(i)
			await _settle()
			return
	print("[DevCli] story: WARNING choice %s not offered at %s" % [key, ui.runner.current_id])


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
