class_name PhotoMode
extends Node
## Camera mode: a free camera tethered near the player, with zoom, aperture
## (depth of field), exposure, filters and a thirds grid. Shooting saves a
## real PNG to the album and shows a small, encouraging result card.

signal photo_taken(entry: Dictionary)

const FILTER_KEYS: Array[String] = [
	"FILTER_NONE", "FILTER_WARM", "FILTER_COOL", "FILTER_MONO", "FILTER_VINTAGE", "FILTER_VIVID",
]
const FILTER_SHADER: Shader = preload("res://assets/shaders/photo_filter.gdshader")

@export var config: PhotoConfig
@export var travel_path: NodePath
@export var follow_camera_path: NodePath

var active: bool = false
var fov: float = 60.0
var aperture_index: int = 5
var exposure_ev: float = 0.0
var filter_index: int = 0
var show_grid: bool = true
var ui_hidden: bool = false
var focus_distance: float = 20.0
var last_entry: Dictionary = {}

var _travel: TravelController
var _follow: FollowCamera
var _camera := Camera3D.new()
var _attributes := CameraAttributesPractical.new()
var _yaw: float = 0.0
var _pitch: float = 0.0
var _anchor := Vector3.ZERO
var _busy: bool = false
var _filter_layer := CanvasLayer.new()
var _filter_rect := ColorRect.new()
var _filter_material := ShaderMaterial.new()
var _ui_layer := CanvasLayer.new()
var _overlay: PhotoOverlay
var _card: PhotoResultCard
var _flash := ColorRect.new()
var _shutter := AudioStreamPlayer.new()


func _ready() -> void:
	_travel = get_node(travel_path)
	_follow = get_node(follow_camera_path)
	_camera.name = "PhotoCamera"
	_camera.far = 4500.0
	_camera.attributes = _attributes
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_camera)

	_filter_layer.layer = 5
	_filter_material.shader = FILTER_SHADER
	_filter_rect.material = _filter_material
	_filter_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter_layer.add_child(_filter_rect)
	add_child(_filter_layer)

	_ui_layer.layer = 6
	_overlay = PhotoOverlay.new(self)
	_ui_layer.add_child(_overlay)
	_card = PhotoResultCard.new()
	_ui_layer.add_child(_card)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_flash)
	add_child(_ui_layer)

	_shutter.stream = ProceduralAudio.shutter()
	_shutter.bus = AudioManager.BUS_SFX
	add_child(_shutter)
	_set_visible(false)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		if event.is_action_pressed(&"photo_mode") and GameState.is_gameplay():
			enter()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if _busy:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		var sens: float = 0.0022 * fov / 60.0
		_look(-m.relative.x * sens, -m.relative.y * sens)
	elif event.is_action_pressed(&"photo_mode") or event.is_action_pressed(&"pause"):
		exit()
	elif event.is_action_pressed(&"photo_shoot"):
		shoot()
	elif event.is_action_pressed(&"photo_zoom_in"):
		_zoom(-4.0)
	elif event.is_action_pressed(&"photo_zoom_out"):
		_zoom(4.0)
	elif event.is_action_pressed(&"photo_aperture_wider"):
		aperture_index = maxi(aperture_index - 1, 0)
	elif event.is_action_pressed(&"photo_aperture_narrower"):
		aperture_index = mini(aperture_index + 1, config.apertures.size() - 1)
	elif event.is_action_pressed(&"photo_exposure_down"):
		exposure_ev = maxf(exposure_ev - 0.33, -config.exposure_range)
	elif event.is_action_pressed(&"photo_exposure_up"):
		exposure_ev = minf(exposure_ev + 0.33, config.exposure_range)
	elif event.is_action_pressed(&"photo_filter_next"):
		filter_index = (filter_index + 1) % FILTER_KEYS.size()
	elif event.is_action_pressed(&"photo_grid"):
		show_grid = not show_grid
	elif event.is_action_pressed(&"photo_hide_ui"):
		ui_hidden = not ui_hidden


func enter() -> void:
	if active:
		return
	active = true
	GameState.set_context(GameState.Context.PHOTO)
	_travel.suspend_control()
	var src: Camera3D = _follow.camera
	_camera.global_transform = src.global_transform
	var euler: Vector3 = src.global_basis.get_euler()
	_yaw = euler.y
	_pitch = euler.x
	fov = src.fov
	_anchor = _travel.get_controlled_body().global_position + Vector3(0, 1.6, 0)
	_camera.current = true
	_set_visible(true)


func exit() -> void:
	if not active:
		return
	active = false
	_follow.camera.current = true
	_set_visible(false)
	GameState.set_context(GameState.Context.GAMEPLAY)
	_travel.restore_control()


func _process(delta: float) -> void:
	if not active:
		return
	var stick := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	if stick.length() > 0.0:
		_look(-stick.x * 2.0 * delta * fov / 60.0, -stick.y * 2.0 * delta * fov / 60.0)
	_move(delta)
	_camera.global_basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	_camera.fov = fov
	_update_focus()
	_update_lens()
	_filter_material.set_shader_parameter(&"mode", filter_index)
	_filter_rect.visible = true
	_overlay.visible = not ui_hidden and not _busy
	_overlay.queue_redraw()


## Takes the photo: score from the scene, then capture pixels without UI.
func shoot() -> void:
	if _busy:
		return
	_busy = true
	var blur: float = config.aperture_blur[aperture_index]
	var eval: Dictionary = PhotoScorer.evaluate(_camera, focus_distance, blur, config)
	_card.visible = false
	_overlay.visible = false
	var image: Image = await _capture()
	_shutter.play()
	_flash_screen()

	var exposure: Dictionary = PhotoScorer.rate_exposure(image)
	var score: int = PhotoScorer.final_score(eval, exposure.rating, config)
	var feedback: Array = (eval.feedback as Array).duplicate()
	if exposure.feedback != "":
		feedback.append(exposure.feedback)
	var subject_list: Array = []
	var seen_ids: Dictionary = {}
	for s: Dictionary in eval.subjects:
		if not seen_ids.has(s.id):
			seen_ids[s.id] = true
			subject_list.append({"id": String(s.id), "name_key": s.name_key, "category": s.category})
	for m: StringName in eval.moments:
		subject_list.append({"id": String(m), "name_key": String(m), "category": PhotoSubject.Category.MOMENT})
	var info: Dictionary = {
		"day": TimeManager.day,
		"hour": TimeManager.time_of_day,
		"region": String(GameState.current_region_id),
		"weather": String(WeatherManager.target_id),
		"score": score,
		"stars": PhotoScorer.stars(score, config),
		"subject_list": subject_list,
		"main": String(eval.main.get("id", "")),
		"breakdown": {
			"content": eval.content, "composition": eval.composition,
			"focus": eval.focus, "exposure": exposure.rating,
		},
		"feedback": feedback,
		"filter": FILTER_KEYS[filter_index],
		"aperture": config.apertures[aperture_index],
		"fov": fov,
	}
	var entry: Dictionary = GameState.album.add_photo(image, info)
	entry["value"] = config.value_base + roundi(score * config.value_per_point) \
			+ config.value_new_subject_bonus * (entry.new_subjects as Array).size()
	GameState.album.save_index()
	last_entry = entry
	_card.show_result(entry, GameState.album.get_thumbnail(entry))
	photo_taken.emit(entry)
	_busy = false


func _capture() -> Image:
	if DisplayServer.get_name() == "headless":
		# No renderer in headless runs (tests): use a mid-grey frame.
		var blank := Image.create(640, 360, false, Image.FORMAT_RGB8)
		blank.fill(Color(0.45, 0.45, 0.45))
		return blank
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _look(d_yaw: float, d_pitch: float) -> void:
	_yaw += d_yaw
	_pitch = clampf(_pitch + d_pitch, -1.45, 1.45)


func _zoom(amount: float) -> void:
	var min_fov: float = config.lens_min_fov[clampi(GameState.lens_level, 0, config.lens_min_fov.size() - 1)]
	fov = clampf(fov + amount, min_fov, config.max_fov)


func _move(delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var vertical: float = Input.get_axis(&"photo_down", &"photo_up")
	var dir := Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.y) + Vector3(0, vertical, 0)
	var pos: Vector3 = _camera.global_position + dir * config.move_speed * delta
	# Tethered to the player so photo mode can't be used to fly around the map.
	var offset: Vector3 = pos - _anchor
	if offset.length() > config.move_radius:
		pos = _anchor + offset.normalized() * config.move_radius
	if GameState.current_region:
		pos.y = maxf(pos.y, GameState.current_region.get_ground_height(pos.x, pos.z) + 0.35)
	_camera.global_position = pos


func _update_focus() -> void:
	# Autofocus on whatever is under the centre of the frame.
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from - _camera.global_basis.z * 2000.0
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	var target: float = from.distance_to(hit.position) if not hit.is_empty() else 1500.0
	focus_distance = lerpf(focus_distance, target, 0.25)


func _update_lens() -> void:
	var blur: float = config.aperture_blur[aperture_index]
	_attributes.dof_blur_amount = blur
	_attributes.dof_blur_far_enabled = blur > 0.0
	_attributes.dof_blur_near_enabled = blur > 0.0 and focus_distance < 25.0
	var depth: float = focus_distance * (0.15 + config.apertures[aperture_index] * 0.06)
	_attributes.dof_blur_far_distance = focus_distance + depth
	_attributes.dof_blur_far_transition = maxf(focus_distance * 0.8, 2.0)
	_attributes.dof_blur_near_distance = maxf(focus_distance - depth * 0.5, 0.1)
	_attributes.dof_blur_near_transition = maxf(focus_distance * 0.3, 0.3)
	_attributes.exposure_multiplier = pow(2.0, exposure_ev)


func _set_visible(on: bool) -> void:
	_filter_layer.visible = on
	_ui_layer.visible = on
	if not on:
		_card.visible = false


func _flash_screen() -> void:
	_flash.color = Color(1, 1, 1, 0.85)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.35)
